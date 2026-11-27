-- NodeSight's far away sparkles (Beta): a column of sparkles in the world on the next place a
-- herb or ore can be, seen from far away. The game's map pin goes on the place the next node
-- arrow would point to, and the sparkles go on the marker the game draws for a tracked pin
-- (In-Game Navigation). Your own pin and tracked quest are kept and put back after.
--
-- Sections: Picking, The pin, The sparkles, Every frame, Settings.

local _, ns = ...

local abs, floor, max, min = math.abs, math.floor, math.max, math.min

local PICK_EVERY = 0.25 -- seconds between looks for the next place
local FADE = 0.4 -- seconds to fade in, or out at the screen's edge
local NEAR, FULL = 15, 21 -- yards: unseen at the first (the node's own sparkles take over), in full from the second
local COUNT = 14 -- sparkles in the column
local WIDE = 60 -- the column's width
local REACH = 5 -- yards the column goes up and down from the marker
local LENS = 560 -- screen units a yard takes up one yard away, roughly

-- at: the place the pin is on { map, place, key, kind, mx, my }; pin, quest, tracked: what
-- you had before; shown: the sparkles' fade, 0 to 1.
local far = {}
local driver, list, frame
local target = {}

local function MapOpen() return WorldMapFrame ~= nil and WorldMapFrame:IsShown() end

-- Where a record of your own pin is kept while the pin is ours (each character has its own pin).
local function Saved() return type(NodeSightCharDB) == "table" and NodeSightCharDB or NodeSightDB end

---------------------------------------------------------------------------
-- Picking
---------------------------------------------------------------------------

-- The place the next node arrow would point to, looked for a few times a second.
local function Pick()
    local now = GetTime()
    if far.pickedAt and now - far.pickedAt < PICK_EVERY then return far.target end
    far.pickedAt, far.target = now, nil
    local C = ns.Collecting
    local map = C_Map.GetBestMapForUnit("player")
    if issecretvalue(map) or type(map) ~= "number" then return nil end
    local own, gm = C.Sources(map)
    if not (own or gm) then return nil end
    local x, y, width, height = C.MapPosition(map)
    if not x then return nil end
    local reach = ns.db.nodeArrowRange * ns.db.nodeArrowRange
    C.Near(list, own, gm, x, y, width, height, reach)
    local i = ns.NearestNode(list, map, x, y, width, height, C.Version(), reach)
    if not i then return nil end
    target.map, target.place, target.key, target.kind = map, list.place[i], list.key[i], list.kind[i]
    far.target = target
    return target
end

---------------------------------------------------------------------------
-- The pin
---------------------------------------------------------------------------

-- The world map's own pin, unseen and not clickable while the pin is ours. Blizzard's
-- waypoint provider places it again on every change, so a hook on that does it.
local function ShowMapPin(pin)
    if not pin then return end
    local ours = far.at ~= nil and not far.moved -- (moved: you put one of your own there)
    pin:SetAlpha(ours and 0 or 1)
    pin:EnableMouse(not ours)
end

local function MapPin()
    local providers = not far.mapHooked and WorldMapFrame and WorldMapFrame.dataProviders
    if type(providers) == "table" then
        for provider in pairs(providers) do
            -- Known by its mixin's function (some providers' GetPinTemplate needs an argument).
            if type(provider) == "table" and WaypointLocationDataProviderMixin and provider.RefreshAllData
                and provider.GetPinTemplate == WaypointLocationDataProviderMixin.GetPinTemplate then
                far.mapHooked, far.mapPins = true, provider
                hooksecurefunc(provider, "RefreshAllData", function(self) ShowMapPin(self.pin) end)
                break
            end
        end
    end
    if far.mapPins then ShowMapPin(far.mapPins.pin) end
end

