-- This needs a lot more work. It was just thrown together quickly to get it
-- working, as a proof of concept.
--
-- NodeSight's sparkles on far away herbs and ore (Beta). The map pin is put on
-- a herb the scan found, and the sparkles go on the marker the game draws for
-- it in the world (In-Game Navigation).
--
-- In order: the world table, its functions, world.Update (every frame), world.Changed.

local _, ns = ...

local ipairs = ipairs

local hidden = ns.hidden
local ApplyColor, NewSparkle, NewSparkles = ns.ApplyColor, ns.NewSparkle, ns.NewSparkles
local Clean, MapPosition, PlayerFacing = ns.Clean, ns.MapPosition, ns.PlayerFacing
local UpdateScanner, Markers = ns.UpdateScanner, ns.Markers

---------------------------------------------------------------------------
-- Far sparkles
---------------------------------------------------------------------------
-- Costs more CPU than the rest. While on, it takes over your map pin and
-- tracked quest (restored when nothing is marked or a fight starts). Nothing
-- changes in combat or with the world map open (the map would build its pin
-- frame under our taint).
--
-- A pin has no height and the marker is drawn at your height, so the sparkles
-- are a column up or down from it, by the minimap's arrow (world.Level) or by
-- the game hiding the marker underground.
--
-- Up to four more herbs get sparkles too, placed using the camera angle that
-- puts the marker where it is on screen (world.Project, world.Camera):
--     depth = far * cos(side) * cos(down) + zoom + pivot * sin(down)
--     X = far * sin(side) / depth
--     Y = (far * cos(side) * sin(down) - pivot * cos(down)) / depth
-- (far: yards away; side: radians right of the view; down: camera pitch; zoom:
-- camera distance; pivot: its height above your feet; X, Y in focal lengths.)
-- The focal length and pivot height are measured by briefly moving the pin
-- (world.Hop, world.Fit) and saved in NodeSightDB.cam.
local world = ns.world

-- The look a marker's kind sparkles with: herbs', ore's, chests', or other objects'.
local function LookOf(kind)
    if kind == "herbs" or kind == "ore" or kind == "chests" or kind == "others" then return kind end -- already a look
    return kind == "treasure" and "chests" or "others"
end

-- Starts ten sparkles in a frame, in the kind's color and size.
function world.Fill(frame, kind)
    frame.kind = LookOf(kind)
    local parts, one, two = frame.parts, ns.SparkleColors(frame.kind)
    for i = 1, 10 do
        local part = parts[i]
        if not part then
            part = NewSparkle(frame)
            parts[i] = part
        end
        ApplyColor(part, i % 2 == 0 and two or one)
        part.texture:Show()
        part.core:Show()
        if not part.group:IsPlaying() then part.group:Play() end
        if not part.coreGroup:IsPlaying() then part.coreGroup:Play() end
    end
    frame:Show()
end

-- Can it be marked, and is it the marked one? Kept until 12 yards; new ones from 16.
function world.Can(marker)
    if marker.hard or marker.dim or marker.kind == "rares" or not marker.map or not marker.yards then return false end
    local at = world.at
    local marked = at and at.map == marker.map and (at.mx - marker.mx) ^ 2 + (at.my - marker.my) ^ 2 <= 2.5e-7 or false
    return marker.yards >= (marked and 12 or 16), marked
end

-- Angle between it and your facing (0 to pi).
function world.Off(marker, facing)
    return math.abs((marker.world + facing + math.pi) % (2 * math.pi) - math.pi)
end

-- Marks the nearest node within 15 degrees of your facing; the current one is
-- kept unless another is 5+ yards nearer.
function world.Pick()
    local facing = PlayerFacing()
    local least, kept
    for _, marker in ipairs(Markers()) do -- (nearest first)
        local can, marked = world.Can(marker)
        if can then
            if not facing or not marker.world then return marker end
            local off = world.Off(marker, facing)
            if not least or off < least then least = off end
            if marked and not kept then kept = marker end
        end
    end
    if not least then return nil end
    if kept and GetTime() - (world.taken or 0) < 0.5 then return kept end
    local keep = kept and world.Off(kept, facing) <= least + 0.26
    for _, marker in ipairs(Markers()) do
        if world.Can(marker) and world.Off(marker, facing) <= least + 0.26 then
            if keep and kept.yards - marker.yards <= 5 then return kept end
            return marker
        end
    end
