-- NodeSight's settings: the main page plus Arrow, Minimap, Scanning, Switch, Sparkles and Beta.
-- Sections: Scan key, Settings panel.

local ADDON_NAME, ns = ...

local ipairs = ipairs

local defaults, SHAPES, world = ns.defaults, ns.SHAPES, ns.world
local UpdateScanner, ApplyDotScale, ApplyArrowLock = ns.UpdateScanner, ns.ApplyDotScale, ns.ApplyArrowLock
local ApplyArrowSize = ns.ApplyArrowSize
local ShowWhatsNew = ns.ShowWhatsNew
local SwitchDistance, SwitchReset = ns.SwitchDistance, ns.SwitchReset

---------------------------------------------------------------------------
-- Scan key
---------------------------------------------------------------------------

-- The scan's key binding, set from a button: click, then press the key. A listener of
-- our own, so the game's Keybindings page and its listener are left alone.
local SCAN_BINDING = "NODESIGHT_SCAN"
local LISTENING = "Press a key"
local listener, listeningOn -- listeningOn: the button that was clicked

local function ScanKeyText()
    local key = GetBindingKey(SCAN_BINDING)
    return key and GetBindingText(key) or NOT_BOUND
end

local function StopListening()
    local button = listeningOn
    listeningOn = nil
    listener:Hide()
    -- Settings rows are reused: only a button still showing our prompt is ours.
    if button:IsVisible() and button:GetText() == LISTENING then button:SetText(ScanKeyText()) end
end

local function OnKey(_, key)
    if key == "ESCAPE" then return StopListening() end
    if IsKeyPressIgnoredForBinding(key) then return end -- Shift, Ctrl or Alt alone: wait for the key
    if not InCombatLockdown() then -- key bindings can't change in combat
        local old = GetBindingKey(SCAN_BINDING)
        if old then SetBinding(old) end
        SetBinding(CreateKeyChordStringUsingMetaKeyState(key), SCAN_BINDING)
        SaveBindings(GetCurrentBindingSet())
    end
    StopListening()
end

local function ScanKeyClicked(button)
    if listeningOn then return StopListening() end
    if InCombatLockdown() then return end
    if not listener then
        listener = CreateFrame("Frame")
        listener:SetParent(UIParent)
        listener:SetFrameStrata("FULLSCREEN_DIALOG") -- keys reach it before the options window
        listener:EnableKeyboard(true)
        listener:SetScript("OnKeyDown", OnKey)
        -- The options window closed or the page changed (its rows are reused).
        listener:SetScript("OnUpdate", function()
            if not listeningOn:IsVisible() or listeningOn:GetText() ~= LISTENING or InCombatLockdown() then StopListening() end
        end)
    end
    listeningOn = button
    button:SetText(LISTENING)
    listener:Show()
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

-- Blizzard's own check (InputUtil.IsGamepadUIEnabled); Retail may have neither.
local function GamepadUI()
    local style = C_InputInterfaceStyle and C_InputInterfaceStyle.GetCurrentStyle and C_InputInterfaceStyle.GetCurrentStyle()
    return Enum.InputDeviceInterfaceType ~= nil and style == Enum.InputDeviceInterfaceType.Gamepad
end

-- The sparkle window errored on opening in this version; a new version tries it again.
local function WindowFailed()
    local version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
    if ns.db.sparkleWindowFailed ~= version then ns.db.sparkleWindowFailed = nil end
    return ns.db.sparkleWindowFailed ~= nil
end

-- Sparkles are on, but Enable Interact Key is off (1 is gamepad only), so objects get no plate.
local function InteractOff()
    if GamepadUI() or ns.SetupPending() then return false end
    local any = false
    for _, kind in ipairs(ns.KINDS) do any = any or ns.db[kind] == true end
    local value = tonumber(C_CVar.GetCVar("softTargetInteract"))
    return any and value ~= nil and value < 2
end
ns.InteractOff = InteractOff
ns.INTERACT_OFF = ("Sparkles need %s (%s > %s)."):format(ENABLE_INTERACT_TEXT, SETTINGS_TITLE, CONTROLS_LABEL)

-- The switch distance's label: the percent, and the yards it is now if known.
local function Percent(value)
    local yards = SwitchDistance(value)
    if yards then return ("%d %% (%d yd)"):format(value, math.floor(yards + 0.5)) end
    return ("%d %%"):format(value)
end

-- A pause slider's label: Off at 0.
local function Off(value)
    if value == 0 then return "Off" end
    return tostring(value)
end

