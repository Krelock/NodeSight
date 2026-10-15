-- AI has done an awful job at commenting on the code. I'm going to try and fix
-- it up within the next few updates and put most of my mods on GitHub. I did
-- not expect so many people to be going through this and to be so interested!
-- Thank you to everyone trying my addons. I appreciate you all, this has made
-- my year.
--
-- NodeSight: the herbs and ore on your minimap as their own pictures, an arrow
-- to the nearest one, and twinkling sparkles around the herb or ore nearest to
-- you. Out of the box only the minimap pictures are on.
--
-- The sparkles: interactable objects (herbs, ore, chests, ...) get a nameplate
-- with Blizzard's interact icon and name when they're the game's "soft
-- interact" target (with Enable Interact Key and the interact icons for
-- objects on, see below). While any sparkles are on, this looks at those
-- plates: it hides Blizzard's plate on every object (alpha only), and on a
-- herb or ore puts sparkles on a frame of the addon's own, parented to the
-- plate so they follow the object and scale with distance like the plate does.
-- The addon never writes into Blizzard's frames.
--
-- The game doesn't tell addons where objects are, so only this one plate
-- exists at a time, and the sparkles sit where the plate is held: its bottom
-- edge is at the top of the object, so the sparkle area hangs below it (Height
-- moves it).
--
-- Those plates only exist while the game's interact detection is on, so while
-- any sparkles are on the addon turns on the game settings it needs (Enable
-- Interact Key, the interact icons for objects, and the range and facing of
-- the interact target) outside combat, remembers what they were, and puts them
-- back when the last sparkles are turned off. It never touches a setting
-- that's already right, and with no sparkles on it leaves the game's interact
-- detection, plates and icons alone.
--
-- Herbs and ore out of sight are found another way: the minimap's tracking
-- dots (see the minimap scan below) give each its picture on the minimap and
-- an arrow to the nearest one, whatever the sparkles are set to. Treasure
-- chests (the dwarves' Find Treasure) are found and shown the same way, and so
-- are rare beasts while a hunter's Track Beasts is on (Beta).
--
-- Settings (Options > AddOns > NodeSight, with the pages Symbols, Sparkles and
-- Beta under it): sparkles on herbs, on ore and on other objects, their color,
-- area, height and number; the minimap scan and whether it goes on in combat,
-- the arrow, the minimap symbols, their shape and size, rings of their own for
-- tin and iron, red for the ones above your skill, a sound for something new,
-- the scan detail, the size of the game's own dots, Find Herbs and Find
-- Minerals in turn as you move, rare beasts (Beta) and sparkles on far away
-- herbs and ore (Beta). Always on: what a herb or ore above your
-- skill needs, in the minimap's tooltip, and a gray symbol on one in a cave.
--
-- Blizzard reuses its nameplate frames between units, so each plate is set up
-- again every time Blizzard gives it a unit.
--
-- The file, in order (the big parts start with a heading between two lines of
-- dashes):
--   1. The settings' defaults, with what each one does.
--   2. Telling herbs and ore from other objects, by the interact icon.
--   3. Sparkles: the textures and their twinkle.
--   4. Nameplates: hiding Blizzard's plate and putting the sparkles on it.
--   5. Interact detection: the game settings the plates need.
--   6. The minimap scan. First what it needs to know: the names of herbs,
--      ore, chests and rare beasts, the skill each needs, learning new
--      nodes, switching finders, the tooltip line, the symbols and the
--      arrow. Then the scan itself: the grid of points, splitting a group
--      of points into dots, following the places between scans, and
--      pinning a dot's exact place.
--   7. Sparkles on far away herbs and ore (everything in the `world` table).
--   8. What's new: the patch notes dialog.
--   9. Settings panel.
--  10. Loading and the events, at the end.

local ADDON_NAME = ...

local ipairs, pairs = ipairs, pairs
local random = math.random

local defaults = {
    herbs = false, -- sparkles on herbs
    ore = false, -- sparkles on ore (mining nodes)
    others = false, -- sparkles on every other object with a plate
    arrow = false, -- an arrow to the nearest herb or ore found by the minimap scan
    mapIcons = true, -- the herb's or ore's map symbol on the minimap where the scan found one
    shape = 3, -- the symbols' shape: 1 square, 2 round, 3 round with the game's gold border
    oreRings = false, -- tin's and iron's symbols get rings of their own (green and rust) in place of the gold one (see oreRing)
    iconSize = 11, -- the symbols' width and height
    hard = true, -- a symbol is red when the herb or ore needs more skill than you have
    sound = false, -- a sound when a herb, ore, chest or rare beast shows up that wasn't there before (see FinishScan)
    scan = true, -- the minimap scan (the arrow and the symbols); off leaves only the sparkles
    scanDetail = 2, -- the minimap scan: 3 full, 2 lighter (fewer points, less often), 1 lightest (see DETAIL)
    switchFinders = false, -- Find Herbs and Find Minerals turned on in turn as you move (see Switch)
    switchYards = 15, -- how far you go between two of those switches (10 at the least: see the slider)
    combatScan = true, -- the minimap scan goes on in a fight (off: none in a fight, the symbols found before it stay)
    rares = true, -- a rare symbol of the game's on rare beasts while Track Beasts is on (Beta: see RARES)
    rareIcon = 2, -- which symbol that is (see ICONS.rares; 2 is the game's elite rare icon)
    worldMark = false, -- Beta: sparkles on far herbs and ore, on the game's own marker in the world (see world)
    dotScale = 100, -- the game's own dots on the minimap, in percent of their own size (see ApplyDotScale)
    sparkleColor = "ffffffff", -- what the sparkles are tinted, as the settings' color swatch keeps a color (white: the picture's own colors)
    size = 100, -- the sparkle area's width and height
    height = -60, -- moves the area up (or down) from the plate's bottom edge
    count = 9, -- sparkles twinkling at once
}
local db = defaults -- NodeSightDB once it's loaded

-- Are any sparkles on? Only then does the addon turn on the game's interact
-- detection (see Setup) and hide the game's own icon and name.
local function SparklesOn()
    return db.herbs or db.ore or db.others
end

-- The sparkle's picture: the gathering nodes' own sparkle, the one the herbs
-- have in Mists of Pandaria (the game file
-- world/skillactivated/tradeskillnodes/sparkle.blp, by ID).
local PICTURE = 984391

-- Each sparkle is a body with a smaller, brighter core on top, like the real
-- herb sparkles (measured in a screenshot of Mists of Pandaria's: rays about
-- RGB 234, 207, 98 and a core about 254, 255, 156). The body is tinted the
-- Sparkle color, the core the same color most of the way to white.
local CORE = 0.45 -- a core's size next to its body
local CORE_LIGHT = 0.6 -- how far a core's tint is from the body's toward white

-- Blizzard's nameplate frames made invisible, keyed by frame.
local hidden = {}
-- The addon's sparkle frame on each base nameplate that sparkles now, keyed by
-- plate, and the frames no plate is using: the next plate to sparkle takes one
-- of those, so there are only as many as have sparkled at the same time.
local sparkles = {}
local spare = {}

---------------------------------------------------------------------------
-- Telling herbs and ore from other objects: the interact icon on a herb is the
-- herb-gathering cursor, whose name has "Herb" in it (in game the texture is
-- "Cursor Crosshair_GatherHerbs_64"), and on ore the mining cursor, whose name
-- should have "Mine" in it (going by the game's file
-- interface/cursor/crosshair/mine.blp; not checked in game), as a texture name
-- or an atlas.
---------------------------------------------------------------------------

local function HasName(name, a, b)
    if issecretvalue(name) or type(name) ~= "string" then return false end
    name = name:lower()
    return name:find(a, 1, true) ~= nil or (b ~= nil and name:find(b, 1, true) ~= nil)
end

-- "herbs", "ore" or "others", for the object whose interact icon this is.
-- Blizzard hides the icon when the object stops being the soft interact
-- target, and leaves its texture as it was, so a hidden icon is "others".
-- A guild vault (the game's buy cursor, the bag a merchant has: in game its
-- texture is "Cursor Crosshair_UnableBuy_64"), a mailbox (the mail cursor) and
-- what is only used (the gear: chairs, doors, levers) are "plain": no setting
-- has that name, so they never sparkle. A quest's object has a cursor of its
-- own ("questinteract") and is "others".
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

-- The plate's own icon only shows when Interact Key Icons lets it (it stays
-- hidden with "None"), and then there'd be nothing to tell a herb by. So the
-- object's cursor is asked for on a texture of the addon's, the way Blizzard
-- does it for the icon, for the object that is the soft interact target. Low
-- priority icons are included (the game leaves them out when there's a loot or
-- quest effect on the object, unless Interact Key Icons is Show All).
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

-- Moves a sparkle (body and core) to a new spot in the area (each time it
-- starts again).
local function Place(frame, part)
    local size = db.size
    local s = size * (0.2 + 0.2 * random())
    local x, y = (random() - 0.5) * (frame.wide or size), (random() - 0.5) * (frame.tall or size)
    PlaceTexture(frame, part.texture, s, x, y)
    PlaceTexture(frame, part.core, s * CORE, x, y)
end

-- The red, green and blue (0 to 1) of a color as the settings' color swatch
-- keeps it: eight hex digits, the first two the alpha. White for anything else.
local function RGB(color)
    local r, g, b = tostring(color):match("^%x%x(%x%x)(%x%x)(%x%x)$")
    if not r then return 1, 1, 1 end
    return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
end

-- Sets a sparkle's tints to the chosen color, if they aren't already.
local function ApplyColor(part)
    if part.color ~= db.sparkleColor then
        part.color = db.sparkleColor
        local r, g, b = RGB(part.color)
        part.texture:SetVertexColor(r, g, b)
        part.core:SetVertexColor(r + (1 - r) * CORE_LIGHT, g + (1 - g) * CORE_LIGHT, b + (1 - b) * CORE_LIGHT)
    end
end

-- A looping twinkle on a texture: it grows and fades in while drifting up, then
-- shrinks and fades out. Returns the group and its two drifts.
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
    growIn:SetStartDelay(delay) -- same delay as the fade, so they start together
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

-- One sparkle on a frame: its body and its core, each with a twinkle of its
-- own.
local function NewSparkle(frame)
    local texture = frame:CreateTexture(nil, "OVERLAY")
    texture:SetTexture(PICTURE)
    texture:SetBlendMode("ADD")
    texture:SetAlpha(0)
    local core = frame:CreateTexture(nil, "OVERLAY", nil, 1) -- on top of the body
    core:SetTexture(PICTURE)
    core:SetBlendMode("ADD")
    core:SetAlpha(0)
    local part = { texture = texture, core = core }
    -- Each sparkle twinkles at its own speed so they don't pulse together; its
    -- core twinkles with its body.
    local time, delay = 0.5 + 0.7 * random(), random()
    local group, riseIn, riseOut = Twinkle(texture, time, delay)
    local coreGroup, coreRiseIn, coreRiseOut = Twinkle(core, time, delay)
    part.group, part.coreGroup = group, coreGroup
    -- A new spot each time it starts again; it drifts up a fifth of the area.
    local function Respawn()
        Place(frame, part)
        local rise = db.size * 0.1
        riseIn:SetOffset(0, rise)
        riseOut:SetOffset(0, rise)
        coreRiseIn:SetOffset(0, rise)
        coreRiseOut:SetOffset(0, rise)
    end
    group:SetScript("OnLoop", Respawn)
    Respawn()
    return part
end

-- No parent in CreateFrame: with the gamepad UI on, a frame made with a parent
-- inside an open window rebuilds that window's gamepad navigation under the
-- addon's taint. SetParent isn't hooked.
local function NewSparkles()
    local frame = CreateFrame("Frame")
    frame:Hide()
    frame.parts = {}
    return frame
end

-- Sizes and places the area on the plate and shows the first db.count sparkles.
local function ShowSparkles(namePlate)
    local frame = sparkles[namePlate]
    if not frame then
        frame = table.remove(spare) or NewSparkles()
        frame:SetParent(namePlate)
        sparkles[namePlate] = frame
    end
    frame:SetSize(db.size, db.size)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", namePlate, "BOTTOM", 0, db.height)
    local parts = frame.parts
    for i = 1, db.count do
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
    for i = db.count + 1, #parts do
        parts[i].group:Stop()
        parts[i].coreGroup:Stop()
        parts[i].texture:Hide()
        parts[i].core:Hide()
    end
    frame:Show()
end

-- Stops a plate's sparkles and takes their frame off the plate, for the next
-- plate that sparkles. (A plate that has none, or no plate at all: nothing.)
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

-- With no sparkles on (the way the addon comes) and nothing of its own left on
-- any plate (a plate it hid, a sparkle frame), nameplates are none of its
-- business: one then costs no call into the game.
local function Idle()
    return not SparklesOn() and not next(hidden) and not next(sparkles)
end

-- A nameplate got a unit, or something about it may have changed. On an
-- object's plate, while any sparkles are on, Blizzard's icon and name are
-- hidden and the sparkles put on or taken off by what kind of object it is;
-- any other plate the addon had hidden is shown again.
local function Update(unit)
    if Idle() then return end
    -- A plate of Blizzard's own UI (the preview on Options > Nameplates, sent
    -- through the same code with the unit "preview") is no unit's: the game
    -- takes its token for a name and refuses it with an error. Blizzard's driver
    -- knows its frame, and its unit frame comes from the pool every plate's
    -- does, so it may be one this addon hid: that one is shown again.
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
        -- While any sparkles are on, every object's plate goes; only herbs,
        -- ore and, if asked, other objects sparkle. Blizzard's plate only gets
        -- hidden by this addon, and only restored (below) if the addon hid it.
        SetHidden(unitFrame, true)
        if db[ObjectKind(unit, unitFrame.SoftTargetFrame.Icon)] then ShowSparkles(namePlate) else HideSparkles(namePlate) end
    else
        if hidden[unitFrame] then SetHidden(unitFrame, false) end
        HideSparkles(namePlate)
    end
end

-- Every plate on screen (the soft interact target changed, settings changed).
local function UpdateAll()
    if Idle() then return end
    for _, namePlate in ipairs(C_NamePlate.GetNamePlates()) do
        local unit = namePlate.UnitFrame and namePlate.UnitFrame.unit
        if unit then Update(unit) end
    end
end

-- Runs right after Blizzard gives a nameplate its unit frame, and when the
-- game's soft interact target changes (Blizzard sets the interact icons then).
hooksecurefunc(NamePlateDriverFrame, "OnNamePlateAdded", function(_, unit) Update(unit) end)
hooksecurefunc(NamePlateDriverFrame, "OnSoftTargetUpdate", UpdateAll)

-- Blizzard sets the plate's alpha back to 1 each time it updates the unit.
hooksecurefunc("CompactUnitFrame_UpdateCenterStatusIcon", function(frame)
    if hidden[frame] then frame:SetAlpha(0) end
end)

