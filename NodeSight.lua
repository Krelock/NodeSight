-- AI has done an awful job at commenting on the code. I'm going to try and fix
-- it up within the next few updates and put most of my mods on GitHub. I did
-- not expect so many people to be going through this and to be so interested!
-- Thank you to everyone trying my addons. I appreciate you all, this has made
-- my year.
--
-- NodeSight: herbs and ore on the minimap get their own symbols, an arrow
-- points to the nearest one, and the one in front of you sparkles.
--
-- Files, in load order (they share functions through the addon table `ns`):
--   Locales\*.lua    node names in other languages (each loads only on its client)
--   Zones.lua        map and instance IDs of the rares' home zones
--   Names.lua        node names, icons and skill levels
--   RareNames.lua    rare names in the client's language, asked from the client
--   NodeSight.lua    defaults, the minimap scan, loading and events
--   Sparkles.lua     sparkles on the herb or ore in front of you
--   FarSparkles.lua  sparkles on far away herbs and ore (Beta)
--   WhatsNew.lua     the patch notes dialog
--   Settings.lua     the settings pages
--
-- Sections: Minimap scan, Node kinds, Learning nodes, Switching finders, Tooltip,
-- Symbols and arrow, Splitting groups, Following, Scanning, Running the scan, Loading.

local ADDON_NAME, ns = ...

local ipairs, pairs = ipairs, pairs

local defaults = {
    herbs = false, -- sparkles on herbs
    ore = false, -- sparkles on ore
    others = false, -- sparkles on other objects
    gameIcons = false, -- keep the game's interact icons while sparkles are on
    arrow = false, -- arrow to the nearest node
    arrowLocked = false, -- the arrow can't be dragged, and clicks go through it
    arrowSize = 40, -- arrow size
    arrowSkip = true, -- the arrow passes over the node you're at
    arrowFirst = false, -- the arrow to herbs and ore before anything else
    arrowHerbs = true, -- what the arrow points to: herbs,
    arrowOre = true, -- ore,
    arrowChests = true, -- chests,
    arrowRares = true, -- rares,
    arrowLeylines = true, -- leylines and convergences
    mapIcons = true, -- symbols on the minimap
    shape = 3, -- 1 square, 2 round, 3 round with a gold ring, 4 with a slim one
    oreRings = false, -- green and rust rings for tin and iron
    iconSize = 11, -- symbol size
    hard = true, -- red symbols for nodes above your skill
    clearNear = false, -- symbols see-through over your own arrow
    sound = false, -- sound when something new shows up
    scan = true, -- the minimap scan
    scanDetail = 2, -- 3 full, 2 lighter, 1 lightest
    switchFinders = false, -- Find Herbs and Find Minerals in turn
    switchYards = 15, -- yards between switches (10 at least)
    combatScan = true, -- keep scanning in combat
    rares = true, -- rare beasts and humanoids (Beta)
    rareIcon = 2, -- which of ICONS.rares
    leylines = true, -- Skyborne: leylines and elemental convergences, while the racial is ready
    worldMark = false, -- Beta: sparkles on far away herbs and ore
    dotScale = 100, -- the game's own dot size, in percent
    sparkleColor = "ffffffff", -- sparkle tint, "aarrggbb" (white = none)
    size = 100, -- sparkle area size
    height = -60, -- sparkle area offset from the plate's bottom
    count = 9, -- sparkles twinkling at once
}
local db = defaults -- NodeSightDB once it's loaded
ns.db = db -- shared with the other files

---------------------------------------------------------------------------
-- Minimap scan
---------------------------------------------------------------------------
-- Addons can't see where herbs are, but the minimap's tracking dots can be
-- read: a fake mouse (Minimap:UpdateMouseoverAtPoint) is moved over a grid of
-- points, a few per frame, and the minimap tooltip names the dots under it.
-- Points that hit the same dot are grouped into one place.

local STEP = 8 -- grid spacing in minimap units
local PER_FRAME = 60 -- points per frame
local WAIT = 0.5 -- seconds between scans
local NO_FINDER = 5 -- seconds between checks while no finder is on
-- Tracking spell IDs: Find Herbs, Find Minerals, Find Treasure.
local FINDERS = { [2383] = "herbs", [2580] = "ore", [2481] = "treasure" }
FINDERS[1494] = "rares" -- Track Beasts (only with the rares setting)
FINDERS[19883], FINDERS[5225] = "rares", "rares" -- Track Humanoids: hunters', druids'
local MAX_ICONS = 40
local ICONS = { herbs = "Professions_Tracking_Herb", ore = "Professions_Tracking_Ore" }
ICONS.rares = { "VignetteKill", "VignetteKillElite", "Rare-Elite-Star" }
-- Skyborne racials and what each finds, shown while it is ready: High Order Skyborne's
-- Read Leyline leylines, Windshaper Skyborne's Skysight elemental convergences. The
-- icon is the spell's, for when the game gives none.
local RACIALS = {
    leyline = { spell = 1259705, icon = "Interface\\Icons\\ability_mage_incantersabsorbtion" },
    convergence = { spell = 1259686, icon = "Interface\\Icons\\ability_skyreach_lens_flare" },
}
local ICON_SIZE = 12 -- the size the gold ring is fitted to
local NORMAL_DOTS = 100 -- the game's own dot size (%)
-- Round shapes use Blizzard's circle mask; the gold ring is MiniMap-TrackingBorder.
local SHAPES = { "Square", "Round", "Round, gold ring", "Round, slim gold ring" }
local CIRCLE = "CircleMask"
local GOLD_BORDER = 136430
-- Gold ring size and top-left offset that center its hole on the symbol.
local GOLD_SIZE, GOLD_X, GOLD_Y = 30, -9.3, 8.7
-- High visibility tin and iron: the Necrolord covenant ring, half desaturated
-- and tinted. Its hole is 58 of its 80x82 pixels, hence the size ratios.
local oreRing = {
    atlas = "CovenantChoice-Offering-Ability-Ring-Necrolord",
    width = 80 / 58, height = 82 / 58, gray = 0.5,
    tints = {
        ["Interface\\Icons\\inv_ore_tin_01"] = { 0.374, 1, 0.972 }, -- #43B3AE
        ["Interface\\Icons\\inv_ore_iron_01"] = { 0.82, 0.55, 0.36 },
    },
}
oreRing.ok = C_Texture.GetAtlasExists(oreRing.atlas)
-- The gold ring's outer edge across, per symbol size (measured on Blizzard's art).
local GOLD_OUTER = 17.6 / 12
local SLIM = 26 -- the slim gold ring: the gold ring cut to this share of its width (%)
local ARROW = "MiniMap-QuestArrow" -- points up
-- The arrow's checkbox for each kind, and how near the node you're at is (yards).
local ARROW_TO = { herbs = "arrowHerbs", ore = "arrowOre", treasure = "arrowChests", rares = "arrowRares", leyline = "arrowLeylines", convergence = "arrowLeylines" }
local SKIP_YARDS = 5
-- See-through near you: the game draws your own arrow under addons' textures, so a
-- symbol over it (half its size plus this many minimap units from the middle) gets this alpha.
local PLAYER_ARROW, CLEAR = 8, 0.35
-- Grid points are keyed x * 1000 + y; these are the offsets of the 8 neighbours.
local AROUND = { -1001, -1000, -999, -1, 1, 999, 1000, 1001 }
local AROUND4 = { -1000, -1, 1, 1000 } -- and the 4 direct ones

-- Close herbs merge into one big group of hits. A group too big for one dot
-- (see Single) is probed again on a finer grid and split into dots.
local FINE = 3
local MAX_FINE = 900 -- max fine points per scan
local MIN_VOTES = 6 -- outline points a dot has to explain
local TOL = 2 -- outline fit tolerance (units)
local MAX_DISCS = 8
local hitRadius = 15 -- dot hit radius in minimap units (refined as dots are fitted)

-- Max grid points one dot can cover; more means several dots.
local function Single()
    return math.floor(math.pi * hitRadius ^ 2 / STEP ^ 2 + 0.6 * math.pi * hitRadius / STEP)
end

-- Scan detail levels: grid spacing and seconds between scans.
local DETAIL = { [3] = { 8, 0.5 }, [2] = { 10, 0.75 }, [1] = { 12, 1 } }
-- After SETTLE scans with nothing new, drop a detail level.
local SETTLE = 4
local eased, quiet = 0, 0 -- detail levels dropped, quiet scans since

