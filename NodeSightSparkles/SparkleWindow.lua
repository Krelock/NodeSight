-- The sparkle window: a list on the left with each kind of node and the settings for all
-- of them (and the addon's own pages, if it adds any), the styles as tiles with a small
-- preview each (None turns the kind off), the look's settings, and the node in 3D with
-- its sparkles on it, as in the world.
--
-- Sections: Nodes to preview, Changing the look, Building the window, Showing a page,
-- Interact Key turned off.

local ADDON_NAME, ns = ...

local ipairs, floor, format = ipairs, math.floor, string.format
local sqrt, sin, cos, tan, max = math.sqrt, math.sin, math.cos, math.tan, math.max

---------------------------------------------------------------------------
-- Nodes to preview
---------------------------------------------------------------------------
-- Name, model file (world/skillactivated/..., and world/goober/..., the game's objects you click),
-- the scale the world draws it at (1 if not given) and how much nearer the camera goes.

local NODES = {
    herbs = {
        { "Peacebloom", 219481, 0.5 }, { "Silverleaf", 219487, 0.6, 0.55 }, { "Bruiseweed", 219440, 0.7 },
        { "Stranglekelp", 219495, 0.5 }, { "Black Lotus", 219437 },
    },
    ore = {
        { "Copper Vein", 219514, 0.5 }, { "Tin Vein", 219568, 0.5 }, { "Iron Deposit", 219532, 0.5 }, { "Gold Vein", 219524, 0.5 },
        { "Mithril Deposit", 219541, 0.5 }, { "Truesilver Deposit", 219569, 0.5 }, { "Small Thorium Vein", 219566, 0.5 },
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
    -- Creatures by display ID (creature = true), lying dead.
    skinning = {
        { "Plainstrider", 1219, creature = true }, { "Mottled Boar", 503, creature = true },
        { "Young Wolf", 447, creature = true }, { "Flatland Cougar", 1059, creature = true },
    },
}
NODES.loot = NODES.skinning
local DEAD = 6 -- the "Dead" animation: a corpse lying still

-- The camera looks down a little, as you see a node on the ground, and the
-- node fills this much of the preview.
local PITCH, FOV, FILL = 0.35, 0.6, 0.7
local ZOOM_IN, ZOOM_START, ZOOM_OUT = 0.4, 1.6, 2.2 -- times that distance

-- The sparkles at the size and place they have in the world, next to the node.
-- In the world they are sized for a node 25 yards from the camera; with the game's
-- camera seeing 54 degrees top to bottom on a screen 768 UI units high, a yard is YARD units there.
local YARD = 768 / (2 * 25 * tan(math.rad(27)))
local PLATE_OVER = 1.25 -- yards from the top of the node's box up to its plate
local AREA = 100 -- the camera also stands back far enough for sparkles this size
local NEARER = { herbs = 0.85, skinning = 0.65, loot = 0.65 } -- small next to their sparkles (herbs) or their box (a corpse): the camera nearer

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
    harvest = true, grayTooHard = true, myProfessions = true, rareGlow = true, sparkleSound = true, gatherDim = true,
    minimapButton = true, townInteractOff = true, stoneBackground = true }

-- The list's sparkle entries: each kind (its name, what it sparkles on and its icon), then the settings.
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
    { key = "bobber", name = "Fishing bobber", on = "Sparkles on your fishing bobber", icon = "Interface\\Icons\\Trade_Fishing",
        tip = "Sparkles on your bobber so it's easier to spot." },
    { key = "skinning", name = "Skinning", on = "Sparkles on skinnable corpses", icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
        tip = "Sparkles on corpses you can skin, once they're looted." },
    { key = "loot", name = "Lootable corpses", on = "Sparkles on lootable corpses", icon = "Interface\\Icons\\INV_Misc_Bag_08",
        tip = "Sparkles on corpses that still have loot." },
    { key = "general", name = "Sparkle settings", icon = "Interface\\Icons\\INV_Misc_Gear_01" },
}
-- The game's own icon over each kind when it's the interact target (its cursor's atlas).
local GAME_ICONS = { herbs = "Crosshair_GatherHerbs_64", ore = "Crosshair_Mine_64", chests = "Crosshair_lootall_64",
    quests = "Crosshair_questinteract_64", others = "Crosshair_interact_64", bobber = "Crosshair_interact_64",
    skinning = "Crosshair_Skin_64", loot = "Crosshair_lootall_64" }
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
local function Shown() return (window.tab.key == "general" or window.tab.page) and "herbs" or window.tab.key end

local function Hex(r, g, b)
    return format("ff%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

local Refresh, FrameNode, PlaceCamera, PickStyle, PlayHarvest, ShowExample
-- The settings the preview shows for a few seconds when they're ticked, and what it shows.
local EXAMPLES = { rareGlow = "rare", reachLook = "far", grayTooHard = "tooHard" }
local EXAMPLE_TIME = 3

-- The sparkles in the world after a change.
local function Changed()
    ns.UpdateAll()
end

-- Each kind keeps every style's look as it was last left (the settings' styleLooks[kind][style]),
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

-- Kinds whose every style starts at one height: the bobber floats on the water, and a
-- corpse lies well under its plate (it stays where the living creature's head was).
local START_HEIGHT = { bobber = 0, skinning = -115, loot = -115 }

-- Style i's look for a kind: as it was left, or the one it comes with.
local function LookOf(kind, i)
    local look = ns.db.styleLooks[kind] and ns.db.styleLooks[kind][i]
    if type(look) == "table" and type(look.size) == "number" and type(look.height) == "number" and type(look.count) == "number"
        and tostring(look.color):match("^%x%x%x%x%x%x%x%x$") and (look.color2 == nil or tostring(look.color2):match("^%x%x%x%x%x%x%x%x$")) then
        return look
    end
    local start = ns.SPARKLE_STYLES[i].start
    return { size = start.size, height = START_HEIGHT[kind] or start.height, count = start.count, color = start.color, color2 = start.color2 }
end

-- Sets a part of the look (or "on") for the tab's kinds, then the sparkles and the window.
-- "everything": sparkles on or off for every kind.
local function Set(what, value)
    if what == "own" then
        if ns.SetOwnSettings then ns.SetOwnSettings(value) end
        ns.AskReload()
        return Refresh()
    end
    if GENERAL[what] then
        ns.db[what] = value
        Changed()
        if what == "gameIcons" or what == "townInteractOff" then ns.Setup() end
        if what == "minimapButton" and ns.MinimapButtonChanged then ns.MinimapButtonChanged() end
        if value and EXAMPLES[what] then return ShowExample(what) end
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

-- A kind on or off (its box in the list).
local function SetKind(kind, on)
    ns.db[kind] = on
    Changed()
    ns.Setup()
    Refresh()
end

-- A style, with its look as it was left, for the tab's kinds; it turns them on.
function PickStyle(i)
    for _, kind in ipairs(Kinds()) do
        local keys, look = ns.SPARKLE_KEYS[kind], LookOf(kind, i)
        ns.db[keys.style] = i
        for _, what in ipairs(LOOK) do ns.db[keys[what]] = look[what] end
        ns.db[kind] = true
    end
    Changed()
    ns.Setup()
    Refresh()
end

-- The kind's style and look as they come (on or off stays as it is).
local function Defaults()
    for _, kind in ipairs(Kinds()) do
        local keys = ns.SPARKLE_KEYS[kind]
        ns.db[keys.style] = ns.defaults[keys.style]
        for _, what in ipairs(LOOK) do ns.db[keys[what]] = ns.defaults[keys[what]] end
        ns.db.styleLooks[kind] = nil
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
local RIGHT_COLUMN = 235 -- the settings page's second column
local LIST = 180 -- the list's width
local function Row(panel, y, text, control, tip)
    local label = Label(panel, text)
    label:SetPoint("LEFT", panel, "TOPLEFT", 0, y)
    control:SetPoint("LEFT", panel, "TOPLEFT", COLUMN, y)
    local hover
    if tip then
        Tooltip(control, text, tip)
        hover = New("Frame", panel)
        hover:SetPoint("LEFT", panel, "TOPLEFT", 0, y)
        hover:SetSize(COLUMN - 4, 26)
        hover:EnableMouse(true)
        Tooltip(hover, text, tip)
    end
    return label, hover
end

local function Checkbox(panel, y, text, what, tip)
    local box = New("CheckButton", panel, "MinimalCheckboxTemplate")
    box:SetScript("OnClick", function(self)
        PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        Set(what, self:GetChecked())
    end)
    box.label, box.hover = Row(panel, y, text, box, tip)
    return box
end

-- The look a style comes with (its tile gives it back).
local function StyleStart(kind, what)
    local style = ns.SPARKLE_STYLES[ns.SparkleLook(kind, "style")] or ns.SPARKLE_STYLES[1]
    if what == "height" and START_HEIGHT[kind] then return START_HEIGHT[kind] end
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

-- The first tile: no sparkles on the kind.
local function NoneTile(grid)
    local tile = New("Button", grid)
    tile:SetSize(81, 76)
    local background = tile:CreateTexture(nil, "BACKGROUND")
    background:SetAtlas("collections-background-tile")
    background:SetAllPoints()
    tile.border = tile:CreateTexture(nil, "BORDER")
    tile.border:SetAllPoints()
    local highlight = tile:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAtlas("PetList-ButtonHighlight")
    highlight:SetAllPoints()
    tile.name = Label(tile, NONE, "GameFontNormalSmall")
    tile.name:SetPoint("BOTTOM", 0, 8)
    tile:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        Set("on", false)
    end)
    Tooltip(tile, NONE, function()
        return "Turns off " .. window.tab.on:lower() .. ". Pick a style to turn them back on."
    end)
    return tile
end

-- A row in the list: a page of the addon's, a kind (its on/off box and icon) or the settings.
-- A line in one color fading out to the right (header lines, the picked row's edges).
local function Fade(texture, r, g, b, a)
    texture:SetColorTexture(1, 1, 1, 1)
    texture:SetGradient("HORIZONTAL", CreateColor(r, g, b, a), CreateColor(r, g, b, 0))
end

local function ListEntry(list, y, entry)
    local item = New("Button", list)
    item:SetSize(LIST - 12, 22)
    item:SetPoint("TOPLEFT", 4, y)
    -- The picked row: the logo's brown a shade lighter, bronze lines fading out above and
    -- below it, a gold bar at its left.
    item.selected = item:CreateTexture(nil, "BACKGROUND")
    item.selected:SetColorTexture(46 / 255, 38 / 255, 27 / 255)
    item.selected:SetAllPoints()
    item.picked = { item.selected }
    for _, edge in ipairs({ "TOP", "BOTTOM" }) do
        local line = item:CreateTexture(nil, "BORDER")
        line:SetPoint(edge .. "LEFT")
        line:SetPoint(edge .. "RIGHT")
        line:SetHeight(1)
        Fade(line, 0.47, 0.39, 0.24, 1)
        item.picked[#item.picked + 1] = line
    end
    local bar = item:CreateTexture(nil, "BORDER")
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("BOTTOMLEFT")
    bar:SetWidth(3)
    bar:SetColorTexture(1, 0.82, 0)
    item.picked[#item.picked + 1] = bar
    item:SetHighlightAtlas("Options_List_Hover")
    local x = 10
    if entry.on then
        local box = New("CheckButton", item, "MinimalCheckboxTemplate")
        box:SetSize(20, 20)
        box:SetPoint("LEFT", 4, 0)
        box:SetScript("OnClick", function(self)
            PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
            SetKind(entry.key, self:GetChecked() == true)
        end)
        Tooltip(box, entry.on, entry.tip .. NEEDS)
        item.box = box
        item.icon = item:CreateTexture(nil, "ARTWORK")
        item.icon:SetTexture(entry.icon)
        item.icon:SetSize(16, 16)
        item.icon:SetPoint("LEFT", 28, 0)
        x = 48
    end
    item.text = Label(item, entry.list or entry.name)
    item.text:SetPoint("LEFT", x, 0)
    item:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        window.tab = entry
        Refresh()
    end)
    return item
end

local function Build()
    -- The style grid is as tall as the biggest tab's styles need (and None), five a row.
    local most = 0
    for _, tab in ipairs(TABS) do
        local n = 0
        for i in ipairs(ns.SPARKLE_STYLES) do
            if ns.StyleFits(i, tab.key) then n = n + 1 end
        end
        most = max(most, n + 1)
    end
    local gridHeight = floor((most + 4) / 5) * 80 - 4
    window = New("Frame", UIParent, "ButtonFrameTemplate")
    window:Hide()
    window:SetSize(760 + LIST, 402 + gridHeight)
    window:SetPoint("CENTER", 0, 20)
    window:SetFrameStrata("DIALOG")
    window:SetToplevel(true)
    window:EnableMouse(true)
    -- Dragged by any empty part of it and kept on screen (back in the middle after a reload).
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetTitle(C_AddOns.GetAddOnMetadata(ADDON_NAME, "Title") or ADDON_NAME)
    local logo = "Interface\\AddOns\\" .. ADDON_NAME .. "\\logo"
    window:SetPortraitToAsset(logo)
    -- The logo in a gold ring (the minimap tracking ring's) on a dark circle over the frame's
    -- portrait ring, in place of the portrait (whose round mask sits off the ring's middle).
    local corner = window.NineSlice and window.NineSlice.TopLeftCorner
    if corner then
        local size = corner:GetWidth()
        if not (size and size > 0) then size = 95 end
        window.PortraitContainer:Hide()
        local badge = New("Frame", window.NineSlice)
        badge:SetSize(size * 0.68, size * 0.68) -- (just over the frame's ring)
        badge:SetPoint("CENTER", corner, "TOPLEFT", size * 0.397, -size * 0.397) -- (the ring's middle in the art)
        local shadow = badge:CreateTexture(nil, "BACKGROUND")
        badge.shadow = shadow
        shadow:SetAtlas("gamepad-actionbar-circleslot-dropshadow")
        shadow:SetPoint("TOPLEFT", -size * 0.12, size * 0.12)
        shadow:SetPoint("BOTTOMRIGHT", size * 0.125, -size * 0.125)
        -- A round piece of the badge: a texture under a circle mask its own size.
        local function Round(layer, scale)
            local piece = badge:CreateTexture(nil, layer)
            piece:SetSize(size * 0.68 * scale, size * 0.68 * scale)
            piece:SetPoint("CENTER")
            local mask = badge:CreateMaskTexture()
            mask:SetAllPoints(piece)
            mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            piece:AddMaskTexture(mask)
            return piece
        end
        Round("BORDER", 1):SetColorTexture(27 / 255, 23 / 255, 18 / 255) -- (the logo's own dark)
        Round("ARTWORK", 0.8):SetTexture(logo)
        -- The ring's outside is 0.8 of the part shown, on the circle's edge.
        badge.ring = badge:CreateTexture(nil, "OVERLAY")
        badge.ring:SetSize(size * 0.68 / 0.8, size * 0.68 / 0.8)
        badge.ring:SetPoint("CENTER")
        badge.ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        badge.ring:SetTexCoord(0, 0.625, -1 / 64, 39 / 64) -- (its ring's middle at 20, 19 of 64)
        badge.ring:SetVertexColor(0.82, 0.74, 0.55) -- the minimap's bright gold softened, nearer the frame's metal
        window.badge = badge
    end
    window.interactOff = Label(window, ns.INTERACT_OFF, "GameFontRed")
    window.interactOff:SetPoint("TOP", 0, -36)
    -- Turns it back on with the rest of what sparkles need (after the fight, in combat).
    local turnOn = New("Button", window, "UIPanelButtonTemplate")
    turnOn:SetSize(80, 22)
    turnOn:SetText(ENABLE)
    turnOn:SetPoint("LEFT", window.interactOff, "RIGHT", 8, 0)
    turnOn:SetScript("OnClick", function()
        ns.Setup()
        Refresh()
    end)
    Tooltip(turnOn, ENABLE_INTERACT_TEXT, "Turns the game's Enable Interact Key back on, so sparkles show again.")
    window.turnOn = turnOn
    ButtonFrameTemplate_HideButtonBar(window)
    window.CloseButton:SetScript("OnClick", function() window:Hide() end)
    -- (The previews hide with it, and their frames only run while shown.)
    window:SetScript("OnShow", function() PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN) end)
    window:SetScript("OnHide", function() PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE) end)
    window.tab, window.node = TABS[1], {}
    -- The list and pages in the logo's own dark brown (#1B1712), and the strip under the
    -- title too (over the frame's gray streaks).
    window.backdrop = window.Inset:CreateTexture(nil, "BACKGROUND", nil, 7)
    window.backdrop:SetAllPoints()
    window.strip = window:CreateTexture(nil, "BORDER", nil, 1)
    window.strip:SetPoint("TOPLEFT", 2, -21)
    window.strip:SetPoint("BOTTOMRIGHT", window, "TOPRIGHT", -2, -60)
    window.strip:SetColorTexture(27 / 255, 23 / 255, 18 / 255)
    -- What's New (an addon that has its notes) in the strip's right end: gold words with a
    -- notes icon, white under the mouse, like a link. The version in the bottom right corner.
    if ns.ShowWhatsNew then
        local news = New("Button", window)
        news:SetPoint("RIGHT", window, "TOPRIGHT", -16, -40)
        local icon = news:CreateTexture(nil, "ARTWORK")
        icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
        icon:SetSize(18, 18)
        icon:SetPoint("LEFT")
        news.label = Label(news, GAMEMENU_NEW_BUTTON, "GameFontNormal")
        news.label:SetPoint("LEFT", icon, "RIGHT", 5, 0)
        news:SetSize(18 + 5 + news.label:GetStringWidth(), 22)
        news:SetScript("OnEnter", function() news.label:SetFontObject("GameFontHighlight") end)
        news:SetScript("OnLeave", function() news.label:SetFontObject("GameFontNormal") end)
        news:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            ns.ShowWhatsNew()
        end)
        window.news = news
    end
    window.version = Label(window, ("%s %s"):format(GAME_VERSION_LABEL, C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or ""), "GameFontDisableSmall")
    window.version:SetPoint("BOTTOMRIGHT", -16, 12)

    -- The list on the left: the addon's own pages, then the sparkles.
    local list = New("Frame", window.Inset)
    list:SetPoint("TOPLEFT", 2, -2) -- (inside the inset's border, no gap to it)
    list:SetPoint("BOTTOMLEFT", 2, 2)
    list:SetWidth(LIST - 2)
    -- On a panel of its own: a shade lighter (added, so the stone shows through), a thin line beside it.
    local panel = list:CreateTexture(nil, "BACKGROUND", nil, -1)
    panel:SetAllPoints()
    panel:SetColorTexture(7 / 255, 5 / 255, 4 / 255)
    panel:SetBlendMode("ADD")
    local divider = list:CreateTexture(nil, "BORDER")
    divider:SetPoint("TOPRIGHT")
    divider:SetPoint("BOTTOMRIGHT")
    divider:SetWidth(1)
    divider:SetColorTexture(70 / 255, 58 / 255, 40 / 255)
    window.listPanel, window.listDivider = panel, divider
    window.list, window.pages, window.Tabs = {}, {}, {}
    local y = -6
    for i, entry in ipairs(ns.WINDOW_PAGES or {}) do
        entry.index = nil
        window.list[i] = ListEntry(list, y, entry)
        y = y - 24
    end
    if ns.WINDOW_PAGES then
        local header = Label(list, "Sparkles", "GameFontNormalLarge")
        header:SetPoint("TOPLEFT", 10, y - 8)
        local line = list:CreateTexture(nil, "ARTWORK")
        Fade(line, 1, 0.82, 0, 0.67) -- (the logo's gold)
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -3)
        line:SetPoint("RIGHT", list, "RIGHT", -8, 0)
        y = y - 36
    end
    for i, tab in ipairs(TABS) do
        tab.index = i
        window.Tabs[i] = ListEntry(list, y, tab)
        y = y - 24
    end

    -- The preview: the node turning slowly on Blizzard's mount journal background. It fills its
    -- column, from the list's line to the inset's border at the top and bottom.
    local preview = New("Frame", window.Inset)
    preview:SetPoint("TOPLEFT", LIST, -2)
    preview:SetPoint("BOTTOMLEFT", LIST, 2)
    preview:SetWidth(288)
    preview:SetClipsChildren(true)
    -- Its edge, over everything in it (the preview clips what it holds): a thin line in the
    -- headers' gold with a dark one round it.
    local edge = New("Frame", window.Inset)
    edge:SetAllPoints(preview)
    edge:SetFrameLevel(preview:GetFrameLevel() + 50)
    window.edge = edge
    edge.gold = {}
    -- A strip along one side: across the top or bottom, or down the left or right.
    local function Side(side, layer, sublevel, out, width)
        local piece = edge:CreateTexture(nil, layer, nil, sublevel)
        if side == "TOP" or side == "BOTTOM" then
            local y = side == "TOP" and out or -out
            piece:SetPoint(side .. "LEFT", -out, y)
            piece:SetPoint(side .. "RIGHT", out, y)
            piece:SetHeight(width)
        else
            local x = side == "LEFT" and -out or out
            piece:SetPoint("TOP" .. side, x, out)
            piece:SetPoint("BOTTOM" .. side, x, -out)
            piece:SetWidth(width)
        end
        return piece
    end
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local dark = Side(side, "OVERLAY", 0, 2, 3) -- (from 2 outside to 1 in)
        dark:SetColorTexture(0.04, 0.03, 0.02, 1)
        local gold = Side(side, "OVERLAY", 1, 0, 1)
        gold:SetColorTexture(0.47, 0.39, 0.24, 1)
        edge.gold[#edge.gold + 1] = dark
        edge.gold[#edge.gold + 1] = gold
    end
    -- Its backdrop: Blizzard's mount journal art grayed and tinted the logo's brown and gold.
    local background = preview:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\PetBattles\\MountJournal-BG")
    background:SetTexCoord(2 / 512, 0.78515625, 2 / 512, 510 / 512) -- the picture's left corners are white
    background:SetAllPoints()
    background:SetDesaturated(true)
    background:SetVertexColor(0.59, 0.47, 0.24)
    window.previewBackdrop = background
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
    -- The sparkles grow and shrink with the zoom, around the node's middle (PlaceCamera).
    scene.zoomer = New("Frame", scene)
    scene.zoomer:SetSize(1, 1)
    scene.zoomer:SetPoint("CENTER", preview, "CENTER")
    window.anchor = New("Frame", scene.zoomer) -- where the node's plate would be
    window.anchor:SetSize(1, 1)
    window.anchor:SetPoint("BOTTOM", scene.zoomer, "CENTER", 0, 60)
    local picker = New("Frame", preview, "SettingsDropdownWithButtonsTemplate")
    picker:SetWidth(260)
    picker.Dropdown:SetWidth(210)
    picker:SetPoint("TOP", 0, -6)
    picker:SetFrameLevel(scene:GetFrameLevel() + 10) -- over the model, which takes the mouse
    window.picker = picker
    -- Under the node while these sparkles are off.
    local off = New("Frame", preview)
    off:SetAllPoints()
    off:SetFrameLevel(scene:GetFrameLevel() + 10)
    window.offText = Label(off, "Sparkles are off", "GameFontNormalLarge")
    window.offText:SetPoint("BOTTOM", 0, 60)
    window.offHint = Label(off, "Pick a style to turn them on.", "GameFontHighlight")
    window.offHint:SetPoint("TOP", window.offText, "BOTTOM", 0, -6)
    window.off = off
    -- The game's icon over the node, while Keep the game's icons is on (its box in the corner).
    local over = New("Frame", scene.zoomer) -- (its own frame: the sparkles are the anchor's)
    over:SetSize(32, 32)
    over:SetPoint("CENTER", window.anchor)
    window.gameIcon = over:CreateTexture(nil, "OVERLAY")
    window.gameIcon:SetAllPoints()
    local icons = New("Frame", preview)
    icons:SetAllPoints()
    icons:SetFrameLevel(scene:GetFrameLevel() + 10)
    local box = New("CheckButton", icons, "MinimalCheckboxTemplate")
    box:SetPoint("BOTTOMLEFT", 8, 6)
    box:SetScript("OnClick", function(self)
        PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        Set("gameIcons", self:GetChecked())
    end)
    box.label = Label(icons, "Keep the game's icons", "GameFontNormal")
    box.label:SetPoint("LEFT", box, "RIGHT", 4, 0)
    Tooltip(box, "Keep the game's icons", "Keeps the game's own icon over things you can interact with.")
    window.gameIcons = box

    -- The styles.
    -- A kind's page: its name and a gray line on it on top (like the addon's own pages), then the styles.
    window.kindTitle = Label(window.Inset, "", "GameFontHighlightLarge")
    window.kindTitle:SetPoint("TOPLEFT", preview, "TOPRIGHT", 12, -12)
    window.kindAbout = Label(window.Inset, "", "GameFontDisableSmall")
    window.kindAbout:SetPoint("TOPLEFT", preview, "TOPRIGHT", 12, -36)
    local grid = New("Frame", window.Inset)
    grid:SetPoint("TOPLEFT", preview, "TOPRIGHT", 10, -58)
    grid:SetSize(428, gridHeight)
    window.tiles = {}
    window.none = NoneTile(grid)
    for i, style in ipairs(ns.SPARKLE_STYLES) do window.tiles[i] = Tile(grid, i, style) end

    -- The rest of the look.
    local panel = New("Frame", window.Inset)
    panel:SetPoint("TOPLEFT", grid, "BOTTOMLEFT", 0, -26)
    panel:SetPoint("BOTTOMRIGHT", -8, 8)
    local defaults = New("Button", panel, "UIPanelButtonTemplate")
    defaults:SetSize(110, 22)
    defaults:SetText(DEFAULTS)
    defaults:SetPoint("LEFT", panel, "TOPLEFT", 0, 0)
    defaults:SetScript("OnClick", Defaults)
    Tooltip(defaults, DEFAULTS, "Puts this kind's style, colors, area, height and count back to how they come. On or off stays as it is.")
    window.defaults = defaults
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
    window.height = Slider(panel, -146, "Height", "height", -150, 100, "Moves the sparkles up or down.", true)
    window.count = Slider(panel, -184, "Count", "count", 1, 20,
        "How many sparkles show at once. Some styles don't use it.", true)

    -- The settings page: for all sparkles, under headers.
    window.look, window.preview = { grid, panel, window.kindTitle, window.kindAbout }, preview
    local general = New("Frame", window.Inset)
    general:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, 38) -- (as high as the kind's name)
    general:SetPoint("BOTTOMRIGHT", -8, 8)
    window.general = general
    local function At(box, x) -- the box first, its words after it
        local y = select(5, box:GetPoint(1))
        box:ClearAllPoints()
        box:SetPoint("LEFT", general, "TOPLEFT", x or -4, y)
        box.label:ClearAllPoints()
        box.label:SetPoint("LEFT", box, "RIGHT", 4, 0)
        local width = (x or -4) > 0 and 190 or 205 -- (a longer label wraps instead of leaving the page)
        box.label:SetWidth(width)
        box.label:SetJustifyH("LEFT")
        box.hover:ClearAllPoints()
        box.hover:SetPoint("LEFT", box.label, "LEFT")
        box.hover:SetSize(math.min(box.label:GetStringWidth(), width) + 4, 26)
        box:SetFrameLevel(box:GetFrameLevel() + 1) -- over its row's tooltip area, so all of it takes the click
        return box
    end
    local function Header(y, text)
        local header = Label(general, text, "GameFontNormalLarge")
        header:SetPoint("LEFT", general, "TOPLEFT", 0, y)
        local line = general:CreateTexture(nil, "ARTWORK")
        Fade(line, 1, 0.82, 0, 0.67) -- (the logo's gold)
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -3)
        line:SetPoint("RIGHT", general, "RIGHT", -12, 0)
    end
    window.everything = At(Checkbox(general, 0, "Sparkles on everything", "everything",
        "Turns them all on or off at once. Each kind's None tile turns that one off." .. NEEDS))
    Header(-36, "Look")
    window.brightness = Slider(general, -66, "Brightness", "brightness", 10, 100,
        "How bright the sparkles are.")
    window.reachLook = At(Checkbox(general, -98, "Dimmer out of reach", "reachLook",
        "Dimmer when it's too far to gather. Flashes when you get in range."))
    window.rareGlow = At(Checkbox(general, -98, "Rare nodes stand out", "rareGlow",
        "A gold glow on rare herbs and ore like Black Lotus and Truesilver."), RIGHT_COLUMN)
    window.grayTooHard = At(Checkbox(general, -130, "Gray when your skill is too low", "grayTooHard",
        "Herbs and ore your skill is too low for sparkle gray."))
    local harvest = New("DropdownButton", general, "WowStyle1DropdownTemplate")
    harvest:SetWidth(180)
    Row(general, -164, "When gathered", harvest,
        "What the sparkles do when you loot it. Picking one plays it on the preview.")
    window.harvest = harvest
    local show = New("Button", general, "UIPanelButtonTemplate")
    show:SetSize(90, 22)
    show:SetText(PREVIEW)
    show:SetPoint("LEFT", harvest, "RIGHT", 8, 0)
    show:SetScript("OnClick", function() PlayHarvest() end)
    Tooltip(show, PREVIEW, "Plays it on the preview.")
    window.showHarvest = show
    Header(-202, "When to hide")
    window.combatHide = At(Checkbox(general, -232, "Hide in combat", "combatHide",
        "No sparkles while you're in combat."))
    window.instanceHide = At(Checkbox(general, -232, "Hide in instances", "instanceHide",
        "No sparkles in dungeons and raids."), RIGHT_COLUMN)
    window.gatherDim = At(Checkbox(general, -264, "Dim while gathering", "gatherDim",
        "Sparkles fade while you gather so you can see the node."))
    Header(-302, "Extras")
    window.sparkleSound = At(Checkbox(general, -332, "Sparkle sound", "sparkleSound",
        "Plays a soft sound when something near you starts sparkling."))
    window.townInteractOff = At(Checkbox(general, -332, "Interact Key off in towns (Beta)", "townInteractOff",
        "Turns the game's Interact Key off while you're in a town or inn, so it doesn't pick the NPCs there. Nothing sparkles in town then."), RIGHT_COLUMN)
    window.myProfessions = At(Checkbox(general, -364, "Only for my professions", "myProfessions",
        "Herbs sparkle only if you have Herbalism, ore only with Mining, and corpses only with Skinning."))
    -- An addon with pages of its own has these there.
    window.minimapButton = At(Checkbox(general, -364, "Minimap button", "minimapButton",
        "The button on the minimap."), RIGHT_COLUMN)
    window.own = At(Checkbox(general, -396, "Settings for this character only", "own",
        "This character keeps its own settings. Untick it to use the settings your other characters share. It offers a reload to switch."))
    window.stone = At(Checkbox(general, -396, "Stone background", "stoneBackground",
        "Blizzard's stone texture behind this window, warmed to the logo's brown. Off: plain brown."), RIGHT_COLUMN)
    for _, box in ipairs({ window.minimapButton, window.own, window.stone }) do
        for _, part in ipairs({ box, box.label, box.hover }) do part:SetShown(not ns.WINDOW_PAGES) end
    end
    -- Blizzard's proc glow round the box that turns them on: only its loop, as on
    -- an action button whose alert skips the burst.
    if ActionButtonSpellAlertMixin then
        window.glow = New("Frame", window.Inset, "ActionButtonSpellAlertTemplate")
        window.glow.ProcStartFlipbook:Hide()
        window.glow:SetFrameLevel(window.everything:GetFrameLevel() + 2)
    end

    -- The addon's own pages, beside the list.
    for i, entry in ipairs(ns.WINDOW_PAGES or {}) do
        local page = New("Frame", window.Inset)
        page:SetPoint("TOPLEFT", LIST + 4, -4)
        page:SetPoint("BOTTOMRIGHT", -4, 4)
        entry.page = page
        entry.build(page)
        window.pages[i] = page
    end

    -- Closes with the options window it was opened from.
    if SettingsPanel and SettingsPanel.HookScript then
        SettingsPanel:HookScript("OnHide", function() window:Hide() end)
    end
    window.Set = Set -- what the controls do, by name
    window.SetSetting = ns.WindowSet -- the addon's own pages' settings, by key
end

---------------------------------------------------------------------------
-- Showing a page
---------------------------------------------------------------------------

-- The camera, then the sparkles where the node's plate is on screen (the top of its box
-- plus PLATE_OVER), at their world size there.
function PlaceCamera(scene)
    local distance = scene.distance * scene.zoom
    local fx, fy, fz = scene:GetCameraForward()
    scene:SetCameraPosition(-fx * distance, -fy * distance, -fz * distance)
    local _, height = scene:GetSize()
    local focal = max(height, 1) / 2 / tan(FOV / 2)
    local up = scene.tall / 2 + PLATE_OVER / scene.scale -- model units over the box's middle
    local depth = max(distance - up * sin(PITCH), 0.01)
    local scale = focal / depth / (YARD * scene.scale)
    scene.zoomer:SetScale(scale)
    window.anchor:SetPoint("BOTTOM", scene.zoomer, "CENTER", 0, up * cos(PITCH) * focal / depth / scale)
end

-- Stands the camera back far enough that the whole node shows, at any turn, and
-- sparkles of size AREA around it. Its size is only known once the model has loaded.
function FrameNode(scene, actor)
    local x1, y1, z1, x2, y2, z2 = actor:GetActiveBoundingBox()
    if not (x1 and y1 and z1 and x2 and y2 and z2) then return false end
    local across, tall = sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2), z2 - z1
    across = max(across, AREA / (YARD * scene.scale))
    local width, height = scene:GetSize()
    local fit = tan(FOV / 2) * FILL
    local seen = tall * cos(PITCH) + across * sin(PITCH)
    scene.distance = (max(seen / 2 / fit, across / 2 / (fit * width / max(height, 1))) + across / 2) * (scene.nearer or 1)
    scene.tall = tall
    PlaceCamera(scene)
    return true
end

local function ShowNode()
    local kind = Shown()
    local nodes = NODES[kind]
    local index = window.node[kind] or 1
    local node = nodes[index]
    local file = node.creature and "creature" .. node[2] or node[2]
    if window.file ~= file then -- only for another node: a new style keeps the view
        window.file = file
        if node.creature then
            window.actor:SetModelByCreatureDisplayID(node[2])
            window.actor:SetAnimation(DEAD)
        else
            window.actor:SetModelByFileID(node[2])
            if window.dead then window.actor:SetAnimation(0) end -- the actor keeps its animation
        end
        window.dead = node.creature
        window.scene.framed = false
    end
    window.scene.scale = node[3] or 1
    window.scene.nearer = (node[4] or 1) * (NEARER[kind] or 1) -- node[4]: a model whose box is bigger than what shows
    window.picker.Dropdown:SetupMenu(function(_, root)
        for i, choice in ipairs(nodes) do
            root:CreateRadio(choice[1], function() return (window.node[kind] or 1) == i end, function()
                window.node[kind] = i
                Refresh()
            end, i)
        end
    end)
end

function Refresh()
    local tab, kind = window.tab, Shown()
    window.refreshing = true
    window.selectedTab = tab.index
    for _, entry in ipairs(ns.WINDOW_PAGES or {}) do entry.page:SetShown(entry == tab) end
    local items = {}
    for i, entry in ipairs(ns.WINDOW_PAGES or {}) do items[#items + 1] = { window.list[i], entry } end
    for i, entry in ipairs(TABS) do items[#items + 1] = { window.Tabs[i], entry } end
    for _, pair in ipairs(items) do
        local item, entry = pair[1], pair[2]
        for _, part in ipairs(item.picked) do part:SetShown(entry == tab) end
        local off = entry.on and not ns.db[entry.key]
        if item.box then item.box:SetChecked(not off) end
        item.text:SetFontObject(entry == tab and "GameFontHighlight" or off and "GameFontDisable" or "GameFontNormal")
    end
    local isGeneral = tab.key == "general"
    for _, part in ipairs(window.look) do part:SetShown(not isGeneral and not tab.page) end
    window.kindTitle:SetText(tab.name)
    window.kindAbout:SetText(tab.tip or "")
    window.general:SetShown(isGeneral)
    window.preview:SetShown(not tab.page)
    window.edge:SetShown(not tab.page)
    window.interactOff:SetShown(ns.InteractOff())
    window.turnOn:SetShown(window.interactOff:IsShown())
    -- Stone background: the inset's stone with the logo's brown added over it (its grain
    -- kept, its average that brown); off, plain brown.
    if ns.db.stoneBackground == true then
        window.backdrop:SetColorTexture(14 / 255, 10 / 255, 5 / 255)
        window.backdrop:SetBlendMode("ADD")
    else
        window.backdrop:SetColorTexture(27 / 255, 23 / 255, 18 / 255)
        window.backdrop:SetBlendMode("BLEND")
    end
    if tab.page then
        tab.refresh(tab.page)
        window.off:SetShown(false)
        if window.glow then window.glow:SetShown(false) end
        window.refreshing = nil
        return
    end
    local everything = true
    for _, k in ipairs(ns.KINDS) do everything = everything and ns.db[k] == true end
    window.everything:SetChecked(everything)
    window.gameIcons:SetChecked(ns.db.gameIcons)
    window.gameIcon:SetAtlas(GAME_ICONS[kind])
    window.gameIcon:SetShown(ns.db.gameIcons == true)
    window.myProfessions:SetChecked(ns.db.myProfessions)
    window.minimapButton:SetChecked(ns.db.minimapButton)
    window.townInteractOff:SetChecked(ns.db.townInteractOff)
    window.own:SetChecked(not ns.OwnSettings or ns.OwnSettings())
    window.stone:SetChecked(ns.db.stoneBackground == true)
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
    local anyOn = false
    for _, k in ipairs(ns.KINDS) do anyOn = anyOn or ns.db[k] == true end
    window.off:SetShown(not isGeneral and not on)
    local glow = window.glow
    if glow then
        local off = isGeneral and not anyOn
        glow:SetShown(off)
        if off then
            local box = window.everything
            glow:ClearAllPoints()
            glow:SetPoint("CENTER", box)
            glow:SetSize(box:GetWidth() * 1.4, box:GetHeight() * 1.4) -- Blizzard's size on a button
            if not glow.ProcLoop:IsPlaying() then glow.ProcLoop:Play() end
        end
    end
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
    local chosen = on and ns.SparkleLook(kind, "style")
    window.none.border:SetAtlas(on and "PetList-ButtonBackground" or "PetList-ButtonSelect")
    window.none.name:SetFontObject(on and GameFontNormalSmall or GameFontHighlightSmall)
    window.none:SetPoint("TOPLEFT", 0, 0)
    window.none:SetShown(not isGeneral)
    local at = 1 -- five across: None, the styles for every kind, then the tab's own
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
    local node = NODES[kind][window.node[kind] or 1]
    local example = EXAMPLES[window.example]
    if ns.db[kind] or example then -- (the preview's own kind: on Sparkle settings, the last one shown)
        ns.ShowSparkles(window.anchor, kind, nil, { lower = ns.SPARKLE_LOWER[node[1]:lower()], -- the saved look, as a preview
            rare = example == "rare", far = example == "far", tooHard = example == "tooHard" })
    elseif ns.SparklePreviews[window.anchor] then
        ns.SparklePreviews[window.anchor]:Hide() -- (off: the node alone, as it would be in the world)
    end
    ShowNode()
end

-- A ticked setting's look on the preview (EXAMPLES) for a few seconds, then the usual look.
function ShowExample(what)
    window.example = what
    window.examples = (window.examples or 0) + 1
    local shown = window.examples
    Refresh()
    C_Timer.After(EXAMPLE_TIME, function()
        if window.examples ~= shown then return end -- another one started since
        window.example = nil
        if window:IsShown() then Refresh() end
    end)
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

-- key: the page to show (a kind, "general", one of the addon's pages, or "sparkles" for the
-- sparkles as they were last shown); nil keeps the last.
local function Open(key)
    if not window then Build() end
    for _, entry in ipairs(ns.WINDOW_PAGES or {}) do
        if entry.key == key then window.tab = entry end
    end
    for _, entry in ipairs(TABS) do
        if entry.key == key then window.tab = entry end
    end
    if key == "sparkles" and window.tab.page then window.tab = TABS[1] end
    window:Show()
    Refresh()
end

-- If opening it errors, the error is still reported, the window stays shut, and
-- from the next reload this version's sparkle settings in the options have Blizzard's rows instead.
local failed
function ns.ShowSparkleWindow(key)
    if failed then return end
    failed = not xpcall(Open, geterrorhandler(), key)
    if failed then
        ns.db.sparkleWindowFailed = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
        if window then window:Hide() end
    end
end

-- After a change made elsewhere (the minimap button).
function ns.RefreshSparkleWindow()
    if window and window:IsShown() then Refresh() end
end
function ns.SparkleWindowShown() return window ~= nil and window:IsShown() end
-- The page shown (a kind, "general" or one of the addon's own).
function ns.SparkleWindowPage() return window and window.tab.key end
function ns.HideSparkleWindow() if window then window:Hide() end end

---------------------------------------------------------------------------
-- Interact Key turned off
---------------------------------------------------------------------------
-- Turned off while sparkles are on: a dialog like the game's offers it back.

local notice

local function DialogButton(parent, text, onClick)
    local button = New("Button", parent)
    button:SetSize(128, 21) -- StaticPopupButtonTemplate's size
    button:SetNormalTexture("Interface\\Buttons\\UI-DialogBox-Button-Up")
    button:GetNormalTexture():SetTexCoord(0, 1, 0, 0.71875)
    button:SetPushedTexture("Interface\\Buttons\\UI-DialogBox-Button-Down")
    button:GetPushedTexture():SetTexCoord(0, 1, 0, 0.71875)
    button:SetHighlightTexture("Interface\\Buttons\\UI-DialogBox-Button-Highlight", "ADD")
    button:GetHighlightTexture():SetTexCoord(0, 1, 0, 0.71875)
    button:SetNormalFontObject(GameFontNormal)
    button:SetHighlightFontObject(GameFontHighlight)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function ShowNotice()
    if not notice then
        notice = New("Frame", UIParent)
        notice:SetFrameStrata("FULLSCREEN_DIALOG") -- (over the settings window, which can open it)
        notice:SetToplevel(true)
        notice:EnableMouse(true)
        notice:SetPoint("TOP", UIParent, "TOP", 0, -135)
        notice:SetWidth(420)
        local background = notice:CreateTexture(nil, "BACKGROUND", nil, -7)
        background:SetAtlas("UI-DialogBox-Background-Dark", true)
        background:SetPoint("TOPLEFT", 7, -7)
        background:SetPoint("BOTTOMRIGHT", -7, 7)
        local edge = notice:CreateTexture(nil, "BACKGROUND", nil, -4)
        edge:SetAtlas("UI-DiamondDialogBox-Border", true)
        edge:SetAllPoints()
        local text = notice:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("TOP", 0, -20)
        text:SetWidth(380)
        text:SetSpacing(3)
        text:SetText(NORMAL_FONT_COLOR:WrapTextInColorCode(C_AddOns.GetAddOnMetadata(ADDON_NAME, "Title") or ADDON_NAME)
            .. "\n\n" .. ns.INTERACT_OFF)
        notice:SetHeight(text:GetStringHeight() + 73)
        notice.text = text
        notice.enable = DialogButton(notice, ENABLE, function()
            notice:Hide()
            ns.Setup()
            if window and window:IsShown() then Refresh() end
        end)
        notice.close = DialogButton(notice, CLOSE, function() notice:Hide() end)
        notice.never = DialogButton(notice, CONFIRM_POPUP_DONT_SHOW_AGAIN, function()
            ns.NoMorePopups()
            notice:Hide()
        end)
        notice.never:SetWidth(math.max(128, notice.never:GetTextWidth() + 24))
        -- The three in a row, the dialog wide enough for them.
        local row = 128 + 8 + 128 + 8 + notice.never:GetWidth()
        notice:SetWidth(math.max(420, row + 40))
        notice.enable:SetPoint("BOTTOMLEFT", notice, "BOTTOM", -row / 2, 16)
        notice.close:SetPoint("LEFT", notice.enable, "RIGHT", 8, 0)
        notice.never:SetPoint("LEFT", notice.close, "RIGHT", 8, 0)
    end
    notice:Show()
end

-- Settings for this character only changed: the other settings are only used after a
-- reload, so a dialog like the game's offers one.
local reloadAsk
function ns.AskReload()
    if not reloadAsk then
        reloadAsk = New("Frame", UIParent)
        reloadAsk:SetFrameStrata("FULLSCREEN_DIALOG") -- (over the settings window, which opens it)
        reloadAsk:SetToplevel(true)
        reloadAsk:EnableMouse(true)
        reloadAsk:SetPoint("TOP", UIParent, "TOP", 0, -135)
        reloadAsk:SetWidth(420)
        local background = reloadAsk:CreateTexture(nil, "BACKGROUND", nil, -7)
        background:SetAtlas("UI-DialogBox-Background-Dark", true)
        background:SetPoint("TOPLEFT", 7, -7)
        background:SetPoint("BOTTOMRIGHT", -7, 7)
        local edge = reloadAsk:CreateTexture(nil, "BACKGROUND", nil, -4)
        edge:SetAtlas("UI-DiamondDialogBox-Border", true)
        edge:SetAllPoints()
        local text = reloadAsk:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("TOP", 0, -20)
        text:SetWidth(380)
        text:SetSpacing(3)
        text:SetText(NORMAL_FONT_COLOR:WrapTextInColorCode(C_AddOns.GetAddOnMetadata(ADDON_NAME, "Title") or ADDON_NAME)
            .. "\n\nSettings for this character only changed. Reload now to switch settings?")
        reloadAsk:SetHeight(text:GetStringHeight() + 73)
        reloadAsk.text = text
        reloadAsk.reload = DialogButton(reloadAsk, RELOADUI, function() ReloadUI() end)
        reloadAsk.cancel = DialogButton(reloadAsk, CANCEL, function() reloadAsk:Hide() end)
        reloadAsk.reload:SetPoint("BOTTOMRIGHT", reloadAsk, "BOTTOM", -4, 16)
        reloadAsk.cancel:SetPoint("BOTTOMLEFT", reloadAsk, "BOTTOM", 4, 16)
    end
    reloadAsk:Show()
end

local interactWatch = CreateFrame("Frame")
interactWatch:RegisterEvent("CVAR_UPDATE")
interactWatch:SetScript("OnEvent", function(_, _, name)
    if issecretvalue(name) or type(name) ~= "string" or name:lower() ~= "softtargetinteract" or not ns.db then return end
    if window and window:IsShown() then Refresh() end
    if ns.InteractOff() then
        ns.AfterFight("interact", function() if ns.InteractOff() then ShowNotice() end end)
    end
end)

ns.SPARKLE_TABS, ns.SPARKLE_NEEDS = TABS, NEEDS -- the Options rows' words with the gamepad UI on
