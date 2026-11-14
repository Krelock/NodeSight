-- Collecting: where you gathered a herb or ore is remembered, and marked on the world
-- map. Nothing is sent to anyone or read from other players.
--
-- Saved account-wide in NodeSightDB.nodes: per map ID, per node (its English name in
-- lower case, ns.NodeKey), a list of places. A place is one number: x * 10000 + y,
-- with x and y in thousandths of the map (0 to 1000). A node gathered again at a
-- place already known adds nothing, so the list stops growing once a zone's spawn
-- points are known.
--
-- Sections: Places, Gathering, World map.

local _, ns = ...

local ipairs, pairs = ipairs, pairs
local floor, abs = math.floor, math.abs

---------------------------------------------------------------------------
-- Places
---------------------------------------------------------------------------

local UNITS = 1000 -- a map's width and height, in the units places are saved in
local PACK = 10000 -- x * PACK + y
local SAME = 4 -- places of one node this close (in units, each way) are the same spawn point

local function Say(text)
    DEFAULT_CHAT_FRAME:AddMessage(NORMAL_FONT_COLOR:WrapTextInColorCode("NodeSight") .. ": " .. text)
end

-- The saved places (NodeSightDB.nodes), made on first use. Anything else saved there is dropped.
local function Nodes()
    if type(NodeSightDB.nodes) ~= "table" then NodeSightDB.nodes = {} end
    return NodeSightDB.nodes
end

local function Unpack(place)
    return floor(place / PACK), place % PACK
end

-- How many places are saved.
local function Count()
    local count = 0
    for _, map in pairs(Nodes()) do
        if type(map) == "table" then
            for _, places in pairs(map) do
                if type(places) == "table" then count = count + #places end
            end
        end
    end
    return count
end

-- Where you stand: the map's ID and x, y in units; nil where the game gives no place
-- (dungeons and raids).
local function PlayerPlace()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local map = C_Map.GetBestMapForUnit("player")
    if issecretvalue(map) or type(map) ~= "number" then return nil end
    local position = C_Map.GetPlayerMapPosition(map, "player")
    if issecretvalue(position) or not position then return nil end
    local x, y = position:GetXY()
    if issecretvalue(x) or issecretvalue(y) or type(x) ~= "number" or type(y) ~= "number" then return nil end
    if x <= 0 and y <= 0 then return nil end -- (no place on this map)
    return map, floor(x * UNITS + 0.5), floor(y * UNITS + 0.5)
end

