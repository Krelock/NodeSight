-- Collecting: remembers where you gathered each herb and ore and marks the places on
-- the world map and the minimap. Nothing is sent to or read from other players.
--
-- Saved account-wide in NodeSightDB.nodes[mapID][node] (the node's English name in
-- lower case): a list of places, each x * 10000 + y in thousandths of the map. A
-- place close to a known one adds nothing, so a zone's list stops growing.
--
-- Sections: Places, Gathering, World map, Minimap, Forget all.

local _, ns = ...

local ipairs, pairs = ipairs, pairs
local floor, abs = math.floor, math.abs

-- Frames are made with no parent, then SetParent (the gamepad UI hooks CreateFrame).
local function New(kind, parent, template)
    local frame = CreateFrame(kind, nil, nil, template)
    frame:SetParent(parent)
    return frame
end

---------------------------------------------------------------------------
-- Places
---------------------------------------------------------------------------

local UNITS = 1000 -- a map's width and height in saved units
local PACK = 10000 -- x * PACK + y
local SAME = 4 -- places of one node this close (in units, each way) are one spawn point

local function Nodes()
    if type(NodeSightDB.nodes) ~= "table" then NodeSightDB.nodes = {} end
    return NodeSightDB.nodes
end

local function Unpack(place)
    return floor(place / PACK), place % PACK
end

-- How many places are saved: all, herbs, ore.
local function Count()
    local herbs, ore = 0, 0
    for _, map in pairs(Nodes()) do
        if type(map) == "table" then
            for key, places in pairs(map) do
                local kind = type(places) == "table" and ns.NodeKind(key)
                if kind == "ore" then ore = ore + #places elseif kind == "herbs" then herbs = herbs + #places end
            end
        end
    end
    return herbs + ore, herbs, ore
end

-- Your map and place on it, or nil where the game gives none (dungeons and raids).
local function PlayerPlace()
    local map = C_Map.GetBestMapForUnit("player")
    if issecretvalue(map) or type(map) ~= "number" then return nil end
    local position = C_Map.GetPlayerMapPosition(map, "player")
    if issecretvalue(position) or not position then return nil end
    local x, y = position:GetXY()
    if issecretvalue(x) or issecretvalue(y) or type(x) ~= "number" or type(y) ~= "number" then return nil end
    if x <= 0 and y <= 0 then return nil end
    return map, floor(x * UNITS + 0.5), floor(y * UNITS + 0.5)
end

