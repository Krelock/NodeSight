-- NodeSight's sparkles on the herb or ore in front of you. They sit on the
-- nameplate of the game's soft interact target, so while sparkles are on the
-- interact CVars are turned on and Blizzard's object plates are hidden (unless
-- the game's icons are kept).
--
-- Sections: Telling herbs and ore apart, Sparkles, Nameplates, Interact detection.

local _, ns = ...

local ipairs, pairs = ipairs, pairs
local random = math.random

-- Any sparkles on? Only then does the addon touch interact settings or plates.
local function SparklesOn()
    return ns.db.herbs or ns.db.ore or ns.db.others
end

-- The gathering nodes' sparkle (world/skillactivated/tradeskillnodes/sparkle.blp).
local PICTURE = 984391

-- Each sparkle is a body plus a smaller, lighter core.
local CORE = 0.45 -- core size relative to the body
local CORE_LIGHT = 0.6 -- how much lighter the core's tint is

-- Blizzard plates we hid (alpha 0), keyed by frame.
local hidden = {}
-- Sparkle frames by plate, and spares to reuse.
local sparkles = {}
local spare = {}

---------------------------------------------------------------------------
-- Telling herbs and ore apart
---------------------------------------------------------------------------
-- By the name of the interact icon's texture or atlas: "herb" or "mine".

local function HasName(name, a, b)
    if issecretvalue(name) or type(name) ~= "string" then return false end
    name = name:lower()
    return name:find(a, 1, true) ~= nil or (b ~= nil and name:find(b, 1, true) ~= nil)
end

-- "herbs", "ore", "others", or "plain" (never sparkles: guild vault, mailbox,
-- chairs, doors). A hidden icon counts as "others".
local function Kind(icon)
    if not icon:IsShown() then return "others" end
    local texture, atlas = icon:GetTexture(), icon:GetAtlas()
    if HasName(texture, "herb") or HasName(atlas, "herb") then return "herbs" end
    if HasName(texture, "mine", "mining") or HasName(atlas, "mine", "mining") then return "ore" end
    if HasName(texture, "buy") or HasName(atlas, "buy") then return "plain" end
    if HasName(texture, "mail") or HasName(atlas, "mail") then return "plain" end
    if HasName(texture, "questinteract") or HasName(atlas, "questinteract") then return "others" end
    if HasName(texture, "interact") or HasName(atlas, "interact") then return "plain" end
    return "others"
end

-- With Interact Key Icons set to None the plate icon stays hidden, so the
-- object's cursor is read onto our own texture instead (SetUnitCursorTexture).
local probe

local function ObjectKind(unit, icon)
    if icon:IsShown() then return Kind(icon) end
    if not SetUnitCursorTexture then return "others" end
    local picked = UnitIsUnit(unit, "softinteract")
    if not picked or issecretvalue(picked) then return "others" end
    if not probe then probe = CreateFrame("Frame"):CreateTexture() end
    if not SetUnitCursorTexture(probe, unit, nil, true, true) then return "others" end
    return Kind(probe)
end

---------------------------------------------------------------------------
-- Sparkles
---------------------------------------------------------------------------

local function PlaceTexture(frame, texture, size, x, y)
    texture:SetSize(size, size)
    texture:ClearAllPoints()
    texture:SetPoint("CENTER", frame, "CENTER", x, y)
end

-- Moves a sparkle to a random spot in the area.
local function Place(frame, part)
    local size = ns.db.size
    local s = size * (0.2 + 0.2 * random())
    local x, y = (random() - 0.5) * (frame.wide or size), (random() - 0.5) * (frame.tall or size)
    PlaceTexture(frame, part.texture, s, x, y)
    PlaceTexture(frame, part.core, s * CORE, x, y)
end

-- The color swatch's "aarrggbb" as 0-1 RGB; white for anything else.
local function RGB(color)
    local r, g, b = tostring(color):match("^%x%x(%x%x)(%x%x)(%x%x)$")
    if not r then return 1, 1, 1 end
    return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
end

-- Tints a sparkle. A color puts the alpha back to 1, so it goes to 0 again: a sparkle
-- is unseen until its twinkle fades it in.
local function ApplyColor(part)
    if part.color ~= ns.db.sparkleColor then
        part.color = ns.db.sparkleColor
        local r, g, b = RGB(part.color)
        part.texture:SetVertexColor(r, g, b)
        part.core:SetVertexColor(r + (1 - r) * CORE_LIGHT, g + (1 - g) * CORE_LIGHT, b + (1 - b) * CORE_LIGHT)
        part.texture:SetAlpha(0)
        part.core:SetAlpha(0)
    end
end