local scan
local wait = 0 -- seconds until the next scan
local hurry = 0 -- scans left at full pace (after loot, rares)
local markers = {} -- the places the last scan found, nearest first
local grid, gridWidth -- grid points for this minimap size
local tracker, arrow, arrowTexture, arrowText
local mapFrame, mapIcons = nil, {}
local empties = 0 -- empty scans in a row
local emptyMap, emptyX, emptyY -- where the last empty scan was
-- Standing still slows the scan down (REST), up to SLEEP times the wait.
local SLEEP = 30
local REST = { [0] = 4, 4, 8, 16, SLEEP }
local rested = 0 -- scans started in a row while standing still
local heard = {} -- recent finds, for the Sound setting
local shownText
local arrowOn = false
local turning -- the minimap was rotating at the last scan
-- Switch state: kind, map, x, y, scanned, picked (see Switch and Picked).
local turns = {}
local racialWasReady = false -- a Skyborne racial was ready at the last cooldown change
local racialShown = false -- the last scan found a leyline or convergence

-- Scan detail setting (3 if invalid).
local function SettingLevel()
    return DETAIL[db.scanDetail] and db.scanDetail or 3
end

-- Sets STEP and WAIT for the current detail level.
local function ApplyDetail()
    local level = DETAIL[math.max(1, SettingLevel() - eased)]
    STEP, WAIT = level[1], level[2]
    gridWidth = nil -- rebuild the grid
end

local function Enabled()
    return db.scan and (db.arrow or db.mapIcons or db.sound or db.worldMark)
end

-- Facing in radians (counterclockwise from north), or nil.
local function PlayerFacing()
    local facing = GetPlayerFacing()
    if issecretvalue(facing) then return nil end
    return facing
end

-- Map ID, your x and y on it (0-1) and its size in yards; nil if unknown.
local function MapPosition()
    local map = C_Map.GetBestMapForUnit("player")
    if not map or issecretvalue(map) then return nil end
    local position = C_Map.GetPlayerMapPosition(map, "player")
    if not position or issecretvalue(position) then return nil end
    local x, y = position:GetXY()
    local width, height = C_Map.GetMapWorldSize(map)
    if issecretvalue(x) or issecretvalue(y) or not width or not height or width <= 0 or height <= 0 then return nil end
    return map, x, y, width, height
end

-- Moved more than 3 yards since the last empty scan?
local function Moved(map, x, y, width, height)
    if not map or map ~= emptyMap then return true end
    local dx, dy = (x - emptyX) * width, (y - emptyY) * height
    return dx * dx + dy * dy > 9
end

-- From Names.lua.
local Plain, NodeKind, NodeIcon = ns.Plain, ns.NodeKind, ns.NodeIcon
local TREASURE, RARES, FRIENDLY = ns.TREASURE, ns.RARES, ns.FRIENDLY
local TOO_HARD, skills, professions, TooHard, NodeSkill = ns.TOO_HARD, ns.skills, ns.professions, ns.TooHard, ns.NodeSkill

---------------------------------------------------------------------------
-- Node kinds
---------------------------------------------------------------------------
-- What a minimap dot's name stands for, and the picture its symbol gets.

-- The racial that finds `kind` known and ready, with the setting on. Its global
-- cooldown counts as ready. isActive and isOnGCD are never secret; the times are in a fight.
local function RacialReady(kind)
    local spell = RACIALS[kind].spell
    if not db.leylines or not (C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spell)) then return false end
    local info = C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(spell)
    if issecretvalue(info) or type(info) ~= "table" or issecretvalue(info.isActive) or not info.isActive then return true end
    return not issecretvalue(info.isOnGCD) and info.isOnGCD == true
end

-- Is a finder on? true if the game won't say. A ready racial needs none.
local function FinderOn()
    if not (C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo) then return true end
    for index = 1, C_Minimap.GetNumTrackingTypes() do
        local info = C_Minimap.GetTrackingInfo(index)
        if issecretvalue(info) then return true end
        if info then
            if issecretvalue(info.active) or issecretvalue(info.spellID) then return true end
            local shows = info.spellID and FINDERS[info.spellID]
            if shows == "rares" and not db.rares then shows = nil end
            if shows and info.active then return true end
        end
    end
    return RacialReady("leyline") or RacialReady("convergence")
end

-- "herbs", "ore", "treasure", "rares" (with that setting), "leyline" or "convergence"
-- (while its racial is ready) or nil.
local function KindOf(name)
    if db.rares then
        local id = ns.RareID(Plain(name)) -- by NPC ID, the names come from the client (RareNames.lua)
        local home = id and RARES[id]
        if id and FRIENDLY[id] == UnitFactionGroup("player") then home = nil end
        -- Only in its home zone.
        if home == true or (home and ns.InZone(home)) then
            -- Not your own pet (a tamed rare keeps its name).
            local pet = UnitName("pet")
            if not issecretvalue(pet) and (not pet or ns.RareID(Plain(pet)) ~= id) then return "rares" end
        end
    end
    -- Learned herbs and ore. Chests go by their names, so a learned "treasure" is passed over.
    local known = db.learned and db.learned[Plain(name)]
    local kind = known and known.kind ~= "treasure" and known.kind or NodeKind(name)
    if RACIALS[kind] and not RacialReady(kind) then return nil end
    return kind
end

local function IconOf(name, kind)
    if kind == "treasure" then return TREASURE.icon end
    if kind == "rares" then return nil end -- the rare symbol, though a name can hold an ore's ("Dark Iron ...")
    local racial = RACIALS[kind]
    if racial then
        local file = C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(racial.spell)
        if issecretvalue(file) or type(file) ~= "number" or file <= 0 then file = racial.icon end
        return file
    end
    local known = db.learned and db.learned[Plain(name)]
    return NodeIcon(name) or (known and known.icon)
end

---------------------------------------------------------------------------
-- Learning nodes
---------------------------------------------------------------------------
-- Nodes missing from the English lists are learned when gathered, from the loot.

local TRADE_GOODS, HERB, METAL_AND_STONE, GEM = 7, 9, 7, 3 -- item class/subclasses
local castTarget -- target of your last cast
local lastSource -- GUID of the last looted object

local function NoteCast(target)
    castTarget = nil
    if issecretvalue(target) or type(target) ~= "string" or target == "" then return end
    castTarget = target
end