end

-- Above or below you? Read from the arrow the minimap tooltip shows before the
-- name (Minimap-PositionArrows). Which half means "up" is a guess;
-- NodeSightDB.arrowsFlipped = true reverses it.
function world.Level(marker)
    local left, bottom = Minimap:GetLeft(), Minimap:GetBottom()
    if marker.far or not (left and bottom and Minimap:IsVisible()) or InCombatLockdown() then return world.level end
    local scale = Minimap:GetEffectiveScale()
    Minimap:SetUsingSoftCursor(true)
    local ok, data = pcall(function()
        Minimap:UpdateMouseoverAtPoint((left + marker.x) * scale, (bottom + marker.y) * scale)
        return C_TooltipInfo.GetMinimapMouseover()
    end)
    Minimap:SetUsingSoftCursor(false)
    if not ok then error(data, 0) end -- after letting go of the pretend mouse
    local lines = data and not issecretvalue(data) and data.lines
    if not lines or issecretvalue(lines) then return world.level end
    for _, line in ipairs(lines) do
        local text = line.leftText
        if text and not issecretvalue(text) then
            for row in text:gmatch("[^\n]+") do
                if Clean(row) == marker.name then
                    local top = row:match("PositionArrows[%d:]-:(%d+):%d+|t") -- 0 or 16
                    if not top then return "level" end
                    return ((top == "0") ~= (ns.db.arrowsFlipped == true)) and "up" or "down"
                end
            end
        end
    end
    return world.level
end

-- Puts the map pin on the spot and tracks it.
function world.Set(at)
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(at.map, at.mx, at.my))
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
end

-- Restores your own pin and tracked quest.
function world.Back()
    if world.pin then C_Map.SetUserWaypoint(world.pin) else C_Map.ClearUserWaypoint() end
    C_SuperTrack.SetSuperTrackedUserWaypoint(false)
    if world.quest and world.quest ~= 0 then C_SuperTrack.SetSuperTrackedQuestID(world.quest) end
    world.at, world.pin, world.quest = nil, nil, nil
end

-- Combat starts: remove the pin now, since nothing can change during the fight.
function world.Fight()
    world.fight = true
    if world.at and not (WorldMapFrame and WorldMapFrame:IsShown()) then world.Back() end
end

-- Debug readout, only with NodeSightDB.worldReadout = true (set by hand).
function world.Say(target)
    local now = GetTime()
    if world.said and now - world.said < 0.25 then return end
    world.said = now
    local at = world.at
    if not at then
        if world.text then world.text:SetText("") end
        return
    end
    if not world.text then
        local holder = CreateFrame("Frame")
        holder:SetParent(UIParent)
        holder:SetSize(10, 10)
        holder:SetPoint("TOP", UIParent, "TOP", 0, -240)
        world.text = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        world.text:SetPoint("TOP", holder, "TOP", 0, 0)
    end
    local state = C_Navigation.GetTargetState()
    local camera = world.hop and "measuring" or "not worked out"
    if world.side and not world.hop then
        local focal, pivot, riding = world.Lens()
        camera = ("%.0f deg, pivot %.1f, %.0f deg down, measured %d of 3%s%s%s"):format(math.deg(2 * math.atan(UIParent:GetHeight() / 2 / focal)),
            pivot, math.deg(world.down), #world.fits[riding], #world.fits[riding] < 3 and world.fails < 8 and ", stand still for more" or "",
            world.fit and " (last: " .. world.fit .. ")" or "",
            world.fails > 0 and (", %d tries gave nothing%s"):format(world.fails, world.fails >= 8 and ": left at that" or "") or "")
    end
    world.text:SetText(("NodeSight test: %s %s   arrow: %s   marker: %s (%s)   sparkles: %s   others: %d   camera: %s%s"):format(
        target and target.name or "?", target and target.yards and ("%.0f yd"):format(target.yards) or "",
        world.level or "not asked", state == 1 and "hidden" or "in view", tostring(state), world.shape or "none", world.shown or 0, camera,
        world.detail and "\nlast try: " .. world.detail or ""))
