-- NodeSight's page in the game's Options: a button that opens NodeSight's own settings
-- window, or, where that window can't be used (the gamepad UI, or it failed to open),
-- Blizzard's own rows for every setting.
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

-- A window errored on opening in this version; a new version tries it again.
local function Failed(key)
    local version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
    if ns.db[key] ~= version then ns.db[key] = nil end
    return ns.db[key] ~= nil
end

-- Every setting is a row of Blizzard's in the options instead of the window.
function ns.OptionsOnly() return GamepadUI() or Failed("sparkleWindowFailed") end

-- Sparkles or the Cultivation icon are on, but Enable Interact Key is off (1 is gamepad
-- only), so objects get no plate.
local function InteractOff()
    if GamepadUI() or ns.SetupPending() or ns.InteractPaused() then return false end
    local any = ns.CultivationOn()
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

local TOWN_TIP = "Turns the game's Interact Key off while you're in a town or inn, so it doesn't pick the NPCs there. Nothing sparkles in town then."

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
        Settings.CreateCheckbox(category, setting, tooltip)
        return setting
    end

    local function Header(text)
        if CreateSettingsListSectionHeaderInitializer then
            layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
        end
    end

    local function Slider(key, name, minValue, maxValue, tooltip, onChange, step, label)
        local options = Settings.CreateSliderOptions(minValue, maxValue, step or 1)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, label)
        Settings.CreateSlider(category, Register(key, name, onChange), options, tooltip)
    end

    -- choices: the labels, in order.
    local function Dropdown(key, name, choices, tooltip, onChange)
        local function GetOptions()
            local container = Settings.CreateControlTextContainer()
            for value, label in ipairs(choices) do container:Add(value, label) end
            return container:GetData()
        end
        Settings.CreateDropdown(category, Register(key, name, onChange), GetOptions, tooltip)
    end

    -- Search tags off (false): addon code adding them taints the options' search.
    local function Button(text, onClick, tooltip)
        layout:AddInitializer(CreateSettingsButtonInitializer(text, "Open", onClick, tooltip, false))
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

    if not ns.OptionsOnly() then
        -- Everything is in NodeSight's window.
        Button("NodeSight settings", ns.ShowSettingsWindow, "All of NodeSight's settings, the sparkles' too.")
        return Settings.RegisterAddOnCategory(main)
    end
    do
        -- Blizzard's rows. Every row always shows: rows hidden or indented from addon code
        -- would taint the options list (its dropdowns are then blocked in combat).
        local findersTip = "Switches between Find Herbs and Find Minerals as you travel. You need both trained and one active to start."
        -- Toggling the switch also ends a stop after failed switches; other settings keep it.
        local finders = Checkbox("switchFinders", "Switch between herbs and ore", findersTip,
            function() SwitchReset() UpdateSwitch() end)
        Checkbox("skillLine", "Required skill in tooltips",
            "Shows the skill a herb or ore needs in its tooltip when your mouse is on it in the world, and on herb and ore items.",
            function() end) -- (tooltips are built again each time they show)
        Checkbox("popups", "Popups",
            "NodeSight's popups: when Enable Interact Key is off, and when the game needs a restart after an update. "
                .. "They wait until a fight is over. Off: none at all.",
            function() end)
        Checkbox("minimapButton", "Minimap button",
            "NodeSight's button on the minimap: left click opens the sparkle window, right click turns all sparkles on or off, Shift right click the Herb/Ore Switch. Shift left click says where these settings are.",
            function() ns.MinimapButtonChanged() end)
        -- Saved on the character whichever settings are in use; they switch at the next reload.
        local own = Settings.RegisterAddOnSetting(category, "NodeSight_own", "own", NodeSightCharDB, "boolean",
            "Settings for this character only", true)
        own:SetValueChangedCallback(function() ns.AskReload() end)
        Settings.CreateCheckbox(category, own,
            "This character keeps its own NodeSight settings. Untick it to use the settings your other characters share. It offers a reload to switch.")
        local town = Checkbox("townInteractOff", "Interact Key off in towns (Beta)", TOWN_TIP, function() ns.Setup() end)

        Page("Herb/Ore Switch")
        Settings.CreateCheckbox(category, finders, findersTip) -- the same setting as on NodeSight's own page
        Header("When")
        Dropdown("switchMeasure", "Measure distance in", ns.SWITCH_MEASURES,
            "How the distance between switches is measured: percent of what your minimap shows (it changes with the zoom), yards, or seconds on the move. Only the matching distance below is used.",
            function() ns.SwitchMeasureChanged() UpdateSwitch() end)
        Slider("switchPercent", "Distance between switches", 20, 100,
            "With % of the minimap: how far you go between switches, in percent of what your minimap shows. The default is " .. defaults.switchPercent .. " %.",
            UpdateSwitch, 5, Percent)
        local yards, seconds = ns.SWITCH_RANGES.switchDistanceYards, ns.SWITCH_RANGES.switchSeconds
        Slider("switchDistanceYards", "Distance between switches (yards)", yards[1], yards[2],
            "With Yards: how far you go between switches. The default is " .. defaults.switchDistanceYards .. ".",
            UpdateSwitch, yards[3])
        Slider("switchSeconds", "Time between switches (seconds)", seconds[1], seconds[2],
            "With Seconds: how long you move between switches. Time standing still doesn't count. The default is " .. defaults.switchSeconds .. ".",
            UpdateSwitch, seconds[3])
        Checkbox("switchMounted", "Only while mounted",
            "Switches only while you ride a mount. Travel Form and Ghost Wolf don't count.", UpdateSwitch)
        Header("Pauses")
        Checkbox("switchPauseBusy", "Pause while casting, looting or with a spell or item on the cursor",
            "Switching pauses while you cast, gather or loot, and while a spell waits for a target or something is on your cursor.",
            UpdateSwitch)
        Slider("switchEnemyYards", "Pause with an enemy targeted within about (yards)", 0, 60,
            "Switching pauses while you target a living enemy this close, and for a second after you mouse over one. Distances are rough: the game doesn't give exact ones.",
            UpdateSwitch, 1, Off)
        Checkbox("switchPauseStealth", "Pause while stealthed", "Switching pauses while you're stealthed.", UpdateSwitch)
        Slider("switchAfterCast", "Pause after your own spells (seconds)", 0, 10,
            "Switching pauses this long after your own spells end, and after you dismount, so the switch's global cooldown doesn't get in your way.",
            UpdateSwitch, 1, Off)
        Header("Where")
        Checkbox("switchWorld", "Switch in the open world", "Switches while you're in the open world.", UpdateSwitch)
        Checkbox("switchDungeons", "Switch in dungeons", "Switches while you're in a dungeon.", UpdateSwitch)
        Checkbox("switchRaids", "Switch in raids", "Switches while you're in a raid.", UpdateSwitch)
        Checkbox("switchBattlegrounds", "Switch in battlegrounds", "Switches while you're in a battleground.", UpdateSwitch)
        Header("Thanks to tester617 for the Switch page")

        Page("Collecting (Beta)")
        Checkbox("collect", "Remember where I gather",
            "Remembers each place you gather a herb or ore, on this computer only. Off: nothing new is remembered and the world map shows no marks; the places remembered are kept.",
            function() ns.UpdateCollect() end)
        Checkbox("collectMap", "Show them on the world map",
            "A small herb or ore icon on the world map for each place you gathered at. Put your mouse on one to see what it was.",
            function() ns.RefreshNodePins() end)
        Checkbox("collectMinimap", "Show them on the minimap",
            "The same symbols on the minimap for the places near you. They let the mouse through to the game's own dots.",
            function() ns.RefreshNodePins() end)
        local function MapChanged() ns.RefreshNodePins() end
        local size, opacity = ns.COLLECT_RANGES.collectSize, ns.COLLECT_RANGES.collectOpacity
        Dropdown("collectPicture", "Map symbols' picture", ns.COLLECT_PICTURES,
            "Each node's own item icon, or one plain icon for herbs and one for ore.", MapChanged)
        Dropdown("collectShape", "Map symbols' shape", ns.COLLECT_SHAPES, "The symbols' shape, on the world map and the minimap.", MapChanged)
        Slider("collectSize", "Map symbols' size", size[1], size[2], "How big the symbols are, on the world map and the minimap.", MapChanged, size[3])
        Slider("collectOpacity", "Minimap symbols' opacity (%)", opacity[1], opacity[2],
            "How much of a minimap symbol shows. Lower lets the game's dot under it show through. On the world map they're solid.", MapChanged, opacity[3])
        Dropdown("collectSkill", "Skill colors", ns.COLLECT_SKILL_LOOKS,
            "How a symbol shows your skill. Red when too low: red if you can't gather it yet. Colored ring and Colored gem: the profession window's skill-up colors, from red to gray. Colored ring needs a gold ring shape.",
            MapChanged)
        Checkbox("collectOreRings", "High visibility tin and iron",
            "Tin gets a green ring and iron a rust one, so they're easy to tell apart. Needs a gold ring shape.", MapChanged)
        layout:AddInitializer(CreateSettingsButtonInitializer("Remembered places", "Forget all", function() ns.AskForget() end,
            "Forgets every place NodeSight remembered, for all your characters. It asks first.", false))
        Header("Collecting is new and will be improved in future updates.")
        Header("Thanks to Urfoks for Collecting")

        -- The sparkles' basics. A controller can't reach the window, and its color picker and
        -- menus would run Blizzard's gamepad code tainted.
        Page("Sparkles")
        local function SparklesChanged() ns.UpdateAll() ns.Setup() end
        local function LookChanged() ns.UpdateAll() end
        local function CultivationChanged() SparklesChanged() ns.CultivationRefresh() end
        for _, tab in ipairs(ns.SPARKLE_TABS) do
            if tab.on then Checkbox(tab.key, tab.on, tab.tip .. ns.SPARKLE_NEEDS, SparklesChanged) end
        end
        Checkbox("gameIcons", "Keep the game's icons", "Keeps the game's own icon over things you can interact with.", SparklesChanged)
        Settings.CreateCheckbox(category, town, TOWN_TIP) -- the same setting as on the main page
        Slider("brightness", "Brightness", 10, 100, "How bright the sparkles are.", LookChanged)
        Checkbox("reachLook", "Dimmer out of reach", "Dimmer when it's too far to gather. Flashes when you get in range.", LookChanged)
        Checkbox("combatHide", "Hide in combat", "No sparkles while you're in combat.", LookChanged)
        Checkbox("instanceHide", "Hide in instances", "No sparkles in dungeons and raids.", LookChanged)
        Checkbox("grayTooHard", "Gray when your skill is too low", "Herbs and ore your skill is too low for sparkle gray.", LookChanged)
        Checkbox("myProfessions", "Only for my professions",
            "Herbs sparkle only if you have Herbalism, ore only with Mining, and corpses only with Skinning.", LookChanged)
        Checkbox("cultivation", "Show when Cultivation is ready",
            "Tauren: the Cultivation icon over a herb you can cultivate now. Works without herb sparkles and without Herbalism. Like sparkles, it turns on the game's Interact Key.",
            CultivationChanged)
        Checkbox("rareGlow", "Rare nodes stand out", "A gold glow on rare herbs and ore like Black Lotus and Truesilver.", LookChanged)
        Checkbox("sparkleSound", "Sparkle sound", "Plays a soft sound when something near you starts sparkling.", LookChanged)
        Checkbox("gatherDim", "Dim while gathering", "Sparkles fade while you gather so you can see the node.", LookChanged)
        local finishes = {}
        for i, finish in ipairs(ns.HARVESTS) do finishes[i] = finish.name end
        Dropdown("harvest", "When gathered", finishes, "What the sparkles do when you loot it.", LookChanged)
    end

    Settings.RegisterAddOnCategory(main)
end

ns.RegisterSettings = RegisterSettings
