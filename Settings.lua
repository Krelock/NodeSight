-- NodeSight's settings: the main page plus Switch and Sparkles.
-- Sections: Settings panel.

local ADDON_NAME, ns = ...

local ipairs = ipairs

local defaults = ns.defaults
local UpdateSwitch = ns.UpdateSwitch
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

-- The sparkle settings are a page of Blizzard's rows instead of the window.
function ns.OptionsOnly() return GamepadUI() or WindowFailed() end

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
    ns.settingsCategory = main
    local category, pages = main, { [main] = true }
    local function Page(name)
        category, layout = Settings.RegisterVerticalLayoutSubcategory(main, name)
        pages[category] = true
    end

    -- A setting saved in NodeSightDB[key], with its change callback.
    local registered = {}
    local function Register(key, name, onChange)
        local setting = Settings.RegisterAddOnSetting(category, "NodeSight_" .. key, key, ns.db,
            type(defaults[key]), name, defaults[key])
        setting:SetValueChangedCallback(onChange)
        registered[key] = setting
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

    local function Slider(key, name, minValue, maxValue, tooltip, onChange, step, label)
        local options = Settings.CreateSliderOptions(minValue, maxValue, step or 1)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, label)
        local setting = Register(key, name, onChange)
        return setting, Settings.CreateSlider(category, setting, options, tooltip)
    end

    -- choices: the labels, in order.
    local function Dropdown(key, name, choices, tooltip, onChange)
        local function GetOptions()
            local container = Settings.CreateControlTextContainer()
            for value, label in ipairs(choices) do container:Add(value, label) end
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

    local findersTip = "Switches between Find Herbs and Find Minerals as you travel. You need both trained and one active to start."
    -- Toggling the switch also ends a stop after failed switches; other settings keep it.
    local finders = Checkbox("switchFinders", "Switch between herbs and ore", findersTip,
        function() SwitchReset() UpdateSwitch() Redraw() end)
    Checkbox("skillLine", "Required skill in tooltips",
        "Shows the skill a herb or ore needs in its tooltip when your mouse is on it in the world, and on herb and ore items.",
        function() end) -- (tooltips are built again each time they show)

    Checkbox("popups", "Popups",
        "NodeSight's popups: when Enable Interact Key is off, and when the game needs a restart after an update. "
            .. "They wait until a fight is over. Off: none at all.",
        function() end)
    Checkbox("minimapButton", "Minimap button",
        "NodeSight's button on the minimap: left click opens the sparkle settings, Shift left click these settings, right click turns all sparkles on or off, Shift right click switching between herbs and ore.",
        function() ns.MinimapButtonChanged() end)

    -- Saved on the character whichever settings are in use; they switch at the next reload.
    local own = Settings.RegisterAddOnSetting(category, "NodeSight_own", "own", NodeSightCharDB, "boolean",
        "Settings for this character only", true)
    own:SetValueChangedCallback(function() end)
    Settings.CreateCheckbox(category, own,
        "This character keeps its own NodeSight settings. Untick it to use the settings your other characters share. Changes at your next reload or login.")


    Page("Switch")
    local findersRow = Settings.CreateCheckbox(category, finders, findersTip) -- the same setting as on NodeSight's own page
    -- The rest of the page shows once Switch is on.
    local function SwitchOn() return ns.db.switchFinders end
    local function UnderSwitch(row) Indent(row, findersRow, SwitchOn) end
    UnderSwitch(Header("When"))
    -- The measure's change restarts the way and redraws the page, so only its slider shows.
    local measure = Dropdown("switchMeasure", "Measure distance in", ns.SWITCH_MEASURES,
        "How the distance between switches is measured: percent of what your minimap shows (it changes with the zoom), yards, or seconds on the move.",
        function()
            ns.SwitchMeasureChanged()
            UpdateSwitch()
            if SettingsInbound and SettingsInbound.RepairDisplay then pcall(SettingsInbound.RepairDisplay) end
        end)
    if measure and type(measure.AddShownPredicate) == "function" then measure:AddShownPredicate(SwitchOn) end
    -- A distance slider goes under the measure and shows only at its value, where the client can.
    local function Under(slider, value)
        if not slider then return end
        local function Chosen() return ns.db.switchMeasure == value end
        if measure and type(slider.SetParentInitializer) == "function" then
            slider:SetParentInitializer(measure, Chosen)
        end
        if type(slider.AddShownPredicate) == "function" then
            slider:AddShownPredicate(Chosen)
            slider:AddShownPredicate(SwitchOn)
        end
    end
    local percent, percentSlider = Slider("switchPercent", "Distance between switches", 20, 100,
        "How far you go between switches, in percent of what your minimap shows: farther when zoomed out or outdoors. The default is " .. defaults.switchPercent .. " %.",
        UpdateSwitch, 5, Percent)
    Under(percentSlider, 1)
    local yards, seconds = ns.SWITCH_RANGES.switchDistanceYards, ns.SWITCH_RANGES.switchSeconds
    local _, yardsSlider = Slider("switchDistanceYards", "Distance between switches (yards)", yards[1], yards[2],
        "How far you go between switches, in yards. The default is " .. defaults.switchDistanceYards .. ".",
        UpdateSwitch, yards[3])
    Under(yardsSlider, 2)
    local _, secondsSlider = Slider("switchSeconds", "Time between switches (seconds)", seconds[1], seconds[2],
        "How long you move between switches, in seconds. Time standing still doesn't count. The default is " .. defaults.switchSeconds .. ".",
        UpdateSwitch, seconds[3])
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
        UpdateSwitch)))
    UnderSwitch(Header("Pauses"))
    UnderSwitch(select(2, Checkbox("switchPauseBusy", "Pause while casting, looting or with a spell or item on the cursor",
        "Switching pauses while you cast, gather or loot, and while a spell waits for a target or something is on your cursor.",
        UpdateSwitch)))
    UnderSwitch(select(2, Slider("switchEnemyYards", "Pause with an enemy targeted within about (yards)", 0, 60,
        "Switching pauses while you target a living enemy this close, and for a second after you mouse over one. Distances are rough: the game doesn't give exact ones.",
        UpdateSwitch, 1, Off)))
    UnderSwitch(select(2, Checkbox("switchPauseStealth", "Pause while stealthed",
        "Switching pauses while you're stealthed.",
        UpdateSwitch)))
    UnderSwitch(select(2, Slider("switchAfterCast", "Pause after your own spells (seconds)", 0, 10,
        "Switching pauses this long after your own spells end, and after you dismount, so the switch's global cooldown doesn't get in your way.",
        UpdateSwitch, 1, Off)))
    UnderSwitch(Header("Where"))
    UnderSwitch(select(2, Checkbox("switchWorld", "Switch in the open world",
        "Switches while you're in the open world.",
        UpdateSwitch)))
    UnderSwitch(select(2, Checkbox("switchDungeons", "Switch in dungeons",
        "Switches while you're in a dungeon.",
        UpdateSwitch)))
    UnderSwitch(select(2, Checkbox("switchRaids", "Switch in raids",
        "Switches while you're in a raid.",
        UpdateSwitch)))
    UnderSwitch(select(2, Checkbox("switchBattlegrounds", "Switch in battlegrounds",
        "Switches while you're in a battleground.",
        UpdateSwitch)))
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
    ns.sparklesCategory = sparklesPage
    if GamepadUI() or WindowFailed() then
        local function SparklesChanged() ns.UpdateAll() ns.Setup() end
        local function LookChanged() ns.UpdateAll() end
        for _, tab in ipairs(ns.SPARKLE_TABS) do
            if tab.on then Checkbox(tab.key, tab.on, tab.tip .. ns.SPARKLE_NEEDS, SparklesChanged) end
        end
        Checkbox("gameIcons", "Keep the game's icons", "Keeps the game's own icon over things you can interact with.", SparklesChanged)
        Slider("brightness", "Brightness", 10, 100, "How bright the sparkles are.", LookChanged)
        Checkbox("reachLook", "Dimmer out of reach", "Dimmer when it's too far to gather. Flashes when you get in range.", LookChanged)
        Checkbox("combatHide", "Hide in combat", "No sparkles while you're in combat.", LookChanged)
        Checkbox("instanceHide", "Hide in instances", "No sparkles in dungeons and raids.", LookChanged)
        Checkbox("grayTooHard", "Gray when your skill is too low", "Herbs and ore your skill is too low for sparkle gray.", LookChanged)
        Checkbox("myProfessions", "Only for my professions",
            "Herbs sparkle only if you have Herbalism, ore only with Mining, and corpses only with Skinning.", LookChanged)
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

    Settings.RegisterAddOnCategory(main)
end

ns.RegisterSettings = RegisterSettings