-- A looping twinkle: grows and fades in while rising, then shrinks and fades out.
local function Twinkle(texture, time, delay)
    local group = texture:CreateAnimationGroup()
    group:SetLooping("REPEAT")
    group:SetToFinalAlpha(true)
    local fadeIn = group:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(time)
    fadeIn:SetOrder(1)
    fadeIn:SetStartDelay(delay)
    local growIn = group:CreateAnimation("Scale")
    growIn:SetScaleFrom(0.3, 0.3)
    growIn:SetScaleTo(1, 1)
    growIn:SetDuration(time)
    growIn:SetOrder(1)
    growIn:SetStartDelay(delay) -- start with the fade
    local fadeOut = group:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(time)
    fadeOut:SetOrder(2)
    local shrink = group:CreateAnimation("Scale")
    shrink:SetScaleFrom(1, 1)
    shrink:SetScaleTo(0.3, 0.3)
    shrink:SetDuration(time)
    shrink:SetOrder(2)
    local riseIn = group:CreateAnimation("Translation")
    riseIn:SetDuration(time)
    riseIn:SetOrder(1)
    riseIn:SetStartDelay(delay)
    local riseOut = group:CreateAnimation("Translation")
    riseOut:SetDuration(time)
    riseOut:SetOrder(2)
    return group, riseIn, riseOut
end

-- One sparkle: a body and a core, twinkling together.
local function NewSparkle(frame)
    local texture = frame:CreateTexture(nil, "OVERLAY")
    texture:SetTexture(PICTURE)
    texture:SetBlendMode("ADD")
    local core = frame:CreateTexture(nil, "OVERLAY", nil, 1) -- on top of the body
    core:SetTexture(PICTURE)
    core:SetBlendMode("ADD")
    local part = { texture = texture, core = core }
    -- Random speed so they don't pulse together.
    local time, delay = 0.5 + 0.7 * random(), random()
    local group, riseIn, riseOut = Twinkle(texture, time, delay)
    local coreGroup, coreRiseIn, coreRiseOut = Twinkle(core, time, delay)
    part.group, part.coreGroup = group, coreGroup
    -- New spot on every loop; drifts up a fifth of the area.
    local function Respawn()
        Place(frame, part)
        local rise = ns.db.size * 0.1
        riseIn:SetOffset(0, rise)
        riseOut:SetOffset(0, rise)
        coreRiseIn:SetOffset(0, rise)
        coreRiseOut:SetOffset(0, rise)
    end
    group:SetScript("OnLoop", Respawn)
    Respawn()
    return part
end

-- No parent in CreateFrame: with the gamepad UI on, the game hooks CreateFrame
-- and a frame made inside an open window taints it. SetParent isn't hooked.
local function NewSparkles()
    local frame = CreateFrame("Frame")
    frame:Hide()
    frame.parts = {}
    return frame
end

-- Puts the sparkle area on a plate and starts ns.db.count sparkles.
local function ShowSparkles(namePlate)
    local frame = sparkles[namePlate]
    if not frame then
        frame = table.remove(spare) or NewSparkles()
        frame:SetParent(namePlate)
        sparkles[namePlate] = frame
    end
    frame:SetSize(ns.db.size, ns.db.size)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", namePlate, "BOTTOM", 0, ns.db.height)
    local parts = frame.parts
    for i = 1, ns.db.count do
        local part = parts[i]
        if not part then
            part = NewSparkle(frame)
            parts[i] = part
        end
        ApplyColor(part)
        part.texture:Show()
        part.core:Show()
        if not part.group:IsPlaying() then part.group:Play() end
        if not part.coreGroup:IsPlaying() then part.coreGroup:Play() end
    end
    for i = ns.db.count + 1, #parts do
        parts[i].group:Stop()
        parts[i].coreGroup:Stop()
        parts[i].texture:Hide()
        parts[i].core:Hide()
    end
    frame:Show()
end

