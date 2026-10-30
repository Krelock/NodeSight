-- NodeSight's sparkle window: a tab for each kind of node and one for the
-- settings of all of them, the styles as tiles with a small preview each, the
-- look's settings, and the node in 3D with its sparkles on it, as in the world.
--
-- Sections: Nodes to preview, Changing the look, Building the window, Showing a tab.

local ADDON_NAME, ns = ...

local ipairs, floor, format = ipairs, math.floor, string.format
local GENERAL_LABEL = GENERAL -- Blizzard's word, before the name is used for the keys below
local sqrt, sin, cos, tan, max = math.sqrt, math.sin, math.cos, math.tan, math.max

---------------------------------------------------------------------------
-- Nodes to preview
---------------------------------------------------------------------------
-- Name and model file (world/skillactivated/..., and world/goober/..., the game's objects you click).

local NODES = {
    herbs = {
        { "Peacebloom", 219481 }, { "Silverleaf", 219487, 0.55 }, { "Bruiseweed", 219440 },
        { "Stranglekelp", 219495 }, { "Black Lotus", 219437 },
    },
    ore = {
        { "Copper Vein", 219514 }, { "Tin Vein", 219568 }, { "Iron Deposit", 219532 }, { "Gold Vein", 219524 },
        { "Mithril Deposit", 219541 }, { "Truesilver Deposit", 219569 }, { "Small Thorium Vein", 219566 },
    },
    chests = { { "Battered Chest", 219372 } },
    quests = {
        { "Supply Crate", 200960 }, { "Barrel", 200884 }, { "Scroll", 201113 }, { "Spider Egg Sac", 200974 },
        { "Keg", 201058 }, { "Pumpkin", 201088 },
    },
    others = {
        { "Book", 200912 }, { "Meeting Stone", 197022 }, { "Lever", 201061 }, { "Gong", 201029 }, { "Brazier", 200925 },
    },
    bobber = { { "Fishing Bobber", 201000 } },
}

-- The camera looks down a little, as you see a node on the ground, and the
-- node fills this much of the preview.
local PITCH, FOV, FILL = 0.35, 0.6, 0.7
local ZOOM_IN, ZOOM_START, ZOOM_OUT = 0.4, 1.6, 2.2 -- times that distance

-- Color sets, from the game's own colors (item qualities, class colors, gold text).
local SETS = {
    { "Gold and white", "ffffd100", "ffffffff" },
    { "Nature", "ff1eff00", "ffffd100" },
    { "Arcane", "ffa335ee", "ff69ccf0" },
    { "Frost", "ff69ccf0", "ffffffff" },
    { "Fire", "ffff8000", "ffffd100" },
    { "Shadow", "ff8788ee", "ffa335ee" },
    { "Holy", "fff58cba", "ffffd100" },
    { "Blood", "ffc41f3b", "ffff8000" },
}

-- Settings for all sparkles (the General tab), saved under these keys.
local GENERAL = { gameIcons = true, brightness = true, reachLook = true, combatHide = true, instanceHide = true,
    harvest = true, grayTooHard = true, rareGlow = true, sparkleSound = true, gatherDim = true }

-- The tabs: each kind (its name, the "Sparkles on" box and the icon), then General.
local TABS = {
    { key = "herbs", name = "Herbs", on = "Sparkles on herbs", icon = "Interface\\Icons\\INV_Misc_Herb_01",
        tip = "Sparkles on the herb in front of you." },
    { key = "ore", name = "Ore", on = "Sparkles on ore", icon = "Interface\\Icons\\INV_Ore_Copper_01",
        tip = "Sparkles on the ore in front of you." },
    { key = "chests", name = "Chests", on = "Sparkles on chests", icon = "Interface\\Icons\\INV_Box_01",
        tip = "Sparkles on chests, footlockers and other treasure." },
    { key = "quests", name = "Quest objects", on = "Sparkles on quest objects", icon = "Interface\\Icons\\INV_Misc_Note_01",
        tip = "Sparkles on things you need for a quest." },
    { key = "others", name = "Other objects", on = "Sparkles on other objects", icon = "Interface\\Icons\\INV_Box_02",
        tip = "Sparkles on anything else you can use. Not mailboxes, chairs or doors." },
    { key = "bobber", name = "Fishing bobber", on = "Sparkles on your fishing bobber (Beta)", icon = "Interface\\Icons\\Trade_Fishing",
        tip = "Sparkles on your bobber so it's easier to spot. Not tested in game yet." },
    { key = "general", name = GENERAL_LABEL, icon = "Interface\\Icons\\INV_Misc_Gear_01" },
}
-- Added to the on/off box's tooltip.
local NEEDS = " Sparkles turn on the game's Interact Key. Turn them all off and your settings go back."

local window -- made the first time it opens

---------------------------------------------------------------------------
-- Changing the look
---------------------------------------------------------------------------

-- The kinds the shown tab changes, and the one whose look it shows (All shows the herbs').
local function Kinds()
    return { window.tab.key }
end
local function Shown() return window.tab.key == "general" and "herbs" or window.tab.key end

local function Hex(r, g, b)
    return format("ff%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

local Refresh, FrameNode, PlaceCamera, PickStyle, PlayHarvest

-- The sparkles in the world, near and far, after a change.
local function Changed()
    ns.UpdateAll()
    ns.RefreshFarSparkles()
end

-- Each kind keeps every style's look as it was last left (NodeSightDB.styleLooks[kind][style]),
-- so a style picked again comes back with its changes.
local LOOK = { "size", "height", "count", "color", "color2" }
local IN_LOOK = { size = true, height = true, count = true, color = true, color2 = true }
local function Remember(kind)
    local keys, looks = ns.SPARKLE_KEYS[kind], ns.db.styleLooks
    local look = {}
    for _, what in ipairs(LOOK) do look[what] = ns.db[keys[what]] end
    looks[kind] = looks[kind] or {}
    looks[kind][ns.db[keys.style]] = look
end

-- Style i's look for a kind: as it was left, or the one it comes with (the bobber floats
-- on the water: every style starts at height 0 on it).
local function LookOf(kind, i)
    local look = ns.db.styleLooks[kind] and ns.db.styleLooks[kind][i]
    if type(look) == "table" and type(look.size) == "number" and type(look.height) == "number" and type(look.count) == "number"
        and tostring(look.color):match("^%x%x%x%x%x%x%x%x$") and (look.color2 == nil or tostring(look.color2):match("^%x%x%x%x%x%x%x%x$")) then
        return look
    end
    local start = ns.SPARKLE_STYLES[i].start
    return { size = start.size, height = kind == "bobber" and 0 or start.height, count = start.count, color = start.color, color2 = start.color2 }
end

-- Sets a part of the look (or "on") for the tab's kinds, then the sparkles and the window.
-- "everything": sparkles on or off for every kind.
local function Set(what, value)
    if GENERAL[what] then
        ns.db[what] = value
        Changed()
        if what == "gameIcons" then ns.Setup() end
        return Refresh()
    end
    local kinds = what == "everything" and ns.KINDS or Kinds()
    for _, kind in ipairs(kinds) do
        if what == "on" or what == "everything" then
            ns.db[kind] = value
        else
            ns.db[ns.SPARKLE_KEYS[kind][what]] = value
            if IN_LOOK[what] then Remember(kind) end
        end
    end
    Changed()
    if what == "on" or what == "everything" then ns.Setup() end
    Refresh()
end

-- A style, with its look as it was left, for the tab's kinds.
function PickStyle(i)
    for _, kind in ipairs(Kinds()) do
        local keys, look = ns.SPARKLE_KEYS[kind], LookOf(kind, i)
        ns.db[keys.style] = i
        for _, what in ipairs(LOOK) do ns.db[keys[what]] = look[what] end
    end
    Changed()
    Refresh()
end

-- Both colors at once (a set, Reset); nil for the second: the same as the first.
local function SetColors(one, two)
    for _, kind in ipairs(Kinds()) do
        local keys = ns.SPARKLE_KEYS[kind]
        ns.db[keys.color], ns.db[keys.color2] = one, two
        Remember(kind)
    end
    Changed()
    Refresh()
end

-- what: "color" or "color2". Cancel puts back each kind's colors from before. The picker
-- calls swatchFunc as it opens and on Okay too: nothing is saved until the color moves.
local function PickColor(what)
    local one, two = ns.SparkleLook(Shown(), "color"), ns.SparkleLook(Shown(), "color2")
    local r, g, b = ns.SparkleRGB(what == "color2" and (two or one) or one)
    local kinds, before, start, moved = Kinds(), {}, Hex(r, g, b), false
    for i, kind in ipairs(kinds) do before[i] = { ns.SparkleLook(kind, "color"), ns.SparkleLook(kind, "color2") } end
    ColorPickerFrame:SetupColorPickerAndShow({ r = r, g = g, b = b, hasOpacity = false,
        swatchFunc = function()
            local hex = Hex(ColorPickerFrame:GetColorRGB())
            if hex == start and not moved then return end
            moved = true
            Set(what, hex)
        end,
        cancelFunc = function()
            for i, kind in ipairs(kinds) do
                local keys = ns.SPARKLE_KEYS[kind]
                ns.db[keys.color], ns.db[keys.color2] = before[i][1], before[i][2]
                Remember(kind)
            end
            Changed()
            Refresh()
        end })
end

---------------------------------------------------------------------------
-- Building the window
---------------------------------------------------------------------------
-- Frames are made with no parent, then SetParent (see NewSparkles in Sparkles.lua).

local function New(kind, parent, template)
    local frame = CreateFrame(kind, nil, nil, template)
    frame:SetParent(parent)
    return frame
end

local function Label(parent, text, font)
    local label = parent:CreateFontString(nil, "ARTWORK", font or "GameFontNormal")
    label:SetText(text)
    return label
end

-- title and text can be functions (for the tab's own words). Hooked, so a Blizzard
-- template keeps its own hover look.
local function Tooltip(frame, title, text)
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(type(title) == "function" and title() or title)
        local body = type(text) == "function" and text() or text
        if body then GameTooltip:AddLine(body, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- An Options-style row: a gold label at the left, its control COLUMN to the right
-- (room for the labels). Its tooltip shows over the
-- label too, as on Blizzard's rows.
local COLUMN = 150
local function Row(panel, y, text, control, tip)
    local label = Label(panel, text)
    label:SetPoint("LEFT", panel, "TOPLEFT", 0, y)
    control:SetPoint("LEFT", panel, "TOPLEFT", COLUMN, y)
    if tip then
        Tooltip(control, text, tip)
        local hover = New("Frame", panel)
        hover:SetPoint("LEFT", panel, "TOPLEFT", 0, y)
        hover:SetSize(COLUMN - 4, 26)
        hover:EnableMouse(true)
        Tooltip(hover, text, tip)
    end
    return label
end

local function Checkbox(panel, y, text, what, tip)
    local box = New("CheckButton", panel, "MinimalCheckboxTemplate")
    box:SetScript("OnClick", function(self)
        PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        Set(what, self:GetChecked())
    end)
    box.label = Row(panel, y, text, box, tip)
    return box
end

-- The look a style comes with (its tile gives it back); the bobber's height is 0.
local function StyleStart(kind, what)
    local style = ns.SPARKLE_STYLES[ns.SparkleLook(kind, "style")] or ns.SPARKLE_STYLES[1]
    if kind == "bobber" and what == "height" then return 0 end
    return style.start[what]
end

-- withDefault: the tooltip also says what the shown style comes with.
local function Slider(panel, y, text, what, low, high, tip, withDefault)
    local slider = New("Frame", panel, "MinimalSliderWithSteppersTemplate")
    slider:SetWidth(230)
    local formatters = { [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right) }
    slider:Init(low, low, high, high - low, formatters)
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        if not window.refreshing then Set(what, floor(value + 0.5)) end
    end, slider)
    local words = tip
    if withDefault then
        words = function() return ("%s\n\n%s: %d"):format(tip, DEFAULT, StyleStart(Shown(), what)) end
    end
    Row(panel, y, text, slider, words)
    -- The bar and its arrows take the mouse themselves.
    for _, part in ipairs({ slider.Slider, slider.Back, slider.Forward }) do Tooltip(part, text, words) end
    return slider
end

-- A style's tile: its name and a small preview of it; a click picks it.
local function Tile(grid, i, style)
    local tile = New("Button", grid)
    tile:SetSize(81, 76) -- five across, as the Toy Box's (Refresh places it)
    tile:SetClipsChildren(true) -- a light beam stays inside
    local background = tile:CreateTexture(nil, "BACKGROUND")
    background:SetAtlas("collections-background-tile")
    background:SetAllPoints()
    tile.border = tile:CreateTexture(nil, "BORDER")
    tile.border:SetAllPoints()
    local highlight = tile:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAtlas("PetList-ButtonHighlight")
    highlight:SetAllPoints()
    tile.name = Label(tile, style.name, "GameFontNormalSmall")
    tile.name:SetPoint("BOTTOM", 0, 8)
    tile.anchor = New("Frame", tile) -- the sparkles sit on its bottom, like on a nameplate's
    tile.anchor:SetSize(1, 1)
    tile.anchor:SetPoint("BOTTOM", tile, "CENTER", 0, 10)
    tile:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        PickStyle(i)
    end)
    Tooltip(tile, style.name, style.tip)
    return tile
end

local function Build()
    -- The style grid is as tall as the biggest tab's styles need, five a row.
    local most = 0
    for _, tab in ipairs(TABS) do
        local n = 0
        for i in ipairs(ns.SPARKLE_STYLES) do
            if ns.StyleFits(i, tab.key) then n = n + 1 end
        end
        most = max(most, n)
    end
    local gridHeight = floor((most + 4) / 5) * 80 - 4
    window = New("Frame", UIParent, "ButtonFrameTemplate")
    window:Hide()
    window:SetSize(760, 366 + gridHeight)
    window:SetPoint("CENTER", 0, 20)
    window:SetFrameStrata("DIALOG")
    window:SetToplevel(true)
    window:EnableMouse(true)
    window:SetTitle("NodeSight Sparkles")
    ButtonFrameTemplate_HideButtonBar(window)
    window.CloseButton:SetScript("OnClick", function() window:Hide() end)
    -- (The previews hide with it, and their frames only run while shown.)
    window:SetScript("OnShow", function() PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN) end)
    window:SetScript("OnHide", function() PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE) end)
    window.tab, window.node = TABS[1], {}

    -- The preview: the node turning slowly on Blizzard's mount journal background.
    local preview = New("Frame", window.Inset)
    preview:SetPoint("TOPLEFT", 8, -8)
    preview:SetPoint("BOTTOMLEFT", 8, 8)
    preview:SetWidth(280)
    preview:SetClipsChildren(true)
    local background = preview:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\PetBattles\\MountJournal-BG")
    background:SetTexCoord(2 / 512, 0.78515625, 2 / 512, 510 / 512) -- the picture's left corners are white
    background:SetAllPoints()
    local scene = New("ModelScene", preview)
    scene:SetAllPoints()
    scene:SetCameraFieldOfView(FOV)
    scene:SetCameraOrientationByYawPitchRoll(math.pi, PITCH, 0)
    scene:SetLightVisible(true)
    scene:SetLightType(Enum.ModelLightType.Directional)
    scene:SetLightDirection(scene:GetCameraForward())
    scene:SetLightAmbientColor(0.7, 0.7, 0.7)
    scene:SetLightDiffuseColor(0.8, 0.8, 0.8)
    local actor = scene:CreateActor()
    actor:SetUseCenterForOrigin(true, true, true) -- turns on the spot, its middle in the middle
    -- Drag it round to turn it; the mouse wheel zooms. Both stay as you left them.
    scene.yaw, scene.zoom = 0, ZOOM_START
    scene:EnableMouse(true)
    scene:EnableMouseWheel(true)
    scene:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then self.dragging = GetCursorPosition() end
    end)
    scene:SetScript("OnMouseUp", function(self) self.dragging = nil end)
    scene:SetScript("OnHide", function(self) self.dragging = nil end)
    scene:SetScript("OnMouseWheel", function(self, delta)
        self.zoom = math.min(ZOOM_OUT, max(ZOOM_IN, self.zoom - delta * 0.1))
        if self.framed then PlaceCamera(self) end
    end)
    scene:SetScript("OnUpdate", function(self)
        if self.dragging then
            local x = GetCursorPosition()
            self.yaw = self.yaw + (x - self.dragging) * 0.01
            self.dragging = x
            actor:SetYaw(self.yaw)
        end
        if not self.framed and actor:IsLoaded() then self.framed = FrameNode(self, actor) end
    end)
    window.scene, window.actor = scene, actor
    -- The sparkles grow and shrink with the zoom, around the node's middle.
    scene.zoomer = New("Frame", scene)
    scene.zoomer:SetSize(1, 1)
    scene.zoomer:SetPoint("CENTER", preview, "CENTER")
    window.anchor = New("Frame", scene.zoomer) -- sparkles 60 under it with the default height: on the node
    window.anchor:SetSize(1, 1)
    window.anchor:SetPoint("BOTTOM", scene.zoomer, "CENTER", 0, 60)
    local picker = New("Frame", preview, "SettingsDropdownWithButtonsTemplate")
    picker:SetWidth(260)
    picker.Dropdown:SetWidth(210)
    picker:SetPoint("TOP", 0, -6)
    picker:SetFrameLevel(scene:GetFrameLevel() + 10) -- over the model, which takes the mouse
    window.picker = picker

    -- The styles.
    local grid = New("Frame", window.Inset)
    grid:SetPoint("TOPLEFT", preview, "TOPRIGHT", 10, 0)
    grid:SetSize(428, gridHeight)
    window.tiles = {}
    for i, style in ipairs(ns.SPARKLE_STYLES) do window.tiles[i] = Tile(grid, i, style) end

    -- The rest of the look.
    local panel = New("Frame", window.Inset)
    panel:SetPoint("TOPLEFT", grid, "BOTTOMLEFT", 0, -26)
    panel:SetPoint("BOTTOMRIGHT", -8, 8)
    window.on = Checkbox(panel, 0, "", "on")
    window.on:SetPoint("LEFT", panel, "TOPLEFT", -4, 0) -- the box first: the kinds' names are long
    window.on.label:ClearAllPoints()
    window.on.label:SetPoint("LEFT", window.on, "RIGHT", 4, 0)
    Tooltip(window.on, function() return window.tab.on end, function() return window.tab.tip .. NEEDS end)
    local swatch = New("Button", panel, "ColorSwatchTemplate")
    swatch:SetSize(22, 22)
    swatch:SetScript("OnClick", function() PickColor("color") end)
    Row(panel, -36, COLOR, swatch, "Tints the sparkles. White keeps their own colors.")
    window.swatch = swatch
    local swatch2 = New("Button", panel, "ColorSwatchTemplate")
    swatch2:SetSize(22, 22)
    swatch2:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
    swatch2:SetScript("OnClick", function() PickColor("color2") end)
    Tooltip(swatch2, "Second color", "Sparkles switch between the two colors. Same as the first until you pick one.")
    window.swatch2 = swatch2
    local reset = New("Button", panel, "UIPanelButtonTemplate")
    reset:SetSize(80, 22)
    reset:SetText(RESET)
    reset:SetPoint("LEFT", swatch2, "RIGHT", 12, 0)
    reset:SetScript("OnClick", function()
        for _, kind in ipairs(Kinds()) do
            local keys = ns.SPARKLE_KEYS[kind]
            local start = (ns.SPARKLE_STYLES[ns.db[keys.style]] or ns.SPARKLE_STYLES[1]).start
            ns.db[keys.color], ns.db[keys.color2] = start.color, start.color2
            Remember(kind)
        end
        Changed()
        Refresh()
    end)
    Tooltip(reset, RESET, "Back to the style's own colors.")
    window.reset = reset
    local sets = New("DropdownButton", panel, "WowStyle1DropdownTemplate")
    sets:SetWidth(180)
    sets:SetDefaultText(CUSTOM)
    Row(panel, -72, "Color set", sets, "Two colors that go well together.")
    window.sets = sets
    window.size = Slider(panel, -108, "Area", "size", 30, 200, "How far around the node the sparkles go.", true)
    window.height = Slider(panel, -146, "Height", "height", -100, 100, "Moves the sparkles up or down.", true)
    window.count = Slider(panel, -184, "Count", "count", 1, 20,
        "How many sparkles show at once. Some styles don't use it.", true)
    window.beta = Label(panel, "Beta: not tested in game yet.", "GameFontDisableSmall")
    window.beta:SetPoint("BOTTOMLEFT", 0, 4)

    -- The General tab: settings for all sparkles.
    window.look = { grid, panel }
    local general = New("Frame", window.Inset)
    general:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, -14)
    general:SetPoint("BOTTOMRIGHT", -8, 8)
    window.general = general
    local function BoxFirst(box) -- long names: the box first, its words after it
        box:SetPoint("LEFT", general, "TOPLEFT", -4, select(5, box:GetPoint(1)))
        box.label:ClearAllPoints()
        box.label:SetPoint("LEFT", box, "RIGHT", 4, 0)
        box:SetFrameLevel(box:GetFrameLevel() + 1) -- over its row's tooltip area, so all of it takes the click
        return box
    end
    window.everything = BoxFirst(Checkbox(general, 0, "Sparkles on everything", "everything",
        "Turns them all on or off at once. Each tab has its own box too." .. NEEDS))
    window.gameIcons = BoxFirst(Checkbox(general, -36, "Keep the game's icons", "gameIcons",
        "Keeps the game's own icon over things you can interact with."))
    window.brightness = Slider(general, -76, "Brightness", "brightness", 10, 100,
        "How bright the sparkles are.")
    window.reachLook = BoxFirst(Checkbox(general, -116, "Dimmer out of reach", "reachLook",
        "Dimmer when it's too far to gather. Flashes when you get in range."))
    window.combatHide = BoxFirst(Checkbox(general, -152, "Hide in combat", "combatHide",
        "No sparkles while you're in combat."))
    window.instanceHide = BoxFirst(Checkbox(general, -188, "Hide in instances", "instanceHide",
        "No sparkles in dungeons and raids."))
    window.grayTooHard = BoxFirst(Checkbox(general, -224, "Gray when your skill is too low", "grayTooHard",
        "Herbs and ore your skill is too low for sparkle gray."))
    window.rareGlow = BoxFirst(Checkbox(general, -260, "Rare nodes stand out", "rareGlow",
        "A gold glow on rare herbs and ore like Black Lotus and Truesilver."))
    window.sparkleSound = BoxFirst(Checkbox(general, -296, "Sparkle sound", "sparkleSound",
        "Plays a soft sound when something near you starts sparkling."))
    window.gatherDim = BoxFirst(Checkbox(general, -332, "Dim while gathering", "gatherDim",
        "Sparkles fade while you gather so you can see the node."))
    local harvest = New("DropdownButton", general, "WowStyle1DropdownTemplate")
    harvest:SetWidth(180)
    Row(general, -372, "When gathered", harvest,
        "What the sparkles do when you loot it. Picking one plays it on the preview.")
    window.harvest = harvest
    local show = New("Button", general, "UIPanelButtonTemplate")
    show:SetSize(90, 22)
    show:SetText(PREVIEW)
    show:SetPoint("LEFT", harvest, "RIGHT", 8, 0)
    show:SetScript("OnClick", function() PlayHarvest() end)
    Tooltip(show, PREVIEW, "Plays it on the preview.")
    window.showHarvest = show

    -- The tabs along the bottom, as on Forever's friends list.
    window.Tabs = {}
    for i, tab in ipairs(TABS) do
        tab.index = i
        local button = New("Button", window, "PanelTabButtonTemplate")
        button:SetID(i)
        button:SetText(tab.name)
        if i == 1 then button:SetPoint("TOPLEFT", window, "BOTTOMLEFT", 11, 2) end
        button:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            window.tab = tab
            Refresh()
        end)
        window.Tabs[i] = button
        PanelTemplates_TabResize(button, 0)
    end
    PanelTemplates_SetNumTabs(window, #TABS)

    -- Closes with the options window it was opened from.
    if SettingsPanel and SettingsPanel.HookScript then
        SettingsPanel:HookScript("OnHide", function() window:Hide() end)
    end
    window.Set = Set -- what the controls do, by name
end

---------------------------------------------------------------------------
-- Showing a tab
---------------------------------------------------------------------------

function PlaceCamera(scene)
    scene.zoomer:SetScale(ZOOM_START / scene.zoom)
    local distance = scene.distance * scene.zoom
    local fx, fy, fz = scene:GetCameraForward()
    scene:SetCameraPosition(-fx * distance, -fy * distance, -fz * distance)
end

-- Stands the camera back far enough that the whole node shows, at any turn.
-- Its size is only known once the model has loaded.
function FrameNode(scene, actor)
    local x1, y1, z1, x2, y2, z2 = actor:GetActiveBoundingBox()
    if not (x1 and y1 and z1 and x2 and y2 and z2) then return false end
    local across, tall = sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2), z2 - z1
    local width, height = scene:GetSize()
    local fit = tan(FOV / 2) * FILL
    local seen = tall * cos(PITCH) + across * sin(PITCH)
    scene.distance = (max(seen / 2 / fit, across / 2 / (fit * width / max(height, 1))) + across / 2) * (scene.nearer or 1)
    PlaceCamera(scene)
    return true
