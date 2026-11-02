-- NodeSight's finder switch: mutes the click of a switch.

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

local events = CreateFrame("Frame")
events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function(_, event, _, _, arg3)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        CastDone(arg3)
    elseif event == "PLAYER_LOGOUT" then
        Unmute() -- also on a /reload: the timers end with the UI
    end
end)
