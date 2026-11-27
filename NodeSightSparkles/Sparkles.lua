-- Sparkles on the herb or ore in front of you. They sit on the
-- nameplate of the game's soft interact target, so while sparkles are on the
-- interact CVars are turned on and Blizzard's object plates are hidden (unless
-- the game's icons are kept).
--
-- Sections: Each kind's look, Telling herbs and ore apart, Sparkles, Styles,
-- Made sparkles, In reach and fading, Camera zoom, Showing sparkles, Gathering,
-- Nameplates, Interact detection.

local _, ns = ...

local ipairs, pairs = ipairs, pairs
local random = math.random
local sin, cos, floor, max, min, abs, pi = math.sin, math.cos, math.floor, math.max, math.min, math.abs, math.pi

-- Any sparkle switch on? Only then are Blizzard's object plates hidden.
local function SparkleSwitchesOn()
    return ns.db.herbs or ns.db.ore or ns.db.chests or ns.db.quests or ns.db.others or ns.db.bobber or ns.db.skinning or ns.db.loot
end

-- The main file started: it stays off, with no saved CVars, when a file is missing
-- (updated without a game restart).
local function Running() return ns.db.saved ~= nil end

-- Any sparkles on, or the Cultivation icon (Cultivation.lua) for a player who knows
-- the racial? Only then does the addon touch interact settings or plates.
local function SparklesOn()
    if not Running() then return false end
    return SparkleSwitchesOn() or ns.CultivationOn()
end

-- The gathering nodes' sparkle (world/skillactivated/tradeskillnodes/sparkle.blp).
local PICTURE = 984391
-- Blizzard's art for the other styles: a four-point star, a soft round glow, a gold ring.
local GLOW = "BonusChest-CircleGlow"
local RING = "PowerSwirlAnimation-YellowRing"
local STAR4 = 131010 -- Interface\Cooldown\star4, the cooldown's finish flash
local SOFT_STAR = "GarrisonFX-StarBurst"
local TOO_HARD_GRAY = "ff8c8c8c" -- herbs and ore above your skill, with Gray when your skill is too low
-- With Skill colors: herbs and ore by Names.lua's SkillLevel (too hard, then the
-- profession window's orange, yellow, green and gray).
local SKILL_COLORS = { "ffff2020", "ffff8040", "ffffff00", "ff40bf40", TOO_HARD_GRAY }
local RARE_COLOR = "ffffd100" -- a rare node's glow
-- Rare herbs and ore (English names, as Names.lua keys them in every language).
local RARE = {
    ["black lotus"] = true, ["silver vein"] = true, ["ooze covered silver vein"] = true, ["gold vein"] = true,
    ["ooze covered gold vein"] = true, ["truesilver deposit"] = true, ["ooze covered truesilver deposit"] = true,
    ["dark iron deposit"] = true, ["rich thorium vein"] = true, ["ooze covered rich thorium vein"] = true,
}
local BUBBLE = 241052 -- spells/t_vfx_bubble.blp, a clear bubble with a highlight
-- Painted pictures, drawn as they are: a butterfly (spells/butterfly.blp) and the
-- Zuldazar vault's gold coin turning over, 16 frames in 8 columns and 2 rows.
local BUTTERFLY, VAULT_COIN = 165767, 2449274
-- The gossip window's quest "!" (painted), the minimap ping's glowing "!" and a firefly's glow.
local QUEST_MARK, PING_MARK, FIREFLY = 132049, 136440, 190732
-- With Sparkle sound: the map's waypoint chime (the minimap ping where a
-- client has no such sound), once a name in SOUND_AGAIN seconds, never two at once.
local SPARKLE_SOUND = SOUNDKIT.UI_MAP_WAYPOINT_SUPER_TRACK_ON or SOUNDKIT.MAP_PING
local SOUND_AGAIN, SOUND_APART = 30, 2
local heard, heardAt = {}, 0 -- name: when its sound played
-- The flash when a node comes into reach (Interface\Cooldown\starburst).
local BURST = 131011
-- Corpses: spells/fly03.blp, a fly with its wings on the left half, without on the right.
local FLY = 166202

-- Each sparkle is a body plus a smaller, lighter core.
local CORE = 0.45 -- core size relative to the body
local CORE_LIGHT = 0.6 -- how much lighter the core's tint is
local BEAM_FOOT = 0.1 -- the beam's alpha at its foot, where the node is
-- A rare node's glow (and Glow around the node): a soft round light centered on it, so
-- it looks the same from any camera angle (sizes and its middle's height in areas).
local GLOW_WIDE, GLOW_TALL, GLOW_Y = 1.3, 1, -0.1

-- Blizzard plates we hid (alpha 0), keyed by frame.
local hidden = {}
-- Sparkle frames by plate, and spares to reuse.
local sparkles = {}
local spare = {}
-- The sparkle window's previews keep frames of their own (never a plate's spare).
local previews = {}
local leaving = {} -- plate: its sparkles fading out
local known = {} -- plate: what its object's icon said it was
local looted = {} -- plate: a corpse whose loot window opened (its sparkles gone until the plate's next unit)

---------------------------------------------------------------------------
-- Each kind's look
---------------------------------------------------------------------------
-- Herbs' keys have no prefix.

local KINDS = { "herbs", "ore", "chests", "quests", "others", "bobber", "skinning", "loot" }
local KEYS = {
    herbs = { style = "herbStyle", color = "sparkleColor", color2 = "sparkleColor2", size = "size", height = "height", count = "count",
        made = "herbMade", style2 = "herbStyle2", made2 = "herbMade2", glow = "herbNodeGlow" },
}
-- made: the id of a Sparkle Maker sparkle used instead of the style; style2 or made2: a
-- second style or sparkle shown with it; glow: a soft glow around the node too (nil is off).
for _, kind in ipairs({ "ore", "chests", "quests", "others", "bobber", "skinning", "loot" }) do
    KEYS[kind] = { style = kind .. "Style", color = kind .. "Color", color2 = kind .. "Color2", size = kind .. "Size", height = kind .. "Height",
        count = kind .. "Count", made = kind .. "Made", style2 = kind .. "Style2", made2 = kind .. "Made2",
        glow = kind .. "NodeGlow" }
end

local function Look(kind, what) return ns.db[KEYS[kind or "herbs"][what]] end

-- A kind's two colors; with no second color saved, the first twice.
local function Colors(kind)
    local one = Look(kind, "color")
    return one, Look(kind, "color2") or one
end

-- A frame's look: what frame.over gives (the sparkle window's previews), a made
-- sparkle's (its size and height), or its kind's.
local function FrameLook(frame, what)
    local over = frame.over
    if over and over[what] ~= nil then return over[what] end
    if frame.madeLook then return frame.madeLook[what] end
    return Look(frame.kind, what)
end

-- Nodes whose plate sits higher over the plant than most: their sparkles go this much lower.
local LOWER = { silverleaf = 15 }

-- Where the sparkles' middle is, under the plate's bottom.
local function Height(frame)
    return FrameLook(frame, "height") - (frame.lower or 0)
end

-- Before the defaults are filled in: chests and quest objects (other objects before)
-- start as other objects were, and the other kinds from the herbs' saved look (but
-- not the height of the bobber, which floats on the water, or of corpses, whose
-- plate stays where the living creature's was).
local function CarryOverLooks(db)
    for _, kind in ipairs({ "chests", "quests" }) do
        -- Only once: a kind's second color is often unset, and must stay so.
        if db[kind] == nil then
            db[kind] = db.others
            for what, key in pairs(KEYS[kind]) do
                if db[key] == nil then db[key] = db[KEYS.others[what]] end
            end
        end
    end
    for _, what in ipairs({ "color", "size", "height", "count" }) do
        local saved = db[KEYS.herbs[what]]
        if saved ~= nil then
            for kind, keys in pairs(KEYS) do
                if kind ~= "herbs" and db[keys[what]] == nil and not ((kind == "bobber" or kind == "skinning" or kind == "loot") and what == "height") then db[keys[what]] = saved end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Telling herbs and ore apart
---------------------------------------------------------------------------
-- By the name of the interact icon's texture or atlas: "herb" or "mine".

local function HasName(name, a, b)
    if issecretvalue(name) or type(name) ~= "string" then return false end
    name = name:lower()
    return name:find(a, 1, true) ~= nil or (b ~= nil and name:find(b, 1, true) ~= nil)
end

-- "herbs", "ore", "skinning", "loot" (the loot cursor: a corpse to loot, or a chest),
-- "quests", "others", or "plain" (never sparkles: guild vault, mailbox, chairs, doors).
-- A hidden icon counts as "others".
local function Kind(icon)
    if not icon:IsShown() then return "others" end
    local texture, atlas = icon:GetTexture(), icon:GetAtlas()
    if HasName(texture, "herb") or HasName(atlas, "herb") then return "herbs" end
    if HasName(texture, "mine", "mining") or HasName(atlas, "mine", "mining") then return "ore" end
    if HasName(texture, "skin") or HasName(atlas, "skin") then return "skinning" end
    if HasName(texture, "loot") or HasName(atlas, "loot") then return "loot" end
    if HasName(texture, "buy") or HasName(atlas, "buy") then return "plain" end
    if HasName(texture, "mail") or HasName(atlas, "mail") then return "plain" end
    if HasName(texture, "questinteract") or HasName(atlas, "questinteract") then return "quests" end
    if HasName(texture, "interact") or HasName(atlas, "interact") then return "plain" end
    return "others"
end

-- With Interact Key Icons set to None the plate icon stays hidden, so the
-- object's cursor is read onto our own texture instead (SetUnitCursorTexture).
local probe

-- Also true when an icon was read (the object is your interact target).
local function ObjectKind(unit, icon)
    if icon:IsShown() then return Kind(icon), true end
    if not SetUnitCursorTexture then return "others" end
    local picked = UnitIsUnit(unit, "softinteract")
    if issecretvalue(picked) or not picked then return "others" end -- a secret can't be tested
    if not probe then probe = CreateFrame("Frame"):CreateTexture() end
    if not SetUnitCursorTexture(probe, unit, nil, true, true) then return "others" end
    return Kind(probe), true
end

-- The bobber has the plain interact icon. Its object ID (in its GUID) says
-- what it is; without a readable GUID, an object while you fish is taken for it.
-- Bobber toys (Crate of Bobbers, Oversized Bobber) swap it for objects of their own.
local BOBBERS = { [35591] = true }
for _, id in ipairs({ 241592, 241593, 241594, 241595, 241596, 245190, 251708, 266869, 353192, 355518,
    520304, 520305, 520306, 520308, 520309, 520311 }) do BOBBERS[id] = true end
for id = 268883, 268888 do BOBBERS[id] = true end
for id = 385541, 385553 do BOBBERS[id] = true end -- the toys' bobbers made big
local FISHING_ICON = 136245 -- the Fishing spell's icon, the same in every language

local function Fishing()
    local _, _, icon = UnitChannelInfo("player")
    return not issecretvalue(icon) and icon == FISHING_ICON
end

