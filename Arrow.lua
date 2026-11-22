-- The next node arrow: Blizzard's waypoint arrow around the symbol of the nearest marked
-- herb or ore you can gather (Collecting's places and GatherMate2's), with the yards under
-- it. Once you are within 15 yards of a place it is skipped for two minutes and the arrow goes
-- on to the next. Nothing is worked out while you stand still and don't turn. While the
-- Collecting page is open it can be dragged.
--
-- Sections: Picking, Drawing, Moving, Settings.

local _, ns = ...

local floor, sqrt, sin, cos, atan2 = math.floor, math.sqrt, math.sin, math.cos, math.atan2

local SKIP_SECONDS = 120
local REACHED = 15 -- yards: you are at the place (skipped)
local SIZE = 64 -- the frame
local SYMBOL = 24
local ORBIT = 24 -- the arrow's distance from the symbol's middle
local ARROW_W, ARROW_H = 22 * 1.4, 18 * 1.4 -- Navigation-Tracked-Arrow, a bit bigger

local frame, arrow, symbol, text, hint
local list -- the places near you (Collect.lua's Near)
local skipped = {} -- [map][place] = when it may be picked again
local skipEnds -- the soonest of those (the arrow is worked out again then, standing still too)
local target -- { map, place, key, kind }
local stamp = 0 -- goes up when the target changes (the compass bar marks it)
local gatherable, gatherableFor = {}, nil -- by node key, for one version
local last = {}
local moving, broken = false, false

local function New(kind, parent)
    local made = CreateFrame(kind, nil, nil)
    made:SetParent(parent)
    return made
end

---------------------------------------------------------------------------
-- Picking
---------------------------------------------------------------------------

-- Your skill isn't too low for it, and you have the profession.
local function CanGather(key, kind, version)
    if gatherableFor ~= version then
        wipe(gatherable)
        gatherableFor = version
    end
    local can = gatherable[key]
    if can == nil then
        can = ns.HasProfession(kind) and ns.SkillLevel(key, kind) ~= 1
        gatherable[key] = can
    end
    return can
end

local function Skipped(map, place, now)
    local free = skipped[map] and skipped[map][place]
    return free ~= nil and free > now
end

local function Skip(map, place)
    local now = GetTime()
    local spots = skipped[map]
    if not spots then
        spots = {}
        skipped[map] = spots
    end
    for spot, at in pairs(spots) do
        if at <= now then spots[spot] = nil end
    end
    spots[place] = now + SKIP_SECONDS
end

-- The nearest place you can gather that isn't skipped: its list index and yards east and north.
-- A place you are at is skipped here.
local function Nearest(map, x, y, width, height, version, reach)
    local C = ns.Collecting
    local PACK, UNITS = C.PACK, C.UNITS
    local now = GetTime()
    local best, bestEast, bestNorth, bestDistance
    for i = 1, list.count do
        local place = list.place[i]
        if not Skipped(map, place, now) and CanGather(list.key[i], list.kind[i], version) then
            local east = (floor(place / PACK) / UNITS - x) * width
            local north = (y - place % PACK / UNITS) * height
            local distance = east * east + north * north
            if distance <= REACHED * REACHED then
                Skip(map, place)
            elseif distance <= reach and (not bestDistance or distance < bestDistance) then
                best, bestEast, bestNorth, bestDistance = i, east, north, distance
            end
        end
    end
    return best, bestEast, bestNorth
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------

local function Hide()
    if target then
        target = nil
        stamp = stamp + 1
    end
    if moving then
        -- (shown while it's being moved, pointing ahead)
        arrow:SetRotation(0)
        arrow:SetPoint("CENTER", frame, "CENTER", 0, ORBIT)
        symbol:Hide()
        text:SetText("")
        frame.art:Show()
    else
        frame.art:Hide()
    end
end

local function Draw()
    local facing = GetPlayerFacing()
    if issecretvalue(facing) or type(facing) ~= "number" then facing = nil end
    local wx, wy = UnitPosition("player")
    if issecretvalue(wx) or issecretvalue(wy) then wx, wy = nil, nil end
    local C = ns.Collecting
    local version = C.Version()
    local now = GetTime()
    if facing == last.facing and wx == last.wx and wy == last.wy and version == last.version and last.drawn
        and not (skipEnds and now >= skipEnds) then return end
    last.facing, last.wx, last.wy, last.version, last.drawn = facing, wx, wy, version, true
    if not facing then return Hide() end
    local map = C_Map.GetBestMapForUnit("player")
    local own, gm, x, y, width, height
    if not issecretvalue(map) and type(map) == "number" then own, gm = C.Sources(map) end
    if own or gm then x, y, width, height = C.MapPosition(map) end
    if not x then return Hide() end
    local reach = ns.db.nodeArrowRange * ns.db.nodeArrowRange -- (yards, set)
    C.Near(list, own, gm, x, y, width, height, reach)
    local i, east, north = Nearest(map, x, y, width, height, version, reach)
    skipEnds = nil
    for _, spots in pairs(skipped) do
        for _, at in pairs(spots) do
            if at > now and (not skipEnds or at < skipEnds) then skipEnds = at end
        end
    end
    if not i then return Hide() end
    local place, key = list.place[i], list.key[i]
    if not target or target.map ~= map or target.place ~= place then
        target = { map = map, place = place, key = key, kind = list.kind[i] }
        stamp = stamp + 1
    end
    if symbol.key ~= key or symbol.version ~= version then -- (a new place, look or skill level)
        local look = C.CurrentLook()
        look.size, look.alpha = SYMBOL, 1
        if symbol.shape ~= look.shape or symbol.size ~= look.size then C.ApplyShape(symbol, look) end
        C.ApplyLook(symbol, key, target.kind, look)
        symbol.key, symbol.version = key, version
    end
    local distance = sqrt(east * east + north * north)
    -- The arrow goes around the symbol, pointing the way (radians as GetPlayerFacing: left is +).
    local turn = atan2(-east, north) - facing
    arrow:SetRotation(turn)
    arrow:SetPoint("CENTER", frame, "CENTER", -sin(turn) * ORBIT, cos(turn) * ORBIT)
    text:SetFormattedText(IN_GAME_NAVIGATION_RANGE, floor(distance + 0.5))
    symbol:Show()
    frame.art:Show()
end

local function OnUpdate()
    if not xpcall(Draw, geterrorhandler()) then
        broken = true
        frame:Hide()
        target, stamp = nil, stamp + 1 -- (the compass's pointer goes too)
    end
end

local function Make()
    frame = New("Frame", UIParent)
    frame:SetFrameStrata("LOW")
    frame:SetSize(SIZE, SIZE)
    frame:SetClampedToScreen(true)
    frame.art = New("Frame", frame)
    frame.art:SetSize(SIZE, SIZE)
    frame.art:SetPoint("CENTER")
    symbol = ns.Collecting.NewSymbol(frame.art)
    symbol:SetPoint("CENTER")
    arrow = frame.art:CreateTexture(nil, "OVERLAY")
    arrow:SetAtlas("Navigation-Tracked-Arrow")
    arrow:SetSize(ARROW_W, ARROW_H)
    text = frame.art:CreateFontString(nil, "OVERLAY", "GameFontHighlight") -- (Blizzard's waypoint distance font)
    text:SetPoint("TOP", frame, "BOTTOM", 0, 2)
    hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOP", text, "BOTTOM", 0, -2)
    hint:SetText("Drag to move")
    hint:Hide()
    list = ns.Collecting.NewNearList()
    frame:SetScript("OnUpdate", OnUpdate)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Saved as its top from the screen's top middle.
        local x, top = self:GetCenter(), self:GetTop()
        local middle, screenTop = UIParent:GetCenter(), UIParent:GetTop()
        if x and top and middle and screenTop then
            ns.db.nodeArrowX, ns.db.nodeArrowY = floor(x - middle + 0.5), floor(top - screenTop + 0.5)
        end
        ns.ArrowChanged()
    end)
end

---------------------------------------------------------------------------
-- Moving
---------------------------------------------------------------------------

function ns.ArrowMovable(on)
    moving = on == true
    if not frame then return end
    frame:SetMovable(moving)
    frame:EnableMouse(moving)
    hint:SetShown(moving)
    last.drawn = nil
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------

function ns.ArrowChanged()
    local db = ns.db
    if not db.nodeArrow then
        if frame then frame:Hide() end
        if target then
            target = nil
            stamp = stamp + 1
        end
        return
    end
    if broken then return end
    if not frame then
        Make()
        ns.ArrowMovable(moving)
    end
    -- The size: the art scaled, the frame (what is dragged and placed) as big as it shows.
    local scale = db.nodeArrowSize / 100
    frame:SetSize(SIZE * scale, SIZE * scale)
    frame.art:SetScale(scale)
    frame:ClearAllPoints()
    frame:SetPoint("TOP", UIParent, "TOP", db.nodeArrowX, db.nodeArrowY)
    last.drawn = nil
    frame:Show()
end

-- The place the arrow points to (map, place), and a number that changes with it.
function ns.ArrowTarget()
    if target then return target.map, target.place, stamp end
    return nil, nil, stamp
end

-- At load, once the saved settings are in use.
function ns.Arrow()
    ns.ArrowChanged()
end
