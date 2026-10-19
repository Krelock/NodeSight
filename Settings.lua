-- NodeSight's settings: the main page plus Arrow, Symbols, Sparkles and Beta.

local _, ns = ...

local ipairs = ipairs

local defaults, SHAPES, world = ns.defaults, ns.SHAPES, ns.world
local UpdateScanner, ApplyDotScale, ApplyArrowLock = ns.UpdateScanner, ns.ApplyDotScale, ns.ApplyArrowLock
local Setup, UpdateAll, ShowWhatsNew = ns.Setup, ns.UpdateAll, ns.ShowWhatsNew

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

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

    -- Blizzard's color swatch; clicking it opens the color picker.
    local function ColorSwatch(key, name, tooltip, onChange)
        Settings.CreateColorSwatch(category, Register(key, name, onChange), tooltip)
    end

    local function Dropdown(key, name, choices, tooltip, onChange)
        local function GetOptions()
            local container = Settings.CreateControlTextContainer()
            for value, label in ipairs(choices) do container:Add(value, label) end
            return container:GetData()
        end
        Settings.CreateDropdown(category, Register(key, name, onChange), GetOptions, tooltip)
    end

    -- Added to the sparkle checkboxes' tooltips.
    local NEEDS = " While any sparkles are on, NodeSight turns on Enable Interact Key, its icons for objects and targeting all around you (Options > Controls and Accessibility), and hides the game's own icon and name. Turning all sparkles off puts your settings back."
    local function SparklesChanged()
        UpdateAll()
        Setup()
    end

    -- What's New button, left of Blizzard's Defaults button and parented to it (so
    -- it hides during searches). Not shown with the gamepad UI.
    local list = SettingsPanel and SettingsPanel.Container and SettingsPanel.Container.SettingsList
    local defaultsButton = list and list.Header and list.Header.DefaultsButton
    if defaultsButton and C_InputInterfaceStyle.GetCurrentStyle() ~= Enum.InputDeviceInterfaceType.Gamepad then
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

    Page("Sparkles")
    Checkbox("herbs", "Sparkles on herbs",
        "Sparkles around the nearest herb." .. NEEDS,
        SparklesChanged)
    Checkbox("ore", "Sparkles on ore",
        "Sparkles around the nearest ore (mining node)." .. NEEDS,
        SparklesChanged)
    Checkbox("others", "Sparkles on other objects",
        "Sparkles around other objects with an interact icon, like chests and quest objects. Not mailboxes, chairs or doors." .. NEEDS,
        SparklesChanged)
    ColorSwatch("sparkleColor", "Sparkle color",
        "The sparkles' tint. White shows them in their own colors.",
        UpdateAll)
    -- Writes the saved color directly: going through the setting would run Blizzard's
    -- shared color row under our taint. Search tags off (false) for the same reason.
    layout:AddInitializer(CreateSettingsButtonInitializer("Reset the sparkle color", RESET, function()
        ns.db.sparkleColor = defaults.sparkleColor
        UpdateAll()
    end, "Resets sparkles back to their original color.", false))
    Slider("size", "Sparkle area", 30, 200,
        "How big the area around the herb or ore is that the sparkles twinkle in. The default is " .. defaults.size .. ".",
        UpdateAll)
    Slider("height", "Sparkle height", -100, 100,
        "Moves the sparkles up or down, if they sit above or below the herb or ore. The default is " .. defaults.height .. ".",
        UpdateAll)
    Slider("count", "Number of sparkles", 1, 20,
        "How many sparkles twinkle at once. The default is " .. defaults.count .. ".",
        UpdateAll)

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