end

local function ShowNode()
    local kind = Shown()
    local nodes = NODES[kind]
    local index = window.node[kind] or 1
    local node = nodes[index]
    if window.file ~= node[2] then -- only for another node: a new style keeps the view
        window.file = node[2]
        window.actor:SetModelByFileID(node[2])
        window.scene.framed = false
    end
    window.scene.nearer = node[3] or 1 -- a model whose box is bigger than what shows
    window.picker.Dropdown:SetupMenu(function(_, root)
        for i, choice in ipairs(nodes) do
            root:CreateRadio(choice[1], function() return (window.node[kind] or 1) == i end, function()
                window.node[kind] = i
                ShowNode()
            end, i)
        end
    end)
end

function Refresh()
    local tab, kind = window.tab, Shown()
    window.refreshing = true
    PanelTemplates_SetTab(window, tab.index)
    window:SetPortraitToAsset(tab.icon)
    local isGeneral = tab.key == "general"
    for _, part in ipairs(window.look) do part:SetShown(not isGeneral) end
    window.general:SetShown(isGeneral)
    local everything = true
    for _, k in ipairs(ns.KINDS) do everything = everything and ns.db[k] == true end
    window.everything:SetChecked(everything)
    window.gameIcons:SetChecked(ns.db.gameIcons)
    window.brightness:SetValue(ns.db.brightness)
    window.reachLook:SetChecked(ns.db.reachLook)
    window.combatHide:SetChecked(ns.db.combatHide)
    window.instanceHide:SetChecked(ns.db.instanceHide)
    window.sparkleSound:SetChecked(ns.db.sparkleSound)
    window.gatherDim:SetChecked(ns.db.gatherDim)
    window.grayTooHard:SetChecked(ns.db.grayTooHard)
    window.rareGlow:SetChecked(ns.db.rareGlow)
    window.harvest:SetupMenu(function(_, root)
        for i, harvest in ipairs(ns.HARVESTS) do
            root:CreateRadio(harvest.name, function() return ns.db.harvest == i end, function()
                Set("harvest", i)
                PlayHarvest()
            end)
        end
    end)
    local on = true
    for _, k in ipairs(Kinds()) do on = on and ns.db[k] end
    window.on:SetChecked(on)
    window.on.label:SetText(tab.on or "")
    window.beta:SetShown(tab.key == "bobber")
    local one, two = ns.SparkleColors(kind)
    window.swatch:SetColorRGB(ns.SparkleRGB(one))
    window.swatch2:SetColorRGB(ns.SparkleRGB(two))
    window.sets:SetupMenu(function(_, root)
        for _, set in ipairs(SETS) do
            root:CreateRadio(set[1], function()
                local now, second = ns.SparkleColors(Shown())
                return now == set[2] and second == set[3]
            end, function() SetColors(set[2], set[3]) end)
        end
    end)
    window.size:SetValue(ns.SparkleLook(kind, "size"))
    window.height:SetValue(ns.SparkleLook(kind, "height"))
    window.count:SetValue(ns.SparkleLook(kind, "count"))
    window.refreshing = nil
    local chosen = ns.SparkleLook(kind, "style")
    local at = 0 -- five across: the styles for every kind, then the tab's own
    for pass = 1, 2 do
        for i, tile in ipairs(window.tiles) do
            local style = ns.SPARKLE_STYLES[i]
            if (style.only == nil) == (pass == 1) then
                local fits = ns.StyleFits(i, tab.key)
                tile:SetShown(fits)
                if fits then
                    tile:SetPoint("TOPLEFT", (at % 5) * 86, -floor(at / 5) * 80)
                    at = at + 1
                    tile.border:SetAtlas(i == chosen and "PetList-ButtonSelect" or "PetList-ButtonBackground")
                    tile.name:SetFontObject(i == chosen and GameFontHighlightSmall or GameFontNormalSmall)
                    local look = LookOf(kind, i) -- what a click on it gives
                    ns.ShowSparkles(tile.anchor, kind, nil, { style = i, size = 46, height = 0, count = math.min(look.count, 9),
                        color = look.color, color2 = look.color2 })
                end
            end
        end
    end
    ns.ShowSparkles(window.anchor, kind, nil, {}) -- the saved look, as a preview
    ShowNode()
end

-- The finish on the preview's node, then the sparkles back.
function PlayHarvest()
    local frame = ns.SparklePreviews[window.anchor]
    if not frame then return end
    ns.ResetHarvest(frame)
    frame.harvestAge, frame.harvest, frame.harvested = 0, ns.db.harvest, true
    frame:SetScript("OnUpdate", ns.SparkleAnimate)
    window.played = (window.played or 0) + 1
    local played = window.played
    C_Timer.After(1.5, function()
        if window.played ~= played then return end -- another one started since
        ns.ResetHarvest(frame)
        frame.fade = 0
        frame:SetScript("OnUpdate", ns.SparkleAnimate)
    end)
end

local function Open()
    if not window then Build() end
    window:Show()
    Refresh()
end

-- If opening it errors, the error is still reported, the window stays shut, and
-- from the next reload this version's Sparkles page has Blizzard's rows instead.
local failed
function ns.ShowSparkleWindow()
    if failed then return end
    failed = not xpcall(Open, geterrorhandler())
    if failed then
        ns.db.sparkleWindowFailed = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
        if window then window:Hide() end
    end
end

ns.SPARKLE_TABS, ns.SPARKLE_NEEDS = TABS, NEEDS -- the Options rows' words with the gamepad UI on
