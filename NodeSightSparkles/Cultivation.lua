-- The Tauren racial Cultivation: is it ready for a herb, and which herbs this session
-- were already cultivated. Sparkles.lua puts the racial's icon over a herb when
-- CanCultivate says yes; this file draws the icon and refreshes the plates when the
-- answer may change.
--
-- In order: CultivationOn, CultivationReady, CanCultivate, the icon, the cultivated set,
-- refreshing.

local _, ns = ...

local cos, pi = math.cos, math.pi

-- 20552 is the racial you know and cast, instant; it casts 1312643, which takes 3 seconds,
-- cultivates the herb and carries the 15-minute cooldown (they share a cooldown category).
-- Only 1312643's success counts: that cast can still be interrupted.
local CULTIVATION = 20552
local CASTS = { [1312643] = true }
local GLOBAL_COOLDOWN = 1.5 -- a cooldown this short is only the global cooldown
local TIMER_EXTRA = 0.1 -- the refresh at the end of the cooldown comes this much later
local REGEN_RETRY = 1 -- seconds after combat for one more look at a cooldown still secret

-- Herbs cultivated this session, by GUID (cleared by /reload).
local cultivated = {}
local timerPending = false
local lastReady -- CultivationReady's answer at the last refresh
local lastOn -- CultivationOn's answer at the last SPELLS_CHANGED

-- Is a value readable (not secret)?
local function Readable(value)
    return not issecretvalue(value)
end

-- Is Cultivation in your spellbook? IsPlayerSpell only where C_SpellBook is missing (it is
-- a deprecated fallback in Forever).
local function Known()
    local book, bank = C_SpellBook, Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if book and book.IsSpellKnown and bank then return book.IsSpellKnown(CULTIVATION, bank) end
    if IsPlayerSpell then return IsPlayerSpell(CULTIVATION) end
    return false
end

-- Switch on and Cultivation known, and not passive (Retail's Cultivation is a passive with
-- no cooldown to watch)?
local function CultivationOn()
    if not (ns.db and ns.db.cultivation) then return false end
    local known = Known()
    if not Readable(known) or known ~= true then return false end
    local passive = C_Spell and C_Spell.IsSpellPassive and C_Spell.IsSpellPassive(CULTIVATION)
    return Readable(passive) and not passive
end

-- Cultivation's cooldown as C_Spell.GetSpellCooldown gives it, or from the global
-- GetSpellCooldown (start, duration, enabled) where a client has no C_Spell one.
local function Cooldown()
    if C_Spell and C_Spell.GetSpellCooldown then return C_Spell.GetSpellCooldown(CULTIVATION) end
    if not GetSpellCooldown then return nil end
    local start, duration, enabled = GetSpellCooldown(CULTIVATION)
    if not Readable(start) or start == nil then return nil end
    return { startTime = start, duration = duration, isEnabled = enabled }
end

-- Is the cooldown over (only the global cooldown counts as over)? If not, also the
-- seconds left, or nil if unknown. A secret or missing cooldown is not ready.
local function CultivationReady()
    local cooldown = Cooldown()
    if not Readable(cooldown) or type(cooldown) ~= "table" then return false, nil end
    local duration, active = cooldown.duration, cooldown.isActive
    local recover, start = cooldown.timeUntilEndOfStartRecover, cooldown.startTime
    if not (Readable(duration) and Readable(active) and Readable(recover) and Readable(start)) then return false, nil end
    if type(duration) == "number" and duration <= GLOBAL_COOLDOWN then return true end
    if active == false then return true end
    local left = recover
    if left == nil and type(start) == "number" and type(duration) == "number" then
        left = start + duration - GetTime()
    end
    if type(left) ~= "number" then return false, nil end
    if left <= 0 then return true end
    return false, left
end

-- Can you cultivate this herb now? The level must be a fifth of the herb's Herbalism
-- value (1 if unknown). A missing or secret GUID can't be excluded.
local function CanCultivate(name, guid)
    if not CultivationOn() or not CultivationReady() then return false end
    if not Readable(name) then return false end
    local level = UnitLevel("player")
    if not Readable(level) or type(level) ~= "number" then return false end
    local need = name and ns.NodeSkill(name, "herbs") or 1
    if level * 5 < need then return false end
    return not (Readable(guid) and guid ~= nil and cultivated[guid])
