-- NodeSight's finder switch: when to switch Find Herbs and Find Minerals, and the mute of its click.

local _, ns = ...

local FINDERS = ns.FINDERS

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

ns.Mute = Mute

local switch = {
    on = false, -- events registered
    way = 0, -- yards walked, or seconds moved in the Seconds measure, since the last reset
    lastTick = nil, -- GetTime() of the last tick, nil after a reset
    pending = nil, -- { kind = "herbs"|"ore", at = seconds } from a switch until its verdict
    kind = nil, -- the herbs or ore finder on at the last tracking event or switch-on (nil: none or both)
    stopped = false, -- stop after a code error, until /reload
    speeds = {}, -- { walking = n, mounted = n }, last readable speeds
    radius = nil, -- last readable view radius
    measure = nil, -- switchMeasure the way was counted in
}
ns.switch = switch

local TICK = 0.25 -- seconds between ticks
local MAX_STEP = 1 -- seconds of way a tick counts at most, so a frame stall isn't walked
local SPEEDS = { walking = 7, mounted = 11.2 } -- yards a second until the game tells

-- A value the game returned is set: not nil or false, and a secret counts as unset.
local function IsSet(value)
    return not issecretvalue(value) and value ~= nil and value ~= false
end

-- The distance between switches: percent of the minimap's view radius, 10 yards at least.
-- nil until the view radius was readable once; 0 or less counts as unreadable.
function ns.SwitchDistance(percent)
    local radius = C_Minimap.GetViewRadius()
    if not issecretvalue(radius) and type(radius) == "number" and radius > 0 then switch.radius = radius end
    if not switch.radius then return nil end
    return math.max(10, percent / 100 * switch.radius)
end

-- The Measure distance in setting's choices; the index is switchMeasure.
ns.SWITCH_MEASURES = { "% of the minimap", "Yards", "Seconds" }
-- The yards and seconds sliders' { min, max, step }; load clamps saved values to them.
ns.SWITCH_RANGES = { switchDistanceYards = { 20, 200, 5 }, switchSeconds = { 2, 30, 1 } }

-- The way to go between switches and its unit ("yd" or "s"), per switchMeasure: percent of the
-- view radius, yards, or seconds on the move. nil while the view radius was never readable.
function ns.SwitchGoal()
    local db = ns.db
    if db.switchMeasure == 2 then return db.switchDistanceYards, "yd" end
    if db.switchMeasure == 3 then return db.switchSeconds, "s" end
    return ns.SwitchDistance(db.switchPercent), "yd"
end

-- The way counted so far is in the old measure's unit: start again.
function ns.SwitchMeasureChanged()
    switch.way = 0
end

-- Moving on your own: not on a flight path, not dead or a ghost.
local function Moving()
    local moving, taxi, dead = IsPlayerMoving(), UnitOnTaxi("player"), UnitIsDeadOrGhost("player")
    if issecretvalue(moving) or issecretvalue(taxi) or issecretvalue(dead) then return false end
    return moving and not taxi and not dead
end

-- Your speed while moving, walking or mounted: the last readable one, else a usual one.
local function Speed()
    local mounted = IsMounted()
    local state = IsSet(mounted) and "mounted" or "walking"
    local speed = GetUnitSpeed("player")
    if not issecretvalue(speed) and type(speed) == "number" and speed > 0 then switch.speeds[state] = speed end
    return switch.speeds[state] or SPEEDS[state]
end

-- The finder spell of each kind to switch to.
local SPELLS = {}
for spell, kind in pairs(FINDERS) do
    if kind == "herbs" or kind == "ore" then SPELLS[kind] = spell end
end

-- Whether to switch to kind now; each check says why not.
function ns.SwitchReady(kind)
    -- In combat (a switch costs a global cooldown) or not moving on your own (a secret counts as standing).
    if InCombatLockdown() or not Moving() then return false end
    -- While kind's cooldown runs: the finders have none of their own, so it's the global cooldown (a secret counts as running).
    local info = C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(SPELLS[kind])
    if issecretvalue(info) then return false end
    return type(info) ~= "table" or not (issecretvalue(info.isActive) or info.isActive == true)
end

-- Every frame with the switch on: adds the way (yards or seconds) since the last tick, and
-- switches once it reaches the goal.
function ns.SwitchUpdate()
    local now = GetTime()
    if not switch.lastTick then
        switch.lastTick = now
        return
    end
    local step = now - switch.lastTick
    if step < TICK then return end
    -- The measure changed anywhere (its dropdown, Defaults, /run): the way is in the old unit.
    if switch.measure ~= ns.db.switchMeasure then
        ns.SwitchMeasureChanged()
        switch.measure = ns.db.switchMeasure
    end
    if switch.pending and now >= switch.pending.at + ns.SWITCH_WAIT then
        switch.pending = nil
        switch.kind = ns.Finders() or switch.kind -- so a late tracking event isn't taken for one by hand
    end
    if Moving() then
        local counted = math.min(step, MAX_STEP)
        switch.way = switch.way + (ns.db.switchMeasure == 3 and counted or counted * Speed())
    end
    switch.lastTick = now
    local goal = ns.SwitchGoal()
    if goal and switch.way >= goal and ns.TrySwitch() then switch.way = 0 end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Events only the switch needs: unit events for the player, and plain ones.
local UNIT_EVENTS = { "UNIT_SPELLCAST_SUCCEEDED" }
local EVENTS = { "MINIMAP_UPDATE_TRACKING" }

-- Registers the switch's events while it's on, so players without it notice nothing.
function ns.SwitchEvents(on)
    if on == switch.on then return end
    switch.on = on
    for _, event in ipairs(UNIT_EVENTS) do
        if on then events:RegisterUnitEvent(event, "player") else events:UnregisterEvent(event) end
    end
    for _, event in ipairs(EVENTS) do
        if on then events:RegisterEvent(event) else events:UnregisterEvent(event) end
    end
    if on then switch.kind = ns.Finders() end
    if not on then switch.way, switch.pending, switch.lastTick = 0, nil, nil end
end

events:SetScript("OnEvent", function(_, event, _, _, arg3)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        CastDone(arg3)
    elseif event == "MINIMAP_UPDATE_TRACKING" then
        -- Another herbs or ore finder, and not NodeSight's switch: one by hand. The next needs a
        -- scan of that kind and a new way. Other tracking changes (creatures, treasure) don't count.
        local kind = ns.Finders()
        if not switch.pending and kind ~= switch.kind then ns.turns.scanned, switch.way = false, 0 end
        switch.kind = kind
    elseif event == "PLAYER_ENTERING_WORLD" then
        switch.way, switch.lastTick = 0, nil -- a loading screen is no way
        switch.kind = ns.Finders() -- the finder may have changed meanwhile
    elseif event == "PLAYER_LOGOUT" then
        Unmute() -- also on a /reload: the timers end with the UI
    end
end)