-- Blizzard's marker in the world, unseen while the pin is ours (after its own UpdateAlpha).
local function HookMarker()
    if far.markerHooked or not (SuperTrackedFrame and SuperTrackedFrame.UpdateAlpha) then return end
    far.markerHooked = true
    hooksecurefunc(SuperTrackedFrame, "UpdateAlpha", function(marker)
        if far.hide then marker:SetAlpha(0) end
    end)
end

-- Your pin and tracked quest, saved while the pin is ours: if giving them back fails as the
-- game closes, PinBack does it at the next login.
local function Keep()
    local pin = far.pin
    local saved = { quest = far.quest, tracked = far.tracked == true }
    if pin then
        local ok, at = pcall(C_Map.GetUserWaypointPositionForMap, pin.uiMapID)
        if not (ok and type(at) == "table" and not issecretvalue(at.x) and not issecretvalue(at.y)
            and type(at.x) == "number" and type(at.y) == "number") then return end
        saved.map, saved.x, saved.y = pin.uiMapID, at.x, at.y
    end
    Saved().farPinWas = saved
end

local function PinBack()
    local was = Saved().farPinWas
    if type(was) ~= "table" or far.at then return end
    Saved().farPinWas = nil
    if was.map then C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(was.map, was.x, was.y)) else C_Map.ClearUserWaypoint() end
    C_SuperTrack.SetSuperTrackedUserWaypoint(was.tracked == true)
    if was.quest and was.quest ~= 0 then C_SuperTrack.SetSuperTrackedQuestID(was.quest) end
end

-- What you have now, before the pin is taken.
local function Remember()
    local quest = C_SuperTrack.GetSuperTrackedQuestID()
    far.pin = C_Map.GetUserWaypoint()
    far.quest = not issecretvalue(quest) and type(quest) == "number" and quest or nil
    far.tracked = C_SuperTrack.IsSuperTrackingUserWaypoint() == true
    Keep()
end

-- Puts the map pin on the place and tracks it. (ours: the game sends USER_WAYPOINT_UPDATED
-- inside the call, and YourPin takes every other change for yours.)
local function Set(at)
    far.ours = true
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(at.map, at.mx, at.my))
    far.ours = nil
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    MapPin()
end

-- Your own pin (tracked if it was) and tracked quest back.
local function Back()
    far.ours = true
    if far.pin then C_Map.SetUserWaypoint(far.pin) else C_Map.ClearUserWaypoint() end
    far.ours = nil
    C_SuperTrack.SetSuperTrackedUserWaypoint(far.tracked == true)
    if far.quest and far.quest ~= 0 then C_SuperTrack.SetSuperTrackedQuestID(far.quest) end
    far.at, far.pin, far.quest, far.tracked, far.moved = nil, nil, nil, nil, nil
    Saved().farPinWas = nil
    MapPin()
end

-- The pin changed while it was ours, and not by us: you put one on the world map or took it
-- off, or a chat link or another addon did. That is the one to give back, and ours is set
-- again after (once the map is closed).
local function YourPin()
    if not far.at or far.ours then return end
    far.pin, far.tracked, far.moved = C_Map.GetUserWaypoint(), false, true
    Keep()
end

---------------------------------------------------------------------------
-- The sparkles
---------------------------------------------------------------------------

local function Out()
    if frame and frame:IsShown() then
        frame:Hide()
        for _, part in ipairs(frame.parts) do
            part.group:Stop()
            part.coreGroup:Stop()
        end
    end
    if frame then frame.filled = nil end
    far.nav, far.shown = nil, nil
end

-- The column's sparkles: the kind's, in its colors or the place's skill color.
local function Fill(kind, key)
    local one, two = ns.SparkleColors(kind)
    local level = ns.db.skillColors and ns.SkillLevel(key, kind)
    if level then one, two = ns.SKILL_COLORS[level], ns.SKILL_COLORS[level] end
    if frame.filled and frame.kind == kind and frame.one == one and frame.two == two then return end
    frame.kind, frame.one, frame.two, frame.filled = kind, one, two, true
    local parts = frame.parts
    for i = 1, COUNT do
        local part = parts[i]
        if not part then
            part = ns.NewSparkle(frame)
            parts[i] = part
        end
        ns.ApplyColor(part, i % 2 == 0 and two or one)
        part.texture:Show()
        part.core:Show()
        if not part.group:IsPlaying() then part.group:Play() end
        if not part.coreGroup:IsPlaying() then part.coreGroup:Play() end
    end