end

-- The icon: the racial's icon, round, in a thin green ring, pulsing, laid opaque over the
-- game's interact icon on the herb. It is bigger and keeps its size (no camera zoom
-- scale), so that icon doesn't show.
local ICON_FILE = 133938 -- Cultivation's icon, where C_Spell.GetSpellTexture is missing
local ROUND = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local ICON_SIZE, RING_SIZE = 22, 26
local RING_R, RING_G, RING_B = 0.35, 0.85, 0.35
local OVER_GAME_ICON = 2 -- frame levels above the game's interact icon
local CROP = 0.08 -- the border painted into a spell icon, cut off at each side
-- One pulse in PULSE seconds: size from 1 up to 1.08 times and back.
local PULSE, PULSE_GROW = 1.6, 0.08

local icons, spareIcons = {}, {} -- plate: its icon frame; frames to reuse

-- Cuts a texture round.
local function Round(frame, texture)
    local mask = frame:CreateMaskTexture()
    mask:SetTexture(ROUND, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(texture)
    texture:AddMaskTexture(mask)
end

-- OnUpdate: the pulse, in the textures' size, so the icon stays centered.
local function Pulse(frame, elapsed)
    frame.clock = (frame.clock + elapsed) % PULSE
    local up = (1 - cos(2 * pi * frame.clock / PULSE)) / 2 -- 0 to 1 and back
    local grow = 1 + PULSE_GROW * up
    frame.ring:SetSize(RING_SIZE * grow, RING_SIZE * grow)
    frame.icon:SetSize(ICON_SIZE * grow, ICON_SIZE * grow)
end

-- No parent in CreateFrame (see Sparkles.lua's NewSparkles); the plate is set as parent.
local function NewIcon()
    local frame = CreateFrame("Frame")
    frame:Hide()
    frame:SetSize(RING_SIZE, RING_SIZE)
    local ring = frame:CreateTexture(nil, "ARTWORK")
    ring:SetColorTexture(RING_R, RING_G, RING_B)
    ring:SetPoint("CENTER", frame, "CENTER")
    Round(frame, ring)
    local icon = frame:CreateTexture(nil, "ARTWORK", nil, 1) -- on the ring
    icon:SetPoint("CENTER", frame, "CENTER")
    icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
    Round(frame, icon)
    frame:SetAlpha(1)
    frame:SetScale(1)
    frame.ring, frame.icon = ring, icon
    frame:SetScript("OnUpdate", Pulse) -- (only while shown)
    return frame
end

-- The racial's icon on the icon frame.
local function SetIconTexture(frame)
    local texture = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(CULTIVATION)
    if not Readable(texture) or texture == nil then texture = ICON_FILE end
    frame.icon:SetTexture(texture)
end

-- Shows the icon on a plate (over its game interact icon), or updates it there.
local function ShowCultivation(namePlate)
    local frame = icons[namePlate]
    if not frame then
        frame = table.remove(spareIcons) or NewIcon()
        frame:SetParent(namePlate)
        icons[namePlate] = frame
        frame.clock = 0
    end
    SetIconTexture(frame)
    local soft = namePlate.UnitFrame.SoftTargetFrame
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", soft.Icon, "CENTER", 0, 0)
    local level = soft:GetFrameLevel()
    if Readable(level) and type(level) == "number" then frame:SetFrameLevel(level + OVER_GAME_ICON) end
    Pulse(frame, 0)
    frame:Show()
end

-- The icon for the sparkle window's preview, hidden: on parent, centered on the game's
-- icon there (a texture), at its size and pulsing as in the world.
local function PreviewIcon(parent, gameIcon)
    local frame = NewIcon()
    frame:SetParent(parent)
    frame:SetPoint("CENTER", gameIcon, "CENTER", 0, 0)
    frame.clock = 0
    SetIconTexture(frame)
    Pulse(frame, 0)
    return frame
end

-- Takes the icon off a plate and keeps its frame as a spare.
local function HideCultivation(namePlate)
    local frame = icons[namePlate]
    if not frame then return end
    icons[namePlate] = nil
    frame:Hide()
    frame:ClearAllPoints()
    frame:SetParent(nil)
    spareIcons[#spareIcons + 1] = frame
end

-- With the switch on: refreshes the plates, and once more at the end of a running
-- cooldown (one timer at a time).
local function Refresh()
    if not (ns.db and ns.db.cultivation) then return end
    if ns.UpdateAll then ns.UpdateAll() end
    local on = CultivationOn()
    local ready, left = false, nil
    if on then ready, left = CultivationReady() end
    lastReady = ready
    if timerPending or not on or ready or not left then return end
    timerPending = true
    C_Timer.After(left + TIMER_EXTRA, function()
        timerPending = false
        Refresh()
    end)
end

-- The herb you just cultivated, or tried to: the soft interact target.
local function Remember()
    local guid = UnitGUID("softinteract")
    if not Readable(guid) or guid == nil or cultivated[guid] then return end
    cultivated[guid] = true
    Refresh()
end

local events = CreateFrame("Frame")
events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
-- PLAYER_REGEN_ENABLED: Forever keeps cooldowns secret in combat. That takes the icon off
-- and stops a timer that fires in combat from scheduling again, so check at the end of combat.
for _, event in ipairs({ "UI_ERROR_MESSAGE", "SPELL_UPDATE_COOLDOWN", "SPELLS_CHANGED", "PLAYER_LEVEL_UP",
    "PLAYER_REGEN_ENABLED", "NAME_PLATE_UNIT_REMOVED" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if Readable(unit) and unit == "player" and Readable(spellID) and CASTS[spellID] then Remember() end
    elseif event == "UI_ERROR_MESSAGE" then
        local _, message = ...
        local already = SPELL_FAILED_CUSTOM_ERROR_2613 -- "That herb has already been cultivated."
        if Readable(message) and already ~= nil and message == already then Remember() end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        -- The plate goes: its icon too (Sparkles.lua's Update doesn't see a plate go).
        local unit = ...
        if not next(icons) or not Readable(unit) or type(unit) ~= "string" then return end
        local namePlate = C_NamePlate.GetNamePlateForUnit(unit)
        if namePlate then HideCultivation(namePlate) end
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        -- (every global cooldown: the plates only when Cultivation's readiness changes)
        if CultivationOn() and (CultivationReady()) ~= lastReady then Refresh() end
    elseif event == "SPELLS_CHANGED" then
        -- The racial known now, or no longer: the interact setup depends on it.
        local on = CultivationOn()
        if on ~= lastOn then
            local was = lastOn
            lastOn = on
            if (on or was ~= nil) and ns.Setup then ns.Setup() end
        end
        Refresh()
    elseif event == "PLAYER_LEVEL_UP" then
        -- (UnitLevel can still give the old level in the event: a frame later)
        if ns.db and ns.db.cultivation then C_Timer.After(0, Refresh) end
    else -- PLAYER_REGEN_ENABLED
        Refresh()
        -- The cooldown may still be secret for a moment: one more look a second later.
        if CultivationOn() then
            local ready, left = CultivationReady()
            if not ready and not left then C_Timer.After(REGEN_RETRY, Refresh) end
        end
    end
end)

-- What the other files use of this one (and the tests: the spells, the set, CultivationReady).
ns.CULTIVATION, ns.CULTIVATION_CASTS, ns.cultivated = CULTIVATION, CASTS, cultivated
ns.CultivationOn, ns.CultivationReady, ns.CanCultivate = CultivationOn, CultivationReady, CanCultivate
ns.ShowCultivation, ns.HideCultivation, ns.cultivationIcons = ShowCultivation, HideCultivation, icons
ns.CultivationRefresh = Refresh -- (the switch's settings, after it changes)
ns.CultivationPreviewIcon = PreviewIcon -- (the sparkle window)
