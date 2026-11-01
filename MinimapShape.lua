-- NodeSight's minimap shape: round, square or mixed.
-- Offsets are from the middle, x right, y up.

local _, ns = ...

-- Round (true) or square (false) per quarter: 1 bottom right, 2 bottom left,
-- 3 top right, 4 top left. Table and numbering from LibDBIcon-1.0.
local minimapShapes = {
    ["ROUND"] = {true, true, true, true},
    ["SQUARE"] = {false, false, false, false},
    ["CORNER-TOPLEFT"] = {false, false, false, true},
    ["CORNER-TOPRIGHT"] = {false, false, true, false},
    ["CORNER-BOTTOMLEFT"] = {false, true, false, false},
    ["CORNER-BOTTOMRIGHT"] = {true, false, false, false},
    ["SIDE-LEFT"] = {false, true, false, true},
    ["SIDE-RIGHT"] = {true, false, true, false},
    ["SIDE-TOP"] = {false, false, true, true},
    ["SIDE-BOTTOM"] = {true, true, false, false},
    ["TRICORNER-TOPLEFT"] = {false, true, true, true},
    ["TRICORNER-TOPRIGHT"] = {true, false, true, true},
    ["TRICORNER-BOTTOMLEFT"] = {true, true, false, true},
    ["TRICORNER-BOTTOMRIGHT"] = {true, true, true, false},
}

-- The shape GetMinimapShape() names. Round without an answer.
function ns.MinimapQuarters()
    if not GetMinimapShape then return minimapShapes.ROUND end
    local ok, shape = pcall(GetMinimapShape)
    return ok and minimapShapes[shape] or minimapShapes.ROUND
end

-- Whether an offset is inside a minimap of this half width.
function ns.InShape(dx, dy, half, quarters)
    local q = 1 + (dx < 0 and 1 or 0) + (dy > 0 and 2 or 0)
    if quarters[q] then return dx * dx + dy * dy <= half * half end
    return math.abs(dx) <= half and math.abs(dy) <= half
end

-- How far it is from (px, py) along (dx, dy) to the rim; nil from outside.
-- (dx, dy) must be one of the four unit axis vectors.
function ns.RimDistance(px, py, dx, dy, rim, quarters)
    if not ns.InShape(px, py, rim, quarters) then return nil end
    -- The quarter the ray ends in: the ray's side on its axis, the point's on the other.
    local ex, ey = dx ~= 0 and dx or px, dy ~= 0 and dy or py
    local q = 1 + (ex < 0 and 1 or 0) + (ey > 0 and 2 or 0)
    local along = px * dx + py * dy
    if quarters[q] then return math.sqrt(math.max(0, along * along - (px * px + py * py - rim * rim))) - along end
    return rim - along
end