end

-- The column on the game's marker, yards away: smaller with distance, as the world is.
local function Show(nav, distance, passed)
    local at = far.at
    if not frame then
        frame = ns.NewSparkles()
        frame:SetParent(UIParent)
        frame:SetFrameStrata("BACKGROUND")
    end
    local scale = max(0.2, min(1, 15 / distance))
    local tall = 2 * LENS * min(REACH / distance, 0.3) / scale
    if not far.scale or abs(far.scale - scale) > 0.01 then
        far.scale = scale
        frame:SetScale(scale)
    end
    if not frame.tall or abs(frame.tall - tall) > 0.5 then
        frame.wide, frame.tall = WIDE, tall
        frame:SetSize(WIDE, tall)
    end
    if far.nav ~= nav then
        frame:ClearAllPoints()
        -- A marker that can't be anchored to: Blizzard's own shows instead.
        if not pcall(frame.SetPoint, frame, "CENTER", nav, "CENTER", 0, 0) then
            far.broken = true
            return Out()
        end
        far.nav = nav
    end
    Fill(at.kind, at.key)
    if not frame:IsShown() then frame:Show() end
    far.shown = min(1, (far.shown or 0) + passed / FADE)
    local alpha = far.shown * max(0, min(1, (distance - NEAR) / (FULL - NEAR))) * ns.db.brightness / 100
    if ns.db.combatHide and InCombatLockdown() then alpha = 0 end
    if frame.alpha ~= alpha then
        frame.alpha = alpha
        frame:SetAlpha(alpha)
    end
end

---------------------------------------------------------------------------
-- Every frame
---------------------------------------------------------------------------

-- Moves the pin to the next place, and the sparkles onto the game's marker. Nothing is
-- changed in combat, or with the world map open (it would make its pin under our taint).
local function Update(passed)
    local db = ns.db
    local busy = far.fight or InCombatLockdown() or MapOpen()
    local want = db.farSparkles and Pick() or nil
    local at = far.at
    if busy then
        -- (the pin stays as it is)
    elseif want then
        if not at or far.moved or at.map ~= want.map or at.place ~= want.place then
            if C_Map.CanSetUserWaypointOnMap(want.map) then
                if not at then Remember() end
                local C = ns.Collecting
                far.at = { map = want.map, place = want.place, key = want.key, kind = want.kind,
                    mx = floor(want.place / C.PACK) / C.UNITS, my = want.place % C.PACK / C.UNITS }
                far.moved, far.shown = nil, nil
                Set(far.at)
            end
        end
    elseif at then
        Back()
    end
    -- The game's marker is the pin's only while the pin is what's tracked. Tracking a quest
    -- meanwhile makes it the one to give back, and its marker is left alone.
    local tracked = far.at ~= nil and C_SuperTrack.IsSuperTrackingUserWaypoint()
    if issecretvalue(tracked) then tracked = false end
    -- Your corpse comes before a tracked pin: the marker is its then, and is left alone.
    local top = tracked and C_SuperTrack.GetHighestPrioritySuperTrackingType and C_SuperTrack.GetHighestPrioritySuperTrackingType()
    if issecretvalue(top) or top and top ~= Enum.SuperTrackingType.UserWaypoint then tracked = false end
    if far.at and not tracked then
        local quest = C_SuperTrack.GetSuperTrackedQuestID()
        if not issecretvalue(quest) and type(quest) == "number" and quest ~= 0 then far.quest = quest end
    end
    far.hide = tracked == true and not far.broken
    if far.hide then HookMarker() end
    local nav = far.hide and C_Navigation.GetFrame() or nil
    local distance = nav and C_Navigation.GetDistance()
    if issecretvalue(distance) or type(distance) ~= "number" then distance = nil end
    local valid, clamped = distance and C_Navigation.HasValidScreenPosition(), distance and C_Navigation.WasClampedToScreen()
    if issecretvalue(valid) or issecretvalue(clamped) then valid = false end
    if valid and not clamped then
        Show(nav, distance, passed)
    elseif valid and frame and frame:IsShown() and far.shown then
        -- Held at the screen's edge: fades out, so turning the camera past it doesn't blink.
        far.shown = far.shown - passed / FADE
        if far.shown <= 0 then
            Out()
        else
            frame.alpha = min(frame.alpha or 1, far.shown)
            frame:SetAlpha(frame.alpha)
        end
    else
        Out()
    end
    if not db.farSparkles and not far.at then driver:Hide() end