end

-- A spot's place on screen in focal lengths (see the top); nil behind the camera.
function world.Project(far, side, down, zoom, pivot)
    local ahead = far * math.cos(side)
    local depth = ahead * math.cos(down) + zoom + pivot * math.sin(down)
    if depth < 1 then return nil end
    return far * math.sin(side) / depth, (ahead * math.sin(down) - pivot * math.cos(down)) / depth
end

-- The reverse: camera side and down angles that put the marked node at X, Y.
function world.Camera(X, Y, far, zoom, pivot)
    local side, down = 0, 0
    for _ = 1, 8 do
        local ahead = far * math.cos(side)
        local a, b = ahead - Y * pivot, pivot + Y * ahead
        local sine = Y * zoom / math.sqrt(a * a + b * b)
        if not (sine >= -1 and sine <= 1) then return nil end
        down = math.atan2(b, a) + math.asin(sine)
        local c = X * math.cos(down)
        sine = X * (zoom + pivot * math.sin(down)) / (far * math.sqrt(1 + c * c))
        if not (sine >= -1 and sine <= 1) then return nil end
        side = math.atan2(c, 1) + math.asin(sine)
    end
    return side, down
end

-- The marker's screen position (UIParent units from the center), read from a
-- 1x1 frame anchored to it; nil if unreadable.
function world.Where(nav)
    local probe = world.probe
    if not probe then
        probe = CreateFrame("Frame")
        probe:SetParent(UIParent)
        probe:SetSize(1, 1)
        world.probe = probe
    end
    if world.probed ~= nav then
        probe:ClearAllPoints()
        if not pcall(probe.SetPoint, probe, "CENTER", nav, "CENTER", 0, 0) then return nil end
        world.probed = nav
    end
    local x, y = probe:GetCenter()
    if issecretvalue(x) or issecretvalue(y) or not x or not y then return nil end
    return x - UIParent:GetWidth() / 2, y - UIParent:GetHeight() / 2
end

-- Focal length, pivot height and whether you're mounted: measured, or guessed.
function world.Lens()
    local cvar = C_CVar.GetCVar("cameraFov")
    if world.cvar ~= cvar or not world.fits then world.cvar, world.fits, world.fit, world.fails, world.wait = cvar, { [true] = {}, [false] = {} }, nil, 0, 0.3 end
    local cam = ns.db.cam
    if cam and cam.cvar ~= cvar then cam = nil end
    local riding = IsMounted() and true or false
    local lens = cam and cam.lens or 0.5 / math.tan(math.rad((tonumber(cvar) or 90) * 0.6) / 2)
    local pivot = cam and (riding and cam.ride or not riding and cam.pivot) or (riding and 3 or 2)
    return lens * UIParent:GetHeight(), pivot, riding
end