-- Remembers a node at a place; true if it was new.
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
-- A cast of yours whose target is a herb's or ore's name, then loot from a game
-- object: you gathered that node where you stand. (The loot check keeps out a spell
-- cast on a player or pet with a herb's name.)

local LOOT_WAIT = 3 -- seconds from the cast's end to its loot

local cast -- the gathering cast under way: { guid, key, kind }
local done -- the one that succeeded, waiting for its loot: { key, kind, map, x, y, at }

-- Does any loot in the window come from a game object?
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
    if not Remember(found.key, found.map, found.x, found.y) then return end
    ns.RefreshNodePins()
    -- The first one ever says what just happened, and where to turn it off.
    if not NodeSightDB.collectTold then
        NodeSightDB.collectTold = true
        Say("I'll remember where you gather herbs and ore, and mark the places on your world map. "
            .. "Nothing is shared. You can turn it off in NodeSight's settings, under Collecting.")
    end
end

local watch = CreateFrame("Frame")
watch:SetScript("OnEvent", function(_, event, _, a, b)
    if event == "LOOT_READY" then return Gathered() end
    if event == "UNIT_SPELLCAST_SENT" then
        cast = nil
        if issecretvalue(a) or issecretvalue(b) or type(a) ~= "string" or b == nil then return end
        local kind = ns.NodeKind(a)
        if kind == "herbs" or kind == "ore" then cast = { guid = b, key = ns.NodeKey(a), kind = kind } end
        return
    end
    if not cast or issecretvalue(a) or a ~= cast.guid then return end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local map, x, y = PlayerPlace()
        if map then done = { key = cast.key, kind = cast.kind, map = map, x = x, y = y, at = GetTime() } end
    end
    cast = nil -- (succeeded, failed or interrupted)
end)

-- The Collecting setting changed, or the settings were loaded.
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
-- A small icon on the world map for each place saved for the map it shows. The
-- icons are plain frames on the map's canvas; the mouse on one names its node.

local ICONS = { herbs = "Interface\\Icons\\INV_Misc_Flower_02", ore = "Interface\\Icons\\INV_Ore_Copper_01" }
local PIN_SIZE = 12
local PIN_LEVEL = 100 -- above the canvas, if the map gives no pin level of its own

local pins, used = {}, 0 -- the icons made so far, and how many of them show
local hooked = false

-- This client's name for a saved node, where its Locales file has one, with a capital first letter.
local localNames
local function DisplayName(key)
    if not localNames then
        localNames = {}
        for _, list in ipairs({ "HERBS", "ORE" }) do
            for name, english in pairs(ns.LOCALE and ns.LOCALE[list] or {}) do localNames[english] = name end
        end
    end
    return ((localNames[key] or key):gsub("^%l", string.upper))
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

local function Pin(canvas)
    used = used + 1
    local pin = pins[used]
    if not pin then
        pin = CreateFrame("Frame", nil, canvas)
        pin:SetSize(PIN_SIZE, PIN_SIZE)
        pin.icon = pin:CreateTexture(nil, "ARTWORK")
        pin.icon:SetAllPoints()
        pin.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- (without the icon's border)
        -- The mouse over it shows the name; clicks go through to the map.
        if pin.SetMouseMotionEnabled and pin.SetMouseClickEnabled then
            pin:SetMouseMotionEnabled(true)
            pin:SetMouseClickEnabled(false)
            pin:SetScript("OnEnter", PinEnter)
            pin:SetScript("OnLeave", PinLeave)
        end
        pins[used] = pin
    end
    return pin
end

-- The pins' frame level: the map's own level for points of interest, where it has one.
local function PinLevel(canvas)
    local manager = WorldMapFrame.GetPinFrameLevelsManager and WorldMapFrame:GetPinFrameLevelsManager()
    if manager and manager.GetValidFrameLevel then
        local ok, level = pcall(manager.GetValidFrameLevel, manager, "PIN_FRAME_LEVEL_AREA_POI")
        if ok and type(level) == "number" then return level end
    end
    return canvas:GetFrameLevel() + PIN_LEVEL
end

-- Shows the pins of the map the world map is on (none if the setting is off).
local function Refresh()
    used = 0
    local canvas = Canvas()
    if canvas and WorldMapFrame:IsShown() and ns.db.collect and ns.db.collectMap then
        local map = WorldMapFrame:GetMapID()
        local nodes = not issecretvalue(map) and map and Nodes()[map]
        if type(nodes) == "table" then
            local width, height = canvas:GetSize()
            -- The canvas grows as the map zooms in: the pins keep their size on screen.
            local scale = canvas:GetScale()
            scale = scale and scale > 0 and 1 / scale or 1
            local level = PinLevel(canvas)
            for key, places in pairs(nodes) do
                local icon = ICONS[ns.NodeKind(key)]
                if icon and type(places) == "table" then
                    for _, place in ipairs(places) do
                        local x, y = Unpack(place)
                        local pin = Pin(canvas)
                        pin.key = key
                        pin.icon:SetTexture(icon)
                        pin:SetScale(scale)
                        pin:SetFrameLevel(level)
                        pin:ClearAllPoints()
                        pin:SetPoint("CENTER", canvas, "TOPLEFT", x / UNITS * width / scale, -y / UNITS * height / scale)
                        pin:Show()
                    end
                end
            end
        end
    end
    for i = used + 1, #pins do pins[i]:Hide() end
end

-- An error in it would repeat at every map change: reported once, and the pins stay off until the next reload.
local broken = false
function ns.RefreshNodePins()
    if broken or not hooked then return end
    if not xpcall(Refresh, geterrorhandler()) then
        broken = true
        for _, pin in ipairs(pins) do pin:Hide() end
    end
end

-- The world map is there (Blizzard_WorldMap is loaded): follow what it shows.
local function HookMap()
    if hooked or not Canvas() then return end
    hooked = true
    WorldMapFrame:HookScript("OnShow", ns.RefreshNodePins)
    if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", ns.RefreshNodePins) end
    if WorldMapFrame.OnCanvasScaleChanged then hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", ns.RefreshNodePins) end
    ns.RefreshNodePins()
end

-- At load, once the saved settings are in use.
function ns.Collect()
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

-- Forgets every saved place; returns how many there were.
function ns.ForgetNodes()
    local count = Count()
    NodeSightDB.nodes = {}
    ns.RefreshNodePins()
    return count
end

-- What the other files use of this one.
ns.UpdateCollect, ns.NodeCount, ns.CollectSay = UpdateCollect, Count, Say
