-- Collecting: remembers where you gathered each herb and ore and marks the places on
-- the world map and the minimap, with every known spawn (Spawns.lua) and GatherMate2's
-- places too if those are on.
-- Nothing is sent to or read from other players.
--
-- Saved account-wide in NodeSightDB.nodes[mapID][node] (the node's English name in
-- lower case): a list of places, each x * 10000 + y in thousandths of the map. A
-- place close to a known one adds nothing, so a zone's list stops growing.
--
-- Sections: Places, Known spawns and GatherMate2, Filters, Rare ones only, Areas, Where to farm,
-- Gathering, World map, Minimap, Forget all.

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

local EMPTY = {}
local UNITS = 1000 -- a map's width and height in saved units
local PACK = 10000 -- x * PACK + y
local SAME = 4 -- places of one node this close (in units, each way) are one spawn point
local version = 0 -- goes up when the places or the symbols' look change

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
-- Known spawns and GatherMate2
---------------------------------------------------------------------------
-- The places that aren't your own: every known spawn (Spawns.lua, one string of places per
-- node and map) and GatherMate2's herbs and ore (what it recorded, and Wowhead's from
-- GatherMate2_Data, read without an import), read through its own functions: its saved
-- tables can be split over storage addons. Kept per map in Collecting's units until
-- something changes; read again then.

local GM_TYPES = { "Herb Gathering", "Mining" }
local gmPlaces = {} -- [map] = { [key] = places } or false (none): the known spawns' and GatherMate2's
local gmKeys = {} -- [type][node ID] = key, or false for anything not a herb or ore
local listening = false
local DATA = "GatherMate2_Data"
local DATA_TABLES = { ["Herb Gathering"] = "GatherMateData2HerbDB", ["Mining"] = "GatherMateData2MineDB" }
local data, dataTried -- GatherMate2_Data's tables by node type, once loaded

local function GatherMate()
    local gm = _G.GatherMate2
    if type(gm) == "table" and type(gm.GetNodesForZone) == "function" and type(gm.DecodeLoc) == "function"
        and type(gm.GetNameForNode) == "function" then return gm end
end

-- GatherMate2 says it added a place for every gather; during one of ours, or just after it was
-- read in, that place is already marked, so the map isn't read again for it.
local OWN_WAIT = 2
local ownAt, ownGathering = -OWN_WAIT, nil
local function GatherMateChanged()
    if ownGathering and ownGathering() or GetTime() - ownAt < OWN_WAIT then return end
    ns.RereadNodePins()
end

-- Its messages for a place added or deleted; an import sends none (the map's OnShow reads again).
local function Listen()
    listening = true
    local events = LibStub and LibStub("AceEvent-3.0", true)
    if not events then return end
    local target = {}
    events:Embed(target)
    for _, message in ipairs({ "GatherMate2NodeAdded", "GatherMate2NodeDeleted", "GatherMate2Cleanup", "GatherMateData2Import" }) do
        target:RegisterMessage(message, GatherMateChanged)
    end
end

-- An addon's state: "on" (there to load), "off" (turned off for this character), "missing",
-- or the game's reason it can't load.
local function AddOnState(name)
    if not (C_AddOns and C_AddOns.GetAddOnInfo) then return "missing" end
    local ok, found, _, _, loadable, reason = pcall(C_AddOns.GetAddOnInfo, name)
    if not ok or not found or reason == "MISSING" then return "missing" end
    if loadable or reason == "DEMAND_LOADED" then return "on" end
    return reason == "DISABLED" and "off" or reason or "off"
end

-- Loads GatherMate2_Data (it loads on demand) and keeps its tables; not in combat.
local dataWait -- (a frame that waits out a fight to load it)
local function Data()
    if data or dataTried then return data end
    local loaded = false
    for _, name in pairs(DATA_TABLES) do loaded = loaded or type(_G[name]) == "table" end
    if not loaded then
        if AddOnState(DATA) ~= "on" then
            dataTried = true
            return nil
        end
        if InCombatLockdown() then -- (loaded after the fight, and the maps read again)
            if not dataWait then
                dataWait = CreateFrame("Frame")
                dataWait:SetScript("OnEvent", function(self)
                    self:UnregisterAllEvents()
                    if not data and not dataTried then ns.RereadNodePins() end
                end)
            end
            dataWait:RegisterEvent("PLAYER_REGEN_ENABLED")
            return nil
        end
        pcall(C_AddOns.LoadAddOn, DATA)
    end
    dataTried = true
    for nodeType, name in pairs(DATA_TABLES) do
        if type(_G[name]) == "table" then
            data = data or {}
            data[nodeType] = _G[name]
        end
    end
    return data
end

-- GatherMate2's own herb and ore icons off while its places are marked here (its Show
-- settings set to never), and put back as they were once they aren't.
local function GatherMateIcons()
    local gm = _G.GatherMate2
    local profile = type(gm) == "table" and type(gm.db) == "table" and gm.db.profile
    local show = type(profile) == "table" and profile.show
    if type(show) ~= "table" then return end
    local db, changed = ns.db, false
    local was = db.gatherMateShow
    if db.collectGatherMate and db.collectHideGatherMate then
        if type(was) ~= "table" then
            was = {}
            for _, nodeType in ipairs(GM_TYPES) do was[nodeType] = show[nodeType] end
            db.gatherMateShow = was
        end
        for _, nodeType in ipairs(GM_TYPES) do
            if show[nodeType] ~= "never" then show[nodeType], changed = "never", true end
        end
    elseif type(was) == "table" then
        for _, nodeType in ipairs(GM_TYPES) do
            if type(was[nodeType]) == "string" then show[nodeType] = was[nodeType] end
        end
        db.gatherMateShow, changed = nil, true
    end
    if changed and type(gm.SendMessage) == "function" then pcall(gm.SendMessage, gm, "GatherMate2ConfigChanged") end
end

local function KeyOf(gm, nodeType, id)
    local keys = gmKeys[nodeType]
    if not keys then
        keys = {}
        gmKeys[nodeType] = keys
    end
    local key = keys[id]
    if key == nil then
        local replaced = type(gm.nodeIDReplacementMap) == "table" and gm.nodeIDReplacementMap[id] or id
        local name = gm:GetNameForNode(nodeType, replaced)
        key = false
        if type(name) == "string" and not issecretvalue(name) then
            local kind = ns.NodeKind(name)
            if kind == "herbs" or kind == "ore" then key = ns.NodeKey(name) end
        end
        keys[id] = key
    end
    return key
end

