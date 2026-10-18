-- NodeSight's settings: the main page plus Symbols, Sparkles and Beta.

local _, ns = ...

local ipairs = ipairs

local defaults, SHAPES, world = ns.defaults, ns.SHAPES, ns.world
local UpdateScanner, ApplyDotScale = ns.UpdateScanner, ns.ApplyDotScale
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
        Settings.CreateCheckbox(category, Register(key, name, onChange), tooltip)
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
    local NEEDS = " While any sparkles are on, NodeSight turns on Enable Interact Key, the interact icons for objects and picking a target in every direction around you (Options > Controls and Accessibility), which the sparkles need, and hides the game's own icon and name. Turning all sparkles off puts your settings back as they were."
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
        "Scans the minimap for herbs and ore, for the arrow and the symbols. Turn it off to use only the sparkles: nothing is scanned then.",
        UpdateScanner)
    Checkbox("combatScan", "Scan in combat",
        "Keeps scanning the minimap during fights, so new herbs and ore still show up. With it off, the symbols you have stay during a fight and new ones show up after it. Needs Scan the minimap.",
        UpdateScanner)
    Checkbox("arrow", "Arrow to the nearest herb or ore",
        "An arrow near the top of the screen points to the nearest herb or ore on your minimap, with its name and distance. Needs Scan the minimap, and Find Herbs or Find Minerals on. Zoom the minimap out to see farther. Drag the arrow to move it.",
        UpdateScanner)
    Checkbox("mapIcons", "Herb and ore symbols on the minimap",
        "Puts the herb's or ore's map symbol on the minimap where the scan finds one. Needs Scan the minimap, and Find Herbs or Find Minerals on.",
        UpdateScanner)
    Checkbox("sound", "Sound when something new shows up",
        "Plays the minimap's ping sound when a herb, ore, chest, leyline or rare beast shows up on your minimap that wasn't there in the last minute. Not for a herb or ore above your skill. Needs Scan the minimap.",
        UpdateScanner)
    Checkbox("leylines", "Leylines on the minimap",
        "For High Order Skyborne. Symbols on leylines on your minimap while Read Leyline is ready. Needs Scan the minimap.",
        UpdateScanner)
    Checkbox("switchFinders", "Switch between herbs and ore",
        "Switches between Find Herbs and Find Minerals. You need both trained and one active to start.",
        UpdateScanner)
    Slider("switchYards", "Yards between switches", 10, 50,
        "How far you go before the other one is turned on. The default is " .. defaults.switchYards .. ". Needs Switch between herbs and ore.",
        UpdateScanner)

    Page("Symbols")
    Checkbox("hard", "Red symbols when your skill is too low",
        "A herb or ore you can't gather yet, because it needs more Herbalism or Mining skill than you have, has a red symbol. Needs Herb and ore symbols on the minimap.",
        UpdateScanner)
    Dropdown("shape", "Symbol shape", SHAPES,
        "The shape of the herb and ore symbols on the minimap: round with the game's gold ring around it, round without it, or square like the game's item icons. Needs Scan the minimap.",
        UpdateScanner)
    Checkbox("oreRings", "High visibility tin and iron",
        "Tin and iron look alike on the minimap. With this on, tin's symbol gets a green ring and iron's a rust one, in place of the gold ring. Needs Symbol shape at Round, gold ring.",
        UpdateScanner)
    Slider("iconSize", "Symbol size", 8, 24,
        "How big the herb and ore symbols on the minimap are. The default is " .. defaults.iconSize .. ". Needs Herb and ore symbols on the minimap.",
        UpdateScanner)
    Slider("dotScale", "Size of the game's own dots", 50, 300,
        "How big the game's own dots on the minimap are, in percent: 100 is the game's own size, which NodeSight leaves alone until you move this. Change it together with Symbol size to get the size you want.",
        ApplyDotScale)
    Slider("scanDetail", "Scan detail", 1, 3,
        "How closely the minimap is scanned for the arrow and the symbols. Needs Scan the minimap. Where the scan starts; after a few scans with no new herb it eases down by itself, and a new herb brings it back. 3: the most exact. 2 (the default): about a third fewer points, a scan every three quarters of a second. 1: about half the points, a scan every second; it uses the least CPU but can place herbs poorly.",
        UpdateScanner)

    Page("Sparkles")
    Checkbox("herbs", "Sparkles on herbs",
        "Sparkles around the nearest herb." .. NEEDS,
        SparklesChanged)
    Checkbox("ore", "Sparkles on ore",
        "Sparkles around the nearest ore (mining node)." .. NEEDS,
        SparklesChanged)
    Checkbox("others", "Sparkles on other objects",
        "Sparkles around the other objects the game puts an interact icon on (chests, quest objects, ...). Not mailboxes, or things you only use, like chairs and doors." .. NEEDS,
        SparklesChanged)
    ColorSwatch("sparkleColor", "Sparkle color",
        "The color the sparkles are tinted. Click the color to pick your own. White shows the sparkles in their own colors.",
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
    Checkbox("rares", "Rare beasts on the minimap (Beta)",
        "For hunters. Track Beasts shows every beast as the same dot: with this on, a rare beast's dot gets a rare symbol, and the arrow, if you have it on, points to the nearest one. Needs Scan the minimap, and Track Beasts on.",
        UpdateScanner)
    Dropdown("rareIcon", "Rare beast symbol", { "Rare icon", "Elite rare icon", "Star" },
        "Which of the game's own rare symbols a rare beast's dot gets. Needs Rare beasts on the minimap.",
        UpdateScanner)
    Checkbox("worldMark", "Sparkles on far away herbs and ore (Beta)",
        "Sparkles on the herb or ore you face, from far away. Does not work perfectly and uses a lot more CPU than with it off. It will be improved in further updates. Takes over your map pin while on. Needs Sparkles on herbs or ore.",
        world.Changed)

    Settings.RegisterAddOnCategory(main)
end

ns.RegisterSettings = RegisterSettings
