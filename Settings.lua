-- NodeSight's settings: the main page plus Arrow, Minimap, Switch, Sparkles and Beta.

local ADDON_NAME, ns = ...

local ipairs = ipairs

local defaults, SHAPES, world = ns.defaults, ns.SHAPES, ns.world
local UpdateScanner, ApplyDotScale, ApplyArrowLock = ns.UpdateScanner, ns.ApplyDotScale, ns.ApplyArrowLock
local ApplyArrowSize = ns.ApplyArrowSize
local ShowWhatsNew = ns.ShowWhatsNew
local SwitchDistance, SwitchReset = ns.SwitchDistance, ns.SwitchReset

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

    local function Header(text)
        if CreateSettingsListSectionHeaderInitializer then
            layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
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
        EventRegistry:RegisterCallback("Settings.CategoryChanged", function(_, shown)
            button:SetShown(pages[shown] == true)
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

    Checkbox("scan", "Scan the minimap",
        "Scans the minimap for herbs and ore, for the arrow and the symbols. Turn it off to use only the sparkles.",
        UpdateScanner)
    Checkbox("mapIcons", "Herb and ore symbols",
        "Puts the herb's or ore's map symbol on the minimap where the scan finds one. Needs Scan the minimap, and Find Herbs or Find Minerals on.",
        UpdateScanner)
    local arrowTip = "An arrow near the top of the screen points to the nearest herb or ore on your minimap, with its name and distance. Drag it to move it. Needs Scan the minimap."
    local arrow = Checkbox("arrow", "Arrow to the nearest herb or ore", arrowTip, UpdateScanner)
    local findersTip = "Switches between Find Herbs and Find Minerals. You need both trained and one active to start."
    -- Toggling the switch also ends a stop after failed switches; other settings keep it.
    local finders = Checkbox("switchFinders", "Switch between herbs and ore", findersTip,
        function() SwitchReset() UpdateScanner() end)
    local _, soundRow = Checkbox("sound", "Sound for new finds",
        "Plays a sound when something new shows up on your minimap. Not for herbs or ore above your skill. Needs Scan the minimap.",
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

    -- Saved on the character whichever settings are in use; they switch at the next reload.
    local own = Settings.RegisterAddOnSetting(category, "NodeSight_own", "own", NodeSightCharDB, "boolean",
        "Settings for this character only", true)
    own:SetValueChangedCallback(function() end)
    Settings.CreateCheckbox(category, own,
        "This character keeps its own NodeSight settings. Untick it to use the settings your other characters share. Changes at your next reload or login.")

    Page("Arrow")
    Settings.CreateCheckbox(category, arrow, arrowTip) -- the same setting as on NodeSight's own page
    Checkbox("arrowLocked", "Lock the arrow in place",
        "The arrow can't be dragged, and your clicks go through it to the world.",
        ApplyArrowLock)
    Checkbox("arrowSkip", "Skip the node you're at",
        "The arrow passes over a node within 5 yards of you and points to the next one.",
        UpdateScanner)
    Slider("arrowSize", "Arrow size", 20, 100,
        "How big the arrow and its text are. The default is " .. defaults.arrowSize .. ".",
        ApplyArrowSize)
    Header("Points to")
    Checkbox("arrowFirst", "Herbs and ore first",
        "The arrow points to a chest, rare, leyline or convergence only when no herb or ore is in sight.",
        UpdateScanner)
    Checkbox("arrowHerbs", "Herbs", "The arrow points to herbs.", UpdateScanner)
    Checkbox("arrowOre", "Ore", "The arrow points to ore.", UpdateScanner)
    Checkbox("arrowChests", "Chests", "The arrow points to treasure chests (Find Treasure).", UpdateScanner)
    Checkbox("arrowRares", "Rares",
        "The arrow points to rare beasts and humanoids. Needs Rares on the minimap (Minimap page).",
        UpdateScanner)
    Checkbox("arrowLeylines", "Leylines and convergences",
        "The arrow points to leylines and elemental convergences. Needs Leylines and convergences (Minimap page).",
        UpdateScanner)

    Page("Minimap")
    Header("Symbols for")
    Checkbox("leylines", "Leylines and convergences",
        "High Order Skyborne get symbols on leylines while Read Leyline is ready, Windshaper Skyborne on elemental convergences while Skysight is ready. Needs Scan the minimap.",
        UpdateScanner)
    local _, rares = Checkbox("rares", "Rares on the minimap",
        "For hunters and druids: a rare beast's or humanoid's dot gets a rare symbol. Needs Scan the minimap, and Track Beasts or Track Humanoids on.",
        function() UpdateScanner() Redraw() end)
    local rareIcon = Dropdown("rareIcon", "Rare symbol", { "Rare icon", "Elite rare icon", "Star" },
        "Which of the game's own rare symbols a rare beast's or humanoid's dot gets.",
        UpdateScanner)
    Indent(rareIcon, rares, function() return ns.db.rares end)
    Header("Look")
    Dropdown("shape", "Symbol shape", SHAPES,
        "The shape of the herb and ore symbols on the minimap. Needs Scan the minimap.",
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
    Header("Scanning")
    Checkbox("combatScan", "Scan in combat",
        "Keeps scanning during fights, so new herbs and ore still show up. With it off, new ones show up after the fight. Needs Scan the minimap.",
        UpdateScanner)
    Slider("scanDetail", "Scan detail", 1, 3,
        "How closely the minimap is scanned: 3 is the most exact, 1 uses the least CPU but can place herbs poorly. The default is " .. defaults.scanDetail .. ". Needs Scan the minimap.",
        UpdateScanner)
    Dropdown("minimapShape", "Minimap shape", ns.MapShapeChoices,
        "Automatic asks your UI addon and shows its answer in brackets. Pick Square if herbs and ore in the corners of a square minimap don't show up. Needs Scan the minimap.",
        UpdateScanner)

    Page("Switch")
    Settings.CreateCheckbox(category, finders, findersTip) -- the same setting as on NodeSight's own page
    Header("When")
    -- The measure's change restarts the way and redraws the page, so only its slider shows.
    local measure = Dropdown("switchMeasure", "Measure distance in", ns.SWITCH_MEASURES,
        "How the distance between switches is measured: percent of what your minimap shows (it changes with the zoom), yards, or seconds on the move.",
        function()
            ns.SwitchMeasureChanged()
            UpdateScanner()
            if SettingsInbound and SettingsInbound.RepairDisplay then pcall(SettingsInbound.RepairDisplay) end
        end)
    -- A distance slider goes under the measure and shows only at its value, where the client can.
    local function Under(slider, value)
        if not slider then return end
        local function Chosen() return ns.db.switchMeasure == value end
        if measure and type(slider.SetParentInitializer) == "function" then slider:SetParentInitializer(measure, Chosen) end
        if type(slider.AddShownPredicate) == "function" then slider:AddShownPredicate(Chosen) end
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
    Checkbox("switchMounted", "Only while mounted",
        "Switches only while you ride a mount. Travel Form and Ghost Wolf don't count.",
        UpdateScanner)
    Header("Pauses")
    Checkbox("switchPauseBusy", "Pause while casting, looting or with a spell or item on the cursor",
        "Switching pauses while you cast, gather or loot, and while a spell waits for a target or something is on your cursor.",
        UpdateScanner)
    Slider("switchEnemyYards", "Pause with an enemy targeted within about (yards)", 0, 60,
        "Switching pauses while you target a living enemy this close, and for a second after you mouse over one. Distances are rough: the game doesn't give exact ones.",
        UpdateScanner, 1, Off)
    Checkbox("switchPauseStealth", "Pause while stealthed",
        "Switching pauses while you're stealthed.",
        UpdateScanner)
    Slider("switchNearYards", "Pause near a herb or ore (yards)", 0, 40,
        "Switching pauses this close to a herb or ore with a symbol, so you can walk up and gather it.",
        UpdateScanner, 1, Off)
    Slider("switchAfterCast", "Pause after your own spells (seconds)", 0, 10,
        "Switching pauses this long after your own spells end, and after you dismount, so the switch's global cooldown doesn't get in your way.",
        UpdateScanner, 1, Off)
    Header("Where")
    Checkbox("switchWorld", "Switch in the open world",
        "Switches while you're in the open world.",
        UpdateScanner)
    Checkbox("switchDungeons", "Switch in dungeons",
        "Switches while you're in a dungeon.",
        UpdateScanner)
    Checkbox("switchRaids", "Switch in raids",
        "Switches while you're in a raid.",
        UpdateScanner)
    Checkbox("switchBattlegrounds", "Switch in battlegrounds",
        "Switches while you're in a battleground.",
        UpdateScanner)
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
    local _, far = Checkbox("worldMark", "Far away sparkles (Beta)",
        "Sparkles on the herb or ore you face, from far away. Not perfect yet, and uses a lot more CPU. Takes over your map pin while on. Needs Sparkles on herbs or ore.",
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
