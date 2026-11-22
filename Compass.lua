-- The compass bar: a strip at the top of the screen with N, E, S and W, and a symbol for
-- each remembered herb and ore within range (Collecting's places and GatherMate2's), in
-- the direction it lies. Nearer ones are brighter, and the next node arrow's place has
-- Blizzard's waypoint arrow over it. Nothing is worked out while you stand still and
-- don't turn. While the Collecting page is open it can be dragged.
--
-- Sections: Drawing, Moving, Settings.

local _, ns = ...

local floor, abs, atan2, pi = math.floor, math.abs, math.atan2, math.pi

local HEIGHT = 26
local SYMBOL = 16 -- the symbols' size on the bar
local SPAN = pi -- the bar shows this much of the way around (half to each side)
local EDGE = 40 -- marks fade out over this many pixels at the ends
local FAR_ALPHA = 0.35 -- a symbol at the range's edge; one where you stand is solid
local DARK = { 0.106, 0.090, 0.071 } -- #1B1712
local GOLD = { 1, 0.82, 0 }
-- Letters at the four points, ticks between (radians: 0 north, west at a quarter turn).
local MARKS = { { 0, "N" }, { pi / 4 }, { pi / 2, "W" }, { 3 * pi / 4 }, { pi, "S" }, { 5 * pi / 4 }, { 3 * pi / 2, "E" }, { 7 * pi / 4 } }

local bar, art, hint, pointer
local marks, pins, shown = {}, {}, 0
local list -- the places near you (Collect.lua's Near)
local last = {}
-- The places in range from the last full look: bearing and distance each. Turning only moves
-- their marks; they're looked at again once you've moved far enough to shift the nearest one's
-- mark STILL pixels, or anything else changed.
local STILL = 0.5
local seen = { n = 0, nearest = 1, key = {}, kind = {}, bearing = {}, distance = {} }
local moving = false
local broken = false

-- Frames are made with no parent, then SetParent (the gamepad UI hooks CreateFrame).
local function New(kind, parent)
    local frame = CreateFrame(kind, nil, nil)
    frame:SetParent(parent)
    return frame
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------

-- Pixels from the bar's middle for a direction (radians, as GetPlayerFacing gives them);
-- nil when it is behind the part shown.
local function Offset(direction, facing, half)
    local turn = (direction - facing + pi) % (2 * pi) - pi
    if abs(turn) > SPAN / 2 then return nil end
    return -turn / (SPAN / 2) * half
end

-- Fades a mark out toward the bar's ends.
local function EdgeAlpha(x, half)
    return math.max(0, math.min(1, (half - abs(x)) / EDGE))
end

local function Draw()
    local facing = GetPlayerFacing()
    if issecretvalue(facing) or type(facing) ~= "number" then facing = nil end
    local wx, wy = UnitPosition("player")
    if issecretvalue(wx) or issecretvalue(wy) then wx, wy = nil, nil end
    local C = ns.Collecting
    local version = C.Version()
    local targetMap, targetPlace, stamp = ns.ArrowTarget()
    if facing == last.facing and wx == last.wx and wy == last.wy and version == last.version and stamp == last.stamp and last.drawn then return end
    last.facing, last.wx, last.wy, last.version, last.stamp, last.drawn = facing, wx, wy, version, stamp, true
    if not facing then
        if not moving then
            art:Hide()
            return
        end
        facing = 0 -- (shown while it's being moved)
    end
    art:Show()
    local half = bar:GetWidth() / 2
    for i, mark in ipairs(MARKS) do
        local x = Offset(mark[1], facing, half)
        local region = marks[i]
        if x and abs(x) < half then
            region:SetPoint("CENTER", art, "CENTER", x, 0)
            region:SetAlpha(EdgeAlpha(x, half))
            region:Show()
        else
            region:Hide()
        end
    end
    -- The places in range.
    local used = 0
    local pointAt
    local map = C_Map.GetBestMapForUnit("player")
    local own, gm, x, y, width, height
    if not issecretvalue(map) and type(map) == "number" then own, gm = C.Sources(map) end
    if own or gm then x, y, width, height = C.MapPosition(map) end
    if x then
        local range = ns.db.compassRange
        local still = STILL * seen.nearest / (half / (SPAN / 2)) -- (yards)
        if seen.map ~= map or seen.version ~= version or seen.stamp ~= stamp or seen.range ~= range or seen.width ~= width
            or seen.height ~= height or ((x - seen.x) * width) ^ 2 + ((y - seen.y) * height) ^ 2 >= still * still then
            local reach = range * range
            C.Near(list, own, gm, x, y, width, height, reach)
            local PACK, UNITS = C.PACK, C.UNITS
            local n, nearest = 0, range
            for i = 1, list.count do
                local place = list.place[i]
                local east = (floor(place / PACK) / UNITS - x) * width
                local north = (y - place % PACK / UNITS) * height
                local distance = east * east + north * north
                if distance <= reach then
                    n = n + 1
                    distance = math.sqrt(distance)
                    seen.key[n], seen.kind[n], seen.bearing[n], seen.distance[n] = list.key[i], list.kind[i], atan2(-east, north), distance
                    if distance < nearest then nearest = distance end
                end
            end
            -- The arrow's place, at any distance.
            seen.target = nil
            if targetMap == map then
                local east = (floor(targetPlace / PACK) / UNITS - x) * width
                local north = (y - targetPlace % PACK / UNITS) * height
                seen.target = atan2(-east, north)
            end
            seen.n, seen.nearest, seen.x, seen.y, seen.map, seen.version, seen.stamp = n, math.max(nearest, 1), x, y, map, version, stamp
            seen.range, seen.width, seen.height = range, width, height
        end
        local look
        for i = 1, seen.n do
            local key, kind, distance = seen.key[i], seen.kind[i], seen.distance[i]
            do
                local at = Offset(seen.bearing[i], facing, half)
                if at and abs(at) < half then
                    used = used + 1
                    local pin = pins[used] or C.NewSymbol(art)
                    pins[used] = pin
                    if pin.key ~= key or pin.version ~= version then
                        if not look then
                            look = C.CurrentLook()
                            look.size, look.alpha = SYMBOL, 1
                        end
                        pin.key, pin.version = key, version
                        if pin.shape ~= look.shape or pin.size ~= look.size then C.ApplyShape(pin, look) end
                        C.ApplyLook(pin, key, kind, look)
                    end
                    local alpha = (1 - (1 - FAR_ALPHA) * distance / range) * EdgeAlpha(at, half)
                    if pin.barAlpha ~= alpha then
                        pin.barAlpha = alpha
                        pin:SetAlpha(alpha)
                    end
                    pin:SetPoint("CENTER", art, "CENTER", at, 0)
                end
            end
        end
        if seen.target then
            pointAt = Offset(seen.target, facing, half)
            if pointAt and abs(pointAt) >= half then pointAt = nil end
        end
    end
    if pointAt then
        pointer:SetPoint("BOTTOM", art, "TOP", pointAt, -2)
        pointer:Show()
    else
        pointer:Hide()
    end
    for i = used + 1, shown do pins[i]:Hide() end
    for i = shown + 1, used do pins[i]:Show() end
    shown = used
end

-- At most about 60 times a second, as the minimap's symbols.
local STEP, wait = 1 / 60, 0
-- An error here would repeat every frame: reported once, then no compass until a reload.
local function OnUpdate(_, elapsed)
    wait = wait + (elapsed or STEP)
    if wait < STEP * 0.9 then return end
    wait = math.min(wait - STEP, STEP)
    if not xpcall(Draw, geterrorhandler()) then
        broken = true
        bar:Hide()
    end
end

-- A strip of color that fades out toward both ends: two halves, each a gradient.
local function Fade(parent, color, alpha, layer, top, bottom)
    for side = 1, 2 do
        local half = parent:CreateTexture(nil, layer)
        half:SetColorTexture(1, 1, 1, 1)
        local outer, inner = CreateColor(color[1], color[2], color[3], 0), CreateColor(color[1], color[2], color[3], alpha)
        if side == 1 then
            half:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, top)
            half:SetPoint("BOTTOMRIGHT", parent, "BOTTOM", 0, bottom)
            half:SetGradient("HORIZONTAL", outer, inner)
        else
            half:SetPoint("TOPLEFT", parent, "TOP", 0, top)
            half:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, bottom)
            half:SetGradient("HORIZONTAL", inner, outer)
        end
    end
