-- NodeSight's settings: the main page plus Arrow, Symbols, Sparkles and Beta.

local ADDON_NAME, ns = ...

local ipairs = ipairs

local defaults, SHAPES, world = ns.defaults, ns.SHAPES, ns.world
local UpdateScanner, ApplyDotScale, ApplyArrowLock = ns.UpdateScanner, ns.ApplyDotScale, ns.ApplyArrowLock
local ApplyArrowSize = ns.ApplyArrowSize
local ShowWhatsNew = ns.ShowWhatsNew

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
    end

    Checkbox("scan", "Scan the minimap",
        "Scans the minimap for herbs and ore, for the arrow and the symbols. Turn it off to use only the sparkles.",
        UpdateScanner)
    Checkbox("combatScan", "Scan in combat",
        "Keeps scanning during fights, so new herbs and ore still show up. With it off, new ones show up after the fight. Needs Scan the minimap.",
        UpdateScanner)
    local arrowTip = "An arrow near the top of the screen points to the nearest herb or ore on your minimap, with its name and distance. Drag it to move it. Needs Scan the minimap."
    local arrow = Checkbox("arrow", "Arrow to the nearest herb or ore", arrowTip, UpdateScanner)
    Checkbox("mapIcons", "Herb and ore symbols",
        "Puts the herb's or ore's map symbol on the minimap where the scan finds one. Needs Scan the minimap, and Find Herbs or Find Minerals on.",
        UpdateScanner)
    Checkbox("sound", "Sound for new finds",
        "Plays the minimap's ping sound when something new shows up on your minimap, not seen in the last minute. Not for a herb or ore above your skill. Needs Scan the minimap.",
        UpdateScanner)
    Checkbox("switchFinders", "Switch between herbs and ore",
        "Switches between Find Herbs and Find Minerals. You need both trained and one active to start.",
        UpdateScanner)
    Slider("switchYards", "Yards between switches", 10, 50,
        "How far you go before the other one is turned on. The default is " .. defaults.switchYards .. ". Needs Switch between herbs and ore.",
        UpdateScanner)

    Page("Arrow")
    Settings.CreateCheckbox(category, arrow, arrowTip) -- the same setting as on NodeSight's own page
    Checkbox("arrowLocked", "Lock the arrow in place",
        "The arrow can't be dragged, and your clicks go through it to the world. Needs Arrow to the nearest herb or ore.",
        ApplyArrowLock)
    Checkbox("arrowSkip", "Skip the node you're at",
        "The arrow passes over a node within 5 yards of you and points to the next one. Needs Arrow to the nearest herb or ore.",
        UpdateScanner)
    Checkbox("arrowFirst", "Herbs and ore first",
        "The arrow points to a chest, rare, leyline or convergence only when no herb or ore is in sight. Needs Arrow to the nearest herb or ore.",
        UpdateScanner)
    Checkbox("arrowHerbs", "Herbs", "The arrow points to herbs. Needs Arrow to the nearest herb or ore.", UpdateScanner)
    Checkbox("arrowOre", "Ore", "The arrow points to ore. Needs Arrow to the nearest herb or ore.", UpdateScanner)
    Checkbox("arrowChests", "Chests", "The arrow points to treasure chests (Find Treasure). Needs Arrow to the nearest herb or ore.", UpdateScanner)
    Checkbox("arrowRares", "Rares",
        "The arrow points to rare beasts and humanoids. Needs Arrow to the nearest herb or ore, and Rares on the minimap (Beta).",
        UpdateScanner)
    Checkbox("arrowLeylines", "Leylines and convergences",
        "The arrow points to leylines and elemental convergences. Needs Arrow to the nearest herb or ore, and Leylines and convergences.",
        UpdateScanner)
    Slider("arrowSize", "Arrow size", 20, 100,
        "How big the arrow is. The default is " .. defaults.arrowSize .. ". Needs Arrow to the nearest herb or ore.",
        ApplyArrowSize)

    Page("Symbols")
    Checkbox("hard", "Red symbols when too low",
        "A herb or ore you don't have the skill for yet has a red symbol. Needs Herb and ore symbols.",
        UpdateScanner)
    Checkbox("clearNear", "See-through near you",
        "A symbol over your own arrow on the minimap is see-through, so you still see which way you face. Needs Herb and ore symbols.",
        UpdateScanner)
    Checkbox("leylines", "Leylines and convergences",
        "High Order Skyborne get symbols on leylines while Read Leyline is ready, Windshaper Skyborne on elemental convergences while Skysight is ready. Needs Scan the minimap.",
        UpdateScanner)
    Dropdown("shape", "Symbol shape", SHAPES,
        "The shape of the herb and ore symbols on the minimap. Needs Scan the minimap.",
        UpdateScanner)
    Checkbox("oreRings", "High visibility tin and iron",
        "Tin and iron look alike on the minimap: with this on, tin gets a green ring and iron a rust one. Needs Symbol shape at Round, gold ring or Round, slim gold ring.",
        UpdateScanner)
    Slider("iconSize", "Symbol size", 8, 24,
        "How big the herb and ore symbols on the minimap are. The default is " .. defaults.iconSize .. ". Needs Herb and ore symbols.",
        UpdateScanner)
    Slider("dotScale", "Size of the game's own dots", 50, 300,
        "How big the game's own dots on the minimap are, in percent: 100 is the game's own size, which NodeSight leaves alone until you move this. Change it together with Symbol size to get the size you want.",
        ApplyDotScale)
    Slider("scanDetail", "Scan detail", 1, 3,
        "How closely the minimap is scanned: 3 is the most exact, 1 uses the least CPU but can place herbs poorly. The default is " .. defaults.scanDetail .. ". Needs Scan the minimap.",
        UpdateScanner)

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
    Checkbox("rares", "Rares on the minimap (Beta)",
        "For hunters and druids: a rare beast's or humanoid's dot gets a rare symbol. Needs Scan the minimap, and Track Beasts or Track Humanoids on.",
        UpdateScanner)
    Dropdown("rareIcon", "Rare symbol", { "Rare icon", "Elite rare icon", "Star" },
        "Which of the game's own rare symbols a rare beast's or humanoid's dot gets. Needs Rares on the minimap.",
        UpdateScanner)
    Checkbox("worldMark", "Far away sparkles (Beta)",
        "Sparkles on the herb or ore you face, from far away. Not perfect yet, and uses a lot more CPU. Takes over your map pin while on. Needs Sparkles on herbs or ore.",
        world.Changed)

    Settings.RegisterAddOnCategory(main)
end

ns.RegisterSettings = RegisterSettings