local function RegisterSettings()
    -- Rows go to the current page; Page() starts a subpage.
    local main, layout = Settings.RegisterVerticalLayoutCategory("NodeSight")
    local category, pages = main, { [main] = true }
    local function Page(name)
        category, layout = Settings.RegisterVerticalLayoutSubcategory(main, name)
        pages[category] = true
    end

    -- A setting saved in NodeSightDB[key], with its change callback.
    local function Register(key, name, onChange)
        local setting = Settings.RegisterAddOnSetting(category, "NodeSight_" .. key, key, ns.db,
            type(defaults[key]), name, defaults[key])
        setting:SetValueChangedCallback(onChange)
        return setting
    end

    local function Checkbox(key, name, tooltip, onChange)
        local setting = Register(key, name, onChange)
        return setting, Settings.CreateCheckbox(category, setting, tooltip)
    end

    local function Header(text, tooltip)
        if CreateSettingsListSectionHeaderInitializer then
            local row = CreateSettingsListSectionHeaderInitializer(text, tooltip)
            layout:AddInitializer(row)
            return row
        end
    end

    -- Shown rows are worked out again only when the page is redrawn.
    local function Redraw()
        if SettingsInbound and SettingsInbound.RepairDisplay then pcall(SettingsInbound.RepairDisplay) end
    end

    -- A row indented under another, shown only while shown() says so, where the client can.
    local function Indent(row, parent, shown)
        if not row or not parent then return end
        if type(row.SetParentInitializer) == "function" then row:SetParentInitializer(parent, shown) end
        if type(row.AddShownPredicate) == "function" then row:AddShownPredicate(shown) end
    end

    -- A row under a checkbox, grayed out while it's off.
    local function Gray(row, parent, on)
        if row and parent and type(row.SetParentInitializer) == "function" then row:SetParentInitializer(parent, on) end
    end

    local function Slider(key, name, minValue, maxValue, tooltip, onChange, step, label)
        local options = Settings.CreateSliderOptions(minValue, maxValue, step or 1)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, label)
        local setting = Register(key, name, onChange)
        return setting, Settings.CreateSlider(category, setting, options, tooltip)
    end

    -- choices: the labels, or a function that returns them each time the dropdown is built.
    local function Dropdown(key, name, choices, tooltip, onChange)
        local function GetOptions()
            local container = Settings.CreateControlTextContainer()
            local labels = type(choices) == "function" and choices() or choices
            for value, label in ipairs(labels) do container:Add(value, label) end
            return container:GetData()
        end
        return Settings.CreateDropdown(category, Register(key, name, onChange), GetOptions, tooltip)
    end

    -- What's New button, left of Blizzard's Defaults button and parented to it (so
    -- it hides during searches).
    local list = SettingsPanel and SettingsPanel.Container and SettingsPanel.Container.SettingsList
    local defaultsButton = list and list.Header and list.Header.DefaultsButton
    if defaultsButton then
        local button = CreateFrame("Button", nil, nil, "UIPanelButtonTemplate")
        button:SetParent(defaultsButton)
        button:SetSize(96, 22)
        button:SetPoint("RIGHT", defaultsButton, "LEFT", -2, 0)
        button:SetText(GAMEMENU_NEW_BUTTON)
        button:SetScript("OnClick", ShowWhatsNew)
        button:Hide()
        -- Bug report, left of What's New: NodeSight's setup and its last scans, to copy.
        local bug = CreateFrame("Button", nil, nil, "UIPanelButtonTemplate")
        bug:SetParent(button)
        bug:SetSize(96, 22)
        bug:SetPoint("RIGHT", button, "LEFT", -2, 0)
        bug:SetText("Bug report")
        bug:SetScript("OnClick", function() ns.ShowReport() end)
        bug:SetScript("OnEnter", function()
            GameTooltip:SetOwner(bug, "ANCHOR_BOTTOM")
            GameTooltip:SetText("Bug report", NORMAL_FONT_COLOR:GetRGB())
            GameTooltip:AddLine("NodeSight's setup and what its last scans did. When reporting a bug, please send this with it.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        bug:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- Setup, left of Bug report: the first launch's setup window again (Setup.lua).
        local setup = CreateFrame("Button", nil, nil, "UIPanelButtonTemplate")
        setup:SetParent(button)
        setup:SetSize(96, 22)
        setup:SetPoint("RIGHT", bug, "LEFT", -2, 0)
        setup:SetText("Setup")
        setup:SetScript("OnClick", function() ns.ShowSetup() end)
        setup:SetScript("OnEnter", function()
            GameTooltip:SetOwner(setup, "ANCHOR_BOTTOM")
            GameTooltip:SetText("Setup", NORMAL_FONT_COLOR:GetRGB())
            GameTooltip:AddLine("Pick how much the scans may interrupt you and what NodeSight shows, in two quick steps.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        setup:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- Scanning isn't working now (ns.Trouble): a warning sign and "Not scanning" left of
        -- the buttons; its tooltip says why and what to do. Checked twice a second while shown.
        local trouble = CreateFrame("Frame")
        trouble:SetParent(button)
        trouble:SetPoint("RIGHT", setup, "LEFT", -10, 0)
        trouble:EnableMouse(true)
        trouble:Hide()
        local sign = trouble:CreateTexture(nil, "ARTWORK")
        sign:SetAtlas("services-icon-warning")
        sign:SetSize(16, 14)
        sign:SetPoint("LEFT")
        local line = trouble:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        line:SetPoint("LEFT", sign, "RIGHT", 4, 0)
        line:SetTextColor(RED_FONT_COLOR:GetRGB())
        line:SetText("Not scanning")
        trouble:SetSize(20 + line:GetStringWidth(), 22)
        local nextLook = 0
        local function Look()
            nextLook = GetTime() + 0.5
            local ok, id = pcall(ns.Trouble)
            trouble:SetShown(ok and id ~= nil)
        end
        button:SetScript("OnUpdate", function()
            if GetTime() >= nextLook then Look() end
        end)
        trouble:SetScript("OnEnter", function()
            local ok, id, _, title, text = pcall(ns.Trouble)
            if not ok or not id then return end
            GameTooltip:SetOwner(trouble, "ANCHOR_BOTTOM")
            GameTooltip:SetText(title, NORMAL_FONT_COLOR:GetRGB())
            GameTooltip:AddLine(text, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        trouble:SetScript("OnLeave", function() GameTooltip:Hide() end)
        EventRegistry:RegisterCallback("Settings.CategoryChanged", function(_, shown)
            button:SetShown(pages[shown] == true)
            Look()
        end, button)
        -- Until this version's notes are opened, the button's own hover light
        -- (UIPanelButtonHighlightTexture's picture) slowly fades in and out while it shows.
        local version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
        if NodeSightDB.notesSeen ~= version then
            local light = button:CreateTexture(nil, "ARTWORK")
            light:SetTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
            light:SetTexCoord(0, 0.625, 0, 0.6875)
            light:SetBlendMode("ADD")
            light:SetAllPoints(button)
            local pulse = light:CreateAnimationGroup()
            pulse:SetLooping("BOUNCE")
            local fade = pulse:CreateAnimation("Alpha")
            fade:SetFromAlpha(1)
            fade:SetToAlpha(0.1)
            fade:SetDuration(1)
            fade:SetSmoothing("IN_OUT")
            button:HookScript("OnShow", function()
                if NodeSightDB.notesSeen ~= version then pulse:Play() end
            end)
            button:HookScript("OnClick", function()
                NodeSightDB.notesSeen = version
                pulse:Stop()
                light:Hide()
            end)
        end
    end

    Header("Minimap symbols: how often it scans is on the Scanning page", ns.SCAN_NOTICE[2])
    Checkbox("scanMinimap", "Scan the minimap",
        "Scans the minimap for herbs and ore, for the symbols and the arrow: with your Scan key, on a timer or by distance (the Scanning page). "
            .. "Your minimap is hidden for a moment while it scans. Turn it off and NodeSight never touches your minimap; the sparkles still work.",
        UpdateScanner)
    Checkbox("mapIcons", "Herb and ore symbols",
        "Puts the herb's or ore's map symbol on the minimap where the scan finds one. Needs Scan the minimap, and Find Herbs or Find Minerals on.",
        UpdateScanner)
    local arrowTip = "An arrow near the top of the screen points to the nearest herb or ore on your minimap, with its name and distance. Drag it to move it. Needs Scan the minimap."
    local arrow = Checkbox("arrow", "Arrow to the nearest herb or ore", arrowTip, function() UpdateScanner() Redraw() end)
    local findersTip = "Switches between Find Herbs and Find Minerals. You need both trained and one active to start. "
        .. "With Scan on a timer or Scan by distance on, it switches right before each of their scans."
    -- Toggling the switch also ends a stop after failed switches; other settings keep it.
    local finders = Checkbox("switchFinders", "Switch between herbs and ore", findersTip,
        function() SwitchReset() UpdateScanner() Redraw() end)
    local _, soundRow = Checkbox("sound", "Sound for new finds",
        "Plays a sound when something new shows up on your minimap. Not for herbs or ore above your skill.",
        function() UpdateScanner() Redraw() end)
    local function SoundOn() return ns.db.sound end
    Indent(Dropdown("soundKit", "Sound", ns.FIND_SOUND_NAMES, "Which of the game's sounds plays. Picking one plays it.",
        ns.PlayFindSound), soundRow, SoundOn)
    Indent(select(2, Checkbox("soundSkillUps", "Only for skill-ups",
        "Only herbs and ore you can still get a skill-up from make the sound. Not chests or rares.",
        UpdateScanner)), soundRow, SoundOn)
    Checkbox("skillLine", "Required skill in tooltips",
        "Shows the skill a herb or ore needs in its tooltip.",
        function() end) -- (tooltips are built again each time they show)

    -- Every kind of sparkle at once, like the Sparkle window's "Sparkles on everything".
    local function AllOn()
        for _, kind in ipairs(ns.KINDS) do
            if not ns.db[kind] then return false end
        end
        return true
    end
    local function AllText() return AllOn() and DISABLE_ALL_ADDONS or ENABLE_ALL_ADDONS end
    layout:AddInitializer(CreateSettingsButtonInitializer("Sparkles", AllText, function(button)
        local on = not AllOn()
        for _, kind in ipairs(ns.KINDS) do ns.db[kind] = on end
        ns.UpdateAll()
        ns.RefreshFarSparkles()
        ns.Setup()
        ns.RefreshSparkleWindow()
        button:SetText(AllText())
    end, function()
        local tip = "Turns sparkles on or off for herbs, ore, chests, quest objects, other objects, your fishing bobber and skinnable corpses. "
            .. ((GamepadUI() or WindowFailed()) and "Each has its own setting on the Sparkles page." or "Each has its own box in the Sparkle window.")
        if InteractOff() then tip = tip .. "\n\n" .. RED_FONT_COLOR:WrapTextInColorCode(ns.INTERACT_OFF) end
        return tip
    end, false))
    if not (GamepadUI() or WindowFailed()) then
        layout:AddInitializer(CreateSettingsButtonInitializer("Sparkle settings", "Open", ns.ShowSparkleWindow,
            "All the sparkle settings, with a preview.", false))
    end
    Checkbox("myProfessions", "Sparkles only for my professions",
        "Herbs sparkle only if you have Herbalism, ore only with Mining, and skinnable corpses only with Skinning. Everything else sparkles as before.",
        function() ns.UpdateAll() ns.Setup() end)
    Checkbox("popups", "Popups",
        "NodeSight's popups: when an error stops scans, when Lueur scans too, when Enable Interact Key is off, the notice about scanning, "
            .. "and when the game needs a restart after an update. They wait until a fight is over. Off: none at all; "
            .. "the warning at the top of this page still says when scans aren't working.",
        function() end)

    -- Saved on the character whichever settings are in use; they switch at the next reload.
    local own = Settings.RegisterAddOnSetting(category, "NodeSight_own", "own", NodeSightCharDB, "boolean",
        "Settings for this character only", true)
    own:SetValueChangedCallback(function() end)
    Settings.CreateCheckbox(category, own,
        "This character keeps its own NodeSight settings. Untick it to use the settings your other characters share. Changes at your next reload or login.")

    Page("Arrow")
    Header("Arrow: needs scanning on", ns.SCAN_NOTICE[2])
    local arrowRow = Settings.CreateCheckbox(category, arrow, arrowTip) -- the same setting as on NodeSight's own page
    -- The rest of the page shows once the arrow is on.
    local function ArrowOn() return ns.db.arrow end
    local function UnderArrow(row) Indent(row, arrowRow, ArrowOn) end
    UnderArrow(select(2, Checkbox("arrowLocked", "Lock the arrow in place",
        "The arrow can't be dragged, and your clicks go through it to the world.",
        ApplyArrowLock)))
    UnderArrow(select(2, Checkbox("arrowSkip", "Skip the node you're at",
        "The arrow passes over a node within 5 yards of you and points to the next one.",
        UpdateScanner)))
    UnderArrow(select(2, Checkbox("arrowCombat", "Hide in combat", "No arrow while you're in combat.", UpdateScanner)))
    UnderArrow(select(2, Slider("arrowSize", "Arrow size", 20, 100,
        "How big the arrow and its text are. The default is " .. defaults.arrowSize .. ".",
        ApplyArrowSize)))
    UnderArrow(Header("Points to"))
    UnderArrow(select(2, Checkbox("arrowFirst", "Herbs and ore first",
        "The arrow points to a chest, rare, leyline or convergence only when no herb or ore is in sight.",
        UpdateScanner)))
    UnderArrow(select(2, Checkbox("arrowHerbs", "Herbs", "The arrow points to herbs.", UpdateScanner)))
    UnderArrow(select(2, Checkbox("arrowOre", "Ore", "The arrow points to ore.", UpdateScanner)))
    UnderArrow(select(2, Checkbox("arrowChests", "Chests", "The arrow points to treasure chests (Find Treasure).", UpdateScanner)))
    UnderArrow(select(2, Checkbox("arrowRares", "Rares",
        "The arrow points to rare beasts and humanoids. Needs Rares on the minimap (Minimap page).",
        UpdateScanner)))
    UnderArrow(select(2, Checkbox("arrowLeylines", "Leylines and convergences",
        "The arrow points to leylines and elemental convergences. Needs Leylines and convergences (Minimap page).",
        UpdateScanner)))

    Page("Minimap")
    Header("Symbols for")
    Checkbox("leylines", "Leylines and convergences",
        "High Order Skyborne get symbols on leylines while Read Leyline is ready, Windshaper Skyborne on elemental convergences while Skysight is ready.",
        UpdateScanner)
    local _, rares = Checkbox("rares", "Rares on the minimap",
        "For hunters and druids: a rare beast's or humanoid's dot gets a rare symbol. Needs Track Beasts or Track Humanoids on.",
        function() UpdateScanner() Redraw() end)
    local rareIcon = Dropdown("rareIcon", "Rare symbol", { "Rare icon", "Elite rare icon", "Star" },
        "Which of the game's own rare symbols a rare beast's or humanoid's dot gets.",
        UpdateScanner)
    Indent(rareIcon, rares, function() return ns.db.rares end)
    Header("Look")
    Dropdown("shape", "Symbol shape", SHAPES,
        "The shape of the herb and ore symbols on the minimap.",
        UpdateScanner)
    Dropdown("skillLook", "Skill colors", ns.SKILL_LOOKS,
        "How a symbol shows your skill. Red when too low: red if you can't gather it yet. Colored ring and Colored gem: the profession window's skill-up colors, from red to gray. Colored ring needs a gold ring Symbol shape. Needs Herb and ore symbols.",
        UpdateScanner)
    Checkbox("oreRings", "High visibility tin and iron",
        "Tin gets a green ring and iron a rust one, so they're easy to tell apart. Needs a gold ring Symbol shape.",
        UpdateScanner)
    Dropdown("nearLook", "Symbols near you", ns.NEAR_LOOKS,
        "A symbol over your own arrow on the minimap can be see-through or hidden, so you still see which way you face. Needs Herb and ore symbols.",
        UpdateScanner)
    Slider("iconSize", "Symbol size", 8, 24,
        "How big the herb and ore symbols on the minimap are. The default is " .. defaults.iconSize .. ". Needs Herb and ore symbols.",
        UpdateScanner)
    Slider("dotScale", "Size of the game's own dots", 50, 300,
        "Resizes the game's own minimap dots. 100 is the game's own size. Use it with Symbol size.",
        ApplyDotScale)
    Page("Scanning")
    Header("When")
    layout:AddInitializer(CreateSettingsButtonInitializer("Scan key", ScanKeyText, ScanKeyClicked,
        "The key that scans the minimap. Click, then press a key (with Shift, Ctrl or Alt if you like); Esc cancels. "
            .. "A key used for something else is taken from it. It's the Scan the minimap key binding (Keybindings > AddOns > NodeSight).",
        false))
    Header("Automatic scans")
    -- Presets: each sets these settings at once; the dropdown shows the one they match, or Custom.
    local PRESET_KEYS = { "autoScanTimer", "autoScanSeconds", "scanStanding", "autoScan", "autoScanYards", "combatScan", "mouseStill" }
    local PRESETS = { {},
        { autoScanTimer = true, autoScanSeconds = 5, scanStanding = true, autoScan = false, autoScanYards = 30,
            combatScan = true, mouseStill = true },
        { autoScanTimer = true, autoScanSeconds = 5, scanStanding = true, autoScan = true, autoScanYards = 20,
            combatScan = true, mouseStill = false } }
    for _, k in ipairs(PRESET_KEYS) do PRESETS[1][k] = defaults[k] end
    local CUSTOM = #PRESETS + 1
    local function Matching()
        for i, preset in ipairs(PRESETS) do
            local same = true
            for _, k in ipairs(PRESET_KEYS) do
                if ns.db[k] ~= preset[k] then same = false end
            end
            if same then return i end
        end
        return CUSTOM
    end
    local parts, presetSetting = {}, nil
    -- A setting a preset sets: changed by hand, the dropdown shows what it matches now.
    local function Part(onChange)
        return function(...)
            onChange(...)
            local now = Matching()
            if now ~= ns.db.scanPreset then
                ns.db.scanPreset = now
                if presetSetting and SettingsPanel and SettingsPanel:IsShown() then presetSetting:NotifyUpdate() end
            end
        end
    end
    ns.db.scanPreset = Matching()
    presetSetting = Register("scanPreset", "Preset", function(_, value)
        local preset = PRESETS[value]
        if preset then
            for _, k in ipairs(PRESET_KEYS) do ns.db[k] = preset[k] end
            for _, k in ipairs(PRESET_KEYS) do parts[k]:NotifyUpdate() end
            Redraw() -- (the rows grayed by Scan on a timer and Scan by distance)
        elseif Matching() ~= value then -- (Custom picked while the settings match a preset)
            ns.db.scanPreset = Matching()
            presetSetting:NotifyUpdate()
        end
    end)
    Settings.CreateDropdown(category, presetSetting, function()
        local container = Settings.CreateControlTextContainer()
        for value, label in ipairs({ "Default", "Less intrusive", "Most scans", "Custom" }) do container:Add(value, label) end
        return container:GetData()
    end, "Sets the automatic scan settings below at once. Default: as NodeSight comes. "
        .. "Less intrusive: scans only while your mouse is still, also while you stand still and in combat, every 5 seconds. "
        .. "Most scans: every 5 seconds, also while you stand still, every 20 yards walked and in combat. "
        .. "Change any of them by hand and it shows Custom.")
    local function Changed() UpdateScanner() Redraw() end
    local timerSetting, timer = Checkbox("autoScanTimer", "Scan on a timer",
        "Scans every few seconds (set below) while you're moving, so herbs and ore that appear or are taken show up. "
            .. "Not while flying, only while your mouse is over the world (not a window), and out of combat unless Scan in combat is on. "
            .. "The minimap is hidden for a moment while it scans.",
        Part(Changed))
    parts.autoScanTimer = timerSetting
    local secondsSetting, secondsRow = Slider("autoScanSeconds", "Seconds between scans", 5, 120,
        "How long Scan on a timer waits between scans. The default is " .. defaults.autoScanSeconds .. ".",
        Part(UpdateScanner), 5)
    parts.autoScanSeconds = secondsSetting
    Indent(secondsRow, timer, function() return ns.db.autoScanTimer end)
    local standingSetting, standingRow = Checkbox("scanStanding", "Also while standing still",
        "Scan on a timer scans while you stand still too, not only while you move, so herbs and ore near you show up without walking.",
        Part(UpdateScanner))
    parts.scanStanding = standingSetting
    Indent(standingRow, timer, function() return ns.db.autoScanTimer end)
    local distanceSetting, distance = Checkbox("autoScan", "Scan by distance",
        "Scans each time you've walked the distance set below. The same rules as Scan on a timer. Both can be on.",
        Part(Changed))
    parts.autoScan = distanceSetting
    local yardsSetting, yardsRow = Slider("autoScanYards", "Yards walked between scans", 10, 150,
        "How far Scan by distance waits for you to walk between scans. The default is " .. defaults.autoScanYards .. ".",
        Part(UpdateScanner), 5)
    parts.autoScanYards = yardsSetting
    Indent(yardsRow, distance, function() return ns.db.autoScan end)
    Settings.CreateCheckbox(category, finders, findersTip) -- the same setting as on NodeSight's own page
    parts.combatScan = Checkbox("combatScan", "Scan in combat",
        "Scan on a timer and Scan by distance keep scanning in combat too. The minimap is hidden for a moment each time, mid-fight. Your Scan key scans in combat either way.",
        Part(UpdateScanner))
    local _, loot = Checkbox("lootWait", "Wait to loot after fights",
        "After a fight, Scan on a timer and Scan by distance wait the seconds set below, so a scan doesn't hide the minimap while you loot. Your Scan key scans at once either way.",
        UpdateScanner)
    local _, lootRow = Slider("lootSeconds", "Seconds to wait after fights", 1, 10,
        "How long Wait to loot after fights waits. The default is " .. defaults.lootSeconds .. ".", UpdateScanner)
    Indent(lootRow, loot, function() return ns.db.lootWait end)
    Checkbox("skipRest", "Not in cities and inns",
        "Scan on a timer and Scan by distance don't scan while you're resting: in capital cities and inns (the Zzz on your portrait). Your Scan key scans there either way.",
        UpdateScanner)
    Header("Your mouse")
    Checkbox("mobWait", "Not with a mob under the mouse",
        "Scan on a timer and Scan by distance wait while your mouse is on a mob, a player or a corpse, so the minimap doesn't vanish as you go to loot or click it, and while a tooltip is open under it (a herb, a chest, a mailbox), so the tooltip stays. Your Scan key scans there either way.",
        UpdateScanner)
    parts.mouseStill = Checkbox("mouseStill", "Only while the mouse is still",
        "Scan on a timer and Scan by distance wait until your mouse has stayed put for half a second, so a scan never starts while you move it. "
            .. "A scan already running finishes. Your Scan key scans either way.",
        Part(UpdateScanner))
    Checkbox("mouseStop", "Stop when the mouse moves",
        "Scan on a timer and Scan by distance stop as soon as you move your mouse, so whatever you move onto (a mob, a herb) shows its tooltip right away. "
            .. "Your symbols stay as they were until the next scan. Your Scan key scans either way.",
        UpdateScanner)
    Header("Minimap")
    Dropdown("minimapShape", "Minimap shape", ns.MapShapeChoices,
        "Automatic asks your UI addon and shows its answer in brackets. Pick Square if herbs and ore in the corners of a square minimap don't show up.",
        UpdateScanner)
    Checkbox("scanMap", "Map while scanning (Beta)",
        "While the minimap is hidden for a scan, shows the world map's picture of where you are in its place, moving with you. Not with a rotating minimap, or where the zone has no world map.",
        UpdateScanner)
    Checkbox("scanFade", "Fade in and out",
        "The minimap fades into its stand-in (the map picture, or a dark fill) before a scan and back after, instead of blinking. Each scan starts a moment later.",
        UpdateScanner)
    Checkbox("windowWait", "Fewer blinks",
        "When your mouse goes over a window (your bags) during a scan, the minimap stays hidden for up to 2 seconds instead of coming back at once. A mouse click always brings it back at once.",
        UpdateScanner)

    Page("Switch")
    local findersRow = Settings.CreateCheckbox(category, finders, findersTip) -- the same setting as on NodeSight's own page
    -- With automatic scans on, the switch comes before each of them: its own timing isn't used.
    local function OwnTiming()
        return not (ns.db.scanMinimap and (ns.db.autoScan or ns.db.autoScanTimer and (tonumber(ns.db.autoScanSeconds) or 0) > 0))
    end
    -- The rest of the page shows once Switch is on.
    local function SwitchOn() return ns.db.switchFinders end
    local function UnderSwitch(row) Indent(row, findersRow, SwitchOn) end
    UnderSwitch(Header("When"))
    -- The measure's change restarts the way and redraws the page, so only its slider shows.
    local measure = Dropdown("switchMeasure", "Measure distance in", ns.SWITCH_MEASURES,
        "How the distance between switches is measured: percent of what your minimap shows (it changes with the zoom), yards, or seconds on the move. "
            .. "Not used while Scan on a timer or Scan by distance is on: Switch then switches right before each scan.",
        function()
            ns.SwitchMeasureChanged()
            UpdateScanner()
            if SettingsInbound and SettingsInbound.RepairDisplay then pcall(SettingsInbound.RepairDisplay) end
        end)
    Gray(measure, findersRow, OwnTiming)
    if measure and type(measure.AddShownPredicate) == "function" then measure:AddShownPredicate(SwitchOn) end
    -- A distance slider goes under the measure and shows only at its value, where the client can.
    local function Under(slider, value)
        if not slider then return end
        local function Chosen() return ns.db.switchMeasure == value end
        if measure and type(slider.SetParentInitializer) == "function" then
            slider:SetParentInitializer(measure, function() return Chosen() and OwnTiming() end)
        end
        if type(slider.AddShownPredicate) == "function" then
            slider:AddShownPredicate(Chosen)
            slider:AddShownPredicate(SwitchOn)
        end
    end
    local percent, percentSlider = Slider("switchPercent", "Distance between switches", 20, 100,
        "How far you go between switches, in percent of what your minimap shows: farther when zoomed out or outdoors. The default is " .. defaults.switchPercent .. " %.",
        UpdateScanner, 5, Percent)
    Under(percentSlider, 1)
    local yards, seconds = ns.SWITCH_RANGES.switchDistanceYards, ns.SWITCH_RANGES.switchSeconds
    local _, yardsSlider = Slider("switchDistanceYards", "Distance between switches (yards)", yards[1], yards[2],
        "How far you go between switches, in yards. The default is " .. defaults.switchDistanceYards .. ".",
        UpdateScanner, yards[3])
    Under(yardsSlider, 2)
    local _, secondsSlider = Slider("switchSeconds", "Time between switches (seconds)", seconds[1], seconds[2],
        "How long you move between switches, in seconds. Time standing still doesn't count. The default is " .. defaults.switchSeconds .. ".",
        UpdateScanner, seconds[3])
    Under(secondsSlider, 3)
    -- The yards in its label follow the minimap's zoom while the settings are open.
    if percentSlider then percentSlider.reinitializeOnValueChanged = true end
    local zoom = CreateFrame("Frame")
    zoom:RegisterEvent("MINIMAP_UPDATE_ZOOM")
    zoom:SetScript("OnEvent", function()
        if SettingsPanel and SettingsPanel:IsShown() then percent:NotifyUpdate() end
    end)
    UnderSwitch(select(2, Checkbox("switchMounted", "Only while mounted",
        "Switches only while you ride a mount. Travel Form and Ghost Wolf don't count.",
        UpdateScanner)))
    UnderSwitch(Header("Pauses"))
    UnderSwitch(select(2, Checkbox("switchPauseBusy", "Pause while casting, looting or with a spell or item on the cursor",
        "Switching pauses while you cast, gather or loot, and while a spell waits for a target or something is on your cursor.",
        UpdateScanner)))
    UnderSwitch(select(2, Slider("switchEnemyYards", "Pause with an enemy targeted within about (yards)", 0, 60,
        "Switching pauses while you target a living enemy this close, and for a second after you mouse over one. Distances are rough: the game doesn't give exact ones.",
        UpdateScanner, 1, Off)))
    UnderSwitch(select(2, Checkbox("switchPauseStealth", "Pause while stealthed",
        "Switching pauses while you're stealthed.",
        UpdateScanner)))
    UnderSwitch(select(2, Slider("switchNearYards", "Pause near a herb or ore (yards)", 0, 40,
        "Switching pauses this close to a herb or ore with a symbol, so you can walk up and gather it.",
        UpdateScanner, 1, Off)))
    UnderSwitch(select(2, Slider("switchAfterCast", "Pause after your own spells (seconds)", 0, 10,
        "Switching pauses this long after your own spells end, and after you dismount, so the switch's global cooldown doesn't get in your way.",
        UpdateScanner, 1, Off)))
    UnderSwitch(Header("Where"))
    UnderSwitch(select(2, Checkbox("switchWorld", "Switch in the open world",
        "Switches while you're in the open world.",
        UpdateScanner)))
    UnderSwitch(select(2, Checkbox("switchDungeons", "Switch in dungeons",
        "Switches while you're in a dungeon.",
        UpdateScanner)))
    UnderSwitch(select(2, Checkbox("switchRaids", "Switch in raids",
        "Switches while you're in a raid.",
        UpdateScanner)))
    UnderSwitch(select(2, Checkbox("switchBattlegrounds", "Switch in battlegrounds",
        "Switches while you're in a battleground.",
        UpdateScanner)))
    if CreateSettingsListSectionHeaderInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Thanks to tester617 for the Switch page"))
    end

    -- The sparkles' settings are all in their own window, which opens with this page.
    -- A controller can't reach that window, and its color picker and menus would run
    -- Blizzard's gamepad code tainted, so with the gamepad UI on the page has
    -- Blizzard's own rows for the basics instead (until a reload, if it's switched).
    -- The same if the window failed to open.
    Page("Sparkles")
    local sparklesPage = category
    if GamepadUI() or WindowFailed() then
        local function SparklesChanged() ns.UpdateAll() ns.RefreshFarSparkles() ns.Setup() end
        local function LookChanged() ns.UpdateAll() ns.RefreshFarSparkles() end
        for _, tab in ipairs(ns.SPARKLE_TABS) do
            if tab.on then Checkbox(tab.key, tab.on, tab.tip .. ns.SPARKLE_NEEDS, SparklesChanged) end
        end
        Checkbox("gameIcons", "Keep the game's icons", "Keeps the game's own icon over things you can interact with.", SparklesChanged)
        Slider("brightness", "Brightness", 10, 100, "How bright the sparkles are.", LookChanged)
        Checkbox("reachLook", "Dimmer out of reach", "Dimmer when it's too far to gather. Flashes when you get in range.", LookChanged)
        Checkbox("combatHide", "Hide in combat", "No sparkles while you're in combat.", LookChanged)
        Checkbox("instanceHide", "Hide in instances", "No sparkles in dungeons and raids.", LookChanged)
        Checkbox("grayTooHard", "Gray when your skill is too low", "Herbs and ore your skill is too low for sparkle gray.", LookChanged)
        Checkbox("rareGlow", "Rare nodes stand out", "A gold glow on rare herbs and ore like Black Lotus and Truesilver.", LookChanged)
        Checkbox("sparkleSound", "Sparkle sound", "Plays a soft sound when something near you starts sparkling.", LookChanged)
        Checkbox("gatherDim", "Dim while gathering", "Sparkles fade while you gather so you can see the node.", LookChanged)
        local finishes = {}
        for i, finish in ipairs(ns.HARVESTS) do finishes[i] = finish.name end
        Dropdown("harvest", "When gathered", finishes, "What the sparkles do when you loot it.", LookChanged)
    else
        -- Search tags off (false): addon code adding them taints the options' search.
        layout:AddInitializer(CreateSettingsButtonInitializer("Sparkle window", "Open", ns.ShowSparkleWindow,
            "All the sparkle settings, with a preview.", false))
        EventRegistry:RegisterCallback("Settings.CategoryChanged", function(_, shown)
            if shown == sparklesPage then ns.ShowSparkleWindow() end
        end, sparklesPage)
    end

    Page("Beta")
    Checkbox("trailFrames", "Hide frames that follow the minimap (Beta)",
        "During a scan, also hides frames other addons keep where your minimap is without being attached to it (some addons' map pins "
            .. "and icons), so they don't show up under your mouse. They're back after the scan.",
        function() end) -- (read as each scan starts)
    Checkbox("edgeScan", "Edge scans while moving (Beta)",
        "While you move, scans read only the part of the minimap that's new since the last scan, so they take less time. "
            .. "Every third scan, and any scan while you stand still, reads all of it.",
        UpdateScanner)
    local farNote = "Far away sparkles don't work as well since WoW Forever's latest update: whether a far herb is above or below you can't be read any more."
    Header(RED_FONT_COLOR:WrapTextInColorCode("Far away sparkles don't work as well now"), farNote)
    local _, far = Checkbox("worldMark", "Far away sparkles (Beta)",
        "Sparkles on the herb or ore you face, from far away. Not perfect yet, and uses a lot more CPU. Takes over your map pin while on. Needs Sparkles on herbs or ore.\n\n"
            .. RED_FONT_COLOR:WrapTextInColorCode(farNote),
        function() world.Changed() Redraw() end)
    local _, sizeRow = Slider("worldSize", "Far away sparkle size", 50, 300,
        "How big far away sparkles are: wider, and a longer column. The default is " .. defaults.worldSize .. " %.",
        function() end, 5, function(value) return ("%d %%"):format(value) end) -- (read every frame)
    Indent(sizeRow, far, function() return ns.db.worldMark end)
    local _, keepQuest = Checkbox("worldKeepQuest", "Keep my tracked quest (less accurate sparkles)",
        "Your tracked quest keeps the game's navigation, so you keep the way to your quest objective. Far away sparkles borrow the map pin for a moment after you turn or zoom (your quest's arrow blinks then), and can drift in between.\n\n"
            .. RED_FONT_COLOR:WrapTextInColorCode("Far away sparkles are much less accurate with this on."),
        function() world.Changed() Redraw() end)
    Indent(keepQuest, far, function() return ns.db.worldMark end)
    local _, realignRow = Slider("worldRealign", "Line up again every", 2, 15,
        "How often far away sparkles borrow the map pin to line up again while you track a quest. Lower is more accurate, but your quest's arrow blinks more often. The default is " .. defaults.worldRealign .. " seconds.",
        function() end, 1, function(value) return ("%d s"):format(value) end) -- (read every frame)
    Indent(realignRow, keepQuest, function() return ns.db.worldMark and ns.db.worldKeepQuest end)

    Settings.RegisterAddOnCategory(main)
end

ns.RegisterSettings = RegisterSettings