end

local function Make()
    bar = New("Frame", UIParent)
    bar:SetFrameStrata("LOW")
    bar:SetHeight(HEIGHT)
    bar:SetClampedToScreen(true)
    art = New("Frame", bar)
    art:SetAllPoints()
    Fade(art, DARK, 0.8, "BACKGROUND", 0, 0)
    Fade(art, GOLD, 0.6, "BORDER", 0, HEIGHT - 1) -- (a gold line along the top
    Fade(art, GOLD, 0.6, "BORDER", 1 - HEIGHT, 0) -- and the bottom)
    local middle = art:CreateTexture(nil, "OVERLAY")
    middle:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.9)
    middle:SetSize(2, 7)
    middle:SetPoint("TOP", art, "TOP", 0, -1)
    for i, mark in ipairs(MARKS) do
        local region
        if mark[2] then
            region = art:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            region:SetText(mark[2])
        else
            region = art:CreateTexture(nil, "ARTWORK")
            region:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.5)
            region:SetSize(1, 6)
        end
        marks[i] = region
    end
    pointer = art:CreateTexture(nil, "OVERLAY")
    pointer:SetAtlas("Navigation-Tracked-Arrow")
    pointer:SetSize(18, 15)
    pointer:SetRotation(pi) -- (pointing down at the place)
    pointer:Hide()
    hint = bar:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOP", bar, "BOTTOM", 0, -2)
    hint:SetText("Drag to move")
    hint:Hide()
    list = ns.Collecting.NewNearList()
    bar:SetScript("OnUpdate", OnUpdate)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function(self) self:StartMoving() end)
    bar:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Saved as the bar's top from the screen's top middle.
        local x, top = self:GetCenter(), self:GetTop()
        local middle, screenTop = UIParent:GetCenter(), UIParent:GetTop()
        if x and top and middle and screenTop then
            ns.db.compassX, ns.db.compassY = floor(x - middle + 0.5), floor(top - screenTop + 0.5)
        end
        ns.CompassChanged()
    end)
end

---------------------------------------------------------------------------
-- Moving
---------------------------------------------------------------------------

-- While NodeSight's settings window is open the bar takes the mouse and can be dragged;
-- otherwise clicks go through it.
function ns.CompassMovable(on)
    moving = on == true
    if not bar then return end
    bar:SetMovable(moving)
    bar:EnableMouse(moving)
    hint:SetShown(moving)
    last.drawn = nil
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------

function ns.CompassChanged()
    local db = ns.db
    if not db.compass then
        if bar then bar:Hide() end
        return
    end
    if broken then return end
    if not bar then
        Make()
        ns.CompassMovable(moving)
    end
    bar:SetWidth(db.compassWidth)
    bar:ClearAllPoints()
    bar:SetPoint("TOP", UIParent, "TOP", db.compassX, db.compassY)
    last.drawn = nil
    bar:Show()
end

-- At load, once the saved settings are in use.
function ns.Compass()
    ns.CompassChanged()
end