---------------------------------------------------------------------------
-- Interact detection, on while any sparkles are. The game settings the plates
-- need: Options > Controls > Enable Interact Key (softTargetInteract 3),
-- Options > Accessibility > Interact Key Icons (icons over objects), and how
-- far and in which directions the game picks an interact target (the default
-- is 10 yards, and only what's in front of you). None is read by Blizzard's
-- own code through its CVar cache, which would taint it. Setting them is
-- blocked in combat, so it waits. What a setting was is saved the first time
-- the addon changes it (NodeSightDB.saved), with what the addon set it to
-- (applied), and put back when the last sparkles are turned off, unless you
-- changed it since.
---------------------------------------------------------------------------

local RANGE = 30 -- how far away the game picks an interact target (yards; its own default is 10)

local WANTED = {
    { "softTargetInteract", "3" },
    { "SoftTargetIconGameObject", "1" },
    { "SoftTargetInteractArc", "2" }, -- anywhere around you, not only in front
    { "SoftTargetInteractRange", tostring(RANGE) },
    -- The icon the game draws over an NPC it picked (a vendor, a quest giver)
    -- has no nameplate, so there's nothing to hide it on: its size is a setting
    -- (the game's own is 32), and Blizzard's code doesn't read it.
    { "SoftTargetWorldtextSize", "0" },
}
local pendingSetup -- true while a change waits for the end of combat

-- The game gives some values back in another form ("30.000000" for 30).
local function Same(a, b)
    return a == b or (tonumber(a) ~= nil and tonumber(a) == tonumber(b))
end

-- One setting back to what it was, unless you changed it since.
local function PutBack(cvar)
    local old, mine = db.saved[cvar], db.applied[cvar]
    if old ~= nil and mine ~= nil and Same(C_CVar.GetCVar(cvar), mine) then C_CVar.SetCVar(cvar, old) end
    db.saved[cvar], db.applied[cvar] = nil, nil
end

-- Turns on each game setting the plates need that isn't right yet, noting what
-- it was.
local function ApplySetup()
    for _, entry in ipairs(WANTED) do
        local cvar, value = entry[1], entry[2]
        local old = C_CVar.GetCVar(cvar)
        if old ~= nil and not Same(old, value) then
            C_CVar.SetCVar(cvar, value)
            -- Remembered only if the game took it, and only the first time.
            if Same(C_CVar.GetCVar(cvar), value) then
                if db.saved[cvar] == nil then db.saved[cvar] = old end
                db.applied[cvar] = value
            end
        end
    end
end

-- Every setting the addon changed goes back to what it was.
local function RestoreSetup()
    for cvar in pairs(db.saved) do PutBack(cvar) end
    for cvar in pairs(db.applied) do db.applied[cvar] = nil end
end

-- The settings on while any sparkles are, and back as they were when none is.
local function Setup()
    if InCombatLockdown() then
        pendingSetup = true
        return
    end
    pendingSetup = nil
    if SparklesOn() then ApplySetup() else RestoreSetup() end
end

---------------------------------------------------------------------------
-- Herbs and ore out of sight: the minimap scan. With Find Herbs (or Find
-- Minerals) on, the minimap has a dot for every herb around you, far beyond
-- what the interact detection reaches or the screen shows. The game answers a
-- pretend mouse over any point of the minimap (Minimap:UpdateMouseoverAtPoint,
-- made for the controller's cursor, so only while the minimap's soft cursor is
-- on, and in screen pixels) with what its tooltip would say there
-- (C_TooltipInfo.GetMinimapMouseover): the names of the dots under it. So the
-- addon tries a grid of points over the minimap a few every frame (not in
-- combat, unless a setting says so), joins the neighbouring points that gave a name into one place per
-- dot (splitting a group that is too big for one dot), and works out from where
-- that is on the minimap which way it is and how far (C_Minimap.GetViewRadius is the yards from the middle to the edge). The
-- places get the map symbol on the minimap, and the nearest an arrow.
---------------------------------------------------------------------------

local STEP = 8 -- minimap units between the points tried (a dot answers within about 15)
local PER_FRAME = 60 -- points tried each frame
local WAIT = 0.5 -- seconds between one scan and the next
local NO_FINDER = 5 -- seconds between looks at whether a herb or ore finder is on, when none is
-- The spells Find Herbs and Find Minerals, and the dwarves' Find Treasure, and what each shows.
local FINDERS = { [2383] = "herbs", [2580] = "ore", [2481] = "treasure" }
FINDERS[1494] = "rares" -- the hunters' Track Beasts: a finder only while the Rare beasts setting is on (see RARES)
local MAX_ICONS = 40
local ICONS = { herbs = "Professions_Tracking_Herb", ore = "Professions_Tracking_Ore" }
-- A rare beast's symbol, by the Rare beast symbol setting: the one the game's own minimap has on a rare (in Retail,
-- where the game marks them itself), its elite one, or the star of the game's rare elites.
ICONS.rares = { "VignetteKill", "VignetteKillElite", "Rare-Elite-Star" }
local ICON_SIZE = 12 -- the size the gold border below is fitted to (the Symbol size setting's default is 11)
local NORMAL_DOTS = 100 -- the game's own dots as the game has them, in percent
-- The Symbol shape setting: square like the game's item icons (1), or cut to a
-- circle (2) with Blizzard's circle mask, the one on its target of target
-- portrait, or round with the game's own gold border over it (3, the default):
-- the ring around the minimap's tracking button and every minimap button
-- (Interface\Minimap\MiniMap-TrackingBorder).
local SHAPES = { "Square", "Round", "Round, gold ring" }
local CIRCLE = "CircleMask"
local GOLD_BORDER = 136430
-- That picture is drawn 50 wide around an 18 wide icon, its ring's middle 15.5
-- in from the left and 14.5 down from the top, with a hole about 20 across:
-- at 30 wide the hole fits the symbol, and this puts its middle on the symbol's.
local GOLD_SIZE, GOLD_X, GOLD_Y = 30, -9.3, 8.7
-- High visibility tin and iron (the oreRings setting): tin and iron look
-- alike, so their symbols get another ring of the game's in place of the gold
-- one, the Necrolord ring of the Covenant choice screen (weathered bronze),
-- half grayed (gray) and tinted by the ore: green for tin (as bright as a
-- tint can make it), a brown rust for iron (tints, by the symbol's picture;
-- a redder rust reads as copper on the minimap). Its
-- picture is 80 by 82 with a hole 58 across in its middle, so drawn width and
-- height times the symbol's size on the symbol's middle, the hole is the
-- symbol's edge. ok: the game has the picture (without it the gold ring stays).
local oreRing = {
    atlas = "CovenantChoice-Offering-Ability-Ring-Necrolord",
    width = 80 / 58, height = 82 / 58, gray = 0.5,
    tints = {
        ["Interface\\Icons\\inv_ore_tin_01"] = { 0.374, 1, 0.972 }, -- #43B3AE
        ["Interface\\Icons\\inv_ore_iron_01"] = { 0.82, 0.55, 0.36 },
    },
}
oreRing.ok = C_Texture.GetAtlasExists(oreRing.atlas)
local ARROW = "MiniMap-QuestArrow" -- the game's arrow that points up
local ARROW_SIZE = 40
-- A point's number is x * 1000 + y in steps; these are the eight points around it.
local AROUND = { -1001, -1000, -999, -1, 1, 999, 1000, 1001 }
local AROUND4 = { -1000, -1, 1, 1000 } -- and the four beside it

-- Herbs closer together than the game's answer area (about 15 minimap units
-- around each dot: zoomed out, 25 yards apart is close) answer as one big group
-- of points. A group with more points than one dot gives (see Single) is looked at
-- again with points FINE units apart over its whole area, and the dots it is
-- made of are worked out from its outline (see Fit).
local FINE = 3
local MAX_FINE = 900 -- finer points tried in one scan
local MIN_VOTES = 6 -- outline points a dot has to explain
local TOL = 2 -- how far from a circle an outline point may be (units)
local MAX_DISCS = 8
local hitRadius = 15 -- how far from a dot the game answers, in minimap units (adjusted as dots are fitted)

-- The most grid points one dot can give, depending on where the points fall
-- (the area of its circle over a point's area, and some for the edge: a dot
-- gives 4 to 9 points at 10 units apart): a group with more is more than one dot.
local function Single()
    return math.floor(math.pi * hitRadius ^ 2 / STEP ^ 2 + 0.6 * math.pi * hitRadius / STEP)
end

-- The scan detail setting: the minimap units between the points tried (a
-- dot answers within about 15, so these still find every one) and the seconds
-- between scans. Fewer points and fewer scans cost less, and place a dot a
-- little less exactly.
local DETAIL = { [3] = { 8, 0.5 }, [2] = { 10, 0.75 }, [1] = { 12, 1 } }
-- The setting is where the scan starts. Scans in a row that find no new herb
-- (SETTLE of them) ease it down one level, to 1 at the lowest; a new herb, or a
-- setting changed, brings it back to the setting.
local SETTLE = 4
local eased, quiet = 0, 0 -- levels eased down, and quiet scans since the last one

local scan -- the scan in progress
local wait = 0 -- seconds until the next scan
local hurry = 0 -- scans still to start at the full pace though you stand still (after loot, and while a rare beast is in sight)
local markers = {} -- the places the last scan found, nearest first
local grid, gridWidth -- the points a scan tries, for this minimap size
local tracker, arrow, arrowTexture, arrowText -- the frame that runs it, and the arrow
local mapFrame, mapIcons = nil, {} -- the symbols on the minimap
local empties = 0 -- scans in a row that found nothing (each makes the wait longer)
local emptyMap, emptyX, emptyY -- where you were at the last of them
-- Standing still, nothing comes in over the minimap's edge, so the scan can
-- rest. With nothing found the wait goes on growing; by places already known
-- it runs four times slower, and slower again with each scan started while you
-- still stand. Both up to SLEEP usual waits. Setting off, zooming the minimap
-- or changing what it tracks ends the rest at once (see the events at the end).
local SLEEP = 30
local REST = { [0] = 4, 4, 8, 16, SLEEP }
local rested = 0 -- scans in a row started while you stood still by known places (as far as REST goes)
local heard = {} -- what the Sound setting saw lately, each { name, map, mx, my (where it was first seen), at (when a scan last saw it) }
local shownText -- what the arrow's text says now
local arrowOn = false -- the arrow is shown
local turning -- the minimap turned with you when the places were found
-- Find Herbs and Find Minerals in turn (see Switch): the kind whose finder is on
-- ("herbs" or "ore", nil if that can't be told), where you were at the last
-- switch (map, x, y), whether a scan has finished since (scanned), and the kind
-- of node whose loot you have open (picked).
local turns = {}

-- What is a herb or ore is told by the name the minimap tooltip gives. Anything
-- else on the minimap (quest markers, NPCs, other tracking) is no node and is
-- left alone: a herb's name ends with the herb ("Stunted Silverleaf"), a mining
-- node's with "vein" or "deposit" ("Ooze Covered Silver Vein"), and neither has
-- a number or a colon in it (a quest's "Peacebloom 3/8").
local HERB_OTHER = { "doom weed", "gloom weed", "moonroot" } -- herb objects that give no item (the plain symbol)
-- What Find Treasure shows is told the same way: a chest's name ends with one
-- of these ("Large Solid Chest", "Buccaneer's Strongbox"). Its symbol is Find
-- Treasure's own icon. Anything else that tracking shows is learned the first
-- time you open one (see Learn).
local TREASURE = { "chest", "footlocker", "strongbox", "lockbox", "coffer", icon = "Interface\\Icons\\racial_dwarf_findtreasure" }
-- Rare beasts (the Rare beasts setting, Beta). A hunter's Track Beasts shows
-- every beast as the same dot, and the minimap's tooltip gives only a name:
-- these are the names of the beasts the game counts as rare or rare elite
-- (Wowhead's WoW Forever data, 116 of them, in lower case). Their dots get
-- a rare symbol of the game's (ICONS.rares) and the arrow, like a herb's.
-- English names, like the herb list.
--
-- Each has the zone it lives in, as GetRealZoneText names it (two zones with
-- a slash between them; true where Wowhead has none), and only counts there.
-- A hunter's pet keeps the name of the rare beast it was tamed from and is a
-- dot like any beast, and nothing on the minimap tells the two apart: but the
-- beast itself never leaves its zone, so the same name anywhere else is
-- somebody's pet.
local RARES = {
    ["abominable snowman"] = true, ["antilos"] = "Azshara", ["antilus the soarer"] = "Feralas",
    ["araga"] = "Alterac Mountains", ["arash-ethis"] = "Feralas", ["arcterris"] = "Winterspring",
    ["azzere the skyblade"] = "The Barrens", ["bannerwing survivor"] = true, ["barnabus"] = "Badlands", ["ben"] = true,
    ["big samras"] = "Hillsbrad Foothills", ["bjarn"] = "Dun Morogh", ["blightsculler"] = "Tirisfal Glades",
    ["blind hunter"] = "Razorfen Kraul", ["broken tooth"] = "Badlands", ["brontus"] = "The Barrens",
    ["carrodin"] = "Wetlands", ["chatter"] = "Redridge Mountains", ["clack the reaver"] = "Blasted Lands",
    ["coldrasp"] = "Tirisfal Glades", ["cranky benj"] = "Alterac Mountains", ["creepthess"] = "Hillsbrad Foothills",
    ["crystal fang"] = "Blackrock Spire", ["darkmist widow"] = "Dustwallow Marsh", ["dart"] = "Dustwallow Marsh",
    ["death flayer"] = "Durotar", ["death howl"] = "Felwood", ["deatheye"] = "Blasted Lands",
    ["deathmaw"] = "Burning Steppes", ["den'dralass"] = "Zephras Isle", ["dishu"] = "The Barrens",
    ["doomkin"] = "The Hinterlands", ["duskstalker"] = "Teldrassil", ["fernfeather"] = "Zephras Isle",
    ["ghost howl"] = "Mulgore/Thunder Bluff", ["ghostfang"] = "Dun Morogh", ["giggler"] = "Desolace",
    ["gorefang"] = "Silverpine Forest", ["greater firebird"] = "Tanaris", ["gretheer"] = "Silithus",
    ["grubthor"] = "Silithus", ["gruff"] = "Un'Goro Crater", ["grunter"] = "Blasted Lands",
    ["hayoc"] = "Dustwallow Marsh", ["heartrazor"] = "Thousand Needles", ["hissperak"] = "Desolace",
    ["humar the pridelord"] = "The Barrens", ["ironback"] = "The Hinterlands",
    ["ironeye the invincible"] = "Thousand Needles", ["jorul"] = "Dun Morogh", ["kackle"] = "Loch Modan",
    ["king mosh"] = "Un'Goro Crater", ["koartul"] = "Hillsbrad Foothills", ["krellack"] = "Silithus",
    ["krethis shadowspinner"] = "Silverpine Forest", ["kurmokk"] = "Stranglethorn Vale",
    ["large loch crocolisk"] = "Loch Modan", ["leech widow"] = "Wetlands", ["lord condar"] = "Loch Modan",
    ["lupos"] = "Duskwood", ["matriarch bristlefur"] = "Elwynn Forest", ["mazzranache"] = "Mulgore",
    ["mist howler"] = "Ashenvale", ["mokwa"] = "Mulgore", ["mongress"] = "Felwood", ["mowgh"] = "Teldrassil",
    ["murderous blisterpaw"] = "Tanaris", ["mystmane"] = "Zephras Isle", ["naraxis"] = "Duskwood",
    ["needletooth"] = "Arathi Highlands", ["nightscreech"] = "Teldrassil", ["old cliff jumper"] = "The Hinterlands",
    ["old grizzlegut"] = "Feralas", ["old ironfang"] = true, ["old rusthowl"] = true, ["old thornpaw"] = true,
    ["old vicejaw"] = "Silverpine Forest", ["olm the wise"] = "Felwood", ["oozeworm"] = "Dustwallow Marsh",
    ["pridewing patriarch"] = "Stonetalon Mountains", ["rak'shiri"] = "Winterspring", ["raluk"] = "Durotar",
    ["ravage"] = "Blasted Lands", ["ravasaur matriarch"] = "Un'Goro Crater", ["razormaw matriarch"] = "Wetlands",
    ["rekk'tilac"] = "Searing Gorge", ["ressan the needler"] = "Tirisfal Glades", ["rippa"] = "Stranglethorn Vale",
    ["ripscale"] = "Dustwallow Marsh", ["scale belly"] = "Stranglethorn Vale", ["scalebeard"] = "Azshara",
    ["sewer beast"] = "Stormwind City", ["shadowclaw"] = "Darkshore", ["shal'ma"] = "Durotar",
    ["shanda the spinner"] = "Loch Modan", ["slydris"] = "Zephras Isle", ["snapbeak the quick"] = "Zephras Isle",
    ["snarler"] = "Feralas", ["snort the heckler"] = "The Barrens", ["sorrow wing"] = "Stonetalon Mountains",
    ["spiteflayer"] = "Blasted Lands", ["sri'skulk"] = "Tirisfal Glades", ["strider clutchmother"] = "Darkshore",
    ["swiftmane"] = "The Barrens", ["takk the leaper"] = "The Barrens", ["the evalcharr"] = "Azshara",
    ["the rake"] = "Mulgore", ["the razza"] = "Feralas", ["thunderstomp"] = "The Barrens", ["timber"] = "Dun Morogh",
    ["uhk'loc"] = "Un'Goro Crater", ["ursol'lok"] = "Ashenvale", ["vile sting"] = "Thousand Needles",
    ["vultros"] = "Westfall", ["zaricotl"] = "Badlands", ["zopilote"] = "Tanaris",
}
local MAX_WORDS = 5

-- Lower case, with the curly apostrophe made straight.
local function Plain(name)
    return (name:lower():gsub("\226\128\153", "'"))
end

local function EndsWith(text, ending)
    return text:sub(-#ending) == ending
end

-- The inventory icon of what a node gives, by a word or two of its name (the
-- node's own name has more in it: "Stunted Silverleaf", "Ooze Covered Silver
-- Vein"). Interface/Icons file names, from Wowhead's forever item data. The
-- first that fits wins, so "dark iron" is before "iron deposit". A node that
-- fits none gets the plain herb or ore symbol.
local HERB_ICONS = {
    { "silverleaf", "inv_misc_herb_10" }, { "mageroyal", "inv_jewelry_talisman_03" },
    { "peacebloom", "inv_misc_flower_02" }, { "earthroot", "inv_misc_herb_07" },
    { "briarthorn", "inv_misc_root_01" }, { "swiftthistle", "inv_misc_herb_04" },
    { "bruiseweed", "inv_misc_herb_01" }, { "steelbloom", "inv_misc_flower_01" },
    { "kingsblood", "inv_misc_herb_03" }, { "liferoot", "inv_misc_root_02" },
    { "khadgar's whisker", "inv_misc_herb_08" }, { "grave moss", "inv_misc_dust_02" },
    { "fadeleaf", "inv_misc_herb_12" }, { "wintersbite", "inv_misc_flower_03" },
    { "stranglekelp", "inv_misc_herb_11" }, { "goldthorn", "inv_misc_herb_15" },
    { "firebloom", "inv_misc_herb_19" }, { "purple lotus", "inv_misc_herb_17" },
    { "arthas' tears", "inv_misc_herb_13" }, { "sungrass", "inv_misc_herb_18" },
    { "blindweed", "inv_misc_herb_14" }, { "ghost mushroom", "inv_mushroom_08" },
    { "gromsblood", "inv_misc_herb_16" }, { "dreamfoil", "inv_misc_herb_dreamfoil" },
    { "golden sansam", "inv_misc_herb_sansamroot" }, { "mountain silversage", "inv_misc_herb_mountainsilversage" },
    { "plaguebloom", "inv_misc_herb_plaguebloom" }, { "icecap", "inv_misc_herb_icecap" },
    { "black lotus", "inv_misc_herb_blacklotus" }, { "hive thistle", "inv_misc_spineleaf-_01" },
    { "demonsage", "inv_misc_herb_heartblossom" }, { "death lotus", "inv_nulllotus_void" },
    { "marefoil", "item_herbc" }, { "stranglevine", "inv_herbalism_70_nightmaredreamleaf" },
    { "frilled lichen", "inv_misc_food_109_honeylichen" }, { "rosecap", "inv_misc_herb_talandrasrose" },
}
local ORE_ICONS = {
    { "copper vein", "inv_ore_copper_01" }, { "tin vein", "inv_ore_tin_01" },
    { "silver vein", "inv_stone_16" }, { "dark iron", "inv_ore_mithril_01" },
    { "iron deposit", "inv_ore_iron_01" }, { "gold vein", "inv_ore_copper_01" },
    { "mithril deposit", "inv_ore_mithril_02" }, { "truesilver deposit", "inv_ore_truesilver_01" },
    { "thorium vein", "inv_ore_thorium_02" }, { "indurium", "inv_ore_mithril_01" },
    { "incendicite", "inv_ore_thorium_01" }, { "bloodstone", "inv_ore_thorium_01" },
}

-- "herbs", "ore" or "treasure", nil if the name is none of them.
local function NodeKind(name)
    name = Plain(name)
    if name:find("[%d:/]") then return nil end
    local words = 0
    for _ in name:gmatch("%S+") do words = words + 1 end
    if words > MAX_WORDS then return nil end
    if EndsWith(name, " vein") or EndsWith(name, " deposit") then return "ore" end
    for _, entry in ipairs(HERB_ICONS) do
        if EndsWith(name, entry[1]) then return "herbs" end
    end
    for _, other in ipairs(HERB_OTHER) do
        if EndsWith(name, other) then return "herbs" end
    end
    for _, ending in ipairs(TREASURE) do
        if EndsWith(name, ending) then return "treasure" end
    end
    return nil
end

-- The icon file of a node's name, nil if it isn't one of those.
local function NodeIcon(name)
    name = Plain(name)
    for pass = 1, 2 do -- (the herbs, then the ore)
        for _, entry in ipairs(pass == 1 and HERB_ICONS or ORE_ICONS) do
            if name:find(entry[1], 1, true) then return "Interface\\Icons\\" .. entry[2] end
        end
    end
end

-- The skill a herb or ore needs before you can gather it, by the node's whole
-- name (Wowhead's WoW Forever object data). The ones anyone with the profession
-- can gather aren't listed, and a node that isn't listed (a learned one, or any
-- of them in another language of the game) is never taken for too hard.
local SKILL_LINE = { herbs = 182, ore = 186 } -- Herbalism and Mining
local NEEDED = {
    herbs = {
        ["earthroot"] = 15, ["mageroyal"] = 50, ["briarthorn"] = 70, ["stranglekelp"] = 85,
        ["bruiseweed"] = 100, ["wild steelbloom"] = 115, ["grave moss"] = 120, ["kingsblood"] = 125,
        ["nightmare moss"] = 125, ["liferoot"] = 150, ["fadeleaf"] = 160, ["goldthorn"] = 170,
        ["khadgar's whisker"] = 185, ["wintersbite"] = 195, ["dreamroot"] = 205, ["firebloom"] = 205,
        ["purple lotus"] = 210, ["arthas' tears"] = 220, ["sungrass"] = 230, ["blindweed"] = 235,
        ["ghost mushroom"] = 245, ["gromsblood"] = 250, ["moonroot"] = 250, ["star lotus"] = 250,
        ["golden sansam"] = 260, ["dreamfoil"] = 270, ["mountain silversage"] = 280, ["plaguebloom"] = 285,
        ["icecap"] = 290, ["black lotus"] = 300,
    },
    ore = {
        ["tin vein"] = 65, ["incendicite mineral vein"] = 65, ["silver vein"] = 75,
        ["ooze covered silver vein"] = 75, ["lesser bloodstone deposit"] = 75, ["iron deposit"] = 125,
        ["cold iron deposit"] = 125, ["indurium mineral vein"] = 150, ["gold vein"] = 155,
        ["ooze covered gold vein"] = 155, ["mithril deposit"] = 175, ["ooze covered mithril deposit"] = 175,
        ["fool's gold vein"] = 175, ["truesilver deposit"] = 230, ["ooze covered truesilver deposit"] = 230,
        ["dark iron deposit"] = 230, ["small thorium vein"] = 245, ["ooze covered thorium vein"] = 245,
        ["starsilver vein"] = 245, ["greater moonstone formation"] = 245, ["rich thorium vein"] = 275,
        ["ooze covered rich thorium vein"] = 275, ["hakkari thorium vein"] = 275, ["heavy thorium vein"] = 300,
        ["small obsidian chunk"] = 305, ["large obsidian chunk"] = 305,
    },
    treasure = {}, -- (a chest needs no skill)
    rares = {}, -- (nor does a rare beast)
}
local TOO_HARD = { 1, 0.2, 0.2 } -- what the symbol of a node above your skill is tinted
local skills = {} -- your skills as last read (false: the game didn't say); emptied to have them read again
local professions = {} -- what the game calls Herbalism and Mining, as it said with the skill

-- Your Herbalism or Mining skill with what your race and gear add to it, nil if
-- the game doesn't say.
local function GatherSkill(kind)
    local info = C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID(SKILL_LINE[kind])
    if not info or issecretvalue(info) then return nil end
    local rank, bonus = info.rank, info.modifier
    if issecretvalue(rank) or issecretvalue(bonus) or not rank then return nil end
    local name = info.name
    if not issecretvalue(name) then professions[kind] = name end
    return rank + (bonus or 0)
end

-- Does this herb or ore need more skill than you have, and what does it need?
-- Your skill is asked for once a scan, and only when a node there needs any.
local function TooHard(name, kind)
    local need = NEEDED[kind][Plain(name)]
    if not need then return false end
    if skills[kind] == nil then skills[kind] = GatherSkill(kind) or false end
    local skill = skills[kind]
    return skill ~= false and need > skill, need
end

---------------------------------------------------------------------------
-- Learning nodes. The lists above have English names, and only the herbs and
-- ore known when they were written (and of what Find Treasure shows, only the
-- names that end like a chest's: the rest is learned when you open one with
-- Find Treasure on). A node they don't know (a new one, or any
-- of them in another language of the game) is learned the first time you
-- gather it: when the loot comes, the game says which object it came from, and
-- the loot itself says what kind of node that was, a herb if it gave herbs,
-- ore if it gave ore or stone (gems may come with either; anything else and
-- it was no node). The name is the object's, or failing that what your cast
-- was sent at. From then on the minimap scan knows that name, with the icon of
-- what the node gave most often. Every node you gather is noted, the ones the
-- lists know too (their icons come from the lists all the same). Kept for the
-- account (NodeSightDB.learned).
---------------------------------------------------------------------------

local TRADE_GOODS, HERB, METAL_AND_STONE, GEM = 7, 9, 7, 3 -- item classes, and trade goods' subclasses
local castTarget -- what your last cast was sent at (a name), if the game said
local lastSource -- the object the last loot looked at came from (each is looked at once)

-- Is a tracking on that shows herbs, ore or treasure (or just the one kind
-- asked for)? The finders are the spells Find Herbs, Find Minerals and Find
-- Treasure, and Track Beasts while the Rare beasts setting is on: with none
-- of them on, or on a character that has none (whatever else it tracks:
-- mailboxes, innkeepers), there is nothing to scan for. true if it can't tell.
local function FinderOn(kind)
    if not (C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo) then return true end
    for index = 1, C_Minimap.GetNumTrackingTypes() do
        local info = C_Minimap.GetTrackingInfo(index)
        if issecretvalue(info) then return true end
        if info then
            if issecretvalue(info.active) or issecretvalue(info.spellID) then return true end
            local shows = info.spellID and FINDERS[info.spellID]
            if shows == "rares" and not db.rares then shows = nil end -- (Track Beasts counts only with its setting on)
            if shows and info.active and (not kind or shows == kind) then return true end
        end
    end
    return false
end

-- "herbs", "ore" or "treasure" (learned ones too), "rares" for a rare beast
-- while that setting is on, nil if the name is none of them.
local function KindOf(name)
    if db.rares then
        local plain = Plain(name)
        local home = RARES[plain]
        -- Only in the zone it lives in (see RARES): the slashes keep a part
        -- of a zone's name from being taken for the zone.
        local zone = home and GetRealZoneText()
        if home == true or (type(zone) == "string" and ("/" .. home .. "/"):find("/" .. zone .. "/", 1, true)) then
            -- Not your own pet: a rare you tamed keeps its name.
            local pet = UnitName("pet")
            if not issecretvalue(pet) and (not pet or Plain(pet) ~= plain) then return "rares" end
        end
    end
    local known = db.learned and db.learned[Plain(name)]
    return known and known.kind or NodeKind(name)
end

-- The icon of a node's name: a file from the lists, or a learned one's. A
-- chest's is always the same. (A rare beast has none: ICONS has its symbols.)
local function IconOf(name, kind)
    if kind == "treasure" then return TREASURE.icon end
    local known = db.learned and db.learned[Plain(name)]
    return NodeIcon(name) or (known and known.icon)
end

-- Your cast was sent: at what, if anything.
local function NoteCast(target)
    castTarget = nil
    if issecretvalue(target) or type(target) ~= "string" or target == "" then return end
    castTarget = target
end

-- What kind of node gives this loot, and the herbs or ore and stone in it as
-- { item, icon }: nil if a node wouldn't give it (money, or anything else).
local function LootKind()
    local kind, gave = nil, {}
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        if not link or issecretvalue(link) then return nil end
        local item, _, _, _, icon, class, subclass = C_Item.GetItemInfoInstant(link)
        local this = class == TRADE_GOODS and (subclass == HERB and "herbs" or subclass == METAL_AND_STONE and "ore") or nil
        if this then
            if kind and kind ~= this then return nil end
            kind = this
            gave[#gave + 1] = { item, icon }
        elseif class ~= GEM then
            return nil
        end
    end
    return kind, gave
end

-- The name of the object the loot came from.
local function SourceName(guid)
    local name = UnitNameFromGUID and UnitNameFromGUID(guid)
    if issecretvalue(name) or type(name) ~= "string" or name == "" or name == UNKNOWNOBJECT then name = castTarget end
    return name
end

-- The loot is there: if it came from a node, note what the node is called and
-- what it gave.
local function Learn()
    local guid = GetLootSourceInfo(1)
    if issecretvalue(guid) or type(guid) ~= "string" or guid == lastSource then return end
    lastSource = guid
    if guid:sub(1, 11) ~= "GameObject-" then return end
    local name = SourceName(guid)
    castTarget = nil
    local kind, gave = LootKind()
    turns.picked = kind -- (see Picked)
    if not name then return end
    local key = Plain(name)
    if not kind then
        -- No herb and no ore: with Find Treasure on, and a name that says
        -- nothing yet, it is one of the things that tracking shows.
        if not KindOf(name) and FinderOn("treasure") then db.learned[key] = { kind = "treasure", seen = {}, most = 0 } end
        return
    end
    local known = db.learned[key] or { seen = {}, most = 0 }
    known.kind = kind
    for _, pair in ipairs(gave) do
        local count = (known.seen[pair[1]] or 0) + 1
        known.seen[pair[1]] = count
        if count > known.most then known.most, known.icon = count, pair[2] end
    end
    db.learned[key] = known
end

-- The Scan detail setting's level (3 for a saved value that is none of the
-- levels).
local function SettingLevel()
    return DETAIL[db.scanDetail] and db.scanDetail or 3
end

-- STEP and WAIT for that level, less the levels eased down.
local function ApplyDetail()
    local level = DETAIL[math.max(1, SettingLevel() - eased)]
    STEP, WAIT = level[1], level[2]
    gridWidth = nil -- the points are worked out again
end

-- Is there anything to scan for: the scan is on, and so is something that uses
-- it.
local function Enabled()
    return db.scan and (db.arrow or db.mapIcons or db.sound or db.worldMark)
end

-- The way you face (radians counterclockwise from north), nil if it can't be read.
local function PlayerFacing()
    local facing = GetPlayerFacing()
    if issecretvalue(facing) then return nil end
    return facing
end

-- Where you are on the zone map: its id, your place on it (0 to 1, x to the east,
-- y to the south) and its width and height in yards. nil if the game won't say.
local function MapPosition()
    local map = C_Map.GetBestMapForUnit("player")
    if not map or issecretvalue(map) then return nil end
    local position = C_Map.GetPlayerMapPosition(map, "player")
    if not position or issecretvalue(position) then return nil end
    local x, y = position:GetXY()
    local width, height = C_Map.GetMapWorldSize(map)
    if issecretvalue(x) or issecretvalue(y) or not width or not height or width <= 0 or height <= 0 then return nil end
    return map, x, y, width, height
end

-- Have you gone more than 3 yards from where you were at the last empty scan?
-- (Walking counts: on foot you go about 5 yards between two scans, and that is
-- when a herb comes in over the minimap's edge.)
local function Moved(map, x, y, width, height)
    if not map or map ~= emptyMap then return true end
    local dx, dy = (x - emptyX) * width, (y - emptyY) * height
    return dx * dx + dy * dy > 9
end

-- Find Herbs and Find Minerals in turn (the Switch setting). The game shows
-- the dots of only one of them at a time, so the addon turns on the other one
-- each time you have gone db.switchYards from where it last did
-- (C_Minimap.SetTracking, which addon code is allowed to call). Only when the
-- game lists both and just one of them is on: with neither on, or both, the
-- choice is yours and nothing is switched. Never in combat (no scan starts
-- there), and a scan has to have finished between two switches. The symbols of
-- the kind that is off are kept meanwhile (see FinishScan), so both kinds are
-- on the minimap.
local SWITCH_WAIT = 1 -- seconds from a switch to the next scan (the game's dots take a moment to change)
local PICK_REACH = 10 -- yards: a kept symbol this near goes when you loot a node of its kind (see Picked)

-- The kind whose finder is on, and the other finder's place in the game's
-- list (nil if it isn't listed). Nothing if not just one of the two is on, or
-- the game won't say.
local function Finders()
    if not (C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo) then return nil end
    local on, off, active = nil, nil, 0
    for index = 1, C_Minimap.GetNumTrackingTypes() do
        local info = C_Minimap.GetTrackingInfo(index)
        if issecretvalue(info) then return nil end
        local shows = info and not issecretvalue(info.spellID) and FINDERS[info.spellID]
        if shows == "herbs" or shows == "ore" then -- (Find Treasure and Track Beasts are no part of this)
            if issecretvalue(info.active) then return nil end
            if info.active then
                on, active = shows, active + 1
            else
                off = index
            end
        end
    end
    if active ~= 1 then return nil end
    return on, off
end

-- A scan is about to start: turns on the other finder if you have gone far
-- enough. true if it did (the scan then waits for the dots to change).
local function Switch()
    local kind, other = Finders()
    turns.kind = kind
    if InCombatLockdown() then return false end -- (never in a fight, also when the scan goes on in one: each switch costs a global cooldown)
    if not (kind and other and C_Minimap.SetTracking) then return false end
    local map, x, y, width, height = MapPosition()
    if not map then return false end
    if map ~= turns.map then -- (another zone map: counted from here)
        turns.map, turns.x, turns.y = map, x, y
        return false
    end
    local dx, dy = (x - turns.x) * width, (y - turns.y) * height
    if not turns.scanned or dx * dx + dy * dy < db.switchYards ^ 2 then return false end
    turns.x, turns.y, turns.scanned = x, y, false
    C_Minimap.SetTracking(other, true)
    return true
end

-- A tooltip line without its color codes and inline pictures.
local function Clean(text)
    text = text:gsub("|A.-|a", ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return text:match("^%s*(.-)%s*$")
end

-- Is a color a gray (no hue, and darker than white)? The game has a herb's or
-- ore's name in gray in the minimap's tooltip when it is in a cave.
local function Gray(r, g, b)
    if issecretvalue(r) or issecretvalue(g) or issecretvalue(b) or not (r and g and b) then return false end
    return math.abs(r - g) < 0.1 and math.abs(g - b) < 0.1 and r < 0.9
end

-- The names in a tooltip line (it can hold several, one per row). The same few
-- lines come back all the time, so what was made of one is kept. A name with
-- a color of its own in the line (a color code) has in list.gray whether that
-- is a gray.
local lineNames, lineCount = {}, 0
local function NamesIn(text)
    local list = lineNames[text]
    if not list then
        list = {}
        for name in text:gmatch("[^\n]+") do
            local r, g, b = name:match("|c%x%x(%x%x)(%x%x)(%x%x)") -- (before Clean takes it out)
            name = Clean(name)
            if name ~= "" then list[#list + 1] = name end
            if r and name ~= "" then
                list.gray = list.gray or {}
                list.gray[#list] = Gray(tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255)
            end
        end
        if lineCount >= 300 then lineNames, lineCount = {}, 0 end
        lineNames[text] = list
        lineCount = lineCount + 1
    end
    return list
end

-- Notes that the point had these names: true, or "gray" where the game has
-- the name in gray (by a color of the name's own, else by the line's: `gray`).
local function Record(hits, text, point, gray)
    local list = NamesIn(text)
    for i, name in ipairs(list) do
        local set = hits[name]
        if not set then
            set = {}
            hits[name] = set
        end
        local own = list.gray and list.gray[i]
        if own == nil then own = gray end
        set[point] = own and "gray" or true
    end
end

-- The mouse over a herb or ore on the minimap: the game's tooltip names it, and
-- when it needs more skill than you have, a line under the name says what it
-- needs, worded and colored as the game's own tooltips are for an item you
-- can't use ("Requires Herbalism (15)" in red). Always on. The game fills that
-- tooltip again every frame the mouse is over a dot, so for it your skills are
-- read again once a second at most.
local SKILL_WAIT = 1
local skillsRead = 0 -- when your skills were last emptied for the tooltip
local said = {} -- the lines added to the tooltip this time (each once)

-- "Requires Herbalism (15)" for a herb or ore above your skill, nil for anything else.
local function Requirement(name)
    local kind = KindOf(name)
    if not kind then return nil end
    local hard, need = TooHard(name, kind)
    if not hard or not professions[kind] then return nil end
    return ITEM_MIN_SKILL:format(professions[kind], need)
end

local function OnMinimapTooltip(tooltip, data)
    local lines = not issecretvalue(data) and data.lines
    if not lines or issecretvalue(lines) then return end
    local now = GetTime()
    if now - skillsRead >= SKILL_WAIT then skills.herbs, skills.ore, skillsRead = nil, nil, now end
    if next(said) then wipe(said) end
    for _, line in ipairs(lines) do
        local text = line.leftText
        if text and not issecretvalue(text) then
            for _, name in ipairs(NamesIn(text)) do
                local requires = Requirement(name)
                if requires and not said[requires] then
                    said[requires] = true
                    tooltip:AddLine(requires, RED_FONT_COLOR:GetRGB())
                end
            end
        end
    end
end

-- (Its size comes with its first use: see ApplySize.)
local function NewIcon()
    local texture = mapFrame:CreateTexture(nil, "OVERLAY")
    return { texture = texture, hard = false, dim = false }
end

-- Cuts a symbol's texture (or its ring's) to a circle.
local function NewMask(region)
    local mask = mapFrame:CreateMaskTexture()
    mask:SetAtlas(CIRCLE)
    mask:SetAllPoints(region)
    region:AddMaskTexture(mask)
    return mask
end

-- The gold border is fitted to a symbol 12 across: with another size it grows
-- or shrinks with the symbol, and so does how far its corner is from the
-- symbol's middle. Tin's and iron's ring (icon.tint, see oreRing) hangs by its
-- middle on the symbol's.
local function SizeRing(icon)
    local scale = icon.size / ICON_SIZE
    icon.border:ClearAllPoints() -- (the two rings hang by different points)
    if icon.tint then
        icon.border:SetSize(icon.size * oreRing.width, icon.size * oreRing.height)
        icon.border:SetPoint("CENTER", icon.texture, "CENTER")
        return
    end
    icon.border:SetSize(GOLD_SIZE * scale, GOLD_SIZE * scale)
    icon.border:SetPoint("TOPLEFT", icon.texture, "CENTER", GOLD_X * scale, GOLD_Y * scale)
end

-- Gives a symbol the size that is set, and its border if it has one.
local function ApplySize(icon)
    icon.size = db.iconSize
    icon.texture:SetSize(icon.size, icon.size)
    if icon.border then SizeRing(icon) end
end

-- Gives a symbol a shape (the one that is set; a rare beast's is always the
-- plain one, see ShowMarkers). Its mask and its border are made the first time
-- it needs them, and kept.
local function ApplyShape(icon, shape)
    icon.shape = shape
    local ringed = shape == 3
    local round = shape == 2 or ringed
    if round ~= (icon.round or false) then
        icon.round = round
        if not round then
            icon.texture:RemoveMaskTexture(icon.mask)
        elseif icon.mask then
            icon.texture:AddMaskTexture(icon.mask)
        else
            icon.mask = NewMask(icon.texture)
        end
    end
    if ringed then
        if not icon.border then
            -- Over the symbol (a sublevel higher), which shows through its
            -- hole, and anchored to it, so it goes where the symbol goes.
            icon.border = mapFrame:CreateTexture(nil, "OVERLAY", nil, 1)
            icon.border:SetTexture(GOLD_BORDER)
            SizeRing(icon)
        end
        icon.ring = icon.border
        icon.ring:Show() -- (the symbol itself is shown right after this, if it isn't yet)
    elseif icon.ring then
        icon.ring:Hide()
        icon.ring = nil
    end
end

-- Where the arrow points: the nearest herb or ore you can gather (one that
-- needs more skill than you have is passed over, and so is one in a cave,
-- whose symbol is gray: you can't walk straight to that one), nil if there
-- is none.
local function Target()
    for _, marker in ipairs(markers) do
        if not marker.hard and not marker.dim then return marker end
    end
end

-- The symbols and the arrow's text follow the places found.
local function ShowMarkers()
    local target = db.arrow and Target()
    if target then -- (the arrow's text; turning the arrow on comes through here too)
        local text = target.yards and ("%s  %.0f yd"):format(target.name, target.yards) or target.name
        if text ~= shownText then
            shownText = text
            arrowText:SetText(text)
        end
    end
    for i = 1, MAX_ICONS do
        local marker = db.mapIcons and markers[i]
        local icon = mapIcons[i]
        if marker and not marker.far then
            icon = icon or NewIcon()
            mapIcons[i] = icon
            -- The node's own inventory icon, or the plain herb or ore symbol.
            local picture = marker.file or ICONS[marker.kind]
            if marker.kind == "rares" then picture = picture[db.rareIcon] end -- (the one that is set)
            if icon.picture ~= picture then
                icon.picture = picture
                if marker.file then
                    icon.texture:SetTexture(picture)
                    icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- without the icon's border
                else
                    icon.texture:SetAtlas(picture)
                end
            end
            if icon.size ~= db.iconSize then ApplySize(icon) end -- (before the shape: a new border takes the symbol's size)
            -- (A rare beast's symbol is the game's own picture as it is: no
            -- gold ring around it and not cut to a circle, whatever the shape
            -- that is set.)
            local shape = marker.kind == "rares" and 1 or db.shape
            if icon.shape ~= shape then ApplyShape(icon, shape) end
            -- Tin's and iron's own ring, with High visibility tin and iron on
            -- and the gold ring's shape: the gold ring's texture, given the
            -- other picture, size and place (see oreRing).
            local tint = icon.ring and db.oreRings and oreRing.ok and oreRing.tints[marker.file] or false
            local swap = not icon.tint ~= not tint -- (tin to iron is only another tint, told below)
            icon.tint = tint
            if swap then
                if tint then
                    icon.border:SetAtlas(oreRing.atlas)
                else
                    icon.border:SetTexture(GOLD_BORDER)
                end
                SizeRing(icon)
            end
            -- Red while it needs more skill than you have, and dark while the
            -- game has its name in gray (it is in a cave; always on): the
            -- picture in grays at half its brightness. Grays alone don't
            -- show on ore, whose picture is gray as it is.
            local hard = (db.hard and marker.hard) or false
            if icon.hard ~= hard or icon.dim ~= marker.dim then
                icon.hard, icon.dim = hard, marker.dim
                local shade = icon.dim and 0.5 or 1
                if hard then
                    icon.texture:SetVertexColor(TOO_HARD[1] * shade, TOO_HARD[2] * shade, TOO_HARD[3] * shade)
                else
                    icon.texture:SetVertexColor(shade, shade, shade)
                end
                icon.texture:SetDesaturated(icon.dim)
            end
            -- Its ring goes dark with it and loses its gold, or tin's or iron's
            -- tint. (Told here and not with the picture: the ring may only just
            -- have been made, shown again or given the other picture above, as
            -- it was when it was hidden.) look: dark, the tint, or as it is.
            local look = icon.dim or icon.tint or false
            if icon.ring and (icon.ringLook or false) ~= look then
                icon.ringLook = look
                if icon.tint and not icon.dim then
                    icon.ring:SetVertexColor(icon.tint[1], icon.tint[2], icon.tint[3])
                    icon.ring:SetDesaturation(oreRing.gray)
                else
                    local shade = icon.dim and 0.5 or 1
                    icon.ring:SetVertexColor(shade, shade, shade)
                    icon.ring:SetDesaturated(icon.dim)
                end
            end
            -- (Its one point set again replaces the old place: nothing to clear.)
            icon.texture:SetPoint("CENTER", mapFrame, "BOTTOMLEFT", marker.x, marker.y)
            if not icon.shown then
                icon.shown = true
                icon.texture:Show()
                if icon.ring then icon.ring:Show() end
            end
        elseif icon and icon.shown then
            icon.shown = false
            icon.texture:Hide()
            if icon.ring then icon.ring:Hide() end
        end
    end
end

-- Turns the arrow to the nearest place you can gather (the way it was when
-- found, whatever you have turned since) and hides it when there is none.
local function UpdateArrow()
    local target = db.arrow and Target()
    local facing = target and PlayerFacing()
    if not facing then
        if arrowOn then
            arrowOn = false
            arrow:Hide()
        end
        return
    end
    -- The way is clockwise from north, facing counterclockwise from north, and
    -- a texture turns counterclockwise.
    arrowTexture:SetRotation(-(target.world + facing))
    if not arrowOn then
        arrowOn = true
        arrow:Show()
    end
end

-- The groups of neighbouring points in a set: a list of lists of points.
local function Blobs(set)
    local blobs, seen = {}, {}
    for first in pairs(set) do
        if not seen[first] then
            seen[first] = true
            local stack, keys = { first }, {}
            while #stack > 0 do
                local point = table.remove(stack)
                keys[#keys + 1] = point
                for _, step in ipairs(AROUND) do
                    local other = point + step
                    if set[other] and not seen[other] then
                        seen[other] = true
                        stack[#stack + 1] = other
                    end
                end
            end
            blobs[#blobs + 1] = keys
        end
    end
    return blobs
end

-- The middle of some points, in minimap units.
local function Middle(keys, step)
    local sx, sy = 0, 0
    for _, point in ipairs(keys) do sx, sy = sx + math.floor(point / 1000), sy + point % 1000 end
    return sx / #keys * step, sy / #keys * step
end

-- The dots of radius R that make up an outline (the points where the group ends):
-- the centers that the most outline points lie around at distance R, found one
-- after another, each taking the points it explains out of the count. A dot has
-- to explain MIN_VOTES points (an arc of a few units), so the notches where two
-- dots overlap show where one stops and the next starts.
local function FitRadius(boundary, candidates, R, most)
    local low, high = (R - TOL) ^ 2, (R + TOL) ^ 2
    -- A dot's whole area answers: no point that didn't is inside its circle
    -- (a little less than R, for a candidate that isn't quite at the center).
    local clear = (R - TOL - 1) ^ 2
    local valid = {}
    for _, c in ipairs(candidates) do
        if c[3] >= clear then valid[#valid + 1] = c end
    end
    candidates = valid
    local left, discs, total = boundary, {}, 0
    local function Count(cx, cy)
        local n = 0
        for _, b in ipairs(left) do
            local d = (cx - b[1]) ^ 2 + (cy - b[2]) ^ 2
            if d >= low and d <= high then n = n + 1 end
        end
        return n
    end
    for _ = 1, most do
        local bestN, bx, by = 0, 0, 0
        for _, c in ipairs(candidates) do
            local n = Count(c[1], c[2])
            if n > bestN then bestN, bx, by = n, c[1], c[2] end
        end
        if bestN < MIN_VOTES then break end
        local cx, cy = bx, by -- the points around the winner may fit better
        for dx = -1, 1 do
            for dy = -1, 1 do
                local n = Count(bx + dx, by + dy)
                if n > bestN then bestN, cx, cy = n, bx + dx, by + dy end
            end
        end
        discs[#discs + 1] = { cx, cy }
        total = total + bestN
        local rest = {}
        for _, b in ipairs(left) do
            local d = (cx - b[1]) ^ 2 + (cy - b[2]) ^ 2
            if d < low or d > high then rest[#rest + 1] = b end
        end
        left = rest
    end
    return discs, total
end

-- The dots in a group, from the finer look at it. The radius is tried a little
-- smaller and bigger than the last one found, and the one that explains most
-- wins; one radius a frame (StartFit gets the outline ready, FitStep tries the
-- next radius, FinishFit gives the dots), so no frame takes long.
local function StartFit(job)
    local hit = job.hits[job.name]
    if not hit then return nil end
    local boundary, outside, seenOutside = {}, {}, {}
    for point in pairs(hit) do
        local px, py = math.floor(point / 1000), point % 1000
        local edge, ox, oy = false, 0, 0
        for _, step in ipairs(AROUND4) do
            local other = point + step
            if job.probed[other] and not hit[other] then
                edge = true
                ox = ox + (step == -1000 and -1 or step == 1000 and 1 or 0)
                oy = oy + (step == -1 and -1 or step == 1 and 1 or 0)
                if not seenOutside[other] then
                    seenOutside[other] = true
                    outside[#outside + 1] = { math.floor(other / 1000) * FINE, other % 1000 * FINE }
                end
            end
        end
        -- The outline is half a step beyond a point that has a point outside beside it.
        if edge then boundary[#boundary + 1] = { (px + ox / 2) * FINE, (py + oy / 2) * FINE } end
    end
    -- Every point of the group is a candidate center, with how near the nearest
    -- point outside it is (squared).
    local candidates = {}
    for point in pairs(hit) do
        local cx, cy = math.floor(point / 1000) * FINE, point % 1000 * FINE
        local nearest = 1e9
        for _, o in ipairs(outside) do
            local d = (cx - o[1]) ^ 2 + (cy - o[2]) ^ 2
            if d < nearest then nearest = d end
        end
        candidates[#candidates + 1] = { cx, cy, nearest }
    end
    return { boundary = boundary, candidates = candidates, next = 1, n = #job.keys, results = {},
        radii = { hitRadius, hitRadius - 1.5, hitRadius + 1.5, hitRadius - 3, hitRadius + 3, hitRadius - 4.5, hitRadius + 4.5,
            hitRadius + 6, hitRadius + 7.5 } }
end

-- Tries the next radius; true when all have been tried.
local function FitStep(fit)
    local R = fit.radii[fit.next]
    -- A group of this many points can't be many more dots than its area says.
    local most = math.min(MAX_DISCS, math.max(1, math.floor(1.25 * fit.n / (math.pi * R ^ 2 / STEP ^ 2) + 0.5)))
    local discs, total = FitRadius(fit.boundary, fit.candidates, R, most)
    fit.results[#fit.results + 1] = { discs = discs, total = total, radius = R }
    fit.next = fit.next + 1
    return fit.next > #fit.radii
end

-- The dots found: a list of { x, y } in minimap units, nil if the outline said
-- nothing. Of the radii that explain nearly as much of the outline as the best
-- (FEWER of it), the one with the fewest dots wins: one big dot explains a
-- group as well as several small ones, and is likelier.
local FEWER = 0.85

local function FinishFit(fit)
    local top = 0
    for _, result in ipairs(fit.results) do
        if result.total > top then top = result.total end
    end
    if top == 0 then return nil end
    local best
    for _, result in ipairs(fit.results) do
        if result.total >= FEWER * top and (not best or #result.discs < #best.discs
            or (#result.discs == #best.discs and result.total > best.total)) then
            best = result
        end
    end
    hitRadius = math.max(11, math.min(24, hitRadius + (best.radius - hitRadius) / 4))
    return best.discs
end

-- A group of points as a job: the finer points over its area, and what they say.
local function NewJob(name, keys)
    local x0, y0, x1, y1 = 1e9, 1e9, -1e9, -1e9
    for _, point in ipairs(keys) do
        local x, y = math.floor(point / 1000) * STEP, point % 1000 * STEP
        x0, y0, x1, y1 = math.min(x0, x), math.min(y0, y), math.max(x1, x), math.max(y1, y)
    end
    local half = gridWidth / 2
    local list, probed = {}, {}
    for fx = math.ceil((x0 - STEP) / FINE), math.floor((x1 + STEP) / FINE) do
        for fy = math.ceil((y0 - STEP) / FINE), math.floor((y1 + STEP) / FINE) do
            local dx, dy = fx * FINE - half, fy * FINE - half
            if fx >= 0 and fy >= 0 and dx * dx + dy * dy <= half * half then
                list[#list + 1] = fx * 1000 + fy
                probed[fx * 1000 + fy] = true
            end
        end
    end
    return { name = name, keys = keys, list = list, probed = probed, hits = {}, next = 1 }
end

-- Between scans the places stay where they are in the world: each frame their
-- yards, way and place on the minimap are worked out again from where you are
-- now (the zone map's position, in yards), so the symbols and the arrow move
-- smoothly as you do. A place the map can't follow (no position, another zone)
-- stays as the last scan found it.
local function ByDistance(a, b) return a.distance < b.distance end

local lastMap, lastX, lastY, lastFacing, lastRadius -- what the last Follow worked from
local still = false -- you and the minimap haven't changed since the last Follow

local function Follow()
    still = false
    if not markers[1] or not markers[1].map then return end
    local map, x, y, width, height = MapPosition()
    local radius = C_Minimap.GetViewRadius()
    local facing = turning and PlayerFacing() -- (only a minimap that turns with you needs it)
    if not map or not radius or issecretvalue(radius) or (turning and not facing) then return end
    -- Standing still with the minimap as it was: the places are where they were.
    if map == lastMap and x == lastX and y == lastY and radius == lastRadius and (not turning or facing == lastFacing) then
        still = true
        return
    end
    lastMap, lastX, lastY, lastFacing, lastRadius = map, x, y, facing, radius
    local half = Minimap:GetWidth() / 2
    local sorted, last = true, 0
    for _, marker in ipairs(markers) do
        if marker.map == map then
            local east, north = (marker.mx - x) * width, (y - marker.my) * height
            marker.yards = math.sqrt(east * east + north * north)
            marker.world = math.atan2(east, north)
            marker.distance = marker.yards / radius * half
            local way = turning and marker.world + facing or marker.world -- clockwise from the top of the minimap
            marker.x, marker.y = half + marker.distance * math.sin(way), half + marker.distance * math.cos(way)
            marker.far = marker.distance > half
        end
        if marker.distance < last then sorted = false end
        last = marker.distance
    end
    -- Nearest first. (They seldom change places from one frame to the next.)
    if not sorted then table.sort(markers, ByDistance) end
    ShowMarkers()
end

-- A scan's place for a herb is only as exact as the points tried (up to about
-- 9 yards off), and a new scan puts it somewhere a little different each time.
-- So a herb seen again (the same name, within MERGE yards of one from the last
-- scans) keeps its place, moved toward the new one by 1/(count + 1) of the way,
-- the count growing to AVERAGE: the symbol stops jumping and the place gets
-- better the longer you see it.
local MERGE = 15 -- yards
local AVERAGE = 8

local function Smooth(found, before, width, height, used)
    for _, marker in ipairs(found) do
        local best, bestGap
        for _, old in ipairs(before) do
            if marker.map and old.map == marker.map and old.name == marker.name and not used[old] then
                local gap = ((old.mx - marker.mx) * width) ^ 2 + ((old.my - marker.my) * height) ^ 2
                if gap < MERGE * MERGE and (not bestGap or gap < bestGap) then best, bestGap = old, gap end
            end
        end
        -- (A beast walks: where it was says nothing of where it is now.)
        if marker.kind == "rares" then best = nil end
        if marker.pinned then
            marker.count = marker.count or 1 -- (it is where its dot is: nothing to average)
        elseif best then
            used[best] = true
            local n = math.min(best.count, AVERAGE)
            marker.mx = (best.mx * n + marker.mx) / (n + 1)
            marker.my = (best.my * n + marker.my) / (n + 1)
            marker.count = n + 1
        else
            marker.count = 1
        end
    end
end

-- A scan is done: its places become the markers. Each gets its distance and
-- bearing from where it is on the minimap, then its spot on the zone map so it
-- can be followed until the next scan. Then the pace of the next scans is set,
-- the places the Switch setting keeps are added, and the Sound setting's sound
-- is played for anything new.
local function FinishScan()
    local places = scan.places
    local hits = scan.hits -- (what the grid's points said: for the gray below)
    scan = nil
    local width = Minimap:GetWidth()
    local radius = C_Minimap.GetViewRadius()
    if issecretvalue(radius) then radius = nil end
    local rotating = C_CVar.GetCVar("rotateMinimap") == "1"
    local facing = PlayerFacing()
    local found, pinOf, kept = {}, {}, {}
    skills.herbs, skills.ore = nil, nil -- (asked for again by the first node that needs one)
    -- A turning minimap has the way you face at the top; otherwise north is.
    if not (rotating and not facing) then
        for _, place in ipairs(places) do
            local name, x, y = place.name, place.x, place.y
            local kind = KindOf(name)
            local dx, dy = x - width / 2, y - width / 2
            local bearing = math.atan2(dx, dy) -- clockwise from the top of the minimap
            local distance = math.sqrt(dx * dx + dy * dy)
            local said = hits[name] -- (what the grid's points said of this name: see Record)
            local marker = {
                name = name, kind = kind, file = IconOf(name, kind), hard = (db.hard or db.arrow or db.sound or db.worldMark) and TooHard(name, kind),
                x = x, y = y, distance = distance, age = place.age, exact = place.exact,
                yards = radius and distance / (width / 2) * radius,
                world = rotating and bearing - facing or bearing,
                -- In a cave: the game had its name in gray at the point of the grid nearest to it.
                dim = said and said[math.floor(x / STEP + 0.5) * 1000 + math.floor(y / STEP + 0.5)] == "gray" or false,
            }
            found[#found + 1] = marker
            pinOf[marker] = place.pin
        end
    end
    table.sort(found, ByDistance)
    -- Where each is on the zone map, so it can be followed until the next scan.
    local map, x, y, mapWidth, mapHeight = MapPosition()
    if map then
        for _, marker in ipairs(found) do
            if marker.yards then
                marker.map = map
                local pin = pinOf[marker]
                if pin and pin.map == map then
                    -- Pinned by an earlier scan: it stays where it was found to be.
                    marker.mx, marker.my, marker.count, marker.pinned = pin.mx, pin.my, pin.count + 1, true
                    kept[pin] = true
                else
                    marker.mx = x + marker.yards * math.sin(marker.world) / mapWidth
                    marker.my = y - marker.yards * math.cos(marker.world) / mapHeight
                    marker.pinned = marker.exact -- its dot's exact place was found in this scan
                end
            end
        end
    end
    if map then Smooth(found, markers, mapWidth, mapHeight, kept) end
    -- Nothing new for a few scans: the places are known, so look less closely.
    local was, new = eased, false
    for _, marker in ipairs(found) do
        if not (marker.count and marker.count > 1) then new = true end
    end
    if new then
        eased, quiet = 0, 0
    else
        quiet = quiet + 1
        if quiet >= SETTLE and SettingLevel() - eased > 1 then eased, quiet = eased + 1, 0 end
    end
    if eased ~= was then ApplyDetail() end
    -- Nothing found again and again: look less often, until you have moved.
    if found[1] then
        empties = 0
        if wait > WAIT then wait = WAIT end -- (a wait made long by the empty scans before this one)
    else
        empties = empties + 1
        emptyMap, emptyX, emptyY = map, x, y -- (where you are: asked for above)
    end
    -- A rare beast walks about: while one is in sight the next scan comes at
    -- the full pace, also while you stand still.
    for _, marker in ipairs(found) do
        if marker.kind == "rares" and hurry == 0 then hurry = 1 end
    end
    -- The Switch setting: the kind whose finder is off has no dots to be found
    -- by, so its places stay as they were until its turn comes (unless this
    -- scan saw one of that kind after all: then what it saw stands).
    local shown = db.switchFinders and turns.kind
    if shown and map then
        local other = shown == "herbs" and "ore" or "herbs" -- (the kind whose finder is off)
        local seen = false
        for _, marker in ipairs(found) do
            if marker.kind == other then seen = true end
        end
        for _, old in ipairs(markers) do
            if not seen and old.kind == other and old.map == map then
                old.held = true
                found[#found + 1] = old
            end
        end
    end
    -- The Sound setting: the minimap's ping sound when something is found that
    -- no scan of the last minute saw. What was seen is kept by its name and
    -- place (a rare beast by its name alone: it walks), so a herb that was out
    -- of sight for a moment, or in sight all through a short fight, isn't new
    -- again. The same place is anything within 25 minimap units, a dot and a
    -- half: at the minimap's rim, where only a part of a dot answers, a place
    -- can be a dot's reach off. One sound a scan however many are new, and none
    -- for a herb or ore above your skill (the arrow passes those over too).
    if db.sound then
        local now, new = GetTime(), false
        local reach = radius and (25 * radius * 2 / width) ^ 2 -- (in yards, squared)
        for i = #heard, 1, -1 do
            if now - heard[i].at > 60 then table.remove(heard, i) end
        end
        for _, marker in ipairs(found) do
            if not marker.hard then
                local known
                for _, old in ipairs(heard) do
                    if old.name == marker.name and old.map == marker.map and (marker.kind == "rares" or not marker.map
                        or ((old.mx - marker.mx) * mapWidth) ^ 2 + ((old.my - marker.my) * mapHeight) ^ 2 < reach) then
                        known = old
                        break
                    end
                end
                if known then
                    known.at = now
                else
                    heard[#heard + 1] = { name = marker.name, map = marker.map, mx = marker.mx, my = marker.my, at = now }
                    new = true
                end
            end
        end
        if new then PlaySound(SOUNDKIT.MAP_PING) end
    end
    turns.scanned = true
    turning = rotating
    markers = found
    lastMap = nil -- (Follow works the new places out at once)
    ShowMarkers()
end

-- Time for a scan: starts one over the grid of points, unless there is nothing
-- to scan now (a fight, the minimap hidden, no finder on), and sets the wait
-- until the next.
local function StartScan()
    wait = WAIT
    if hurry > 0 then hurry = hurry - 1 end
    if not Minimap:IsVisible() or not Minimap:GetLeft() then
        if markers[1] then
            markers = {}
            ShowMarkers()
        end
        return
    end
    -- No scan in a fight, unless the Scan in combat setting is on. The symbols
    -- found before it stay and follow you, and the fight's end brings a scan at
    -- once (see the events at the end).
    if InCombatLockdown() and not db.combatScan then return end
    if empties > 0 and Moved(MapPosition()) then empties = 0 end
    if db.switchFinders and Switch() then -- the other finder is on now: scan when its dots are there
        wait = SWITCH_WAIT
        if hurry == 0 then hurry = 1 end -- (at the full pace, also if you stop)
        return
    end
    if not FinderOn() then -- nothing on the minimap to find: look again in a while
        wait = NO_FINDER
        if markers[1] then
            markers = {}
            ShowMarkers()
        end
        return
    end
    -- (Nothing found: a wait longer with each such scan up to seven, then twice as long each time.)
    wait = WAIT * math.min(SLEEP, empties <= 6 and 1 + empties or 7 * 2 ^ (empties - 6))
    rested = still and hurry == 0 and math.min(rested + 1, #REST) or 0
    local width = Minimap:GetWidth()
    if gridWidth ~= width then
        gridWidth, grid = width, {}
        for x = 0, math.floor(width / STEP) do
            for y = 0, math.floor(width / STEP) do
                local dx, dy = x * STEP - width / 2, y * STEP - width / 2
                if dx * dx + dy * dy <= width * width / 4 then grid[#grid + 1] = x * 1000 + y end
            end
        end
    end
    scan = { points = grid, next = 1, hits = {} }
end

-- What the minimap says under a pretend mouse at x, y (minimap units): every name
-- on it is noted under the point's number.
local function Probe(left, bottom, scale, x, y, hits, point)
    Minimap:UpdateMouseoverAtPoint((left + x) * scale, (bottom + y) * scale)
    local data = C_TooltipInfo.GetMinimapMouseover()
    local lines = data and not issecretvalue(data) and data.lines
    if lines and not issecretvalue(lines) then
        for _, line in ipairs(lines) do
            local text = line.leftText
            local color = line.leftColor
            local gray = color and not issecretvalue(color) and Gray(color.r, color.g, color.b)
            if text and not issecretvalue(text) then Record(hits, text, point, gray) end
        end
    end
end

-- Splitting a group is the costly part, and the herbs in it don't move. So a
-- group the last scan already split (two or more places of the same name, each
-- inside the group, every point of the group within a dot's reach of one) keeps
-- those places, until REFIT scans have passed.
local REFIT = 10

local function Known(name, keys, set)
    -- Only the places inside this group: another group of the same name has its own.
    local inGroup = {}
    for _, point in ipairs(keys) do inGroup[point] = true end
    local mine = {}
    for _, marker in ipairs(markers) do
        if marker.name == name and not marker.far
            and inGroup[math.floor(marker.x / STEP + 0.5) * 1000 + math.floor(marker.y / STEP + 0.5)] then
            mine[#mine + 1] = marker
        end
    end
    if #mine < 2 then return nil end
    local reach = (hitRadius + STEP / 2 + 1) ^ 2
    for _, marker in ipairs(mine) do
        if (marker.age or 0) >= REFIT then return nil end
        -- Its middle and four points around it, each as near a point of the
        -- grid as there is, have to have answered (at most one may not).
        local missing = 0
        for _, offset in ipairs({ { 0, 0 }, { 6, 0 }, { -6, 0 }, { 0, 6 }, { 0, -6 } }) do
            local gx = math.floor((marker.x + offset[1]) / STEP + 0.5)
            local gy = math.floor((marker.y + offset[2]) / STEP + 0.5)
            if not set[gx * 1000 + gy] then missing = missing + 1 end
        end
        if missing > 1 then return nil end
    end
    for _, point in ipairs(keys) do
        local x, y = math.floor(point / 1000) * STEP, point % 1000 * STEP
        local covered = false
        for _, marker in ipairs(mine) do
            if (x - marker.x) ^ 2 + (y - marker.y) ^ 2 <= reach then
                covered = true
                break
            end
        end
        if not covered then return nil end
    end
    return mine
end

-- A dot's exact place. The grid says where a dot is to within half a step or
-- so, and a little differently every scan. So once, when a dot is first seen,
-- its edges are looked for from the grid's place, to the left, right, down and
-- up: each lies between the dot's last point of the grid that answered and a
-- little past the next one, which didn't, and halving in on it finds it. The
-- dot is midway between its edges. That place is then kept (pinned) for as
-- long as scans find the dot on it, instead of being worked out anew and
-- averaged. An edge can't be found beyond the minimap's rim, or where another
-- dot of the kind answers right beside this one: such a dot has the grid's
-- place for now and is looked at again next scan.
local HALVINGS = 5 -- an edge to within a unit
local PAST = 1.2 -- steps past the dot's last point that answered: where its edge is looked for up to
local PIN_REACH = 0.6 -- of a step: how far a scan's place may be from a pinned one and still be its dot
local scratch = {}

-- Does the game name this dot at x, y?
local function Under(left, bottom, scale, x, y, name)
    wipe(scratch)
    Probe(left, bottom, scale, x, y, scratch, 1)
    return scratch[name] ~= nil
end

-- How far a dot answers from x, y (inside it) the way dx, dy, looked for up to
-- `reach` away: nil if it still answers there, or at the minimap's rim if that
-- comes first.
local function Edge(left, bottom, scale, name, x, y, dx, dy, reach)
    local px, py, rim = x - gridWidth / 2, y - gridWidth / 2, gridWidth / 2 - 1
    local out = px * px + py * py - rim * rim
    if out >= 0 then return nil end
    local along = px * dx + py * dy
    local inside, outside = 0, math.min(reach, math.sqrt(along * along - out) - along) -- (the rim, a unit in)
    if Under(left, bottom, scale, x + dx * outside, y + dy * outside, name) then return nil end
    for _ = 1, HALVINGS do
        local far = (inside + outside) / 2
        if Under(left, bottom, scale, x + dx * far, y + dy * far, name) then inside = far else outside = far end
    end
    return inside
end

-- Puts a new place on the middle of its dot, and notes whether all four edges
-- were found (exact). place.box is the box around its points of the grid.
local function Refine(left, bottom, scale, place)
    local name, x, y, box, past = place.name, place.x, place.y, place.box, PAST * STEP
    local west = Edge(left, bottom, scale, name, x, y, -1, 0, x - box[1] + past)
    local east = Edge(left, bottom, scale, name, x, y, 1, 0, box[3] - x + past)
    if west and east then x = x + (east - west) / 2 end
    local south = Edge(left, bottom, scale, name, x, y, 0, -1, y - box[2] + past)
    local north = Edge(left, bottom, scale, name, x, y, 0, 1, box[4] - y + past)
    if south and north then y = y + (north - south) / 2 end
    place.x, place.y, place.box = x, y, nil
    place.exact = (west and east and south and north) ~= nil
end

-- The box around some points of the grid, in minimap units: { left, bottom, right, top }.
local function Box(keys)
    local x0, y0, x1, y1 = 1e9, 1e9, -1e9, -1e9
    for _, point in ipairs(keys) do
        local x, y = math.floor(point / 1000) * STEP, point % 1000 * STEP
        x0, y0, x1, y1 = math.min(x0, x), math.min(y0, y), math.max(x1, x), math.max(y1, y)
    end
    return { x0, y0, x1, y1 }
end

-- The place pinned by an earlier scan that this scan's place is still on, nil
-- if there is none. (Two dots of a kind near enough for both to fit are one
-- group, which gets the finer look.)
local function PinAt(name, x, y)
    local reach = (PIN_REACH * STEP) ^ 2
    for _, marker in ipairs(markers) do
        if marker.pinned and marker.name == name and (marker.x - x) ^ 2 + (marker.y - y) ^ 2 <= reach then return marker end
    end
end

-- The grid is done: a group of points no bigger than one dot's is one place
-- (its middle, then its dot's exact place: a pinned one, or found now); bigger
-- ones get the finer look, if there are not too many.
local function EndCoarse()
    scan.places, scan.jobs, scan.job, scan.fresh = {}, {}, 1, {}
    local fine = 0
    local mapped = MapPosition() ~= nil -- (a place can only be kept where the zone map can follow it)
    for name, set in pairs(scan.hits) do
        if KindOf(name) then
            for _, keys in ipairs(Blobs(set)) do
                local known = #keys > Single() and Known(name, keys, set)
                local job = #keys > Single() and not known and NewJob(name, keys)
                if known then
                    for _, marker in ipairs(known) do
                        scan.places[#scan.places + 1] = { name = name, x = marker.x, y = marker.y, age = (marker.age or 0) + 1 }
                    end
                elseif job and fine + #job.list <= MAX_FINE then
                    fine = fine + #job.list
                    scan.jobs[#scan.jobs + 1] = job
                else
                    local x, y = Middle(keys, STEP)
                    local place = { name = name, x = x, y = y }
                    if mapped and #keys <= Single() then -- one dot
                        place.pin = PinAt(name, x, y) -- (FinishScan keeps its place on the zone map)
                        -- (Not a beast's: it walks, so its dot's place is looked for anew in every scan.)
                        if place.pin and place.pin.kind == "rares" then place.pin = nil end
                        if not place.pin then
                            place.box = Box(keys)
                            scan.fresh[#scan.fresh + 1] = place
                        end
                    end
                    scan.places[#scan.places + 1] = place
                end
            end
        end
    end
    if #scan.jobs == 0 and not scan.fresh[1] then FinishScan() end
end

-- A big group has been looked at: the places are the dots found in it (or its
-- middle if no dot fits).
local function EndJob(job, discs)
    if discs and #discs > 0 then
        for _, disc in ipairs(discs) do scan.places[#scan.places + 1] = { name = job.name, x = disc[1], y = disc[2] } end
    else
        local x, y = Middle(job.keys, STEP)
        scan.places[#scan.places + 1] = { name = job.name, x = x, y = y }
    end
    scan.job = scan.job + 1
    if scan.job > #scan.jobs then FinishScan() end
end

-- Tries the next points. The soft cursor is only on while they are tried.
local function ScanSome()
    local left, bottom = Minimap:GetLeft(), Minimap:GetBottom()
    if not (left and bottom and Minimap:IsVisible()) or (InCombatLockdown() and not db.combatScan) then
        scan = nil
        return
    end
    local scale = Minimap:GetEffectiveScale()
    Minimap:SetUsingSoftCursor(true)
    if not scan.jobs then
        local points = scan.points
        for i = scan.next, math.min(scan.next + PER_FRAME - 1, #points) do
            local point = points[i]
            Probe(left, bottom, scale, math.floor(point / 1000) * STEP, point % 1000 * STEP, scan.hits, point)
        end
        Minimap:SetUsingSoftCursor(false)
        scan.next = scan.next + PER_FRAME
        if scan.next > #points then EndCoarse() end
    elseif scan.fresh[1] then
        -- New dots: each one's exact place, three a frame.
        for _ = 1, math.min(3, #scan.fresh) do
            Refine(left, bottom, scale, table.remove(scan.fresh))
        end
        Minimap:SetUsingSoftCursor(false)
        if not scan.fresh[1] and scan.job > #scan.jobs then FinishScan() end
    else
        local job = scan.jobs[scan.job]
        local list = job.list
        if job.fit then -- all its points are in: work out the dots, a radius a frame
            Minimap:SetUsingSoftCursor(false)
            if FitStep(job.fit) then EndJob(job, FinishFit(job.fit)) end
            return
        end
        for i = job.next, math.min(job.next + PER_FRAME - 1, #list) do
            local point = list[i]
            Probe(left, bottom, scale, math.floor(point / 1000) * FINE, point % 1000 * FINE, job.hits, point)
        end
        Minimap:SetUsingSoftCursor(false)
        job.next = job.next + PER_FRAME
        if job.next > #list then
            job.fit = StartFit(job)
            if not job.fit then EndJob(job) end
        end
    end
end

---------------------------------------------------------------------------
-- Sparkles on far away herbs and ore (Beta; the worldMark setting, off out of
-- the box). It doesn't work perfectly and costs a good deal more than the rest
-- each frame, which its setting says. The game draws a marker in the world
-- where a tracked map pin is (its In-Game Navigation setting), and the scan
-- knows where each herb is on the zone map. So the map pin is put on a herb,
-- ore or chest you can gather (world.Pick chooses which) and tracked, and
-- sparkles are put on the frame the game places on screen at that spot
-- (C_Navigation.GetFrame, which Blizzard's own marker is anchored to). While
-- it is on it takes the place of your own map pin and of the quest you track;
-- both are put back when nothing is left to mark, and when a fight begins (see
-- world.Fight). Nothing is changed in a fight or while the world map is open
-- (the map makes its pin's frame as the pin is set, which would then run under
-- the addon's taint).
--
-- The height: a map pin has no height, the game draws its marker at your own,
-- and an addon is told neither the herb's height nor yours. So the marker is
-- right on flat ground, and too high or too low on a slope. What is right is
-- where it is on the ground, so the herb is straight above or below the
-- marker: the sparkles are a column from the marker, upward if the minimap's
-- tooltip says the herb is above you, downward if below (see world.Level), a
-- short one both ways if it has it level, and the herb is somewhere on that
-- column. (A column of the same 8 yards both ways at any distance gets longer
-- and longer on screen as you come near, most of it on the wrong side of the
-- herb.) Up close you see the herb itself, so the one you are within 12 yards
-- of is let go, and the marker goes to another (from 16 yards on) or is taken
-- away.
--
-- Sparkles or the game's marker: with the Sparkles setting on for what is
-- marked (Sparkles on herbs for a herb, on ore for ore, on other objects for a
-- chest) only the sparkles show, and the game's own marker (its pin and the
-- yards under it) is kept unseen; with it off only the game's marker shows.
-- Blizzard's marker (SuperTrackedFrame) sets its own alpha every frame, so a
-- hook after that sets it to 0 while it is to be unseen (alpha only: nothing
-- is written into Blizzard's frame).
--
-- The ground's height can't be had: the game gives your own height as 0, and
-- though a map pin can carry a height (UiMapPoint's z) and the game keeps it,
-- its marker is drawn in the same place whatever that height is. What the game
-- does say is whether its marker is hidden or in view
-- (C_Navigation.GetTargetState): hidden, the spot at your height is under the
-- ground, so the herb is above it and the column goes up (see Update). A
-- one-line readout near the top of the screen says what the game answered
-- (world.Say).
--
-- No jerking: the marker's state goes back and forth over bumps, past trees
-- and in a jump, and a column that changed at once between short and long
-- would jerk up and down with it. So the state has to hold for most of a
-- second before it is taken (world.heat), the column glides to where it goes
-- (world.low, world.high; its area is always held by its bottom, so far from
-- the marker), and a pin moved a few yards for the same herb keeps what was
-- known of it.
--
-- Several at once: the game has one map pin and draws one marker, so only one
-- herb can have the game's marker. But where the game put that marker on
-- screen says which way the camera looks, and with that the other herbs'
-- places on screen can be worked out (each at your own height, like the
-- marker) and sparkles put there: up to four more, at least 12 yards off.
--
-- All of it in a frame turned with the camera. A spot at your own height,
-- `far` yards from you and `side` radians to the right of the way the camera
-- looks, seen by a camera `zoom` yards behind a point `pivot` yards above your
-- feet that looks `down` radians downward, is this many focal lengths right of
-- and above the middle of the screen (world.Project):
--     depth = far * cos(side) * cos(down) + zoom + pivot * sin(down)
--     X = far * sin(side) / depth
--     Y = (far * cos(side) * sin(down) - pivot * cos(down)) / depth
-- Known: far and the compass bearing of every herb (the zone map), zoom
-- (GetCameraZoom), X and Y of the marked one (the game's marker). Worked out
-- from those every frame: side and down (world.Camera). Not told by the game:
-- the focal length (the field of view; taken as the screen's height times
-- `lens`) and the pivot's height. Guessed at first (the cameraFov setting
-- times 0.6 as the angle from top to bottom, which is what the old clients
-- did; 2 yards, 3 riding), then measured: the pin is put on another spot for a
-- third of a second and where the game draws it then gives both (world.Hop,
-- world.Fit), three times, and again riding. Kept in NodeSightDB.cam.
---------------------------------------------------------------------------
local world = { others = {} } -- others: the sparkles of the ones that aren't marked; probe, probed: a frame of the addon's on the game's marker, to read its place; cvar, fits: the game's field of view setting and what was measured under it (riding or not: a list of { lens, pivot }); hop, tried, fit, detail, fails, wait: a measurement going on, when the last one began, how it went, what it read, how many gave nothing and how long the game's marker is given to move; side, down, shown: which way the camera looks (by the marked one) and how many others have sparkles; stillX, stillY, stillAt: where the marked one was on screen when the view last moved, and when; taken: when the marked one was taken; at: where the pin is ({ map, mx, my, kind, name }); pin, quest: what you had; frame, nav, shape: the sparkles, what they are on and which way they go; low, high, base: where the column starts and ends on screen, up from the marker, and where its area's bottom is; level, asked: above or below you by the minimap, and when that was asked; plain, clear, blip, was: for how long the game's marker has been in plain view, whether it is taken for in plain view all along, when it last went hidden and whether it was hidden the frame before; heat, under, seen: how much of the last while the game's marker was hidden, whether it is taken for hidden, and when that was last asked; hide: Blizzard's marker is kept unseen; text, said: the readout

-- The sparkles on the game's marker, shown: ten of them in an area frame.wide
-- by frame.tall (Place puts them anywhere in it; Update sets the area).
function world.Fill(frame)
    local parts = frame.parts
    for i = 1, 10 do
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
    frame:Show()
end

-- Can this one be marked, and is it the marked one? A herb, ore or chest
-- you can gather that isn't right beside you: the one that is marked
-- stays marked until you are within 12 yards of it; another is only taken
-- from 16 yards on (so the marker doesn't flicker at the line).
function world.Can(marker)
    -- (Nor one in a cave, like the arrow, nor a rare beast.)
    if marker.hard or marker.dim or marker.kind == "rares" or not marker.map or not marker.yards then return false end
    local at = world.at
    local marked = at and at.map == marker.map and (at.mx - marker.mx) ^ 2 + (at.my - marker.my) ^ 2 <= 2.5e-7 or false
    return marker.yards >= (marked and 12 or 16), marked
end

-- How far off the way you face it is (radians, 0 to pi): its bearing is
-- clockwise from north, the way you face counterclockwise.
function world.Off(marker, facing)
    return math.abs((marker.world + facing + math.pi) % (2 * math.pi) - math.pi)
end

-- What to mark: the one you face, not simply the nearest. The marked one is
-- also what the camera is worked out from, so it should be on screen, and near
-- the middle of it. Those within 15 degrees of the one most the way you face
-- count alike, and of them the nearest is taken. So that the marker doesn't go
-- back and forth between two, the marked one stays while it is one of them and
-- none of them is more than 5 yards nearer, and for half a second after it was
-- taken. The nearest of all if the game won't say which way you face.
function world.Pick()
    local facing = PlayerFacing()
    local least, kept
    for _, marker in ipairs(markers) do -- (nearest first)
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
    for _, marker in ipairs(markers) do
        if world.Can(marker) and world.Off(marker, facing) <= least + 0.26 then
            if keep and kept.yards - marker.yards <= 5 then return kept end
            return marker
        end
    end
end

-- Is what is marked above you or below you? The minimap's tooltip says so with
-- a little arrow before the name (a half of the picture
-- Interface\Minimap\Minimap-PositionArrows: the upper half is taken for "above
-- you" and the lower for "below you", which is a guess, not checked in game;
-- NodeSightDB.arrowsFlipped = true for the other way round). Asked with one
-- pretend mouse point on its dot. "up", "down", or "level" when the tooltip
-- has no arrow for it; what it was when its dot doesn't answer (off the
-- minimap, a fight).
function world.Level(marker)
    local left, bottom = Minimap:GetLeft(), Minimap:GetBottom()
    if marker.far or not (left and bottom and Minimap:IsVisible()) or InCombatLockdown() then return world.level end
    local scale = Minimap:GetEffectiveScale()
    Minimap:SetUsingSoftCursor(true)
    Minimap:UpdateMouseoverAtPoint((left + marker.x) * scale, (bottom + marker.y) * scale)
    local data = C_TooltipInfo.GetMinimapMouseover()
    Minimap:SetUsingSoftCursor(false)
    local lines = data and not issecretvalue(data) and data.lines
    if not lines or issecretvalue(lines) then return world.level end
    for _, line in ipairs(lines) do
        local text = line.leftText
        if text and not issecretvalue(text) then
            for row in text:gmatch("[^\n]+") do
                if Clean(row) == marker.name then
                    local top = row:match("PositionArrows[%d:]-:(%d+):%d+|t") -- (where the half starts in the picture: 0 or 16)
                    if not top then return "level" end
                    return ((top == "0") ~= (db.arrowsFlipped == true)) and "up" or "down"
                end
            end
        end
    end
    return world.level
end

-- Puts the map pin on the marked spot and tracks it. (A pin can carry a
-- height, and the game keeps it, but it draws its marker in the same place
-- whatever that height is, so none is given.)
function world.Set(at)
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(at.map, at.mx, at.my))
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
end

-- Nothing is marked any more: your own pin and tracked quest are back.
function world.Back()
    if world.pin then C_Map.SetUserWaypoint(world.pin) else C_Map.ClearUserWaypoint() end
    C_SuperTrack.SetSuperTrackedUserWaypoint(false)
    if world.quest and world.quest ~= 0 then C_SuperTrack.SetSuperTrackedQuestID(world.quest) end
    world.at, world.pin, world.quest = nil, nil, nil
end

-- A fight begins (PLAYER_REGEN_DISABLED): the pin comes off what is marked,
-- and the sparkles with it, until the fight is over. Done here, as the fight
-- begins, and not in the fight itself: once it has begun the pin is left
-- alone. world.fight is on until the fight is over, so nothing is marked in
-- it, also if the game's lockdown begins a moment after its event. With the
-- world map open the pin stays as it is.
function world.Fight()
    world.fight = true
    if world.at and not (WorldMapFrame and WorldMapFrame:IsShown()) then world.Back() end
end

-- A readout near the top of the screen, for finding faults: only with
-- NodeSightDB.worldReadout = true, which nothing in the addon sets (a switch
-- to set by hand). What is marked, what the minimap's arrow said, what the
-- game says of its marker (C_Navigation.GetTargetState: 1 is taken for hidden,
-- anything else for in view), which way the sparkles go from it, how many
-- others have sparkles, and the camera: its angle from top to bottom, the
-- pivot's height, how far down it looks, and how the measuring went.
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

-- Where a spot is on screen, in focal lengths right of and above the middle
-- (see the top). nil for one behind the camera.
function world.Project(far, side, down, zoom, pivot)
    local ahead = far * math.cos(side)
    local depth = ahead * math.cos(down) + zoom + pivot * math.sin(down)
    if depth < 1 then return nil end
    return far * math.sin(side) / depth, (ahead * math.sin(down) - pivot * math.cos(down)) / depth
end

-- The other way round: the marked one is at (X, Y) on screen, so which way
-- does the camera look? side and down, each worked out from the other a few
-- times over (the equations above, one solved for down and one for side).
-- nil if nothing fits.
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

-- Where the game's marker is on screen, in UIParent's units right of and
-- above the screen's middle: read off a frame of the addon's own held on it
-- (so the scale the game's frame has doesn't matter). nil if it can't be read.
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

-- The focal length (in UIParent's units), the pivot's height, and whether you
-- ride: what was measured under the game's field of view setting as it is
-- now, or the guesses.
function world.Lens()
    local cvar = C_CVar.GetCVar("cameraFov")
    if world.cvar ~= cvar or not world.fits then world.cvar, world.fits, world.fit, world.fails, world.wait = cvar, { [true] = {}, [false] = {} }, nil, 0, 0.3 end
    local cam = db.cam
    if cam and cam.cvar ~= cvar then cam = nil end
    local riding = IsMounted() and true or false
    local lens = cam and cam.lens or 0.5 / math.tan(math.rad((tonumber(cvar) or 90) * 0.6) / 2)
    local pivot = cam and (riding and cam.ride or not riding and cam.pivot) or (riding and 3 or 2)
    return lens * UIParent:GetHeight(), pivot, riding
end

-- The middle one of what was measured.
function world.Middle(fits, key)
    local values = {}
    for _, fit in ipairs(fits) do values[#values + 1] = fit[key] end
    table.sort(values)
    return values[math.ceil(#values / 2)]
end

-- A measurement's answer. The marked one was at (hop.X0, hop.Y0) before and is
-- at (X, Y) after, so about halfway between when the tried spot was at
-- (hop.X, hop.Y); the lens and the pivot's height that put the tried spot
-- there are looked for (Newton's way, both at once). Returns how it went.
function world.Fit(hop, X, Y)
    local RX, RY = (hop.X0 + X) / 2, (hop.Y0 + Y) / 2
    -- (For the readout: what was read, whatever comes of it.)
    world.detail = ("the marked one moved %.0f, the tried spot was %.0f from it (%.0f by the guess)"):format(
        math.sqrt((hop.X0 - X) ^ 2 + (hop.Y0 - Y) ^ 2), math.sqrt((hop.X - RX) ^ 2 + (hop.Y - RY) ^ 2), hop.gap)
    if (hop.X0 - X) ^ 2 + (hop.Y0 - Y) ^ 2 > 144 then return "you or the camera moved" end
    if (hop.X - RX) ^ 2 + (hop.Y - RY) ^ 2 < 3600 then return "the game's marker didn't go to the tried spot" end
    local height = UIParent:GetHeight()
    local focal, pivot, riding = world.Lens()
    local lens = focal / height
    -- How far off the tried spot would be drawn, with this lens and pivot.
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
    local cam = db.cam and db.cam.cvar == world.cvar and db.cam or { cvar = world.cvar }
    cam.lens, cam[riding and "ride" or "pivot"] = world.Middle(fits, "lens"), world.Middle(fits, "pivot")
    db.cam = cam
    return "ok"
end

-- A measurement going on (world.hop): the game's pin is on the tried spot.
-- After a third of a second where the game draws it is read and the pin goes
-- back on the marked one; a third of a second later the marked one's place is
-- read again and the answer worked out. The marked one's own sparkles are
-- unseen meanwhile (they are on the game's marker). Nothing is changed in a
-- fight or with the world map open: it waits (a fight's start takes the pin
-- off, and the try is dropped: see world.Fight). How long the game takes to
-- move its marker isn't known: if the marker wasn't on the tried spot the
-- next try waits twice as long (up to a second), and after eight tries that
-- gave nothing it is left at the guesses (world.fails).
function world.Hop(nav, seen, busy)
    local hop, now = world.hop, GetTime()
    if world.at ~= hop.at then -- (the pin went elsewhere meanwhile)
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
            -- (Where you are now: you may have walked on.)
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

-- The others' sparkles, from the first one on: off.
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

-- The spots tried for a measurement: so far to the right of the marked one
-- (radians, as seen from you) and at so many times its distance. The first
-- that would be well on screen and away from the marked one is taken.
world.TRIES = { { 0.35, 0.5 }, { -0.35, 0.5 }, { 0.6, 0.5 }, { -0.6, 0.5 }, { 0.35, 1.6 }, { -0.35, 1.6 } }

-- Every frame the game's marker is on screen: the camera is worked out from
-- it, and the others get their sparkles where they would be on screen (a
-- short column both ways, as for one the game has level with you: nothing is
-- known of their heights). And a measurement is started if one is due.
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
            for _, marker in ipairs(markers) do -- (nearest first)
                if shown == 4 then break end
                if not marker.hard and not marker.dim and marker.kind ~= "rares" and marker.map == map and marker.yards and marker.yards >= 12
                    and (at.mx - marker.mx) ^ 2 + (at.my - marker.my) ^ 2 > 2.5e-7
                    and db[(marker.kind == "herbs" or marker.kind == "ore") and marker.kind or "others"] then
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
                        if not frame:IsShown() then world.Fill(frame) end
                    end
                end
            end
            -- A measurement, until there are three (riding or not), four
            -- seconds apart, and only once the view has been still for 0.4 s
            -- (the marked one within 3 units of where it was): one made while
            -- you or the camera move is far off, and would put the others'
            -- sparkles in the wrong places.
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

-- Every frame: the pin follows what is to be marked, and the sparkles the game's marker.
function world.Update()
    -- (Off, and nothing left of it: nothing to do.)
    if not db.worldMark and not world.at and not world.hop then return end
    local target = db.worldMark and world.Pick()
    local busy = world.fight or InCombatLockdown() or (WorldMapFrame and WorldMapFrame:IsShown())
    local at = world.at
    if busy then
        -- (as it is)
    elseif target then
        -- (Moved: more than about three yards on a zone map a few thousand across.)
        if not at or at.map ~= target.map or (at.mx - target.mx) ^ 2 + (at.my - target.my) ^ 2 > 2.5e-7 then
            if C_Map.CanSetUserWaypointOnMap(target.map) then
                if not at then world.pin, world.quest = C_Map.GetUserWaypoint(), C_SuperTrack.GetSuperTrackedQuestID() end
                -- The same one, its place on the map found a little better (it
                -- has the name, and is within some 15 yards of where the pin
                -- was): what is known of it stays, and so does its column.
                -- Another one: all is asked anew.
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
        world.Back() -- (nothing left to mark)
    end
    if db.worldReadout then world.Say(target) end
    -- Sparkles or the game's marker, by the Sparkles setting for what is marked.
    at = world.at
    local sparkly = at and db[(at.kind == "herbs" or at.kind == "ore") and at.kind or "others"] or false
    world.hide = sparkly
    if world.hide and not world.hooked and SuperTrackedFrame and SuperTrackedFrame.UpdateAlpha then
        world.hooked = true
        hooksecurefunc(SuperTrackedFrame, "UpdateAlpha", function(marker)
            if world.hide then marker:SetAlpha(0) end
        end)
    end
    -- The sparkles: on the spot the game's marker is at, while that is on screen.
    local nav = sparkly and not world.broken and C_Navigation.GetFrame()
    local distance = nav and C_Navigation.GetDistance()
    local seen = nav and distance and not issecretvalue(distance) and distance > 0
        and C_Navigation.HasValidScreenPosition() and not C_Navigation.WasClampedToScreen()
    if world.hop then
        -- (The camera is being measured: the game's marker is on the tried spot for a moment.)
        world.Hop(nav, seen, busy)
    elseif seen then
        local frame = world.frame
        if not frame then
            frame = NewSparkles()
            frame:SetParent(UIParent)
            frame:SetFrameStrata("BACKGROUND")
            world.frame = frame
        end
        -- Above you or below you: asked once a second (and at once for a new one).
        local now = GetTime()
        if target and (not world.asked or now - world.asked >= 1) then
            world.level, world.asked = world.Level(target), now
        end
        -- Is the game's marker hidden? Asked every frame, and what it says is
        -- only taken once it has said so for most of the last second: over
        -- bumps, past a tree and in a jump it goes back and forth, and the
        -- column would go from short to long and back with it. world.heat is
        -- how much of the last while it was hidden (0 to 1, half forgotten in
        -- a third of a second): above four fifths it is taken for hidden,
        -- under one fifth for in view, in between for what it was taken for
        -- before. (So it has to hold for 0.8 s.) Back on screen, what it says
        -- is taken at once.
        local passed = math.min(now - (world.seen or now), 0.1)
        world.seen = now
        local hidden = C_Navigation.GetTargetState() == 1 and 1 or 0
        if world.nav ~= nav then world.heat, world.plain, world.clear, world.blip, world.was = nil, nil, nil, nil, nil end
        world.heat = world.heat and world.heat + (hidden - world.heat) * (1 - math.exp(-passed / 0.5)) or hidden
        if world.heat > 0.8 then world.under = true elseif world.heat < 0.2 then world.under = false end
        -- And the other way: in plain view for two seconds on end (world.plain
        -- is for how long now, counted frame by frame so a long frame isn't
        -- two seconds), the spot at your own height is in the air there, so
        -- the herb is at the marker or below it ("clear": without this, a herb
        -- some yards lower than you has its sparkles way above it). Hidden
        -- once for a moment (a tree in the way) it stays so; hidden twice
        -- within three seconds (world.blip is when it last went hidden; about
        -- level with you, the marker in and out of the ground) or for good, it
        -- is no longer.
        if hidden == 1 and not world.was then
            if world.blip and now - world.blip < 3 then world.clear = false end
            world.blip = now
        end
        world.was = hidden == 1
        world.plain = hidden == 0 and (world.plain or 0) + passed or 0
        if world.under then world.clear = false elseif world.plain >= 2 then world.clear = true end
        -- The marker is at your own height and the herb straight above or
        -- below it: a column up from the marker, down from it, or a little
        -- both ways when the game has it level with you; on screen 8 yards of
        -- height at that distance, but no more than a slope of three in ten
        -- would put the herb off the marker (168 units from 27 yards in),
        -- half of that when level. Where the minimap has no arrow for it but
        -- the game says its marker is hidden, the spot at your own height is
        -- under the ground there, so the herb is above the marker: a column
        -- up from it, longer (20 yards of height, a slope of 45 in a hundred:
        -- a hillside), which "hidden" is the name for here; and where it has
        -- been in plain view all along, the same column down from it
        -- ("clear"). The sparkles themselves are smaller the farther away it is
        -- (full size within 15 yards, a fifth from 75).
        local level = world.level or "level"
        if level == "level" and world.under then
            level = "hidden"
        elseif level == "level" and world.clear then
            level = "clear"
        end
        local scale = math.max(0.2, math.min(1, 15 / distance))
        -- Where the column starts and where it ends, on screen, up from the marker.
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
        -- It goes there over a second or so, not at once, so the column
        -- doesn't jump when it changes. At once for another one, and when the
        -- marker comes back on screen.
        if world.low and world.nav == nav then
            local step = 1 - math.exp(-passed / 0.3)
            low, high = world.low + (low - world.low) * step, world.high + (high - world.high) * step
        end
        world.low, world.high, world.shape = low, high, level
        -- The area's bottom is on the marker, or that far from it (base).
        local wide, tall, base = 60, (high - low) / scale, low / scale
        frame:SetScale(scale)
        if world.nav ~= nav or math.abs(frame.tall - tall) > 0.5 or math.abs(world.base - base) > 0.5 then
            frame.wide, frame.tall, world.base = wide, tall, base
            frame:SetSize(wide, tall)
            frame:ClearAllPoints()
            -- (If the game won't have an addon's frame anchored to its marker, say so once and leave it.)
            local ok, problem = pcall(frame.SetPoint, frame, "BOTTOM", nav, "CENTER", 0, base)
            if not ok then
                world.broken = true
                frame:Hide()
                geterrorhandler()("NodeSight: sparkles can't be put on the game's marker: " .. tostring(problem))
                return
            end
            world.nav = nav
        end
        if not frame:IsShown() then world.Fill(frame) end
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

-- Every frame while the scan is on: a few more points of the scan in progress,
-- or the wait until the next one; then the places, the arrow and the far
-- sparkles follow you.
local function OnUpdate(_, elapsed)
    if scan then
        ScanSome()
    else
        -- Slower while you stand still (but not right after loot: see LOOT_CLOSED).
        wait = wait - (still and hurry == 0 and elapsed / REST[rested] or elapsed)
        if wait <= 0 then StartScan() end
    end
    Follow()
    UpdateArrow()
    world.Update()
end

-- A loading screen: you may be somewhere else, so the places and a scan half
-- done are old news.
local function NewPlace()
    scan, wait, empties, rested, markers = nil, 0, 0, 0, {}
    ShowMarkers()
    UpdateArrow()
end

-- Your loot window closed. If it was a node's, a symbol near you that was kept
-- for its kind while its finder is off (see FinishScan) is the one you just
-- picked: no scan sees its dot go until its finder's turn, so it goes now.
local function Picked()
    local kind, gone = turns.picked, false
    turns.picked = nil
    if not kind then return end
    for i = #markers, 1, -1 do
        local marker = markers[i]
        if marker.held and marker.kind == kind and marker.yards and marker.yards <= PICK_REACH then
            table.remove(markers, i)
            gone = true
        end
    end
    if gone then ShowMarkers() end
end

-- Starts or stops the scan after a setting changed, and scans again at once.
local function UpdateScanner()
    eased, quiet = 0, 0
    ApplyDetail()
    local on = Enabled()
    tracker:SetScript("OnUpdate", on and OnUpdate or nil)
    scan, wait, empties, rested = nil, 0, 0, 0
    if not on then markers = {} end
    ShowMarkers()
    UpdateArrow()
    world.Update() -- (the far sparkles: with the scan stopped nothing is left marked)
end

-- The key binding (Bindings.xml: Options > Keybindings > AddOns > NodeSight):
-- the Herb and ore symbols on the minimap setting on and off, to tell what is
-- NodeSight's from what another addon put on the minimap (a gathering addon's
-- icons can be the very same pictures). It does what the checkbox does, and
-- sets the saved setting itself, like the sparkle color's reset button: the
-- checkbox shows it the next time its page is drawn.
BINDING_HEADER_NODESIGHT = "NodeSight"
BINDING_NAME_NODESIGHT_SYMBOLS = "Toggle Herb and Ore Symbols"
function NodeSight_ToggleSymbols()
    if not tracker then return end -- (not loaded yet: the settings are still the defaults)
    db.mapIcons = not db.mapIcons
    UpdateScanner()
end

-- Sparkles on far away herbs and ore (see world). The
-- setting changed: the game only draws its marker with In-Game Navigation
-- on (off out of the box in WoW Forever), so that goes on with it, and back
-- to what it was when the setting is turned off.
function world.Changed()
    if db.worldMark then
        local now = C_CVar.GetCVar("showInGameNavigation")
        if now ~= "1" then
            db.navWas = now or "0"
            C_CVar.SetCVar("showInGameNavigation", "1")
        end
    elseif db.navWas then
        C_CVar.SetCVar("showInGameNavigation", db.navWas)
        db.navWas = nil
    end
    UpdateScanner()
end

-- The game's own dots on the minimap, bigger or smaller: Minimap:SetIconScale
-- (no code of Blizzard's calls it; 1 is taken for the game's own size). At 100
-- percent the addon leaves the game's size alone: this only runs when the
-- setting is moved, and after a loading screen while it isn't 100.
local function ApplyDotScale()
    if Minimap.SetIconScale then Minimap:SetIconScale(db.dotScale / 100) end
end

-- No parent in CreateFrame (see NewSparkles). The arrow sits near the top of the
-- screen with the name and distance under it, until you drag it somewhere
-- else (kept for the account: NodeSightDB.arrowPlace, the point, the screen's
-- point and the offsets the game gives a frame it has moved); the symbols are
-- textures on a frame over the minimap.
local function NewScanner()
    tracker = CreateFrame("Frame")
    arrow = CreateFrame("Frame")
    arrow:SetParent(UIParent)
    arrow:SetSize(ARROW_SIZE, ARROW_SIZE)
    local place = db.arrowPlace
    if place then
        arrow:SetPoint(place[1], UIParent, place[2], place[3], place[4])
    else
        arrow:SetPoint("TOP", UIParent, "TOP", 0, -170)
    end
    arrow:Hide()
    arrow:SetMovable(true)
    arrow:SetClampedToScreen(true)
    arrow:EnableMouse(true)
    arrow:RegisterForDrag("LeftButton")
    local dragging = false
    -- You let go of it (or it went while you held it: nothing left in sight,
    -- a fight): it stays there, and the place is kept.
    local function Drop()
        if not dragging then return end
        dragging = false
        arrow:StopMovingOrSizing()
        local point, _, relativePoint, x, y = arrow:GetPoint()
        db.arrowPlace = { point, relativePoint, x, y }
    end
    arrow:SetScript("OnDragStart", function()
        dragging = true
        arrow:StartMoving()
    end)
    arrow:SetScript("OnDragStop", Drop)
    arrow:SetScript("OnHide", Drop)
    arrowTexture = arrow:CreateTexture(nil, "OVERLAY")
    arrowTexture:SetAllPoints(arrow)
    arrowTexture:SetAtlas(ARROW)
    arrowText = arrow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arrowText:SetPoint("TOP", arrow, "BOTTOM", 0, -2)
    mapFrame = CreateFrame("Frame")
    mapFrame:SetParent(Minimap)
    mapFrame:SetAllPoints(Minimap)
end

---------------------------------------------------------------------------
-- What's new: the What's New button at the top of each settings page (see
-- RegisterSettings) shows the patch notes in a dialog in the look of
-- Blizzard's own (nothing opens by itself). WHATS_NEW is a list of versions,
-- the newest first, each with its `version` (one without it is titled with the
-- .toc's). A version's notes are sections of items: an item's name (in gold)
-- and what it does, or just a line. A new release's notes go on top and the
-- others move down; a small patch version doesn't have to add any (the dialog
-- then still opens on the last version that did). Two arrows at the dialog's
-- top, Blizzard's page arrows, go to the version before (the right one) and
-- back (the left one). Notes too long for the screen at the usual width get a
-- wider dialog, so its Okay button can always be reached.
---------------------------------------------------------------------------
local ShowWhatsNew
do
    local WHATS_NEW = {
        { version = "1.3.0", -- (still the first: the patch versions after it added no notes)
            { "New", {
                { "Sparkles on far away herbs and ore (Beta) (off by default).", "Sparkles on the herb or ore you are facing, and on up to four more, from as far away as your minimap shows them. This does not work perfectly: on hills the sparkles can be above or below the herb, and it uses a lot more CPU than with it off. It will be improved in further updates. While it is on it uses the game's map pin and In-Game Navigation, in place of your own map pin and tracked quest. Turn it on under Beta, with Sparkles on herbs or Sparkles on ore on" },
                { "Rare beasts on the minimap (Beta) (on by default).", "For hunters. Track Beasts shows every beast as the same dot: with this on, a rare beast's dot gets a rare symbol (three to pick from), and the arrow, if you have it on, points to the nearest one. It needs Track Beasts on, and can be turned off under Beta. It knows the rare beasts by their English names" },
                { "Gray symbols in caves.", "A herb or ore in a cave has a gray symbol." },
                { "Sound when something new shows up (off by default).", "Plays a sound when a new herb, ore, chest or rare beast shows up on your minimap. Turn it on in NodeSight's settings" },
                { "Key binding for the symbols (no key set by default).", "Turns the herb and ore symbols on the minimap on and off with a key" },
            } },
            { "Changes", {
                "Switch between herbs and ore and Yards between switches are out of Beta and on NodeSight's own page",
                "The settings are sorted into pages. The basics are on NodeSight's own page, and Symbols, Sparkles and Beta have pages of their own under it",
                "What's New has arrows now: the right one shows the notes of the version before",
                "Small performance improvements",
            } },
        },
        { version = "1.2.0",
            { "New", {
                { "Switch between herbs and ore (Beta) (off by default).", "NodeSight turns on Find Herbs and Find Minerals on and off as you move so you find both without switching yourself. The symbols of the one that is off stay on your minimap, so you see herbs and ore together. You need both Find Herbs and Find Minerals, with one of them turned on, and it never switches in combat. Turn it on under Arrow and minimap. Thank you W8kingNightmare for the amazing suggestion" },
                { "Treasure chests for dwarves (Beta)", "With Find Treasure on, the chests on your minimap get a chest symbol the way herbs and ore get theirs, and the arrow points to the nearest one" },
                { "You can move the arrow now!", "Drag the arrow to put it where you want it" },
            } },
            { "Changes", {
                "While you stand still, NodeSight scans the minimap less and less",
                "With Sparkles on other objects on, mailboxes and things you only use, like chairs and doors no longer sparkle. Chests and quest objects still do",
            } },
            { "Fixes", {
                "The arrow no longer points to a herb or ore you don't have the skill for. It goes to the nearest one you can gather, and there is no arrow when you can't gather anything in sight.",
                "Minor fixes to the scanning logic",
                "NodeSight now only scans the minimap while Find Herbs, Find Minerals or Find Treasure is on. A character with none would still be scanning the minimap before",
                "Opening the game's Options no longer gives an error from NodeSight",
            } },
        },
    }
    -- No parent in CreateFrame (see NewSparkles).
    local function NewFrame(kind, parent)
        local frame = CreateFrame(kind)
        frame:SetParent(parent)
        return frame
    end
    local function DialogButton(parent, text, onClick)
        local button = NewFrame("Button", parent)
        button:SetSize(128, 21) -- Blizzard's StaticPopupButtonTemplate
        button:SetNormalTexture("Interface\\Buttons\\UI-DialogBox-Button-Up")
        button:GetNormalTexture():SetTexCoord(0, 1, 0, 0.71875)
        button:SetPushedTexture("Interface\\Buttons\\UI-DialogBox-Button-Down")
        button:GetPushedTexture():SetTexCoord(0, 1, 0, 0.71875)
        button:SetHighlightTexture("Interface\\Buttons\\UI-DialogBox-Button-Highlight", "ADD")
        button:GetHighlightTexture():SetTexCoord(0, 1, 0, 0.71875)
        button:SetNormalFontObject(GameFontNormal)
        button:SetHighlightFontObject(GameFontHighlight)
        button:SetText(text)
        button:SetScript("OnClick", onClick)
        return button
    end
    local dialog = { page = 1 } -- the window: its frame, text and arrows (older, newer), and which of WHATS_NEW shows
    -- Shows a version's notes: its text, the dialog as tall as that (wider if
    -- it is too tall for the screen), and each arrow only while there is a
    -- version that way.
    function dialog.ShowPage()
        local notes = WHATS_NEW[dialog.page]
        local lines = { NORMAL_FONT_COLOR:WrapTextInColorCode(("NodeSight %s"):format(
            notes.version or C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version"))) }
        for _, section in ipairs(notes) do
            lines[#lines + 1] = "\n" .. NORMAL_FONT_COLOR:WrapTextInColorCode(section[1])
            for _, item in ipairs(section[2]) do
                if type(item) == "table" then item = NORMAL_FONT_COLOR:WrapTextInColorCode(item[1]) .. " " .. item[2] end
                lines[#lines + 1] = "- " .. item
            end
        end
        local frame, text = dialog.frame, dialog.text
        frame:SetWidth(480)
        text:SetWidth(440)
        text:SetText(table.concat(lines, "\n"))
        if text:GetStringHeight() + 73 > UIParent:GetHeight() - 145 then -- (it hangs 135 below the top)
            frame:SetWidth(720)
            text:SetWidth(680)
        end
        frame:SetHeight(text:GetStringHeight() + 73)
        dialog.older:SetEnabled(dialog.page < #WHATS_NEW)
        dialog.newer:SetEnabled(dialog.page > 1)
    end
    -- An arrow pressed: the version before (1) or after (-1), if there is one,
    -- with the sound Blizzard's page arrows make.
    function dialog.Turn(by)
        if not WHATS_NEW[dialog.page + by] then return end
        dialog.page = dialog.page + by
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        dialog.ShowPage()
    end
    function ShowWhatsNew()
        if not dialog.frame then
            local frame = NewFrame("Frame", UIParent)
            frame:SetFrameStrata("DIALOG")
            frame:SetToplevel(true)
            frame:EnableMouse(true)
            frame:SetPoint("TOP", UIParent, "TOP", 0, -135)
            local background = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
            background:SetAtlas("UI-DialogBox-Background-Dark", true)
            background:SetPoint("TOPLEFT", 7, -7)
            background:SetPoint("BOTTOMRIGHT", -7, 7)
            local edge = frame:CreateTexture(nil, "BACKGROUND", nil, -4)
            edge:SetAtlas("UI-DiamondDialogBox-Border", true)
            edge:SetAllPoints()
            local text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            text:SetPoint("TOP", 0, -20)
            text:SetJustifyH("LEFT")
            text:SetSpacing(3)
            text:SetIndentedWordWrap(true) -- a long item's next lines start further in
            -- The arrows: Blizzard's page arrows (its merchant window's Prev
            -- and Next: the same pictures and size), at the top right beside
            -- the title, where they stay put while the dialog's height changes
            -- with the notes. The right one goes on to the version before (the
            -- next page), the left one back.
            local function ArrowButton(way, by)
                local button = NewFrame("Button", frame)
                button:SetSize(32, 32)
                button:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. way .. "Page-Up")
                button:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. way .. "Page-Down")
                button:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. way .. "Page-Disabled")
                button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
                button:SetScript("OnClick", function() dialog.Turn(by) end)
                return button
            end
            dialog.frame, dialog.text = frame, text
            dialog.older = ArrowButton("Next", 1)
            dialog.older:SetPoint("TOPRIGHT", -14, -10)
            dialog.newer = ArrowButton("Prev", -1)
            dialog.newer:SetPoint("RIGHT", dialog.older, "LEFT", 0, 0)
            DialogButton(frame, OKAY, function() frame:Hide() end):SetPoint("BOTTOM", 0, 16)
        end
        dialog.page = 1 -- (opened: this version's)
        dialog.ShowPage()
        dialog.frame:Show()
    end
end

---------------------------------------------------------------------------
-- Settings panel (Options > AddOns > NodeSight, and the pages under it)
---------------------------------------------------------------------------

local function RegisterSettings()
    -- The main page has the basics (and Switch between herbs and ore). The
    -- rows below are added to `category` (and the button row to its `layout`):
    -- the main page, until Page() starts a page under it (Symbols, Sparkles,
    -- Beta: the game lists them under NodeSight in its list of addons).
    local main, layout = Settings.RegisterVerticalLayoutCategory("NodeSight")
    local category, pages = main, { [main] = true }
    local function Page(name)
        category, layout = Settings.RegisterVerticalLayoutSubcategory(main, name)
        pages[category] = true
    end

    -- A setting kept in NodeSightDB under its key, with what runs when it changes.
    local function Register(key, name, onChange)
        local setting = Settings.RegisterAddOnSetting(category, "NodeSight_" .. key, key, db,
            type(defaults[key]), name, defaults[key])
        setting:SetValueChangedCallback(onChange)
        return setting
    end

    local function Checkbox(key, name, tooltip, onChange)
        Settings.CreateCheckbox(category, Register(key, name, onChange), tooltip)
    end

    local function Slider(key, name, minValue, maxValue, tooltip, onChange)
        local options = Settings.CreateSliderOptions(minValue, maxValue, 1)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
        Settings.CreateSlider(category, Register(key, name, onChange), options, tooltip)
    end

    -- The game's own color swatch: a click on it opens the game's color picker.
    local function ColorSwatch(key, name, tooltip, onChange)
        Settings.CreateColorSwatch(category, Register(key, name, onChange), tooltip)
    end

    local function Dropdown(key, name, choices, tooltip, onChange)
        local function GetOptions()
            local container = Settings.CreateControlTextContainer()
            for value, label in ipairs(choices) do container:Add(value, label) end
            return container:GetData()
        end
        Settings.CreateDropdown(category, Register(key, name, onChange), GetOptions, tooltip)
    end

    -- Any sparkles on: the game's interact detection goes on with them, and
    -- its own icon and name are hidden. The last ones off: all of it goes back.
    local NEEDS = " While any sparkles are on, NodeSight turns on Enable Interact Key, the interact icons for objects and picking a target in every direction around you (Options > Controls and Accessibility), which the sparkles need, and hides the game's own icon and name. Turning all sparkles off puts your settings back as they were."
    local function SparklesChanged()
        UpdateAll()
        Setup()
    end

    -- The What's New button, left of Blizzard's Defaults button at the top of
    -- each of NodeSight's pages, in its look: the same template and size, 2 apart like the
    -- window's own Apply and Close buttons, Blizzard's own wording. Its parent
    -- is the Defaults button, so it hides with it while search results show,
    -- and Blizzard says when another page is picked. Left out if Blizzard's
    -- header isn't as expected, and with the controller UI on (a mouse button
    -- on Blizzard's header hasn't been tried there).
    local list = SettingsPanel and SettingsPanel.Container and SettingsPanel.Container.SettingsList
    local defaultsButton = list and list.Header and list.Header.DefaultsButton
    if defaultsButton and C_InputInterfaceStyle.GetCurrentStyle() ~= Enum.InputDeviceInterfaceType.Gamepad then
        local button = CreateFrame("Button", nil, nil, "UIPanelButtonTemplate")
        button:SetParent(defaultsButton)
        button:SetSize(96, 22)
        button:SetPoint("RIGHT", defaultsButton, "LEFT", -2, 0)
        button:SetText(GAMEMENU_NEW_BUTTON)
        button:SetScript("OnClick", ShowWhatsNew)
        button:Hide()
        EventRegistry:RegisterCallback("Settings.CategoryChanged", function(_, shown)
            button:SetShown(pages[shown] == true)
        end, button)
    end

    Checkbox("scan", "Scan the minimap",
        "Scans the minimap for herbs and ore, for the arrow and the symbols. Turn it off to use only the sparkles: nothing is scanned then.",
        UpdateScanner)
    Checkbox("combatScan", "Scan in combat",
        "Keeps scanning the minimap during fights, so new herbs and ore still show up. With it off, the symbols you have stay during a fight and new ones show up after it. Needs Scan the minimap.",
        UpdateScanner)
    Checkbox("arrow", "Arrow to the nearest herb or ore",
        "An arrow near the top of the screen points to the nearest herb or ore on your minimap, with its name and distance. Needs Scan the minimap, and Find Herbs or Find Minerals on. Zoom the minimap out to see farther. Drag the arrow to move it.",
        UpdateScanner)
    Checkbox("mapIcons", "Herb and ore symbols on the minimap",
        "Puts the herb's or ore's map symbol on the minimap where the scan finds one. Needs Scan the minimap, and Find Herbs or Find Minerals on.",
        UpdateScanner)
    Checkbox("sound", "Sound when something new shows up",
        "Plays the minimap's ping sound when a herb, ore, chest or rare beast shows up on your minimap that wasn't there in the last minute. Not for a herb or ore above your skill. Needs Scan the minimap.",
        UpdateScanner)
    Checkbox("switchFinders", "Switch between herbs and ore",
        "Switches between Find Herbs and Find Minerals. You need both trained and one active to start.",
        UpdateScanner)
    Slider("switchYards", "Yards between switches", 10, 50,
        "How far you go before the other one is turned on. The default is " .. defaults.switchYards .. ". Needs Switch between herbs and ore.",
        UpdateScanner)

    Page("Symbols")
    Checkbox("hard", "Red symbols when your skill is too low",
        "A herb or ore you can't gather yet, because it needs more Herbalism or Mining skill than you have, has a red symbol. Needs Herb and ore symbols on the minimap.",
        UpdateScanner)
    Dropdown("shape", "Symbol shape", SHAPES,
        "The shape of the herb and ore symbols on the minimap: round with the game's gold ring around it, round without it, or square like the game's item icons. Needs Scan the minimap.",
        UpdateScanner)
    Checkbox("oreRings", "High visibility tin and iron",
        "Tin and iron look alike on the minimap. With this on, tin's symbol gets a green ring and iron's a rust one, in place of the gold ring. Needs Symbol shape at Round, gold ring.",
        UpdateScanner)
    Slider("iconSize", "Symbol size", 8, 24,
        "How big the herb and ore symbols on the minimap are. The default is " .. defaults.iconSize .. ". Needs Herb and ore symbols on the minimap.",
        UpdateScanner)
    Slider("dotScale", "Size of the game's own dots", 50, 300,
        "How big the game's own dots on the minimap are, in percent: 100 is the game's own size, which NodeSight leaves alone until you move this. Change it together with Symbol size to get the size you want.",
        ApplyDotScale)
    Slider("scanDetail", "Scan detail", 1, 3,
        "How closely the minimap is scanned for the arrow and the symbols. Needs Scan the minimap. Where the scan starts; after a few scans with no new herb it eases down by itself, and a new herb brings it back. 3: the most exact. 2 (the default): about a third fewer points, a scan every three quarters of a second. 1: about half the points, a scan every second; it uses the least CPU but can place herbs poorly.",
        UpdateScanner)

    Page("Sparkles")
    Checkbox("herbs", "Sparkles on herbs",
        "Sparkles around the nearest herb." .. NEEDS,
        SparklesChanged)
    Checkbox("ore", "Sparkles on ore",
        "Sparkles around the nearest ore (mining node)." .. NEEDS,
        SparklesChanged)
    Checkbox("others", "Sparkles on other objects",
        "Sparkles around the other objects the game puts an interact icon on (chests, quest objects, ...). Not mailboxes, or things you only use, like chairs and doors." .. NEEDS,
        SparklesChanged)
    ColorSwatch("sparkleColor", "Sparkle color",
        "The color the sparkles are tinted. Click the color to pick your own. White shows the sparkles in their own colors.",
        UpdateAll)
    -- A way back to the sparkles' own colors. It sets the saved color itself:
    -- going through the game's setting from addon code would run Blizzard's
    -- color row (shared with its own Raid Frames page) under the addon's
    -- taint. So the color above only shows the change the next time the page
    -- is drawn. No search tags (addon code would be adding them).
    layout:AddInitializer(CreateSettingsButtonInitializer("Reset the sparkle color", RESET, function()
        db.sparkleColor = defaults.sparkleColor
        UpdateAll()
    end, "Resets sparkles back to their original color.", false))
    Slider("size", "Sparkle area", 30, 200,
        "How big the area around the herb or ore is that the sparkles twinkle in. The default is " .. defaults.size .. ".",
        UpdateAll)
    Slider("height", "Sparkle height", -100, 100,
        "Moves the sparkles up or down, if they sit above or below the herb or ore. The default is " .. defaults.height .. ".",
        UpdateAll)
    Slider("count", "Number of sparkles", 1, 20,
        "How many sparkles twinkle at once. The default is " .. defaults.count .. ".",
        UpdateAll)

    Page("Beta")
    Checkbox("rares", "Rare beasts on the minimap (Beta)",
        "For hunters. Track Beasts shows every beast as the same dot: with this on, a rare beast's dot gets a rare symbol, and the arrow, if you have it on, points to the nearest one. Needs Scan the minimap, and Track Beasts on.",
        UpdateScanner)
    Dropdown("rareIcon", "Rare beast symbol", { "Rare icon", "Elite rare icon", "Star" },
        "Which of the game's own rare symbols a rare beast's dot gets. Needs Rare beasts on the minimap.",
        UpdateScanner)
    Checkbox("worldMark", "Sparkles on far away herbs and ore (Beta)",
        "Sparkles on the herb or ore you face, from far away. Does not work perfectly and uses a lot more CPU than with it off. It will be improved in further updates. Takes over your map pin while on. Needs Sparkles on herbs or ore.",
        world.Changed)

    Settings.RegisterAddOnCategory(main)
end

local MINIMAP_TOOLTIP = Enum.TooltipDataType.MinimapMouseover -- the kind of tooltip the minimap's dots have

local function OnAddonLoaded()
    NodeSightDB = NodeSightDB or {}
    for key, value in pairs(defaults) do
        if NodeSightDB[key] == nil then NodeSightDB[key] = value end
    end
    -- A saved color that the color swatch couldn't have given is the default.
    NodeSightDB.sparkleColor = tostring(NodeSightDB.sparkleColor):match("^%x%x%x%x%x%x%x%x$") or defaults.sparkleColor
    -- A saved shape that is none of the shapes is the default.
    if not SHAPES[NodeSightDB.shape] then NodeSightDB.shape = defaults.shape end
    -- ...and so is a saved rare symbol that is none of the three.
    if not ICONS.rares[NodeSightDB.rareIcon] then NodeSightDB.rareIcon = defaults.rareIcon end
    -- A saved distance between switches under the slider's least is that
    -- least.
    if NodeSightDB.switchYards < 10 then NodeSightDB.switchYards = 10 end
    db = NodeSightDB
    NewScanner()
    UpdateScanner()
    -- What the addon changed, and what it set it to, to put back.
    NodeSightDB.saved = NodeSightDB.saved or {}
    NodeSightDB.applied = NodeSightDB.applied or {}
    -- The herbs and ore learned by gathering them (see Learn).
    NodeSightDB.learned = NodeSightDB.learned or {}
    -- Also with WoW Forever's controller UI (Enable Gamepad UI) on: the page,
    -- the scan and the interact detection all work there (checked in game).
    RegisterSettings()
    -- What a herb or ore under the mouse on the minimap needs (see OnMinimapTooltip).
    if MINIMAP_TOOLTIP then TooltipDataProcessor.AddTooltipPostCall(MINIMAP_TOOLTIP, OnMinimapTooltip) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
events:RegisterEvent("LOOT_READY")
events:RegisterEvent("LOOT_CLOSED")
events:RegisterEvent("PLAYER_STARTED_MOVING")
events:RegisterEvent("MINIMAP_UPDATE_ZOOM")
events:RegisterEvent("MINIMAP_UPDATE_TRACKING")
events:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
events:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            events:UnregisterEvent("ADDON_LOADED")
            OnAddonLoaded()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        NewPlace()
        if db.dotScale ~= NORMAL_DOTS then ApplyDotScale() end
        -- (With no sparkles on, anything still applied from before, say a
        -- restore that waited for the end of a fight and a reload, goes back.)
        Setup() -- after every loading screen
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        -- The plate's unit is gone, and the game hides the plate: its sparkle
        -- frame is free for the next one. (No plate sparkles: nothing to ask.)
        if next(sparkles) then HideSparkles(C_NamePlate.GetNamePlateForUnit(arg1)) end
    elseif event == "UNIT_SPELLCAST_SENT" then
        NoteCast(arg2)
    elseif event == "LOOT_READY" then
        Learn()
    elseif event == "LOOT_CLOSED" then
        -- You may just have picked a herb, standing still, where the scan is
        -- slow: scan at once, and twice more at the full pace (its dot can take
        -- a moment to go), so its symbol goes when its dot does.
        wait, hurry = 0, 3
        Picked()
    elseif event == "PLAYER_STARTED_MOVING" or event == "MINIMAP_UPDATE_ZOOM" or event == "MINIMAP_UPDATE_TRACKING" then
        -- You set off, zoomed the minimap or changed what it tracks: the rest
        -- is over, and the next scan comes after the usual wait at the latest
        -- (after a change of tracking the dots take a moment: SWITCH_WAIT).
        local soon = event == "MINIMAP_UPDATE_TRACKING" and SWITCH_WAIT or WAIT
        empties, rested = 0, 0
        if wait > soon then wait = soon end
    elseif event == "PLAYER_REGEN_DISABLED" then
        world.Fight()
    else -- (PLAYER_REGEN_ENABLED) the fight is over
        wait = 0 -- (nothing was scanned in it: what changed meanwhile shows at once)
        world.fight = nil
        if pendingSetup then Setup() end
    end
end)