-- Median of the measurements.
function world.Middle(fits, key)
    local values = {}
    for _, fit in ipairs(fits) do values[#values + 1] = fit[key] end
    table.sort(values)
    return values[math.ceil(#values / 2)]
end

-- Solves lens and pivot from one measurement (Newton's method).
function world.Fit(hop, X, Y)
    local RX, RY = (hop.X0 + X) / 2, (hop.Y0 + Y) / 2
    -- for the readout
    world.detail = ("the marked one moved %.0f, the tried spot was %.0f from it (%.0f by the guess)"):format(
        math.sqrt((hop.X0 - X) ^ 2 + (hop.Y0 - Y) ^ 2), math.sqrt((hop.X - RX) ^ 2 + (hop.Y - RY) ^ 2), hop.gap)
    if (hop.X0 - X) ^ 2 + (hop.Y0 - Y) ^ 2 > 144 then return "you or the camera moved" end
    if (hop.X - RX) ^ 2 + (hop.Y - RY) ^ 2 < 3600 then return "the game's marker didn't go to the tried spot" end
    local height = UIParent:GetHeight()
    local focal, pivot, riding = world.Lens()
    local lens = focal / height
    -- Screen error of the tried spot for a given lens and pivot.
    local function Miss(l, p)
        local side, down = world.Camera(RX / (l * height), RY / (l * height), hop.far, hop.zoom, p)
        if not side then return nil end
        local x, y = world.Project(hop.reach, side + hop.turn, down, hop.zoom, p)
        if not x then return nil end
        return x * l * height - hop.X, y * l * height - hop.Y
    end
    for _ = 1, 12 do
        local ex, ey = Miss(lens, pivot)
        local ax, ay = Miss(lens + 0.001, pivot)
        local bx, by = Miss(lens, pivot + 0.01)
        if not (ex and ax and bx) then return "no answer" end
        local j11, j21, j12, j22 = (ax - ex) / 0.001, (ay - ey) / 0.001, (bx - ex) / 0.01, (by - ey) / 0.01
        local det = j11 * j22 - j12 * j21
        if math.abs(det) < 1e-9 then return "can't be told from that spot" end
        lens = math.max(0.3, math.min(3, lens - (j22 * ex - j12 * ey) / det))
        pivot = math.max(-4, math.min(8, pivot - (j11 * ey - j21 * ex) / det))
    end
    local ex, ey = Miss(lens, pivot)
    if not ex or ex * ex + ey * ey > 1 then return "no answer that fits" end
    if lens < 0.4 or lens > 2 or pivot < -3 or pivot > 6 then return ("unlikely (%.2f, %.1f)"):format(lens, pivot) end
    local fits = world.fits[riding]
    fits[#fits + 1] = { lens = lens, pivot = pivot }
    local cam = ns.db.cam and ns.db.cam.cvar == world.cvar and ns.db.cam or { cvar = world.cvar }
    cam.lens, cam[riding and "ride" or "pivot"] = world.Middle(fits, "lens"), world.Middle(fits, "pivot")
    ns.db.cam = cam
    return "ok"
end

-- A camera measurement: the pin moves to a test spot for a third of a second,
-- its screen position is read, then the pin goes back. Waits in combat or with
-- the world map open; gives up after eight failures.
function world.Hop(nav, seen, busy)
    local hop, now = world.hop, GetTime()
    if world.at ~= hop.at then -- the pin moved on
        world.hop = nil
        if world.frame then world.frame:SetAlpha(1) end
        return
    end
    if busy or now < hop.due then return end
    local X, Y
    if seen then X, Y = world.Where(nav) end
    if hop.stage == 1 then
        local map, px, py, wide, tall = MapPosition()
        local zoom = GetCameraZoom()
        if X and map == hop.at.map and not issecretvalue(zoom) and zoom then
            -- Use your current position.
            local east, north = (hop.at.mx - px) * wide, (py - hop.at.my) * tall
            hop.far = math.sqrt(east * east + north * north)
            local way = math.atan2(east, north)
            east, north = (hop.mx - px) * wide, (py - hop.my) * tall
            hop.reach, hop.turn = math.sqrt(east * east + north * north), math.atan2(east, north) - way
            hop.X, hop.Y, hop.zoom = X, Y, zoom
        else
            hop.failed = "the tried spot wasn't on screen"
        end
        world.Set(hop.at)
        hop.stage, hop.due = 2, now + world.wait
        return
    end
    world.hop = nil
    world.fit = hop.failed or (X and world.Fit(hop, X, Y)) or "the marker wasn't on screen after"
    if world.fit ~= "ok" then
        world.fails = world.fails + 1
        if world.fit == "the game's marker didn't go to the tried spot" then world.wait = math.min(1, world.wait * 2) end
    end
    if world.frame then world.frame:SetAlpha(1) end
end

-- Hides the other sparkle frames from index `from` on.
function world.Clear(from)
    for i = from or 1, #world.others do
        local frame = world.others[i]
        if frame:IsShown() then
            frame:Hide()
            for _, part in ipairs(frame.parts) do
                part.group:Stop()
                part.coreGroup:Stop()
            end
        end
    end
end

-- Test spots for a measurement: { radians right of the marked node, distance factor }.
world.TRIES = { { 0.35, 0.5 }, { -0.35, 0.5 }, { 0.6, 0.5 }, { -0.6, 0.5 }, { 0.35, 1.6 }, { -0.35, 1.6 } }

-- Every frame the marker is visible: work out the camera, place the other
-- sparkles, and start a measurement when due.
function world.Several(nav, now, busy)
    local shown = 0
    world.side = nil
    local at, zoom = world.at, GetCameraZoom and GetCameraZoom()
    local map, px, py, wide, tall = MapPosition()
    local X, Y
    if not issecretvalue(zoom) and zoom and map and at.map == map then X, Y = world.Where(nav) end
    if X then
        local focal, pivot, riding = world.Lens()
        local east, north = (at.mx - px) * wide, (py - at.my) * tall
        local far, way = math.sqrt(east * east + north * north), math.atan2(east, north)
        local side, down = world.Camera(X / focal, Y / focal, far, zoom, pivot)
        if side then
            world.side, world.down = side, down
            local halfWide, halfTall = UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
            for _, marker in ipairs(Markers()) do -- (nearest first)
                if shown == 4 then break end
                if not marker.hard and not marker.dim and marker.kind ~= "rares" and marker.map == map and marker.yards and marker.yards >= 12
                    and (at.mx - marker.mx) ^ 2 + (at.my - marker.my) ^ 2 > 2.5e-7
                    and ns.db[LookOf(marker.kind)] then
                    east, north = (marker.mx - px) * wide, (py - marker.my) * tall
                    local reach = math.sqrt(east * east + north * north)
                    local x, y = world.Project(reach, side + math.atan2(east, north) - way, down, zoom, pivot)
                    if x and math.abs(x * focal) < halfWide and math.abs(y * focal) < halfTall then
                        shown = shown + 1
                        local frame = world.others[shown]
                        if not frame then
                            frame = NewSparkles()
                            frame:SetParent(UIParent)
                            frame:SetFrameStrata("BACKGROUND")
                            world.others[shown] = frame
                        end
                        local scale = math.max(0.2, math.min(1, 15 / reach))
                        frame.wide, frame.tall = 60, 560 * math.min(8 / reach, 0.3) / 2 / scale
                        frame:SetScale(scale)
                        frame:SetSize(frame.wide, frame.tall)
                        frame:ClearAllPoints()
                        frame:SetPoint("CENTER", UIParent, "CENTER", x * focal / scale, y * focal / scale)
                        if not frame:IsShown() or frame.kind ~= LookOf(marker.kind) then world.Fill(frame, marker.kind) end
                    end
                end
            end
            -- Measure (3 times, 4 s apart) once the view has been still for 0.4 s.
            if not world.stillAt or math.abs(X - world.stillX) + math.abs(Y - world.stillY) > 3 then
                world.stillX, world.stillY, world.stillAt = X, Y, now
            end
            if #world.fits[riding] < 3 and world.fails < 8 and not busy and now - (world.tried or -10) >= 4
                and now - world.stillAt >= 0.4 then
                for _, try in ipairs(world.TRIES) do
                    local reach, bearing = math.max(10, far * try[2]), way + try[1]
                    local x, y = world.Project(reach, side + try[1], down, zoom, pivot)
                    local mx, my = px + reach * math.sin(bearing) / wide, py - reach * math.cos(bearing) / tall
                    local gap = x and math.sqrt((x * focal - X) ^ 2 + (y * focal - Y) ^ 2)
                    if x and math.abs(x * focal) < halfWide * 0.8 and math.abs(y * focal) < halfTall * 0.8
                        and gap > 150 and mx > 0 and mx < 1 and my > 0 and my < 1 then
                        world.tried = now
                        world.hop = { at = at, stage = 1, due = now + world.wait, X0 = X, Y0 = Y, mx = mx, my = my, gap = gap }
                        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, mx, my))
                        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
                        if world.frame then world.frame:SetAlpha(0) end
                        break
                    end
                end
            end
        end
    end
    world.shown = shown
    world.Clear(shown + 1)
end

-- Every frame: move the pin to the target and the sparkles to the marker.
function world.Update()
    -- Off and nothing left to clean up.
    if not ns.db.worldMark and not world.at and not world.hop then return end
    local target = ns.db.worldMark and world.Pick()
    local busy = world.fight or InCombatLockdown() or (WorldMapFrame and WorldMapFrame:IsShown())
    local at = world.at
    if busy then
        -- leave the pin alone
    elseif target then
        -- moved more than ~3 yards
        if not at or at.map ~= target.map or (at.mx - target.mx) ^ 2 + (at.my - target.my) ^ 2 > 2.5e-7 then
            if C_Map.CanSetUserWaypointOnMap(target.map) then
                if not at then world.pin, world.quest = C_Map.GetUserWaypoint(), C_SuperTrack.GetSuperTrackedQuestID() end
                -- Same herb, slightly better position: keep its state.
                local same = at and at.map == target.map and at.name == target.name
                    and (at.mx - target.mx) ^ 2 + (at.my - target.my) ^ 2 <= 6.25e-6
                world.at = { map = target.map, mx = target.mx, my = target.my, kind = target.kind, name = target.name }
                world.Set(world.at)
                if not same then
                    world.level, world.asked, world.under, world.heat, world.low = nil, nil, nil, nil, nil
                    world.plain, world.clear, world.blip, world.was = nil, nil, nil, nil
                    world.taken = GetTime()
                end
            end
        end
    elseif at then
        world.Back() -- nothing left to mark
    end
    if ns.db.worldReadout then world.Say(target) end
    -- With that kind's Sparkles setting on, show sparkles and hide Blizzard's
    -- marker (alpha 0 after its UpdateAlpha); otherwise just the marker.
    at = world.at
    local sparkly = at and ns.db[LookOf(at.kind)] or false
    world.hide = sparkly and not world.broken -- with no sparkles possible, Blizzard's marker stays
    if world.hide and not world.hooked and SuperTrackedFrame and SuperTrackedFrame.UpdateAlpha then
        world.hooked = true
        hooksecurefunc(SuperTrackedFrame, "UpdateAlpha", function(marker)
            if world.hide then marker:SetAlpha(0) end
        end)
    end
    -- Sparkles on the marker while it's on screen.
    local nav = sparkly and not world.broken and C_Navigation.GetFrame()
    local distance = nav and C_Navigation.GetDistance()
    local seen = nav and distance and not issecretvalue(distance) and distance > 0
        and C_Navigation.HasValidScreenPosition() and not C_Navigation.WasClampedToScreen()
    -- Measuring the camera; once it ends (or is called off), on as usual this frame.
    if world.hop then world.Hop(nav, seen, busy) end
    if world.hop then
        -- still measuring
    elseif seen then
        local frame = world.frame
        if not frame then
            frame = NewSparkles()
            frame:SetParent(UIParent)
            frame:SetFrameStrata("BACKGROUND")
            world.frame = frame
        end
        -- Above or below you: checked once a second.
        local now = GetTime()
        if target and (not world.asked or now - world.asked >= 1) then
            world.level, world.asked = world.Level(target), now
        end
        -- Is the marker hidden (underground)? Smoothed over most of a second so the
        -- column doesn't flip on bumps, trees or jumps.
        local passed = math.min(now - (world.seen or now), 0.1)
        world.seen = now
        local hidden = C_Navigation.GetTargetState() == 1 and 1 or 0
        if world.nav ~= nav then world.heat, world.plain, world.clear, world.blip, world.was = nil, nil, nil, nil, nil end
        world.heat = world.heat and world.heat + (hidden - world.heat) * (1 - math.exp(-passed / 0.5)) or hidden
        if world.heat > 0.8 then world.under = true elseif world.heat < 0.2 then world.under = false end
        -- In plain view for 2 s: the herb is at or below the marker ("clear").
        if hidden == 1 and not world.was then
            if world.blip and now - world.blip < 3 then world.clear = false end
            world.blip = now
        end
        world.was = hidden == 1
        world.plain = hidden == 0 and (world.plain or 0) + passed or 0
        if world.under then world.clear = false elseif world.plain >= 2 then world.clear = true end
        -- Column height: 8 yards at this distance (max 3 in 10 slope), 20 yards for
        -- "hidden" and "clear". Sparkles shrink with distance.
        local level = world.level or "level"
        if level == "level" and world.under then
            level = "hidden"
        elseif level == "level" and world.clear then
            level = "clear"
        end
        local scale = math.max(0.2, math.min(1, 15 / distance))
        -- Column start and end on screen, relative to the marker.
        local short = 560 * math.min(8 / distance, 0.3)
        local low, high = -short / 4, short / 4
        if level == "hidden" then
            low, high = 0, 560 * math.min(20 / distance, 0.45)
        elseif level == "clear" then
            low, high = -560 * math.min(20 / distance, 0.45), 0
        elseif level == "up" then
            low, high = 0, short
        elseif level == "down" then
            low, high = -short, 0
        end
        -- Glide to the new column over about a second.
        if world.low and world.nav == nav then
            local step = 1 - math.exp(-passed / 0.3)
            low, high = world.low + (low - world.low) * step, world.high + (high - world.high) * step
        end
        world.low, world.high, world.shape = low, high, level
        -- base: the area's bottom, relative to the marker
        local wide, tall, base = 60, (high - low) / scale, low / scale
        frame:SetScale(scale)
        if world.nav ~= nav or math.abs(frame.tall - tall) > 0.5 or math.abs(world.base - base) > 0.5 then
            frame.wide, frame.tall, world.base = wide, tall, base
            frame:SetSize(wide, tall)
            frame:ClearAllPoints()
            -- If the marker can't be anchored to, report once and stop.
            local ok, problem = pcall(frame.SetPoint, frame, "BOTTOM", nav, "CENTER", 0, base)
            if not ok then
                world.broken = true
                frame:Hide()
                geterrorhandler()("NodeSight: sparkles can't be put on the game's marker: " .. tostring(problem))
                return
            end
            world.nav = nav
        end
        local kind = world.at and world.at.kind
        if not frame:IsShown() or frame.kind ~= LookOf(kind) then world.Fill(frame, kind) end
        world.Several(nav, now, busy)
    else
        if world.frame and world.frame:IsShown() then
            world.frame:Hide()
            world.nav = nil
            for _, part in ipairs(world.frame.parts) do
                part.group:Stop()
                part.coreGroup:Stop()
            end
        end
        world.side, world.shown = nil, 0
        world.Clear()
    end
end

-- A look changed in the sparkle window: the far sparkles on screen take it now.
function ns.RefreshFarSparkles()
    if world.frame and world.frame:IsShown() then world.Fill(world.frame, world.frame.kind) end
    for _, frame in ipairs(world.others) do
        if frame:IsShown() then world.Fill(frame, frame.kind) end
    end
end

-- Setting changed: turn In-Game Navigation on with it (off by default in WoW
-- Forever) and restore it when turned off.
function world.Changed()
    if ns.db.worldMark then
        local now = C_CVar.GetCVar("showInGameNavigation")
        if now ~= "1" then
            ns.db.navWas = now or "0"
            C_CVar.SetCVar("showInGameNavigation", "1")
        end
    elseif ns.db.navWas then
        C_CVar.SetCVar("showInGameNavigation", ns.db.navWas)
        ns.db.navWas = nil
    end
    UpdateScanner()
end
