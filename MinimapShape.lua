-- NodeSight's minimap shape: round, square or mixed, maybe cropped at the top and bottom.
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
-- EllesmereUI's shape names; any other is round.
local ellesmereShapes = {
    circle = minimapShapes.ROUND,
    textured_circle = minimapShapes.ROUND,
    square = minimapShapes.SQUARE,
    rectangular = minimapShapes.SQUARE, -- 4:3: a square cut off at the top and bottom
}

-- The shape EllesmereUI's minimap renders; nil without its minimap or for a shape we don't know.
local function EllesmereRendered()
    local module = type(EllesmereUI) == "table" and type(EllesmereUI._ModuleNS) == "table"
        and EllesmereUI._ModuleNS.EllesmereUIMinimap
    if type(module) ~= "table" or type(module.MinimapShape) ~= "function" then return nil end
    local ok, shape = pcall(module.MinimapShape)
    return ok and ellesmereShapes[shape] or nil
end

-- The shape Automatic finds: EllesmereUI's, else GetMinimapShape's, round without an answer.
-- EllesmereUI comes first: its minimap replaces the stock one.
local function Detected()
    local rendered = EllesmereRendered()
    if rendered then return rendered end
    if not GetMinimapShape then return minimapShapes.ROUND end
    local ok, shape = pcall(GetMinimapShape)
    return ok and minimapShapes[shape] or minimapShapes.ROUND
end

-- The setting's shape, or on Automatic the one it finds.
local function Uncropped()
    local forced = ns.db.minimapShape
    if forced == 2 then return minimapShapes.ROUND end
    if forced == 3 then return minimapShapes.SQUARE end
    return Detected()
end

-- How high a cropped square reaches, as a share of the half width: the hit rect's insets,
-- only with both top and bottom set, the larger one on both sides. nil without a crop.
local function CropHeight()
    local ok, _, _, top, bottom = pcall(Minimap.GetHitRectInsets, Minimap)
    if not ok or type(top) ~= "number" or type(bottom) ~= "number"
        or issecretvalue(top) or issecretvalue(bottom) then return nil end
    local width = Minimap:GetWidth()
    if not (top > 0 and bottom > 0 and width > 0) then return nil end -- also catches NaN
    local height = math.max(0, math.min(1, 1 - 2 * math.max(top, bottom) / width))
    return math.floor(height * 1000 + 0.5) / 1000
end

local cropped = {} -- the cropped square, one table per height, so the scan keeps its grid

-- The quarters for the current shape and crop. Only a fully square map is cropped.
function ns.MinimapQuarters()
    local quarters = Uncropped()
    if quarters[1] or quarters[2] or quarters[3] or quarters[4] then return quarters end
    local height = CropHeight()
    if not height then return quarters end
    cropped[height] = cropped[height] or {false, false, false, false, height = height}
    return cropped[height]
end

-- Whether an offset is inside a minimap of this half width.
function ns.InShape(dx, dy, half, quarters)
    local q = 1 + (dx < 0 and 1 or 0) + (dy > 0 and 2 or 0)
    if quarters[q] then return dx * dx + dy * dy <= half * half end
    return math.abs(dx) <= half and math.abs(dy) <= half * (quarters.height or 1)
end

ns.MAP_SHAPES = { "Automatic", "Round", "Square" } -- the Minimap shape setting's choices

-- The setting's choice labels, Automatic with what it finds in brackets: Round, Square or Mixed.
function ns.MapShapeChoices()
    local found = Detected()
    local name = found == minimapShapes.ROUND and "Round" or found == minimapShapes.SQUARE and "Square" or "Mixed"
    return { ("%s (%s)"):format(ns.MAP_SHAPES[1], name), ns.MAP_SHAPES[2], ns.MAP_SHAPES[3] }
end