-- "herbs" or "ore" if a node gave this loot, and its items as { item, icon }.
local function LootKind()
    local kind, gave = nil, {}
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        if not link or issecretvalue(link) then return nil end
        local item, _, _, _, icon, class, subclass = C_Item.GetItemInfoInstant(link)
        local this = class == TRADE_GOODS and (subclass == HERB and "herbs" or subclass == METAL_AND_STONE and "ore") or nil
        if this then
            if kind and kind ~= this then return nil end
            kind = this
            gave[#gave + 1] = { item, icon }
        elseif class ~= GEM then
            return nil
        end
    end
    return kind, gave
end

local function SourceName(guid)
    local name = UnitNameFromGUID and UnitNameFromGUID(guid)
    if issecretvalue(name) or type(name) ~= "string" or name == "" or name == UNKNOWNOBJECT then name = castTarget end
    return name
end

-- LOOT_READY: learn the node the loot came from.
local function Learn()
    local guid = GetLootSourceInfo(1)
    if issecretvalue(guid) or type(guid) ~= "string" or guid == lastSource then return end
    lastSource = guid
    if guid:sub(1, 11) ~= "GameObject-" then return end
    local name = SourceName(guid)
    castTarget = nil
    local kind, gave = LootKind()
    turns.picked = kind -- (see Picked)
    if not (name and kind) then return end -- no name, or not a herb or ore
    local key = Plain(name)
    local known = db.learned[key] or { seen = {}, most = 0 }
    known.kind = kind
    for _, pair in ipairs(gave) do
        local count = (known.seen[pair[1]] or 0) + 1
        known.seen[pair[1]] = count
        if count > known.most then known.most, known.icon = count, pair[2] end
    end
    db.learned[key] = known
end

---------------------------------------------------------------------------
-- Switching finders
---------------------------------------------------------------------------
-- The minimap shows one finder's dots at a time. The Switch setting toggles
-- Find Herbs and Find Minerals as you move, keeping the other kind's symbols
-- meanwhile (marker.held).
local SWITCH_WAIT = 1 -- seconds from a switch to the next scan
local PICK_REACH = 10 -- yards: looting removes a held symbol this close

-- Active finder kind and the other's tracking index; nil unless exactly one is on.
local function Finders()
    if not (C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo) then return nil end
    local on, off, active = nil, nil, 0
    for index = 1, C_Minimap.GetNumTrackingTypes() do
        local info = C_Minimap.GetTrackingInfo(index)
        if issecretvalue(info) then return nil end
        local shows = info and not issecretvalue(info.spellID) and FINDERS[info.spellID]
        if shows == "herbs" or shows == "ore" then -- (not Find Treasure or creature tracking)
            if issecretvalue(info.active) then return nil end
            if info.active then
                on, active = shows, active + 1
            else
                off = index
            end
        end
    end
    if active ~= 1 then return nil end
    return on, off
end

-- A switch plays the game's UI click. That file is shared by most UI buttons,
-- so it's muted only from just before the switch until the cast is through
-- (or MUTE_MAX at most).
local SWITCH_SOUND = 567407 -- sound/interface/uchatscrollbutton.ogg
local MUTE_MAX, MUTE_TAIL = 0.6, 0.1 -- seconds (switches are over a second apart)
local muted = false

local function Unmute()
    if not muted then return end
    UnmuteSoundFile(SWITCH_SOUND)
    muted = false
end

local function Mute()
    muted = true
    MuteSoundFile(SWITCH_SOUND)
    C_Timer.After(MUTE_MAX, Unmute)
end

-- Your cast went through: if it was the switch, its sound has played.
local function CastDone(spellID)
    if not muted or issecretvalue(spellID) then return end
    local kind = FINDERS[spellID]
    if kind == "herbs" or kind == "ore" then C_Timer.After(MUTE_TAIL, Unmute) end
end

-- Switches finder after switchYards; true if it did.
local function Switch()
    local kind, other = Finders()
    turns.kind = kind
    if InCombatLockdown() then return false end -- costs a global cooldown
    if not (kind and other and C_Minimap.SetTracking) then return false end
    local map, x, y, width, height = MapPosition()
    if not map then return false end
    if map ~= turns.map then -- new map: start counting here
        turns.map, turns.x, turns.y = map, x, y
        return false
    end
    local dx, dy = (x - turns.x) * width, (y - turns.y) * height
    if not turns.scanned or dx * dx + dy * dy < db.switchYards ^ 2 then return false end
    turns.x, turns.y, turns.scanned = x, y, false
    Mute()
    C_Minimap.SetTracking(other, true)
    return true
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------

-- Strips color codes and inline textures from a tooltip line.
local function Clean(text)
    text = text:gsub("|A.-|a", ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return text:match("^%s*(.-)%s*$")
end

-- Gray text means the node is in a cave.
local function Gray(r, g, b)
    if issecretvalue(r) or issecretvalue(g) or issecretvalue(b) or not (r and g and b) then return false end
    return math.abs(r - g) < 0.1 and math.abs(g - b) < 0.1 and r < 0.9
end

-- Names in a tooltip line (one per row), cached by text; list.gray marks gray ones.
local lineNames, lineCount = {}, 0
local function NamesIn(text)
    local list = lineNames[text]
    if not list then
        list = {}
        for name in text:gmatch("[^\n]+") do
            local r, g, b = name:match("|c%x%x(%x%x)(%x%x)(%x%x)") -- before Clean strips it
            name = Clean(name)
            if name ~= "" then list[#list + 1] = name end
            if r and name ~= "" then
                list.gray = list.gray or {}
                list.gray[#list] = Gray(tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255)
            end
        end
        if lineCount >= 300 then lineNames, lineCount = {}, 0 end
        lineNames[text] = list
        lineCount = lineCount + 1
    end
    return list
end

-- Records the names hit at a point (true, or "gray" in a cave).
local function Record(hits, text, point, gray)
    local list = NamesIn(text)
    for i, name in ipairs(list) do
        local set = hits[name]
        if not set then
            set = {}
            hits[name] = set
        end
        local own = list.gray and list.gray[i]
        if own == nil then own = gray end
        set[point] = own and "gray" or true
    end
end

-- Adds a "Requires Herbalism (15)" line to the minimap tooltip, red if your skill
-- is too low, else in the profession window's colors for the chance of a skill-up.
-- It's rebuilt every frame, so skills are reread at most once a second.
local SKILL_WAIT = 1
local skillsRead = 0 -- last skill refresh
local said = {} -- lines added this frame

-- The line and its color. A skill-up always, likely, unlikely, never: 25, 50 and
-- 100 points above what the node needs.
local function Requirement(name)
    local kind = KindOf(name)
    local need, skill = NodeSkill(name, kind) -- nothing for chests, rares and the like
    if not skill or not professions[kind] then return nil end
    local over = skill - need
    local color = over < 0 and RED_FONT_COLOR or over < 25 and DIFFICULT_DIFFICULTY_COLOR
        or over < 50 and FAIR_DIFFICULTY_COLOR or over < 100 and EASY_DIFFICULTY_COLOR or TRIVIAL_DIFFICULTY_COLOR
    return ITEM_MIN_SKILL:format(professions[kind], need), color
end

local function FreshSkills()
    local now = GetTime()
    if now - skillsRead >= SKILL_WAIT then skills.herbs, skills.ore, skillsRead = nil, nil, now end
end

local function OnMinimapTooltip(tooltip, data)
    local lines = not issecretvalue(data) and data.lines
    if not lines or issecretvalue(lines) then return end
    FreshSkills()
    if next(said) then wipe(said) end
    for _, line in ipairs(lines) do
        local text = line.leftText
        if text and not issecretvalue(text) then
            for _, name in ipairs(NamesIn(text)) do
                local requires, color = Requirement(name)
                if requires and not said[requires] then
                    said[requires] = true
                    tooltip:AddLine(requires, color:GetRGB())
                end
            end
        end
    end
end

-- The same line on a herb's or ore's own tooltip, when the mouse is over it.
local function OnObjectTooltip(tooltip, data)
    local lines = not issecretvalue(data) and data.lines
    if not lines or issecretvalue(lines) or issecretvalue(lines[1]) then return end
    local name = lines[1] and lines[1].leftText
    if not name or issecretvalue(name) then return end
    FreshSkills()
    local requires, color = Requirement(Clean(name))
    if not requires then return end
    for i = 2, #lines do
        local line = lines[i]
        if issecretvalue(line) then return end
        local text = line.leftText
        if issecretvalue(text) or text == requires then return end -- the game has it already
    end
    tooltip:AddLine(requires, color:GetRGB())
end

---------------------------------------------------------------------------
-- Symbols and arrow
---------------------------------------------------------------------------

-- New symbol texture (sized later by ApplySize).
local function NewIcon()
    local texture = mapFrame:CreateTexture(nil, "OVERLAY")
    return { texture = texture, hard = false, dim = false }
end

-- Circle mask for a symbol or its ring.
local function NewMask(region)
    local mask = mapFrame:CreateMaskTexture()
    mask:SetAtlas(CIRCLE)
    mask:SetAllPoints(region)
    region:AddMaskTexture(mask)
    return mask
end

-- How much of the ring's width a shape shows (%): the slim gold ring is cut.
local function RingCut(shape) return shape == 4 and SLIM or 100 end

-- The slim gold ring is the gold ring cut thin: it goes under the symbol, which
-- hides its dark inner edge, and a circle on the symbol's middle cuts it from the
-- outside, so what shows is an even band between two circles around the same point.
local function CutRing(icon)
    icon.cut = RingCut(icon.shape)
    local cut = icon.cut < 100
    if cut then
        if not icon.cutMask then
            icon.cutMask = mapFrame:CreateMaskTexture()
            -- Clear outside its square, or the game stretches the circle's edge outward.
            icon.cutMask:SetAtlas(CIRCLE, false, nil, nil, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            icon.cutMask:SetPoint("CENTER", icon.texture, "CENTER")
        end
        local outer = icon.tint and oreRing.width or GOLD_OUTER
        local across = icon.size * (1 + (outer - 1) * icon.cut / 100)
        icon.cutMask:SetSize(across, across)
    end
    if cut ~= (icon.ringCut or false) then
        icon.ringCut = cut
        if cut then
            icon.border:AddMaskTexture(icon.cutMask)
            icon.border:SetDrawLayer("OVERLAY", -1)
        else
            icon.border:RemoveMaskTexture(icon.cutMask)
            icon.border:SetDrawLayer("OVERLAY", 1)
        end
    end
end

-- The gold ring scales with the symbol; the ore rings are centered on it.
local function SizeRing(icon)
    CutRing(icon)
    local scale = icon.size / ICON_SIZE
    icon.border:ClearAllPoints() -- the rings use different anchors
    if icon.tint then
        icon.border:SetSize(icon.size * oreRing.width, icon.size * oreRing.height)
        icon.border:SetPoint("CENTER", icon.texture, "CENTER")
        return
    end
    icon.border:SetSize(GOLD_SIZE * scale, GOLD_SIZE * scale)
    icon.border:SetPoint("TOPLEFT", icon.texture, "CENTER", GOLD_X * scale, GOLD_Y * scale)
end

local function ApplySize(icon)
    icon.size = db.iconSize
    icon.texture:SetSize(icon.size, icon.size)
    if icon.border then SizeRing(icon) end
end

-- Applies a shape; the mask and ring are created on first use.
local function ApplyShape(icon, shape)
    icon.shape = shape
    local ringed = shape == 3 or shape == 4
    local round = shape == 2 or ringed
    if round ~= (icon.round or false) then
        icon.round = round
        if not round then
            icon.texture:RemoveMaskTexture(icon.mask)
        elseif icon.mask then
            icon.texture:AddMaskTexture(icon.mask)
        else
            icon.mask = NewMask(icon.texture)
        end
    end
    if ringed then
        if not icon.border then
            -- Drawn over the symbol, anchored to it.
            icon.border = mapFrame:CreateTexture(nil, "OVERLAY", nil, 1)
            icon.border:SetTexture(GOLD_BORDER)
            SizeRing(icon)
        end
        icon.ring = icon.border
        icon.ring:Show() -- the symbol itself is shown by ShowMarkers
    elseif icon.ring then
        icon.ring:Hide()
        icon.ring = nil
    end
end

-- The arrow's node: the nearest you can gather (not too hard, not in a cave) of the
-- kinds it points to; with those settings past the one you're at, herbs and ore first.
local function Target()
    local other
    for _, marker in ipairs(markers) do
        if not marker.hard and not marker.dim and db[ARROW_TO[marker.kind]]
            and not (db.arrowSkip and marker.yards and marker.yards < SKIP_YARDS) then
            if not db.arrowFirst or marker.kind == "herbs" or marker.kind == "ore" then return marker end
            other = other or marker
        end
    end
    return other
end

-- A symbol's picture: the item icon, or the plain herb, ore or rare symbol.
local function ShowPicture(icon, marker)
    local picture = marker.file or ICONS[marker.kind]
    if marker.kind == "rares" then picture = picture[db.rareIcon] end
    if icon.picture ~= picture then
        icon.picture = picture
        if marker.file then
            icon.texture:SetTexture(picture)
            icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- without the icon's border
        else
            icon.texture:SetAtlas(picture)
        end
    end
end

-- A symbol's size, shape and ring.
local function ShowShape(icon, marker)
    if icon.size ~= db.iconSize then ApplySize(icon) end -- before ApplyShape, so a new ring gets this size
    -- Rare symbols keep Blizzard's own look: square, no ring.
    local shape = marker.kind == "rares" and 1 or db.shape
    if icon.shape ~= shape then ApplyShape(icon, shape) end
    -- High visibility tin and iron: swap the gold ring for the tinted one.
    local tint = icon.ring and db.oreRings and oreRing.ok and oreRing.tints[marker.file] or false
    local swap = not icon.tint ~= not tint -- tin to iron is just a new tint
    icon.tint = tint
    if swap then
        if tint then
            icon.border:SetAtlas(oreRing.atlas)
        else
            icon.border:SetTexture(GOLD_BORDER)
        end
        SizeRing(icon)
    end
    if icon.ring and icon.cut ~= RingCut(shape) then CutRing(icon) end
end

-- A symbol's look: red, gray in a cave, see-through over your arrow. After a color
-- change the alpha is set again, not left to what the color did to it.
local function ShowLook(icon, marker)
    -- Red if too hard; dimmed and desaturated in a cave (ore icons are already gray).
    local hard = (db.hard and marker.hard) or false
    if icon.hard ~= hard or icon.dim ~= marker.dim then
        icon.hard, icon.dim = hard, marker.dim
        local shade = icon.dim and 0.5 or 1
        if hard then
            icon.texture:SetVertexColor(TOO_HARD[1] * shade, TOO_HARD[2] * shade, TOO_HARD[3] * shade)
        else
            icon.texture:SetVertexColor(shade, shade, shade)
        end
        icon.texture:SetDesaturated(icon.dim)
        icon.alpha = nil -- set again below
    end
    -- The ring gets the cave look or the ore tint. Done here because ApplyShape may
    -- have just created or re-shown it.
    local look = icon.dim or icon.tint or false
    if icon.ring and (icon.ringLook or false) ~= look then
        icon.ringLook = look
        if icon.tint and not icon.dim then
            icon.ring:SetVertexColor(icon.tint[1], icon.tint[2], icon.tint[3])
            icon.ring:SetDesaturation(oreRing.gray)
        else
            local shade = icon.dim and 0.5 or 1
            icon.ring:SetVertexColor(shade, shade, shade)
            icon.ring:SetDesaturated(icon.dim)
        end
        icon.ringAlpha = nil
    end
    -- See-through near you: while over your own arrow.
    local alpha = db.clearNear and marker.distance < icon.size / 2 + PLAYER_ARROW and CLEAR or 1
    if icon.alpha ~= alpha then
        icon.alpha = alpha
        icon.texture:SetAlpha(alpha)
    end
    if icon.ring and icon.ringAlpha ~= alpha then
        icon.ringAlpha = alpha
        icon.ring:SetAlpha(alpha)
    end
end

-- Updates the symbols and the arrow's text.
local function ShowMarkers()
    local target = db.arrow and Target()
    if target then -- arrow text
        local text = target.yards and ("%s  %.0f yd"):format(target.name, target.yards) or target.name
        if text ~= shownText then
            shownText = text
            arrowText:SetText(text)
        end
    end
    for i = 1, MAX_ICONS do
        local marker = db.mapIcons and markers[i]
        local icon = mapIcons[i]
        if marker and not marker.far then
            icon = icon or NewIcon()
            mapIcons[i] = icon
            ShowPicture(icon, marker)
            ShowShape(icon, marker)
            ShowLook(icon, marker)
            -- Setting the same point again moves it; no ClearAllPoints needed.
            icon.texture:SetPoint("CENTER", mapFrame, "BOTTOMLEFT", marker.x, marker.y)
            if not icon.shown then
                icon.shown = true
                icon.texture:Show()
                if icon.ring then icon.ring:Show() end
            end
        elseif icon and icon.shown then
            icon.shown = false
            icon.texture:Hide()
            if icon.ring then icon.ring:Hide() end
        end
    end
end

local function UpdateArrow()
    local target = db.arrow and Target()
    local facing = target and PlayerFacing()
    if not facing then
        if arrowOn then
            arrowOn = false
            arrow:Hide()
        end
        return
    end
    -- Bearings are clockwise from north; facing and texture rotation counterclockwise.
    arrowTexture:SetRotation(-(target.world + facing))
    if not arrowOn then
        arrowOn = true
        arrow:Show()
    end
end

-- A locked arrow takes no mouse: it can't be dragged, and clicks go through it.
local function ApplyArrowLock()
    arrow:EnableMouse(not db.arrowLocked)
end

local function ApplyArrowSize()
    arrow:SetSize(db.arrowSize, db.arrowSize)
end

---------------------------------------------------------------------------
-- Splitting groups
---------------------------------------------------------------------------

-- Connected groups of points.
local function Blobs(set)
    local blobs, seen = {}, {}
    for first in pairs(set) do
        if not seen[first] then
            seen[first] = true
            local stack, keys = { first }, {}
            while #stack > 0 do
                local point = table.remove(stack)
                keys[#keys + 1] = point
                for _, step in ipairs(AROUND) do
                    local other = point + step
                    if set[other] and not seen[other] then
                        seen[other] = true
                        stack[#stack + 1] = other
                    end
                end
            end
            blobs[#blobs + 1] = keys
        end
    end
    return blobs
end

-- Center of some points, in minimap units.
local function Middle(keys, step)
    local sx, sy = 0, 0
    for _, point in ipairs(keys) do sx, sy = sx + math.floor(point / 1000), sy + point % 1000 end
    return sx / #keys * step, sy / #keys * step
end

-- Fits circles of radius R to a group's outline: repeatedly picks the center
-- that explains the most outline points (at least MIN_VOTES).
local function FitRadius(boundary, candidates, R, most)
    local low, high = (R - TOL) ^ 2, (R + TOL) ^ 2
    -- Only centers with no miss inside the circle.
    local clear = (R - TOL - 1) ^ 2
    local valid = {}
    for _, c in ipairs(candidates) do
        if c[3] >= clear then valid[#valid + 1] = c end
    end
    candidates = valid
    local left, discs, total = boundary, {}, 0
    local function Count(cx, cy)
        local n = 0
        for _, b in ipairs(left) do
            local d = (cx - b[1]) ^ 2 + (cy - b[2]) ^ 2
            if d >= low and d <= high then n = n + 1 end
        end
        return n
    end
    for _ = 1, most do
        local bestN, bx, by = 0, 0, 0
        for _, c in ipairs(candidates) do
            local n = Count(c[1], c[2])
            if n > bestN then bestN, bx, by = n, c[1], c[2] end
        end
        if bestN < MIN_VOTES then break end
        local cx, cy = bx, by -- try the neighbouring centers too
        for dx = -1, 1 do
            for dy = -1, 1 do
                local n = Count(bx + dx, by + dy)
                if n > bestN then bestN, cx, cy = n, bx + dx, by + dy end
            end
        end
        discs[#discs + 1] = { cx, cy }
        total = total + bestN
        local rest = {}
        for _, b in ipairs(left) do
            local d = (cx - b[1]) ^ 2 + (cy - b[2]) ^ 2
            if d < low or d > high then rest[#rest + 1] = b end
        end
        left = rest
    end
    return discs, total
end

-- Splitting runs one radius per frame: StartFit, FitStep, FinishFit.
local function StartFit(job)
    local hit = job.hits[job.name]
    if not hit then return nil end
    local boundary, outside, seenOutside = {}, {}, {}
    for point in pairs(hit) do
        local px, py = math.floor(point / 1000), point % 1000
        local edge, ox, oy = false, 0, 0
        for _, step in ipairs(AROUND4) do
            local other = point + step
            if job.probed[other] and not hit[other] then
                edge = true
                ox = ox + (step == -1000 and -1 or step == 1000 and 1 or 0)
                oy = oy + (step == -1 and -1 or step == 1 and 1 or 0)
                if not seenOutside[other] then
                    seenOutside[other] = true
                    outside[#outside + 1] = { math.floor(other / 1000) * FINE, other % 1000 * FINE }
                end
            end
        end
        -- Outline: half a step out from points that border a miss.
        if edge then boundary[#boundary + 1] = { (px + ox / 2) * FINE, (py + oy / 2) * FINE } end
    end
    -- Every point is a candidate center (with squared distance to the nearest miss).
    local candidates = {}
    for point in pairs(hit) do
        local cx, cy = math.floor(point / 1000) * FINE, point % 1000 * FINE
        local nearest = 1e9
        for _, o in ipairs(outside) do
            local d = (cx - o[1]) ^ 2 + (cy - o[2]) ^ 2
            if d < nearest then nearest = d end
        end
        candidates[#candidates + 1] = { cx, cy, nearest }
    end
    return { boundary = boundary, candidates = candidates, next = 1, n = #job.keys, results = {},
        radii = { hitRadius, hitRadius - 1.5, hitRadius + 1.5, hitRadius - 3, hitRadius + 3, hitRadius - 4.5, hitRadius + 4.5,
            hitRadius + 6, hitRadius + 7.5 } }
end

-- Tries the next radius; true when all have been tried.
local function FitStep(fit)
    local R = fit.radii[fit.next]
    -- Cap the dot count by the group's area.
    local most = math.min(MAX_DISCS, math.max(1, math.floor(1.25 * fit.n / (math.pi * R ^ 2 / STEP ^ 2) + 0.5)))
    local discs, total = FitRadius(fit.boundary, fit.candidates, R, most)
    fit.results[#fit.results + 1] = { discs = discs, total = total, radius = R }
    fit.next = fit.next + 1
    return fit.next > #fit.radii
end

-- Picks the radius with the fewest dots among those within FEWER of the best
-- fit. Returns the dots as { x, y }, or nil.
local FEWER = 0.85

local function FinishFit(fit)
    local top = 0
    for _, result in ipairs(fit.results) do
        if result.total > top then top = result.total end
    end
    if top == 0 then return nil end
    local best
    for _, result in ipairs(fit.results) do
        if result.total >= FEWER * top and (not best or #result.discs < #best.discs
            or (#result.discs == #best.discs and result.total > best.total)) then
            best = result
        end
    end
    hitRadius = math.max(11, math.min(24, hitRadius + (best.radius - hitRadius) / 4))
    return best.discs
end

-- A finer grid over a big group's area.
local function NewJob(name, keys)
    local x0, y0, x1, y1 = 1e9, 1e9, -1e9, -1e9
    for _, point in ipairs(keys) do
        local x, y = math.floor(point / 1000) * STEP, point % 1000 * STEP
        x0, y0, x1, y1 = math.min(x0, x), math.min(y0, y), math.max(x1, x), math.max(y1, y)
    end
    local half = gridWidth / 2
    local list, probed = {}, {}
    for fx = math.ceil((x0 - STEP) / FINE), math.floor((x1 + STEP) / FINE) do
        for fy = math.ceil((y0 - STEP) / FINE), math.floor((y1 + STEP) / FINE) do
            local dx, dy = fx * FINE - half, fy * FINE - half
            if fx >= 0 and fy >= 0 and dx * dx + dy * dy <= half * half then
                list[#list + 1] = fx * 1000 + fy
                probed[fx * 1000 + fy] = true
            end
        end
    end
    return { name = name, keys = keys, list = list, probed = probed, hits = {}, next = 1 }
end

---------------------------------------------------------------------------
-- Following
---------------------------------------------------------------------------
-- Between scans, places stay fixed on the zone map and their minimap position
-- is recomputed every frame as you move.
local function ByDistance(a, b) return a.distance < b.distance end

local lastMap, lastX, lastY, lastFacing, lastRadius -- inputs of the last Follow
local still = false -- nothing moved since the last Follow

local function Follow()
    still = false
    if not markers[1] or not markers[1].map then return end
    local map, x, y, width, height = MapPosition()
    local radius = C_Minimap.GetViewRadius()
    local facing = turning and PlayerFacing() -- only needed when rotating
    if not map or not radius or issecretvalue(radius) or (turning and not facing) then return end
    -- Nothing moved.
    if map == lastMap and x == lastX and y == lastY and radius == lastRadius and (not turning or facing == lastFacing) then
        still = true
        return
    end
    lastMap, lastX, lastY, lastFacing, lastRadius = map, x, y, facing, radius
    local half = Minimap:GetWidth() / 2
    local sorted, last = true, 0
    for _, marker in ipairs(markers) do
        if marker.map == map then
            local east, north = (marker.mx - x) * width, (y - marker.my) * height
            marker.yards = math.sqrt(east * east + north * north)
            marker.world = math.atan2(east, north)
            marker.distance = marker.yards / radius * half
            local way = turning and marker.world + facing or marker.world -- clockwise from the minimap's top
            marker.x, marker.y = half + marker.distance * math.sin(way), half + marker.distance * math.cos(way)
            marker.far = marker.distance > half
        end
        if marker.distance < last then sorted = false end
        last = marker.distance
    end
    -- Keep nearest first.
    if not sorted then table.sort(markers, ByDistance) end
    ShowMarkers()
end

-- A herb seen again (same name, within MERGE yards) is averaged with its old
-- place over up to AVERAGE scans, so symbols don't jump.
local MERGE = 15 -- yards
local AVERAGE = 8

local function Smooth(found, before, width, height, used)
    for _, marker in ipairs(found) do
        local best, bestGap
        for _, old in ipairs(before) do
            if marker.map and old.map == marker.map and old.name == marker.name and not used[old] then
                local gap = ((old.mx - marker.mx) * width) ^ 2 + ((old.my - marker.my) * height) ^ 2
                if gap < MERGE * MERGE and (not bestGap or gap < bestGap) then best, bestGap = old, gap end
            end
        end
        -- Rares move: no averaging.
        if marker.kind == "rares" then best = nil end
        if marker.pinned then
            marker.count = marker.count or 1
        elseif best then
            used[best] = true
            local n = math.min(best.count, AVERAGE)
            marker.mx = (best.mx * n + marker.mx) / (n + 1)
            marker.my = (best.my * n + marker.my) / (n + 1)
            marker.count = n + 1
        else
            marker.count = 1
        end
    end
end

---------------------------------------------------------------------------
-- Scanning
---------------------------------------------------------------------------

-- A scan finished: its places become the markers. Also sets the next scan's
-- pace, keeps held symbols and plays the Sound setting's sound.
local function FinishScan()
    local places = scan.places
    local hits = scan.hits -- for the cave check below
    scan = nil
    local width = Minimap:GetWidth()
    local radius = C_Minimap.GetViewRadius()
    if issecretvalue(radius) then radius = nil end
    local rotating = C_CVar.GetCVar("rotateMinimap") == "1"
    local facing = PlayerFacing()
    local found, pinOf, kept = {}, {}, {}
    skills.herbs, skills.ore = nil, nil -- reread when needed
    racialShown = false
    -- A rotating minimap has your facing at the top; otherwise north.
    if not (rotating and not facing) then
        for _, place in ipairs(places) do
            local name, x, y = place.name, place.x, place.y
            -- Skip names that stopped being nodes mid-scan (zone change, pet called).
            local kind = KindOf(name)
            if kind then
                if RACIALS[kind] then racialShown = true end
                local dx, dy = x - width / 2, y - width / 2
                local bearing = math.atan2(dx, dy) -- clockwise from the top of the minimap
                local distance = math.sqrt(dx * dx + dy * dy)
                local said = hits[name] -- (see Record)
                local marker = {
                    name = name, kind = kind, file = IconOf(name, kind), hard = (db.hard or db.arrow or db.sound or db.worldMark) and TooHard(name, kind),
                    x = x, y = y, distance = distance, age = place.age, exact = place.exact,
                    yards = radius and distance / (width / 2) * radius,
                    world = rotating and bearing - facing or bearing,
                    -- In a cave: its name was gray at the nearest grid point.
                    dim = said and said[math.floor(x / STEP + 0.5) * 1000 + math.floor(y / STEP + 0.5)] == "gray" or false,
                }
                found[#found + 1] = marker
                pinOf[marker] = place.pin
            end
        end
    end
    table.sort(found, ByDistance)
    -- Zone map positions, for Follow.
    local map, x, y, mapWidth, mapHeight = MapPosition()
    if map then
        for _, marker in ipairs(found) do
            if marker.yards then
                marker.map = map
                local pin = pinOf[marker]
                if pin and pin.map == map then
                    -- Pinned earlier: keep that spot.
                    marker.mx, marker.my, marker.count, marker.pinned = pin.mx, pin.my, pin.count + 1, true
                    kept[pin] = true
                else
                    marker.mx = x + marker.yards * math.sin(marker.world) / mapWidth
                    marker.my = y - marker.yards * math.cos(marker.world) / mapHeight
                    marker.pinned = marker.exact -- exact spot found this scan
                end
            end
        end
    end
    if map then Smooth(found, markers, mapWidth, mapHeight, kept) end
    -- Nothing new for a few scans: ease the detail down.
    local was, new = eased, false
    for _, marker in ipairs(found) do
        if not (marker.count and marker.count > 1) then new = true end
    end
    if new then
        eased, quiet = 0, 0
    else
        quiet = quiet + 1
        if quiet >= SETTLE and SettingLevel() - eased > 1 then eased, quiet = eased + 1, 0 end
    end
    if eased ~= was then ApplyDetail() end
    -- Back off while nothing is found, until you move.
    if found[1] then
        empties = 0
        if wait > WAIT then wait = WAIT end -- end the backoff
    else
        empties = empties + 1
        emptyMap, emptyX, emptyY = map, x, y -- current position
    end
    -- A rare in sight keeps the scan at full pace.
    for _, marker in ipairs(found) do
        if marker.kind == "rares" and hurry == 0 then hurry = 1 end
    end
    -- Switch setting: keep the other kind's symbols until its turn (held).
    local shown = db.switchFinders and turns.kind
    if shown and map then
        local other = shown == "herbs" and "ore" or "herbs" -- kind whose finder is off
        local seen = false
        for _, marker in ipairs(found) do
            if marker.kind == other then seen = true end
        end
        for _, old in ipairs(markers) do
            if not seen and old.kind == other and old.map == map then
                old.held = true
                found[#found + 1] = old
            end
        end
    end
    -- Sound setting: one ping per scan for anything not seen in the last minute
    -- (same name within 25 minimap units; rares by name only). Not for nodes too hard.
    if db.sound then
        local now, new = GetTime(), false
        local reach = radius and (25 * radius * 2 / width) ^ 2 -- yards, squared
        for i = #heard, 1, -1 do
            if now - heard[i].at > 60 then table.remove(heard, i) end
        end
        for _, marker in ipairs(found) do
            if not marker.hard then
                local known
                for _, old in ipairs(heard) do
                    if old.name == marker.name and old.map == marker.map and (marker.kind == "rares" or not marker.map
                        or ((old.mx - marker.mx) * mapWidth) ^ 2 + ((old.my - marker.my) * mapHeight) ^ 2 < reach) then
                        known = old
                        break
                    end
                end
                if known then
                    known.at = now
                else
                    heard[#heard + 1] = { name = marker.name, map = marker.map, mx = marker.mx, my = marker.my, at = now }
                    new = true
                end
            end
        end
        if new then PlaySound(SOUNDKIT.MAP_PING) end
    end
    turns.scanned = true
    turning = rotating
    markers = found
    lastMap = nil -- make Follow recompute
    ShowMarkers()
end

-- Starts a scan unless there's nothing to scan, and sets the wait for the next.
local function StartScan()
    wait = WAIT
    if hurry > 0 then hurry = hurry - 1 end
    if not Minimap:IsVisible() or not Minimap:GetLeft() then
        if markers[1] then
            markers = {}
            ShowMarkers()
        end
        return
    end
    -- No scan in combat unless Scan in combat is on.
    if InCombatLockdown() and not db.combatScan then return end
    if empties > 0 and Moved(MapPosition()) then empties = 0 end
    if db.switchFinders and Switch() then -- wait for the other finder's dots
        wait = SWITCH_WAIT
        if hurry == 0 then hurry = 1 end
        return
    end
    if not FinderOn() then -- nothing to find: check again later
        wait = NO_FINDER
        if markers[1] then
            markers = {}
            ShowMarkers()
        end
        return
    end
    -- Back off after empty scans, up to SLEEP times the wait.
    wait = WAIT * math.min(SLEEP, empties <= 6 and 1 + empties or 7 * 2 ^ (empties - 6))
    rested = still and hurry == 0 and math.min(rested + 1, #REST) or 0
    local width = Minimap:GetWidth()
    if gridWidth ~= width then
        gridWidth, grid = width, {}
        for x = 0, math.floor(width / STEP) do
            for y = 0, math.floor(width / STEP) do
                local dx, dy = x * STEP - width / 2, y * STEP - width / 2
                if dx * dx + dy * dy <= width * width / 4 then grid[#grid + 1] = x * 1000 + y end
            end
        end
    end
    scan = { points = grid, next = 1, hits = {} }
end

-- Moves the fake mouse to x, y and records the names the tooltip shows.
local function Probe(left, bottom, scale, x, y, hits, point)
    Minimap:UpdateMouseoverAtPoint((left + x) * scale, (bottom + y) * scale)
    local data = C_TooltipInfo.GetMinimapMouseover()
    local lines = data and not issecretvalue(data) and data.lines
    if lines and not issecretvalue(lines) then
        for _, line in ipairs(lines) do
            local text = line.leftText
            local color = line.leftColor
            local gray = color and not issecretvalue(color) and Gray(color.r, color.g, color.b)
            if text and not issecretvalue(text) then Record(hits, text, point, gray) end
        end
    end
end

-- Reuse the last split of a group for up to REFIT scans.
local REFIT = 10

local function Known(name, keys, set)
    -- Only places inside this group.
    local inGroup = {}
    for _, point in ipairs(keys) do inGroup[point] = true end
    local mine = {}
    for _, marker in ipairs(markers) do
        if marker.name == name and not marker.far
            and inGroup[math.floor(marker.x / STEP + 0.5) * 1000 + math.floor(marker.y / STEP + 0.5)] then
            mine[#mine + 1] = marker
        end
    end
    if #mine < 2 then return nil end
    local reach = (hitRadius + STEP / 2 + 1) ^ 2
    for _, marker in ipairs(mine) do
        if (marker.age or 0) >= REFIT then return nil end
        -- Its center and 4 points around it must still hit (one miss allowed).
        local missing = 0
        for _, offset in ipairs({ { 0, 0 }, { 6, 0 }, { -6, 0 }, { 0, 6 }, { 0, -6 } }) do
            local gx = math.floor((marker.x + offset[1]) / STEP + 0.5)
            local gy = math.floor((marker.y + offset[2]) / STEP + 0.5)
            if not set[gx * 1000 + gy] then missing = missing + 1 end
        end
        if missing > 1 then return nil end
    end
    for _, point in ipairs(keys) do
        local x, y = math.floor(point / 1000) * STEP, point % 1000 * STEP
        local covered = false
        for _, marker in ipairs(mine) do
            if (x - marker.x) ^ 2 + (y - marker.y) ^ 2 <= reach then
                covered = true
                break
            end
        end
        if not covered then return nil end
    end
    return mine
end

-- Pinning: a new dot's four edges are found by bisection from the grid, and its
-- center is kept while later scans still find the dot there. Edges at the rim
-- or next to another dot of the same kind are retried next scan.
local HALVINGS = 5 -- bisection steps (about 1 unit)
local PAST = 1.2 -- search distance past the last hit (steps)
local PIN_REACH = 0.6 -- steps: closer than this is the pinned dot
local scratch = {}

-- Is this dot hit at x, y?
local function Under(left, bottom, scale, x, y, name)
    wipe(scratch)
    Probe(left, bottom, scale, x, y, scratch, 1)
    return scratch[name] ~= nil
end

-- Distance from x, y to the dot's edge in direction dx, dy (up to reach), or nil.
local function Edge(left, bottom, scale, name, x, y, dx, dy, reach)
    local px, py, rim = x - gridWidth / 2, y - gridWidth / 2, gridWidth / 2 - 1
    local out = px * px + py * py - rim * rim
    if out >= 0 then return nil end
    local along = px * dx + py * dy
    local inside, outside = 0, math.min(reach, math.sqrt(along * along - out) - along) -- stop at the rim
    if Under(left, bottom, scale, x + dx * outside, y + dy * outside, name) then return nil end
    for _ = 1, HALVINGS do
        local far = (inside + outside) / 2
        if Under(left, bottom, scale, x + dx * far, y + dy * far, name) then inside = far else outside = far end
    end
    return inside
end

-- Centers a new place on its dot; exact if all four edges were found.
local function Refine(left, bottom, scale, place)
    local name, x, y, box, past = place.name, place.x, place.y, place.box, PAST * STEP
    local west = Edge(left, bottom, scale, name, x, y, -1, 0, x - box[1] + past)
    local east = Edge(left, bottom, scale, name, x, y, 1, 0, box[3] - x + past)
    if west and east then x = x + (east - west) / 2 end
    local south = Edge(left, bottom, scale, name, x, y, 0, -1, y - box[2] + past)
    local north = Edge(left, bottom, scale, name, x, y, 0, 1, box[4] - y + past)
    if south and north then y = y + (north - south) / 2 end
    place.x, place.y, place.box = x, y, nil
    place.exact = (west and east and south and north) ~= nil
end

-- Bounding box of grid points: { left, bottom, right, top } in minimap units.
local function Box(keys)
    local x0, y0, x1, y1 = 1e9, 1e9, -1e9, -1e9
    for _, point in ipairs(keys) do
        local x, y = math.floor(point / 1000) * STEP, point % 1000 * STEP
        x0, y0, x1, y1 = math.min(x0, x), math.min(y0, y), math.max(x1, x), math.max(y1, y)
    end
    return { x0, y0, x1, y1 }
end

-- The pinned marker this place matches, if any.
local function PinAt(name, x, y)
    local reach = (PIN_REACH * STEP) ^ 2
    for _, marker in ipairs(markers) do
        if marker.pinned and marker.name == name and (marker.x - x) ^ 2 + (marker.y - y) ^ 2 <= reach then return marker end
    end
end

-- Grid done: small groups become places (pinned or refined), big ones get the fine grid.
local function EndCoarse()
    scan.places, scan.jobs, scan.job, scan.fresh = {}, {}, 1, {}
    local fine = 0
    local mapped = MapPosition() ~= nil -- (pins need the zone map)
    for name, set in pairs(scan.hits) do
        if KindOf(name) then
            for _, keys in ipairs(Blobs(set)) do
                local known = #keys > Single() and Known(name, keys, set)
                local job = #keys > Single() and not known and NewJob(name, keys)
                if known then
                    for _, marker in ipairs(known) do
                        scan.places[#scan.places + 1] = { name = name, x = marker.x, y = marker.y, age = (marker.age or 0) + 1 }
                    end
                elseif job and fine + #job.list <= MAX_FINE then
                    fine = fine + #job.list
                    scan.jobs[#scan.jobs + 1] = job
                else
                    local x, y = Middle(keys, STEP)
                    local place = { name = name, x = x, y = y }
                    if mapped and #keys <= Single() then -- one dot
                        place.pin = PinAt(name, x, y) -- FinishScan keeps its map spot
                        -- Rares move: never pinned.
                        if place.pin and place.pin.kind == "rares" then place.pin = nil end
                        if not place.pin then
                            place.box = Box(keys)
                            scan.fresh[#scan.fresh + 1] = place
                        end
                    end
                    scan.places[#scan.places + 1] = place
                end
            end
        end
    end
    if #scan.jobs == 0 and not scan.fresh[1] then FinishScan() end
end

-- A big group is done: its dots become places (its middle if none fit).
local function EndJob(job, discs)
    if discs and #discs > 0 then
        for _, disc in ipairs(discs) do scan.places[#scan.places + 1] = { name = job.name, x = disc[1], y = disc[2] } end
    else
        local x, y = Middle(job.keys, STEP)
        scan.places[#scan.places + 1] = { name = job.name, x = x, y = y }
    end
    scan.job = scan.job + 1
    if scan.job > #scan.jobs then FinishScan() end
end

-- Probes the next points. The minimap's soft cursor is on only while probing.
local function ScanSome()
    local left, bottom = Minimap:GetLeft(), Minimap:GetBottom()
    if not (left and bottom and Minimap:IsVisible()) or (InCombatLockdown() and not db.combatScan) then
        scan = nil
        return
    end
    local scale = Minimap:GetEffectiveScale()
    Minimap:SetUsingSoftCursor(true)
    if not scan.jobs then
        local points = scan.points
        for i = scan.next, math.min(scan.next + PER_FRAME - 1, #points) do
            local point = points[i]
            Probe(left, bottom, scale, math.floor(point / 1000) * STEP, point % 1000 * STEP, scan.hits, point)
        end
        Minimap:SetUsingSoftCursor(false)
        scan.next = scan.next + PER_FRAME
        if scan.next > #points then EndCoarse() end
    elseif scan.fresh[1] then
        -- Pin new dots, three per frame.
        for _ = 1, math.min(3, #scan.fresh) do
            Refine(left, bottom, scale, table.remove(scan.fresh))
        end
        Minimap:SetUsingSoftCursor(false)
        if not scan.fresh[1] and scan.job > #scan.jobs then FinishScan() end
    else
        local job = scan.jobs[scan.job]
        local list = job.list
        if job.fit then -- probed: fit one radius per frame
            Minimap:SetUsingSoftCursor(false)
            if FitStep(job.fit) then EndJob(job, FinishFit(job.fit)) end
            return
        end
        for i = job.next, math.min(job.next + PER_FRAME - 1, #list) do
            local point = list[i]
            Probe(left, bottom, scale, math.floor(point / 1000) * FINE, point % 1000 * FINE, job.hits, point)
        end
        Minimap:SetUsingSoftCursor(false)
        job.next = job.next + PER_FRAME
        if job.next > #list then
            job.fit = StartFit(job)
            if not job.fit then EndJob(job) end
        end
    end
end

---------------------------------------------------------------------------
-- Running the scan
---------------------------------------------------------------------------

-- The far sparkles (Beta): FarSparkles.lua fills this table.
local world = { others = {} }

-- Every frame: the scan or its wait, then the places, arrow and far sparkles.
local function OnUpdate(_, elapsed)
    if scan then
        ScanSome()
    else
        -- Slower while standing still, except right after loot.
        wait = wait - (still and hurry == 0 and elapsed / REST[rested] or elapsed)
        if wait <= 0 then StartScan() end
    end
    Follow()
    UpdateArrow()
    world.Update()
end

-- After a loading screen, old places are stale.
local function NewPlace()
    scan, wait, empties, rested, markers = nil, 0, 0, 0, {}
    ShowMarkers()
    UpdateArrow()
end

-- Loot closed: remove a held symbol of that kind near you (you just took it).
local function Picked()
    local kind, gone = turns.picked, false
    turns.picked = nil
    if not kind then return end
    for i = #markers, 1, -1 do
        local marker = markers[i]
        if marker.held and marker.kind == kind and marker.yards and marker.yards <= PICK_REACH then
            table.remove(markers, i)
            gone = true
        end
    end
    if gone then ShowMarkers() end
end

-- A cooldown changed: a Skyborne racial just used takes its symbols away at once,
-- and one ready again starts a scan now.
local function RacialsChanged()
    local ready, gone = false, false
    for kind in pairs(RACIALS) do
        if RacialReady(kind) then
            ready = true
        elseif racialShown then
            for i = #markers, 1, -1 do
                if markers[i].kind == kind then
                    table.remove(markers, i)
                    gone = true
                end
            end
        end
    end
    if gone then ShowMarkers() end
    if ready and not racialWasReady then wait, empties = 0, 0 end
    racialWasReady = ready
end

-- After a settings change: start or stop the scan and rescan now.
local function UpdateScanner()
    eased, quiet = 0, 0
    ApplyDetail()
    local on = Enabled()
    tracker:SetScript("OnUpdate", on and OnUpdate or nil)
    scan, wait, empties, rested = nil, 0, 0, 0
    if not on then markers = {} end
    ShowMarkers()
    UpdateArrow()
    world.Update() -- clears the far marker when off
end

-- Key binding (Bindings.xml): toggles the minimap symbols.
BINDING_HEADER_NODESIGHT = "NodeSight"
BINDING_NAME_NODESIGHT_SYMBOLS = "Toggle Herb and Ore Symbols"
function NodeSight_ToggleSymbols()
    if not tracker then return end -- (not loaded yet)
    db.mapIcons = not db.mapIcons
    UpdateScanner()
end

-- Scales the game's own minimap dots; left alone at 100 unless the slider moved.
local function ApplyDotScale()
    if Minimap.SetIconScale then Minimap:SetIconScale(db.dotScale / 100) end
end

-- Scan frame, draggable arrow (position saved in NodeSightDB.arrowPlace) and
-- the symbols' frame, all created without a parent (see NewSparkles).
local function NewScanner()
    tracker = CreateFrame("Frame")
    arrow = CreateFrame("Frame")
    arrow:SetParent(UIParent)
    ApplyArrowSize()
    local place = db.arrowPlace
    if place then
        arrow:SetPoint(place[1], UIParent, place[2], place[3], place[4])
    else
        arrow:SetPoint("TOP", UIParent, "TOP", 0, -170)
    end
    arrow:Hide()
    arrow:SetMovable(true)
    arrow:SetClampedToScreen(true)
    ApplyArrowLock()
    arrow:RegisterForDrag("LeftButton")
    local dragging = false
    -- Save the position on drop (or if hidden mid-drag).
    local function Drop()
        if not dragging then return end
        dragging = false
        arrow:StopMovingOrSizing()
        local point, _, relativePoint, x, y = arrow:GetPoint()
        db.arrowPlace = { point, relativePoint, x, y }
    end
    arrow:SetScript("OnDragStart", function()
        dragging = true
        arrow:StartMoving()
    end)
    arrow:SetScript("OnDragStop", Drop)
    arrow:SetScript("OnHide", Drop)
    arrowTexture = arrow:CreateTexture(nil, "OVERLAY")
    arrowTexture:SetAllPoints(arrow)
    arrowTexture:SetAtlas(ARROW)
    arrowText = arrow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arrowText:SetPoint("TOP", arrow, "BOTTOM", 0, -2)
    mapFrame = CreateFrame("Frame")
    mapFrame:SetParent(Minimap)
    mapFrame:SetAllPoints(Minimap)
end

---------------------------------------------------------------------------
-- Loading
---------------------------------------------------------------------------

-- What the other files use of this one.
ns.defaults, ns.SHAPES, ns.world = defaults, SHAPES, world
ns.Clean, ns.MapPosition, ns.PlayerFacing = Clean, MapPosition, PlayerFacing
ns.UpdateScanner, ns.ApplyDotScale, ns.ApplyArrowLock = UpdateScanner, ApplyDotScale, ApplyArrowLock
ns.ApplyArrowSize = ApplyArrowSize
-- A getter, since each scan replaces the list.
function ns.Markers() return markers end

local MINIMAP_TOOLTIP = Enum.TooltipDataType.MinimapMouseover -- the minimap dots' tooltip type
local OBJECT_TOOLTIP = Enum.TooltipDataType.Object -- a herb's or ore's own tooltip

local function OnAddonLoaded()
    NodeSightDB = NodeSightDB or {}
    for key, value in pairs(defaults) do
        if NodeSightDB[key] == nil then NodeSightDB[key] = value end
    end
    -- Fix saved values the settings can't produce.
    NodeSightDB.sparkleColor = tostring(NodeSightDB.sparkleColor):match("^%x%x%x%x%x%x%x%x$") or defaults.sparkleColor
    if not SHAPES[NodeSightDB.shape] then NodeSightDB.shape = defaults.shape end
    if not ICONS.rares[NodeSightDB.rareIcon] then NodeSightDB.rareIcon = defaults.rareIcon end
    if NodeSightDB.switchYards < 10 then NodeSightDB.switchYards = 10 end
    db = NodeSightDB
    ns.db = db
    NewScanner()
    UpdateScanner()
    -- CVars changed by the addon: original (saved) and set (applied) values.
    NodeSightDB.saved = NodeSightDB.saved or {}
    NodeSightDB.applied = NodeSightDB.applied or {}
    -- Nodes learned by gathering (see Learn).
    NodeSightDB.learned = NodeSightDB.learned or {}
    -- Registered with the gamepad UI on too; it works there.
    ns.RegisterSettings()
    -- The "Requires ..." line in the minimap's tooltip and a node's own.
    if MINIMAP_TOOLTIP then TooltipDataProcessor.AddTooltipPostCall(MINIMAP_TOOLTIP, OnMinimapTooltip) end
    if OBJECT_TOOLTIP then TooltipDataProcessor.AddTooltipPostCall(OBJECT_TOOLTIP, OnObjectTooltip) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
events:RegisterEvent("LOOT_READY")
events:RegisterEvent("LOOT_CLOSED")
events:RegisterEvent("PLAYER_STARTED_MOVING")
events:RegisterEvent("MINIMAP_UPDATE_ZOOM")
events:RegisterEvent("MINIMAP_UPDATE_TRACKING")
events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
events:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            events:UnregisterEvent("ADDON_LOADED")
            -- After an update, a /reload only loads the files the old .toc listed:
            -- stay off until the game is restarted.
            if not (ns.Plain and ns.RareID and ns.Setup and world.Update and ns.ShowWhatsNew and ns.RegisterSettings) then
                events:UnregisterAllEvents()
                return
            end
            OnAddonLoaded()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        NewPlace()
        if db.dotScale ~= NORMAL_DOTS then ApplyDotScale() end
        -- Restores CVars left changed (e.g. a restore delayed by combat).
        ns.Setup() -- after every loading screen
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        -- Free the plate's sparkle frame.
        if next(ns.sparkles) then ns.HideSparkles(C_NamePlate.GetNamePlateForUnit(arg1)) end
    elseif event == "UNIT_SPELLCAST_SENT" then
        NoteCast(arg2)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        CastDone(arg3)
    elseif event == "PLAYER_LOGOUT" then
        Unmute() -- also on a /reload: the timers end with the UI
    elseif event == "LOOT_READY" then
        Learn()
    elseif event == "LOOT_CLOSED" then
        -- You may have just picked a herb: rescan now, twice more at full pace.
        wait, hurry = 0, 3
        Picked()
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        RacialsChanged()
    elseif event == "PLAYER_STARTED_MOVING" or event == "MINIMAP_UPDATE_ZOOM" or event == "MINIMAP_UPDATE_TRACKING" then
        -- Moving, zooming or a tracking change ends the slowdown.
        local soon = event == "MINIMAP_UPDATE_TRACKING" and SWITCH_WAIT or WAIT
        empties, rested = 0, 0
        if wait > soon then wait = soon end
    elseif event == "PLAYER_REGEN_DISABLED" then
        world.Fight()
    else -- PLAYER_REGEN_ENABLED
        wait = 0 -- rescan now
        world.fight = nil
        if ns.SetupPending() then ns.Setup() end
    end
end)
