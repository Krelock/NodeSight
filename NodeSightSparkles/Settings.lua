-- NodeSight Sparkles' Options page: it opens the sparkle window, or has
-- Blizzard's own rows for the basics with the gamepad UI on.

local ADDON_NAME, ns = ...

local ipairs = ipairs

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
-- The gamepad UI sets it to 1 or 0 itself on every target change, and 1 works with a controller.
local function InteractOff()
    if GamepadUI() or ns.SetupPending() then return false end
    local any = false
    for _, kind in ipairs(ns.KINDS) do any = any or ns.db[kind] == true end
    local value = tonumber(C_CVar.GetCVar("softTargetInteract"))
    return any and value ~= nil and value < 2
end
ns.InteractOff = InteractOff
-- The Options page instead of the sparkle window (the minimap button's left click too).
function ns.OptionsOnly() return GamepadUI() or WindowFailed() end
ns.INTERACT_OFF = ("Sparkles need %s (%s > %s)."):format(ENABLE_INTERACT_TEXT, SETTINGS_TITLE, CONTROLS_LABEL)

-- nodeSightOn: NodeSight is loaded and this addon stays off, so the page only says so.
local function RegisterSettings(nodeSightOn)
    local category, layout = Settings.RegisterVerticalLayoutCategory("NodeSight Sparkles")
    ns.settingsCategory = category
    if nodeSightOn then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Off while NodeSight is on (it has the same sparkles)"))
        Settings.RegisterAddOnCategory(category)
        return
    end

    -- A setting saved in NodeSightSparklesCharDB[key], with its change callback.
    local function Register(key, name, onChange)
        local setting = Settings.RegisterAddOnSetting(category, "NodeSightSparkles_" .. key, key, ns.db,
            type(ns.defaults[key]), name, ns.defaults[key])
        setting:SetValueChangedCallback(onChange)
        return setting
    end

    local function Checkbox(key, name, tooltip, onChange)
        Settings.CreateCheckbox(category, Register(key, name, onChange), tooltip)
    end

    local function Slider(key, name, minValue, maxValue, tooltip, onChange)
        local options = Settings.CreateSliderOptions(minValue, maxValue, 1)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
        Settings.CreateSlider(category, Register(key, name, onChange), options, tooltip)
    end

    local function Dropdown(key, name, choices, tooltip, onChange)
        local function GetOptions()
            local container = Settings.CreateControlTextContainer()
            for value, label in ipairs(choices) do container:Add(value, label) end
            return container:GetData()
        end
        Settings.CreateDropdown(category, Register(key, name, onChange), GetOptions, tooltip)
    end

    -- All the settings are in the sparkle window, which opens with this page. A
    -- controller can't reach that window, and its color picker and menus would run
    -- Blizzard's gamepad code tainted, so with the gamepad UI on the page has
    -- Blizzard's own rows for the basics instead (until a reload, if it's switched).
    -- The same if the window failed to open.
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
            if shown == category then ns.ShowSparkleWindow() end
        end, category)
        Checkbox("popups", "Popups",
            "A popup when Enable Interact Key is turned off while sparkles are on. It waits until a fight is over. "
                .. "Off: none; the sparkle window still says so.",
            function() end)
    end
    Checkbox("minimapButton", "Minimap button",
        "NodeSight Sparkles' button on the minimap: left click opens the sparkle settings, right click turns all sparkles on or off.",
        function() ns.MinimapButtonChanged() end)

    Settings.RegisterAddOnCategory(category)
end

ns.RegisterSettings = RegisterSettings