-- True if the place was new.
local function Remember(key, map, x, y)
    local nodes = Nodes()
    if type(nodes[map]) ~= "table" then nodes[map] = {} end
    if type(nodes[map][key]) ~= "table" then nodes[map][key] = {} end
    local places = nodes[map][key]
    for _, place in ipairs(places) do
        local px, py = Unpack(place)
        if abs(px - x) <= SAME and abs(py - y) <= SAME then return false end
    end
    places[#places + 1] = x * PACK + y
    return true
end

---------------------------------------------------------------------------
-- Gathering
---------------------------------------------------------------------------
-- Your cast on a herb or ore (the cast's target is the node's name), then loot from a
-- game object: gathered where you stand. The loot check keeps out a spell cast on a
-- player or pet that has a herb's name.

local LOOT_WAIT = 3 -- seconds from the cast's end to its loot

local cast -- { guid, key }: the gathering cast under way
local done -- { key, map, x, y, at }: the cast that worked, waiting for its loot

local function ObjectLoot()
    for slot = 1, GetNumLootItems() do
        local guid = GetLootSourceInfo(slot)
        if not issecretvalue(guid) and type(guid) == "string" and guid:find("^GameObject%-") then return true end
    end
    return false
end

local function Gathered()
    local found = done
    done = nil
    if not found or GetTime() - found.at > LOOT_WAIT or not ObjectLoot() then return end
    if Remember(found.key, found.map, found.x, found.y) then
        ns.RefreshNodePins()
        ns.RefreshSparkleWindow()
    end
end

-- Arguments: SENT (unit, target, castGUID), the others (unit, castGUID).
local watch = CreateFrame("Frame")
watch:SetScript("OnEvent", function(_, event, _, a, b)
    if event == "LOOT_READY" then return Gathered() end
    if event == "UNIT_SPELLCAST_SENT" then
        cast = nil
        if issecretvalue(a) or issecretvalue(b) or type(a) ~= "string" or b == nil then return end
        local kind = ns.NodeKind(a)
        if kind == "herbs" or kind == "ore" then cast = { guid = b, key = ns.NodeKey(a) } end
        return
    end
    if not cast or issecretvalue(a) or a ~= cast.guid then return end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local map, x, y = PlayerPlace()
        if map then done = { key = cast.key, map = map, x = x, y = y, at = GetTime() } end
    end
    cast = nil -- (succeeded, failed or interrupted)
end)

local function UpdateCollect()
    watch:UnregisterAllEvents()
    cast, done = nil, nil
    if ns.db.collect then
        for _, event in ipairs({ "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED",
            "UNIT_SPELLCAST_FAILED_QUIET", "UNIT_SPELLCAST_INTERRUPTED" }) do
            watch:RegisterUnitEvent(event, "player")
        end
        watch:RegisterEvent("LOOT_READY")
    end
    ns.RefreshNodePins()
end

---------------------------------------------------------------------------
-- World map
---------------------------------------------------------------------------
-- A small symbol on the map's canvas for each place on the map shown; the mouse on one
-- names its node, clicks go through to the map. Their look is set in the Collecting
-- settings, as NodeSight's minimap symbols once were.

local PICTURES = { "Each node's own icon", "Plain herb and ore icons" }
local SHAPES = { "Square", "Round", "Round, gold ring", "Round, slim gold ring" }
local SKILL_LOOKS = { "Red when too low", "Colored ring", "Colored gem", "Off" }
local OWN, RING, GEM = 1, 2, 3 -- (pictures: OWN; skill looks: 1 red, RING, GEM, 4 off)
local PLAIN_ICONS = { herbs = "Interface\\Icons\\INV_Misc_Flower_02", ore = "Interface\\Icons\\INV_Ore_Copper_01" }
local TRACKING = { herbs = "Professions_Tracking_Herb", ore = "Professions_Tracking_Ore" } -- a node with no item icon
local TOO_HARD = { 1, 0.2, 0.2 } -- red tint for nodes above your skill
local PIN_LEVEL = 100 -- over the canvas, if the map has no pin levels
-- The gold ring (MiniMap-TrackingBorder): size and top-left offset from the symbol's middle
-- for a 12 wide symbol, which center its hole on it; its outer edge across, per symbol size.
local GOLD_BORDER, GOLD_SIZE, GOLD_X, GOLD_Y, GOLD_FOR = 136430, 30, -9.3, 8.7, 12
local GOLD_OUTER = 17.6 / 12
local SLIM = 0.26 -- the slim ring: this share of the ring's width
-- High visibility tin and iron: the Necrolord covenant ring, half gray and tinted. Its hole
-- is 58 of its 80x82 pixels.
local ORE_RING = { atlas = "CovenantChoice-Offering-Ability-Ring-Necrolord", width = 80 / 58, height = 82 / 58, gray = 0.5,
    tints = { ["tin vein"] = { 0.374, 1, 0.972 }, ["iron deposit"] = { 0.82, 0.55, 0.36 } } }
-- Colored gem: the original game's gems; it has no orange one, so the yellow one is tinted.
local GEMS = { "Interface\\Common\\Indicator-Red", "Interface\\Common\\Indicator-Yellow", "Interface\\Common\\Indicator-Yellow",
    "Interface\\Common\\Indicator-Green", "Interface\\Common\\Indicator-Gray" }
local ORANGE = { 1, 0.55, 0.3 }
local GEM_SIZE, GEM_AT = 0.76, 0.43 -- per symbol size: the gem's size, and its offset to the lower right

-- Item icon by part of the node name (from Wowhead). First match wins, so "dark iron"
-- comes before "iron deposit".
local HERB_ICONS = {
    { "silverleaf", "inv_misc_herb_10" }, { "mageroyal", "inv_jewelry_talisman_03" },
    { "peacebloom", "inv_misc_flower_02" }, { "earthroot", "inv_misc_herb_07" },
    { "briarthorn", "inv_misc_root_01" }, { "swiftthistle", "inv_misc_herb_04" },
    { "bruiseweed", "inv_misc_herb_01" }, { "steelbloom", "inv_misc_flower_01" },
    { "kingsblood", "inv_misc_herb_03" }, { "liferoot", "inv_misc_root_02" },
    { "khadgar's whisker", "inv_misc_herb_08" }, { "grave moss", "inv_misc_dust_02" },
    { "fadeleaf", "inv_misc_herb_12" }, { "wintersbite", "inv_misc_flower_03" },
    { "stranglekelp", "inv_misc_herb_11" }, { "goldthorn", "inv_misc_herb_15" },
    { "firebloom", "inv_misc_herb_19" }, { "purple lotus", "inv_misc_herb_17" },
    { "arthas' tears", "inv_misc_herb_13" }, { "sungrass", "inv_misc_herb_18" },
    { "blindweed", "inv_misc_herb_14" }, { "ghost mushroom", "inv_mushroom_08" },
    { "gromsblood", "inv_misc_herb_16" }, { "dreamfoil", "inv_misc_herb_dreamfoil" },
    { "golden sansam", "inv_misc_herb_sansamroot" }, { "mountain silversage", "inv_misc_herb_mountainsilversage" },
    { "plaguebloom", "inv_misc_herb_plaguebloom" }, { "icecap", "inv_misc_herb_icecap" },
    { "black lotus", "inv_misc_herb_blacklotus" }, { "hive thistle", "inv_misc_spineleaf-_01" },
    { "demonsage", "inv_misc_herb_heartblossom" }, { "death lotus", "inv_nulllotus_void" },
    { "marefoil", "item_herbc" }, { "stranglevine", "inv_herbalism_70_nightmaredreamleaf" },
    { "frilled lichen", "inv_misc_food_109_honeylichen" }, { "rosecap", "inv_misc_herb_talandrasrose" },
}
local ORE_ICONS = {
    { "copper vein", "inv_ore_copper_01" }, { "tin vein", "inv_ore_tin_01" },
    { "silver vein", "inv_stone_16" }, { "dark iron", "inv_ore_mithril_01" },
    { "iron deposit", "inv_ore_iron_01" }, { "gold vein", "inv_ore_copper_01" },
    { "mithril deposit", "inv_ore_mithril_02" }, { "truesilver deposit", "inv_ore_truesilver_01" },
    { "thorium vein", "inv_ore_thorium_02" }, { "indurium", "inv_ore_mithril_01" },
    { "incendicite", "inv_ore_thorium_01" }, { "bloodstone", "inv_ore_thorium_01" },
    { "chunk of amber", 463485 }, -- by file ID: the file's name has spaces
    { "small obsidian", "inv_misc_stonetablet_01" },
    { "large obsidian", "inv_stone_15" }, { "moonstone", "inv_misc_apexis_crystal" },
}

-- The item icon for a node's key, or nil.
local function NodeIcon(key, kind)
    for _, entry in ipairs(kind == "ore" and ORE_ICONS or HERB_ICONS) do
        if key:find(entry[1], 1, true) then
            return type(entry[2]) == "number" and entry[2] or "Interface\\Icons\\" .. entry[2]
        end
    end
end

-- The profession window's colors for a skill-up chance, 1 (too hard) to 5 (none).
local function SkillColor(level)
    return level == 1 and RED_FONT_COLOR or level == 2 and DIFFICULT_DIFFICULTY_COLOR or level == 3 and FAIR_DIFFICULTY_COLOR
        or level == 4 and EASY_DIFFICULTY_COLOR or TRIVIAL_DIFFICULTY_COLOR
end

local pins, used = {}, 0 -- the symbols made, and how many show
local hooked = false

-- This client's name for a node with a capital first letter; English names in title case.
local localNames
local function DisplayName(key)
    if not localNames then
        localNames = {}
        for _, list in ipairs({ "HERBS", "ORE" }) do
            for name, english in pairs(ns.LOCALE and ns.LOCALE[list] or {}) do localNames[english] = name end
        end
    end
    if localNames[key] then return (localNames[key]:gsub("^%l", string.upper)) end
    return (key:gsub("(%S)(%S*)", function(first, rest)
        if first .. rest == "of" then return "of" end
        return first:upper() .. rest
    end))
end

local function Canvas()
    return WorldMapFrame and WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas()
end

local function PinEnter(pin)
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:SetText(DisplayName(pin.key))
    GameTooltip:Show()
end
local function PinLeave() GameTooltip:Hide() end

-- Textures of a symbol: no snapping, so small ones stay round.
local function Smooth(region)
    region:SetSnapToPixelGrid(false)
    region:SetTexelSnappingBias(0)
    return region
end

-- A symbol's frame. A named one shows its node's name under the mouse and lets clicks
-- through; the others take no mouse.
local function NewSymbol(parent, named)
    local pin = New("Frame", parent)
    pin.icon = Smooth(pin:CreateTexture(nil, "ARTWORK"))
    pin.icon:SetAllPoints()
    if named and pin.SetMouseMotionEnabled and pin.SetMouseClickEnabled then
        pin:SetMouseMotionEnabled(true)
        pin:SetMouseClickEnabled(false)
        pin:SetScript("OnEnter", PinEnter)
        pin:SetScript("OnLeave", PinLeave)
    end
    return pin
end

local function Pin(canvas)
    used = used + 1
    pins[used] = pins[used] or NewSymbol(canvas, true)
    return pins[used]
end

-- The ring's size and place: the gold ring by its offset, the ore ring on the middle; the
-- slim ring is cut from the outside by a circle (and goes under the symbol, which hides
-- its dark inner edge).
local function SizeRing(pin)
    local size, ring = pin.size, pin.ring
    ring:ClearAllPoints()
    local outer
    if pin.tint then
        ring:SetSize(size * ORE_RING.width, size * ORE_RING.height)
        ring:SetPoint("CENTER", pin.icon, "CENTER")
        outer = ORE_RING.width
    else
        local scale = size / GOLD_FOR
        ring:SetSize(GOLD_SIZE * scale, GOLD_SIZE * scale)
        ring:SetPoint("TOPLEFT", pin.icon, "CENTER", GOLD_X * scale, GOLD_Y * scale)
        outer = GOLD_OUTER
    end
    local slim = pin.shape == 4
    if slim and not pin.cut then
        -- Clear outside its square, or the game stretches the circle's edge outward.
        pin.cut = Smooth(pin:CreateMaskTexture())
        pin.cut:SetAtlas("CircleMask", false, nil, nil, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        pin.cut:SetPoint("CENTER", pin.icon, "CENTER")
    end
    if slim then
        local across = size * (1 + (outer - 1) * SLIM)
        pin.cut:SetSize(across, across)
    end
    if slim ~= (pin.slim or false) then
        pin.slim = slim
        if slim then ring:AddMaskTexture(pin.cut) else ring:RemoveMaskTexture(pin.cut) end
        ring:SetDrawLayer("OVERLAY", slim and -1 or 1)
    end
end

-- Size and shape; the mask and ring are made the first time a symbol needs them.
local function ApplyShape(pin, look)
    pin.shape, pin.size = look.shape, look.size
    pin:SetSize(look.size, look.size)
    local round, ringed = look.shape > 1, look.shape > 2
    if round and not pin.mask then
        pin.mask = Smooth(pin:CreateMaskTexture())
        pin.mask:SetAtlas("CircleMask")
        pin.mask:SetAllPoints(pin.icon)
    end
    if round ~= (pin.round or false) then
        pin.round = round
        if round then pin.icon:AddMaskTexture(pin.mask) else pin.icon:RemoveMaskTexture(pin.mask) end
    end
    if ringed and not pin.ring then
        pin.ring = Smooth(pin:CreateTexture(nil, "OVERLAY", nil, 1))
        pin.ring:SetTexture(GOLD_BORDER)
    end
    if pin.ring then
        pin.ring:SetShown(ringed)
        if ringed then SizeRing(pin) end
    end
    pin.ringLook = nil -- the ring's color is set again
    if pin.gem then
        pin.gem:SetSize(look.size * GEM_SIZE, look.size * GEM_SIZE)
        pin.gem:SetPoint("CENTER", pin.icon, "CENTER", look.size * GEM_AT, -look.size * GEM_AT)
    end
end

-- The picture, the ore ring, skill colors and see-through, each set only when it changes.
local function ApplyLook(pin, key, kind, look)
    local picture = look.picture == OWN and NodeIcon(key, kind) or look.picture ~= OWN and PLAIN_ICONS[kind] or TRACKING[kind]
    if pin.picture ~= picture then
        pin.picture = picture
        if picture == TRACKING[kind] then
            pin.icon:SetAtlas(picture)
        else
            pin.icon:SetTexture(picture)
            pin.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- (without the icon's border)
        end
    end
    local level = look.skill ~= 4 and ns.SkillLevel(key, kind) or nil
    local hard = look.skill == 1 and level == 1
    if pin.hard ~= hard then
        pin.hard = hard
        if hard then pin.icon:SetVertexColor(TOO_HARD[1], TOO_HARD[2], TOO_HARD[3]) else pin.icon:SetVertexColor(1, 1, 1) end
    end
    -- The ring: tin's and iron's own, colored by the skill, or gold.
    local ringed = pin.ring and look.shape > 2
    local tint = ringed and look.oreRings and not (look.skill == RING and level) and ORE_RING.tints[key] or false
    if ringed and tint ~= (pin.tint or false) then
        local swap = not tint ~= not pin.tint
        pin.tint = tint
        if swap then
            if tint then
                pin.ring:SetAtlas(ORE_RING.atlas)
            else
                pin.ring:SetTexture(GOLD_BORDER)
                pin.ring:SetTexCoord(0, 1, 0, 1) -- (SetTexture keeps an atlas's coords)
            end
            SizeRing(pin)
        end
    end
    local ringLook = ringed and (look.skill == RING and level or tint) or false
    if ringed and pin.ringLook ~= ringLook then
        pin.ringLook = ringLook
        if look.skill == RING and level then
            pin.ring:SetDesaturated(true)
            pin.ring:SetVertexColor(SkillColor(level):GetRGB())
        elseif tint then
            pin.ring:SetVertexColor(tint[1], tint[2], tint[3])
            pin.ring:SetDesaturation(ORE_RING.gray)
        else
            pin.ring:SetVertexColor(1, 1, 1)
            pin.ring:SetDesaturated(false)
        end
    end
    -- The gem, made on first use.
    local gem = look.skill == GEM and level or false
    if gem and not pin.gem then
        pin.gem = Smooth(pin:CreateTexture(nil, "OVERLAY", nil, 2))
        pin.gem:SetSize(pin.size * GEM_SIZE, pin.size * GEM_SIZE)
        pin.gem:SetPoint("CENTER", pin.icon, "CENTER", pin.size * GEM_AT, -pin.size * GEM_AT)
    end
    if pin.gem and pin.gemLevel ~= gem then
        pin.gemLevel = gem
        if gem then
            pin.gem:SetTexture(GEMS[gem])
            local color = gem == 2 and ORANGE or { 1, 1, 1 }
            pin.gem:SetVertexColor(color[1], color[2], color[3])
        end
        pin.gem:SetShown(gem ~= false)
    end
    -- See-through on the whole symbol (a frame's alpha, which colors don't change).
    if pin.alpha ~= look.alpha then
        pin.alpha = look.alpha
        pin:SetAlpha(look.alpha)
    end
end

-- The map's own level for points of interest, where it has one.
local function PinLevel(canvas)
    local manager = WorldMapFrame.GetPinFrameLevelsManager and WorldMapFrame:GetPinFrameLevelsManager()
    if manager and manager.GetValidFrameLevel then
        local ok, level = pcall(manager.GetValidFrameLevel, manager, "PIN_FRAME_LEVEL_AREA_POI")
        if ok and type(level) == "number" then return level end
    end
    return canvas:GetFrameLevel() + PIN_LEVEL
end

-- Sizes and places the symbols shown. The canvas grows as the map zooms in: the symbols
-- keep their size on screen. A zoom only needs this.
local function Place()
    local canvas = Canvas()
    local width, height = canvas:GetSize()
    local scale = WorldMapFrame.GetCanvasScale and WorldMapFrame:GetCanvasScale() or canvas:GetScale()
    scale = scale and scale > 0 and 1 / scale or 1
    for i = 1, used do
        local pin = pins[i]
        pin:SetScale(scale)
        pin:SetPoint("CENTER", canvas, "TOPLEFT", pin.x / UNITS * width / scale, -pin.y / UNITS * height / scale)
    end
end

-- The symbols' settings.
local function CurrentLook()
    local db = ns.db
    return { picture = db.collectPicture, shape = db.collectShape, size = db.collectSize, skill = db.collectSkill,
        oreRings = db.collectOreRings, alpha = db.collectOpacity / 100 }
end

-- The symbols of the map shown, set up again.
local function Refresh()
    used = 0
    local canvas = Canvas()
    local db = ns.db
    if canvas and WorldMapFrame:IsShown() and db.collect and db.collectMap then
        local map = WorldMapFrame:GetMapID()
        local nodes = not issecretvalue(map) and map and Nodes()[map]
        if type(nodes) == "table" then
            local level = PinLevel(canvas)
            local look = CurrentLook()
            look.alpha = 1 -- solid: no node under them on the world map
            for key, places in pairs(nodes) do
                local kind = ns.NodeKind(key)
                if (kind == "herbs" or kind == "ore") and type(places) == "table" then
                    for _, place in ipairs(places) do
                        local pin = Pin(canvas)
                        pin.key, pin.x, pin.y = key, Unpack(place)
                        if pin.shape ~= look.shape or pin.size ~= look.size then ApplyShape(pin, look) end
                        ApplyLook(pin, key, kind, look)
                        pin:SetFrameLevel(level)
                        pin:ClearAllPoints()
                        pin:Show()
                    end
                end
            end
            Place()
        end
    end
    for i = used + 1, #pins do pins[i]:Hide() end
end

---------------------------------------------------------------------------
-- Minimap
---------------------------------------------------------------------------
-- The same symbols on the minimap for the places in its view, moved as you move;
-- nothing is worked out while you stand still. They take no mouse, so the game's own
-- dot under one keeps its tooltip.

-- Round (true) or square per quarter: 1 bottom right, 2 bottom left, 3 top right, 4 top
-- left (LibDBIcon-1.0's table and numbering).
local QUARTERS = {
    ["ROUND"] = { true, true, true, true },
    ["SQUARE"] = { false, false, false, false },
    ["CORNER-TOPLEFT"] = { false, false, false, true },
    ["CORNER-TOPRIGHT"] = { false, false, true, false },
    ["CORNER-BOTTOMLEFT"] = { false, true, false, false },
    ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
    ["SIDE-LEFT"] = { false, true, false, true },
    ["SIDE-RIGHT"] = { true, false, true, false },
    ["SIDE-TOP"] = { false, false, true, true },
    ["SIDE-BOTTOM"] = { true, true, false, false },
    ["TRICORNER-TOPLEFT"] = { false, true, true, true },
    ["TRICORNER-TOPRIGHT"] = { true, false, true, true },
    ["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
    ["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}
-- EllesmereUI's minimap shapes (its minimap replaces the game's); "rectangular" is a
-- square cut at the top and bottom.
local ELLESMERE = { circle = QUARTERS.ROUND, textured_circle = QUARTERS.ROUND, square = QUARTERS.SQUARE, rectangular = QUARTERS.SQUARE }

local mini -- the frame over the minimap
local minis, miniUsed, miniShown = {}, 0, 0
local version = 0 -- goes up when the places or the symbols' look change
local last = {} -- what the symbols were last placed for
local kinds = {} -- NodeKind by node key

local function ReadQuarters()
    local module = type(EllesmereUI) == "table" and type(EllesmereUI._ModuleNS) == "table" and EllesmereUI._ModuleNS.EllesmereUIMinimap
    if type(module) == "table" and type(module.MinimapShape) == "function" then
        local ok, shape = pcall(module.MinimapShape)
        if ok and ELLESMERE[shape] then return ELLESMERE[shape] end
    end
    if GetMinimapShape then
        local ok, shape = pcall(GetMinimapShape)
        if ok and QUARTERS[shape] then return QUARTERS[shape] end
    end
    return QUARTERS.ROUND
end

-- The shape, read again once a second at most.
local shape, shapeAt
local function Quarters()
    local now = GetTime()
    if not shape or now - shapeAt >= 1 then shape, shapeAt = ReadQuarters(), now end
    return shape
end

-- How high a square minimap cut at the top and bottom reaches, as a share of its half
-- width: its hit rect's insets, when both are set.
local function Crop()
    local ok, _, _, top, bottom = pcall(Minimap.GetHitRectInsets, Minimap)
    if not ok or type(top) ~= "number" or type(bottom) ~= "number" or issecretvalue(top) or issecretvalue(bottom) then return 1 end
    local width = Minimap:GetWidth()
    if not (top > 0 and bottom > 0 and width > 0) then return 1 end
    return math.max(0, math.min(1, 1 - 2 * math.max(top, bottom) / width))
end

-- A point from the minimap's middle (y up) inside its shape.
local function InShape(x, y, half, quarters, crop)
    if quarters[(y < 0 and 0 or 2) + (x < 0 and 2 or 1)] then return x * x + y * y <= half * half end
    return abs(x) <= half and abs(y) <= half * crop
end

-- Your place on a map (0 to 1) and the map's size in yards; nil where unknown.
local function MapPosition(map)
    local position = C_Map.GetPlayerMapPosition(map, "player")
    if issecretvalue(position) or not position then return nil end
    local x, y = position:GetXY()
    local width, height = C_Map.GetMapWorldSize(map)
    if issecretvalue(x) or issecretvalue(y) or issecretvalue(width) or issecretvalue(height) or type(x) ~= "number"
        or type(y) ~= "number" or type(width) ~= "number" or type(height) ~= "number" or width <= 0 or height <= 0 then return nil end
    return x, y, width, height
end

-- The places within reach plus NEAR_STEP yards of where the list was made, so a frame
-- goes through those and not every place on the map. Made again after NEAR_STEP yards.
local NEAR_STEP = 20
local nearKey, nearKind, nearPlace, nearCount = {}, {}, {}, 0
local near = {} -- what the list was made for (the map's places, ...)

local function Near(nodes, x, y, width, height, reach)
    if near.nodes == nodes and near.version == version and near.reach == reach then
        local east, north = (x - near.x) * width, (y - near.y) * height
        if east * east + north * north <= NEAR_STEP * NEAR_STEP then return end
    end
    local far = (math.sqrt(reach) + NEAR_STEP) ^ 2
    local n = 0
    for key, places in pairs(nodes) do
        local kind = kinds[key]
        if kind == nil then
            kind = ns.NodeKind(key) or false
            kinds[key] = kind
        end
        if (kind == "herbs" or kind == "ore") and type(places) == "table" then
            for _, place in ipairs(places) do
                local east = (floor(place / PACK) / UNITS - x) * width
                local north = (y - place % PACK / UNITS) * height
                if east * east + north * north <= far then
                    n = n + 1
                    nearKey[n], nearKind[n], nearPlace[n] = key, kind, place
                end
            end
        end
    end
    for i = n + 1, nearCount do nearKey[i], nearKind[i], nearPlace[i] = nil, nil, nil end
    nearCount = n
    near.nodes, near.version, near.reach, near.x, near.y = nodes, version, reach, x, y
end

local function Follow()
    -- Not moved (UnitPosition, plain numbers, no table made), zoom, facing, shape and places the same: nothing to do.
    local wx, wy = UnitPosition("player")
    if issecretvalue(wx) or issecretvalue(wy) then wx, wy = nil, nil end
    local radius = C_Minimap.GetViewRadius()
    local facing = C_CVar.GetCVar("rotateMinimap") == "1" and GetPlayerFacing() or 0
    if issecretvalue(facing) then facing = nil end
    local quarters = Quarters()
    if wx and wx == last.wx and wy == last.wy and radius == last.radius and facing == last.facing and version == last.version
        and quarters == last.quarters then return end
    last.wx, last.wy, last.radius, last.facing, last.version, last.quarters = wx, wy, radius, facing, version, quarters
    miniUsed = 0
    local map = C_Map.GetBestMapForUnit("player")
    local nodes = not issecretvalue(map) and map and Nodes()[map]
    local x, y, width, height
    if type(nodes) == "table" then x, y, width, height = MapPosition(map) end
    if x and facing and not issecretvalue(radius) and type(radius) == "number" and radius > 0 then
        local half = Minimap:GetWidth() / 2
        local square = not (quarters[1] or quarters[2] or quarters[3] or quarters[4])
        local crop = square and Crop() or 1
        -- In yards: as far as the edge, or a square's corners.
        local scale, reach = half / radius, radius * radius * ((quarters[1] and quarters[2] and quarters[3] and quarters[4]) and 1 or 2)
        -- A rotating minimap turns everything by your facing.
        local sin, cos = math.sin(facing), math.cos(facing)
        local look
        Near(nodes, x, y, width, height, reach)
        for i = 1, nearCount do
            local key, kind, place = nearKey[i], nearKind[i], nearPlace[i]
            local east = (floor(place / PACK) / UNITS - x) * width
            local north = (y - place % PACK / UNITS) * height
            if east * east + north * north <= reach then
                local dx, dy = (east * cos + north * sin) * scale, (north * cos - east * sin) * scale
                if InShape(dx, dy, half, quarters, crop) then
                    miniUsed = miniUsed + 1
                    local pin = minis[miniUsed] or NewSymbol(mini)
                    minis[miniUsed] = pin
                    if pin.key ~= key or pin.version ~= version then
                        look = look or CurrentLook()
                        pin.key, pin.version = key, version
                        if pin.shape ~= look.shape or pin.size ~= look.size then ApplyShape(pin, look) end
                        ApplyLook(pin, key, kind, look)
                    end
                    pin:SetPoint("CENTER", mini, "CENTER", dx, dy)
                end
            end
        end
    end
    for i = miniUsed + 1, miniShown do minis[i]:Hide() end
    for i = miniShown + 1, miniUsed do minis[i]:Show() end
    miniShown = miniUsed
end

-- An error here would repeat every frame: reported once, then no minimap symbols until a reload.
local miniBroken = false
local function MiniUpdate()
    if not xpcall(Follow, geterrorhandler()) then
        miniBroken = true
        mini:Hide()
    end
end

local function UpdateMinimap()
    version = version + 1
    if mini then mini:SetShown(not miniBroken and ns.db.collect == true and ns.db.collectMinimap == true) end
end

local function MakeMinimap()
    mini = New("Frame", Minimap)
    mini:SetAllPoints()
    mini:SetScript("OnUpdate", MiniUpdate)
    -- A skill-up changes Skill colors.
    mini:RegisterEvent("SKILL_LINES_CHANGED")
    mini:SetScript("OnEvent", function() version = version + 1 end)
end

-- An error here would repeat at every map change: reported once, then no pins until a reload.
local broken = false
local function Run(fn)
    if broken or not hooked then return end
    if not xpcall(fn, geterrorhandler()) then
        broken = true
        for _, pin in ipairs(pins) do pin:Hide() end
    end
end
function ns.RefreshNodePins()
    UpdateMinimap()
    Run(Refresh)
end
local function Rescale()
    if used > 0 then Run(Place) end
end

-- Once Blizzard_WorldMap is loaded.
local function HookMap()
    if hooked or not Canvas() then return end
    hooked = true
    WorldMapFrame:HookScript("OnShow", ns.RefreshNodePins)
    if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", ns.RefreshNodePins) end
    if WorldMapFrame.OnCanvasScaleChanged then hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", Rescale) end
    ns.RefreshNodePins()
end

-- At load, once the saved settings are in use.
function ns.Collect()
    MakeMinimap()
    HookMap()
    if not hooked then
        local wait = CreateFrame("Frame")
        wait:RegisterEvent("ADDON_LOADED")
        wait:SetScript("OnEvent", function(self)
            HookMap()
            if hooked then self:UnregisterAllEvents() end
        end)
    end
    UpdateCollect()
end

---------------------------------------------------------------------------
-- Forget all
---------------------------------------------------------------------------
-- A dialog like the game's asks first.

local ask

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

local function Forget()
    NodeSightDB.nodes = {}
    ns.RefreshNodePins()
    ns.RefreshSparkleWindow()
end

function ns.AskForget()
    local count = Count()
    if count == 0 then return end
    if not ask then
        ask = New("Frame", UIParent)
        ask:SetFrameStrata("FULLSCREEN_DIALOG") -- (over the settings window)
        ask:SetToplevel(true)
        ask:EnableMouse(true)
        ask:SetPoint("TOP", UIParent, "TOP", 0, -135)
        ask:SetWidth(420)
        local background = ask:CreateTexture(nil, "BACKGROUND", nil, -7)
        background:SetAtlas("UI-DialogBox-Background-Dark", true)
        background:SetPoint("TOPLEFT", 7, -7)
        background:SetPoint("BOTTOMRIGHT", -7, 7)
        local edge = ask:CreateTexture(nil, "BACKGROUND", nil, -4)
        edge:SetAtlas("UI-DiamondDialogBox-Border", true)
        edge:SetAllPoints()
        ask.text = ask:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        ask.text:SetPoint("TOP", 0, -20)
        ask.text:SetWidth(380)
        ask.text:SetSpacing(3)
        ask.yes = DialogButton(ask, "Forget all", function()
            ask:Hide()
            Forget()
        end)
        ask.no = DialogButton(ask, CANCEL, function() ask:Hide() end)
        ask.yes:SetPoint("BOTTOMRIGHT", ask, "BOTTOM", -4, 16)
        ask.no:SetPoint("BOTTOMLEFT", ask, "BOTTOM", 4, 16)
    end
    ask.text:SetText(NORMAL_FONT_COLOR:WrapTextInColorCode("NodeSight") .. "\n\n"
        .. ("Forget all %d %s where you gathered, for all your characters? This can't be undone."):format(count, count == 1 and "place" or "places"))
    ask:SetHeight(ask.text:GetStringHeight() + 73)
    ask:Show()
end

ns.UpdateCollect, ns.NodeCount = UpdateCollect, Count
ns.COLLECT_PICTURES, ns.COLLECT_SHAPES, ns.COLLECT_SKILL_LOOKS = PICTURES, SHAPES, SKILL_LOOKS
ns.COLLECT_RANGES = { collectSize = { 8, 24, 1 }, collectOpacity = { 10, 100, 5 } } -- the sliders: low, high, step