-- An object's ID, the sixth part of its GUID; nil for anything else.
local function ObjectID(guid)
    local id = not issecretvalue(guid) and type(guid) == "string" and guid:match("^GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    return id and tonumber(id) or nil
end

local function IsBobber(unit)
    local id = ObjectID(UnitGUID(unit))
    if id then return BOBBERS[id] == true end
    return Fishing()
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
    local size = FrameLook(frame, "size")
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

local function Lighter(r, g, b)
    return r + (1 - r) * CORE_LIGHT, g + (1 - g) * CORE_LIGHT, b + (1 - b) * CORE_LIGHT
end

-- Tints a sparkle. A color puts the alpha back to 1, so it goes to 0 again: a sparkle
-- is unseen until its twinkle fades it in.
local function ApplyColor(part, color)
    if part.color ~= color then
        part.color = color
        local r, g, b = RGB(part.color)
        part.texture:SetVertexColor(r, g, b)
        part.core:SetVertexColor(Lighter(r, g, b))
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
        local rise = FrameLook(frame, "size") * 0.1
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
    frame.parts, frame.free = {}, {}
    return frame
end

-- Starts `count` twinkling sparkles in a frame and stops the rest.
local function ShowTwinkles(frame, count, one, two)
    local parts = frame.parts
    for i = 1, count do
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
    for i = count + 1, #parts do
        parts[i].group:Stop()
        parts[i].coreGroup:Stop()
        parts[i].texture:Hide()
        parts[i].core:Hide()
    end
end

---------------------------------------------------------------------------
-- Styles
---------------------------------------------------------------------------
-- Every style but Twinkle is moved each frame from the frame's OnUpdate, which
-- only runs while the frame is shown. Sizes are in parts of the sparkle area (S).

local function Bell(u) return sin(pi * u) end
local function EaseOut(u) return 1 - (1 - u) * (1 - u) end
local function EaseIn(u) return u * u end

-- An atlas if the game has it, else the node sparkle.
local function Paint(texture, picture)
    if type(picture) == "string" and C_Texture.GetAtlasInfo(picture) then
        texture:SetAtlas(picture)
    else
        texture:SetTexture(type(picture) == "number" and picture or PICTURE)
    end
end

-- The lower half of the round glow, upside down: wide and bright at the bottom,
-- narrowing and fading to the top. Stretched tall, it is a beam of light.
local function HalfGlow(texture)
    local info = C_Texture.GetAtlasInfo(GLOW)
    if not (info and info.file) then
        Paint(texture, GLOW)
        return
    end
    texture:SetTexture(info.file)
    texture:SetTexCoord(info.leftTexCoord, info.rightTexCoord, info.bottomTexCoord,
        (info.topTexCoord + info.bottomTexCoord) / 2)
end

-- A texture of a style: added light, above the twinkles (sublevels 2 and up).
-- The game never frees textures, so a frame keeps the ones a style gave back
-- (Free) and hands them out again. "half" is HalfGlow's picture. how: "painted"
-- (drawn as it is, not as light).
local function Layer(frame, picture, sublevel, light, how)
    local key = tostring(picture) .. ":" .. sublevel .. (light and "+" or "") .. (how or "")
    local free = frame.free[key]
    local texture = free and table.remove(free)
    if not texture then
        texture = frame:CreateTexture(nil, "OVERLAY", nil, sublevel)
        if picture == "half" then HalfGlow(texture) else Paint(texture, picture) end
        texture:SetBlendMode(how == "painted" and "BLEND" or "ADD")
        -- The ring in grays; it and the bubble tinted a little blue, like water.
        if picture == RING then texture:SetDesaturated(true) end
        texture.layerKey, texture.light, texture.water = key, light, picture == RING or picture == BUBBLE
        texture.column = picture == "half"
    end
    texture:Hide()
    return texture
end

-- Gives a style's textures back to the frame.
local function Free(frame, list)
    for _, v in pairs(list) do
        if type(v) == "table" then
            if v.layerKey then
                v:Hide()
                frame.free[v.layerKey] = frame.free[v.layerKey] or {}
                table.insert(frame.free[v.layerKey], v)
            else
                Free(frame, v)
            end
        end
    end
end

-- Centers a layer at x, y (from the area's middle) with a size and alpha.
local function Put(frame, texture, x, y, w, h, alpha)
    if alpha <= 0.002 or w < 0.5 then
        texture:Hide()
        return
    end
    texture:ClearAllPoints()
    texture:SetPoint("CENTER", frame, "CENTER", x, y)
    texture:SetSize(w, h or w)
    texture:SetAlpha(alpha > 1 and 1 or alpha)
    texture:Show()
end

-- A body and its lighter core at one spot.
local function PutSpark(frame, m, x, y, size, alpha)
    Put(frame, m.body, x, y, size, nil, alpha)
    if m.core then Put(frame, m.core, x, y, size * CORE, nil, alpha) end
end

-- Motes come and go: each lives m.life seconds and is spawned again.
local function Age(motes, elapsed, Spawn, S)
    for _, m in ipairs(motes) do
        m.t = m.t + elapsed
        if m.t > m.life then
            local over = m.t - m.life
            Spawn(m, S)
            m.t = over
        end
    end
end

-- A style's motes, each with a body (and a core when `cored`).
local function Motes(frame, n, picture, cored, Spawn, S)
    local motes = {}
    for i = 1, n do
        local m = { body = Layer(frame, picture, 2), core = cored and Layer(frame, picture, 3, true) or nil }
        Spawn(m, S)
        m.t = -random() * m.life -- not all at once
        motes[i] = m
    end
    return motes
end

local function GlintSpawn(m, S)
    m.flash = 0.22 + 0.13 * random()
    m.life = m.flash + 0.4 + 1.0 * random()
    m.x, m.y = (random() - 0.5) * 0.6 * S, S * (-0.25 + 0.45 * random())
    m.s = S * (0.3 + 0.15 * random())
end

local function PollenSpawn(m, S)
    m.life = 2.6 + 1.6 * random()
    m.phase = random() * 2 * pi
    m.x, m.y = (random() - 0.5) * 0.8 * S, -S * (0.1 + 0.3 * random())
    m.s = S * (0.05 + 0.06 * random())
    m.sway = S * (0.04 + 0.06 * random())
end

local function BubbleSpawn(m, S)
    m.life = 1.6 + 1.2 * random()
    m.phase = random() * 2 * pi
    m.x, m.y = (random() - 0.5) * 0.35 * S, -0.22 * S
    m.rise = S * (0.55 + 0.35 * random())
    m.s = S * (0.1 + 0.1 * random())
    m.spin = random() * 2 * pi -- where the pop's droplets fly
end

local function BeamSpawn(m, S)
    m.life = 1.4 + 1.2 * random()
    m.x = (random() - 0.5) * 0.12 * S
    m.s = S * (0.12 + 0.12 * random())
end

-- Going round the node: a ring seen from a little above (x across, y up, depth 1
-- in front, -1 behind). The game draws the node under every addon texture, so a
-- part going behind it fades out while it crosses the node's middle.
local function Ring(angle, rx, ry)
    return cos(angle) * rx, -sin(angle) * ry, sin(angle)
end

local function Seen(x, depth, S)
    if depth >= 0 then return 1 end
    local over = 1 - min(1, abs(x) / (0.3 * S))
    return (0.5 + 0.5 * (1 + depth)) * (1 - over * min(1, -depth * 3))
end

-- A wisp: a glowing head going round, dropping a trail of fading sparkles.
local function NewWisp(frame)
    local trail = {}
    for i = 1, 28 do trail[i] = { body = Layer(frame, PICTURE, 2), age = 1 } end
    return { trail = trail, next = 1, drop = 0, glow = Layer(frame, GLOW, 2),
        head = { body = Layer(frame, PICTURE, 4), core = Layer(frame, PICTURE, 5, true) } }
end

local function PutWisp(frame, p, S, elapsed, x, y, depth)
    local seen, near = Seen(x, depth, S), 0.8 + 0.2 * depth
    p.drop = p.drop - elapsed
    if p.drop <= 0 then
        p.drop = 0.035
        local m = p.trail[p.next]
        m.x, m.y, m.age, m.seen, m.near = x, y, 0, seen, near
        p.next = p.next % #p.trail + 1
    end
    for _, m in ipairs(p.trail) do
        m.age = m.age + elapsed
        local k = max(0, 1 - m.age / 1)
        PutSpark(frame, m, m.x or 0, (m.y or 0) + m.age * 0.05 * S, 0.16 * S * k * (m.near or 1), k * (m.seen or 0))
    end
    Put(frame, p.glow, x, y, 0.6 * S * near, nil, 0.5 * seen)
    PutSpark(frame, p.head, x, y, 0.4 * S * near, seen)
end

-- A firefly drifts round its own spot, slowly glowing and going dark.
local function NewFirefly(frame, S)
    return { body = Layer(frame, FIREFLY, 3), x = (random() - 0.5) * 0.7 * S, y = S * (-0.15 + 0.5 * random()),
        rx = S * (0.12 + 0.15 * random()), ry = S * (0.06 + 0.1 * random()), f1 = 0.3 + 0.4 * random(), f2 = 0.4 + 0.5 * random(),
        ph = 2 * pi * random(), blink = 0.5 + 0.6 * random(), bph = 2 * pi * random(), s = S * (0.22 + 0.08 * random()) }
end

-- Butterflies: each flies to a new spot every second or so, wings beating (the picture
-- narrowed and widened), then lands on the node for a moment, wings slowly opening.
local function Fly(frame, b, S, elapsed)
    b.fade = min(1, b.fade + elapsed / 0.6)
    b.left = b.left - elapsed
    if b.mode == "fly" then
        b.retarget = b.retarget - elapsed
        if b.retarget <= 0 then b.retarget, b.tx, b.ty = 0.7 + 0.9 * random(), (random() - 0.5) * S * 1.1, S * (0.05 + 0.45 * random()) end
        if b.left <= 0 then b.mode, b.tx, b.ty = "land", (random() - 0.5) * S * 0.3, S * (0.12 + 0.1 * random()) end
        b.flap = b.flap + elapsed * 16
    elseif b.mode == "land" then
        b.flap = b.flap + elapsed * 12
        if (b.tx - b.x) ^ 2 + (b.ty - b.y) ^ 2 < (S * 0.02) ^ 2 then b.mode, b.left, b.vx, b.vy = "rest", 1.4 + 1.8 * random(), 0, 0 end
    else
        b.flap = b.flap + elapsed * 1.6
        if b.left <= 0 then b.mode, b.left, b.retarget = "fly", 3 + 3 * random(), 0 end
    end
    if b.mode ~= "rest" then
        local pull = b.mode == "land" and 7 or 3.2
        b.vx = b.vx + ((b.tx - b.x) * pull - b.vx * 2.2) * elapsed
        b.vy = b.vy + ((b.ty - b.y) * pull - b.vy * 2.2) * elapsed
        b.x = b.x + (b.vx + sin(b.flap * 0.23) * S * 0.12) * elapsed
        b.y = b.y + (b.vy - cos(b.flap * 0.31) * S * 0.16) * elapsed
    end
    local open = b.mode == "rest" and 0.55 + 0.45 * abs(cos(b.flap)) or 0.18 + 0.82 * abs(cos(b.flap))
    Put(frame, b.glow, b.x, b.y, b.s * 1.6, nil, 0.12 * b.fade) -- faint, so they show in the dark
    Put(frame, b.body, b.x, b.y, b.s * open, b.s * 0.92, b.fade)
end

-- Coins: the vault coin turns over with its own frames, three a radian of spin.
local function PutCoin(frame, coin, size, alpha)
    local step = floor(coin.spin * 3) % 16
    if step ~= coin.step then
        coin.step = step
        local col, row = step % 8, floor(step / 8)
        coin.body:SetTexCoord(col / 8, (col + 1) / 8, row / 2, (row + 1) / 2)
    end
    Put(frame, coin.body, coin.x, coin.y, size, nil, alpha)
end

-- A faint glint over a coin, once coin.glint is set to 0.
local function CoinGlint(frame, coin, size, elapsed)
    if coin.glint and coin.glint < 1 then
        coin.glint = min(1, coin.glint + elapsed / 0.35)
        Put(frame, coin.star, coin.x, coin.y, size * 1.5, nil, 0.35 * Bell(coin.glint))
    else
        coin.star:Hide()
    end
end

local function NewCoins(frame, n)
    local coins = {}
    for i = 1, n do coins[i] = { body = Layer(frame, VAULT_COIN, 4, false, "painted"), star = Layer(frame, STAR4, 5, true) } end
    return coins
end

local function DustSpawn(m, S)
    m.life = 3 + 2 * random()
    m.x, m.y, m.fall = (random() - 0.5) * 0.95 * S, S * (0.3 + 0.2 * random()), S * (0.3 + 0.2 * random())
    m.ph, m.s, m.tw = random() * 2 * pi, S * (0.06 + 0.05 * random()), 2 + 3 * random()
end

-- A fly: buzzes round its own spot in quick jerky loops, its wings flapping (the
-- picture with wings and the one without, swapped), and lands on the corpse now and then.
-- Fly i of n has its own part of the corpse, so they don't bunch up.
local function NewFly(frame, S, i, n)
    local across = (i - 0.5) / n - 0.5
    local f = { wings = Layer(frame, FLY, 4, false, "painted"), body = Layer(frame, FLY, 4, false, "painted"),
        cx = (across * 0.9 + (random() - 0.5) * 0.08) * S, cy = S * (0.06 + (i % 2) * 0.16 + 0.06 * random()),
        rx = S * (0.04 + 0.05 * random()), ry = S * (0.03 + 0.04 * random()), f1 = 2.2 + 2.5 * random(),
        f2 = 2.6 + 3 * random(), ph = 2 * pi * random(), s = S * (0.15 + 0.05 * random()),
        lx = across * 0.55 * S, ly = S * (0.02 + 0.06 * random()), cycle = 4.6 * random() }
    f.wings:SetTexCoord(0, 0.5, 0, 1)
    f.body:SetTexCoord(0.5, 1, 0, 1)
    return f
end

local function PutFly(frame, f, S, c)
    local x = f.cx + sin(c * f.f1 + f.ph) * f.rx + sin(c * 13 + f.ph) * S * 0.006
    local y = f.cy + sin(c * f.f2 + f.ph * 1.7) * f.ry + cos(c * 11 + f.ph) * S * 0.006
    -- 2.2 s flying, then down to its spot, 1.6 s sitting with its wings folded, and up
    local u, down = (c + f.cycle) % 4.6 - 2.2, 0
    if u > 0 then down = u < 0.4 and EaseOut(u / 0.4) or u < 2 and 1 or 1 - EaseOut((u - 2) / 0.4) end
    x, y = x + (f.lx - x) * down, y + (f.ly - y) * down
    local sitting = down > 0.98
    local up = not sitting and floor(c * 30) % 2 == 0
    Put(frame, f.wings, x, y, f.s, nil, up and 1 or 0)
    Put(frame, f.body, x, y, sitting and f.s * 0.9 or f.s, nil, up and 0 or 1)
end

-- The Sparkle Maker's own styles' helpers, in one table (the main chunk is near Lua's 200 locals).
local More = {
    LEAVES = { "housing-celebrationtoast-leaf-bottom01", "housing-celebrationtoast-leaf-bottom02",
        "housing-celebrationtoast-leaf-bottom03", "housing-celebrationtoast-leaf-bottom04" },
}

function More.EmberSpawn(m, S)
    m.life = 1.6 + 1.2 * random()
    m.x, m.y = (random() - 0.5) * 0.6 * S, -S * (0.15 + 0.15 * random())
    m.rise, m.drift = S * (0.6 + 0.4 * random()), (random() - 0.5) * 0.3 * S
    m.s, m.ph, m.flicker = S * (0.05 + 0.04 * random()), random() * 2 * pi, 9 + 6 * random()
end

function More.SnowSpawn(m, S)
    m.life = 4 + 3 * random()
    m.x, m.y, m.fall = (random() - 0.5) * S, S * (0.7 + 0.25 * random()), S * (0.9 + 0.2 * random())
    m.sway, m.ph, m.f = S * (0.03 + 0.05 * random()), random() * 2 * pi, 0.8 + 0.6 * random()
    m.s = S * (0.05 + 0.06 * random())
end

function More.LeafSpawn(m, S)
    m.life = 4 + 2 * random()
    m.x, m.y, m.fall = (random() - 0.5) * 0.9 * S, S * (0.6 + 0.3 * random()), S * (0.9 + 0.2 * random())
    m.sway, m.ph, m.f, m.flip = S * (0.12 + 0.08 * random()), random() * 2 * pi, 0.6 + 0.5 * random(), 2 + 2 * random()
    m.s = S * (0.12 + 0.05 * random())
end

-- In for its first share of its life, out over its last.
function More.InOut(u, first, last)
    if u <= 0 then return 0 end
    if u < first then return u / first end
    if u > 1 - last then return max(0, (1 - u) / last) end
    return 1
end

-- Each style: its name, how it is built (Build: its parts for count n), and
-- Draw (moves them; c is the frame's clock, A its alpha). Twinkle is the
-- animations above. start: the look a style comes with when it is picked;
-- only: the one kind it is made for (the rest fit every kind); group: its section
-- on the Sparkle Maker's page; maker: only there (the kinds' pages have no room
-- for more tiles).
local STYLES = {
    { name = "Twinkle", group = "Sparkles", twinkle = true, start = { size = 100, height = -60, count = 9, color = "ffffffff" },
        tip = "Sparkles grow, drift up and fade." },
    { name = "Glints", group = "Sparkles", start = { size = 100, height = -60, count = 6, color = "ffffffff", color2 = "ff9fd8ff" }, tip = "Quick sharp flashes like light on a vein. Shows half the count.",
        Build = function(frame, n, S) return { motes = Motes(frame, max(2, floor(n / 2 + 0.5)), STAR4, true, GlintSpawn, S) } end,
        Draw = function(frame, p, S, elapsed)
            Age(p.motes, elapsed, GlintSpawn, S)
            for _, m in ipairs(p.motes) do
                local k = 0
                if m.t > 0 and m.t < m.flash then
                    local u = m.t / m.flash
                    k = u < 0.25 and EaseOut(u / 0.25) or 1 - EaseIn((u - 0.25) / 0.75)
                end
                PutSpark(frame, m, m.x, m.y, m.s * (0.3 + 0.7 * k), k)
            end
        end },
    { name = "Pollen", group = "Drifting", start = { size = 100, height = -60, count = 9, color = "ffffffff" }, tip = "Soft specks float up and sway. Shows twice the count.",
        Build = function(frame, n, S) return { motes = Motes(frame, n * 2, GLOW, false, PollenSpawn, S) } end,
        Draw = function(frame, p, S, elapsed)
            Age(p.motes, elapsed, PollenSpawn, S)
            for _, m in ipairs(p.motes) do
                local k, u = 0, m.t / m.life
                if m.t > 0 then k = u < 0.25 and u / 0.25 or u > 0.7 and 1 - (u - 0.7) / 0.3 or 1 end
                PutSpark(frame, m, m.x + sin(u * 2 * pi * 1.3 + m.phase) * m.sway, m.y + u * 0.65 * S, m.s, k * 0.85)
            end
        end },
    { name = "Star crown", group = "Sparkles", start = { size = 110, height = -60, count = 7, color = "ffffd100", color2 = "ffffffff" }, tip = "A ring of stars turns over the node. Count is how many stars.",
        Build = function(frame, n)
            local stars = {}
            for i = 1, min(12, max(5, n)) do stars[i] = { body = Layer(frame, SOFT_STAR, 2), core = Layer(frame, STAR4, 3, true) } end
            return { stars = stars }
        end,
        Draw = function(frame, p, S, _, c)
            local n = #p.stars
            local head = (c * 4) % n
            for i, m in ipairs(p.stars) do
                local x, y, depth = Ring((i - 1) / n * 2 * pi + c * 0.5, 0.5 * S, 0.14 * S)
                local lit = max(0, 1 - ((head - (i - 1)) % n) / 3)
                local near = 0.8 + 0.2 * depth
                PutSpark(frame, m, x, 0.38 * S + y, S * (0.45 + 0.2 * lit) * near, (0.4 + 0.6 * lit) * near * Seen(x, depth, S))
            end
        end },
    { name = "Wisp", group = "Circling", start = { size = 110, height = -60, count = 9, color = "ff8fd8ff", color2 = "ffffffff" }, tip = "A wisp circles the node and leaves a trail. Doesn't use Count.",
        Build = NewWisp,
        Draw = function(frame, p, S, elapsed, c)
            local x, y, depth = Ring(c * 2 * pi / 3.2, 0.55 * S, 0.16 * S)
            PutWisp(frame, p, S, elapsed, x, y + sin(c * 2.3) * 0.08 * S, depth)
        end },
    { name = "Bubbles", only = "bobber", start = { size = 100, height = -60, count = 9, color = "ffffffff" }, tip = "Bubbles rise up and pop.",
        Build = function(frame, n, S)
            local bubbles = {}
            for i = 1, n do
                local m = { body = Layer(frame, BUBBLE, 2), drops = {} }
                for d = 1, 3 do m.drops[d] = Layer(frame, BUBBLE, 3) end
                BubbleSpawn(m, S)
                m.t = -random() * m.life
                bubbles[i] = m
            end
            return { motes = bubbles }
        end,
        Draw = function(frame, p, S, elapsed)
            Age(p.motes, elapsed, BubbleSpawn, S)
            for _, m in ipairs(p.motes) do
                local u = m.t / m.life
                local x, y = m.x + sin(m.t * 6 + m.phase) * 0.03 * S, m.y + u * m.rise
                if m.t <= 0 or u < 0.9 then
                    Put(frame, m.body, x, y, m.s * (0.8 + 0.3 * u), nil, m.t > 0 and min(1, u * 5) * 0.8 or 0)
                    for _, d in ipairs(m.drops) do d:Hide() end
                else
                    -- The pop: the skin swells and fades, droplets fly off.
                    local v = (u - 0.9) / 0.1
                    Put(frame, m.body, x, y, m.s * (1.1 + 0.5 * v), nil, 0.8 * (1 - v))
                    for i, d in ipairs(m.drops) do
                        local angle, reach = m.spin + i * 2 * pi / #m.drops, m.s * (0.3 + 0.9 * EaseOut(v))
                        Put(frame, d, x + cos(angle) * reach, y + sin(angle) * reach, m.s * 0.22 * (1 - 0.5 * v), nil, 1 - v)
                    end
                end
            end
        end },
    { name = "Light beam", group = "Light", start = { size = 100, height = -60, count = 9, color = "ffffd100", color2 = "ffffffff" }, tip = "A beam of light goes up from the node. Easy to spot from far away. Doesn't use Count.",
        Build = function(frame, _, S)
            return { outer = Layer(frame, "half", 2), inner = Layer(frame, "half", 3, true),
                pool = Layer(frame, GLOW, 2), poolCore = Layer(frame, GLOW, 3, true), ring = Layer(frame, RING, 2),
                motes = Motes(frame, 8, PICTURE, false, BeamSpawn, S) }
        end,
        Draw = function(frame, p, S, elapsed, c)
            Age(p.motes, elapsed, BeamSpawn, S)
            local base, tall = -0.3 * S, 3 * S
            local breath = 0.85 + 0.15 * sin(c * 2.2)
            Put(frame, p.outer, 0, base + tall / 2, 0.5 * S, tall, 0.4 * breath)
            Put(frame, p.inner, 0, base + tall / 2, 0.13 * S, tall, 0.8 * breath)
            Put(frame, p.pool, 0, base, 1.1 * S, 0.3 * S, 0.4)
            Put(frame, p.poolCore, 0, base, 0.45 * S, 0.13 * S, 0.5)
            local u = (c % 2.2) / 1.2 -- a ring spreads over the ground every 2.2 s
            if u < 1 then
                Put(frame, p.ring, 0, base, S * (0.3 + 1.3 * EaseOut(u)), S * (0.09 + 0.38 * EaseOut(u)), (1 - u) * 0.6)
            else
                p.ring:Hide()
            end
            for _, m in ipairs(p.motes) do
                local v = m.t / m.life
                PutSpark(frame, m, m.x, base + (0.3 + v * 0.6) * tall, m.s, m.t > 0 and Bell(v) * 0.8 or 0)
            end
        end },
    { name = "Butterflies", only = "herbs", start = { size = 110, height = -60, count = 3, color = "ffffffff" }, tip = "Butterflies fly around the herb and land on it. Count is how many, 2 to 5.",
        Build = function(frame, n, S)
            local flies = {}
            for i = 1, min(5, max(2, n)) do
                flies[i] = { glow = Layer(frame, GLOW, 2), body = Layer(frame, BUTTERFLY, 4, false, "painted"),
                    x = (random() - 0.5) * S, y = S * (0.2 + 0.3 * random()), vx = 0, vy = 0, tx = 0, ty = S * 0.3,
                    mode = "fly", left = 2 + (i - 1) * 1.3 + 2 * random(), retarget = 0, flap = random() * 2 * pi,
                    s = S * (0.17 + 0.05 * random()), fade = 0 }
            end
            return { flies = flies }
        end,
        Draw = function(frame, p, S, elapsed)
            for _, b in ipairs(p.flies) do Fly(frame, b, S, elapsed) end
        end },
    { name = "Pickaxe sparks", only = "ore", start = { size = 100, height = -60, count = 7, color = "ffffe6a6" }, tip = "Sparks fly out like a pickaxe just hit it. Count is how many sparks.",
        Build = function(frame, n, S)
            local p = { sparks = {}, n = min(12, max(3, n)), next = 0.2, flash = Layer(frame, BURST, 6), flashAt = 99 }
            for i = 1, p.n * 3 do
                local m = { body = Layer(frame, PICTURE, 2), core = Layer(frame, PICTURE, 3, true), trail = {}, was = {} }
                for j = 1, 4 do m.trail[j], m.was[j] = Layer(frame, PICTURE, 2), { 0, 0 } end
                p.sparks[i] = m
            end
            return p
        end,
        Draw = function(frame, p, S, elapsed)
            p.next, p.flashAt = p.next - elapsed, p.flashAt + elapsed
            if p.next <= 0 then
                p.next = 0.8 + 1.4 * random()
                local x, y = (random() - 0.5) * S * 0.55, -S * (0.02 + (random() - 0.5) * 0.18)
                p.fx, p.fy, p.flashAt = x, y, 0
                local left = p.n
                for _, m in ipairs(p.sparks) do
                    if left == 0 then break end
                    if not m.on then
                        local angle, speed = pi / 2 + (random() - 0.5) * 2.4, (0.85 + 0.75 * random()) * S
                        m.on, m.t, m.x, m.y, m.vx, m.vy = true, 0, x, y, cos(angle) * speed, sin(angle) * speed
                        m.life, m.s = 0.35 + 0.3 * random(), S * (0.07 + 0.04 * random())
                        for j = 1, 4 do m.was[j][1], m.was[j][2] = x, y end
                        left = left - 1
                    end
                end
            end
            local u = p.flashAt / 0.22
            Put(frame, p.flash, p.fx or 0, p.fy or 0, S * (0.18 + 0.35 * u), nil, u < 1 and 1 - u or 0)
            for _, m in ipairs(p.sparks) do
                if m.on then
                    m.t = m.t + elapsed
                    table.insert(m.was, 1, table.remove(m.was)) -- where it was, newest first
                    m.was[1][1], m.was[1][2] = m.x, m.y
                    m.x, m.y, m.vy = m.x + m.vx * elapsed, m.y + m.vy * elapsed, m.vy - 2.4 * S * elapsed
                    local v = m.t / m.life
                    if v >= 1 then
                        m.on = false
                        m.body:Hide()
                        m.core:Hide()
                        for j = 1, 4 do m.trail[j]:Hide() end
                    else
                        local k = (1 - v) * (0.8 + 0.2 * sin(m.t * 60))
                        PutSpark(frame, m, m.x, m.y, m.s, k)
                        for j = 1, 4 do
                            Put(frame, m.trail[j], m.was[j][1], m.was[j][2], m.s * (0.85 - 0.15 * j), nil, k * (0.7 - 0.15 * j))
                        end
                    end
                end
            end
        end },
    { name = "Settling dust", group = "Drifting", start = { size = 110, height = -60, count = 8, color = "ffffe9bf" }, tip = "Dust floats down and settles on the node. Shows three times the count.",
        Build = function(frame, n, S) return { motes = Motes(frame, n * 3, PICTURE, true, DustSpawn, S) } end,
        Draw = function(frame, p, S, elapsed)
            Age(p.motes, elapsed, DustSpawn, S)
            for _, m in ipairs(p.motes) do
                local u = m.t / m.life
                local k = m.t > 0 and Bell(u) * (0.5 + 0.5 * max(0, sin(m.t * m.tw + m.ph)) ^ 2) or 0
                PutSpark(frame, m, m.x + sin(m.t * 1.1 + m.ph) * S * 0.03, m.y - u * m.fall, m.s, k)
            end
        end },
    { name = "Spilling coins", only = "chests", start = { size = 100, height = -60, count = 9, color = "ffffffff" }, tip = "Gold coins fall off the chest and bounce. Higher count, more coins.",
        Build = function(frame, n) return { coins = NewCoins(frame, 3 + floor(n / 3)), n = n, next = 0.2 } end,
        Draw = function(frame, p, S, elapsed)
            p.next = p.next - elapsed
            if p.next <= 0 then
                p.next = (8.5 / p.n) * (0.75 + 0.5 * random()) -- at 9, a coin every 0.7-1.2 s
                for _, coin in ipairs(p.coins) do
                    if not coin.on then
                        local side = random() < 0.5 and -1 or 1
                        coin.on, coin.t, coin.out, coin.glint, coin.bounced = true, 0, 0, nil, false
                        coin.x, coin.y, coin.ground = side * S * (0.12 + 0.06 * random()), S * 0.05, -S * (0.38 + 0.03 * random())
                        coin.vx, coin.vy = side * S * (0.28 + 0.12 * random()), S * (0.25 + 0.15 * random())
                        coin.spin, coin.rate = 2 * pi * random(), side * (4 + 2 * random())
                        break
                    end
                end
            end
            local size = S * 0.114
            for _, coin in ipairs(p.coins) do
                if coin.on then
                    coin.t, coin.spin = coin.t + elapsed, coin.spin + coin.rate * elapsed
                    coin.x, coin.y, coin.vy = coin.x + coin.vx * elapsed, coin.y + coin.vy * elapsed, coin.vy - 2.4 * S * elapsed
                    if coin.vy < 0 and coin.y <= coin.ground then
                        coin.y = coin.ground
                        if not coin.bounced then coin.bounced, coin.vy, coin.vx, coin.glint = true, -coin.vy * 0.25, coin.vx * 0.5, 0 end
                    end
                    if coin.bounced then coin.out = coin.out + elapsed / 0.35 end
                    if coin.out >= 1 then
                        coin.on = false
                        coin.body:Hide()
                        coin.star:Hide()
                    else
                        PutCoin(frame, coin, size, min(1, coin.t / 0.1) * (1 - coin.out))
                        CoinGlint(frame, coin, size, elapsed)
                    end
                end
            end
        end },
    { name = "Quest mark", only = "quests", start = { size = 200, height = -60, count = 9, color = "ffffffff" }, tip = "A yellow \"!\" floats over it. Doesn't use Count.",
        Build = function(frame) return { mark = Layer(frame, QUEST_MARK, 4, false, "painted"), glow = Layer(frame, FIREFLY, 3) } end,
        Draw = function(frame, p, S, _, c)
            local y = S * 0.4 + sin(c * 2) * S * 0.03
            Put(frame, p.glow, 0, y, S * 0.55, nil, 0.35 * (0.85 + 0.15 * sin(c * 2)))
            Put(frame, p.mark, 0, y, S * 0.2, nil, 1)
        end },
    { name = "Glowing mark", only = "quests", start = { size = 200, height = -60, count = 9, color = "ffffffff" }, tip = "A glowing \"!\" over it that slowly pulses. Doesn't use Count.",
        Build = function(frame) return { mark = Layer(frame, PING_MARK, 4) } end,
        Draw = function(frame, p, S, _, c)
            Put(frame, p.mark, 0, S * 0.4 + sin(c * 1.6) * S * 0.025, S * 0.42, nil, 0.55 + 0.4 * sin(c * 2.2) ^ 2)
        end },
    { name = "Fireflies", group = "Circling", start = { size = 100, height = -60, count = 9, color = "ffffffff" }, tip = "Fireflies float around and blink on and off. Count is how many, 2 to 8.",
        Build = function(frame, n, S)
            local flies = {}
            for i = 1, min(8, max(2, floor(n * 0.6 + 0.5))) do flies[i] = NewFirefly(frame, S) end
            return { flies = flies }
        end,
        Draw = function(frame, p, _, _, c)
            for _, f in ipairs(p.flies) do
                local glow = max(0, sin(c * f.blink + f.bph)) ^ 1.5
                Put(frame, f.body, f.x + sin(c * f.f1 + f.ph) * f.rx, f.y + sin(c * f.f2 + f.ph * 1.7) * f.ry, f.s, nil, 0.15 + 0.85 * glow)
            end
        end },
    { name = "Landing flies", only = "skinning", start = { size = 100, height = -60, count = 9, color = "ffffffff" }, tip = "Flies buzz around the corpse and land on it now and then. Count is how many, 2 to 6.",
        Build = function(frame, n, S)
            local flies = {}
            local count = min(6, max(2, floor(n / 2 + 0.5)))
            for i = 1, count do flies[i] = NewFly(frame, S, i, count) end
            return { flies = flies }
        end,
        Draw = function(frame, p, S, _, c)
            for _, f in ipairs(p.flies) do PutFly(frame, f, S, c) end
        end },
    { name = "Shooting stars", group = "Sparkles", maker = true, start = { size = 110, height = -60, count = 9, color = "ffffffff", color2 = "ffffe08a" },
        tip = "Stars streak over the node now and then. Higher count, more often.",
        Build = function(frame, n)
            local stars = {}
            for i = 1, 3 do
                local star = { head = Layer(frame, STAR4, 3, true), glow = Layer(frame, GLOW, 2), trail = {} }
                for j = 1, 6 do star.trail[j] = Layer(frame, PICTURE, 2) end
                stars[i] = star
            end
            return { stars = stars, gap = 1 + 8 / max(1, n), next = 0.3 }
        end,
        Draw = function(frame, p, S, elapsed)
            p.next = p.next - elapsed
            if p.next <= 0 then
                p.next = p.gap * (0.6 + 0.8 * random())
                for _, star in ipairs(p.stars) do
                    if not star.on then
                        local side = random() < 0.5 and -1 or 1
                        star.on, star.t, star.life = true, 0, 0.7 + 0.3 * random()
                        star.x, star.y = -side * S * (0.6 + 0.2 * random()), S * (0.5 + 0.3 * random())
                        star.vx, star.vy = side * S * (1.4 + 0.6 * random()), -S * (0.5 + 0.3 * random())
                        break
                    end
                end
            end
            for _, star in ipairs(p.stars) do
                if star.on then
                    star.t = star.t + elapsed
                    local u = star.t / star.life
                    if u >= 1 then
                        star.on = false
                        star.head:Hide()
                        star.glow:Hide()
                        for _, dot in ipairs(star.trail) do dot:Hide() end
                    else
                        local k = More.InOut(u, 0.2, 0.8)
                        local x, y = star.x + star.vx * star.t, star.y + star.vy * star.t
                        Put(frame, star.head, x, y, S * 0.22 * (0.8 + 0.2 * k), nil, k)
                        Put(frame, star.glow, x, y, S * 0.3, nil, 0.4 * k)
                        for j, dot in ipairs(star.trail) do -- where it was, a little earlier each
                            local t = max(0, star.t - j * 0.035)
                            Put(frame, dot, star.x + star.vx * t, star.y + star.vy * t, S * 0.08 * (1 - j / 7), nil, k * (0.7 - 0.1 * j))
                        end
                    end
                end
            end
        end },
    { name = "Embers", group = "Drifting", maker = true, start = { size = 100, height = -60, count = 9, color = "ffff8a3d", color2 = "ffffd100" },
        tip = "Warm sparks rise from the node and flicker out. Shows twice the count.",
        Build = function(frame, n, S) return { motes = Motes(frame, n * 2, PICTURE, true, More.EmberSpawn, S) } end,
        Draw = function(frame, p, S, elapsed)
            Age(p.motes, elapsed, More.EmberSpawn, S)
            for _, m in ipairs(p.motes) do
                local u = m.t / m.life
                local k = More.InOut(u, 0.15, 0.85) * (0.7 + 0.3 * sin(m.t * m.flicker + m.ph))
                PutSpark(frame, m, m.x + m.drift * u + sin(m.t * 3 + m.ph) * 0.03 * S, m.y + m.rise * EaseOut(u), m.s * (1 - 0.5 * u), k)
            end
        end },
    { name = "Snow", group = "Drifting", maker = true, start = { size = 110, height = -60, count = 9, color = "ffeaf6ff", color2 = "ffffffff" },
        tip = "Snowflakes drift down past the node. Shows twice the count.",
        Build = function(frame, n, S) return { motes = Motes(frame, n * 2, GLOW, false, More.SnowSpawn, S) } end,
        Draw = function(frame, p, S, elapsed)
            Age(p.motes, elapsed, More.SnowSpawn, S)
            for _, m in ipairs(p.motes) do
                local u = m.t / m.life
                PutSpark(frame, m, m.x + sin(m.t * m.f + m.ph) * m.sway, m.y - u * m.fall, m.s, 0.9 * More.InOut(u, 0.15, 0.2))
            end
        end },
    { name = "Falling leaves", group = "Drifting", maker = true, start = { size = 110, height = -60, count = 5, color = "ffffffff", color2 = "ffffd9a6" },
        tip = "Leaves drift down and turn as they fall. Count is how many, 2 to 8.",
        Build = function(frame, n, S)
            local leaves = {}
            for i = 1, min(8, max(2, n)) do
                local leaf = More.LEAVES[(i - 1) % #More.LEAVES + 1]
                local info = C_Texture.GetAtlasInfo(leaf)
                local m = { body = Layer(frame, leaf, 4, false, "painted"), wide = info and info.width / info.height or 1 }
                More.LeafSpawn(m, S)
                m.t = -random() * m.life
                leaves[i] = m
            end
            return { motes = leaves }
        end,
        Draw = function(frame, p, S, elapsed)
            Age(p.motes, elapsed, More.LeafSpawn, S)
            for _, m in ipairs(p.motes) do
                local u = m.t / m.life
                local turn = 0.35 + 0.65 * abs(cos(m.t * m.flip + m.ph)) -- seen edge on as it turns
                Put(frame, m.body, m.x + sin(m.t * m.f + m.ph) * m.sway, m.y - u * m.fall, m.s * m.wide * turn, m.s, More.InOut(u, 0.15, 0.2))
            end
        end },
    { name = "Ripple", group = "Light", maker = true, start = { size = 100, height = -60, count = 9, color = "ffffd100", color2 = "ffffffff" },
        tip = "Rings spread over the ground from the node, like a ping on the map. Doesn't use Count.",
        Build = function(frame)
            local rings = {}
            for i = 1, 3 do rings[i] = { body = Layer(frame, RING, 2) } end
            return { pool = Layer(frame, GLOW, 2), rings = rings }
        end,
        Draw = function(frame, p, S, _, c)
            local base = -0.3 * S
            Put(frame, p.pool, 0, base, S * 0.8, S * 0.25, 0.3 + 0.1 * sin(c * 2))
            for i, ring in ipairs(p.rings) do
                local u = ((c + (i - 1) * 0.9) % 2.7) / 2.7 -- one every 0.9 s
                local wide = EaseOut(u)
                Put(frame, ring.body, 0, base, S * (0.25 + 1.2 * wide), S * (0.08 + 0.35 * wide), (1 - u) * 0.6 * min(1, u * 8))
            end
        end },
    { name = "Halo", group = "Light", maker = true, start = { size = 110, height = -60, count = 9, color = "ffffd100", color2 = "ffffffff" },
        tip = "A soft glow round the node that slowly breathes. Doesn't use Count.",
        Build = function(frame)
            return { glows = { { body = Layer(frame, GLOW, 2) }, { body = Layer(frame, GLOW, 3, true) } } }
        end,
        Draw = function(frame, p, S, _, c)
            local b = 0.5 + 0.5 * sin(c * 1.4)
            Put(frame, p.glows[1].body, 0, -0.1 * S, S * (1.2 + 0.1 * b), nil, 0.3 + 0.25 * b)
            Put(frame, p.glows[2].body, 0, -0.1 * S, S * (0.55 + 0.05 * b), nil, 0.25 + 0.2 * b)
        end },
}

-- Can kind have style i?
local function StyleFits(i, kind)
    local style = STYLES[i]
    return style ~= nil and not style.maker and (not style.only or style.only == kind)
end

-- Kinds whose every style starts at one height: the bobber floats on the water, and a
-- corpse lies well under its plate (it stays where the living creature's head was).
More.START_HEIGHT = { bobber = 0, skinning = -115, loot = -115 }

-- Style i's look for a kind: as it was left (the settings' styleLooks), or the one it comes with.
function More.StyleLook(kind, i)
    local look = ns.db.styleLooks[kind] and ns.db.styleLooks[kind][i]
    if type(look) == "table" and type(look.size) == "number" and type(look.height) == "number" and type(look.count) == "number"
        and tostring(look.color):match("^%x%x%x%x%x%x%x%x$") and (look.color2 == nil or tostring(look.color2):match("^%x%x%x%x%x%x%x%x$")) then
        return look
    end
    local start = STYLES[i].start
    return { size = start.size, height = More.START_HEIGHT[kind] or start.height, count = start.count, color = start.color, color2 = start.color2 }
end

local function Shade(texture, r, g, b)
    if texture.water then return r * 0.85, g * 0.92, b end
    if texture.light then return Lighter(r, g, b) end
    return r, g, b
end

-- Tints every texture of a style's parts (one, two: the colors as text). Motes
-- and stars take turns; a light beam's column goes from the first color at its
-- base to the second at its top.
local function TintAll(list, one, two)
    for key, v in pairs(list) do
        if type(v) == "table" then
            if v.column then
                local r, g, b = Shade(v, RGB(one))
                local r2, g2, b2 = Shade(v, RGB(two))
                v:SetGradient("VERTICAL", CreateColor(r, g, b, BEAM_FOOT), CreateColor(r2, g2, b2, 1))
            elseif v.layerKey then
                v:SetVertexColor(Shade(v, RGB(one)))
            elseif type(key) == "number" then
                local color = key % 2 == 0 and two or one
                TintAll(v, color, color)
            else
                TintAll(v, one, two)
            end
        end
    end
end

-- Hides every texture of a style's parts.
local function HideAll(list)
    for _, v in pairs(list) do
        if type(v) == "table" then
            if v.layerKey then v:Hide() else HideAll(v) end
        end
    end
end

-- Shows a style in a frame: other styles' parts hidden, this one's made again when
-- the count or size changed, then tinted.
local function ShowStyle(frame, style, count, S, color, color2)
    for name, parts in pairs(frame.parts) do
        if type(name) == "string" and name ~= style.name then HideAll(parts) end
    end
    if style.twinkle then return ShowTwinkles(frame, count, color, color2) end
    ShowTwinkles(frame, 0)
    local parts = frame.parts[style.name]
    if not parts or parts.count ~= count or parts.S ~= S then
        if parts then Free(frame, parts) end
        parts = style.Build(frame, count, S)
        parts.count, parts.S = count, S
        frame.parts[style.name] = parts
    end
    if parts.color ~= color .. color2 then
        parts.color = color .. color2
        TintAll(parts, color, color2)
    end
end

---------------------------------------------------------------------------
-- Made sparkles
---------------------------------------------------------------------------
-- The Sparkle Maker's sparkles, saved for every character in db.made: a list of
-- { id, name, effects = { look, look }, layers = { look, look, look } }. An effect is
-- one of Blizzard's 3D models (by file ID, or a creature's display ID) in a ModelScene
-- under the styles: it can be turned, tilted, sped up and made see-through, not
-- recolored (an actor can only be grayed). A style layer is one of the styles above
-- with its own look. Any layer can loop an animation, as WeakAuras' main animations
-- do. A kind uses a made sparkle in place of its style while its made key holds that id.

local Made = {} -- (in a block: the file's main chunk is near Lua's 200 locals)
do
local rad = math.rad

local EFFECTS = {
    { name = "Holy glow", file = 981525, group = "Glows" }, -- spells/holy_precast_low_base.m2
    { name = "Holy light", file = 166338, group = "Glows" }, -- spells/holy_precast_uber_base.m2
    { name = "Holy rays", file = 166334, group = "Glows" }, -- spells/holy_precast_high_base.m2
    { name = "Frost glow", file = 166383, group = "Glows" }, -- spells/ice_precast_uber_base.m2
    { name = "Shadow glow", file = 166810, group = "Glows" }, -- spells/shadow_precast_uber_base.m2
    { name = "Nature motes", file = 166604, group = "Glows" }, -- spells/nature_precast_chest.m2
    { name = "Sparkler", file = 426041, group = "Glows" }, -- spells/sparkler_white.m2
    { name = "Fireflies", file = 190731, group = "Nature" }, -- world/critter/fireflies/fireflies01.m2
    { name = "Arcane form", file = 165568, group = "Glows" }, -- arcane_form_precast
    { name = "Fire form", file = 166112, group = "Glows" }, -- fire_form_precast
    { name = "Frost form", file = 166209, group = "Glows" }, -- frost_form_precast
    { name = "Holy form", file = 166322, group = "Glows" }, -- holy_form_precast
    { name = "Nature form", file = 166603, group = "Glows" }, -- nature_form_precast
    { name = "Shadow form", file = 166792, group = "Glows" }, -- shadow_form_precast
    { name = "Frost glow, high", file = 166378, group = "Glows" }, -- ice_precast_high_base
    { name = "Frost glow 2", file = 344549, group = "Glows" }, -- ice_precast_uber_base_var2
    { name = "Shadow glow, high", file = 166805, group = "Glows" }, -- shadow_precast_high_base
    { name = "Shadow glow, medium", file = 166808, group = "Glows" }, -- shadow_precast_med_base
    { name = "Arcane ritual", file = 166734, group = "Glows" }, -- ritual_arcane_precast_base
    { name = "Fire ritual", file = 166735, group = "Glows" }, -- ritual_fire_precast_base
    { name = "Frost ritual", file = 166736, group = "Glows" }, -- ritual_frost_precast_base
    { name = "Summoning ritual", file = 166737, group = "Glows" }, -- ritualsummoning_precast_base
    { name = "Dark ritual", file = 165879, group = "Glows" }, -- darkritual_precast_base
    { name = "Dark ritual, blue", file = 252133, group = "Glows" }, -- darkritual_precast_baseblue
    { name = "Water glow", file = 469404, group = "Glows" }, -- water_precast
    { name = "Blessing of Freedom", file = 165693, group = "Auras" }, -- blessingoffreedom_state
    { name = "Green ghost", file = 166278, group = "Auras" }, -- greenghost_state
    { name = "Flare", file = 166196, group = "Auras" }, -- flare_state_base
    { name = "Cyan aura, short", file = 1310444, group = "Auras" }, -- auracyanshort
    { name = "Purple aura, tall", file = 612472, group = "Auras" }, -- aurapurpleverytall_v2
    { name = "Yellow aura, tall", file = 612474, group = "Auras" }, -- aurayellowverytall_v2
    { name = "Blackfathom wisp", file = 201436, group = "Nature" }, -- bfd_wisp01
    { name = "Blackfathom wisp, small", file = 201439, group = "Nature" }, -- bfd_wispsmall
    { name = "Blackfathom wisp, green", file = 201440, group = "Nature" }, -- bfd_wispsmallgreen
    { name = "Blackfathom wisp, purple", file = 201441, group = "Nature" }, -- bfd_wispsmallpurple
    { name = "Single firefly", file = 892364, group = "Nature" }, -- spells/single_firefly
    { name = "Motes of possibility", file = 5202080, group = "Nature" }, -- cfx_evoker_motesofpossibility
    { name = "Bubbles", file = 165411, group = "Nature" }, -- particles/bubbles
    { name = "Rising bubbles", file = 199932, group = "Nature" }, -- particleemitters/bubbles01
    { name = "Scourge spirits", file = 243608, group = "Nature" }, -- sc_spirits_01
    { name = "Lightwell", file = 917914, group = "Nature" }, -- spells/priest_lightwell_v2
    -- Creatures, by display ID (CreatureDisplayInfo): their model files draw nothing without their skin.
    { name = "Wisp", display = 1824, group = "Creatures" },
    { name = "Firefly, purple", display = 19252, group = "Creatures" },
}
local MAX, MAX_PARTS = 9, 6 -- (nine as tiles keep the window under the screen's 768 high; six layers, effects and styles in any mix, fill the maker's layer strip)
local LIMITS = { size = { 30, 300 }, height = { -150, 150 }, x = { -150, 150 }, count = { 1, 20 }, turn = { 0, 359 },
    tilt = { -90, 90 }, alpha = { 10, 100 }, particles = { 25, 300 }, speed = { 0, 300 }, animSpeed = { 25, 300 } }
local DEFAULT = { size = 100, height = -60, x = 0, count = 9, turn = 0, tilt = 0, alpha = 100, particles = 100, speed = 100,
    animSpeed = 100 }
local EFFECT_PARTS = { "size", "height", "x", "turn", "tilt", "alpha", "particles", "speed", "animSpeed" }
local STYLE_PARTS = { "size", "height", "x", "count", "alpha", "animSpeed" }
-- Looping animations: a loop takes LOOP seconds at speed 100. Spin turns an effect.
local ANIMS = { "None", "Pulse", "Breathe", "Bob", "Orbit", "Spin" }
local LOOP = 2
-- The effect's camera: as the sparkle window's node preview looks, from this far back.
local FX_PITCH, FX_FOV, FX_DISTANCE = 0.35, 0.6, 8

local function EffectOf(look)
    local file, display = tonumber(look.file), tonumber(look.display)
    for _, effect in ipairs(EFFECTS) do
        if file and effect.file == file or display and effect.display == display then return effect end
    end
end

local function StyleNamed(name)
    for i, style in ipairs(STYLES) do
        if style.name == name and not style.only then return i end
    end
end

local function Whole(value, what)
    value = tonumber(value)
    if not value or value ~= value then return DEFAULT[what] end -- (nil or NaN)
    local limits = LIMITS[what]
    return min(limits[2], max(limits[1], floor(value + 0.5)))
end

local function HexColor(color, default)
    return type(color) == "string" and color:match("^%x%x%x%x%x%x%x%x$") and color or default
end

-- An animation's name, or None (Spin only for an effect).
local function AnimOf(name, effect)
    for _, anim in ipairs(ANIMS) do
        if anim == name and (effect or anim ~= "Spin") then return anim end
    end
    return "None"
end

local function CleanEffect(look)
    local effect = type(look) == "table" and EffectOf(look)
    if not effect then return nil end
    local clean = { file = effect.file, display = effect.display, anim = AnimOf(look.anim, true) }
    for _, what in ipairs(EFFECT_PARTS) do clean[what] = Whole(look[what], what) end
    return clean
end

local function CleanLayer(look)
    local i = type(look) == "table" and StyleNamed(look.style)
    if not i then return nil end
    local color = HexColor(look.color, "ffffffff")
    local clean = { style = i, color = color, color2 = HexColor(look.color2, color), anim = AnimOf(look.anim, false) }
    for _, what in ipairs(STYLE_PARTS) do clean[what] = Whole(look[what], what) end
    return clean
end

-- A saved or pasted sparkle as it can be drawn: unknown effects and styles left out,
-- numbers inside their limits, bad colors white. Nil if nothing is left to draw.
local function CleanMade(sparkle)
    if type(sparkle) ~= "table" then return nil end
    local clean = { id = sparkle.id, effects = {}, layers = {} }
    clean.name = type(sparkle.name) == "string" and sparkle.name ~= "" and sparkle.name or "Sparkle"
    -- (Saves from the first version have one effect, not a list.)
    local effects = type(sparkle.effects) == "table" and sparkle.effects or { sparkle.effect }
    for i = 1, #effects do
        local look = CleanEffect(effects[i])
        if look and #clean.effects + #clean.layers < MAX_PARTS then clean.effects[#clean.effects + 1] = look end
    end
    for _, look in ipairs(type(sparkle.layers) == "table" and sparkle.layers or {}) do
        look = CleanLayer(look)
        if look and #clean.effects + #clean.layers < MAX_PARTS then clean.layers[#clean.layers + 1] = look end
    end
    if not clean.effects[1] and not clean.layers[1] then return nil end
    return clean
end

local function MadeList()
    if type(ns.db.made) ~= "table" then ns.db.made = {} end
    return ns.db.made
end

local function FindMade(id)
    if id == nil then return nil end
    for _, sparkle in ipairs(MadeList()) do
        if type(sparkle) == "table" and sparkle.id == id then return sparkle end
    end
end

-- The first layer's height is the frame's; the others sit that much higher or lower.
local function MadeBase(clean)
    return (clean.effects[1] or clean.layers[1]).height
end

-- The size and height a frame showing it takes (k: how much it is shrunk to fit a tile).
local function MadeLook(clean, k)
    local size = 0
    for _, look in ipairs(clean.effects) do size = max(size, look.size) end
    for _, look in ipairs(clean.layers) do size = max(size, look.size) end
    return { size = size * k, height = MadeBase(clean) }
end

-- A layer's place, size and alpha now, with its animation (clock: the frame's).
local function PlaceLayer(layer, clock)
    local look, k = layer.look, layer.k
    local x, y = look.x * k, (look.height - layer.base) * k
    local scale, alpha = 1, look.alpha / 100
    local anim = look.anim
    if anim ~= "None" then
        local w = clock * look.animSpeed / 100 * 2 * pi / LOOP + layer.phase
        local S = look.size * k
        if anim == "Pulse" then
            scale = 1 + 0.15 * sin(w)
        elseif anim == "Breathe" then
            alpha = alpha * (0.6 + 0.4 * sin(w))
        elseif anim == "Bob" then
            y = y + 0.1 * S * sin(w)
        elseif anim == "Orbit" then
            x, y = x + 0.15 * S * cos(w), y + 0.06 * S * sin(w)
        elseif anim == "Spin" then
            layer.actor:SetYaw(rad(look.turn) + w)
        end
    end
    layer:SetScale(scale)
    layer:ClearAllPoints()
    layer:SetPoint("CENTER", layer:GetParent(), "CENTER", x / scale, y / scale) -- (offsets are in the layer's own scale)
    -- An effect's see-through is its actor's (whether models follow a frame's alpha isn't known).
    if layer.actor then
        if layer.alpha ~= alpha then
            layer.alpha = alpha
            layer.actor:SetAlpha(alpha)
        end
    else
        layer:SetAlpha(alpha)
    end
end

-- Effect i, made the first time a frame shows one (no parent in CreateFrame, as NewSparkles).
local function ShowEffect(frame, i, look, k, base, tint)
    local fx = frame.fxs[i]
    if not fx then
        fx = CreateFrame("ModelScene")
        fx:SetParent(frame)
        fx:SetCameraFieldOfView(FX_FOV)
        fx:SetCameraOrientationByYawPitchRoll(pi, FX_PITCH, 0)
        local x, y, z = fx:GetCameraForward()
        fx:SetCameraPosition(-x * FX_DISTANCE, -y * FX_DISTANCE, -z * FX_DISTANCE)
        fx.actor = fx:CreateActor()
        fx.actor:SetUseCenterForOrigin(true, true, true)
        fx.phase = random() * 2 * pi
        frame.fxs[i] = fx
    end
    local actor, key = fx.actor, look.display and "d" .. look.display or look.file
    if fx.key ~= key then
        fx.key, fx.speed = key, nil
        if look.display then actor:SetModelByCreatureDisplayID(look.display) else actor:SetModelByFileID(look.file) end
    end
    if fx.speed ~= look.speed then
        fx.speed = look.speed
        actor:SetAnimation(0, nil, look.speed / 100)
    end
    actor:SetPitch(rad(look.tilt))
    actor:SetYaw(rad(look.turn))
    actor:SetParticleOverrideScale(look.particles / 100)
    local gray = tint == TOO_HARD_GRAY -- (a model takes no color: only gray shows on it)
    if fx.gray ~= gray then
        fx.gray = gray
        actor:SetDesaturation(gray and 1 or 0)
    end
    fx.look, fx.k, fx.base = look, k, base
    fx:SetFrameLevel(frame:GetFrameLevel() + i)
    fx:SetSize(look.size * k, look.size * k)
    PlaceLayer(fx, frame.clock or 0)
    fx:Show()
end

-- Style layer i, above the effects.
local function ShowStyleLayer(frame, i, look, kind, k, base, tint)
    local child = frame.layers[i]
    if not child then
        child = NewSparkles()
        child:SetParent(frame)
        child.phase = random() * 2 * pi
        frame.layers[i] = child
    end
    local style, S = STYLES[look.style], look.size * k
    child.kind, child.over = kind, { size = S, count = look.count, height = 0 }
    child.clock = child.clock or 0
    child.look, child.k, child.base = look, k, base
    child:SetFrameLevel(frame:GetFrameLevel() + MAX_PARTS + i)
    child:SetSize(S, S)
    PlaceLayer(child, frame.clock or 0)
    local one, two = look.color, look.color2
    if tint then one, two = tint, tint end
    ShowStyle(child, style, look.count, S, one, two)
    child.style = style
    child:Show()
end

-- Shows a made sparkle's layers in a frame. tint: a color instead of their own (gray
-- above your skill, or a skill color). Returns whether something moves each frame
-- (an animation, or a style with Draw).
local function ShowMadeLayers(frame, clean, kind, k, tint)
    local base = MadeBase(clean)
    frame.fxs, frame.layers = frame.fxs or {}, frame.layers or {}
    local moving = false
    for i = 1, MAX_PARTS do
        local look = clean.effects[i]
        if look then
            ShowEffect(frame, i, look, k, base, tint)
            moving = moving or look.anim ~= "None"
        elseif frame.fxs[i] then
            frame.fxs[i]:Hide()
        end
    end
    for i = 1, MAX_PARTS do
        local look, child = clean.layers[i], frame.layers[i]
        if look then
            ShowStyleLayer(frame, i, look, kind, k, base, tint)
            moving = moving or look.anim ~= "None" or STYLES[look.style].Draw ~= nil
        elseif child then
            ShowTwinkles(child, 0)
            child:Hide()
        end
    end
    return moving
end

-- The parts of a frame's made sparkle hidden (it shows a style again).
local function HideMade(frame)
    for _, child in ipairs(frame.layers or {}) do
        ShowTwinkles(child, 0)
        child:Hide()
    end
    for _, fx in ipairs(frame.fxs or {}) do fx:Hide() end
end

-- Moves the layers: the styles that move, as Animate does a style's, and the animations.
local function DrawMade(frame, _, _, elapsed)
    local clock = frame.clock
    for _, fx in ipairs(frame.fxs) do
        if fx:IsShown() and fx.look.anim ~= "None" then PlaceLayer(fx, clock) end
    end
    for _, child in ipairs(frame.layers) do
        if child:IsShown() then
            local style = child.style
            if style.Draw then
                child.clock = child.clock + elapsed
                style.Draw(child, child.parts[style.name], FrameLook(child, "size"), elapsed, child.clock)
            end
            if child.look.anim ~= "None" then PlaceLayer(child, clock) end
        end
    end
end
-- The style a frame with a made sparkle runs: it moves only when a layer does.
Made.STILL, Made.MOVING = { name = "made" }, { name = "made", Draw = DrawMade }
Made.EFFECTS, Made.ANIMS, Made.LIMITS, Made.DEFAULT = EFFECTS, ANIMS, LIMITS, DEFAULT
Made.MAX, Made.MAX_PARTS = MAX, MAX_PARTS
Made.List, Made.Find, Made.Clean = MadeList, FindMade, CleanMade
Made.Look, Made.ShowLayers, Made.Hide = MadeLook, ShowMadeLayers, HideMade
end

---------------------------------------------------------------------------
-- In reach and fading
---------------------------------------------------------------------------
-- With Dimmer out of reach on, sparkles are dimmer while the node is too far
-- to gather, and a flash goes off when you step into reach. Sparkles fade in,
-- fade out while their plate stays, and fade back while you gather the node.

local REACH_DIM = 0.45 -- alpha while out of reach
local REACH_HOLD = 0.15 -- a change must last this long (no flicker at the edge)
local REACH_FADE = 0.25 -- seconds to go from dim to full
local BURST_TIME = 0.6
local FADE_TIME = 0.3 -- seconds to fade out, or back in while gathering
local APPEAR_TIME = 1 -- seconds to fade in when a node comes into reach
local GATHER_DIM = 0.75 -- how far sparkles fade back while you gather the node
local HARVEST_TIME = 0.65 -- seconds of a gathered node's finish
-- The finish starts with the loot; this long after the gathering with no loot, anyway.
local LOOT_WAIT = 1.5
-- A node still there this long after its loot closed (or a finish with no loot) wasn't
-- emptied: its sparkles come back.
local BACK_WAIT = 1.5

-- Not secret; anything but false (an object the game won't say about, or a game
-- without the call, like Retail) counts as in reach.
local function InReach(unit)
    return not (unit and UnitIsInInteractRange and UnitIsInInteractRange(unit) == false)
end

local function Brightness() return (ns.db.brightness or 100) / 100 end

-- With own set, leaves out the finish's fade (for a part drawn past it).
local function FrameAlpha(frame, own)
    local alpha = Brightness() * frame.fade * (1 - GATHER_DIM * frame.gather) * (not own and frame.harvestAlpha or 1)
    if ns.db.reachLook then alpha = alpha * (REACH_DIM + (1 - REACH_DIM) * frame.reach) end
    return alpha
end

local function Toward(value, goal, step)
    if value < goal then return min(goal, value + step) end
    return max(goal, value - step)
end

local function UpdateReach(frame, elapsed)
    local near = not frame.far and InReach(frame.unit)
    if near ~= frame.near then
        frame.held = frame.held + elapsed
        if frame.held >= REACH_HOLD then
            frame.near, frame.held = near, 0
            if near then frame.burstAge = 0 end
        end
    else
        frame.held = 0
    end
    local goal = frame.near and 1 or 0
    if frame.reach < goal then frame.reach = min(goal, frame.reach + elapsed / REACH_FADE)
    elseif frame.reach > goal then frame.reach = max(goal, frame.reach - elapsed / REACH_FADE) end
end

-- The flash, in reach or when gathering is done.
local function Burst(frame, elapsed)
    frame.burstAge = frame.burstAge + elapsed
    local u = frame.burstAge / BURST_TIME
    if u >= 1 then
        frame.burstAge = nil
        if frame.burst then frame.burst:Hide() end
    else
        if not frame.burst then frame.burst = Layer(frame, BURST, 7) end
        local S = FrameLook(frame, "size")
        Put(frame, frame.burst, 0, 0, S * (0.4 + 1.1 * EaseOut(u)), nil, 1 - u)
    end
end

-- How a gathered node finishes, over HARVEST_TIME (u from 0 to 1). Each draws its
-- own parts and may set harvestAlpha (how much of the sparkles still shows),
-- harvestY (how far they've risen) and harvestScale (how far they've drawn in).
local function Part(frame, key, picture, sublevel, light)
    if not frame[key] then frame[key] = Layer(frame, picture, sublevel, light) end
    return frame[key]
end

local HARVESTS = {
    { name = "Star flash", Draw = function(frame, u, S)
        Put(frame, Part(frame, "burst", BURST, 7), 0, 0, S * (0.4 + 1.1 * EaseOut(u)), nil, 1 - u)
        frame.harvestAlpha = 1 - u
    end },
    { name = "Rising light", Draw = function(frame, u, S)
        frame.harvestAlpha, frame.harvestY = 1 - EaseIn(u), 0.6 * S * EaseOut(u)
    end },
    { name = "Gather in", Draw = function(frame, u, S)
        local pull = min(1, u / 0.6)
        frame.harvestScale = 1 - 0.85 * EaseIn(pull)
        frame.harvestAlpha = u < 0.6 and 1 - 0.3 * pull or 0
        -- The glint at the end, at its own size, and shown though the sparkles are gone.
        local v = max(0, (u - 0.5) / 0.5)
        local glint = Part(frame, "glint", STAR4, 7, true)
        glint:SetIgnoreParentAlpha(true)
        Put(frame, glint, 0, 0, S * 0.8 * Bell(v) / frame.harvestScale, nil, Bell(v) * FrameAlpha(frame, true))
    end },
    { name = "Scatter", Draw = function(frame, u, S)
        frame.scatter = frame.scatter or {}
        for i = 1, 8 do
            local m = frame.scatter[i] or Layer(frame, PICTURE, 7)
            frame.scatter[i] = m
            local angle, out = (i - 1) / 8 * 2 * pi + 0.4, 0.6 * S * EaseOut(u)
            Put(frame, m, cos(angle) * out, sin(angle) * out * 0.6 + S * (0.35 * u - 0.7 * u * u), S * 0.14 * (1 - 0.5 * u), nil, 1 - u)
        end
        frame.harvestAlpha = 1 - u
    end },
    { name = "Fade away", Draw = function(frame, u) frame.harvestAlpha = 1 - u end },
}

local zoomWatch -- below (Camera zoom)

-- The finish plays bright: the gathering dim goes the moment it starts.
local function StartHarvest(frame)
    frame.harvestAge, frame.harvest, frame.harvested = 0, ns.db.harvest, true
    frame.gathering, frame.gather = nil, 0
end

-- Back to no finish: its parts hidden, the sparkles where and as they were.
local function ResetHarvest(frame)
    if frame.harvestScale and frame.harvestScale ~= 1 then -- drawn in: back to its size
        frame:SetScale(frame.over and 1 or zoomWatch.scale or 1)
    end
    -- Risen: back down (only on its own plate; a spare is placed again when used).
    if frame.harvestY and frame.harvestY ~= 0 and frame.plate and frame:GetParent() == frame.plate then
        frame:SetPoint("CENTER", frame.plate, "BOTTOM", 0, Height(frame))
    end
    frame.harvestAge, frame.harvestAlpha, frame.harvestY, frame.harvestScale = nil, 1, 0, 1
    frame.harvested, frame.castDone, frame.backAt = nil, nil, nil
    if frame.burst and not frame.burstAge then frame.burst:Hide() end
    if frame.glint then frame.glint:Hide() end
    for _, m in ipairs(frame.scatter or {}) do m:Hide() end
end

local Recycle -- below

-- A rare node's gold glow, pulsing, or the kind's own glow, breathing slower and fainter
-- (soft: it lies over the node).
local function PutGlow(frame, S)
    local alpha = frame.rare and 0.3 + 0.15 * sin(frame.clock * 2.5) or 0.22 + 0.06 * sin(frame.clock * 1.5)
    Put(frame, frame.under, 0, GLOW_Y * S, GLOW_WIDE * S, GLOW_TALL * S, alpha)
end

-- Runs while a frame has something to move: a drawn style, Dimmer out of reach,
-- a rare node's glow, a fade or a flash. It stops itself when nothing is left.
local function Animate(frame, elapsed)
    if elapsed > 0.1 then elapsed = 0.1 end -- no jump after a stall
    frame.clock = frame.clock + elapsed
    local style = frame.style
    local S = FrameLook(frame, "size")
    if style.Draw then style.Draw(frame, frame.parts[style.name], S, elapsed, frame.clock) end
    local second = frame.second
    local secondDraw = second and second:IsShown() and second.style.Draw
    if secondDraw then
        second.clock = second.clock + elapsed
        secondDraw(second, second.parts[second.style.name], FrameLook(second, "size"), elapsed, second.clock)
    end
    if ns.db.reachLook then UpdateReach(frame, elapsed) end
    local gatherGoal = frame.gathering and ns.db.gatherDim and 1 or 0
    frame.fade = Toward(frame.fade, frame.leaving and 0 or 1, elapsed / (frame.leaving and FADE_TIME or APPEAR_TIME))
    frame.gather = Toward(frame.gather, gatherGoal, elapsed / FADE_TIME)
    if frame.glowing then PutGlow(frame, S) end
    if frame.burstAge then Burst(frame, elapsed) end
    if frame.castDone and not frame.harvested and GetTime() >= frame.castDone + LOOT_WAIT then
        StartHarvest(frame)
        frame.backAt = GetTime() + HARVEST_TIME + BACK_WAIT
    end
    if frame.backAt and GetTime() >= frame.backAt then
        ResetHarvest(frame)
        frame.fade = 0
    end
    if frame.harvestAge then
        frame.harvestAge = frame.harvestAge + elapsed
        local u = min(1, frame.harvestAge / HARVEST_TIME)
        local harvest = HARVESTS[frame.harvest] or HARVESTS[1]
        harvest.Draw(frame, u, S)
        frame:SetScale((frame.over and 1 or zoomWatch.scale or 1) * frame.harvestScale)
        frame:SetPoint("CENTER", frame.plate, "BOTTOM", 0, Height(frame) + frame.harvestY)
        if u >= 1 then
            frame.harvestAge = nil
            if frame.burst then frame.burst:Hide() end
            if frame.glint then frame.glint:Hide() end
        end
    end
    frame:SetAlpha(FrameAlpha(frame))
    if frame.leaving and frame.fade == 0 then return Recycle(frame) end
    if not (style.Draw or secondDraw or ns.db.reachLook or frame.glowing or frame.burstAge or frame.leaving
        or frame.harvestAge or (frame.castDone and not frame.harvested) or frame.backAt or frame.fade < 1 or frame.gather ~= gatherGoal) then
        frame:SetScript("OnUpdate", nil)
    end
end

---------------------------------------------------------------------------
-- Camera zoom
---------------------------------------------------------------------------
-- A node looks smaller the farther back the camera is, so its sparkles do too.
-- The game gives no distance to the node, so it is taken as NODE_AWAY yards
-- ahead of you; with the camera ZOOM_AT yards back, sparkles are their set size.

local ZOOM_AT, NODE_AWAY = 15, 10
local ZOOM_MIN, ZOOM_MAX = 0.4, 2.5

local function ZoomScale()
    local zoom = GetCameraZoom and GetCameraZoom()
    if type(zoom) ~= "number" or issecretvalue(zoom) then return 1 end
    return min(ZOOM_MAX, max(ZOOM_MIN, (ZOOM_AT + NODE_AWAY) / (max(0, zoom) + NODE_AWAY)))
end

-- Checks the zoom 10 times a second, only while sparkles are shown.
zoomWatch = CreateFrame("Frame")
zoomWatch:Hide()
zoomWatch.wait = 0
zoomWatch:SetScript("OnUpdate", function(self, elapsed)
    self.wait = self.wait - elapsed
    if self.wait > 0 then return end
    self.wait = 0.1
    local scale = ZoomScale()
    if scale == self.scale then return end
    self.scale = scale
    for _, frame in pairs(sparkles) do
        if not frame.harvestAge then frame:SetScale(scale) end -- a finish sets its own
    end
end)

---------------------------------------------------------------------------
-- Showing sparkles
---------------------------------------------------------------------------

-- A kind's second style or sparkle (shift-click in the sparkle window), on a frame of its
-- own over the first; hidden when show is false, or when it is the first one again.
-- Returns whether it moves each frame.
local function ShowSecond(frame, kind, show, tint)
    local i, made = show and Look(kind, "style2"), show and Made.Find(Look(kind, "made2"))
    local first = Made.Find(Look(kind, "made"))
    made = made ~= first and made and Made.Clean(made) or nil
    if made or not StyleFits(i, kind) or not first and i == Look(kind, "style") then i = nil end
    local second = frame.second
    if not (made or i) then
        if second and second:IsShown() then
            for key, parts in pairs(second.parts) do
                if type(key) == "string" then HideAll(parts) end
            end
            ShowTwinkles(second, 0)
            Made.Hide(second)
            second:Hide()
        end
        return false
    end
    if not second then
        second = NewSparkles()
        second:SetParent(frame)
        frame.second = second
    end
    second.kind, second.lower, second.clock = kind, frame.lower, second.clock or 0
    second:SetFrameLevel(frame:GetFrameLevel() + 2 * Made.MAX_PARTS + 1) -- (over the first's layers)
    if made then
        second.over, second.madeLook = nil, Made.Look(made, 1)
        for key, parts in pairs(second.parts) do
            if type(key) == "string" then HideAll(parts) end
        end
        ShowTwinkles(second, 0)
        second.style = Made.ShowLayers(second, made, kind, 1, tint) and Made.MOVING or Made.STILL
    else
        local look = More.StyleLook(kind, i)
        second.over, second.madeLook = { style = i, size = look.size, height = look.height, count = look.count }, nil
        Made.Hide(second)
        local one, two = look.color, look.color2 or look.color
        if tint then one, two = tint, tint end
        second.style = STYLES[i]
        ShowStyle(second, STYLES[i], look.count, look.size, one, two)
    end
    local S = FrameLook(second, "size")
    second:SetSize(S, S)
    second:ClearAllPoints()
    second:SetPoint("CENTER", frame, "CENTER", 0, Height(second) - Height(frame))
    second:Show()
    return second.style.Draw ~= nil
end

-- Puts the sparkle area on a plate and shows the kind's style. over: a preview
-- (on any frame), with a look to show instead of the saved one (style, size, height, count),
-- and an example of a setting: rare (the gold glow), far (out of reach), tooHard (gray),
-- skill (a skill color, 1 to 5).
local function ShowSparkles(namePlate, kind, unit, over)
    local frames = over and previews or sparkles
    local frame = frames[namePlate]
    if not frame and not over and leaving[namePlate] then -- fading out: back in
        frame, leaving[namePlate] = leaving[namePlate], nil
        frame.leaving, frames[namePlate] = nil, frame
        if frame.harvested then ResetHarvest(frame) end -- its finish cut short: back as it was
    end
    local fresh = not frame
    if not frame then
        frame = not over and table.remove(spare) or NewSparkles()
        frame:SetParent(namePlate)
        frames[namePlate] = frame
        frame.near, frame.reach, frame.held, frame.burstAge = InReach(unit), InReach(unit) and 1 or 0, 0, nil
        frame.fade, frame.gather, frame.gathering = over and 1 or 0, 0, nil
        ResetHarvest(frame)
    end
    frame.kind, frame.unit, frame.over, frame.plate = kind, unit, over, namePlate
    frame.clock = frame.clock or 0
    local name = not over and unit and UnitName(unit)
    if issecretvalue(name) or type(name) ~= "string" then name = nil end
    frame.name = name
    frame.rare = over and over.rare or name and ns.db.rareGlow and RARE[ns.NodeKey(name)] or nil
    frame.far = over and over.far or nil
    frame.lower = over and over.lower or name and LOWER[ns.NodeKey(name)] or nil
    if fresh and name and ns.db.sparkleSound then
        local now = GetTime()
        if now - heardAt >= SOUND_APART and now - (heard[name] or -SOUND_AGAIN) >= SOUND_AGAIN then
            PlaySound(SPARKLE_SOUND, "SFX")
            if heardAt > 0 and now - heardAt > SOUND_AGAIN then wipe(heard) end -- only the recent ones matter
            heard[name], heardAt = now, now
        end
    end
    if not over then
        zoomWatch.scale = ZoomScale()
        frame:SetScale(zoomWatch.scale * frame.harvestScale)
        zoomWatch:Show()
    end
    -- A made sparkle: the preview's, or the kind's (not on a style's tile, which gives a style).
    local made = over and over.made or not (over and over.style) and Made.Find(Look(kind, "made"))
    made = made and Made.Clean(made)
    local k = made and over and over.fit and over.fit / max(1, Made.Look(made, 1).size) or 1
    frame.madeLook = made and Made.Look(made, k) or nil
    local S = FrameLook(frame, "size")
    frame:SetSize(S, S)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", namePlate, "BOTTOM", 0, Height(frame) + frame.harvestY)
    local style = STYLES[FrameLook(frame, "style")] or STYLES[1]
    local color, color2 = Colors(kind)
    if over and over.color then color, color2 = over.color, over.color2 or over.color end
    local gray = over and over.tooHard or name and ns.db.grayTooHard and (kind == "herbs" or kind == "ore") and ns.TooHard(name, kind)
    -- A skill color goes over the kind's own colors and over that gray (only herbs and ore have one).
    local skill = over and over.skill or name and ns.db.skillColors and ns.SkillLevel(name, kind)
    local tint = skill and SKILL_COLORS[skill] or gray and TOO_HARD_GRAY or nil
    if tint then color, color2 = tint, tint end
    if made then
        for key, parts in pairs(frame.parts) do
            if type(key) == "string" then HideAll(parts) end
        end
        ShowTwinkles(frame, 0)
        style = Made.ShowLayers(frame, made, kind, k, tint) and Made.MOVING or Made.STILL
    else
        Made.Hide(frame)
        ShowStyle(frame, style, FrameLook(frame, "count"), S, color, color2)
    end
    -- A rare node's gold glow, else the kind's own in its first color (a tint too: see above),
    -- not on a style's tile.
    local glow = frame.rare and RARE_COLOR or not (over and (over.style or over.made)) and Look(kind, "glow") and color
    frame.glowing = glow and true or nil
    if frame.glowing then
        if not frame.under then frame.under = Layer(frame, GLOW, -1) end
        frame.under:SetVertexColor(RGB(glow))
        PutGlow(frame, S)
    elseif frame.under then
        frame.under:Hide()
    end
    if frame.burst and not frame.burstAge then frame.burst:Hide() end
    ShowSecond(frame, kind, not (over and (over.style or over.made)), tint) -- (not on a tile, which shows one)
    frame.style = style
    frame:SetScript("OnUpdate", Animate) -- it stops itself when there is nothing to move
    frame:SetAlpha(FrameAlpha(frame))
    frame:Show()
end

-- Stops a frame's sparkles and keeps it as a spare.
function Recycle(frame)
    frame:Hide()
    ShowSecond(frame, frame.kind, false)
    for _, part in ipairs(frame.parts) do
        part.group:Stop()
        part.coreGroup:Stop()
    end
    frame:ClearAllPoints()
    frame:SetParent(nil)
    if leaving[frame.plate] == frame then leaving[frame.plate] = nil end
    frame.leaving, frame.gathering, frame.cast = nil, nil, nil
    spare[#spare + 1] = frame
    if not next(sparkles) then zoomWatch:Hide() end
end

-- A plate's sparkles go: gently (fading out) while the plate stays, else at once.
local function HideSparkles(namePlate, gently)
    local frame = sparkles[namePlate]
    if not frame then
        if not gently and leaving[namePlate] then Recycle(leaving[namePlate]) end
        return
    end
    sparkles[namePlate] = nil
    if gently and frame:IsVisible() then
        frame.leaving, leaving[namePlate] = true, frame
        frame:SetScript("OnUpdate", Animate)
        return
    end
    Recycle(frame)
end

---------------------------------------------------------------------------
-- Gathering
---------------------------------------------------------------------------
-- A cast of yours whose target is the sparkling node's name is you gathering
-- it: its sparkles fade back, and finish when its loot comes.

-- Is a frame's node the game's `token` unit? No answer or a secret one: no.
local function IsUnit(frame, token)
    local same = frame.unit and UnitIsUnit(frame.unit, token)
    return not issecretvalue(same) and same == true
end

-- The cast only names the node: of nodes with that name, the one under the mouse,
-- else the interact target, is the one gathered (nil: can't tell, all of them).
local PICKED = { "mouseover", "softinteract" }
-- Where a loot window's corpse can be: the interact target, under the mouse, or targeted.
local LOOTED_FROM = { "softinteract", "mouseover", "target" }
local function GatheredOne(name)
    for _, token in ipairs(PICKED) do
        for _, frame in pairs(sparkles) do
            if frame.name == name and IsUnit(frame, token) then return frame end
        end
    end
end

local gatherWatch = CreateFrame("Frame")
for _, event in ipairs({ "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_FAILED_QUIET", "UNIT_SPELLCAST_INTERRUPTED" }) do
    gatherWatch:RegisterUnitEvent(event, "player")
end
gatherWatch:RegisterEvent("LOOT_READY")
gatherWatch:RegisterEvent("LOOT_CLOSED")
gatherWatch:SetScript("OnEvent", function(_, event, _, a, b)
    if not next(sparkles) then return end
    if event == "LOOT_CLOSED" then -- an emptied node goes; one left as it was stays
        for _, frame in pairs(sparkles) do
            if frame.harvested then
                frame.backAt = GetTime() + BACK_WAIT
                frame:SetScript("OnUpdate", Animate)
            end
        end
        return
    end
    if event == "LOOT_READY" then
        for _, frame in pairs(sparkles) do
            if frame.gathering and not frame.harvested then
                StartHarvest(frame)
                frame:SetScript("OnUpdate", Animate)
            end
        end
        -- A corpse being looted fades out now, not when the game takes its plate away.
        local corpse
        for _, token in ipairs(LOOTED_FROM) do
            for _, frame in pairs(sparkles) do
                if not corpse and frame.kind == "loot" and IsUnit(frame, token) then corpse = frame end
            end
        end
        if not corpse then -- can't tell: the only lootable corpse sparkling, if there is just one
            for _, frame in pairs(sparkles) do
                if frame.kind == "loot" then
                    if corpse then return end
                    corpse = frame
                end
            end
        end
        if corpse then
            looted[corpse.plate] = true
            HideSparkles(corpse.plate, true)
        end
        return
    end
    local castGUID = event == "UNIT_SPELLCAST_SENT" and b or a
    if issecretvalue(castGUID) or issecretvalue(a) or castGUID == nil then return end
    local one = event == "UNIT_SPELLCAST_SENT" and GatheredOne(a)
    for _, frame in pairs(sparkles) do
        if event == "UNIT_SPELLCAST_SENT" then
            if frame.name and a == frame.name and (not one or one == frame) then frame.gathering, frame.cast = true, castGUID end
        elseif frame.cast == castGUID then
            if event == "UNIT_SPELLCAST_SUCCEEDED" then
                if not frame.harvested then frame.castDone = GetTime() end
            else -- failed or interrupted: back as they were
                frame.gathering, frame.cast = nil, nil
                ResetHarvest(frame)
            end
        end
        frame:SetScript("OnUpdate", Animate)
    end
end)

---------------------------------------------------------------------------
-- Nameplates
---------------------------------------------------------------------------

-- Nameplate addons move the game's interact icon off the unit frame to keep it in
-- view, so the icon's own frame is faded too (Blizzard never sets its alpha).
local function SetHidden(unitFrame, hide)
    unitFrame:SetAlpha(hide and 0 or 1)
    local soft = unitFrame.SoftTargetFrame
    if soft then soft:SetAlpha(hide and 0 or 1) end
    hidden[unitFrame] = hide or nil
end

-- Name only: every part of a unit frame but its name faded out (Blizzard never
-- sets these parts' alpha). The target highlight ignores its parent's alpha.
local BARE_PARTS = { "HealthBarsContainer", "CastBarsContainer", "PlayerLevelDiffFrame", "LevelFrame",
    "ClassificationFrame", "AurasFrame", "SoftTargetFrame" }
local bare = {} -- unit frame: its highlight's alpha before
local function SetBare(unitFrame, on)
    if not on and bare[unitFrame] == nil then return end
    local light = unitFrame.selectionHighlight
    if on and bare[unitFrame] == nil then
        local alpha = light and light:GetAlpha()
        bare[unitFrame] = not issecretvalue(alpha) and alpha or 0.25 -- 0.25: the XML's
    end
    for _, key in ipairs(BARE_PARTS) do
        local part = unitFrame[key]
        if part then part:SetAlpha(on and not (key == "SoftTargetFrame" and ns.db.gameIcons) and 0 or 1) end
    end
    if light then light:SetAlpha(on and 0 or bare[unitFrame]) end
    if not on then bare[unitFrame] = nil end
end

-- Nothing to do: sparkles off and nothing of ours on any plate.
local function Idle()
    return not SparklesOn() and not next(hidden) and not next(bare) and not next(sparkles)
        and not (ns.cultivationIcons and next(ns.cultivationIcons))
end

-- Quest objects you loot or use often have the plain interact icon (a pumpkin has
-- a mailbox's), and UnitIsRelatedToActiveQuest is false for objects, so they're
-- found by name among your unfinished item and object objectives ("Tirisfal
-- Pumpkin: 3/10", "Scourge Cauldron destroyed: 0/1"), by the quest data
-- (ns.QUEST_OBJECTS) and by the objects you got a quest's item from before.
local questNames, questWords, openQuests, questsRead = {}, {}, {}, false

-- Short common words, which would match books and chairs ("The Story of ..." for "Horn of the Beast").
local COMMON = {}
for _, word in ipairs({ "the", "and", "for", "with", "from", "into", "your", "this", "that",
    "der", "die", "das", "des", "den", "dem", "und", "von", "mit", "ein", "eine", "einer", "eines",
    "les", "une", "aux", "pour", "avec", "sur", "dans", "los", "las", "del", "una", "con", "para", "por",
    "dos", "uma", "com" }) do COMMON[word] = true end

-- Words of 3 letters or more, each also without a plural's ending. An object
-- often shares one with the item it gives (Naxxramas Crystal Fragment for
-- Necrotic Crystal Fragment, Cattail for Handful of Cattails).
local function Words(text)
    local words = {}
    for word in text:lower():gmatch("[%a\128-\255]+") do
        if #word >= 3 and not COMMON[word] then
            words[#words + 1] = word
            if #word > 4 and word:sub(-3) == "ies" then
                words[#words + 1] = word:sub(1, -4) .. "y" -- berries: berry
            elseif #word > 3 and word:sub(-1) == "s" and word:sub(-2) ~= "ss" then
                words[#words + 1] = word:sub(1, -2) -- cattails: cattail; grass stays
            end
        end
    end
    return words
end

local function SharesWord(name)
    for _, word in ipairs(Words(name)) do
        if questWords[word] then return true end
    end
    return false
end

local function ObjectiveItem(text)
    return text:match("^(.-):%s*%d+%s*/%s*%d+%s*$") or text:match("^%s*%d+%s*/%s*%d+%s+(.-)%s*$") or text
end

local function ReadQuests()
    questsRead = true
    wipe(questNames)
    wipe(questWords)
    wipe(openQuests)
    local log = C_QuestLog
    if not (log and log.GetNumQuestLogEntries and log.GetInfo and log.GetQuestObjectives) then return end
    for i = 1, log.GetNumQuestLogEntries() do
        local info = log.GetInfo(i)
        local objectives = info and not info.isHeader and info.questID and log.GetQuestObjectives(info.questID)
        if objectives then
            for _, o in ipairs(objectives) do
                local text = o.text
                if not o.finished then openQuests[info.questID] = true end
                if (o.type == "item" or o.type == "object") and not o.finished and type(text) == "string" then
                    local item = ObjectiveItem(text)
                    questNames[item] = true
                    for _, word in ipairs(Words(item)) do questWords[word] = true end
                end
            end
        end
    end
end

-- An object your quests want: one of its quests is open, or it gave you an item
-- an unfinished objective still asks for.
local function QuestObject(unit)
    local id = ObjectID(UnitGUID(unit))
    local item = ns.db.questObjects and ns.db.questObjects[id]
    if item and questNames[item] then return true end
    local quests = ns.QUEST_OBJECTS and ns.QUEST_OBJECTS[id]
    if type(quests) ~= "table" then return openQuests[quests] == true end
    for _, quest in ipairs(quests) do
        if openQuests[quest] then return true end
    end
    return false
end

-- LOOT_READY: an object that gave an item an unfinished objective asks for is
-- remembered (account-wide), so it sparkles as a quest object from then on.
local function LearnQuestLoot()
    if not questsRead then ReadQuests() end
    for slot = 1, GetNumLootItems() do
        local _, name = GetLootSlotInfo(slot)
        if not issecretvalue(name) and questNames[name] then
            local id = ObjectID(GetLootSourceInfo(slot))
            if id then
                ns.db.questObjects = ns.db.questObjects or {}
                ns.db.questObjects[id] = name
            end
        end
    end
end

local questWatch = CreateFrame("Frame")
questWatch:RegisterEvent("QUEST_LOG_UPDATE")
questWatch:RegisterEvent("LOOT_READY")
questWatch:SetScript("OnEvent", function(_, event)
    if event == "LOOT_READY" then
        LearnQuestLoot()
    else
        questsRead = false -- read again when next needed
    end
end)

-- What sparkles on an object's plate: its kind, the bobber and chests (by their
-- names) found among plain and other objects. Your
-- interact target with such an icon also goes by name: herbs and ore (Gloom
-- Weed has no herb icon) and quest objects.
local function SparkleKind(unit, icon)
    local kind, read = ObjectKind(unit, icon)
    if kind == "loot" then kind = "others" end -- (an object to loot: a chest is told by its name)
    if kind == "plain" or kind == "others" then
        if ns.db.bobber and IsBobber(unit) then return "bobber" end
        local name = UnitName(unit)
        if issecretvalue(name) or type(name) ~= "string" then return kind end
        local named = ns.NodeKind(name)
        if ns.db.quests and read and named ~= "herbs" and named ~= "ore" then
            if not questsRead then ReadQuests() end
            if QuestObject(unit) then return "quests" end -- a quest's chest too
        end
        if named == "treasure" then return "chests" end
        if read and (named == "herbs" or named == "ore") then return named end
        if read and (questNames[name] or SharesWord(name)) then return "quests" end
    end
    return kind
end

-- Skinning sparkles need plates on corpses, which the game only gives with
-- "Always show nameplates for soft interact target". That shows a plate on the
-- NPC you can talk to as well; such plates show only the name while they last.
local extra = {} -- plate: an NPC's plate shown that way

-- A kind's sparkles on, and with Only for my professions, its profession known.
local function Mine(kind)
    return ns.db[kind] and (not ns.db.myProfessions or ns.HasProfession(kind)) or false
end

local function Corpse(unit)
    local dead = UnitIsDead(unit)
    if issecretvalue(dead) or not dead then return false end
    local player = UnitIsPlayer(unit)
    return not issecretvalue(player) and not player
end

-- A corpse sparkles with the loot icon (still to loot) or the skinning icon (looted, to skin).
local function CorpseKind(unit, icon)
    local kind = ObjectKind(unit, icon)
    return (kind == "skinning" or kind == "loot") and kind or "plain"
end

-- A friendly NPC's plate that shows only because it is your interact target.
local function InteractOnly(unit)
    if GetCVarBool("nameplateShowFriendlyNpcs") or UnitCanAttack("player", unit) then return false end
    local player = UnitIsPlayer(unit)
    if issecretvalue(player) or player then return false end
    local picked = UnitIsUnit(unit, "softinteract")
    return not issecretvalue(picked) and picked == true
end

-- The Cultivation icon (Cultivation.lua) over a herb you can cultivate now, whatever
-- its sparkles; on any other plate none. A secret name or GUID goes on as unknown.
local function CultivationIcon(namePlate, unit, kind, hide)
    if kind == "herbs" and not hide then
        local name, guid = UnitName(unit), UnitGUID(unit)
        if issecretvalue(name) then name = nil end
        if issecretvalue(guid) then guid = nil end
        if ns.CanCultivate(name, guid) then return ns.ShowCultivation(namePlate) end
    end
    ns.HideCultivation(namePlate)
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
        if unitFrame then SetBare(unitFrame, false) end
        return
    end
    local namePlate = C_NamePlate.GetNamePlateForUnit(unit)
    local unitFrame = namePlate and namePlate.UnitFrame
    if not unitFrame then return end -- forbidden (friendly in instances) or gone
    local object = UnitIsGameObject(unit)
    local corpses = ns.db.skinning or ns.db.loot
    local corpse = not object and corpses and Corpse(unit)
    if not object and not corpse and corpses and (extra[namePlate] or InteractOnly(unit)) then
        extra[namePlate] = true
        if hidden[unitFrame] then SetHidden(unitFrame, false) end
        SetBare(unitFrame, true)
        ns.HideCultivation(namePlate)
        return HideSparkles(namePlate)
    end
    extra[namePlate] = nil
    SetBare(unitFrame, false)
    if (object or corpse) and SparklesOn() then
        -- Hide every object plate (alpha only; not for the Cultivation icon alone); sparkle
        -- herbs, ore and, if set, others.
        if not ns.db.gameIcons and SparkleSwitchesOn() then
            SetHidden(unitFrame, true)
        elseif hidden[unitFrame] then
            SetHidden(unitFrame, false)
        end
        local hide = ns.db.combatHide and UnitAffectingCombat("player") or ns.db.instanceHide and IsInInstance()
        -- A gathered node loses its gathering icon as it goes: its finish plays out in its own look.
        local gathered = sparkles[namePlate]
        if gathered and gathered.harvested then
            ns.HideCultivation(namePlate)
            if ns.db[gathered.kind] and not hide then return end
            return HideSparkles(namePlate, true)
        end
        local icon = unitFrame.SoftTargetFrame.Icon
        local kind = object and SparkleKind(unit, icon) or CorpseKind(unit, icon)
        CultivationIcon(namePlate, unit, kind, hide)
        -- The game shows the icon only on the interact target: a herb or ore that stops
        -- being it fades out, not taken for an other object.
        if kind == "others" and known[namePlate] then return HideSparkles(namePlate, true) end
        if kind ~= "others" then known[namePlate] = kind end
        if kind == "loot" and looted[namePlate] then return HideSparkles(namePlate, true) end
        if Mine(kind) and not hide then ShowSparkles(namePlate, kind, unit) else HideSparkles(namePlate, true) end
    else
        if hidden[unitFrame] then SetHidden(unitFrame, false) end
        ns.HideCultivation(namePlate)
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
hooksecurefunc(NamePlateDriverFrame, "OnNamePlateAdded", function(_, unit)
    if Idle() then
        wipe(known)
        wipe(extra)
        wipe(looted)
    elseif unit:find("^nameplate%d+$") then
        local namePlate = C_NamePlate.GetNamePlateForUnit(unit)
        if namePlate then known[namePlate], extra[namePlate], looted[namePlate] = nil, nil, nil end -- a new object on it
    end
    Update(unit)
end)
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
-- doesn't taint. Set at login and loading screens (a change made elsewhere is left
-- until then); changes wait out combat; old values come back when sparkles go off.

local RANGE = 30 -- yards (default 10)

local WANTED = {
    { "softTargetInteract", "3", town = true },
    { "SoftTargetIconGameObject", "1" },
    { "SoftTargetInteractArc", "2" }, -- anywhere around you, not only in front
    -- Herbs only show within 15 yards whatever this says, so 15 or more is left as it is
    -- (fishing addons set 15 while you fish).
    { "SoftTargetInteractRange", tostring(RANGE), least = 15 },
    -- NPC interact icons have no plate to hide, so shrink them to 0 (only with a sparkle
    -- switch on: the Cultivation switch alone leaves them, like Blizzard's object plates).
    { "SoftTargetWorldtextSize", "0", npcIcon = true },
    -- Corpses only get a plate with this. It would give the NPC you can talk to
    -- one too (hiding its own name), so it's on only while a corpse is the target.
    { "SoftTargetNameplateInteract", "1", corpse = true },
}
local pendingSetup -- a change is waiting for combat to end
local corpseShown -- the plates setting is on for the corpse you target
local refused = {} -- cvar: true while the game refuses our value

local function CorpseTargeted()
    return (Mine("skinning") or Mine("loot")) and UnitExists("softinteract") and Corpse("softinteract") or false
end

-- Corpse sparkles on, but the game gives a corpse no plate with enemy nameplates off.
function ns.CorpsePlatesOff()
    return (Mine("skinning") or Mine("loot")) and not GetCVarBool("nameplateShowEnemies")
end

-- Interact Key off in towns: there the game would pick NPCs you can talk to rather than objects.
local function InTown() return ns.db.townInteractOff == true and (IsResting() == true or ns.InTownArea()) end
local townShown -- the Interact Key is off for a town
local TOWN_EVENTS = { PLAYER_UPDATE_RESTING = true, ZONE_CHANGED = true, ZONE_CHANGED_INDOORS = true, ZONE_CHANGED_NEW_AREA = true }

-- Your own value without the keyboard part (1 is gamepad only), so a controller still talks to NPCs.
local function TownValue(own)
    local value = tonumber(own) or 0
    return value % 2 == 1 and "1" or "0"
end

-- CVars can come back reformatted ("30.000000" for 30).
local function Same(a, b)
    return a == b or (tonumber(a) ~= nil and tonumber(a) == tonumber(b))
end

-- A value that does as well as ours (a range of at least `least`).
local function Enough(entry, value)
    return entry.least ~= nil and (tonumber(value) or 0) >= entry.least
end

-- Restores one CVar, unless you changed it since.
local function PutBack(cvar)
    local old, mine = ns.db.saved[cvar], ns.db.applied[cvar]
    if old ~= nil and mine ~= nil and Same(C_CVar.GetCVar(cvar), mine) then C_CVar.SetCVar(cvar, old) end
    ns.db.saved[cvar], ns.db.applied[cvar] = nil, nil
end

-- Sets each needed CVar, saving the old value.
local function ApplySetup()
    corpseShown = CorpseTargeted()
    townShown = InTown()
    for _, entry in ipairs(WANTED) do
        local cvar, value = entry[1], entry[2]
        local old = C_CVar.GetCVar(cvar)
        if entry.town and townShown then value = TownValue(ns.db.saved[cvar] or old) end
        refused[cvar] = nil
        if entry.npcIcon and (ns.db.gameIcons or not SparkleSwitchesOn()) or entry.corpse and not corpseShown then
            PutBack(cvar)
        elseif old ~= nil and not Same(old, value) and not Enough(entry, old) then
            C_CVar.SetCVar(cvar, value)
            -- Save only if the game accepted it, and only once.
            if Same(C_CVar.GetCVar(cvar), value) then
                if ns.db.saved[cvar] == nil then ns.db.saved[cvar] = old end
                ns.db.applied[cvar] = value
            else
                refused[cvar] = true
            end
        end
    end
end

local function RestoreSetup()
    corpseShown = false
    for cvar in pairs(ns.db.saved) do PutBack(cvar) end
    for cvar in pairs(ns.db.applied) do ns.db.applied[cvar] = nil end
end

-- Applies or restores the CVars to match the sparkle settings.
local function Setup()
    if not Running() then return end
    if InCombatLockdown() then
        pendingSetup = true
        return
    end
    pendingSetup = nil
    if SparklesOn() then ApplySetup() else RestoreSetup() end
end

-- A corpse becoming the interact target, or no longer being it; towns.
local corpseWatch = CreateFrame("Frame")
corpseWatch:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED")
for event in pairs(TOWN_EVENTS) do corpseWatch:RegisterEvent(event) end
corpseWatch:SetScript("OnEvent", function(_, event)
    if TOWN_EVENTS[event] then
        if InTown() ~= (townShown or false) then Setup() end
        return
    end
    if CorpseTargeted() ~= corpseShown then Setup() end
end)

-- What the other files use of this one.
ns.sparkles, ns.hidden, ns.leaving = sparkles, hidden, leaving
ns.HARVESTS, ns.SparklePreviews, ns.SparkleAnimate, ns.ResetHarvest = HARVESTS, previews, Animate, ResetHarvest
ns.ApplyColor, ns.NewSparkle, ns.NewSparkles = ApplyColor, NewSparkle, NewSparkles
ns.ShowSparkles, ns.HideSparkles, ns.Setup, ns.UpdateAll = ShowSparkles, HideSparkles, Setup, UpdateAll
-- Logging out or reloading: the CVars back as they were. They're account settings, so a
-- character without the addon (or with it turned off) finds them as they were; set again at login.
function ns.SetupOut()
    if not InCombatLockdown() then RestoreSetup() end
end
ns.KINDS, ns.SPARKLE_KEYS, ns.SPARKLE_STYLES, ns.StyleFits = KINDS, KEYS, STYLES, StyleFits
ns.StyleLook, ns.SPARKLE_START_HEIGHT = More.StyleLook, More.START_HEIGHT
ns.SPARKLE_EFFECTS, ns.MADE_ANIMS, ns.MADE_LIMITS, ns.MADE_DEFAULT = Made.EFFECTS, Made.ANIMS, Made.LIMITS, Made.DEFAULT
ns.MADE_MAX, ns.MADE_MAX_PARTS = Made.MAX, Made.MAX_PARTS
ns.MadeList, ns.FindMade, ns.CleanMade = Made.List, Made.Find, Made.Clean
ns.CarryOverLooks, ns.SparkleLook, ns.SparkleRGB, ns.SparkleColors, ns.SPARKLE_LOWER = CarryOverLooks, Look, RGB, Colors, LOWER
ns.SKILL_COLORS = SKILL_COLORS
-- Is a Setup waiting for the end of combat?
function ns.SetupPending() return pendingSetup end
-- The first CVar sparkles need that the game refused, or nil.
function ns.RefusedCVar()
    for _, entry in ipairs(WANTED) do
        if refused[entry[1]] then return entry[1] end
    end
end
-- Is the Interact Key off because you're in town (Interact Key off in towns)?
ns.InteractPaused = InTown
-- Did you have the game's icon on objects yourself: Enable Interact Key on, with Interact
-- Key Icons on Show All? (Your own values: the ones kept to put back, else the CVars.)
-- Show All turns on all four icon settings; sparkles only ever set the object one, so
-- what an earlier install left on isn't taken for your choice.
function ns.OwnGameIcons()
    local function Own(cvar) return tonumber(ns.db.saved[cvar] or C_CVar.GetCVar(cvar)) or 0 end
    return Own("softTargetInteract") >= 2 and Own("SoftTargetIconEnemy") == 1 and Own("SoftTargetIconInteract") == 1
        and Own("SoftTargetIconGameObject") == 1 and Own("SoftTargetLowPriorityIcons") == 1
end
-- Blizzard's tip asking for an Interact Key binding comes back every login while the key
-- is on. Sparkles need no binding, so mark it seen (called at PLAYER_LOGIN, before the tip).
function ns.QuietInteractTip()
    if SparklesOn() and not InCombatLockdown() and C_CVar.GetCVar("interactKeyWarningTutorial") == "0" then
        C_CVar.SetCVar("interactKeyWarningTutorial", "1")
    end
end