-- Stops a plate's sparkles and keeps the frame as a spare.
local function HideSparkles(namePlate)
    local frame = sparkles[namePlate]
    if not frame then return end
    frame:Hide()
    for _, part in ipairs(frame.parts) do
        part.group:Stop()
        part.coreGroup:Stop()
    end
    frame:ClearAllPoints()
    frame:SetParent(nil)
    sparkles[namePlate] = nil
    spare[#spare + 1] = frame
end

---------------------------------------------------------------------------
-- Nameplates
---------------------------------------------------------------------------

local function SetHidden(unitFrame, hide)
    unitFrame:SetAlpha(hide and 0 or 1)
    hidden[unitFrame] = hide or nil
end

-- Nothing to do: sparkles off and nothing of ours on any plate.
local function Idle()
    return not SparklesOn() and not next(hidden) and not next(sparkles)
end

-- A plate got a unit or changed: hide object plates and sparkle by kind.
local function Update(unit)
    if Idle() then return end
    -- Options > Nameplates shows a preview plate with unit "preview", which the API
    -- rejects. Its unit frame comes from the shared pool, so unhide it.
    if not unit:find("^nameplate%d+$") then
        local scriptPlate = NamePlateDriverFrame:GetNamePlateForUnit(unit)
        local unitFrame = scriptPlate and scriptPlate.UnitFrame
        if unitFrame and hidden[unitFrame] then SetHidden(unitFrame, false) end
        return
    end
    local namePlate = C_NamePlate.GetNamePlateForUnit(unit)
    local unitFrame = namePlate and namePlate.UnitFrame
    if not unitFrame then return end -- forbidden (friendly in instances) or gone
    if UnitIsGameObject(unit) and SparklesOn() then
        -- Hide every object plate (alpha only); sparkle herbs, ore and, if set, others.
        if not ns.db.gameIcons then
            SetHidden(unitFrame, true)
        elseif hidden[unitFrame] then
            SetHidden(unitFrame, false)
        end
        if ns.db[ObjectKind(unit, unitFrame.SoftTargetFrame.Icon)] then ShowSparkles(namePlate) else HideSparkles(namePlate) end
    else
        if hidden[unitFrame] then SetHidden(unitFrame, false) end
        HideSparkles(namePlate)
    end
end

local function UpdateAll()
    if Idle() then return end
    for _, namePlate in ipairs(C_NamePlate.GetNamePlates()) do
        local unit = namePlate.UnitFrame and namePlate.UnitFrame.unit
        if unit then Update(unit) end
    end
end

-- After Blizzard sets up a plate, and when the soft interact target changes.
hooksecurefunc(NamePlateDriverFrame, "OnNamePlateAdded", function(_, unit) Update(unit) end)
hooksecurefunc(NamePlateDriverFrame, "OnSoftTargetUpdate", UpdateAll)

-- Blizzard resets the plate's alpha on every unit update.
hooksecurefunc("CompactUnitFrame_UpdateCenterStatusIcon", function(frame)
    if hidden[frame] then frame:SetAlpha(0) end
end)

---------------------------------------------------------------------------
-- Interact detection
---------------------------------------------------------------------------
-- The plates need Enable Interact Key, Interact Key Icons and a wider pick
-- range. Blizzard doesn't read these CVars through its cache, so setting them
-- doesn't taint. Changes wait out combat; old values come back when sparkles go off.

local RANGE = 30 -- yards (default 10)

local WANTED = {
    { "softTargetInteract", "3" },
    { "SoftTargetIconGameObject", "1" },
    { "SoftTargetInteractArc", "2" }, -- anywhere around you, not only in front
    { "SoftTargetInteractRange", tostring(RANGE) },
    -- NPC interact icons have no plate to hide, so shrink them to 0.
    { "SoftTargetWorldtextSize", "0", npcIcon = true },
}
local pendingSetup -- a change is waiting for combat to end

-- CVars can come back reformatted ("30.000000" for 30).
local function Same(a, b)
    return a == b or (tonumber(a) ~= nil and tonumber(a) == tonumber(b))
end

-- Restores one CVar, unless you changed it since.
local function PutBack(cvar)
    local old, mine = ns.db.saved[cvar], ns.db.applied[cvar]
    if old ~= nil and mine ~= nil and Same(C_CVar.GetCVar(cvar), mine) then C_CVar.SetCVar(cvar, old) end
    ns.db.saved[cvar], ns.db.applied[cvar] = nil, nil
end

-- Sets each needed CVar, saving the old value.
local function ApplySetup()
    for _, entry in ipairs(WANTED) do
        local cvar, value = entry[1], entry[2]
        local old = C_CVar.GetCVar(cvar)
        if entry.npcIcon and ns.db.gameIcons then
            PutBack(cvar)
        elseif old ~= nil and not Same(old, value) then
            C_CVar.SetCVar(cvar, value)
            -- Save only if the game accepted it, and only once.
            if Same(C_CVar.GetCVar(cvar), value) then
                if ns.db.saved[cvar] == nil then ns.db.saved[cvar] = old end
                ns.db.applied[cvar] = value
            end
        end
    end
end

local function RestoreSetup()
    for cvar in pairs(ns.db.saved) do PutBack(cvar) end
    for cvar in pairs(ns.db.applied) do ns.db.applied[cvar] = nil end
end

-- Applies or restores the CVars to match the sparkle settings.
local function Setup()
    if InCombatLockdown() then
        pendingSetup = true
        return
    end
    pendingSetup = nil
    if SparklesOn() then ApplySetup() else RestoreSetup() end
end

-- What the other files use of this one.
ns.sparkles, ns.hidden = sparkles, hidden
ns.ApplyColor, ns.NewSparkle, ns.NewSparkles = ApplyColor, NewSparkle, NewSparkles
ns.HideSparkles, ns.Setup, ns.UpdateAll = HideSparkles, Setup, UpdateAll
-- Is a Setup waiting for the end of combat?
function ns.SetupPending() return pendingSetup end
