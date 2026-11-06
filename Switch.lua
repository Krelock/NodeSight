-- NodeSight's finder switch: when to switch Find Herbs and Find Minerals, whether it worked, and the mute of its click.

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
    castAt = nil, -- time of the latest own cast event or dismount
    mounted = false, -- IsMounted() at the last mount event or loading screen
    hoverAt = nil, -- time of the last UPDATE_MOUSEOVER_UNIT
    failures = 0, -- failed switches in a row
    stoppedUntil = nil, -- end of the stop after two failures
    measure = nil, -- switchMeasure the way was counted in
}
ns.switch = switch

local TICK = 0.25 -- seconds between ticks
local MAX_STEP = 1 -- seconds of way a tick counts at most, so a frame stall isn't walked
local SPEEDS = { walking = 7, mounted = 11.2 } -- yards a second until the game tells
local STOP = 60 -- seconds without switching after two failed switches in a row

-- Ends the stop after failed switches (not the one after an error).
function ns.SwitchReset()
    switch.failures, switch.stoppedUntil = 0, nil
end

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

-- Busy: casting or channeling (gathering too), looting, or a spell or item on the cursor.
local function Busy()
    if IsSet(UnitCastingInfo("player")) or IsSet(UnitChannelInfo("player")) then return true end
    if IsSet(SpellIsTargeting()) or IsSet(GetCursorInfo()) then return true end
    local loot = GetNumLootItems()
    return not issecretvalue(loot) and type(loot) == "number" and loot > 0
end

-- A herb or ore symbol closer than yards. Only ones with a map position, as only
-- those keep their distance while you move, and none outside the minimap.
local function NearNode(yards)
    for _, marker in ipairs(ns.Markers()) do
        if (marker.kind == "herbs" or marker.kind == "ore") and marker.map and not marker.far
            and marker.yards < yards then return true end
    end
    return false
end

-- The setting for each area type of IsInInstance(). Other types (arenas, scenarios) never switch.
local AREAS = { none = "switchWorld", party = "switchDungeons", raid = "switchRaids", pvp = "switchBattlegrounds" }

-- Switching allowed here: in an area it's on for, and mounted if only while mounted
-- (a secret counts as neither).
local function Allowed()
    local db = ns.db
    local _, area = IsInInstance()
    if issecretvalue(area) or not AREAS[area] or not db[AREAS[area]] then return false end
    return not db.switchMounted or IsSet(IsMounted())
end

-- An enemy: attackable, alive, hostile or neutral (no reaction counts too), not a critter.
-- A secret counts as enemy for its point. Second result: true only for a readable yes from
-- UnitCanAttack, so the range checks may ask items.
local function Enemy(unit)
    local attack = UnitCanAttack("player", unit)
    if not issecretvalue(attack) and not attack then return false end
    local attackable = not issecretvalue(attack) and attack == true
    local dead = UnitIsDeadOrGhost(unit)
    if IsSet(dead) then return false end
    local reaction = UnitReaction("player", unit)
    if not issecretvalue(reaction) and type(reaction) == "number" and reaction > 4 then return false end
    -- Critters by their type ID (8), else by the type's name.
    local name, id = UnitCreatureType(unit)
    if issecretvalue(id) then return true, attackable end
    if id ~= nil then return id ~= 8, attackable end
    local critter = C_CreatureInfo.GetCreatureTypeInfo(8)
    if issecretvalue(name) or name == nil then return true, attackable end
    if type(critter) ~= "table" or issecretvalue(critter.name) then return true, attackable end
    return name ~= critter.name, attackable
end