local CELL = 2 * SAME
-- Places by cell, so the ones near a place are found without reading every place of its node
-- (GatherMate2_Data has thousands a zone): [key] = { [cell] = { place, ... } }.
local function Index(index, key, place)
    local x, y = Unpack(place)
    local cells = index[key]
    if not cells then
        cells = {}
        index[key] = cells
    end
    local cell = floor(x / CELL) * PACK + floor(y / CELL)
    local list = cells[cell]
    if not list then
        list = {}
        cells[cell] = list
    end
    list[#list + 1] = place
end
local function IndexOf(nodes)
    local index = {}
    for key, places in pairs(nodes or EMPTY) do
        if type(places) == "table" then
            for _, place in ipairs(places) do Index(index, key, place) end
        end
    end
    return index
end
-- The nearest place in an index (Collecting's own, or those read so far) for the same node
-- this close: the same spawn point. False for none.
local function Known(index, key, x, y)
    local cells = index[key]
    if not cells then return false end
    local cx, cy = floor(x / CELL), floor(y / CELL)
    local best, near = false, math.huge
    for dx = -1, 1 do
        for dy = -1, 1 do
            for _, place in ipairs(cells[(cx + dx) * PACK + cy + dy] or EMPTY) do
                local px, py = Unpack(place)
                local ex, ey = abs(px - x), abs(py - y)
                if ex <= SAME and ey <= SAME and ex * ex + ey * ey < near then best, near = place, ex * ex + ey * ey end
            end
        end
    end
    return best
end

-- Your own places drawn on the known spawn each is, where there is one: yours are where you
-- stood to gather, a few yards off the node, the known ones the node's own. Kept per map
-- while its lists are the same: [map] = { fixed, [key] = list, [list] = its length }.
local Spots = { ownMaps = {} } -- (shared spots' functions too: Shared spots below)
function Spots.Same(kept, own)
    local n = 0
    for key, places in pairs(own) do
        n = n + 1
        if kept[key] ~= places or type(places) == "table" and kept[places] ~= #places then return false end
    end
    return n == kept.n
end
function Spots.Own(map, own)
    if not own then return nil end
    local kept = Spots.ownMaps[map]
    if kept and Spots.Same(kept, own) then return kept.fixed end
    local list = ns.SPAWNS and ns.SPAWNS[map]
    local known = {}
    for key, text in pairs(type(list) == "table" and list or EMPTY) do
        if type(text) == "string" and type(own[key]) == "table" then
            for number in text:gmatch("%d+") do Index(known, key, tonumber(number)) end
        end
    end
    local fixed = {}
    kept = { fixed = fixed, n = 0 }
    for key, places in pairs(own) do
        kept[key], kept.n = places, kept.n + 1
        if type(places) == "table" then
            kept[places] = #places
            local out, used = {}, {}
            for _, place in ipairs(places) do
                local x, y = Unpack(place)
                local spot = Known(known, key, x, y) or place
                if not used[spot] then -- (two of yours on one known spawn: one symbol)
                    used[spot] = true
                    out[#out + 1] = spot
                end
            end
            fixed[key] = out
        else
            fixed[key] = places
        end
    end
    Spots.Replaced(map, fixed)
    Spots.ownMaps[map] = kept
    return fixed
end

-- Silver, gold and truesilver grow in place of tin, iron or mithril, so a spot of one is the
-- other's too, though Wowhead lists only the node seen there: a rare spot with none of the three
-- (in `nodes` or `other`, as near as one spot's nodes) gets the one it takes the place of (gold's
-- iron or mithril, whichever the map has more of). Into `nodes`' lists (copies, never the saved ones).
Spots.REPLACES = { { "truesilver deposit", "mithril deposit" }, { "gold vein", "iron deposit", "mithril deposit" },
    { "silver vein", "tin vein" } }
Spots.COMMON_ORE = { "tin vein", "iron deposit", "mithril deposit" }
Spots.NEAR = 8 -- (yards apart: one spot)
-- Whether an index (as Index makes) has an ore within rx, ry units of x, y (at most a cell).
function Spots.Has(index, x, y, rx, ry)
    local cells = index.ore
    if not cells then return false end
    local cx, cy = floor(x / CELL), floor(y / CELL)
    for dx = -1, 1 do
        for dy = -1, 1 do
            for _, place in ipairs(cells[(cx + dx) * PACK + cy + dy] or EMPTY) do
                local px, py = Unpack(place)
                if abs(px - x) <= rx and abs(py - y) <= ry then return true end
            end
        end
    end
    return false
end
function Spots.Replaced(map, nodes, other)
    local mine, theirs, reachX, reachY
    local counts = {} -- (the map's own counts, before any are added)
    for _, key in ipairs(Spots.COMMON_ORE) do
        counts[key] = (type(nodes[key]) == "table" and #nodes[key] or 0) + (other and type(other[key]) == "table" and #other[key] or 0)
    end
    for _, row in ipairs(Spots.REPLACES) do
        local places = nodes[row[1]]
        if type(places) == "table" and #places > 0 then
            if not mine then
                local width, height = C_Map.GetMapWorldSize(map)
                if issecretvalue(width) or issecretvalue(height) or type(width) ~= "number" or type(height) ~= "number"
                    or width <= 0 or height <= 0 then return end
                reachX = math.min(CELL, math.max(SAME, Spots.NEAR / width * UNITS))
                reachY = math.min(CELL, math.max(SAME, Spots.NEAR / height * UNITS))
                mine, theirs = {}, {}
                for _, key in ipairs(Spots.COMMON_ORE) do
                    for _, place in ipairs(type(nodes[key]) == "table" and nodes[key] or EMPTY) do Index(mine, "ore", place) end
                    for _, place in ipairs(other and type(other[key]) == "table" and other[key] or EMPTY) do Index(theirs, "ore", place) end
                end
            end
            local common, most = row[2], -1
            for i = 2, #row do
                if counts[row[i]] > most then common, most = row[i], counts[row[i]] end
            end
            for _, place in ipairs(places) do
                local x, y = Unpack(place)
                if not Spots.Has(mine, x, y, reachX, reachY) and not Spots.Has(theirs, x, y, reachX, reachY) then
                    if type(nodes[common]) ~= "table" then nodes[common] = {} end
                    local list = nodes[common]
                    list[#list + 1] = place
                    Index(mine, "ore", place)
                end
            end
        end
    end
end

-- GatherMate2's places, then GatherMate2_Data's it doesn't have (an import put them in both),
-- added to nodes; true if any were.
local function ReadGatherMate(gm, map, mine, nodes, read)
    local any = false
    local extra = Data()
    for _, nodeType in ipairs(GM_TYPES) do
        local seen = {}
        local function Add(coord, id)
            local key = type(coord) == "number" and not seen[coord] and KeyOf(gm, nodeType, id)
            seen[coord] = true
            if key then
                local x, y = gm:DecodeLoc(coord)
                x, y = floor(x * UNITS + 0.5), floor(y * UNITS + 0.5)
                if not Known(mine, key, x, y) and not Known(read, key, x, y) then
                    local places = nodes[key]
                    if not places then
                        places = {}
                        nodes[key] = places
                    end
                    places[#places + 1] = x * PACK + y
                    Index(read, key, x * PACK + y)
                    any = true
                end
            end
        end
        for coord, id in gm:GetNodesForZone(map, nodeType, true) do Add(coord, id) end
        local theirs = extra and extra[nodeType] and extra[nodeType][map]
        if type(theirs) == "table" then
            for coord, id in pairs(theirs) do Add(coord, id) end
        end
    end
    return any
end

-- A map's known spawns (Spawns.lua) not near one of your own, added to nodes; true if any were.
local function ReadSpawns(map, mine, nodes, read)
    local list = ns.SPAWNS and ns.SPAWNS[map]
    if type(list) ~= "table" then return false end
    local any = false
    for key, text in pairs(list) do
        if type(text) == "string" then
            local places
            for number in text:gmatch("%d+") do
                local place = tonumber(number)
                local x, y = Unpack(place)
                if not Known(mine, key, x, y) then
                    places = places or {}
                    places[#places + 1] = place
                    Index(read, key, place)
                end
            end
            if places then
                nodes[key], any = places, true
            end
        end
    end
    return any
end

-- The places on a map that aren't your own: the known spawns (while that setting is on),
-- then GatherMate2's not near one of them (while its setting is on); false for none.
local function ReadTheirs(map, own)
    local db, nodes, any = ns.db, {}, false
    local mine, read = IndexOf(own), {} -- (your own places, and theirs as they're read)
    if db.collectSpawns then any = ReadSpawns(map, mine, nodes, read) end
    local addon = db.collectGatherMate and GatherMate()
    if addon then
        if not listening then pcall(Listen) end
        -- GatherMate2's own error is not ours to repeat: that map has none of its places then.
        local ok, added = pcall(ReadGatherMate, addon, map, mine, nodes, read)
        any = any or ok and added
    end
    if any then Spots.Replaced(map, nodes, own) end
    return any and nodes or false
end

-- The places to mark on a map: Collecting's own (while it is on), and the known spawns and
-- GatherMate2's, each a table of node key to places, or nil.
local function Sources(map)
    local db = ns.db
    local own = db.collect and Nodes()[map]
    own = Spots.Own(map, type(own) == "table" and own or nil)
    if not (db.collectSpawns or db.collectGatherMate) then return own, nil end
    local theirs = gmPlaces[map]
    if theirs == nil then
        theirs = ReadTheirs(map, own)
        gmPlaces[map] = theirs
    end
    return own, theirs or nil
end

local function GatherMateLoaded() return GatherMate() ~= nil end

---------------------------------------------------------------------------
-- Filters
---------------------------------------------------------------------------
-- Which herbs and ore are marked: the ones picked in setup, and only with the profession,
-- while its finder tracks, or while it still gives a skill-up, as set. Kept per version.

-- Every herb and ore, by the skill it needs (herbs not in Names.lua's list last, by name):
-- what setup picks from. A herb's entry is the end of its names, an ore's its name.
local LEVEL_ONE = { silverleaf = true, peacebloom = true, ["copper vein"] = true }
local NODE_LIST = { herbs = {}, ore = {} }
local NODE_NEEDS = { herbs = {}, ore = {} } -- [entry] = skill needed, where known
local function EndsWith(text, ending) return text:sub(-#ending) == ending end
for _, kind in ipairs(ns.NODE_NEEDED and { "herbs", "ore" } or EMPTY) do -- (none if Names.lua didn't load)
    local list, needs, known = NODE_LIST[kind], NODE_NEEDS[kind], ns.NODE_NEEDED[kind]
    if kind == "herbs" then
        for _, herb in ipairs(ns.HERB_ENDINGS) do list[#list + 1] = herb end
    else
        list[1] = "copper vein"
        for name in pairs(known) do list[#list + 1] = name end
    end
    for _, entry in ipairs(list) do
        local need = LEVEL_ONE[entry] and 1 or known[entry]
        if not need then
            for name, skill in pairs(known) do
                if EndsWith(name, " " .. entry) then need = skill end
            end
        end
        needs[entry] = need
    end
    table.sort(list, function(a, b)
        local x, y = needs[a] or 1000, needs[b] or 1000
        if x ~= y then return x < y end
        return a < b
    end)
end

-- A node's entry in NODE_LIST: a herb's by the end of its name, an ore's is its name.
local function NodeEntry(key, kind)
    if kind == "herbs" then
        for _, herb in ipairs(ns.HERB_ENDINGS) do
            if EndsWith(key, herb) then return herb end
        end
    end
    return key
end

local FINDS = { herbs = 2383, ore = 2580 } -- Find Herbs, Find Minerals
local tracked -- [kind] = its finder is on; read again when the tracking changes
local shown, shownVersion = {}, nil

local function Tracked(kind)
    if not tracked then
        tracked = {}
        if C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo then
            for index = 1, C_Minimap.GetNumTrackingTypes() do
                local info = C_Minimap.GetTrackingInfo(index)
                if not issecretvalue(info) and info and not issecretvalue(info.spellID) and not issecretvalue(info.active) then
                    for each, spell in pairs(FINDS) do
                        if info.spellID == spell and info.active then tracked[each] = true end
                    end
                end
            end
        end
    end
    return tracked[kind] == true
end

local function Shown(key, kind)
    if Spots.sample then return true end -- (a settings preview's made-up spawns)
    if shownVersion ~= version then
        wipe(shown)
        shownVersion = version
    end
    local yes = shown[key]
    if yes == nil then
        local db = ns.db
        yes = not db.collectHidden[NodeEntry(key, kind)]
        if yes and db.collectOnlyProfession then yes = ns.HasProfession(kind) end
        -- (the Herb/Ore Switch turns them on in turn: both count then)
        if yes and db.collectOnlyTracking and not db.switchFinders then yes = Tracked(kind) end
        if yes and db.collectHideGray then yes = ns.SkillLevel(key, kind) ~= 5 end
        shown[key] = yes
    end
    return yes
end

---------------------------------------------------------------------------
-- Rare ones only
---------------------------------------------------------------------------
-- While set, a map marks only its rare herbs and ore: the ones rare everywhere (RARE; Wowhead
-- lists a rare ore at the common ore's spots, so its share of a zone says little), and the
-- ones that make up less than the set share of that map's herbs or ore.

local RARE = { ["silver vein"] = true, ["ooze covered silver vein"] = true, ["gold vein"] = true, ["ooze covered gold vein"] = true,
    ["truesilver deposit"] = true, ["ooze covered truesilver deposit"] = true, ["rich thorium vein"] = true,
    ["ooze covered rich thorium vein"] = true, ["black lotus"] = true }
-- The nodes a map doesn't mark ([key] = true), or nil while the setting is off (`always`: the
-- world map's own rare ones, worked out anyway).
local function Common(map, own, gm, always)
    local db = ns.db
    if not (db.collectRareOnly or always) then return nil end
    local counts, totals = {}, { herbs = 0, ore = 0 }
    for source = 1, 2 do
        for key, places in pairs(source == 1 and own or source == 2 and gm or EMPTY) do
            local kind = ns.NodeKind(key)
            if type(places) == "table" and (kind == "herbs" or kind == "ore") then
                counts[key] = (counts[key] or 0) + #places
                totals[kind] = totals[kind] + #places
            end
        end
    end
    local keys = {}
    for key, count in pairs(counts) do
        if not RARE[key] and count * 100 >= db.collectRarePercent * totals[ns.NodeKind(key)] then keys[key] = true end
    end
    return keys
end

---------------------------------------------------------------------------
-- Shared spots
---------------------------------------------------------------------------
-- One spawn spot can hold different ores, or herbs, in turn (iron, gold or silver). It gets one symbol,
-- the common node's (not a rare one, then the one with more spawns on the map), and its tooltip
-- names them all.

-- [key][place] = { keys = { the spot's nodes, the common one first }, at = { [key] = place } }, or nil.
function Spots.Of(map, own, gm)
    local width, height = C_Map.GetMapWorldSize(map)
    if issecretvalue(width) or issecretvalue(height) or type(width) ~= "number" or type(height) ~= "number"
        or width <= 0 or height <= 0 then return nil end
    local near = Spots.NEAR
    -- Every place as a number in a few arrays, not a table each (less garbage on a map with thousands).
    local keyOf, kindOf, placeOf, xs, ys, spotOf, n = {}, {}, {}, {}, {}, {}, 0
    local cells, counts, spots = {}, {}, nil
    for source = 1, 2 do
        for key, places in pairs(source == 1 and own or source == 2 and gm or EMPTY) do
            local kind = ns.NodeKind(key)
            if type(places) == "table" and (kind == "herbs" or kind == "ore") then
                counts[key] = (counts[key] or 0) + #places
                for _, place in ipairs(places) do
                    local x, y = Unpack(place)
                    n = n + 1
                    keyOf[n], kindOf[n], placeOf[n], xs[n], ys[n] = key, kind, place, x / UNITS * width, y / UNITS * height
                    local cell = floor(xs[n] / near) * 65536 + floor(ys[n] / near)
                    local list = cells[cell]
                    if not list then
                        list = {}
                        cells[cell] = list
                    end
                    list[#list + 1] = n
                end
            end
        end
    end
    local function First(a, b)
        if (RARE[a] or false) ~= (RARE[b] or false) then return not RARE[a] end
        if counts[a] ~= counts[b] then return counts[a] > counts[b] end
        return a < b
    end
    for i = 1, n do
        if not spotOf[i] then
            local key, x, y = keyOf[i], xs[i], ys[i]
            local cx, cy, spot = floor(x / near), floor(y / near), nil
            for dx = -1, 1 do
                for dy = -1, 1 do
                    for _, j in ipairs(cells[(cx + dx) * 65536 + cy + dy] or EMPTY) do
                        local other = keyOf[j]
                        if other ~= key and kindOf[j] == kindOf[i] and not spotOf[j] and (xs[j] - x) ^ 2 + (ys[j] - y) ^ 2 <= near * near then
                            if not spot then
                                spot = { keys = { key }, at = { [key] = placeOf[i] } }
                                spotOf[i] = spot
                            end
                            if not spot.at[other] then
                                spot.keys[#spot.keys + 1] = other
                                spot.at[other] = placeOf[j]
                                spotOf[j] = spot
                            end
                        end
                    end
                end
            end
            if spot then
                table.sort(spot.keys, First)
                spots = spots or {}
                for key, place in pairs(spot.at) do
                    spots[key] = spots[key] or {}
                    spots[key][place] = spot
                end
            end
        end
    end
    return spots
end
-- The node a shared spot shows: its first one that is marked.
function Spots.Owner(spot, common)
    for _, key in ipairs(spot.keys) do
        if Shown(key, ns.NodeKind(key)) and not (common and common[key]) then return key end
    end
end
-- The node a shared spot shows after `owner` (its second), or nil.
function Spots.Second(spot, owner, common)
    local past = false
    for _, key in ipairs(spot.keys) do
        if past and Shown(key, ns.NodeKind(key)) and not (common and common[key]) then return key end
        if key == owner then past = true end
    end
end
-- Whether `key`'s place is drawn: alone, or the node its shared spot shows.
function Spots.Drawn(spots, key, place, common)
    local spot = spots and spots[key] and spots[key][place]
    return not spot or Spots.Owner(spot, common) == key, spot
end

---------------------------------------------------------------------------
-- Areas
---------------------------------------------------------------------------
-- Spawns of one herb or ore close together (a mine, a patch: they fill a circle) shown as one symbol with a count
-- in place of a symbol each, while a map is zoomed out (the world map's widest zoom, the
-- minimap's two widest). Other nodes' spawns there keep their symbols.

local AREA_LEAST, AREA_YARDS = 5, 35 -- spawns that make an area, and how close (yards, spawn to spawn)
local AREA_PAD = 12 -- yards an area reaches past its outer spawns
local HERB_AREA = { 0.45, 0.85, 0.35 }
-- Each ore's area in its metal's color, by part of the node name; first match wins, so
-- "dark iron" comes before "iron" and "truesilver" before "silver". Others are copper's.
local ORE_AREAS = {
    { "copper", 0.95, 0.55, 0.2 }, { "tin", 0.45, 0.9, 0.85 }, { "truesilver", 0.92, 0.96, 1 },
    { "dark iron", 0.6, 0.25, 0.4 }, { "iron", 0.55, 0.65, 0.8 }, { "gold", 1, 0.82, 0.2 },
    { "mithril", 0.35, 0.55, 1 }, { "thorium", 0.3, 0.85, 0.6 }, { "incendicite", 1, 0.35, 0.15 },
    { "bloodstone", 0.9, 0.15, 0.2 }, { "indurium", 0.6, 0.6, 0.62 }, { "amber", 1, 0.7, 0.15 },
    { "obsidian", 0.6, 0.35, 0.85 }, { "moonstone", 0.6, 0.78, 1 }, { "silver", 0.8, 0.85, 0.92 },
}
local oreColors = {} -- (one table a node, so a glow sees when its color changes)
local function AreaColor(key, kind)
    if kind ~= "ore" then return HERB_AREA end
    if not oreColors[key] then
        local found = ORE_AREAS[1]
        for _, color in ipairs(ORE_AREAS) do
            if key:find(color[1], 1, true) then found = color break end
        end
        oreColors[key] = { found[2], found[3], found[4] }
    end
    return oreColors[key]
end
local GLOW = "Interface\\AddOns\\NodeSight\\AreaGlow" -- white, fading out from the middle
local LINE = "Interface\\AddOns\\NodeSight\\AreaLine" -- white, fading out across its height (a region's bands)
local ROUND_SPACING = 60 -- yards a spawn or closer, on average over its circle: a round area

-- One node's places in groups: two share a group when a chain of places, each within
-- `yards` of the next, joins them. A grid of yards-wide cells keeps each search to its neighbors.
local function Groups(places, width, height, yards)
    local xs, ys, cells = {}, {}, {}
    for i, place in ipairs(places) do
        local x, y = Unpack(place)
        xs[i], ys[i] = x / UNITS * width, y / UNITS * height
        local cell = floor(xs[i] / yards) * PACK + floor(ys[i] / yards)
        cells[cell] = cells[cell] or {}
        table.insert(cells[cell], i)
    end
    local within, done, groups = yards * yards, {}, {}
    for i = 1, #places do
        if not done[i] then
            done[i] = true
            local group, k = { i }, 1
            while group[k] do
                local j = group[k]
                local cx, cy = floor(xs[j] / yards), floor(ys[j] / yards)
                for dx = -1, 1 do
                    for dy = -1, 1 do
                        for _, m in ipairs(cells[(cx + dx) * PACK + cy + dy] or EMPTY) do
                            local ex, ey = xs[m] - xs[j], ys[m] - ys[j]
                            if not done[m] and ex * ex + ey * ey <= within then
                                done[m] = true
                                group[#group + 1] = m
                            end
                        end
                    end
                end
                k = k + 1
            end
            groups[#groups + 1] = group
        end
    end
    return groups, xs, ys
end

-- A map's areas, each { key, kind, color, x, y (its symbol, in units), yards (its radius),
-- count }; and the places in them ([key][place] = true). nil while areas are off or the
-- map's size is unknown.
-- The links of a group's chain (Prim's tree: each spawn to its nearest already linked), as
-- pairs of indexes into the node's places.
local function Links(group, xs, ys)
    local linked, best, from, links = { true }, {}, {}, {}
    local function Apart(k, to)
        local dx, dy = xs[group[k]] - xs[group[to]], ys[group[k]] - ys[group[to]]
        return dx * dx + dy * dy
    end
    for k = 2, #group do best[k], from[k] = Apart(k, 1), 1 end
    for _ = 2, #group do
        local pick
        for k = 2, #group do
            if not linked[k] and (not pick or best[k] < best[pick]) then pick = k end
        end
        linked[pick] = true
        links[#links + 1], links[#links + 2] = group[from[pick]], group[pick]
        for k = 2, #group do
            if not linked[k] then
                local d = Apart(k, pick)
                if d < best[k] then best[k], from[k] = d, pick end
            end
        end
    end
    return links
end

-- The areas of a map width by height yards (the sparkle window's preview passes its own).
local function AreasIn(width, height, own, gm)
    local db = ns.db
    if not db.collectAreas then return nil end
    -- Each node's places from both sources together.
    local all = {}
    for source = 1, 2 do
        for key, places in pairs(source == 1 and own or source == 2 and gm or EMPTY) do
            local kind = ns.NodeKind(key)
            if type(places) == "table" and (kind == "herbs" or kind == "ore") then
                local into = all[key] or {}
                all[key] = into
                for _, place in ipairs(places) do into[#into + 1] = place end
            end
        end
    end
    local list, hidden = {}, {}
    for key, places in pairs(all) do
        local groups, xs, ys = Groups(places, width, height, AREA_YARDS)
        local mine = {}
        for _, group in ipairs(groups) do
            if #group >= AREA_LEAST then
                local sx, sy = 0, 0
                for _, i in ipairs(group) do sx, sy = sx + xs[i], sy + ys[i] end
                local cx, cy, far = sx / #group, sy / #group, 0
                for _, i in ipairs(group) do
                    local dx, dy = xs[i] - cx, ys[i] - cy
                    far = math.max(far, dx * dx + dy * dy)
                end
                if math.pi * far <= ROUND_SPACING * ROUND_SPACING * #group then -- (spread along a row: no area)
                    local yards = math.sqrt(far) + AREA_PAD
                    mine[#mine + 1] = { key = key, kind = ns.NodeKind(key), color = AreaColor(key, ns.NodeKind(key)), x = cx / width * UNITS, y = cy / height * UNITS,
                        cx = cx, cy = cy, yards = yards, count = 0 }
                end
            end
        end
        -- Every place of the node inside an area is in it, not only its group's.
        if mine[1] then
            local inside = {}
            hidden[key] = inside
            for i, place in ipairs(places) do
                for _, area in ipairs(mine) do
                    local dx, dy = xs[i] - area.cx, ys[i] - area.cy
                    if dx * dx + dy * dy <= area.yards * area.yards then
                        inside[place] = true
                        area.count = area.count + 1
                        break
                    end
                end
            end
            for _, area in ipairs(mine) do
                if area.count > 0 then list[#list + 1] = area end -- (none left when another area took them all)
            end
        end
    end
    return list, hidden
end

local function Areas(map, own, gm)
    local width, height = C_Map.GetMapWorldSize(map)
    if issecretvalue(width) or issecretvalue(height) or type(width) ~= "number" or type(height) ~= "number"
        or width <= 0 or height <= 0 then return nil end
    return AreasIn(width, height, own, gm)
end

-- A map's areas and the nodes Rare ones only leaves out, worked out once and kept until a
-- place or a setting changes (or its places are other tables).
local mapInfo = {} -- [map] = { own, gm, areas, inAreas, common }
local function MapInfo(map, own, gm)
    local kept = mapInfo[map]
    if kept and kept.own == own and kept.gm == gm then return kept end
    kept = { own = own, gm = gm }
    kept.areas, kept.inAreas = Areas(map, own, gm)
    kept.common = Common(map, own, gm)
    -- The world map: rare ones, and every spawn near you (nil when Rare ones only does it already).
    kept.mapCommon = ns.db.collectMapRare and not ns.db.collectRareOnly and Common(map, own, gm, true) or nil
    kept.spots = Spots.Of(map, own, gm)
    mapInfo[map] = kept
    return kept
end

---------------------------------------------------------------------------
-- Where to farm
---------------------------------------------------------------------------
-- Per zone, how many marked places still give you a skill-up (orange, yellow or green),
-- herbs and ore apart. Worked out when the page asks, kept until a place, a setting or
-- your skill changes (the version below).

local FARM_LEVELS = { 2, 3, 4 } -- SkillLevel's orange, yellow, green
local farm, farmVersion

-- Every map with known spawns, GatherMate2 may have places on (its HereBeDragons list), or
-- with Collecting's.
local function FarmMaps(gm)
    local maps, seen = {}, {}
    local function Add(map)
        if type(map) == "number" and not seen[map] then
            seen[map] = true
            maps[#maps + 1] = map
        end
    end
    if ns.db.collect then
        for map in pairs(Nodes()) do Add(map) end
    end
    if ns.db.collectSpawns then
        for map in pairs(ns.SPAWNS or EMPTY) do Add(map) end
    end
    local hbd = gm and gm.HBD
    if type(hbd) == "table" and type(hbd.GetAllMapIDs) == "function" then
        local ok, ids = pcall(hbd.GetAllMapIDs, hbd)
        if ok and type(ids) == "table" then
            for _, map in ipairs(ids) do Add(map) end
        end
    end
    return maps
end

local function FarmZones()
    if farm and farmVersion == ns.Collecting.Version() then return farm end
    local gm = ns.db.collectGatherMate and GatherMate()
    local levels = {} -- SkillLevel by node key (it only depends on your skill)
    local lists = { herbs = {}, ore = {} }
    for _, map in ipairs(FarmMaps(gm)) do
        local own = ns.db.collect and Nodes()[map]
        if type(own) ~= "table" then own = nil end
        local theirs = gmPlaces[map]
        if theirs == nil and (gm or ns.db.collectSpawns) then
            theirs = ReadTheirs(map, own) -- (not kept: every map's places would stay in memory)
        end
        local zone = { herbs = { 0, 0, 0, 0 }, ore = { 0, 0, 0, 0 } } -- [level] for 2-4, [1] the total
        for source = 1, 2 do
            local nodes = source == 1 and own or source == 2 and theirs or EMPTY
            for key, places in pairs(nodes) do
                local kind = ns.NodeKind(key)
                if (kind == "herbs" or kind == "ore") and type(places) == "table" and not ns.db.collectHidden[NodeEntry(key, kind)] then
                    local level = levels[key]
                    if level == nil then
                        level = ns.SkillLevel(key, kind) or false
                        levels[key] = level
                    end
                    if level and level >= 2 and level <= 4 then
                        local counts = zone[kind]
                        counts[level] = counts[level] + #places
                        counts[1] = counts[1] + #places
                    end
                end
            end
        end
        for kind, counts in pairs(zone) do
            if counts[1] > 0 then
                local info = C_Map.GetMapInfo(map)
                local name = info and not issecretvalue(info.name) and info.name or tostring(map)
                local list = lists[kind]
                list[#list + 1] = { map = map, name = name, total = counts[1], [2] = counts[2], [3] = counts[3], [4] = counts[4] }
            end
        end
    end
    for _, list in pairs(lists) do
        table.sort(list, function(a, b)
            if a.total ~= b.total then return a.total > b.total end
            return a.name < b.name
        end)
    end
    farm, farmVersion = lists, ns.Collecting.Version()
    return farm
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
-- A gather of ours under way (GatherMate2's message for it is skipped).
ownGathering = function() return cast ~= nil or done ~= nil and GetTime() - done.at <= LOOT_WAIT end

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
        ownAt = GetTime()
        ns.RereadNodePins() -- (GatherMate2's place there isn't marked twice)
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
    ns.RereadNodePins()
end

-- Collecting on or off in one go (General's box, the minimap button): on is the places you
-- gather and every known spawn, off is every source.
function ns.CollectingOn()
    local db = ns.db
    return db.collect == true or db.collectSpawns == true or db.collectGatherMate == true
end
function ns.SetCollecting(on)
    local db = ns.db
    db.collect, db.collectSpawns = on, on
    if not on then db.collectGatherMate = false end
    UpdateCollect() -- (it redraws the maps too)
end

---------------------------------------------------------------------------
-- World map
---------------------------------------------------------------------------
-- A small symbol on the map's canvas for each place on the map shown; the mouse on one
-- names its node, clicks go through to the map. Their look is set in the Collecting
-- settings, as NodeSight's minimap symbols once were.

local SHAPES = { "Square", "Round", "Round, gold ring", "Round, slim gold ring" }
local SKILL_LOOKS = { "Red when too low", "Colored ring", "Colored gem", "Off" }
local RING, GEM = 2, 3 -- (skill looks: 1 red, RING, GEM, 4 off)
local TRACKING = { herbs = "Professions_Tracking_Herb", ore = "Professions_Tracking_Ore" } -- a node with no item icon
local TOO_HARD = { 1, 0.2, 0.2 } -- red tint for nodes above your skill
local PIN_LEVEL = 100 -- over the canvas, if the map has no pin levels
-- The symbols' size by a map's zoom (0 widest to 1): half at the widest, full all the way in.
local function Shrink(zoom)
    return 0.5 + 0.5 * math.min(math.max(zoom, 0), 1)
end
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
    "Interface\\Common\\Indicator-Green", "Interface\\Common\\Indicator-Gray", orange = { 1, 0.55, 0.3 } }
local GEM_SIZE, GEM_AT = 0.76, 0.43 -- per symbol size: the gem's size, and its offset to the lower right
-- Minimap looks (COLLECT_MINI_LOOKS), so the game's own node dot under a symbol shows: a hole or
-- a see-through middle in the picture (masks, white with the clear part transparent), or the
-- symbol moved off the spot: a pin above a short stem. Moves and sizes per symbol size.
local MINI = { [2] = "Interface\\AddOns\\NodeSight\\MiniHole", [3] = "Interface\\AddOns\\NodeSight\\MiniFade",
    [4] = { scale = 0.8, x = 0, y = 0.9 }, STEM = { 0.35, 0.12 }, OTHER = { scale = 0.67, x = -0.5, y = 0.47 },
    -- The game draws its gold node dot up and right of the node's spot (its art is off the middle
    -- of its square in Interface\Minimap\ObjectIcons; measured in game on the closest zoom):
    -- the symbols' layer is moved as much (minimap units), so a spawn's symbol sits on the dot.
    DOT = { 1.8, 1.5 } }

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
    { "iron deposit", "inv_ore_iron_01" }, { "gold vein", "inv_ore_gold_01" },
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
local glows, glowsUsed = {}, 0 -- the same for the areas
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

-- A node's tooltip: its name, the skill it needs (as on the node in the world) and, for an
-- area, how many spawns it stands for.
local function Requires(key)
    local kind = ns.NodeKind(key)
    local level, need = ns.SkillLevel(key, kind)
    if ns.db.skillLine and level and ns.professions[kind] then
        GameTooltip:AddLine(ITEM_MIN_SKILL:format(ns.professions[kind], need), SkillColor(level):GetRGB())
    end
end
local function NodeTooltip(owner, anchor, key, area, gatherMate, merges, spot)
    GameTooltip:SetOwner(owner, anchor)
    if area and area.region then
        -- A region: its nodes and how many of each, colored by your skill.
        GameTooltip:SetText(area.kind == "herbs" and "Herbs" or "Ore")
        for _, node in ipairs(area.keys) do
            local level = ns.db.skillLine and ns.SkillLevel(node, area.kind)
            local r, g, b = (level and SkillColor(level) or NORMAL_FONT_COLOR):GetRGB()
            GameTooltip:AddDoubleLine(DisplayName(node), area.counts[node], r, g, b, 1, 1, 1)
        end
        if area.count > 1 then GameTooltip:AddLine(("%d spawns around here"):format(area.count), GRAY_FONT_COLOR:GetRGB()) end
        GameTooltip:AddLine("Zoom in to see each one", GRAY_FONT_COLOR:GetRGB())
        GameTooltip:Show()
        return
    end
    GameTooltip:SetText(DisplayName(key))
    Requires(key)
    -- A shared spot: the other nodes that spawn there.
    for _, other in ipairs(spot and spot.keys or EMPTY) do
        if other ~= key and Shown(other, ns.NodeKind(other)) then
            GameTooltip:AddLine(DisplayName(other), NORMAL_FONT_COLOR:GetRGB())
            Requires(other)
        end
    end
    if spot then GameTooltip:AddLine("Any of these can spawn here", GRAY_FONT_COLOR:GetRGB()) end
    if area then
        GameTooltip:AddLine(("%d spawns close together"):format(area.count), GRAY_FONT_COLOR:GetRGB())
        GameTooltip:AddLine("Zoom in to see each one", GRAY_FONT_COLOR:GetRGB())
    elseif merges and merges > 1 then
        GameTooltip:AddLine(("%d spawns here"):format(merges), GRAY_FONT_COLOR:GetRGB())
        GameTooltip:AddLine("Zoom in to see each one", GRAY_FONT_COLOR:GetRGB())
    elseif gatherMate then GameTooltip:AddLine(ns.db.collectSpawns and "Known spawn" or "GatherMate2", GRAY_FONT_COLOR:GetRGB()) end
    GameTooltip:Show()
end
local function PinEnter(pin) NodeTooltip(pin, "ANCHOR_RIGHT", pin.key, pin.area, pin.gatherMate, pin.lead == pin and pin.merges, pin.spot) end
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
    local size, ring = pin.drawn or pin.size, pin.ring
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
    pin.shape, pin.size, pin.miniLook = look.shape, look.size, look.mini
    pin:SetSize(look.size, look.size)
    -- Off the spot (a minimap look): the picture, and the ring and gem on it, smaller and moved.
    local away = MINI[look.mini or 1]
    away = type(away) == "table" and away or nil
    pin.drawn = away and look.size * away.scale or look.size
    pin.icon:ClearAllPoints()
    if away then
        pin.icon:SetSize(pin.drawn, pin.drawn)
        pin.icon:SetPoint("CENTER", pin, "CENTER", away.x * look.size, away.y * look.size)
    else
        pin.icon:SetSize(look.size, look.size)
        pin.icon:SetAllPoints()
    end
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
        pin.gem:SetSize(pin.drawn * GEM_SIZE, pin.drawn * GEM_SIZE)
        pin.gem:SetPoint("CENTER", pin.icon, "CENTER", pin.drawn * GEM_AT, -pin.drawn * GEM_AT)
    end
    -- A hole or a see-through middle: a second mask on the picture.
    local hole = type(MINI[look.mini or 1]) == "string" and MINI[look.mini] or nil
    if hole and not pin.hole then
        pin.hole = Smooth(pin:CreateMaskTexture())
        pin.hole:SetAllPoints(pin.icon)
    end
    if pin.hole and pin.holeFile ~= hole then
        if hole then pin.hole:SetTexture(hole, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE") end
        if hole and not pin.holeFile then pin.icon:AddMaskTexture(pin.hole) end
        if not hole then pin.icon:RemoveMaskTexture(pin.hole) end
        pin.holeFile = hole
    end
    -- The pin's stem down to the spot.
    local stem = look.mini == 4
    if stem and not pin.stem then
        pin.stem = pin:CreateLine(nil, "OVERLAY")
        pin.stem:SetColorTexture(0.9, 0.75, 0.3, 1)
    end
    if pin.stem then
        pin.stem:SetShown(stem)
        pin.stem:SetStartPoint("CENTER", pin, 0, MINI.STEM[1] * look.size)
        pin.stem:SetEndPoint("CENTER", pin, 0, MINI.STEM[2] * look.size)
        pin.stem:SetThickness(math.max(1, look.size / 8))
    end
end

-- The picture, the ore ring, skill colors and see-through, each set only when it changes.
local function ApplyLook(pin, key, kind, look)
    local picture = NodeIcon(key, kind) or TRACKING[kind]
    if pin.picture ~= picture then
        pin.picture = picture
        if picture == TRACKING[kind] then
            pin.icon:SetAtlas(picture)
        else
            pin.icon:SetTexture(picture)
            pin.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- (without the icon's border)
        end
    end
    local level = look.skill ~= 4 and (pin.sampleLevel or ns.SkillLevel(key, kind)) or nil -- (setup's preview gives its own)
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
        local size = pin.drawn or pin.size
        pin.gem:SetSize(size * GEM_SIZE, size * GEM_SIZE)
        pin.gem:SetPoint("CENTER", pin.icon, "CENTER", size * GEM_AT, -size * GEM_AT)
    end
    if pin.gem and pin.gemLevel ~= gem then
        pin.gemLevel = gem
        if gem then
            pin.gem:SetTexture(GEMS[gem])
            local color = gem == 2 and GEMS.orange or { 1, 1, 1 }
            pin.gem:SetVertexColor(color[1], color[2], color[3])
        end
        pin.gem:SetShown(gem ~= false)
    end
    -- See-through on the picture alone: the ring and the gem stay solid.
    if pin.alpha ~= look.alpha then
        pin.alpha = look.alpha
        pin.icon:SetAlpha(look.alpha)
    end
end

-- A minimap symbol on a shared spot (COLLECT_MINI_SHARED): the other node's picture on the
-- right half (both pictures item icons), or its symbol as a small badge at the top left.
-- Either goes with the picture wherever a minimap look puts it, through its masks too.
function MINI.Shared(pin, second, kind, look)
    local how = second and ns.db.collectMiniShared or 1
    local split = how == 2 and pin.picture ~= TRACKING[kind] and NodeIcon(second, kind) or nil
    if split and not pin.half then
        pin.half = Smooth(pin:CreateTexture(nil, "ARTWORK", nil, 1))
        pin.half:SetPoint("TOPLEFT", pin.icon, "TOP")
        pin.half:SetPoint("BOTTOMRIGHT", pin.icon, "BOTTOMRIGHT")
        pin.seam = Smooth(pin:CreateTexture(nil, "ARTWORK", nil, 2))
        pin.seam:SetColorTexture(0.1, 0.06, 0.02, 0.9)
        pin.seam:SetPoint("TOP", pin.icon, "TOP")
        pin.seam:SetPoint("BOTTOM", pin.icon, "BOTTOM")
        pin.half.masked, pin.seam.masked = {}, {}
    end
    if pin.half then
        pin.half:SetShown(split ~= nil)
        pin.seam:SetShown(split ~= nil)
    end
    if split then
        pin.half:SetTexture(split)
        pin.half:SetTexCoord(0.5, 0.92, 0.08, 0.92) -- (the picture's right half, without the icon's border)
        local hard = look.skill == 1 and ns.SkillLevel(second, kind) == 1
        if hard then pin.half:SetVertexColor(TOO_HARD[1], TOO_HARD[2], TOO_HARD[3]) else pin.half:SetVertexColor(1, 1, 1) end
        pin.half:SetAlpha(look.alpha)
        pin.seam:SetWidth(math.max(1, pin.drawn / 12))
        -- The picture's masks (round, a hole) on both.
        for _, part in ipairs({ pin.half, pin.seam }) do
            for _, mask in ipairs({ pin.mask or false, pin.hole or false }) do
                local on = mask and (mask == pin.mask and pin.round or mask == pin.hole and pin.holeFile ~= nil) or false
                if mask and (part.masked[mask] or false) ~= on then
                    part.masked[mask] = on
                    if on then part:AddMaskTexture(mask) else part:RemoveMaskTexture(mask) end
                end
            end
        end
    end
    local badge = how == 3
    if badge and not pin.other then
        pin.other = NewSymbol(pin)
        pin.other.look = {}
    end
    if pin.other then
        pin.other:SetShown(badge)
        if badge then
            local sub = pin.other.look
            for k, v in pairs(look) do sub[k] = v end
            sub.size, sub.mini = pin.drawn * MINI.OTHER.scale, nil
            if sub.skill == GEM then sub.skill = 4 end -- (no gem on the badge: the symbol's own is enough)
            ApplyShape(pin.other, sub)
            ApplyLook(pin.other, second, kind, sub)
            pin.other:ClearAllPoints()
            pin.other:SetPoint("CENTER", pin.icon, "CENTER", MINI.OTHER.x * pin.drawn, MINI.OTHER.y * pin.drawn)
        end
    end
end

-- A dot in the node's color (the world map at its widest zoom), or the symbol again.
local function ToDot(pin, key, kind, size)
    if pin.size ~= size then
        pin.size = size
        pin:SetSize(size, size)
    end
    if not pin.dotEdge then
        pin.dotEdge = Smooth(pin:CreateTexture(nil, "ARTWORK", nil, 1))
        pin.dotEdge:SetAtlas("CircleMask")
        pin.dotEdge:SetAllPoints()
        pin.dotFill = Smooth(pin:CreateTexture(nil, "ARTWORK", nil, 2))
        pin.dotFill:SetAtlas("CircleMask")
        pin.dotFill:SetPoint("CENTER")
    end
    pin.dotEdge:SetVertexColor(0, 0, 0, 0.8)
    pin.dotFill:SetSize(size * 0.7, size * 0.7) -- (inside its dark edge)
    local color = AreaColor(key, kind)
    pin.dotFill:SetVertexColor(color[1], color[2], color[3])
    if not pin.dotted then
        pin.dotted = true
        pin.icon:Hide()
        if pin.ring then pin.ring:Hide() end
        if pin.gem then pin.gem:Hide() end
        pin.dotEdge:Show()
        pin.dotFill:Show()
    end
end
local function FromDot(pin)
    if pin.dotted then
        pin.dotted = false
        pin.dotEdge:Hide()
        pin.dotFill:Hide()
        pin.icon:Show()
        pin.shape, pin.gemLevel = nil, -1 -- (the ring and the gem shown again as they should be)
    end
end

-- An area's count beside its symbol; nil hides it.
local function ShowCount(pin, count)
    if count and not pin.count then
        pin.count = pin:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        pin.count:SetPoint("LEFT", pin, "RIGHT", 1, -3)
    end
    if pin.count and pin.countOf ~= count then
        pin.countOf = count
        pin.count:SetText(count or "")
        pin.count:SetShown(count ~= nil)
    end
end

-- A region's frame over the canvas; Regions.Draw gives it its outline, soft glows and bands.
local function NewGlow(parent)
    return New("Frame", parent)
end

-- Regions and the other zoomed-out looks (below).
local Regions = { LINK = 180, RADIUS = 110, BAND = 90, GRID = 25, SMOOTH = 10, DASH = 7 }

-- The world map at its widest zoom (its scroll container says), or true where that can't be read.
local function ZoomedOut()
    local scroll = WorldMapFrame.ScrollContainer
    if not (scroll and scroll.IsAtMinZoom) then return true end
    local ok, out = pcall(scroll.IsAtMinZoom, scroll)
    return not ok or out ~= false
end
-- Areas on the world map now: at its widest zoom, with a look that has a symbol each.
local function MapAreas()
    return ZoomedOut() and Regions.Plain(Regions.Look())
end
local mapAreas -- what the symbols shown were set up for
local mapDots

-- The map's own level for points of interest, where it has one.
local function PinLevel(canvas)
    local manager = WorldMapFrame.GetPinFrameLevelsManager and WorldMapFrame:GetPinFrameLevelsManager()
    if manager and manager.GetValidFrameLevel then
        local ok, level = pcall(manager.GetValidFrameLevel, manager, "PIN_FRAME_LEVEL_AREA_POI")
        if ok and type(level) == "number" then return level end
    end
    return canvas:GetFrameLevel() + PIN_LEVEL
end

-- How far the world map is zoomed in, 0 (widest) to 1; 1 on a map that can't zoom.
local function MapZoom(now)
    local map = WorldMapFrame
    if not (now and map.GetScaleForMinZoom and map.GetScaleForMaxZoom) then return 1 end
    local ok, low = pcall(map.GetScaleForMinZoom, map)
    local ok2, high = pcall(map.GetScaleForMaxZoom, map)
    if not (ok and ok2 and type(low) == "number" and type(high) == "number" and high > low) then return 1 end
    return (now - low) / (high - low)
end
-- The zoomed-out look now (COLLECT_ZOOM_LOOKS): the one set at the widest zoom of a map that
-- zooms, otherwise 1 (a symbol each, as set).
function Regions.Look()
    local look = ns.db.collectZoomLook
    if look == 1 or MapZoom(WorldMapFrame.GetCanvasScale and WorldMapFrame:GetCanvasScale()) > 0 then return 1 end
    return look
end
-- A look with a symbol for each spawn (Symbols, Dots, Regions): areas show with them.
function Regions.Plain(look) return look == 1 or look == 8 or look == 9 end
-- Dots now: the zoomed-out look, on a map that zooms at its widest zoom.
local function MapDots()
    return Regions.Look() == 8
end

---------------------------------------------------------------------------
-- Regions
---------------------------------------------------------------------------
-- At the world map's widest zoom (as set), spawns show as outlined regions with one symbol and
-- a count, in place of a symbol each. Herbs share theirs (many grow over the same ground), and
-- so do ores that take turns at the same spots (iron, gold and silver): the outline in the two
-- most common ones' colors, each spot filled in its own node's. Only the nodes marked count. The outline is the edge of circles round the spots and bands along
-- the links between them, worked out once on a grid (marching squares), joined and smoothed.

-- Nodes of one kind that share at least a quarter of the fewer one's spots go together.
function Regions.Families(spots, counts)
    local parent = {}
    local function Find(key)
        while parent[key] and parent[key] ~= key do key = parent[key] end
        return key
    end
    local pairCounts, seen = {}, {}
    for _, byPlace in pairs(spots or EMPTY) do
        for _, spot in pairs(byPlace) do
            if not seen[spot] then
                seen[spot] = true
                for i = 1, #spot.keys do
                    for j = i + 1, #spot.keys do
                        local a, b = spot.keys[i], spot.keys[j]
                        if a > b then a, b = b, a end
                        local pair = a .. "|" .. b
                        pairCounts[pair] = (pairCounts[pair] or 0) + 1
                    end
                end
            end
        end
    end
    for pair, n in pairs(pairCounts) do
        local a, b = pair:match("^(.-)|(.*)$")
        if n >= 3 and n * 4 >= math.min(counts[a] or 0, counts[b] or 0) then
            local ra, rb = Find(a), Find(b)
            if ra ~= rb then parent[rb] = ra end
        end
    end
    return Find
end

-- The edge where `field` (a grid of nx by ny values, inside > 0) crosses 0: polylines of
-- x, y in yards from (x0, y0), joined end to end and smoothed.
function Regions.Outline(field, nx, ny, x0, y0)
    local grid, segs = Regions.GRID, {}
    local function At(i, j) return field[j * nx + i + 1] end
    local function Cross(ax, ay, va, bx, by, vb)
        local t = va / (va - vb)
        return ax + (bx - ax) * t, ay + (by - ay) * t
    end
    for j = 0, ny - 2 do
        for i = 0, nx - 2 do
            local v0, v1, v2, v3 = At(i, j), At(i + 1, j), At(i + 1, j + 1), At(i, j + 1)
            local a, b, c, d = v0 > 0, v1 > 0, v2 > 0, v3 > 0
            if not (a == b and b == c and c == d) then
                local x, y = x0 + i * grid, y0 + j * grid
                local e = {}
                if a ~= b then e[0] = { Cross(x, y, v0, x + grid, y, v1) } end
                if b ~= c then e[1] = { Cross(x + grid, y, v1, x + grid, y + grid, v2) } end
                if c ~= d then e[2] = { Cross(x + grid, y + grid, v2, x, y + grid, v3) } end
                if d ~= a then e[3] = { Cross(x, y + grid, v3, x, y, v0) } end
                local function Seg(p, q) segs[#segs + 1] = { e[p][1], e[p][2], e[q][1], e[q][2] } end
                if e[0] and e[1] and e[2] and e[3] then
                    -- A saddle: the middle decides which corners join.
                    local middle = (v0 + v1 + v2 + v3) > 0
                    if (a and c) == middle then Seg(0, 1) Seg(2, 3) else Seg(3, 0) Seg(1, 2) end
                else
                    local first
                    for k = 0, 3 do
                        if e[k] then
                            if first then Seg(first, k) else first = k end
                        end
                    end
                end
            end
        end
    end
    -- Joined end to end.
    local ends = {}
    local function Key(x, y) return floor(x * 8 + 0.5) .. ":" .. floor(y * 8 + 0.5) end
    for n, s in ipairs(segs) do
        for _, k in ipairs({ Key(s[1], s[2]), Key(s[3], s[4]) }) do
            ends[k] = ends[k] or {}
            local list = ends[k]
            list[#list + 1] = n
        end
    end
    local done, lines = {}, {}
    local function Next(x, y)
        for _, n in ipairs(ends[Key(x, y)]) do
            if not done[n] then
                done[n] = true
                local s = segs[n]
                if Key(s[1], s[2]) == Key(x, y) then return s[3], s[4] end
                return s[1], s[2]
            end
        end
    end
    for n, s in ipairs(segs) do
        if not done[n] then
            done[n] = true
            local after, before = { s[3], s[4] }, {}
            local x, y = Next(s[3], s[4])
            while x do
                after[#after + 1], after[#after + 2] = x, y
                x, y = Next(x, y)
            end
            x, y = Next(s[1], s[2])
            while x do
                before[#before + 1], before[#before + 2] = x, y
                x, y = Next(x, y)
            end
            local points = {}
            for k = #before - 1, 1, -2 do points[#points + 1], points[#points + 2] = before[k], before[k + 1] end
            points[#points + 1], points[#points + 2] = s[1], s[2]
            for k = 1, #after do points[#points + 1] = after[k] end
            lines[#lines + 1] = Regions.Smooth(points)
        end
    end
    return lines
end

-- Fewer points: each kept one Regions.SMOOTH yards or more off the straight line (Douglas-Peucker).
function Regions.Smooth(points)
    local n, keep = #points / 2, {}
    keep[1], keep[n] = true, true
    local function Split(first, last)
        local ax, ay, bx, by = points[2 * first - 1], points[2 * first], points[2 * last - 1], points[2 * last]
        local dx, dy = bx - ax, by - ay
        local len = math.sqrt(dx * dx + dy * dy)
        local far, at = 0, nil
        for k = first + 1, last - 1 do
            local px, py = points[2 * k - 1] - ax, points[2 * k] - ay
            local d = len > 0 and math.abs(px * dy - py * dx) / len or math.sqrt(px * px + py * py)
            if d > far then far, at = d, k end
        end
        if at and far > Regions.SMOOTH then
            keep[at] = true
            Split(first, at)
            Split(at, last)
        end
    end
    if n > 2 then Split(1, n) end
    local out = {}
    for k = 1, n do
        if keep[k] then out[#out + 1], out[#out + 2] = points[2 * k - 1], points[2 * k] end
    end
    return out
end

-- A map's regions (width by height yards), each an area with `region`: its nodes most common
-- first (`keys`, `counts`), `spots` (x, y in units) and `spotKeys`, the `line` of links, the
-- `edge` (polylines in units) and the map's size in yards.
function Regions.In(width, height, own, gm, spots, common)
    local function Marked(key, kind) return Shown(key, kind) and not (common and common[key]) end
    -- The spots: a place of each marked node, a shared spot once.
    local sites, counts, seen = {}, {}, {}
    for source = 1, 2 do
        for key, places in pairs(source == 1 and own or source == 2 and gm or EMPTY) do
            local kind = ns.NodeKind(key)
            if type(places) == "table" and (kind == "herbs" or kind == "ore") and Marked(key, kind) then
                for _, place in ipairs(places) do
                    local spot = spots and spots[key] and spots[key][place]
                    if not (spot and seen[spot]) then
                        if spot then seen[spot] = true end
                        local keys = {}
                        for _, k in ipairs(spot and spot.keys or { key }) do
                            if Marked(k, kind) then keys[#keys + 1] = k end
                        end
                        sites[#sites + 1] = { place = spot and spot.at[keys[1]] or place, keys = keys, kind = kind }
                        for _, k in ipairs(keys) do counts[k] = (counts[k] or 0) + 1 end
                    end
                end
            end
        end
    end
    local Find = Regions.Families(spots, counts)
    local families = {}
    for _, site in ipairs(sites) do
        local family = site.kind == "herbs" and "herbs" or Find(site.keys[1])
        families[family] = families[family] or {}
        local list = families[family]
        list[#list + 1] = site
    end
    local R, B, grid, list = Regions.RADIUS, Regions.BAND, Regions.GRID, {}
    for _, family in pairs(families) do
        local places = {}
        for i, site in ipairs(family) do places[i] = site.place end
        local groups, xs, ys = Groups(places, width, height, Regions.LINK)
        for _, group in ipairs(groups) do
            local area = { region = true, kind = family[group[1]].kind, counts = {}, keys = {}, count = #group,
                spots = {}, spotKeys = {}, line = {}, mapWidth = width, mapHeight = height }
            local sx, sy, x1, y1, x2, y2 = 0, 0, math.huge, math.huge, -math.huge, -math.huge
            for n, i in ipairs(group) do
                sx, sy = sx + xs[i], sy + ys[i]
                x1, y1, x2, y2 = math.min(x1, xs[i]), math.min(y1, ys[i]), math.max(x2, xs[i]), math.max(y2, ys[i])
                area.spots[2 * n - 1], area.spots[2 * n] = xs[i] / width * UNITS, ys[i] / height * UNITS
                area.spotKeys[n] = family[i].keys[1]
                for _, k in ipairs(family[i].keys) do
                    if not area.counts[k] then area.keys[#area.keys + 1] = k end
                    area.counts[k] = (area.counts[k] or 0) + 1
                end
            end
            table.sort(area.keys, function(a, b)
                if area.counts[a] ~= area.counts[b] then return area.counts[a] > area.counts[b] end
                return a < b
            end)
            area.key = area.keys[1]
            area.color = AreaColor(area.key, area.kind)
            -- Its symbol on the spot nearest its middle.
            local mx, my, mid, near = sx / #group, sy / #group, group[1], math.huge
            for _, i in ipairs(group) do
                local d = (xs[i] - mx) ^ 2 + (ys[i] - my) ^ 2
                if d < near then mid, near = i, d end
            end
            area.x, area.y, area.midX, area.midY = xs[mid] / width * UNITS, ys[mid] / height * UNITS, mx / width * UNITS, my / height * UNITS
            local links = #group > 1 and Links(group, xs, ys) or EMPTY
            for n = 1, #links do
                local i = links[n]
                area.line[2 * n - 1], area.line[2 * n] = xs[i] / width * UNITS, ys[i] / height * UNITS
            end
            -- The field: how far inside a circle round a spot or a band along a link (1 on it, 0 at its edge).
            local x0, y0 = x1 - R - 2 * grid, y1 - R - 2 * grid
            local nx, ny = floor((x2 + R + 2 * grid - x0) / grid) + 2, floor((y2 + R + 2 * grid - y0) / grid) + 2
            local field = {}
            for k = 1, nx * ny do field[k] = -1 end
            local function Splat(ax, ay, bx, by, r)
                local dx, dy = bx - ax, by - ay
                local len2 = dx * dx + dy * dy
                for j = math.max(0, floor((math.min(ay, by) - r - y0) / grid)), math.min(ny - 1, floor((math.max(ay, by) + r - y0) / grid) + 1) do
                    for i = math.max(0, floor((math.min(ax, bx) - r - x0) / grid)), math.min(nx - 1, floor((math.max(ax, bx) + r - x0) / grid) + 1) do
                        local px, py = x0 + i * grid - ax, y0 + j * grid - ay
                        local t = len2 > 0 and math.min(math.max((px * dx + py * dy) / len2, 0), 1) or 0
                        local v = 1 - math.sqrt((px - dx * t) ^ 2 + (py - dy * t) ^ 2) / r
                        local k = j * nx + i + 1
                        if v > field[k] then field[k] = v end
                    end
                end
            end
            for _, i in ipairs(group) do Splat(xs[i], ys[i], xs[i], ys[i], R) end
            for n = 1, #links, 2 do
                local a, b = links[n], links[n + 1]
                Splat(xs[a], ys[a], xs[b], ys[b], B)
            end
            area.edge = {}
            for _, points in ipairs(Regions.Outline(field, nx, ny, x0, y0)) do
                local poly = {}
                for k = 1, #points, 2 do poly[k], poly[k + 1] = points[k] / width * UNITS, points[k + 1] / height * UNITS end
                area.edge[#area.edge + 1] = poly
            end
            list[#list + 1] = area
        end
    end
    return list
end

-- A map's regions, worked out the first time they're asked for.
function Regions.Of(info, map)
    if info.regionsVersion ~= version then
        info.regionsVersion = version
        local width, height = C_Map.GetMapWorldSize(map)
        info.regions = false
        if not (issecretvalue(width) or issecretvalue(height)) and type(width) == "number" and type(height) == "number"
            and width > 0 and height > 0 then
            info.regions = Regions.In(width, height, info.own, info.gm, info.spots, info.common)
        end
    end
    return info.regions or nil
end

-- Regions now: the zoomed-out look, on a map that zooms at its widest zoom.
function Regions.Now()
    return Regions.Look() == 9
end

-- The mouse at u, v (units) inside the region: near one of its spots or links.
function Regions.Inside(area, u, v)
    local ux, uy = area.mapWidth / UNITS, area.mapHeight / UNITS -- (yards a unit)
    local spots, line = area.spots, area.line
    for k = 1, #spots, 2 do
        local dx, dy = (u - spots[k]) * ux, (v - spots[k + 1]) * uy
        if dx * dx + dy * dy <= Regions.RADIUS * Regions.RADIUS then return true end
    end
    for k = 1, #line, 4 do
        local ax, ay = line[k] * ux, line[k + 1] * uy
        local bx, by = line[k + 2] * ux - ax, line[k + 3] * uy - ay
        local px, py = u * ux - ax, v * uy - ay
        local len2 = bx * bx + by * by
        local t = len2 > 0 and math.min(math.max((px * bx + py * by) / len2, 0), 1) or 0
        if (px - bx * t) ^ 2 + (py - by * t) ^ 2 <= Regions.BAND * Regions.BAND then return true end
    end
    return false
end

-- The nodes of a region the map marks now.
function Regions.Shown(area, common)
    local out = {}
    for _, key in ipairs(area.keys) do
        if Shown(key, area.kind) and not (common and common[key]) then out[#out + 1] = key end
    end
    return out
end

-- Draws a region on the canvas (width by height pixels; `scale`: canvas pixels a screen pixel).
function Regions.Draw(glow, area, canvas, width, height, scale)
    glow.edges, glow.puffs, glow.bands = glow.edges or {}, glow.puffs or {}, glow.bands or {}
    local px = width / area.mapWidth -- (canvas pixels a yard)
    local keys = glow.keys or EMPTY
    local c1 = AreaColor(keys[1] or area.key, area.kind)
    local c2 = keys[2] and AreaColor(keys[2], area.kind)
    if c2 == c1 then c2 = nil end
    -- The fill: a soft glow on each spot in its node's color, a soft band along each link.
    local spots, n = area.spots, 0
    for k = 1, #spots, 2 do
        n = n + 1
        local puff = glow.puffs[n]
        if not puff then
            puff = Smooth(glow:CreateTexture(nil, "BACKGROUND"))
            puff:SetTexture(GLOW)
            glow.puffs[n] = puff
        end
        local color = AreaColor(area.spotKeys[n], area.kind)
        puff:SetSize(2 * Regions.RADIUS * px, 2 * Regions.RADIUS * px)
        puff:ClearAllPoints()
        puff:SetPoint("CENTER", canvas, "TOPLEFT", spots[k] / UNITS * width, -spots[k + 1] / UNITS * height)
        puff:SetVertexColor(color[1], color[2], color[3])
        puff:SetAlpha(0.12) -- (faint: they stack where spots crowd; the outline shows the shape)
        puff:Show()
    end
    for i = n + 1, #glow.puffs do glow.puffs[i]:Hide() end
    local line, b = area.line, 0
    for k = 1, #line, 4 do
        b = b + 1
        local band = glow.bands[b]
        if not band then
            band = glow:CreateLine(nil, "BACKGROUND")
            band:SetTexture(LINE)
            glow.bands[b] = band
        end
        band:SetStartPoint("TOPLEFT", canvas, line[k] / UNITS * width, -line[k + 1] / UNITS * height)
        band:SetEndPoint("TOPLEFT", canvas, line[k + 2] / UNITS * width, -line[k + 3] / UNITS * height)
        band:SetThickness(2 * Regions.BAND * px)
        band:SetVertexColor(c1[1], c1[2], c1[3])
        band:SetAlpha(0.08)
        band:Show()
    end
    for i = b + 1, #glow.bands do glow.bands[i]:Hide() end
    -- The outline: solid in one color, or dashes taking turns in two.
    local e, dash, thick = 0, Regions.DASH * scale, 1.6 * scale
    local function Edge(x1, y1, x2, y2, color)
        e = e + 1
        local part = glow.edges[e]
        if not part then
            part = glow:CreateLine(nil, "ARTWORK")
            part:SetColorTexture(1, 1, 1, 1)
            glow.edges[e] = part
        end
        part:SetStartPoint("TOPLEFT", canvas, x1, y1)
        part:SetEndPoint("TOPLEFT", canvas, x2, y2)
        part:SetThickness(thick)
        part:SetVertexColor(color[1], color[2], color[3])
        part:SetAlpha(0.85)
        part:Show()
    end
    for _, poly in ipairs(area.edge) do
        local run, turn = 0, false
        for k = 1, #poly - 2, 2 do
            local x1, y1 = poly[k] / UNITS * width, -poly[k + 1] / UNITS * height
            local x2, y2 = poly[k + 2] / UNITS * width, -poly[k + 3] / UNITS * height
            if not c2 then
                Edge(x1, y1, x2, y2, c1)
            else
                local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
                local at = 0
                while at < len do
                    local step = math.min(dash - run, len - at)
                    Edge(x1 + (x2 - x1) * at / len, y1 + (y2 - y1) * at / len,
                        x1 + (x2 - x1) * (at + step) / len, y1 + (y2 - y1) * (at + step) / len, turn and c2 or c1)
                    at, run = at + step, run + step
                    if run >= dash then run, turn = 0, not turn end
                end
            end
        end
    end
    for i = e + 1, #glow.edges do glow.edges[i]:Hide() end
end

function Regions.Hide(glow)
    for _, list in ipairs({ glow.edges or EMPTY, glow.puffs or EMPTY, glow.bands or EMPTY }) do
        for _, part in ipairs(list) do part:Hide() end
    end
end

-- Symbols of one node that would overlap at this zoom show as one, with their count: each
-- group's first symbol (its `lead`) at their middle, the others hidden. `near`: a symbol's
-- width in canvas pixels.
local cells = {}
local function Merge(width, height, near, look)
    for i = 1, used do pins[i].lead = nil end
    if look == 1 and not ns.db.collectMerge then return end
    wipe(cells)
    local byKind = look == 5 or look == 6 -- (mix rings and groups: every node of a kind together)
    for i = 1, used do
        local pin = pins[i]
        if not pin.area then
            pin.px, pin.py = pin.x / UNITS * width, pin.y / UNITS * height
            local group = byKind and pin.kind or pin.key
            local byKey = cells[group] or {}
            cells[group] = byKey
            local cell = floor(pin.px / near) * 65536 + floor(pin.py / near)
            local list = byKey[cell] or {}
            byKey[cell] = list
            list[#list + 1] = pin
        end
    end
    for i = 1, used do
        local lead = pins[i]
        if not lead.area and not lead.lead then
            lead.lead = lead
            local n, sx, sy = 1, lead.px, lead.py
            local byKey, cx, cy = cells[byKind and lead.kind or lead.key], floor(lead.px / near), floor(lead.py / near)
            for dx = -1, 1 do
                for dy = -1, 1 do
                    for _, pin in ipairs(byKey[(cx + dx) * 65536 + cy + dy] or EMPTY) do
                        if not pin.lead and (pin.px - lead.px) ^ 2 + (pin.py - lead.py) ^ 2 < near * near then
                            pin.lead = lead
                            n, sx, sy = n + 1, sx + pin.px, sy + pin.py
                        end
                    end
                end
            end
            lead.merges, lead.mx, lead.my = n, sx / n, sy / n
        end
    end
end

---------------------------------------------------------------------------
-- Zoomed-out looks
---------------------------------------------------------------------------
-- Other ways to show spawns at the world map's widest zoom (COLLECT_ZOOM_LOOKS; 2, 3 and 7 are
-- unused): 4 hex tiles tinted by their most common node, its symbol in each, 5 a symbol a group
-- with a ring split by its nodes' shares, 6 one symbol for each group of herbs or ore, the most
-- common one's, with a count; 8 dots and 9 regions are drawn by Refresh.
-- Sizes in symbols: a tile from its middle to a corner, the ring, a group's reach.
Regions.HEX, Regions.RING, Regions.GROUP = 0.95, 0.18, 3
-- A faded node's strength (Bright), and the world map's reach round you for its common nodes (yards).
Regions.FADED, Regions.NEAR = 0.35, 300
Regions.TILE = "Interface\\CovenantRenown\\CovenantRenownHexagonMask" -- (a white flat-topped hex, 40 of its 64 pixels wide)
Regions.ARCS, Regions.BLACK = 20, { 0, 0, 0 } -- (lines a ring)

-- Flat-topped hex tiles `r` canvas pixels across from the middle to a corner: each tile's
-- first spawn leads it, at the tile's middle.
function Regions.Hex(width, height, r)
    wipe(cells)
    for i = 1, used do
        local pin = pins[i]
        pin.lead = nil
        if not pin.area then
            local x, y = pin.x / UNITS * width, pin.y / UNITS * height
            local q, s = 2 / 3 * x / r, (-x / 3 + math.sqrt(3) / 3 * y) / r
            local rq, rs, rt = floor(q + 0.5), floor(s + 0.5), floor(-q - s + 0.5)
            local dq, ds, dt = abs(rq - q), abs(rs - s), abs(rt + q + s)
            if dq > ds and dq > dt then rq = -rs - rt elseif ds > dt then rs = -rq - rt end
            local id = rq * 65536 + rs
            local lead = cells[id]
            if lead then
                pin.lead, lead.merges = lead, lead.merges + 1
            else
                cells[id] = pin
                pin.lead, pin.merges = pin, 1
                pin.mx, pin.my = r * 1.5 * rq, r * math.sqrt(3) * (rs + rq / 2)
            end
        end
    end
end

-- Each group led by a spawn of its most common node (ties: the first name), with how many of each.
function Regions.Lead()
    for i = 1, used do
        local pin = pins[i]
        if pin.lead == pin then
            pin.mix = pin.mix or {}
            wipe(pin.mix)
        end
    end
    for i = 1, used do
        local pin = pins[i]
        local lead = pin.lead
        if lead then lead.mix[pin.key] = (lead.mix[pin.key] or 0) + 1 end
    end
    for i = 1, used do
        local lead = pins[i]
        if lead.lead == lead then
            local best, most = nil, 0
            for key, n in pairs(lead.mix) do
                if n > most or (n == most and key < best) then best, most = key, n end
            end
            if best ~= lead.key then
                local new
                for j = 1, used do
                    if not new and pins[j].lead == lead and pins[j].key == best then new = pins[j] end
                end
                new.merges, new.mx, new.my, new.mix, lead.mix = lead.merges, lead.mx, lead.my, lead.mix, new.mix
                for j = 1, used do
                    if pins[j].lead == lead then pins[j].lead = new end
                end
            end
        end
    end
end

-- The tiles and rings, on one frame under the symbols (`sym`: a symbol's width on the canvas).
function Regions.Layer(canvas, look, width, height, sym, level)
    local layer = Regions.layer
    if look < 4 then
        if layer then layer:Hide() end
        return
    end
    if not layer then
        layer = New("Frame", canvas)
        layer:SetAllPoints(canvas)
        layer.tex, layer.arcs = {}, {}
        Regions.layer = layer
    end
    layer:SetFrameLevel(math.max(0, (level or PinLevel(canvas)) - 1))
    layer:Show()
    local t, a = 0, 0
    local function Tex(file, sub, x, y, size, color, alpha)
        t = t + 1
        local tex = layer.tex[t]
        if not tex then
            tex = Smooth(layer:CreateTexture(nil, "BACKGROUND"))
            layer.tex[t] = tex
        end
        tex:SetTexture(file)
        tex:SetDrawLayer("BACKGROUND", sub)
        tex:SetSize(size, size)
        tex:ClearAllPoints()
        tex:SetPoint("CENTER", canvas, "TOPLEFT", x, -y)
        tex:SetVertexColor(color[1], color[2], color[3])
        tex:SetAlpha(alpha)
        tex:Show()
    end
    local function Arc(x1, y1, x2, y2, thick, color, alpha, layerName)
        a = a + 1
        local arc = layer.arcs[a]
        if not arc then
            arc = layer:CreateLine(nil, "BORDER")
            arc:SetColorTexture(1, 1, 1, 1)
            layer.arcs[a] = arc
        end
        arc:SetDrawLayer(layerName)
        arc:SetStartPoint("TOPLEFT", canvas, x1, -y1)
        arc:SetEndPoint("TOPLEFT", canvas, x2, -y2)
        arc:SetThickness(thick)
        arc:SetVertexColor(color[1], color[2], color[3])
        arc:SetAlpha(alpha)
        arc:Show()
    end
    local BLACK = Regions.BLACK
    for i = 1, used do
        local pin = pins[i]
        if pin.lead == pin and look == 4 then
            local size, n = 3.2 * Regions.HEX * sym, pin.merges -- (the hex is 20 of the texture's 64 pixels from middle to corner)
            Tex(Regions.TILE, 0, pin.mx, pin.my, size, BLACK, math.min(0.8, 0.25 + 0.14 * n))
            Tex(Regions.TILE, 1, pin.mx, pin.my, size * 0.86, AreaColor(pin.key, pin.kind), math.min(0.55, 0.17 + 0.1 * n))
        elseif pin.lead == pin and look == 5 then
            local thick = Regions.RING * sym
            local r = sym / 2 + thick -- (round the symbol)
            local x, y, n = pin.mx, pin.my, pin.merges
            for k = 1, Regions.ARCS do
                local a1, a2 = (k - 1) / Regions.ARCS * 2 * math.pi, k / Regions.ARCS * 2 * math.pi
                -- This piece's node: the one whose share covers its middle, the biggest share first from the top.
                local at, key, done = (k - 0.5) / Regions.ARCS * n, pin.key, pin.mix[pin.key]
                if at > done then
                    for other, m in pairs(pin.mix) do
                        if other ~= pin.key and at > done then key, done = other, done + m end
                    end
                end
                local x1, y1 = x + r * math.sin(a1), y - r * math.cos(a1)
                local x2, y2 = x + r * math.sin(a2), y - r * math.cos(a2)
                Arc(x1, y1, x2, y2, thick * 1.8, BLACK, 0.8, "BACKGROUND")
                Arc(x1, y1, x2, y2, thick, AreaColor(key, pin.kind), 1, "BORDER")
            end
        end
    end
    for i = t + 1, #layer.tex do layer.tex[i]:Hide() end
    for i = a + 1, #layer.arcs do layer.arcs[i]:Hide() end
end

-- Sizes and places the symbols shown. The canvas grows as the map zooms in: the symbols
-- keep their size on screen, smaller zoomed out. A zoom only needs this. (The setup's world
-- map preview gives its own frame, scale, zoom, look and frame level.)
local function Place(canvas, scale, zoom, look, level)
    canvas = canvas or Canvas()
    local width, height = canvas:GetSize()
    scale = scale or WorldMapFrame.GetCanvasScale and WorldMapFrame:GetCanvasScale() or canvas:GetScale()
    local shrink = Shrink(zoom or MapZoom(scale))
    scale = scale and scale > 0 and 1 / scale or 1
    look = look or Regions.Look()
    if look == 8 or look == 9 then look = 1 end -- (dots and regions are set up by Refresh)
    local size, sym = scale * shrink, ns.db.collectSize * scale * shrink
    if look == 4 then
        Regions.Hex(width, height, Regions.HEX * sym)
    else
        Merge(width, height, sym * (look == 5 and 2.5 or look == 6 and Regions.GROUP or 1), look)
    end
    if look >= 4 then Regions.Lead() end
    local tiles = look == 4 -- (no count: the tile shows how many)
    for i = 1, used do
        local pin = pins[i]
        local lead = pin.lead
        local hidden = lead ~= nil and lead ~= pin
        if pin.hidden ~= hidden then
            pin.hidden = hidden
            pin:SetShown(not hidden)
        end
        if not hidden then
            pin:SetScale(size)
            if lead then
                pin:SetPoint("CENTER", canvas, "TOPLEFT", lead.mx / size, -lead.my / size)
                ShowCount(pin, not tiles and lead.merges > 1 and lead.merges or nil)
            else
                pin:SetPoint("CENTER", canvas, "TOPLEFT", pin.x / UNITS * width / size, -pin.y / UNITS * height / size)
                if not pin.area then ShowCount(pin, nil) end
            end
        end
    end
    Regions.Layer(canvas, look, width, height, sym, level)
    -- The regions' outlines grow with the map.
    for i = 1, glowsUsed do
        local glow = glows[i]
        glow:SetAllPoints(canvas)
        Regions.Draw(glow, glow.area, canvas, width, height, scale)
    end
end

-- The symbols' settings (`mini`: the minimap's size).
local function CurrentLook(mini)
    local db = ns.db
    return { shape = db.collectShape, size = mini and db.collectMiniSize or db.collectSize, skill = db.collectSkill,
        mini = mini and db.collectMiniLook or nil,
        oreRings = db.collectOreRings, alpha = db.collectOpacity / 100 }
end

-- A map's symbols and areas set up on canvas as the world map shows them (`info`: MapInfo's;
-- `regions`, `areasOn` and `dots`: what shows at this zoom). A preview's made-up spawns bring
-- their own skill colors (`levels`).
function Regions.Fill(canvas, own, gm, info, regions, areasOn, dots, level, levels, near)
    local db = ns.db
    local common = info.common or EMPTY
    -- The world map's rare ones: a common node shows only within reach of you (`near`: where
    -- you are in units, yards a unit each way and the reach squared).
    local mapCommon = info.mapCommon
    local function Far(x, y)
        if not near then return true end
        local dx, dy = (x - near.x) * near.w, (y - near.y) * near.h
        return dx * dx + dy * dy > near.r2
    end
    local function Away(key, x, y) return mapCommon ~= nil and mapCommon[key] == true and Far(x, y) end
    local bright = db.collectBright
    -- Areas off here, or zoomed in: every spawn has its symbol.
    local areas, inAreas
    if regions then
        areas = regions -- (every spawn in one: no symbol each)
    elseif areasOn then
        areas, inAreas = info.areas, info.inAreas
    end
    local look = CurrentLook()
    look.alpha = 1 -- solid: no node under them on the world map
    local function Symbol(key, kind, x, y, gatherMate, area, spot)
        local pin = Pin(canvas)
        pin.sampleLevel = levels and levels[key] or nil
        pin.key, pin.x, pin.y, pin.gatherMate, pin.area, pin.spot, pin.kind = key, x, y, gatherMate, area, spot, kind
        if dots and not area then
            ToDot(pin, key, kind, look.size)
        else
            FromDot(pin)
            if pin.shape ~= look.shape or pin.size ~= look.size then ApplyShape(pin, look) end
            ApplyLook(pin, key, kind, look)
        end
        ShowCount(pin, area and area.count > 1 and area.count or nil)
        -- Bright: one node in full, the others faded and under it.
        local faded = bright and NodeEntry(key, kind) ~= bright
        pin:SetAlpha(faded and Regions.FADED or 1)
        pin:SetFrameLevel(level + (bright and not faded and 1 or 0))
        pin:ClearAllPoints()
        pin:Show()
        pin.hidden = false
    end
    for source = 1, regions and 0 or 2 do
        local nodes = source == 1 and own or source == 2 and gm or EMPTY
        for key, places in pairs(nodes) do
            local kind = ns.NodeKind(key)
            if (kind == "herbs" or kind == "ore") and type(places) == "table" and Shown(key, kind) and not common[key] then
                local skip = inAreas and inAreas[key] or EMPTY
                for _, place in ipairs(places) do
                    local x, y = Unpack(place)
                    -- Far from you a shared spot shows its rare node (gold at iron's spot), as Rare ones only does.
                    local far = mapCommon ~= nil and Far(x, y)
                    local drawn, spot = Spots.Drawn(info.spots, key, place, far and mapCommon or info.common)
                    if not skip[place] and drawn and not (far and mapCommon[key]) then Symbol(key, kind, x, y, source == 2, nil, spot) end
                end
            end
        end
    end
    for _, area in ipairs(areas or EMPTY) do
        local keys = area.region and Regions.Shown(area, common)
        if (keys and keys[1]) or (not keys and Shown(area.key, area.kind) and not common[area.key] and not Away(area.key, area.x, area.y)) then
            Symbol(keys and keys[1] or area.key, area.kind, area.x, area.y, false, area)
            if area.region then
                glowsUsed = glowsUsed + 1
                local glow = glows[glowsUsed] or NewGlow(canvas)
                glows[glowsUsed] = glow
                glow.area, glow.keys = area, keys
                glow:SetAlpha(bright and NodeEntry(keys[1], area.kind) ~= bright and Regions.FADED or 1)
                glow:SetFrameLevel(math.max(0, level - 1))
                glow:ClearAllPoints()
                glow:Show()
            end
        end
    end
end

-- The settings window's world map preview: made-up spawns (`own`, on a map width by height
-- yards) drawn on `frame` as the world map draws a map at its widest zoom, into
-- `frame.symbols` (one for each spawn). The world map's own symbols, areas and layer are put
-- back after.
function Regions.Preview(frame, own, levels, width, height, level)
    local mine = { pins, used, glows, glowsUsed, Regions.layer }
    frame.glows = frame.glows or {}
    pins, used, glows, glowsUsed, Regions.layer = frame.symbols, 0, frame.glows, 0, frame.layer
    Spots.sample = true
    local ok, err = pcall(function()
        local db = ns.db
        local look = db.collectZoomLook
        local plain = Regions.Plain(look) -- (the other looks take the place of areas)
        local info = { common = Common(nil, own, nil) }
        info.mapCommon = db.collectMapRare and not db.collectRareOnly and Common(nil, own, nil, true) or nil
        info.areas, info.inAreas = AreasIn(width, height, own, nil)
        local regions = look == 9 and Regions.In(width, height, own, nil, nil, info.common) or nil
        local near = { x = UNITS / 2, y = UNITS / 2, w = width / UNITS, h = height / UNITS, r2 = Regions.NEAR * Regions.NEAR } -- (you at the middle)
        Regions.Fill(frame, own, nil, info, regions, plain, look == 8, level, levels, near)
        Place(frame, 1, 0, db.collectZoomLook, level)
        for i = used + 1, #pins do pins[i]:Hide() end
        for i = glowsUsed + 1, #glows do glows[i]:Hide() end
    end)
    Spots.sample = nil
    frame.layer = Regions.layer
    pins, used, glows, glowsUsed, Regions.layer = mine[1], mine[2], mine[3], mine[4], mine[5]
    if not ok then error(err, 0) end
end

-- The symbols of the map shown, set up again.
local function Refresh()
    used, glowsUsed, mapAreas, mapDots = 0, 0, nil, nil
    local canvas = Canvas()
    local db = ns.db
    if canvas and WorldMapFrame:IsShown() and (db.collect or db.collectSpawns or db.collectGatherMate) and db.collectMap then
        local map = WorldMapFrame:GetMapID()
        local own, gm
        if not issecretvalue(map) and type(map) == "number" then own, gm = Sources(map) end
        if own or gm then
            local info = MapInfo(map, own, gm)
            mapAreas, mapDots = MapAreas(), MapDots()
            Regions.shown = Regions.Now()
            local near = info.mapCommon and Regions.Near(map)
            Regions.Fill(canvas, own, gm, info, Regions.shown and Regions.Of(info, map), mapAreas, mapDots, PinLevel(canvas), nil, near)
            Place()
        end
    end
    for i = used + 1, #pins do pins[i]:Hide() end
    for i = glowsUsed + 1, #glows do glows[i]:Hide() end
    if used == 0 then Regions.Layer(canvas, 1) end
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
-- square cut at the top and bottom (a table of its own, so a change between them redraws).
local ELLESMERE = { circle = QUARTERS.ROUND, textured_circle = QUARTERS.ROUND, square = QUARTERS.SQUARE,
    rectangular = { false, false, false, false } }

local mini -- the frame over the minimap
local minis, miniUsed, miniShown = {}, 0, 0
local miniShrink = 1 -- the symbols' scale at the minimap's zoom
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

local function Plain(...)
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if issecretvalue(v) or type(v) ~= "number" then return false end
    end
    return true
end

-- GetPlayerMapPosition makes a new table each call (garbage every frame while you move), so the
-- place comes from UnitPosition's plain numbers through the map's corners in the world, read once
-- a map. Checked against GetPlayerMapPosition at first and every few seconds; a map where they
-- disagree keeps GetPlayerMapPosition.
local corners = {} -- [map] = { a0, b0, a1, b1, how, instance, checkAt }, or false
local CHECK_EVERY, CHECK_YARDS = 5, 1
local function SlowPosition(map)
    local position = C_Map.GetPlayerMapPosition(map, "player")
    if issecretvalue(position) or not position then return nil end
    local x, y = position:GetXY()
    if not Plain(x, y) then return nil end
    return x, y
end
local function Corner(map, u, v)
    if not (C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local ok, _, world = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(u, v))
    if not ok or issecretvalue(world) or type(world) ~= "table" then return nil end
    local a, b = world:GetXY()
    if not Plain(a, b) then return nil end
    return a, b
end
-- Which of UnitPosition's numbers and which of the corners' go with the map's x: one of four
-- ways (`how`), found by the first check.
local function FromWorld(c, how, wx, wy)
    local u, v = wx, wy
    if how == 2 or how == 4 then u, v = wy, wx end
    if how <= 2 then return (u - c[1]) / (c[3] - c[1]), (v - c[2]) / (c[4] - c[2]) end
    return (u - c[2]) / (c[4] - c[2]), (v - c[1]) / (c[3] - c[1])
end
local function Close(c, how, wx, wy, sx, sy, width, height)
    local x, y = FromWorld(c, how, wx, wy)
    return abs(x - sx) * width <= CHECK_YARDS and abs(y - sy) * height <= CHECK_YARDS
end

-- Your place on a map (0 to 1) and the map's size in yards; nil where unknown.
local function MapPosition(map)
    local width, height = C_Map.GetMapWorldSize(map)
    if not Plain(width, height) or width <= 0 or height <= 0 then return nil end
    local c = corners[map]
    if c == nil then
        local a0, b0 = Corner(map, 0, 0)
        local a1, b1 = Corner(map, 1, 1)
        c = a0 and a1 and a1 ~= a0 and b1 ~= b0 and { a0, b0, a1, b1, nil, nil, 0 } or false
        corners[map] = c
    end
    local wx, wy, _, instance = UnitPosition("player")
    if c and Plain(wx, wy, instance) and (c[6] == nil or c[6] == instance) then
        if GetTime() < c[7] then
            local x, y = FromWorld(c, c[5], wx, wy)
            return x, y, width, height
        end
        local sx, sy = SlowPosition(map)
        if not sx then return nil end
        if not c[5] then
            -- The way that fits; none: not for this map; more than one (a spot where they agree): later.
            local found, fits = nil, 0
            for how = 1, 4 do
                if Close(c, how, wx, wy, sx, sy, width, height) then found, fits = how, fits + 1 end
            end
            if fits ~= 1 then
                if fits == 0 then corners[map] = false end
                return sx, sy, width, height
            end
            c[5] = found
        end
        if Close(c, c[5], wx, wy, sx, sy, width, height) then
            c[6], c[7] = instance, GetTime() + CHECK_EVERY
        else
            corners[map] = false
        end
        return sx, sy, width, height
    end
    local x, y = SlowPosition(map)
    if not x then return nil end
    return x, y, width, height
end
-- Where you are on `map` for the world map's rare ones (Regions.Fill's `near`), or nil.
function Regions.Near(map)
    local x, y, width, height = MapPosition(map)
    if not x then return nil end
    return { x = x * UNITS, y = y * UNITS, w = width / UNITS, h = height / UNITS, r2 = Regions.NEAR * Regions.NEAR }
end

-- The places within reach plus NEAR_STEP yards of where the list was made, so a frame
-- goes through those and not every place on the map. Made again after NEAR_STEP yards.
-- The minimap and the compass each keep a list: { key = {}, kind = {}, place = {}, count = 0 }.
local NEAR_STEP = 20

local function NewNearList() return { key = {}, kind = {}, place = {}, second = {}, count = 0 } end
local nearMini = NewNearList()

local function Near(list, own, gm, x, y, width, height, reach, inAreas, common, spots)
    if list.own == own and list.gm == gm and list.version == version and list.reach == reach and list.inAreas == inAreas then
        local east, north = (x - list.x) * width, (y - list.y) * height
        if east * east + north * north <= NEAR_STEP * NEAR_STEP then return end
    end
    local far = (math.sqrt(reach) + NEAR_STEP) ^ 2
    local keys, kindsOf, placesOf, seconds = list.key, list.kind, list.place, list.second
    local n = 0
    for source = 1, 2 do
        local nodes = source == 1 and own or source == 2 and gm or EMPTY
        for key, places in pairs(nodes) do
            local kind = kinds[key]
            if kind == nil then
                kind = ns.NodeKind(key) or false
                kinds[key] = kind
            end
            if (kind == "herbs" or kind == "ore") and type(places) == "table" and Shown(key, kind) and not (common and common[key]) then
                local skip = inAreas and inAreas[key] or EMPTY -- (the minimap's: drawn as areas)
                for _, place in ipairs(places) do
                    local east = (floor(place / PACK) / UNITS - x) * width
                    local north = (y - place % PACK / UNITS) * height
                    if not skip[place] and east * east + north * north <= far then
                        local drawn, spot = Spots.Drawn(spots, key, place, common)
                        if drawn then
                            n = n + 1
                            keys[n], kindsOf[n], placesOf[n] = key, kind, place
                            seconds[n] = spot and Spots.Second(spot, key, common) or false
                        end
                    end
                end
            end
        end
    end
    for i = n + 1, list.count do keys[i], kindsOf[i], placesOf[i], seconds[i] = nil, nil, nil, nil end
    list.count = n
    list.own, list.gm, list.version, list.reach, list.x, list.y, list.inAreas = own, gm, version, reach, x, y, inAreas
end

-- One minimap symbol (an area's with its count); returns the look, worked out once a frame.
-- How strong a minimap symbol shows dx, dy from the middle of a minimap `half` across: full near
-- you, fading toward the edge (Fade toward the edge).
function MINI.Fade(dx, dy, half)
    if not ns.db.collectMiniFade or not half or half <= 0 then return 1 end
    local out = math.sqrt(dx * dx + dy * dy) / half
    if out <= MINI.FADE_FROM then return 1 end
    return math.max(MINI.FADE_TO, 1 - (out - MINI.FADE_FROM) / (1 - MINI.FADE_FROM) * (1 - MINI.FADE_TO))
end
MINI.FADE_FROM, MINI.FADE_TO = 0.4, 0.3 -- (full within 40 % of the way out, down to 30 % at the edge)
MINI.STILL = 0.5 -- minimap units a symbol may lag before it's drawn again
-- In a cave (indoors) only the nearest few: the places have no height, so every tunnel and
-- level of a mine would show at once, and the minimap is zoomed right in there.
MINI.INDOORS = 5

local function MiniSymbol(key, kind, dx, dy, count, look, second)
    miniUsed = miniUsed + 1
    local pin = minis[miniUsed] or NewSymbol(mini)
    minis[miniUsed] = pin
    if pin.key ~= key or pin.version ~= version or pin.second ~= second then
        look = look or CurrentLook(true)
        pin.key, pin.version, pin.second = key, version, second
        if pin.shape ~= look.shape or pin.size ~= look.size or pin.miniLook ~= look.mini then ApplyShape(pin, look) end
        ApplyLook(pin, key, kind, look)
        MINI.Shared(pin, second, kind, look)
    end
    ShowCount(pin, count)
    if pin.shrink ~= miniShrink then pin.shrink = miniShrink pin:SetScale(miniShrink) end
    pin:SetPoint("CENTER", mini, "CENTER", dx / miniShrink, dy / miniShrink)
    local fade = MINI.Fade(dx, dy, last.half)
    if pin.fade ~= fade then
        pin.fade = fade
        pin:SetAlpha(fade)
    end
    return look
end

-- Indoors, the nearest MINI.INDOORS places in view, nearest first (kept in arrays: no table a frame).
local kept = { n = 0, key = {}, kind = {}, x = {}, y = {}, far = {}, second = {} }
function MINI.Keep(key, kind, dx, dy, far, second)
    local k, n = kept, kept.n
    if n == MINI.INDOORS and far >= k.far[n] then return end
    local at = n < MINI.INDOORS and n + 1 or n
    k.n = at
    while at > 1 and k.far[at - 1] > far do
        k.key[at], k.kind[at], k.x[at], k.y[at], k.far[at], k.second[at] =
            k.key[at - 1], k.kind[at - 1], k.x[at - 1], k.y[at - 1], k.far[at - 1], k.second[at - 1]
        at = at - 1
    end
    k.key[at], k.kind[at], k.x[at], k.y[at], k.far[at], k.second[at] = key, kind, dx, dy, far, second
end

local function Follow()
    -- Moved and turned less than would shift a symbol half a unit (UnitPosition, plain numbers,
    -- no table made), and zoom, shape, size and places the same: nothing to do.
    local wx, wy = UnitPosition("player")
    if issecretvalue(wx) or issecretvalue(wy) then wx, wy = nil, nil end
    local radius = C_Minimap.GetViewRadius()
    if issecretvalue(radius) then radius = nil end
    local facing = C_CVar.GetCVar("rotateMinimap") == "1" and GetPlayerFacing() or 0
    if issecretvalue(facing) then facing = nil end
    local quarters = Quarters()
    local zoom = Minimap:GetZoom()
    if issecretvalue(zoom) then zoom = nil end
    local map = C_Map.GetBestMapForUnit("player")
    if issecretvalue(map) then map = nil end
    local indoors = ns.db.collectCaveNearest == true and IsIndoors() == true
    local half = last.half
    if wx and last.wx and map and map == last.map and indoors == last.indoors and type(radius) == "number" and radius > 0 and radius == last.radius and version == last.version
        and quarters == last.quarters and zoom == last.zoom and half and half > 0 and Minimap:GetWidth() / 2 == half then
        local still = MINI.STILL * radius / half -- (in yards)
        local ex, ey = wx - last.wx, wy - last.wy
        local turned = facing ~= last.facing
        if turned and facing and last.facing then
            turned = abs((facing - last.facing + math.pi) % (2 * math.pi) - math.pi) * half >= MINI.STILL
        end
        if ex * ex + ey * ey < still * still and not turned then return end
    end
    last.wx, last.wy, last.radius, last.facing, last.version, last.quarters, last.zoom, last.map = wx, wy, radius, facing, version, quarters, zoom, map
    last.indoors = indoors
    miniUsed = 0
    local own, gm, x, y, width, height
    if type(map) == "number" then own, gm = Sources(map) end
    if own or gm then x, y, width, height = MapPosition(map) end
    if x and facing and not issecretvalue(radius) and type(radius) == "number" and radius > 0 then
        local half = Minimap:GetWidth() / 2
        last.half = half
        local square = not (quarters[1] or quarters[2] or quarters[3] or quarters[4])
        local crop = square and Crop() or 1
        -- In yards: as far as the edge, or a square's corners.
        local scale, reach = half / radius, radius * radius * ((quarters[1] and quarters[2] and quarters[3] and quarters[4]) and 1 or 2)
        local levels = Minimap:GetZoomLevels()
        miniShrink = type(zoom) == "number" and type(levels) == "number" and levels > 1 and Shrink(zoom / (levels - 1)) or 1
        -- A rotating minimap turns everything by your facing.
        local sin, cos = math.sin(facing), math.cos(facing)
        local look
        local info = MapInfo(map, own, gm)
        local common = info.common
        -- Areas at the minimap's two widest zooms; closer in, every spawn has its symbol (and
        -- indoors, where only the nearest show).
        local areas, inAreas
        if type(zoom) == "number" and zoom <= 1 and not indoors then areas, inAreas = info.areas, info.inAreas end
        kept.n = 0
        Near(nearMini, own, gm, x, y, width, height, reach, inAreas, common, info.spots)
        local keys, kindsOf, placesOf, seconds = nearMini.key, nearMini.kind, nearMini.place, nearMini.second
        for i = 1, nearMini.count do
            local key, kind, place = keys[i], kindsOf[i], placesOf[i]
            local east = (floor(place / PACK) / UNITS - x) * width
            local north = (y - place % PACK / UNITS) * height
            if east * east + north * north <= reach then
                local dx, dy = (east * cos + north * sin) * scale, (north * cos - east * sin) * scale
                if InShape(dx, dy, half, quarters, crop) then
                    if indoors then
                        MINI.Keep(key, kind, dx, dy, east * east + north * north, seconds[i] or nil)
                    else
                        look = MiniSymbol(key, kind, dx, dy, nil, look, seconds[i] or nil)
                    end
                end
            end
        end
        for j = 1, kept.n do look = MiniSymbol(kept.key[j], kept.kind[j], kept.x[j], kept.y[j], nil, look, kept.second[j]) end
        -- The areas' symbols in view, with their counts.
        for _, area in ipairs(areas or EMPTY) do
            if Shown(area.key, area.kind) and not (common and common[area.key]) then
                local east, north = (area.x / UNITS - x) * width, (y - area.y / UNITS) * height
                local dx, dy = (east * cos + north * sin) * scale, (north * cos - east * sin) * scale
                if InShape(dx, dy, half, quarters, crop) then look = MiniSymbol(area.key, area.kind, dx, dy, area.count, look) end
            end
        end
    end
    for i = miniUsed + 1, miniShown do minis[i]:Hide() end
    for i = miniShown + 1, miniUsed do minis[i]:Show() end
    miniShown = miniUsed
end

-- At most about 60 times a second: a faster frame rate skips frames (one a little short of
-- a 60th still counts, so 60 fps draws every frame).
local STEP = 1 / 60
local miniWait = 0
-- An error here would repeat every frame: reported once, then no minimap symbols until a reload.
local miniBroken = false
local function MiniUpdate(_, elapsed)
    miniWait = miniWait + (elapsed or STEP)
    if miniWait < STEP * 0.9 then return end
    miniWait = math.min(miniWait - STEP, STEP)
    if not xpcall(Follow, geterrorhandler()) then
        miniBroken = true
        mini:Hide()
    end
end

local function UpdateMinimap()
    version = version + 1
    local db = ns.db
    if mini then mini:SetShown(not miniBroken and (db.collect == true or db.collectSpawns == true or db.collectGatherMate == true) and db.collectMinimap == true) end
end

local function MakeMinimap()
    mini = New("Frame", Minimap)
    mini:SetPoint("TOPLEFT", MINI.DOT[1], MINI.DOT[2])
    mini:SetPoint("BOTTOMRIGHT", MINI.DOT[1], MINI.DOT[2])
    mini:SetScript("OnUpdate", MiniUpdate)
    -- A skill-up changes Skill colors; after a loading screen GatherMate2's places are read again.
    mini:RegisterEvent("SKILL_LINES_CHANGED")
    mini:RegisterEvent("PLAYER_ENTERING_WORLD")
    mini:RegisterEvent("MINIMAP_UPDATE_TRACKING")
    mini:SetScript("OnEvent", function(_, event)
        if event == "MINIMAP_UPDATE_TRACKING" then
            tracked = nil
            if ns.db.collectOnlyTracking then ns.RefreshNodePins() end
            return
        end
        if event == "PLAYER_ENTERING_WORLD" then
            wipe(gmPlaces)
            GatherMateIcons()
        end
        version = version + 1
        -- Where to farm, open: a skill-up changes what counts.
        if event == "SKILL_LINES_CHANGED" and ns.SparkleWindowShown() and ns.SparkleWindowPage() == "farm" then ns.RefreshSparkleWindow() end
    end)
end

-- An error here would repeat at every map change: reported once, then no pins until a reload.
local broken = false
local function Run(fn)
    if broken or not hooked then return end
    if not xpcall(fn, geterrorhandler()) then
        broken = true
        for _, pin in ipairs(pins) do pin:Hide() end
        for _, glow in ipairs(glows) do glow:Hide() end
        Regions.Layer(nil, 1)
    end
end
function ns.RefreshNodePins()
    UpdateMinimap()
    if Regions.button then Regions.button:Look() end
    if ns.CompassChanged then ns.CompassChanged() end
    Run(Refresh)
end
-- The same after GatherMate2's places or Collecting's own changed: GatherMate2's read again.
function ns.RereadNodePins()
    wipe(gmPlaces)
    wipe(mapInfo)
    GatherMateIcons()
    ns.RefreshNodePins()
end
local function Rescale()
    if mapAreas ~= nil and (MapAreas() ~= mapAreas or MapDots() ~= mapDots or Regions.Now() ~= Regions.shown) then
        Run(Refresh) -- (areas or a symbol each)
    elseif used > 0 then
        Run(Place)
    end
end

-- The mouse in a region of the world map: its tooltip. Regions take no mouse (the map keeps its
-- clicks), so this looks while the mouse is on the bare map.
local hover, hovered = nil, {} -- (the area, and where the mouse was)
local function AreaAt(u, v) -- (in units)
    for i = 1, glowsUsed do
        local area = glows[i].area
        if Regions.Inside(area, u, v) then return area end
    end
end
local function Hover()
    local x, y = WorldMapFrame:GetNormalizedCursorPosition()
    if x == hovered.x and y == hovered.y then return end
    hovered.x, hovered.y = x, y
    local area
    if glowsUsed > 0 and type(x) == "number" and type(y) == "number" and GetMouseFoci then
        local top = GetMouseFoci()[1]
        if top == WorldMapFrame.ScrollContainer or top == Canvas() then area = AreaAt(x * UNITS, y * UNITS) end
    end
    if area ~= hovered.area then
        hovered.area = area
        if area then
            NodeTooltip(hover, "ANCHOR_CURSOR", area.key, area)
        elseif GameTooltip:IsOwned(hover) then
            GameTooltip:Hide()
        end
    end
end
local function HoverGone()
    hovered.area, hovered.x, hovered.y = nil, nil, nil
    if GameTooltip:IsOwned(hover) then GameTooltip:Hide() end
end

-- A button on the world map like Blizzard's own at its top right (Blizzard_WorldMapTemplates'
-- tracking pin button, under theirs): this map's herb and ore symbols on or off.
function Regions.MapButton()
    local button = New("Button", WorldMapFrame)
    button:SetSize(32, 32)
    button:SetFrameStrata("HIGH")
    local back = button:CreateTexture(nil, "BACKGROUND")
    back:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    back:SetSize(25, 25)
    back:SetPoint("TOPLEFT", 3, -4)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexture("Interface\\AddOns\\NodeSight\\logo")
    button.icon:SetSize(20, 20)
    button.icon:SetPoint("TOPLEFT", 7, -6)
    local pressed = button:CreateTexture(nil, "OVERLAY")
    pressed:SetAllPoints(button.icon)
    pressed:SetColorTexture(0, 0, 0, 0.3)
    pressed:Hide()
    local border = button:CreateTexture(nil, "OVERLAY", nil, 1)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
    button:SetScript("OnMouseDown", function()
        button.icon:SetPoint("TOPLEFT", 8, -8)
        pressed:Show()
    end)
    button:SetScript("OnMouseUp", function()
        button.icon:SetPoint("TOPLEFT", 7, -6)
        pressed:Hide()
    end)
    local function Tip()
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:SetText("NodeSight")
        GameTooltip:AddLine(ns.db.collectMap and "Click to hide the herbs and ore on the map." or "Click to show the herbs and ore on the map.", 1, 1, 1)
        GameTooltip:Show()
    end
    button:SetScript("OnClick", function()
        ns.db.collectMap = not ns.db.collectMap
        PlaySound(ns.db.collectMap and SOUNDKIT.UI_MAP_WAYPOINT_BUTTON_CLICK_ON or SOUNDKIT.UI_MAP_WAYPOINT_BUTTON_CLICK_OFF)
        ns.RefreshNodePins()
        if ns.RefreshSparkleWindow then ns.RefreshSparkleWindow() end
        if GameTooltip:IsOwned(button) then Tip() end
    end)
    button:SetScript("OnEnter", Tip)
    button:SetScript("OnLeave", GameTooltip_Hide)
    -- Under Blizzard's buttons there (32 apart, from 2 down).
    local below = (WorldMapFrame.WorldMapTrackingOptionsButton and 1 or 0) + (WorldMapFrame.WorldMapTrackingPinButton and 1 or 0)
    local container = WorldMapFrame.GetCanvasContainer and WorldMapFrame:GetCanvasContainer() or WorldMapFrame.ScrollContainer
    button:SetPoint("TOPRIGHT", container, "TOPRIGHT", -4, -2 - 32 * below)
    -- Shown while Collecting marks anything and its setting is on; gray while the symbols are off.
    function button:Look()
        local db = ns.db
        self:SetShown(db.collectMapButton == true and (db.collect == true or db.collectSpawns == true or db.collectGatherMate == true))
        self.icon:SetDesaturated(not db.collectMap)
        self.icon:SetAlpha(db.collectMap and 1 or 0.6)
    end
    Regions.button = button
    button:Look()
end

-- Once Blizzard_WorldMap is loaded.
local function HookMap()
    if hooked or not Canvas() then return end
    hooked = true
    hover = New("Frame", WorldMapFrame)
    hover:SetScript("OnUpdate", function() Run(Hover) end)
    hover:SetScript("OnHide", HoverGone)
    -- An import in GatherMate2 sends no message, so its places are read again as the map opens;
    -- without it nothing changes unseen.
    WorldMapFrame:HookScript("OnShow", function()
        if ns.db.collectGatherMate then ns.RereadNodePins() else ns.RefreshNodePins() end
    end)
    Regions.MapButton()
    if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", ns.RefreshNodePins) end
    if WorldMapFrame.OnCanvasScaleChanged then hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", Rescale) end
    -- The map's own filter menu: herbs and ore (setup's lists), each with the ones on this map.
    if Menu and Menu.ModifyMenu then
        Menu.ModifyMenu("MENU_WORLD_MAP_TRACKING", function(_, root)
            local db = ns.db
            if not ((db.collect or db.collectSpawns or db.collectGatherMate) and db.collectMap) then return end
            local map = WorldMapFrame:GetMapID()
            local own, gm
            if not issecretvalue(map) and type(map) == "number" then own, gm = Sources(map) end
            local here = {}
            for source = 1, 2 do
                for key, places in pairs(source == 1 and own or source == 2 and gm or EMPTY) do
                    local kind = ns.NodeKind(key)
                    if type(places) == "table" and places[1] and (kind == "herbs" or kind == "ore") then here[NodeEntry(key, kind)] = true end
                end
            end
            local function Changed()
                ns.RefreshNodePins()
                ns.RefreshSparkleWindow()
            end
            root:CreateSpacer()
            root:CreateDivider()
            root:CreateSpacer()
            root:CreateTitle("Herbs and Ore:")
            for _, kind in ipairs({ "herbs", "ore" }) do
                local list = NODE_LIST[kind]
                local function AnyOn()
                    for _, entry in ipairs(list) do
                        if not db.collectHidden[entry] then return true end
                    end
                    return false
                end
                local box = root:CreateCheckbox(kind == "herbs" and "Herbs" or "Ore", AnyOn, function()
                    local on = not AnyOn()
                    for _, entry in ipairs(list) do db.collectHidden[entry] = not on or nil end
                    Changed()
                end)
                for _, entry in ipairs(list) do
                    if here[entry] then
                        box:CreateCheckbox(DisplayName(entry), function() return not db.collectHidden[entry] end, function()
                            db.collectHidden[entry] = not db.collectHidden[entry] or nil
                            Changed()
                        end)
                    end
                end
            end
            -- Bright: one herb or ore in full, the others faded.
            local function IsBright(entry) return (db.collectBright or false) == entry end -- (None: false)
            local function SetBright(entry)
                db.collectBright = entry or nil
                Changed()
            end
            local bright = root:CreateButton("Bright")
            bright:CreateRadio(NONE, IsBright, SetBright, false)
            for _, kind in ipairs({ "herbs", "ore" }) do
                for _, entry in ipairs(NODE_LIST[kind]) do
                    if here[entry] then bright:CreateRadio(DisplayName(entry), IsBright, SetBright, entry) end
                end
            end
        end)
    end
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
    ns.RereadNodePins()
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

ns.UpdateCollect, ns.NodeCount, ns.GatherMateLoaded = UpdateCollect, Count, GatherMateLoaded
-- For the compass (Compass.lua): the places and the symbols.
ns.Collecting = {
    Sources = Sources, MapPosition = MapPosition, NewNearList = NewNearList, Near = Near,
    NewSymbol = NewSymbol, ApplyShape = ApplyShape, ApplyLook = ApplyLook, CurrentLook = CurrentLook,
    Version = function() return version end, PACK = PACK, UNITS = UNITS,
    SkillColor = SkillColor, FarmZones = FarmZones, FARM_LEVELS = FARM_LEVELS, DisplayName = DisplayName,
    AreasIn = AreasIn, ShowCount = ShowCount, Regions = Regions,
    Shrink = Shrink, MiniShared = MINI.Shared, Common = Common, MiniFade = MINI.Fade, Spots = Spots,
}
ns.COLLECT_SHAPES, ns.COLLECT_SKILL_LOOKS = SHAPES, SKILL_LOOKS
ns.COLLECT_ZOOM_LOOKS = { "Symbols", false, false, "Hex tiles", "Mix rings", "One symbol a group", false, "Dots", "Regions" } -- (false: taken out, a saved one goes back to the default)
ns.COLLECT_MINI_LOOKS = { "Whole symbol", "Hole in the middle", "See-through middle", "Pin" }
ns.COLLECT_MINI_SHARED = { "The common one", "Split down the middle", "Second as a badge" }
ns.NODE_LIST, ns.NODE_NEEDS = NODE_LIST, NODE_NEEDS -- (setup's herbs and ore)
-- The sliders: low, high, step (the compass bar's too).
ns.COLLECT_RANGES = { collectSize = { 8, 24, 1 }, collectMiniSize = { 8, 40, 1 }, collectOpacity = { 10, 100, 5 }, collectRarePercent = { 0, 50, 5 }, compassWidth = { 200, 1000, 10 }, compassRange = { 50, 500, 25 }, nodeArrowRange = { 50, 1000, 25 }, nodeArrowSize = { 50, 200, 10 } }