end

-- A code error: off until a reload. Your own pin comes back once the world map is closed.
local NavOut
local function OnUpdate(_, passed)
    if far.wait then return end
    if far.stopped then
        if MapOpen() then return end
        driver:Hide()
        if far.at then pcall(Back) end
        far.at = nil -- (once, even if that failed)
        return
    end
    if xpcall(Update, geterrorhandler(), passed) then return end
    far.stopped, far.hide = true, false
    pcall(Out)
    pcall(NavOut)
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------

-- In-Game Navigation draws the marker and is off by default: on while the setting is, and
-- back as it was after (it is an account setting). Not in combat: tried again after it.
local function NavIn()
    if InCombatLockdown() then return end
    local now = C_CVar.GetCVar("showInGameNavigation")
    if now ~= "1" then
        ns.db.farNavWas = now or "0"
        C_CVar.SetCVar("showInGameNavigation", "1")
    end
end

function NavOut()
    local was = ns.db.farNavWas
    if not was or InCombatLockdown() then return end
    C_CVar.SetCVar("showInGameNavigation", was)
    if C_CVar.GetCVar("showInGameNavigation") == was then ns.db.farNavWas = nil end
end

local function OnEvent(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        far.fight = true -- (the game's lockdown starts a moment later)
    elseif event == "PLAYER_REGEN_ENABLED" then
        far.fight = nil
        if ns.db.farSparkles and not far.stopped then NavIn() else NavOut() end
    elseif event == "USER_WAYPOINT_UPDATED" then
        YourPin()
    elseif event == "PLAYER_ENTERING_WORLD" then
        far.wait = nil
        PinBack()
        if ns.db.farSparkles and not far.stopped then NavIn() end
    else -- PLAYER_LOGOUT: everything back as it was (set again at login)
        if far.at and not MapOpen() then pcall(Back) end
        NavOut()
    end
end

local function Start()
    if not driver then
        driver = CreateFrame("Frame")
        list = ns.Collecting.NewNearList()
        driver:SetScript("OnUpdate", OnUpdate)
        driver:SetScript("OnEvent", OnEvent)
        for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "USER_WAYPOINT_UPDATED", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT" }) do
            driver:RegisterEvent(event)
        end
    end
    driver:Show()
end

-- The settings say this in red by the checkbox.
ns.FAR_WARNING = "Takes over your map pin and quest tracking while on."

-- The setting changed. Off: the next frame gives the pin back, then nothing runs.
function ns.FarSparklesChanged()
    if far.stopped then return end
    if ns.db.farSparkles then
        NavIn()
        Start()
    else
        NavOut()
    end
end

-- At load, once the saved settings are in use. A note of your pin left by the last session
-- (a logout with the world map open) is given back at the first loading screen, and
-- nothing is taken before it: the pin still there may be ours.
function ns.FarSparkles()
    if ns.db.farSparkles or type(Saved().farPinWas) == "table" then
        far.wait = true
        Start()
    end
    if not ns.db.farSparkles then NavOut() end
end