-- The range checks, smallest first, one per yard value: { yards, interact = CheckInteractDistance
-- index, items = item IDs for C_Item.IsItemInRange }. The items are LibRangeCheck-3.0's (MIT) for
-- Classic Era and Forever, checked against Forever's client data (build 1.60.1.70707).
-- In-game check pending: the yards of each index and item, whether they answer for enemies, and
-- whether items answer without being owned.
local RANGES = { { 5, items = { 8149 } }, { 10, interact = 3, items = { 17626, 10699 } }, { 11, interact = 2 },
    { 20, items = { 10645, 21519 } }, { 25, items = { 13289 } }, { 28, interact = 4 },
    { 30, items = { 835, 2091 } }, { 35, items = { 1399, 1402 } }, { 40, items = { 8348, 4945 } },
    { 45, items = { 221316 } } }
ns.SWITCH_REACH = RANGES[#RANGES][1] -- the farthest a range check reaches, except your own spells
-- Your own spells as range checks: those whose range rounded down is above SPELL_MIN yards (melee
-- range follows combat reach) and up to SPELL_MAX (the slider's maximum), for the SPELL_YARDS
-- smallest yard values, with SPELLS_PER_YARDS spells per yard value at most.
local SPELL_MIN, SPELL_MAX, SPELL_YARDS, SPELLS_PER_YARDS = 5, 60, 12, 2
-- The range checks in use, smallest first, one tier per yard value: { yards, interact = index,
-- items = item IDs, spells = spell IDs } from RANGES and your spells.
local tiers = {}
-- tiers must be built again before the next check: your spells may have changed.
local ladderDirty = true
-- After a build with a secret or missing spellbook read: GetTime() from which the next check
-- builds again (nil: complete). RETRY seconds apart, as a read may stay unreadable for good.
local ladderRetry = nil
local RETRY = 5
local requested = {} -- items whose data was requested
local HOVER = 1 -- seconds a mouseover counts after it changed

-- value if it's a readable number (Number) or boolean (Bool), else nil (secret, missing or another type).
local function Number(value)
    if not issecretvalue(value) and type(value) == "number" then return value end
end
local function Bool(value)
    if not issecretvalue(value) and type(value) == "boolean" then return value end
end

-- Your spells as range checks, smallest first: a list of { yards, spells = spell IDs } and whether
-- every read was readable (true without the spellbook API). From the player spellbook, without
-- hidden and off-spec lines, passives, flyouts, pet actions and low ranks; a name only once.
-- yards: maxRange rounded down, also for the limits. Harmful spells first, others fill the rest. A secret or missing
-- read leaves out its line or spell (a spell whose harm is unreadable counts as not harmful) and
-- makes the list incomplete.
-- In-game check pending: the spellbook reads, IsSpellInRange for enemies, and whether maxRange
-- includes talents such as Hawk Eye.
local function SpellRungs()
    local book, spell = C_SpellBook, C_Spell
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    local SPELL = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
    if not (book and spell and bank and SPELL and book.GetNumSpellBookSkillLines and book.GetSpellBookSkillLineInfo
        and book.GetSpellBookItemType and book.IsSpellBookItemLowRank and spell.GetSpellInfo
        and spell.IsSpellPassive and spell.IsSpellHarmful) then return {}, true end -- no retry brings them
    local complete, byYards, names = true, {}, {}
    -- Adds the spell in slot to byYards, if it's a range check.
    local function Slot(slot)
        local kind, _, id = book.GetSpellBookItemType(slot, bank)
        if issecretvalue(kind) or kind == nil then complete = false return end
        if kind ~= SPELL then return end
        id = Number(id)
        local low = Bool(book.IsSpellBookItemLowRank(slot, bank))
        if not id or low == nil then complete = false return end
        if low then return end
        local passive, info = Bool(spell.IsSpellPassive(id)), spell.GetSpellInfo(id)
        if passive == nil or issecretvalue(info) or type(info) ~= "table" then complete = false return end
        if passive then return end
        local name, range = info.name, Number(info.maxRange)
        if issecretvalue(name) or type(name) ~= "string" or not range then complete = false return end
        local yards = math.floor(range)
        if not (yards > SPELL_MIN and yards <= SPELL_MAX) or names[name] then return end
        names[name] = true
        local harmful = Bool(spell.IsSpellHarmful(id))
        if harmful == nil then complete = false end
        byYards[yards] = byYards[yards] or { harmful = {}, other = {} }
        local list = harmful and byYards[yards].harmful or byYards[yards].other
        list[#list + 1] = id
    end
    local lines = Number(book.GetNumSpellBookSkillLines())
    if not lines then return {}, false end
    for line = 1, lines do
        local info = book.GetSpellBookSkillLineInfo(line)
        if issecretvalue(info) or type(info) ~= "table" then
            complete = false
        else
            local offset, count = Number(info.itemIndexOffset), Number(info.numSpellBookItems)
            local hide = Bool(info.shouldHide)
            local offSpec = info.offSpecID -- nil (or 0) on active lines
            if not offset or not count or hide == nil or issecretvalue(offSpec)
                or (offSpec ~= nil and type(offSpec) ~= "number") then
                complete = false
            elseif not hide and (offSpec == nil or offSpec == 0) then
                for slot = offset + 1, offset + count do Slot(slot) end
            end
        end
    end
    local values, rungs = {}, {}
    for yards in pairs(byYards) do values[#values + 1] = yards end
    table.sort(values)
    for i = 1, math.min(#values, SPELL_YARDS) do
        local found, spells = byYards[values[i]], {}
        for _, list in ipairs({ found.harmful, found.other }) do
            for _, id in ipairs(list) do
                if #spells < SPELLS_PER_YARDS then spells[#spells + 1] = id end
            end
        end
        rungs[i] = { values[i], spells = spells }
    end
    return rungs, complete
end

-- Fills tiers: RANGES and your spells, each merged into the tier of its yards. With a secret or
-- missing spellbook read, again RETRY seconds later.
local function Tiers()
    for i = #tiers, 1, -1 do tiers[i] = nil end
    local byYards = {}
    -- Adds a check's interact index, items and spells to the tier of yards (a new one if none).
    local function Add(yards, check)
        local tier = byYards[yards]
        if not tier then
            tier = { yards }
            byYards[yards] = tier
            tiers[#tiers + 1] = tier
        end
        tier.interact = tier.interact or check.interact
        for _, field in ipairs({ "items", "spells" }) do
            for _, id in ipairs(check[field] or {}) do
                tier[field] = tier[field] or {}
                tier[field][#tier[field] + 1] = id
            end
        end
    end
    for _, range in ipairs(RANGES) do Add(range[1], range) end
    local rungs, complete = SpellRungs()
    for _, rung in ipairs(rungs) do Add(rung[1], rung) end
    table.sort(tiers, function(a, b) return a[1] < b[1] end)
    ladderDirty, ladderRetry = false, not complete and GetTime() + RETRY or nil
end

-- Asks once for the items' data, so their range checks answer.
local function RequestItems()
    local Request = C_Item.RequestLoadItemDataByID
    if not Request then return end
    for _, range in ipairs(RANGES) do
        for _, item in ipairs(range.items or {}) do
            if not requested[item] then
                requested[item] = true
                Request(item)
            end
        end
    end
end

-- check(id, unit) for ids: yes if one says yes, else no if one says no, else nil (nil or
-- secret). A yes wins, as a no may have other reasons than the distance.
local function Any(check, ids, unit)
    if not check then return nil end
    local answer
    for _, id in ipairs(ids) do
        local near = check(id, unit)
        if not issecretvalue(near) and type(near) == "boolean" then
            if near then return true end
            answer = false
        end
    end
    return answer
end

-- C_Spell.IsSpellInRange for spell's override now (spell itself without a readable one).
local function SpellInRange(spell, unit)
    local Override = C_SpellBook and C_SpellBook.FindSpellOverrideByID
    local override = Override and Number(Override(spell))
    if override and override > 0 then spell = override end
    return C_Spell.IsSpellInRange(spell, unit)
end

-- A tier's answer for unit: yes if its interact check, an item or a spell says yes, else no if
-- the interact check or an item says no, else nil (nil or secret). A spell's no never counts: it
-- may come from a minimum range, a missing weapon or a stance. items false: no item is asked.
local function InRange(unit, tier, items)
    local answer
    if tier.interact then
        local near = CheckInteractDistance(unit, tier.interact)
        if not issecretvalue(near) and type(near) == "boolean" then
            if near then return true end
            answer = false
        end
    end
    if items and tier.items then
        local near = Any(C_Item.IsItemInRange, tier.items, unit)
        if near then return true end
        if near == false then answer = false end
    end
    if tier.spells and C_Spell.IsSpellInRange and Any(SpellInRange, tier.spells, unit) then return true end
    return answer
end

-- unit within yards: exactly if the game tells, else by the next range check at or above
-- yards (the largest if none). Without an answer the next larger one decides, then the
-- next smaller. None answers: far. items false: no item is asked.
local function Near(unit, yards, items)
    local squared, checked = UnitDistanceSquared(unit)
    if not issecretvalue(checked) and checked == true and not issecretvalue(squared)
        and type(squared) == "number" then return squared <= yards ^ 2 end
    if ladderDirty or (ladderRetry and GetTime() >= ladderRetry) then Tiers() end
    local first = #tiers
    for i = #tiers, 1, -1 do
        if tiers[i][1] >= yards then first = i end
    end
    for i = first, #tiers do
        local near = InRange(unit, tiers[i], items)
        if near ~= nil then return near end
    end
    for i = first - 1, 1, -1 do
        local near = InRange(unit, tiers[i], items)
        if near ~= nil then return near end
    end
    return false
end

-- Whether to switch to kind now; each check says why not.
function ns.SwitchReady(kind)
    if switch.stoppedUntil and GetTime() < switch.stoppedUntil then return false end -- after two failed switches
    -- In combat (a switch costs a global cooldown) or not moving on your own (a secret counts as standing).
    if InCombatLockdown() or not Moving() then return false end
    if not Allowed() then return false end -- not on for this area, or not mounted if only while mounted
    local db = ns.db
    if db.switchPauseBusy and Busy() then return false end -- casting, looting or something on the cursor
    if db.switchPauseStealth and IsSet(IsStealthed()) then return false end -- stealthed
    -- Just after your own spell or dismounting.
    local after = db.switchAfterCast
    if after > 0 and switch.castAt and GetTime() - switch.castAt < after then return false end
    if db.switchNearYards > 0 and NearNode(db.switchNearYards) then return false end -- near a herb or ore
    -- While kind's cooldown runs: the finders have none of their own, so it's the global cooldown (a secret counts as running).
    local info = C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(SPELLS[kind])
    if issecretvalue(info) then return false end
    if type(info) == "table" and (issecretvalue(info.isActive) or info.isActive == true) then return false end
    -- With an enemy near as the target or just moused over (last, as it costs most).
    local yards = db.switchEnemyYards
    if yards <= 0 then return true end
    -- A secret UnitCanAttack: no item is asked.
    local enemy, attackable = Enemy("target")
    if enemy and Near("target", yards, attackable) then return false end
    -- The soft target never counts: with action targeting there almost always is one.
    if not (switch.hoverAt and GetTime() - switch.hoverAt < HOVER) then return true end
    enemy, attackable = Enemy("mouseover")
    return not (enemy and Near("mouseover", yards, attackable))
end

-- A second after a switch: did its kind come on? Without exactly one finder on, no verdict.
local function Verdict(now)
    local kind = ns.Finders()
    if kind then switch.kind = kind end -- so a late tracking event isn't taken for one by hand
    if kind == switch.pending.kind then
        switch.failures = 0
    elseif kind then
        switch.failures = switch.failures + 1
        if switch.failures >= 2 then switch.stoppedUntil, switch.failures = now + STOP, 0 end
    end
    switch.pending = nil
end

-- Every frame with the switch on: adds the way (yards or seconds) since the last tick where
-- switching is allowed, and switches once it reaches the goal.
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
    if switch.pending and now >= switch.pending.at + ns.SWITCH_WAIT then Verdict(now) end
    if Moving() and Allowed() then
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
local UNIT_EVENTS = { "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_STOP" }
local EVENTS = { "MINIMAP_UPDATE_TRACKING", "PLAYER_MOUNT_DISPLAY_CHANGED", "UPDATE_MOUSEOVER_UNIT",
    "SPELLS_CHANGED", "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED" }
-- Events after which your spells may reach differently: the spell checks are built again.
local SPELLBOOK = { SPELLS_CHANGED = true, TRAIT_CONFIG_UPDATED = true, PLAYER_TALENT_UPDATE = true,
    CHARACTER_POINTS_CHANGED = true }

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
    if on then
        switch.mounted = IsSet(IsMounted()) -- a secret counts as not mounted
        switch.kind = ns.Finders()
        ladderDirty = true -- the spellbook events weren't registered while it was off
        RequestItems()
    end
    if not on then switch.way, switch.pending, switch.lastTick, switch.hoverAt = 0, nil, nil, nil end
end

-- Your own spells' events: where their spell ID is in the payload.
local CASTS = { UNIT_SPELLCAST_SENT = 4, UNIT_SPELLCAST_SUCCEEDED = 3, UNIT_SPELLCAST_STOP = 3,
    UNIT_SPELLCAST_FAILED = 3, UNIT_SPELLCAST_INTERRUPTED = 3, UNIT_SPELLCAST_CHANNEL_STOP = 3 }

local function Handle(event, arg3, arg4)
    if CASTS[event] then
        -- Any spell but the finders' starts the pause, a secret one too.
        local spellID = arg3
        if CASTS[event] == 4 then spellID = arg4 end -- (no and/or: it may be secret)
        local kind = not issecretvalue(spellID) and FINDERS[spellID]
        if kind ~= "herbs" and kind ~= "ore" then switch.castAt = GetTime() end
    elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        local mounted = IsSet(IsMounted())
        if switch.mounted and not mounted then switch.castAt = GetTime() end -- dismounted
        switch.mounted = mounted
        ns.SwitchReset() -- mounting or dismounting ends a stop
    elseif SPELLBOOK[event] then
        ladderDirty = true
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        switch.hoverAt = GetTime() -- a unit only counts just after the mouse moved onto it
    elseif event == "MINIMAP_UPDATE_TRACKING" then
        -- Another herbs or ore finder, and not NodeSight's switch: one by hand. The next needs a
        -- scan of that kind and a new way. Other tracking changes (creatures, treasure) don't count.
        local kind = ns.Finders()
        if not switch.pending and kind ~= switch.kind then
            ns.turns.scanned, switch.way = false, 0
            ns.SwitchReset()
        end
        switch.kind = kind
    elseif event == "PLAYER_ENTERING_WORLD" then
        switch.way, switch.lastTick = 0, nil -- a loading screen is no way
        switch.kind = ns.Finders() -- the finder may have changed meanwhile
        switch.mounted = IsSet(IsMounted()) -- it may have changed meanwhile (a secret counts as not mounted)
        ns.SwitchReset()
        ladderDirty = true -- your spells' reach may have changed
    end
end

-- An error in a handler would come again at every cast: report it once and stop
-- the switch until /reload. Only the unmutes run on.
events:SetScript("OnEvent", function(_, event, _, _, arg3, arg4)
    if event == "PLAYER_LOGOUT" then
        Unmute() -- also on a /reload: the timers end with the UI
        return
    end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then CastDone(arg3) end
    if switch.stopped then return end
    if not xpcall(Handle, geterrorhandler(), event, arg3, arg4) then switch.stopped = true end
end)
