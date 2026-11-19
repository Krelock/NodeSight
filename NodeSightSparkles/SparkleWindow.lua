-- The sparkle window: a list on the left with each kind of node and the settings for all
-- of them (and the addon's own pages, if it adds any), the styles as tiles with a small
-- preview each (None turns the kind off), the look's settings, and the node in 3D with
-- its sparkles on it, as in the world.
--
-- Sections: Nodes to preview, Changing the look, Building the window, Sparkle Maker,
-- Showing a page, Interact Key turned off.

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
    harvest = true, grayTooHard = true, myProfessions = true, cultivation = true, rareGlow = true, sparkleSound = true,
    gatherDim = true, minimapButton = true, townInteractOff = true, stoneBackground = true }

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
    { key = "maker", name = "Sparkle Maker (Beta)", icon = "Interface\\Icons\\INV_Enchant_EssenceMagicLarge" },
}
-- The game's own icon over each kind when it's the interact target (its cursor's atlas).
local GAME_ICONS = { herbs = "Crosshair_GatherHerbs_64", ore = "Crosshair_Mine_64", chests = "Crosshair_lootall_64",
    quests = "Crosshair_questinteract_64", others = "Crosshair_interact_64", bobber = "Crosshair_interact_64",
    skinning = "Crosshair_Skin_64", loot = "Crosshair_lootall_64" }
-- Added to the on/off box's tooltip.
local NEEDS = " Sparkles turn on the game's Interact Key. Turn them all off (and the Cultivation icon) and your settings go back."

local window -- made the first time it opens

---------------------------------------------------------------------------
-- Changing the look
---------------------------------------------------------------------------

-- The kinds the shown tab changes, and the one whose look it shows (All shows the herbs').
local function Kinds()
    return { window.tab.key }
end
local function Shown()
    local key = window.tab.key
    return (key == "general" or key == "maker" or window.tab.page) and "herbs" or key
end

-- Why sparkles may not show while some are on, most important first: { text, red }.
-- (Enable Interact Key off has a line and button of its own.)
local PROFESSIONS = { herbs = "Herbalism", ore = "Mining", skinning = "Skinning" }
local CVAR_NAMES = { SoftTargetIconGameObject = "Interact Key Icons" }
function ns.RefusedText(cvar)
    return ("Something keeps turning off %s, which sparkles need. Another addon or a setting may be changing it.")
        :format(CVAR_NAMES[cvar] or cvar)
end
local function Problems()
    local list, any = {}, false
    for _, kind in ipairs(ns.KINDS) do any = any or ns.db[kind] == true end
    if not any then return list end
    local cvar = ns.RefusedCVar()
    if cvar then list[#list + 1] = { ns.RefusedText(cvar), true } end
    if ns.SetupPending() then list[#list + 1] = { "Sparkles turn on when this fight ends." } end
    if ns.InteractPaused() then
        list[#list + 1] = { "Nothing sparkles in town: Interact Key off in towns is ticked. Click to change it.", false, "townInteractOff" }
    end
    if ns.db.instanceHide and IsInInstance() then
        list[#list + 1] = { "No sparkles in instances: Hide in instances is ticked. Click to change it.", false, "instanceHide" }
    end
    if ns.db.combatHide and UnitAffectingCombat("player") then
        list[#list + 1] = { "No sparkles in combat: Hide in combat is ticked. Click to change it.", false, "combatHide" }
    end
    if ns.db.myProfessions then
        local missing = {}
        for _, kind in ipairs({ "herbs", "ore", "skinning" }) do
            if ns.db[kind] and not ns.HasProfession(kind) then missing[#missing + 1] = PROFESSIONS[kind] end
        end
        if missing[1] then
            list[#list + 1] = { ("No %s on this character: Only for my professions is ticked. Click to change it.")
                :format(table.concat(missing, " or ")), false, "myProfessions" }
        end
    end
    return list
end

local function Hex(r, g, b)
    return format("ff%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

local Refresh, FrameNode, PlaceCamera, PickStyle, PlayHarvest, ShowExample
local BuildMaker, RefreshMaker, AskDelete, ShowCode, WarnMaker, TileMenu -- (Sparkle Maker)
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

local START_HEIGHT = ns.SPARKLE_START_HEIGHT -- (kinds whose every style starts at one height)
local LookOf = ns.StyleLook -- (style i's look for a kind: as it was left, or the one it comes with)

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
        if what == "gameIcons" or what == "townInteractOff" or what == "cultivation" then ns.Setup() end
        if what == "cultivation" then ns.CultivationRefresh() end
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
        ns.db[keys.style], ns.db[keys.made] = i, nil
        if ns.db[keys.style2] == i then ns.db[keys.style2] = nil end -- (the second one is the first now)
        for _, what in ipairs(LOOK) do ns.db[keys[what]] = look[what] end
        ns.db[kind] = true
    end
    Changed()
    ns.Setup()
    Refresh()
end

-- A Sparkle Maker sparkle for the tab's kinds, in place of their style; it turns them on.
local function PickMade(id)
    for _, kind in ipairs(Kinds()) do
        local keys = ns.SPARKLE_KEYS[kind]
        ns.db[keys.made] = id
        if ns.db[keys.made2] == id then ns.db[keys.made2] = nil end
        ns.db[kind] = true
    end
    Changed()
    ns.Setup()
    Refresh()
end

-- Shift-click: a second style (i) or Sparkle Maker sparkle (id) shown with the first, or
-- taken away again. The first one itself stays as it is.
local function PickSecond(i, id)
    for _, kind in ipairs(Kinds()) do
        local keys = ns.SPARKLE_KEYS[kind]
        local made = ns.FindMade(ns.db[keys.made])
        local first = id and made and made.id == id or i and not made and ns.db[keys.style] == i
        if not first then
            local again = i and ns.db[keys.style2] == i or id and ns.db[keys.made2] == id
            ns.db[keys.style2], ns.db[keys.made2] = not again and i or nil, not again and id or nil
            ns.db[kind] = true
        end
    end
    Changed()
    ns.Setup()
    Refresh()
end

-- The kind's style and look as they come (on or off stays as it is).
local function Defaults()
    for _, kind in ipairs(Kinds()) do
        local keys = ns.SPARKLE_KEYS[kind]
        ns.db[keys.style], ns.db[keys.made], ns.db[keys.style2], ns.db[keys.made2] = ns.defaults[keys.style], nil, nil, nil
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
local function Tooltip(frame, title, text, hint)
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(type(title) == "function" and title() or title)
        local body = type(text) == "function" and text() or text
        if body then GameTooltip:AddLine(body, 1, 1, 1, true) end
        local green = hint and hint() -- (an instruction line, green as Blizzard's)
        if green then GameTooltip:AddLine(green, GREEN_FONT_COLOR:GetRGB()) end
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
local PREVIEW_WIDTH = 288 -- the preview's
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

-- A tile like the Toy Box's (five across; Refresh places it) with a name at its bottom.
local function BareTile(grid, name)
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
    tile.name = Label(tile, name, "GameFontNormalSmall")
    tile.name:SetPoint("BOTTOM", 0, 8)
    return tile
end

-- A tile with a small preview of sparkles (a light beam stays inside).
local function PreviewTile(grid, name)
    local tile = BareTile(grid, name)
    tile:SetClipsChildren(true)
    tile.anchor = New("Frame", tile) -- the sparkles sit on its bottom, like on a nameplate's
    tile.anchor:SetSize(1, 1)
    tile.anchor:SetPoint("BOTTOM", tile, "CENTER", 0, 10)
    return tile
end

-- What Shift-click does with a kind's tile (style i or made sparkle id): nothing on the first one.
local function SecondHint(i, id)
    local keys = ns.SPARKLE_KEYS[Shown()]
    local made = ns.FindMade(ns.db[keys.made])
    if id and made and made.id == id or i and not made and ns.db[keys.style] == i then return nil end
    if i and ns.db[keys.style2] == i or id and ns.db[keys.made2] == id then return "<Shift Click to remove it>" end
    return "<Shift Click to add it as a second sparkle>"
end

-- A style's tile: its name and a small preview of it; a click picks it.
local function Tile(grid, i, style)
    local tile = PreviewTile(grid, style.name)
    tile:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        if IsShiftKeyDown() then PickSecond(i) else PickStyle(i) end
    end)
    Tooltip(tile, style.name, style.tip, function() return SecondHint(i) end)
    return tile
end

-- A Sparkle Maker sparkle's tile (Refresh gives it its sparkle: tile.id, tile.title).
local function MadeTile(grid)
    local tile = PreviewTile(grid, "")
    tile.name:SetWidth(76)
    tile.name:SetWordWrap(false)
    tile:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        if IsShiftKeyDown() then PickSecond(nil, tile.id) else PickMade(tile.id) end
    end)
    Tooltip(tile, function() return tile.title end, "Made in the Sparkle Maker.", function() return SecondHint(nil, tile.id) end)
    return tile
end

-- The first tile: no sparkles on the kind.
local function NoneTile(grid)
    local tile = BareTile(grid, NONE)
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

-- A setting shown from a warning: Blizzard's proc glow round its box for a few seconds.
local FLASH_SECONDS = 3
local function Flash(box)
    local flash = window.flash
    if not (flash and box) then return end
    flash:ClearAllPoints()
    flash:SetPoint("CENTER", box)
    flash:SetSize(box:GetWidth() * 1.4, box:GetHeight() * 1.4)
    flash:Show()
    flash.ProcLoop:Play()
    flash.token = (flash.token or 0) + 1
    local token = flash.token
    C_Timer.After(FLASH_SECONDS, function() if flash.token == token then flash:Hide() end end)
end

-- The style grid is as tall as the biggest tab's tiles need: None, its styles and the made sparkles, five a row.
local function GridHeight()
    return floor((window.mostTiles + #ns.MadeList() + 4) / 5) * 80 - 4
end

local function Build()
    local most = 0
    for _, tab in ipairs(TABS) do
        local n = 0
        for i in ipairs(ns.SPARKLE_STYLES) do
            if ns.StyleFits(i, tab.key) then n = n + 1 end
        end
        most = max(most, n + 1)
    end
    window = New("Frame", UIParent, "ButtonFrameTemplate")
    window.mostTiles = most
    local gridHeight = GridHeight()
    window.gridHeight = gridHeight
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
    -- The logo in the frame's own bronze ring, filling its hole, in place of the
    -- portrait (whose round mask sits off the ring's middle). Under the ring, as the
    -- portrait is.
    local corner = window.NineSlice and window.NineSlice.TopLeftCorner
    if corner then
        local size = corner:GetWidth()
        if not (size and size > 0) then size = 95 end
        window.PortraitContainer.portrait:Hide()
        local art = window.PortraitContainer:CreateTexture(nil, "OVERLAY")
        art:SetSize(size * 0.51, size * 0.51) -- (a little past the hole, under the ring)
        art:SetPoint("CENTER", corner, "TOPLEFT", size * 0.401, -size * 0.401) -- (the ring's middle in the art)
        art:SetTexture(logo)
        local mask = window.PortraitContainer:CreateMaskTexture()
        mask:SetAllPoints(art)
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        art:AddMaskTexture(mask)
        window.logo = art
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
    -- Otherwise the first reason sparkles may not show, with all of them in its tooltip.
    local problem = New("Frame", window)
    problem:SetPoint("TOP", 0, -36)
    problem:EnableMouse(true)
    problem.text = Label(problem, "", "GameFontRed")
    problem.text:SetPoint("CENTER")
    Tooltip(problem, "Why sparkles may not show", function()
        local lines = {}
        for i, reason in ipairs(problem.list or {}) do lines[i] = reason[1] end
        return table.concat(lines, "\n")
    end)
    -- A reason with a setting: clicked, Sparkle settings with that box flashing.
    problem:SetScript("OnMouseUp", function()
        local key = problem.list and problem.list[1] and problem.list[1][3]
        if not key then return end
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        for _, entry in ipairs(TABS) do
            if entry.key == "general" then window.tab = entry end
        end
        Refresh()
        Flash(window[key])
    end)
    window.problem = problem
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
    preview:SetWidth(PREVIEW_WIDTH)
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
    -- In its place on a herb, the Cultivation icon while its switch is on (it covers the game's icon in the world).
    if ns.CultivationPreviewIcon then window.cultivationIcon = ns.CultivationPreviewIcon(over, window.gameIcon) end
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
    window.gameIcons, window.iconsRow = box, icons

    -- The styles.
    -- A kind's page: its name and a gray line on it on top (like the addon's own pages), then the styles.
    window.kindTitle = Label(window.Inset, "", "GameFontHighlightLarge")
    window.kindTitle:SetPoint("TOPLEFT", preview, "TOPRIGHT", 12, -12)
    window.kindAbout = Label(window.Inset, "", "GameFontDisableSmall")
    window.kindAbout:SetPoint("TOPLEFT", preview, "TOPRIGHT", 12, -36)
    local grid = New("Frame", window.Inset)
    grid:SetPoint("TOPLEFT", preview, "TOPRIGHT", 10, -58)
    grid:SetSize(428, gridHeight)
    window.grid, window.tiles, window.madeTiles = grid, {}, {}
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
    -- While the kind uses a Sparkle Maker sparkle: its name and a button to it, in place of the style's look.
    local note = New("Frame", panel)
    note:SetAllPoints()
    note.text = Label(note, "", "GameFontHighlight")
    note.text:SetPoint("LEFT", note, "TOPLEFT", 0, -36)
    note.edit = New("Button", note, "UIPanelButtonTemplate")
    note.edit:SetSize(150, 22)
    note.edit:SetText("Open Sparkle Maker")
    note.edit:SetPoint("LEFT", note, "TOPLEFT", 0, -70)
    note.edit:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        window.madeId, window.makerLayer = note.id, 1
        for _, entry in ipairs(TABS) do
            if entry.key == "maker" then window.tab = entry end
        end
        Refresh()
    end)
    window.madeNote = note
    local outer = panel
    panel = New("Frame", outer) -- (the style's look)
    panel:SetAllPoints()
    window.lookRows = panel
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
    window.look, window.preview = { grid, outer, window.kindTitle, window.kindAbout }, preview
    local general = New("Frame", window.Inset)
    general:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, 38) -- (as high as the kind's name)
    general:SetPoint("BOTTOMRIGHT", -8, 8)
    window.general = general
    local function At(box, x) -- its words first, the box right after them (as in Blizzard's options)
        x = x or 0
        local y = select(5, box:GetPoint(1))
        local width = 170 -- (a longer label wraps instead of reaching the next column)
        box.label:ClearAllPoints()
        box.label:SetPoint("LEFT", general, "TOPLEFT", x, y)
        box.label:SetWidth(width)
        box.label:SetJustifyH("LEFT")
        box:ClearAllPoints()
        box:SetPoint("LEFT", general, "TOPLEFT", x + width + 4, y)
        box.hover:ClearAllPoints()
        box.hover:SetPoint("LEFT", box.label, "LEFT")
        box.hover:SetSize(width + 4, 26)
        box.hover:SetScript("OnMouseDown", function() box:Click() end) -- its words click it too
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
    window.cultivation = At(Checkbox(general, -396, "Show when Cultivation is ready", "cultivation",
        "Tauren: the Cultivation icon over a herb you can cultivate now. Works without herb sparkles and without Herbalism. Like sparkles, it turns on the game's Interact Key."))
    window.own = At(Checkbox(general, -428, "Settings for this character only", "own",
        "This character keeps its own settings. Untick it to use the settings your other characters share. It offers a reload to switch."))
    window.stone = At(Checkbox(general, -428, "Stone background", "stoneBackground",
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
        -- (On the page, so it goes when another page is picked.)
        window.flash = New("Frame", general, "ActionButtonSpellAlertTemplate")
        window.flash.ProcStartFlipbook:Hide()
        window.flash:SetFrameLevel(window.everything:GetFrameLevel() + 2)
        window.flash:Hide()
    end

    BuildMaker(grid)

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
-- Sparkle Maker
---------------------------------------------------------------------------
-- Sparkles built from up to two of Blizzard's 3D effects and three styles, each layer
-- with its own look and a looping animation (laid out like WeakAuras' model and
-- animation options). They are saved for every character (ns.MadeList) and show as
-- tiles on every kind's page. A share code carries one as text:
-- NS2:name:effect:effect:style:style:style, each part "-" when empty (an effect: its
-- file, or d and a creature's display; size, height, sideways, turn, tilt, see-through,
-- particles, speed, animation, its speed; a style: its name, size, height, sideways,
-- count, two colors, see-through, animation, its speed). NS1 codes (one effect, two
-- styles, no motion) are still read.

local CODE = "NS2"
local LABEL = 90 -- the page's labels' column
-- Settings of a layer, two to a row: an effect's, a style's (after its colors).
local EFFECT_ROWS = { { "size", "height" }, { "x", "turn" }, { "tilt", "alpha" }, { "particles", "speed" }, { "animSpeed" } }
local STYLE_ROWS = { { "size", "height" }, { "x", "count" }, { "alpha", "animSpeed" } }
local PARTS = {
    size = { "Area", "How big this layer is." },
    height = { "Height", "Moves this layer up or down." },
    x = { "Sideways", "Moves this layer left or right." },
    count = { "Count", "How many sparkles show at once. Some styles don't use it." },
    turn = { "Turn", "Turns the effect round, in degrees." },
    tilt = { "Tilt", "Tips the effect toward you or away, in degrees." },
    alpha = { "See-through", "How much of this layer shows, in percent." },
    particles = { "Particles", "How big the effect's sparks and motes are, in percent." },
    speed = { "Speed", "How fast the effect plays, in percent. 0 stops it." },
    animSpeed = { "Loop speed", "How fast the animation loops, in percent." },
}
local ANIM_TIPS = {
    None = "Stays still.", Pulse = "Grows and shrinks.", Breathe = "Fades a little and back.",
    Bob = "Floats up and down.", Orbit = "Circles round its place.", Spin = "Turns round and round.",
}
-- The sparkle the page shows: the one picked, else the first.
local function Current()
    return ns.FindMade(window.madeId) or ns.MadeList()[1]
end

-- A name fit for a code: no separators or escape codes, 24 letters at most.
local function CleanName(name)
    name = tostring(name or ""):gsub("[:,|]", ""):gsub("^%s+", "")
    return (name:sub(1, 24):gsub("%s+$", ""))
end

local EFFECT_KEYS = { "size", "height", "x", "turn", "tilt", "alpha", "particles", "speed", "animSpeed" }
local STYLE_KEYS = { "size", "height", "x", "count", "alpha", "animSpeed" }

-- A cleaned sparkle (ns.CleanMade) as it is saved: styles by name.
local function Saved(clean, id)
    local sparkle = { id = id, name = CleanName(clean.name), effects = {}, layers = {} }
    if sparkle.name == "" then sparkle.name = "Sparkle" end
    for i, look in ipairs(clean.effects) do
        local saved = { file = look.file, display = look.display, anim = look.anim }
        for _, what in ipairs(EFFECT_KEYS) do saved[what] = look[what] end
        sparkle.effects[i] = saved
    end
    for i, look in ipairs(clean.layers) do
        local saved = { style = ns.SPARKLE_STYLES[look.style].name, color = look.color, color2 = look.color2, anim = look.anim }
        for _, what in ipairs(STYLE_KEYS) do saved[what] = look[what] end
        sparkle.layers[i] = saved
    end
    return sparkle
end

local function NextId()
    local id = 0
    for _, sparkle in ipairs(ns.MadeList()) do
        if type(sparkle) == "table" and type(sparkle.id) == "number" then id = max(id, sparkle.id) end
    end
    return id + 1
end

-- Saves a new sparkle and shows it; false when the list is full.
local function Add(clean)
    local list = ns.MadeList()
    if not clean or #list >= ns.MADE_MAX then return false end
    local sparkle = Saved(clean, NextId())
    list[#list + 1] = sparkle
    window.madeId, window.makerLayer = sparkle.id, clean.effects[1] and 1 or 3
    return true
end

local function MadeCode(sparkle)
    local clean = ns.CleanMade(sparkle)
    if not clean then return "" end
    local parts = { CODE, CleanName(clean.name), "-", "-", "-", "-", "-" }
    for i, look in ipairs(clean.effects) do
        parts[2 + i] = ("%s,%d,%d,%d,%d,%d,%d,%d,%d,%s,%d"):format(look.display and "d" .. look.display or look.file, look.size,
            look.height, look.x, look.turn, look.tilt, look.alpha, look.particles, look.speed, look.anim, look.animSpeed)
    end
    for i, look in ipairs(clean.layers) do
        parts[4 + i] = ("%s,%d,%d,%d,%d,%s,%s,%d,%s,%d"):format(ns.SPARKLE_STYLES[look.style].name, look.size, look.height,
            look.x, look.count, look.color, look.color2, look.alpha, look.anim, look.animSpeed)
    end
    return table.concat(parts, ":")
end

local NUMBER = "(%-?%d+)"
-- A code back into a sparkle (cleaned, not saved); nil if it isn't one.
local function FromCode(text)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local fields = {}
    for field in (text .. ":"):gmatch("([^:]*):") do fields[#fields + 1] = field end
    local sparkle = { name = fields[2], effects = {}, layers = {} }
    if fields[1] == "NS1" and #fields == 5 then
        if fields[3] ~= "-" then
            local file, size, height = fields[3]:match("^(%d+),(%-?%d+),(%-?%d+)$")
            if not file then return nil end
            sparkle.effects[1] = { file = tonumber(file), size = tonumber(size), height = tonumber(height) }
        end
        for i = 4, 5 do
            if fields[i] ~= "-" then
                local style, size, height, count, one, two = fields[i]:match("^([^,]+),(%-?%d+),(%-?%d+),(%d+),(%x+),(%x+)$")
                if not style then return nil end
                sparkle.layers[#sparkle.layers + 1] = { style = style, size = tonumber(size), height = tonumber(height),
                    count = tonumber(count), color = one, color2 = two }
            end
        end
        return ns.CleanMade(sparkle)
    end
    if fields[1] ~= CODE or #fields ~= 7 then return nil end
    local effectPattern = "^(d?%d+)," .. ("%s,"):rep(8):format(NUMBER, NUMBER, NUMBER, NUMBER, NUMBER, NUMBER, NUMBER, NUMBER) .. "(%a+)," .. NUMBER .. "$"
    for i = 3, 4 do
        if fields[i] ~= "-" then
            local v = { fields[i]:match(effectPattern) }
            if not v[1] then return nil end
            local look = { anim = v[10], animSpeed = tonumber(v[11]) }
            if v[1]:sub(1, 1) == "d" then look.display = tonumber(v[1]:sub(2)) else look.file = tonumber(v[1]) end
            for j, what in ipairs({ "size", "height", "x", "turn", "tilt", "alpha", "particles", "speed" }) do look[what] = tonumber(v[j + 1]) end
            sparkle.effects[#sparkle.effects + 1] = look
        end
    end
    local stylePattern = "^([^,]+)," .. ("%s,"):rep(4):format(NUMBER, NUMBER, NUMBER, NUMBER) .. "(%x+),(%x+)," .. NUMBER .. ",(%a+)," .. NUMBER .. "$"
    for i = 5, 7 do
        if fields[i] ~= "-" then
            local v = { fields[i]:match(stylePattern) }
            if not v[1] then return nil end
            sparkle.layers[#sparkle.layers + 1] = { style = v[1], size = tonumber(v[2]), height = tonumber(v[3]), x = tonumber(v[4]),
                count = tonumber(v[5]), color = v[6], color2 = v[7], alpha = tonumber(v[8]), anim = v[9], animSpeed = tonumber(v[10]) }
        end
    end
    return ns.CleanMade(sparkle)
end

-- A layer of a saved sparkle: 1 and 2 its effects, 3 to 5 its styles; nil when empty.
local function LayerLook(sparkle, layer)
    if layer <= 2 then return (type(sparkle.effects) == "table" and sparkle.effects or { sparkle.effect })[layer] end
    return type(sparkle.layers) == "table" and sparkle.layers[layer - 2] or nil
end

-- Changes a saved sparkle (the one shown unless id says), keeps it within its limits,
-- then the sparkles and the page.
-- Undo: copies of sparkles as they were before each change, newest last. Changes less
-- than half a second apart (a slider or the mouse wheel going) are taken back as one.
local undo = {}
local function Remember(sparkle, force)
    local now = GetTime()
    local last = undo[#undo]
    if not force and last and last.id == sparkle.id and undo.at and now - undo.at < 0.5 then
        undo.at = now
        return
    end
    undo.at = now
    undo[#undo + 1] = CopyTable(sparkle)
    if #undo > 50 then table.remove(undo, 1) end
end

local function Edit(change, id, remembered)
    local sparkle = id and ns.FindMade(id) or Current()
    if not sparkle then return end
    if not remembered then Remember(sparkle) end
    if type(sparkle.effects) ~= "table" then sparkle.effects, sparkle.effect = { sparkle.effect }, nil end -- (a first-version save)
    if type(sparkle.layers) ~= "table" then sparkle.layers = {} end
    change(sparkle)
    local clean = ns.CleanMade(sparkle)
    if clean then
        local saved = Saved(clean, sparkle.id)
        for key in pairs(sparkle) do sparkle[key] = nil end
        for key, value in pairs(saved) do sparkle[key] = value end
    end
    Changed()
    Refresh()
end

-- The last change taken back (one to a sparkle since deleted is passed over).
local function Undo()
    local list = ns.MadeList()
    while #undo > 0 do
        local was = table.remove(undo)
        for i, sparkle in ipairs(list) do
            if type(sparkle) == "table" and sparkle.id == was.id then
                list[i], window.madeId, undo.at = was, was.id, nil
                Changed()
                return Refresh()
            end
        end
    end
end

local function DeleteMade(id)
    local list = ns.MadeList()
    for i = #list, 1, -1 do
        if type(list[i]) == "table" and list[i].id == id then table.remove(list, i) end
    end
    for _, kind in ipairs(ns.KINDS) do
        for _, key in ipairs({ ns.SPARKLE_KEYS[kind].made, ns.SPARKLE_KEYS[kind].made2 }) do
            if ns.db[key] == id then ns.db[key] = nil end
        end
    end
    window.madeId = nil
    Changed()
    Refresh()
end
ns.DeleteMade = DeleteMade

local function Added(clean)
    if Add(clean) then
        Changed()
    else
        window.maker.said, window.maker.saidRed = ("You have %d sparkles. Delete one first."):format(ns.MADE_MAX), true
    end
    Refresh()
end

-- A new sparkle: one layer of twinkles in gold and white.
local function NewMade()
    Added(ns.CleanMade({ name = "Sparkle " .. (#ns.MadeList() + 1), effects = {},
        layers = { { style = "Twinkle", color = "ffffd100", color2 = "ffffffff" } } }))
end

local function CopyMade(id)
    local clean = ns.CleanMade(ns.FindMade(id))
    if not clean then return end
    clean.name = CleanName(clean.name:sub(1, 19) .. " copy")
    Added(clean)
end

-- The styles a layer can have: those made for every kind.
local function LayerStyles()
    local list = {}
    for i, style in ipairs(ns.SPARKLE_STYLES) do
        if not style.only then list[#list + 1] = i end
    end
    return list
end

local function Pick(list) return list[math.random(#list)] end

-- A random sparkle: most often an effect, one or two styles in a color set, now and then an animation.
local function RandomMade()
    local sparkle = { name = "Random " .. (#ns.MadeList() + 1), effects = {}, layers = {} }
    if math.random() < 0.8 then
        local anim = math.random() < 0.4 and Pick({ "Pulse", "Breathe", "Spin" }) or "None"
        local effect = Pick(ns.SPARKLE_EFFECTS)
        sparkle.effects[1] = { file = effect.file, display = effect.display, size = math.random(80, 160), turn = math.random(0, 359), anim = anim }
    end
    for i = 1, math.random(1, 2) do
        local set = Pick(SETS)
        local anim = math.random() < 0.3 and Pick({ "Pulse", "Breathe", "Bob", "Orbit" }) or "None"
        sparkle.layers[i] = { style = ns.SPARKLE_STYLES[Pick(LayerStyles())].name, size = math.random(70, 130),
            count = math.random(5, 12), color = set[2], color2 = set[3], anim = anim }
    end
    Added(ns.CleanMade(sparkle))
end

-- what: "color" or "color2" of the shown style layer. Cancel puts both back.
local function PickLayerColor(what)
    local sparkle = Current()
    local layer = window.makerLayer
    local look = sparkle and layer > 2 and LayerLook(sparkle, layer)
    if not look then return end
    local id, before = sparkle.id, { look.color, look.color2 }
    local r, g, b = ns.SparkleRGB(look[what] or look.color)
    local start, moved = Hex(r, g, b), false
    ColorPickerFrame:SetupColorPickerAndShow({ r = r, g = g, b = b, hasOpacity = false,
        swatchFunc = function()
            local hex = Hex(ColorPickerFrame:GetColorRGB())
            if hex == start and not moved then return end
            moved = true
            Edit(function(s)
                local l = LayerLook(s, layer)
                if l then l[what] = hex end
            end, id)
        end,
        cancelFunc = function()
            Edit(function(s)
                local l = LayerLook(s, layer)
                if l then l.color, l.color2 = before[1], before[2] end
            end, id)
        end })
end

-- The shown layer's effect or style.
-- choice: an effect's entry, or a style's index. A layer of the other kind becomes one of
-- this kind in its place (its size, place and animation kept), as one gallery has both.
local function PickLayer(choice)
    local layer, isStyle = window.makerLayer, type(choice) == "number"
    Edit(function(sparkle)
        local look = LayerLook(sparkle, layer)
        if not look then return end
        if (layer > 2) == isStyle then
            if isStyle then look.style = ns.SPARKLE_STYLES[choice].name else look.file, look.display = choice.file, choice.display end
            return
        end
        local new = { size = look.size, height = look.height, x = look.x, alpha = look.alpha, anim = look.anim, animSpeed = look.animSpeed }
        if layer <= 2 then table.remove(sparkle.effects, layer) else table.remove(sparkle.layers, layer - 2) end
        if window.hidden then window.hidden[sparkle.id] = nil end
        if isStyle then
            local start = ns.SPARKLE_STYLES[choice].start
            new.style, new.count, new.color, new.color2 = ns.SPARKLE_STYLES[choice].name, start.count, start.color, start.color2 or start.color
            sparkle.layers[#sparkle.layers + 1] = new
            window.makerLayer = #sparkle.layers + 2
        else
            new.file, new.display = choice.file, choice.display
            sparkle.effects[#sparkle.effects + 1] = new
            window.makerLayer = #sparkle.effects
        end
    end)
end

-- A new layer: twinkles with their own look while there's room for a style, else the first
-- effect; the gallery then changes it to anything.
local function AddLayer()
    Edit(function(sparkle)
        local effect = #sparkle.layers >= ns.MADE_MAX_LAYERS
        if effect and #sparkle.effects >= ns.MADE_MAX_EFFECTS then return end
        if effect then
            local first = ns.SPARKLE_EFFECTS[1]
            sparkle.effects[#sparkle.effects + 1] = { file = first.file, display = first.display }
            window.makerLayer = #sparkle.effects
        else
            local style = ns.SPARKLE_STYLES[1]
            sparkle.layers[#sparkle.layers + 1] = { style = style.name, size = style.start.size, height = style.start.height,
                count = style.start.count, color = style.start.color, color2 = style.start.color2 or style.start.color }
            window.makerLayer = #sparkle.layers + 2
        end
    end)
end

-- Takes a layer away; the first one left is shown next. Eyes closed on the preview open
-- again (the layers after it moved up).
local function RemoveLayer(layer)
    Edit(function(sparkle)
        if not LayerLook(sparkle, layer) then return end
        if layer <= 2 then table.remove(sparkle.effects, layer) else table.remove(sparkle.layers, layer - 2) end
        if window.hidden then window.hidden[sparkle.id] = nil end
        window.makerLayer = nil
    end)
end

-- The layers in use, in their drawing order: { layer = 1 to 5, look }.
local function UsedLayers(sparkle)
    local used = {}
    local effects = type(sparkle.effects) == "table" and sparkle.effects or { sparkle.effect }
    for i = 1, 2 do
        if type(effects[i]) == "table" then used[#used + 1] = { layer = i, look = effects[i] } end
    end
    for i = 1, 3 do
        local look = type(sparkle.layers) == "table" and sparkle.layers[i]
        if type(look) == "table" then used[#used + 1] = { layer = 2 + i, look = look } end
    end
    return used
end

-- A label at the page's left and its control in the next column.
local function MakerRow(page, y, text, control, tip, x)
    local label = Label(page, text, x and "GameFontNormalSmall" or "GameFontNormal")
    label:SetPoint("LEFT", page, "TOPLEFT", x or 0, y)
    control:SetPoint("LEFT", page, "TOPLEFT", (x or 0) + (x and 66 or LABEL), y)
    if tip then
        Tooltip(control, text, tip)
        local hover = New("Frame", page)
        hover:SetPoint("LEFT", label, "LEFT")
        hover:SetSize(x and 64 or LABEL - 4, 26)
        hover:EnableMouse(true)
        Tooltip(hover, text, tip)
        return label, hover
    end
    return label
end

-- A slider for a part of the shown layer's look (Refresh places it in its row).
local function MakerSlider(page, what)
    local limits, words = ns.MADE_LIMITS[what], PARTS[what]
    local slider = New("Frame", page, "MinimalSliderWithSteppersTemplate")
    slider:SetWidth(110)
    local formatters = { [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right) }
    slider:Init(limits[1], limits[1], limits[2], limits[2] - limits[1], formatters)
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        if window.refreshing then return end
        local layer = window.makerLayer
        Edit(function(sparkle)
            local look = LayerLook(sparkle, layer)
            if look then look[what] = floor(value + 0.5) end
        end)
    end, slider)
    slider.label = Label(page, words[1], "GameFontNormalSmall")
    slider.hover = New("Frame", page)
    slider.hover:SetSize(64, 26)
    slider.hover:EnableMouse(true)
    Tooltip(slider.hover, words[1], words[2])
    for _, part in ipairs({ slider.Slider, slider.Back, slider.Forward }) do Tooltip(part, words[1], words[2]) end
    return slider
end

-- A text box like the game's (Blizzard's input box template).
local function TextBox(page, width)
    local box = New("EditBox", page, "InputBoxTemplate")
    box:SetSize(width, 20)
    box:SetAutoFocus(false)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return box
end

local function SmallButton(page, text, width, onClick)
    local button = New("Button", page, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetText(text)
    button:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        onClick()
    end)
    return button
end

local function Dropdown(page, width)
    local dropdown = New("DropdownButton", page, "WowStyle1DropdownTemplate")
    dropdown:SetWidth(width)
    return dropdown
end

-- The preview is the page's workspace: tools on it, the layers along its bottom, and the
-- sparkles as tiles over the page.
local PREVIEW_MAKER = 640 -- the preview's width on this page
local MAKER_HEIGHT = 700 -- the window at least this high on this page
local CHIP_WIDTH = 100 -- a layer's chip in the strip
local TILE_STEP = 108 -- the gallery's tiles, four across
local STEP = 32 -- between Fine-tune's rows of sliders
local GALLERY_ROWS, TILE_HEIGHT = 3, 64
local ANIMS_SHOWN = { "None", "Pulse", "Breathe", "Bob", "Orbit", "Spin" }

-- The effects' and the styles' groups, in the order the lists first have them (filled with the page).
local GROUPS, STYLE_GROUPS = {}, {}
local function FindGroups()
    local seen = {}
    for _, effect in ipairs(ns.SPARKLE_EFFECTS) do
        if not seen[effect.group] then GROUPS[#GROUPS + 1], seen[effect.group] = effect.group, true end
    end
    seen = {}
    for _, i in ipairs(LayerStyles()) do
        local group = ns.SPARKLE_STYLES[i].group
        if group and not seen[group] then STYLE_GROUPS[#STYLE_GROUPS + 1], seen[group] = group, true end
    end
end

-- Layers hidden on the preview while the others are worked on (not saved): by sparkle, then layer.
local function HiddenLayers(sparkle)
    window.hidden = window.hidden or {}
    window.hidden[sparkle.id] = window.hidden[sparkle.id] or {}
    return window.hidden[sparkle.id]
end

local function ToggleHidden(layer)
    local sparkle = Current()
    if not sparkle then return end
    local hidden = HiddenLayers(sparkle)
    hidden[layer] = not hidden[layer] or nil
    Refresh()
end

-- A layer's chip in the strip under the sparkle: its icon (an effect's, or a style's first
-- color), name and kind, an eye that hides it on the preview, and a cross that takes it out.
local function LayerRow(page)
    local row = New("Button", page)
    row.selected = row:CreateTexture(nil, "BACKGROUND")
    row.selected:SetColorTexture(46 / 255, 38 / 255, 27 / 255) -- (as the window's list)
    row.selected:SetAllPoints()
    row.bar = row:CreateTexture(nil, "BORDER")
    row.bar:SetColorTexture(1, 0.82, 0)
    row:SetHighlightAtlas("Options_List_Hover")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(14, 14)
    row.text = Label(row, "", "GameFontHighlight")
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row.kind = Label(row, "", "GameFontDisableSmall")
    row.eye = New("Button", row)
    row.eye:SetSize(20, 20)
    row.eye.art = row.eye:CreateTexture(nil, "ARTWORK")
    row.eye.art:SetAllPoints()
    row.eye:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        ToggleHidden(row.layer)
    end)
    Tooltip(row.eye, "Show or hide", "Hides this layer on the preview.")
    row.remove = New("Button", row)
    row.remove:SetSize(14, 14)
    row.remove:SetNormalAtlas("common-icon-redx")
    row.remove:SetHighlightAtlas("common-icon-redx", "ADD")
    row.remove:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        RemoveLayer(row.layer)
    end)
    Tooltip(row.remove, REMOVE, "Takes this layer out of the sparkle.")
    row:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        window.makerLayer = row.layer
        Refresh()
    end)
    -- Name on top, kind under it, a gold bar along its bottom.
    row:SetSize(CHIP_WIDTH, 40)
    row.bar:SetPoint("BOTTOMLEFT")
    row.bar:SetPoint("BOTTOMRIGHT")
    row.bar:SetHeight(2)
    row.icon:SetPoint("TOPLEFT", 6, -6)
    row.text:SetPoint("TOPLEFT", 24, -6)
    row.text:SetWidth(CHIP_WIDTH - 44)
    row.kind:SetPoint("TOPLEFT", 24, -22)
    row.remove:SetPoint("TOPRIGHT", -4, -5)
    row.eye:SetPoint("BOTTOMRIGHT", -2, 2)
    return row
end

local EFFECT_ICON = "Interface\\Icons\\INV_Enchant_EssenceMagicLarge" -- (the Sparkle Maker's own, in the window's list)
local STAR = 131010 -- Interface\\Cooldown\\star4: a style's chip, in its first color

-- A style's entry (by its saved name), or nil.
local function StyleEntry(look)
    for _, style in ipairs(ns.SPARKLE_STYLES) do
        if style.name == look.style then return style end
    end
end

-- An effect's entry in the list (by its file or display), or nil.
local function EffectEntry(look)
    for _, effect in ipairs(ns.SPARKLE_EFFECTS) do
        if look.display and effect.display == look.display or not look.display and effect.file == tonumber(look.file) then return effect end
    end
end

-- The sparkle being made on the preview's node (lower: that node's, as Refresh found it),
-- without the layers hidden with their eye.
local function ShowMadePreview()
    local sparkle = Current()
    local hidden = sparkle and window.hidden and window.hidden[sparkle.id]
    if hidden and next(hidden) then
        local shown = { effects = {}, layers = {} }
        for _, entry in ipairs(UsedLayers(sparkle)) do
            if not hidden[entry.layer] then
                local list = entry.layer <= 2 and shown.effects or shown.layers
                list[#list + 1] = entry.look
            end
        end
        sparkle = (shown.effects[1] or shown.layers[1]) and shown or nil
    end
    if sparkle then
        ns.ShowSparkles(window.anchor, Shown(), nil, { made = sparkle, lower = window.previewLower })
    elseif ns.SparklePreviews[window.anchor] then
        ns.SparklePreviews[window.anchor]:Hide()
    end
end

-- A tile in the gallery: an effect or a style playing on it, its name under it.
local function GalleryTile(page)
    local tile = PreviewTile(page, "")
    tile.name:SetWidth(98)
    tile.name:SetWordWrap(false)
    tile:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        PickLayer(tile.choice)
    end)
    Tooltip(tile, function() return tile.title end, function() return tile.tip end)
    return tile
end

-- A sparkle's tile; the last one makes a new one.
-- A tile's right-click menu: a sparkle's Copy, share code and Delete; the New tile's
-- Random and Import.
function TileMenu(tile)
    local id, room = tile.id, #ns.MadeList() < ns.MADE_MAX
    MenuUtil.CreateContextMenu(tile, function(_, root)
        if not id then
            root:CreateButton("New", NewMade)
            root:CreateButton("Random", RandomMade)
            root:CreateButton("Import a code", function() ShowCode(nil) end)
            return
        end
        root:CreateTitle(tile.title)
        root:CreateButton("Copy", function() CopyMade(id) end):SetEnabled(room)
        root:CreateButton("Copy share code", function() if ns.FindMade(id) then ShowCode(ns.FindMade(id)) end end)
        root:CreateDivider()
        root:CreateButton(DELETE, function() if ns.FindMade(id) then AskDelete(ns.FindMade(id)) end end)
    end)
end

local function SparkleTile(page)
    local tile = PreviewTile(page, "")
    tile:SetSize(84, 64)
    tile.name:SetWidth(78)
    tile.name:SetWordWrap(false)
    tile.plus = Label(tile, "+", "GameFontNormalHuge")
    tile.plus:SetPoint("CENTER", 0, 6)
    tile:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    tile:SetScript("OnClick", function(_, button)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        if button == "RightButton" then return TileMenu(tile) end
        if not tile.id then return NewMade() end
        window.madeId, window.makerLayer = tile.id, nil
        Refresh()
    end)
    Tooltip(tile, function() return tile.title end, function()
        return tile.id and "Saved for all your characters." or "A new sparkle: gold and white twinkles."
    end, function()
        return tile.id and "<Right Click to Copy, Share or Delete>" or "<Right Click for Random or Import>"
    end)
    return tile
end

-- A text tab: gold words, white and underlined when picked.
local function TextTab(page, text, onClick)
    local tab = New("Button", page)
    tab.text = Label(tab, text, "GameFontNormalSmall")
    tab.text:SetPoint("LEFT")
    tab:SetSize(tab.text:GetStringWidth() + 2, 18)
    tab.line = tab:CreateTexture(nil, "ARTWORK")
    tab.line:SetColorTexture(1, 0.82, 0)
    tab.line:SetHeight(1)
    tab.line:SetPoint("BOTTOMLEFT")
    tab.line:SetPoint("BOTTOMRIGHT")
    tab:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        onClick()
    end)
    return tab
end

-- A tab over the gallery: a section of the effects or the styles.
local function GroupTab(page, group)
    return TextTab(page, group, function()
        window.galleryGroup, window.galleryPage = group, 1
        Refresh()
    end)
end

local function LitTab(tab, on)
    tab.text:SetFontObject(on and "GameFontHighlightSmall" or "GameFontNormalSmall")
    tab.line:SetShown(on)
end

-- A small tile button, as the gallery's tiles: a gold border while it's on.
local function TileButton(page, text, onClick)
    local button = New("Button", page)
    button:SetHeight(24)
    button.border = button:CreateTexture(nil, "BACKGROUND")
    button.border:SetAllPoints()
    button.border:SetTextureSliceMargins(10, 10, 10, 10) -- (the art's corners kept at any width)
    button.hover = button:CreateTexture(nil, "HIGHLIGHT")
    button.hover:SetAllPoints()
    button.hover:SetAtlas("PetList-ButtonHighlight")
    button.hover:SetTextureSliceMargins(10, 10, 10, 10)
    button.text = Label(button, text, "GameFontNormal")
    button.text:SetPoint("CENTER", 0, 1)
    button:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        onClick()
    end)
    return button
end

local function LitTile(button, on)
    button.border:SetAtlas(on and "PetList-ButtonSelect" or "PetList-ButtonBackground")
    button.text:SetFontObject(on and "GameFontHighlight" or "GameFontNormal")
    button:SetWidth(button.text:GetStringWidth() + 22)
end

-- The spellbook's page arrows.
local function PageArrow(page, way, step)
    local arrow = New("Button", page)
    arrow:SetSize(24, 24)
    arrow:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. way .. "Page-Up")
    arrow:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. way .. "Page-Down")
    arrow:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. way .. "Page-Disabled")
    arrow:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    arrow:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
        window.galleryPage = (window.galleryPage or 1) + step
        Refresh()
    end)
    return arrow
end

-- Use on: the kinds' icons from the list; a lit one carries this sparkle. A click puts it on
-- that kind (and turns the kind on), or takes it off.
local function UseOnIcon(page, tab)
    local icon = New("Button", page)
    icon:SetSize(24, 24)
    icon.edge = icon:CreateTexture(nil, "BACKGROUND")
    icon.edge:SetAllPoints()
    icon.art = icon:CreateTexture(nil, "ARTWORK")
    icon.art:SetPoint("TOPLEFT", 2, -2)
    icon.art:SetPoint("BOTTOMRIGHT", -2, 2)
    icon.art:SetTexture(tab.icon)
    icon:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    icon.tab = tab
    icon:SetScript("OnClick", function()
        local sparkle = Current()
        if not sparkle then return end
        local key = ns.SPARKLE_KEYS[tab.key].made
        local using = ns.db[key] == sparkle.id and ns.db[tab.key] == true
        PlaySound(using and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        if using then
            ns.db[key] = nil
        else
            ns.db[key], ns.db[tab.key] = sparkle.id, true
        end
        Changed()
        ns.Setup()
        Refresh()
    end)
    Tooltip(icon, tab.name, "Click to put this sparkle on " .. tab.name:lower() .. ", or to take it off. Each kind's page can pick it too.")
    return icon
end

---------------------------------------------------------------------------
-- The handle on the preview
---------------------------------------------------------------------------
-- A thin gold ring on the picked layer, as an editor's: drag inside it to move the layer,
-- its edge (the four dots) to size it, the dot on its stem to turn an effect; the mouse
-- wheel over it changes a style's count or an effect's speed. The picked tool says what
-- a drag inside does. Elsewhere the preview still turns and zooms the node.
-- It shares the sparkles' zoom; the number changed shows beside it while dragging.
local EDGE = 0.75 -- a press farther out than this share of the radius sizes the layer
local WHEEL = { count = 1, speed = 10 } -- a wheel step
local SEGMENTS = 48 -- the ring's pieces
local STEM = 14 -- the turn dot's distance outside the ring

local function HandleLook()
    local sparkle = Current()
    local layer = window.makerLayer
    local look = sparkle and layer and LayerLook(sparkle, layer)
    return look, layer and layer <= 2
end

local function Limit(what, value)
    local limits = ns.MADE_LIMITS[what]
    return math.min(limits[2], max(limits[1], floor(value + 0.5)))
end

-- The ring's pieces for radius r: its gold line over a dark one.
local function Ring(handle, r)
    if handle.r == r then return end
    handle.r = r
    for i = 1, SEGMENTS do
        local a, b = (i - 1) * 2 * math.pi / SEGMENTS, i * 2 * math.pi / SEGMENTS
        for _, line in ipairs({ handle.ring[i], handle.shade[i] }) do
            line:SetStartPoint("CENTER", handle, cos(a) * r, sin(a) * r)
            line:SetEndPoint("CENTER", handle, cos(b) * r, sin(b) * r)
        end
    end
    for i, dot in ipairs(handle.dots) do
        local a = (i - 1) * math.pi / 2
        dot:SetPoint("CENTER", handle, "CENTER", cos(a) * r, sin(a) * r)
    end
end

-- The ring on the picked layer, the turn dot at the effect's turn.
local function PlaceHandle()
    local handle = window.handle
    local look, isEffect = HandleLook()
    handle:SetShown(window.tab.key == "maker" and look ~= nil)
    if not look then return end
    local size = tonumber(look.size) or ns.MADE_DEFAULT.size
    handle:SetSize(size, size)
    handle:ClearAllPoints()
    handle:SetPoint("CENTER", window.anchor, "BOTTOM", tonumber(look.x) or 0,
        (tonumber(look.height) or ns.MADE_DEFAULT.height) - (window.previewLower or 0))
    Ring(handle, size / 2)
    local z = window.scene.zoomer:GetScale()
    if handle.z ~= z then -- (the preview's zoom scales the handle: its marks stay one size)
        handle.z = z
        for i, dot in ipairs(handle.dots) do
            dot:SetSize(5 / z, 5 / z)
            handle.backs[i]:SetSize(7 / z, 7 / z)
        end
        handle.knob:SetSize(16 / z, 16 / z)
    end
    handle.knob:SetShown(isEffect == true)
    handle.stem:SetShown(isEffect == true)
    if isEffect then
        local angle = math.rad(tonumber(look.turn) or 0)
        local x, y = cos(angle), sin(angle)
        handle.knob:ClearAllPoints()
        handle.knob:SetPoint("CENTER", handle, "CENTER", x * (size / 2 + STEM), y * (size / 2 + STEM))
        handle.stem:SetStartPoint("CENTER", handle, x * size / 2, y * size / 2)
        handle.stem:SetEndPoint("CENTER", handle, x * (size / 2 + STEM - 6), y * (size / 2 + STEM - 6))
    end
end

-- The cursor in a frame's own units.
local function Cursor(frame)
    local x, y = GetCursorPosition()
    local scale = frame:GetEffectiveScale()
    return x / scale, y / scale
end

-- What a drag changes, as the number beside the ring says it.
local function Readout(mode, look)
    if mode == "move" then
        return ("%s %d   %s %d"):format(PARTS.x[1], look.x, PARTS.height[1], look.height)
    end
    local what = mode == "size" and "size" or "turn"
    return ("%s %d"):format(PARTS[what][1], look[what])
end

-- While dragging: the look changed in place (inside its limits), the preview and the
-- world shown so; let go, it is saved as Edit saves and the page shows the numbers.
local function Dragging(handle)
    local drag, look = handle.drag, HandleLook()
    if not (drag and look) then return end
    local x, y = Cursor(handle)
    if x == drag.lastX and y == drag.lastY then return end
    drag.lastX, drag.lastY = x, y
    if drag.mode == "move" then
        look.x = Limit("x", drag.x + x - drag.fromX)
        look.height = Limit("height", drag.height + y - drag.fromY)
    elseif drag.mode == "size" then
        look.size = Limit("size", drag.size + 2 * (sqrt((x - drag.centerX) ^ 2 + (y - drag.centerY) ^ 2) - drag.fromDist))
    else
        look.turn = floor(math.deg(math.atan2(y - drag.centerY, x - drag.centerX)) + 0.5) % 360
    end
    -- The preview only (the world when it's let go). A style's sparkles start again when
    -- they're made at a new size, so a size drag redraws a style 8 times a second.
    local now = GetTime()
    if not (drag.mode == "size" and drag.style) or now - (drag.shownAt or 0) >= 0.125 then
        drag.shownAt = now
        ShowMadePreview()
    end
    PlaceHandle()
    handle.readout.text:SetText(Readout(drag.mode, look))
    handle.readout:SetWidth(handle.readout.text:GetStringWidth() + 10)
end

local function StartDrag(handle, mode)
    local look, isEffect = HandleLook()
    if not look then return end
    local x, y = Cursor(handle)
    local centerX, centerY = handle:GetCenter()
    if not mode then
        if window.tool == "turn" and isEffect then
            mode = "turn"
        else
            local far = sqrt((x - centerX) ^ 2 + (y - centerY) ^ 2) > EDGE * handle:GetWidth() / 2
            mode = far and "size" or "move"
        end
    end
    Remember(Current(), true)
    handle.drag = { mode = mode, fromX = x, fromY = y, centerX = centerX, centerY = centerY, style = not isEffect,
        x = tonumber(look.x) or 0, height = tonumber(look.height) or ns.MADE_DEFAULT.height,
        size = tonumber(look.size) or ns.MADE_DEFAULT.size, fromDist = sqrt((x - centerX) ^ 2 + (y - centerY) ^ 2) }
    GameTooltip:Hide()
    handle:SetScript("OnUpdate", Dragging)
    handle.readout:Show()
end

local function StopDrag(handle)
    if not handle.drag then return end
    if not handle.drag.lastX then table.remove(undo) end -- (a click: nothing to take back)
    handle.drag, undo.at = nil, nil -- (the next change a step of its own)
    handle:SetScript("OnUpdate", nil)
    handle.readout:Hide()
    Edit(function() end, nil, true) -- (saved as cleaned, and the sliders show the new numbers)
end

local function BuildHandle()
    local handle = New("Button", window.scene.zoomer) -- (beside the anchor, so the sparkles are the anchor's only child)
    handle:SetFrameLevel(window.anchor:GetFrameLevel() + 20) -- (over the sparkles)
    handle:EnableMouse(true)
    handle:EnableMouseWheel(true)
    handle.ring, handle.shade, handle.dots, handle.backs = {}, {}, {}, {}
    for i = 1, SEGMENTS do
        handle.shade[i] = handle:CreateLine(nil, "OVERLAY", nil, 1)
        handle.shade[i]:SetColorTexture(0, 0, 0, 0.45)
        handle.shade[i]:SetThickness(3.5)
        handle.ring[i] = handle:CreateLine(nil, "OVERLAY", nil, 2)
        handle.ring[i]:SetColorTexture(1, 0.82, 0, 0.9)
        handle.ring[i]:SetThickness(1.5)
    end
    for i = 1, 4 do
        local dot = handle:CreateTexture(nil, "OVERLAY", nil, 4)
        dot:SetSize(7, 7)
        dot:SetColorTexture(1, 0.94, 0.78)
        local back = handle:CreateTexture(nil, "OVERLAY", nil, 3)
        back:SetSize(9, 9)
        back:SetColorTexture(0, 0, 0, 0.8)
        back:SetPoint("CENTER", dot)
        handle.dots[i], handle.backs[i] = dot, back
    end
    -- A small cross in its middle (drag there to move it).
    for _, arm in ipairs({ { -5, 0, 5, 0 }, { 0, -5, 0, 5 } }) do
        local line = handle:CreateLine(nil, "OVERLAY", nil, 2)
        line:SetColorTexture(1, 0.94, 0.78, 0.85)
        line:SetThickness(1.4)
        line:SetStartPoint("CENTER", handle, arm[1], arm[2])
        line:SetEndPoint("CENTER", handle, arm[3], arm[4])
    end
    handle.stem = handle:CreateLine(nil, "OVERLAY", nil, 2)
    handle.stem:SetColorTexture(1, 0.82, 0, 0.9)
    handle.stem:SetThickness(1.4)
    handle:SetScript("OnMouseDown", function(self, button) if button == "LeftButton" then StartDrag(self) end end)
    handle:SetScript("OnMouseUp", StopDrag)
    handle:SetScript("OnHide", StopDrag)
    handle:SetScript("OnMouseWheel", function(_, delta)
        local layer = window.makerLayer
        local what = layer and layer <= 2 and "speed" or "count"
        Edit(function(sparkle)
            local look = LayerLook(sparkle, layer)
            if look then look[what] = Limit(what, (tonumber(look[what]) or ns.MADE_DEFAULT[what]) + delta * WHEEL[what]) end
        end)
    end)
    Tooltip(handle, "The picked layer", "Drag inside the ring to move it, drag its edge to make it bigger or smaller."
        .. " The mouse wheel changes a style's count or an effect's speed. Drag the dot on the stem to turn an effect.")
    local knob = New("Button", handle)
    knob:SetSize(16, 16)
    knob:SetFrameLevel(handle:GetFrameLevel() + 2)
    knob:SetNormalAtlas("common-icon-rotateright")
    knob:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then StartDrag(handle, "turn") end end)
    knob:SetScript("OnMouseUp", function() StopDrag(handle) end)
    Tooltip(knob, "Turn", "Drag round the ring to turn the effect.")
    handle.knob = knob
    -- The number a drag changes, at the preview's top (the ring can be wider than the preview).
    local readout = New("Frame", window.preview)
    readout:SetFrameLevel(window.scene:GetFrameLevel() + 10)
    readout:SetHeight(16)
    readout:SetPoint("TOP", 0, -12)
    local back = readout:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0, 0, 0, 0.75)
    readout.text = Label(readout, "", "GameFontHighlightExtraSmall")
    readout.text:SetPoint("CENTER")
    readout:Hide()
    handle.readout = readout
    handle:Hide()
    window.handle = handle
end

-- The tools on the preview: what a drag inside the ring does, and the view put back.
local TOOLS = {
    { key = "turn", atlas = "common-icon-rotateright", name = "Turn", tip = "While it's on, drag round the ring to turn the picked effect. Click it again to move and size." },
    { key = "center", name = "Center", tip = "Puts the picked layer back in the middle, where a new one starts." },
    { key = "undo", atlas = "common-icon-undo", name = "Undo", tip = "Takes back the last change to a sparkle, drags on the preview too." },
    { key = "view", atlas = "common-icon-zoomout", name = "Reset view", tip = "Turns the node back and zooms as the preview opens." },
}

local function BuildTools()
    local tools = New("Frame", window.preview)
    tools:SetFrameLevel(window.scene:GetFrameLevel() + 10) -- (over the model, which takes the mouse)
    tools:SetPoint("TOPLEFT", 10, -44)
    tools:SetSize(32, #TOOLS * 36)
    tools.buttons = {}
    for i, tool in ipairs(TOOLS) do
        local button = New("Button", tools)
        button:SetSize(32, 32)
        button:SetPoint("TOPLEFT", 0, -(i - 1) * 36)
        button:SetNormalAtlas("common-button-square-gray-up")
        button:SetPushedAtlas("common-button-square-gray-down")
        button:SetHighlightAtlas("common-button-square-gray-up", "ADD")
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(20, 20)
        button.icon:SetPoint("CENTER")
        if tool.atlas then
            button.icon:SetAtlas(tool.atlas)
        else
            for _, arm in ipairs({ { -8, 0, -3, 0 }, { 3, 0, 8, 0 }, { 0, -8, 0, -3 }, { 0, 3, 0, 8 } }) do
                local line = button:CreateLine(nil, "ARTWORK")
                line:SetColorTexture(1, 0.82, 0)
                line:SetThickness(2)
                line:SetStartPoint("CENTER", button, arm[1], arm[2])
                line:SetEndPoint("CENTER", button, arm[3], arm[4])
            end
            button.icon:SetSize(3, 3)
            button.icon:SetColorTexture(1, 0.82, 0)
        end
        button.picked = button:CreateTexture(nil, "OVERLAY")
        button.picked:SetAtlas("PetList-ButtonSelect")
        button.picked:SetAllPoints()
        button:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            if tool.key == "view" then
                local scene = window.scene
                scene.yaw, scene.zoom = 0, ZOOM_START
                window.actor:SetYaw(0)
                if scene.framed then PlaceCamera(scene) end
            elseif tool.key == "undo" then
                return Undo()
            elseif tool.key == "center" then
                local layer = window.makerLayer
                return Edit(function(sparkle)
                    local look = layer and LayerLook(sparkle, layer)
                    if look then look.x, look.height = 0, ns.MADE_DEFAULT.height end
                end)
            else
                window.tool = window.tool ~= "turn" and "turn" or nil
            end
            Refresh()
        end)
        Tooltip(button, tool.name, tool.tip)
        tools.buttons[tool.key] = button
    end
    tools:Hide()
    window.tools = tools
    -- The layers along the preview's bottom, over Keep the game's icons.
    local strip = New("Frame", window.preview)
    strip:SetFrameLevel(window.scene:GetFrameLevel() + 10)
    strip:SetPoint("BOTTOMLEFT", 8, 32)
    strip:SetPoint("BOTTOMRIGHT", -8, 32)
    strip:SetHeight(64)
    local back = strip:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0, 0, 0, 0.55)
    strip.label = Label(strip, "Layers", "GameFontNormalSmall")
    strip.label:SetPoint("TOPLEFT", 6, -4)
    strip:Hide()
    window.layerStrip = strip
end

function BuildMaker(grid)
    local page = New("Frame", window.Inset)
    page:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, 38) -- (as the settings page)
    page:SetPoint("BOTTOMRIGHT", -8, 8)
    window.maker = page
    page.title = Label(page, "Sparkle Maker (Beta)", "GameFontHighlightLarge")
    page.title:SetPoint("TOPLEFT", 2, 16)
    page.about = Label(page, "Build a sparkle from Blizzard's 3D effects and the styles, then use it on anything.", "GameFontDisableSmall")
    page.about:SetPoint("TOPLEFT", 2, -5)

    -- The sparkles, and what to do with the one shown.
    page.yours = Label(page, "Your sparkles", "GameFontNormal")
    page.yoursLine = page:CreateTexture(nil, "ARTWORK")
    Fade(page.yoursLine, 1, 0.82, 0, 0.67)
    page.yoursLine:SetHeight(1)
    page.yoursLine:SetPoint("TOPLEFT", page.yours, "BOTTOMLEFT", 0, -3)
    page.yoursLine:SetPoint("RIGHT", page, "RIGHT", -130, 0)
    page.sparkleTiles = {}
    for i = 1, ns.MADE_MAX + 1 do page.sparkleTiles[i] = SparkleTile(page) end
    page.name = TextBox(page, 200)
    page.nameLabel, page.nameHover = MakerRow(page, -60, NAME, page.name, "Its name on the tiles.")
    page.name:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    page.name:SetScript("OnEditFocusLost", function(self)
        local name = CleanName(self:GetText())
        if name == "" then return Refresh() end
        Edit(function(sparkle) sparkle.name = name end)
    end)
    page.useLabel = Label(page, "Use on", "GameFontNormal")
    page.useIcons = {}
    for _, tab in ipairs(TABS) do
        if tab.on then page.useIcons[#page.useIcons + 1] = UseOnIcon(page, tab) end
    end
    page.useNote = Label(page, "", "GameFontDisableSmall")

    -- The layers, as WeakAuras lists a group's parts: click one to change it below.
    BuildTools()
    local strip = window.layerStrip
    page.add = SmallButton(strip, "+ Add layer", 100, AddLayer)
    page.add:SetPoint("RIGHT", strip, "RIGHT", -8, 0)
    Tooltip(page.add, "Add a layer", ("Then pick what it is in the gallery. A sparkle can have %d of Blizzard's 3D effects (the first four sections) and %d of the others."):format(ns.MADE_MAX_EFFECTS, ns.MADE_MAX_LAYERS))
    page.rows = {}
    for i = 1, ns.MADE_MAX_EFFECTS + ns.MADE_MAX_LAYERS do
        page.rows[i] = LayerRow(strip)
        page.rows[i]:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 6 + (i - 1) * (CHIP_WIDTH + 4), 4)
    end

    -- The shown layer: its name over a line, then the gallery to change it.
    page.layerTitle = Label(page, "", "GameFontNormal")
    page.layerLine = page:CreateTexture(nil, "ARTWORK")
    Fade(page.layerLine, 1, 0.82, 0, 0.67)
    page.layerLine:SetHeight(1)
    page.layerLine:SetPoint("TOPLEFT", page.layerTitle, "BOTTOMLEFT", 0, -3)
    page.layerLine:SetPoint("RIGHT", page, "RIGHT", -12, 0)
    page.layerKind = Label(page, "", "GameFontDisableSmall")
    FindGroups()
    page.groupTabs = {}
    for i, group in ipairs(GROUPS) do page.groupTabs[i] = GroupTab(page, group) end
    page.styleTabs = {}
    for i, group in ipairs(STYLE_GROUPS) do page.styleTabs[i] = GroupTab(page, group) end
    page.tiles = {}
    for i = 1, 4 * GALLERY_ROWS do page.tiles[i] = GalleryTile(page) end
    page.prev = PageArrow(page, "Prev", -1)
    page.next = PageArrow(page, "Next", 1)
    page.pageText = Label(page, "", "GameFontHighlightSmall")
    page.pageText:SetPoint("RIGHT", page.prev, "LEFT", -4, 0)
    local swatch = New("Button", page, "ColorSwatchTemplate")
    swatch:SetSize(22, 22)
    swatch:SetScript("OnClick", function() PickLayerColor("color") end)
    page.colorLabel, page.colorHover = MakerRow(page, 0, COLOR, swatch, "This style's colors. White keeps their own.")
    local swatch2 = New("Button", page, "ColorSwatchTemplate")
    swatch2:SetSize(22, 22)
    swatch2:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
    swatch2:SetScript("OnClick", function() PickLayerColor("color2") end)
    Tooltip(swatch2, "Second color", "The style switches between the two colors.")
    local sets = Dropdown(page, 150)
    sets:SetDefaultText(CUSTOM)
    sets:SetPoint("LEFT", swatch2, "RIGHT", 12, 0)
    Tooltip(sets, "Color set", "Two colors that go well together.")
    page.swatch, page.swatch2, page.sets = swatch, swatch2, sets
    page.sliders = {}
    for what in pairs(PARTS) do page.sliders[what] = MakerSlider(page, what) end
    -- The animation as a row of buttons, the one playing lit.
    page.animLabel = Label(page, "Animation", "GameFontNormal")
    page.anims = {}
    for i, anim in ipairs(ANIMS_SHOWN) do
        local button = TileButton(page, anim, function()
            local layer = window.makerLayer
            Edit(function(s)
                local l = LayerLook(s, layer)
                if l then l.anim = anim end
            end)
        end)
        Tooltip(button, anim, ANIM_TIPS[anim])
        page.anims[anim] = button
    end
    -- The exact numbers, and the settings the handles don't have.
    page.fine = TileButton(page, "Advanced", function()
        window.fineTune = not window.fineTune
        Refresh()
    end)
    Tooltip(page.fine, "Advanced", "Sliders for the exact numbers, and for tilt, see-through, particles and loop speed. On the preview you can drag the layer, its edge and its turn dot instead.")
    page.hint = Label(page, "", "GameFontDisableSmall")
    page.hint:SetPoint("LEFT", page.fine, "RIGHT", 14, 0)
    page.empty = Label(page, "No sparkles yet. Click New, or right-click it for Random or Import.", "GameFontHighlight")
    page.noLayers = Label(page, "Add an effect or a style.", "GameFontHighlight")
    BuildHandle()
end

-- Shows a row's control, label and hover area, or hides them.
local function ShowRow(shown, ...)
    for i = 1, select("#", ...) do
        local part = select(i, ...)
        if part then part:SetShown(shown) end
    end
end

-- A part's left at x, its middle at y, on the page.
local function At(part, x, y)
    part:ClearAllPoints()
    part:SetPoint("LEFT", window.maker, "TOPLEFT", x, y)
end

-- The shown layer's sliders in their rows from y, two to a row; the rest hidden (and
-- Loop speed while there's no animation). Returns the last row's y.
local function PlaceSliders(page, rows, y, look)
    local used = {}
    for r, row in ipairs(rows) do
        for c, what in ipairs(row) do
            local slider, x = page.sliders[what], (c - 1) * 220
            slider.label:ClearAllPoints()
            slider.label:SetPoint("LEFT", page, "TOPLEFT", x, y - (r - 1) * STEP)
            slider.hover:ClearAllPoints()
            slider.hover:SetPoint("LEFT", slider.label, "LEFT")
            slider:ClearAllPoints()
            slider:SetPoint("LEFT", page, "TOPLEFT", x + 66, y - (r - 1) * STEP)
            slider:SetValue(tonumber(look[what]) or ns.MADE_DEFAULT[what])
            used[what] = true
        end
    end
    used.animSpeed = used.animSpeed and look.anim ~= nil and look.anim ~= "None"
    for what, slider in pairs(page.sliders) do ShowRow(used[what] == true, slider, slider.label, slider.hover) end
    return y - (#rows - 1) * STEP
end

-- The top of the page: the sparkle and its name, where it's used. Returns the y under it.
local function PlaceTop(page, sparkle, list, room)
    At(page.yours, 0, -24)
    local count = #list + (room and 1 or 0)
    for i, tile in ipairs(page.sparkleTiles) do
        local each = list[i]
        local new = not each and i == #list + 1 and room
        tile:SetShown(each ~= nil or new)
        if each or new then
            tile:ClearAllPoints()
            tile:SetPoint("TOPLEFT", page, "TOPLEFT", ((i - 1) % 5) * 88, -36 - floor((i - 1) / 5) * 68)
            tile.id = each and each.id or nil
            tile.title = each and tostring(each.name) or "New"
            tile.name:SetText(tile.title)
            tile.plus:SetShown(new)
            local picked = each ~= nil and each == sparkle
            tile.border:SetAtlas(picked and "PetList-ButtonSelect" or "PetList-ButtonBackground")
            tile.name:SetFontObject(picked and GameFontHighlightSmall or GameFontNormalSmall)
            if each then
                ns.ShowSparkles(tile.anchor, Shown(), nil, { made = each, fit = 40, height = 0 })
            elseif ns.SparklePreviews[tile.anchor] then
                ns.SparklePreviews[tile.anchor]:Hide()
            end
        end
    end
    local y = -36 - floor((max(count, 1) + 4) / 5) * 68 - 14
    page.empty:SetShown(sparkle == nil)
    At(page.empty, 0, y)
    ShowRow(sparkle ~= nil, page.name, page.nameLabel, page.nameHover, page.useLabel, page.useNote)
    At(page.nameLabel, 0, y)
    At(page.name, LABEL + 6, y)
    At(page.nameHover, 0, y)
    At(page.useLabel, 0, y - 32)
    local using = {}
    for i, icon in ipairs(page.useIcons) do
        icon:SetShown(sparkle ~= nil)
        At(icon, LABEL + (i - 1) * 28, y - 32)
        local tab = icon.tab
        local on = sparkle ~= nil and ns.db[ns.SPARKLE_KEYS[tab.key].made] == sparkle.id and ns.db[tab.key] == true
        icon.on = on
        icon.edge:SetColorTexture(on and 1 or 0.24, on and 0.82 or 0.21, on and 0 or 0.17)
        icon.art:SetDesaturated(not on)
        icon.art:SetAlpha(on and 1 or 0.55)
        if on then using[#using + 1] = tab.name end
    end
    page.useNote:SetText(using[1] and table.concat(using, ", ") or NONE)
    At(page.useNote, LABEL + #page.useIcons * 28 + 4, y - 32)
    return y - 32 - 34
end

-- Is a gallery section the styles'?
local function IsStyleGroup(group)
    for _, each in ipairs(STYLE_GROUPS) do
        if each == group then return true end
    end
    return false
end

-- The gallery for the shown layer: every section, the effects' and the styles', as tabs in
-- one row, a page of the open one's tiles at a time. A tile of the other kind turns the layer
-- into it, grayed while the sparkle has all of that kind it can (fullEffects, fullStyles).
-- Returns the y under it.
local function PlaceGallery(page, look, isStyle, y, fullEffects, fullStyles)
    local perPage = 4 * GALLERY_ROWS
    local items, picked = {}, nil
    local now = not isStyle and EffectEntry(look)
    local clean = isStyle and ns.CleanMade({ layers = { look } })
    local style = clean and clean.layers[1].style
    -- Another layer: the page (and section) with its pick, until a tab or an arrow says otherwise.
    local key = window.madeId .. ":" .. window.makerLayer
    if window.galleryFor ~= key then
        window.galleryFor, window.galleryPage = key, nil
        if isStyle then
            window.galleryGroup = style and ns.SPARKLE_STYLES[style].group or STYLE_GROUPS[1]
        else
            window.galleryGroup = now and now.group or GROUPS[1]
        end
    end
    local styles = IsStyleGroup(window.galleryGroup)
    local full = styles ~= isStyle and (styles and fullStyles or not styles and fullEffects)
    if styles then
        for _, i in ipairs(LayerStyles()) do
            if ns.SPARKLE_STYLES[i].group == window.galleryGroup then
                items[#items + 1] = i
                if style == i then picked = #items end
            end
        end
    else
        for _, effect in ipairs(ns.SPARKLE_EFFECTS) do
            if effect.group == window.galleryGroup then
                items[#items + 1] = effect
                if effect == now then picked = #items end
            end
        end
    end
    local pages = max(1, floor((#items + perPage - 1) / perPage))
    if not window.galleryPage then window.galleryPage = picked and floor((picked - 1) / perPage) + 1 or 1 end
    window.galleryPage = math.min(pages, max(1, window.galleryPage))
    -- The tabs: the effects' sections, then the styles'.
    local x = 0
    for _, set in ipairs({ { page.groupTabs, GROUPS }, { page.styleTabs, STYLE_GROUPS } }) do
        for i, tab in ipairs(set[1]) do
            tab:Show()
            LitTab(tab, set[2][i] == window.galleryGroup)
            At(tab, x, y)
            x = x + tab:GetWidth() + 12
        end
    end
    y = y - 18
    -- The tiles.
    local first = (window.galleryPage - 1) * perPage
    local kind, shown = Shown(), 0
    for i, tile in ipairs(page.tiles) do
        local item = i <= perPage and items[first + i]
        tile:SetShown(item ~= nil and item ~= false)
        if item then
            shown = shown + 1
            tile:SetSize(TILE_STEP - 4, TILE_HEIGHT)
            tile:ClearAllPoints()
            tile:SetPoint("TOPLEFT", page, "TOPLEFT", ((i - 1) % 4) * TILE_STEP, y - floor((i - 1) / 4) * (TILE_HEIGHT + 4))
            tile.choice = item
            local on = first + i == picked
            tile.border:SetAtlas(on and "PetList-ButtonSelect" or "PetList-ButtonBackground")
            tile.name:SetFontObject(on and GameFontHighlightSmall or GameFontNormalSmall)
            tile:SetEnabled(not full)
            tile:SetAlpha(full and 0.45 or 1)
            if styles then
                local each = ns.SPARKLE_STYLES[item]
                tile.title, tile.tip = each.name, each.tip
                ns.ShowSparkles(tile.anchor, kind, nil, { style = item, size = 46, height = 0, count = 9,
                    color = isStyle and look.color or each.start.color, color2 = isStyle and look.color2 or each.start.color2 })
            else
                tile.title, tile.tip = item.name, item.group
                ns.ShowSparkles(tile.anchor, kind, nil, { made = { effects = { { file = item.file, display = item.display } } }, fit = 50, height = 0 })
            end
            if full then
                tile.tip = ("A sparkle can have %d of these. Take one out first."):format(styles and ns.MADE_MAX_LAYERS or ns.MADE_MAX_EFFECTS)
            end
            tile.name:SetText(tile.title)
        end
    end
    y = y - max(1, floor((shown + 3) / 4)) * (TILE_HEIGHT + 4) -- (only as tall as its tiles)
    -- The page arrows under the tiles' right end.
    ShowRow(pages > 1, page.prev, page.next, page.pageText)
    page.prev:ClearAllPoints()
    page.prev:SetPoint("RIGHT", page, "TOPLEFT", 4 * TILE_STEP - 30, y - 10)
    page.next:ClearAllPoints()
    page.next:SetPoint("LEFT", page.prev, "RIGHT", 2, 0)
    page.prev:SetEnabled(window.galleryPage > 1)
    page.next:SetEnabled(window.galleryPage < pages)
    page.pageText:SetText(("%d / %d"):format(window.galleryPage, pages))
    return y - (pages > 1 and 24 or 4)
end

function RefreshMaker()
    local page, list = window.maker, ns.MadeList()
    local sparkle = Current()
    if sparkle then window.madeId = sparkle.id end
    local room = #list < ns.MADE_MAX
    local y = PlaceTop(page, sparkle, list, room)
    -- The layers: the shown one is one in use (the first, if the one picked is gone).
    local used = sparkle and UsedLayers(sparkle) or {}
    local shown
    for _, entry in ipairs(used) do
        if entry.layer == window.makerLayer then shown = entry end
    end
    shown = shown or used[1]
    window.makerLayer = shown and shown.layer or nil
    local hidden = sparkle and HiddenLayers(sparkle) or {}
    window.layerStrip:SetShown(sparkle ~= nil)
    window.tools:SetShown(sparkle ~= nil)
    local effects, styles = 0, 0
    for i, row in ipairs(page.rows) do
        local entry = used[i]
        row:SetShown(entry ~= nil)
        if entry then
            local isEffect = entry.layer <= 2
            local effect = isEffect and EffectEntry(entry.look)
            row.layer = entry.layer
            row.text:SetText(isEffect and (effect and effect.name or "?") or tostring(entry.look.style))
            local style = not isEffect and StyleEntry(entry.look)
            row.kind:SetText(isEffect and (effect and effect.group or "") or (style and style.group or ""))
            if isEffect then
                effects = effects + 1
                row.icon:SetTexture(EFFECT_ICON)
                row.icon:SetVertexColor(1, 1, 1)
            else
                styles = styles + 1
                row.icon:SetTexture(STAR)
                row.icon:SetVertexColor(ns.SparkleRGB(entry.look.color))
            end
            local picked, off = entry == shown, hidden[entry.layer] == true
            row.selected:SetShown(picked)
            row.bar:SetShown(picked)
            row.text:SetFontObject(picked and "GameFontHighlight" or off and "GameFontDisable" or "GameFontNormal")
            row.icon:SetAlpha(off and 0.4 or 1)
            row.eye.art:SetAtlas(off and "GM-icon-visibleDis" or "GM-icon-visible")
        end
    end
    page.add:SetEnabled(effects < ns.MADE_MAX_EFFECTS or styles < ns.MADE_MAX_LAYERS)
    page.noLayers:SetShown(sparkle ~= nil and not shown)
    At(page.noLayers, 0, y)
    -- The shown layer: its name, then its gallery (and a style's colors), its animation, Fine-tune.
    local look = shown and shown.look
    local isStyle = shown and shown.layer > 2 or false
    local fine = look and window.fineTune or false
    ShowRow(look ~= nil, page.layerTitle, page.layerLine, page.layerKind, page.animLabel, page.fine, page.hint)
    ShowRow(look ~= nil and isStyle, page.swatch, page.swatch2, page.sets, page.colorLabel, page.colorHover)
    for _, tile in ipairs(page.tiles) do tile:SetShown(false) end
    for _, tab in ipairs(page.groupTabs) do tab:SetShown(false) end
    for _, tab in ipairs(page.styleTabs) do tab:SetShown(false) end
    ShowRow(false, page.prev, page.next, page.pageText)
    for _, button in pairs(page.anims) do button:Hide() end
    if not fine then
        for _, slider in pairs(page.sliders) do ShowRow(false, slider, slider.label, slider.hover) end
    end
    for _, tool in pairs(window.tools.buttons) do tool.picked:SetShown(false) end
    PlaceHandle()
    if not sparkle then return end
    if not page.name:HasFocus() then page.name:SetText(tostring(sparkle.name)) end
    if not look then return end
    local layer = shown.layer
    local effect = not isStyle and EffectEntry(look)
    page.layerTitle:SetText(isStyle and tostring(look.style) or effect and effect.name or "?")
    At(page.layerTitle, 0, y)
    local entry = isStyle and StyleEntry(look) or effect
    page.layerKind:SetText(entry and entry.group or "")
    page.layerKind:ClearAllPoints()
    page.layerKind:SetPoint("RIGHT", page, "TOPRIGHT", -12, y)
    y = y - 30
    if isStyle then
        At(page.colorLabel, 0, y)
        At(page.colorHover, 0, y)
        At(page.swatch, LABEL, y)
        page.swatch:SetColorRGB(ns.SparkleRGB(look.color))
        page.swatch2:SetColorRGB(ns.SparkleRGB(look.color2 or look.color))
        page.sets:SetupMenu(function(_, root)
            for _, set in ipairs(SETS) do
                root:CreateRadio(set[1], function() return look.color == set[2] and look.color2 == set[3] end, function()
                    Edit(function(s)
                        local l = LayerLook(s, layer)
                        if l then l.color, l.color2 = set[2], set[3] end
                    end)
                end)
            end
        end)
        y = y - 30
    end
    if fine then
        y = PlaceSliders(page, isStyle and STYLE_ROWS or EFFECT_ROWS, y, look) - STEP
    else
        y = PlaceGallery(page, look, isStyle, y + 8, effects >= ns.MADE_MAX_EFFECTS, styles >= ns.MADE_MAX_LAYERS) - 8
    end
    At(page.animLabel, 0, y)
    local x = LABEL
    for _, anim in ipairs(ANIMS_SHOWN) do
        local button = page.anims[anim]
        local shown = anim ~= "Spin" or not isStyle
        button:SetShown(shown)
        LitTile(button, (look.anim or "None") == anim)
        if shown then
            button:ClearAllPoints()
            button:SetPoint("LEFT", page.animLabel, "LEFT", x, 0)
            x = x + button:GetWidth() + 6
        end
    end
    At(page.fine, 0, y - 34)
    page.fine.text:SetText(window.fineTune and "Advanced: done" or "Advanced")
    LitTile(page.fine, window.fineTune == true)
    page.hint:SetText(page.said or "Drag the gold ring on the preview to move or size the layer.")
    page.hint:SetFontObject(page.saidRed and "GameFontRed" or "GameFontDisableSmall")
    -- The tools: Turn lit while on, no turning a style; Undo while there's something to take back.
    if isStyle then window.tool = nil end
    for key, button in pairs(window.tools.buttons) do
        local off = key == "turn" and isStyle or key == "undo" and #undo == 0
        button.picked:SetShown(key == window.tool)
        button:SetEnabled(not off)
        button.icon:SetDesaturated(off)
    end
end

-- A code back into a new sparkle, said under the page.
local function ImportCode(text)
    local page = window.maker
    local clean = FromCode(text)
    if not clean then
        page.said, page.saidRed = "That isn't a sparkle code.", true
        return Refresh()
    end
    page.said, page.saidRed = ("Added %s."):format(CleanName(clean.name)), false
    Added(clean)
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
    if window.handle then PlaceHandle() end -- (its marks keep their size on screen)
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
    local isMaker = tab.key == "maker"
    window.refreshing = true
    local wide = isMaker and PREVIEW_MAKER or PREVIEW_WIDTH
    if window.preview:GetWidth() ~= wide then
        window.preview:SetWidth(wide)
        window:SetWidth(760 + LIST + wide - PREVIEW_WIDTH)
        window.scene.framed = false -- (the camera stands back again for the new size)
    end
    window.iconsRow:SetShown(not isMaker)
    if not isMaker then
        window.handle:Hide()
        window.tools:Hide()
        window.layerStrip:Hide()
    end
    local gridHeight = GridHeight()
    if gridHeight ~= window.gridHeight then
        window.gridHeight = gridHeight
        window.grid:SetHeight(gridHeight)
    end
    local height = isMaker and max(402 + gridHeight, MAKER_HEIGHT) or 402 + gridHeight
    if window:GetHeight() ~= height then window:SetHeight(height) end
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
    for _, part in ipairs(window.look) do part:SetShown(not isGeneral and not isMaker and not tab.page) end
    window.kindTitle:SetText(tab.name)
    window.kindAbout:SetText(tab.tip or "")
    window.general:SetShown(isGeneral)
    window.maker:SetShown(isMaker)
    window.preview:SetShown(not tab.page)
    window.edge:SetShown(not tab.page)
    window.interactOff:SetShown(ns.InteractOff())
    window.turnOn:SetShown(window.interactOff:IsShown())
    local problems = window.interactOff:IsShown() and {} or Problems()
    window.problem.list = problems
    window.problem:SetShown(problems[1] ~= nil)
    if problems[1] then
        window.problem.text:SetFontObject(problems[1][2] and "GameFontRed" or "GameFontNormal")
        window.problem.text:SetText(problems[1][1])
        window.problem:SetSize(window.problem.text:GetStringWidth() + 8, 20)
    end
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
    local cultivation = window.cultivationIcon and kind == "herbs" and ns.db.cultivation == true
    window.gameIcon:SetShown(ns.db.gameIcons == true and not cultivation)
    if window.cultivationIcon then window.cultivationIcon:SetShown(cultivation) end
    window.myProfessions:SetChecked(ns.db.myProfessions)
    window.cultivation:SetChecked(ns.db.cultivation)
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
    window.off:SetShown(not isGeneral and not isMaker and not on)
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
    if isMaker then RefreshMaker() end
    WarnMaker(isMaker)
    window.refreshing = nil
    -- A Sparkle Maker sparkle in use: its note in place of the style's look, and its tile picked.
    local made = ns.FindMade(ns.SparkleLook(kind, "made"))
    window.lookRows:SetShown(not made)
    window.madeNote:SetShown(made ~= nil)
    if made then
        window.madeNote.id = made.id
        window.madeNote.text:SetText(("Uses %s from the Sparkle Maker."):format(tostring(made.name)))
    end
    local chosen = on and not made and ns.SparkleLook(kind, "style")
    local also, alsoMade = on and ns.SparkleLook(kind, "style2"), on and ns.FindMade(ns.SparkleLook(kind, "made2")) -- (the second ones, lit too)
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
                    local lit = i == chosen or i == also
                    tile.border:SetAtlas(lit and "PetList-ButtonSelect" or "PetList-ButtonBackground")
                    tile.name:SetFontObject(lit and GameFontHighlightSmall or GameFontNormalSmall)
                    local look = LookOf(kind, i) -- what a click on it gives
                    ns.ShowSparkles(tile.anchor, kind, nil, { style = i, size = 46, height = 0, count = math.min(look.count, 9),
                        color = look.color, color2 = look.color2 })
                end
            end
        end
    end
    -- Then the Sparkle Maker's sparkles.
    local list = ns.MadeList()
    for i, sparkle in ipairs(list) do
        local tile = window.madeTiles[i] or MadeTile(window.grid)
        window.madeTiles[i] = tile
        tile.id, tile.title = sparkle.id, tostring(sparkle.name)
        tile.name:SetText(tile.title)
        tile:SetPoint("TOPLEFT", (at % 5) * 86, -floor(at / 5) * 80)
        at = at + 1
        local picked = on and (made == sparkle or alsoMade == sparkle)
        tile.border:SetAtlas(picked and "PetList-ButtonSelect" or "PetList-ButtonBackground")
        tile.name:SetFontObject(picked and GameFontHighlightSmall or GameFontNormalSmall)
        tile:SetShown(not isGeneral and not isMaker)
        ns.ShowSparkles(tile.anchor, kind, nil, { made = sparkle, fit = 46, height = 0 })
    end
    for i = #list + 1, #window.madeTiles do window.madeTiles[i]:Hide() end
    local node = NODES[kind][window.node[kind] or 1]
    local example = EXAMPLES[window.example]
    window.previewLower = ns.SPARKLE_LOWER[node[1]:lower()]
    if isMaker then -- the sparkle being made
        ShowMadePreview()
        PlaceHandle()
    elseif ns.db[kind] or example then -- (the preview's own kind: on Sparkle settings, the last one shown)
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
-- Turned off while sparkles are on: a dialog like the game's offers it back. The same
-- dialog says when the game refuses another CVar sparkles need.

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

local function ShowNotice(message)
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
    notice.text:SetText(NORMAL_FONT_COLOR:WrapTextInColorCode(C_AddOns.GetAddOnMetadata(ADDON_NAME, "Title") or ADDON_NAME)
        .. "\n\n" .. message)
    notice:SetHeight(notice.text:GetStringHeight() + 73)
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

-- Deleting a Sparkle Maker sparkle: a dialog like the game's asks first.
local deleteAsk
function AskDelete(sparkle)
    if not deleteAsk then
        deleteAsk = New("Frame", UIParent)
        deleteAsk:SetFrameStrata("FULLSCREEN_DIALOG") -- (over the window)
        deleteAsk:SetToplevel(true)
        deleteAsk:EnableMouse(true)
        deleteAsk:SetPoint("TOP", UIParent, "TOP", 0, -135)
        deleteAsk:SetWidth(420)
        local background = deleteAsk:CreateTexture(nil, "BACKGROUND", nil, -7)
        background:SetAtlas("UI-DialogBox-Background-Dark", true)
        background:SetPoint("TOPLEFT", 7, -7)
        background:SetPoint("BOTTOMRIGHT", -7, 7)
        local edge = deleteAsk:CreateTexture(nil, "BACKGROUND", nil, -4)
        edge:SetAtlas("UI-DiamondDialogBox-Border", true)
        edge:SetAllPoints()
        deleteAsk.text = deleteAsk:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        deleteAsk.text:SetPoint("TOP", 0, -20)
        deleteAsk.text:SetWidth(380)
        deleteAsk.text:SetSpacing(3)
        deleteAsk.yes = DialogButton(deleteAsk, DELETE, function()
            deleteAsk:Hide()
            DeleteMade(deleteAsk.id)
        end)
        deleteAsk.no = DialogButton(deleteAsk, CANCEL, function() deleteAsk:Hide() end)
        deleteAsk.yes:SetPoint("BOTTOMRIGHT", deleteAsk, "BOTTOM", -4, 16)
        deleteAsk.no:SetPoint("BOTTOMLEFT", deleteAsk, "BOTTOM", 4, 16)
    end
    deleteAsk.id = sparkle.id
    deleteAsk.text:SetText(NORMAL_FONT_COLOR:WrapTextInColorCode(C_AddOns.GetAddOnMetadata(ADDON_NAME, "Title") or ADDON_NAME)
        .. "\n\n" .. ("Delete %s? Anything that uses it goes back to its own style."):format(tostring(sparkle.name)))
    deleteAsk:SetHeight(deleteAsk.text:GetStringHeight() + 73)
    deleteAsk:Show()
end

-- Until Okay is pressed once, the Sparkle Maker opens under a shade over the whole
-- window that says it is an early build; nothing under it can be clicked.
local makerWarn
function WarnMaker(shown)
    if makerWarn then makerWarn:SetShown(shown and not ns.db.makerWarned) end
    if makerWarn or not shown or ns.db.makerWarned then return end
    makerWarn = New("Frame", window)
    makerWarn:SetAllPoints(window)
    makerWarn:SetFrameStrata("FULLSCREEN") -- (over the window's own frames, under the game's dialogs)
    makerWarn:EnableMouse(true)
    makerWarn:EnableMouseWheel(true) -- (no zooming the preview under it)
    makerWarn:SetScript("OnMouseWheel", function() end)
    local shade = makerWarn:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0, 0, 0, 0.8)
    local box = New("Frame", makerWarn)
    box:SetPoint("CENTER")
    box:SetWidth(420)
    local background = box:CreateTexture(nil, "BACKGROUND", nil, -7)
    background:SetAtlas("UI-DialogBox-Background-Dark", true)
    background:SetPoint("TOPLEFT", 7, -7)
    background:SetPoint("BOTTOMRIGHT", -7, 7)
    local edge = box:CreateTexture(nil, "BACKGROUND", nil, -4)
    edge:SetAtlas("UI-DiamondDialogBox-Border", true)
    edge:SetAllPoints()
    makerWarn.text = box:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    makerWarn.text:SetPoint("TOP", 0, -20)
    makerWarn.text:SetWidth(380)
    makerWarn.text:SetSpacing(3)
    makerWarn.text:SetText(NORMAL_FONT_COLOR:WrapTextInColorCode(C_AddOns.GetAddOnMetadata(ADDON_NAME, "Title") or ADDON_NAME)
        .. "\n\nThe Sparkle Maker is an early build and a proof of concept. Expect bugs, and things may change in later versions.")
    box:SetHeight(makerWarn.text:GetStringHeight() + 73)
    makerWarn.ok = DialogButton(box, OKAY, function()
        ns.db.makerWarned = true
        makerWarn:Hide()
    end)
    makerWarn.ok:SetPoint("BOTTOM", box, "BOTTOM", 0, 16)
end

-- A sparkle's share code to copy, or a box to paste one into: a dialog like the game's.
local codeAsk
function ShowCode(sparkle)
    if not codeAsk then
        codeAsk = New("Frame", UIParent)
        codeAsk:SetFrameStrata("FULLSCREEN_DIALOG") -- (over the window)
        codeAsk:SetToplevel(true)
        codeAsk:EnableMouse(true)
        codeAsk:SetPoint("TOP", UIParent, "TOP", 0, -135)
        codeAsk:SetWidth(420)
        local background = codeAsk:CreateTexture(nil, "BACKGROUND", nil, -7)
        background:SetAtlas("UI-DialogBox-Background-Dark", true)
        background:SetPoint("TOPLEFT", 7, -7)
        background:SetPoint("BOTTOMRIGHT", -7, 7)
        local edge = codeAsk:CreateTexture(nil, "BACKGROUND", nil, -4)
        edge:SetAtlas("UI-DiamondDialogBox-Border", true)
        edge:SetAllPoints()
        codeAsk.text = codeAsk:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        codeAsk.text:SetPoint("TOP", 0, -20)
        codeAsk.text:SetWidth(380)
        codeAsk.text:SetSpacing(3)
        local box = New("EditBox", codeAsk, "InputBoxTemplate")
        box:SetSize(350, 20)
        box:SetAutoFocus(false)
        box:SetPoint("TOP", codeAsk.text, "BOTTOM", 0, -12)
        box:SetScript("OnEscapePressed", function() codeAsk:Hide() end)
        box:SetScript("OnEnterPressed", function()
            if codeAsk.importing then codeAsk.ok:Click() else codeAsk:Hide() end
        end)
        -- A code to copy stays as it is: typing puts it back, selected.
        box:SetScript("OnTextChanged", function(self, typed)
            if typed and not codeAsk.importing and self:GetText() ~= codeAsk.code then
                self:SetText(codeAsk.code)
                self:HighlightText()
            end
        end)
        codeAsk.box = box
        codeAsk.ok = DialogButton(codeAsk, "Import", function()
            local text = box:GetText()
            codeAsk:Hide()
            ImportCode(text)
        end)
        codeAsk.close = DialogButton(codeAsk, CLOSE, function() codeAsk:Hide() end)
    end
    codeAsk.importing = sparkle == nil
    codeAsk.code = sparkle and MadeCode(sparkle) or ""
    local title = NORMAL_FONT_COLOR:WrapTextInColorCode(C_AddOns.GetAddOnMetadata(ADDON_NAME, "Title") or ADDON_NAME)
    codeAsk.text:SetText(title .. "\n\n" .. (sparkle and ("The share code for %s. Press Ctrl+C to copy it."):format(tostring(sparkle.name))
        or "Paste a sparkle code from someone else and press Import."))
    codeAsk.ok:SetShown(codeAsk.importing)
    codeAsk.close:SetText(codeAsk.importing and CANCEL or CLOSE)
    codeAsk.ok:ClearAllPoints()
    codeAsk.close:ClearAllPoints()
    if codeAsk.importing then
        codeAsk.ok:SetPoint("BOTTOMRIGHT", codeAsk, "BOTTOM", -4, 16)
        codeAsk.close:SetPoint("BOTTOMLEFT", codeAsk, "BOTTOM", 4, 16)
    else
        codeAsk.close:SetPoint("BOTTOM", codeAsk, "BOTTOM", 0, 16)
    end
    codeAsk:SetHeight(codeAsk.text:GetStringHeight() + 73 + 34)
    codeAsk:Show()
    codeAsk.box:SetText(codeAsk.code)
    codeAsk.box:SetFocus()
    codeAsk.box:HighlightText()
end

-- A CVar sparkles need that the game refused: said once a session.
local told = {}
local function TellRefused()
    local cvar = ns.RefusedCVar()
    if not cvar or told[cvar] then return end
    told[cvar] = true
    ns.AfterFight("refused", function()
        if ns.SetupPending() then ns.Setup() end -- (what waited for the fight may set it right)
        local now = ns.RefusedCVar()
        if now then ShowNotice(ns.RefusedText(now)) end
    end)
end

local interactWatch = CreateFrame("Frame")
interactWatch:RegisterEvent("CVAR_UPDATE")
interactWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
-- What the window's reasons depend on.
for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA",
    "PLAYER_UPDATE_RESTING", "SKILL_LINES_CHANGED" }) do
    interactWatch:RegisterEvent(event)
end
interactWatch:SetScript("OnEvent", function(_, event, name)
    if not (ns.db and ns.RefusedCVar and ns.InteractOff) then return end -- (a file missing: the addon stays off)
    if window and window:IsShown() then Refresh() end
    if event == "PLAYER_ENTERING_WORLD" then return TellRefused() end
    if event ~= "CVAR_UPDATE" or issecretvalue(name) or type(name) ~= "string" then return end
    TellRefused()
    if name:lower() ~= "softtargetinteract" then return end
    if ns.InteractOff() then
        ns.AfterFight("interact", function() if ns.InteractOff() then ShowNotice(ns.INTERACT_OFF) end end)
    end
end)

ns.SPARKLE_TABS, ns.SPARKLE_NEEDS = TABS, NEEDS -- the Options rows' words with the gamepad UI on
