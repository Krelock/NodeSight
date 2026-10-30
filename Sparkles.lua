-- NodeSight's sparkles on the herb or ore in front of you. They sit on the
-- nameplate of the game's soft interact target, so while sparkles are on the
-- interact CVars are turned on and Blizzard's object plates are hidden (unless
-- the game's icons are kept).
--
-- Sections: Each kind's look, Telling herbs and ore apart, Sparkles, Styles,
-- In reach and fading, Camera zoom, Showing sparkles, Gathering, Nameplates,
-- Interact detection.

local _, ns = ...

local ipairs, pairs = ipairs, pairs
local random = math.random
local sin, cos, floor, max, min, abs, pi = math.sin, math.cos, math.floor, math.max, math.min, math.abs, math.pi

-- Any sparkles on? Only then does the addon touch interact settings or plates.
local function SparklesOn()
    return ns.db.herbs or ns.db.ore or ns.db.chests or ns.db.quests or ns.db.others or ns.db.bobber
end

-- The gathering nodes' sparkle (world/skillactivated/tradeskillnodes/sparkle.blp).
local PICTURE = 984391
-- Blizzard's art for the other styles: a four-point star, a soft round glow, a gold ring.
local GLOW = "BonusChest-CircleGlow"
local RING = "PowerSwirlAnimation-YellowRing"
local STAR4 = 131010 -- Interface\Cooldown\star4, the cooldown's finish flash
local SOFT_STAR = "GarrisonFX-StarBurst"
local TOO_HARD_GRAY = "ff8c8c8c" -- herbs and ore above your skill, with Gray when your skill is too low
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

-- Each sparkle is a body plus a smaller, lighter core.
local CORE = 0.45 -- core size relative to the body
local CORE_LIGHT = 0.6 -- how much lighter the core's tint is
local BEAM_FOOT = 0.1 -- the beam's alpha at its foot, where the node is
-- A rare node's glow: a soft round light centered on it, so it looks the same from
-- any camera angle (sizes and its middle's height in areas).
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

---------------------------------------------------------------------------
-- Each kind's look
---------------------------------------------------------------------------
-- Herbs keep the keys the shared look had, so saved settings carry over.

local KINDS = { "herbs", "ore", "chests", "quests", "others", "bobber" }
local KEYS = {
    herbs = { style = "herbStyle", color = "sparkleColor", color2 = "sparkleColor2", size = "size", height = "height", count = "count" },
}
for _, kind in ipairs({ "ore", "chests", "quests", "others", "bobber" }) do
    KEYS[kind] = { style = kind .. "Style", color = kind .. "Color", color2 = kind .. "Color2", size = kind .. "Size", height = kind .. "Height",
        count = kind .. "Count" }
end

local function Look(kind, what) return ns.db[KEYS[kind or "herbs"][what]] end

-- A kind's two colors; with no second color saved, the first twice.
local function Colors(kind)
    local one = Look(kind, "color")
    return one, Look(kind, "color2") or one
end

-- A frame's look: its kind's, or what frame.over gives (the sparkle window's previews).
local function FrameLook(frame, what)
    local over = frame.over
    if over and over[what] ~= nil then return over[what] end
    return Look(frame.kind, what)
end

-- Before the defaults are filled in: chests and quest objects (other objects before)
-- start as other objects were, and the other kinds from the herbs' saved look (but
-- the bobber's height: it floats on the water, at 0).
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
                if kind ~= "herbs" and db[keys[what]] == nil and not (kind == "bobber" and what == "height") then db[keys[what]] = saved end
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

-- "herbs", "ore", "quests", "others", or "plain" (never sparkles: guild vault,
-- mailbox, chairs, doors). A hidden icon counts as "others".
local function Kind(icon)
    if not icon:IsShown() then return "others" end
    local texture, atlas = icon:GetTexture(), icon:GetAtlas()
    if HasName(texture, "herb") or HasName(atlas, "herb") then return "herbs" end
    if HasName(texture, "mine", "mining") or HasName(atlas, "mine", "mining") then return "ore" end
    if HasName(texture, "buy") or HasName(atlas, "buy") then return "plain" end
    if HasName(texture, "mail") or HasName(atlas, "mail") then return "plain" end
    if HasName(texture, "questinteract") or HasName(atlas, "questinteract") then return "quests" end
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
    if issecretvalue(picked) or not picked then return "others" end -- a secret can't be tested
    if not probe then probe = CreateFrame("Frame"):CreateTexture() end
    if not SetUnitCursorTexture(probe, unit, nil, true, true) then return "others" end
    return Kind(probe)
end

-- The bobber has the plain interact icon. Its object ID (in its GUID) says
-- what it is; without a readable GUID, an object while you fish is taken for it.
local BOBBER = 35591
local FISHING_ICON = 136245 -- the Fishing spell's icon, the same in every language

local function Fishing()
    local _, _, icon = UnitChannelInfo("player")
    return not issecretvalue(icon) and icon == FISHING_ICON
end

local function IsBobber(unit)
    local guid = UnitGUID(unit)
    local id = not issecretvalue(guid) and type(guid) == "string" and guid:match("^GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    if id then return tonumber(id) == BOBBER end
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

-- Each style: its name, how it is built (Build: its parts for count n), and
-- Draw (moves them; c is the frame's clock, A its alpha). Twinkle is the
-- animations above. start: the look a style comes with when it is picked;
-- only: the one kind it is made for (the rest fit every kind).
local STYLES = {
    { name = "Twinkle", twinkle = true, start = { size = 100, height = -60, count = 9, color = "ffffffff" },
        tip = "Sparkles grow, drift up and fade." },
    { name = "Glints", start = { size = 100, height = -60, count = 6, color = "ffffffff", color2 = "ff9fd8ff" }, tip = "Quick sharp flashes like light on a vein. Shows half the count.",
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
    { name = "Pollen", start = { size = 100, height = -60, count = 9, color = "ffffffff" }, tip = "Soft specks float up and sway. Shows twice the count.",
        Build = function(frame, n, S) return { motes = Motes(frame, n * 2, GLOW, false, PollenSpawn, S) } end,
        Draw = function(frame, p, S, elapsed)
            Age(p.motes, elapsed, PollenSpawn, S)
            for _, m in ipairs(p.motes) do
                local k, u = 0, m.t / m.life
                if m.t > 0 then k = u < 0.25 and u / 0.25 or u > 0.7 and 1 - (u - 0.7) / 0.3 or 1 end
                PutSpark(frame, m, m.x + sin(u * 2 * pi * 1.3 + m.phase) * m.sway, m.y + u * 0.65 * S, m.s, k * 0.85)
            end
        end },
    { name = "Star crown", start = { size = 110, height = -60, count = 7, color = "ffffd100", color2 = "ffffffff" }, tip = "A ring of stars turns over the node. Count is how many stars.",
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
    { name = "Wisp", start = { size = 110, height = -60, count = 9, color = "ff8fd8ff", color2 = "ffffffff" }, tip = "A wisp circles the node and leaves a trail. Doesn't use Count.",
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
    { name = "Light beam", start = { size = 100, height = -60, count = 9, color = "ffffd100", color2 = "ffffffff" }, tip = "A beam of light goes up from the node. Easy to spot from far away. Doesn't use Count.",
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
    { name = "Settling dust", start = { size = 110, height = -60, count = 8, color = "ffffe9bf" }, tip = "Dust floats down and settles on the node. Shows three times the count.",
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
    { name = "Fireflies", start = { size = 100, height = -60, count = 9, color = "ffffffff" }, tip = "Fireflies float around and blink on and off. Count is how many, 2 to 8.",
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
}

-- Can kind have style i?
local function StyleFits(i, kind)
    local style = STYLES[i]
    return style ~= nil and (not style.only or style.only == kind)
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
local FADE_TIME = 0.3 -- seconds to fade in or out
local GATHER_DIM = 0.75 -- how far sparkles fade back while you gather the node
local HARVEST_TIME = 0.7 -- seconds of a gathered node's finish
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
    local near = InReach(frame.unit)
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
        frame:SetPoint("CENTER", frame.plate, "BOTTOM", 0, FrameLook(frame, "height"))
    end
    frame.harvestAge, frame.harvestAlpha, frame.harvestY, frame.harvestScale = nil, 1, 0, 1
    frame.harvested, frame.castDone, frame.backAt = nil, nil, nil
    if frame.burst and not frame.burstAge then frame.burst:Hide() end
    if frame.glint then frame.glint:Hide() end
    for _, m in ipairs(frame.scatter or {}) do m:Hide() end
end

local Recycle -- below

-- A rare node's gold glow, pulsing (soft: it lies over the node).
local function PutGlow(frame, S)
    Put(frame, frame.under, 0, GLOW_Y * S, GLOW_WIDE * S, GLOW_TALL * S, 0.3 + 0.15 * sin(frame.clock * 2.5))
end

-- Runs while a frame has something to move: a drawn style, Dimmer out of reach,
-- a rare node's glow, a fade or a flash. It stops itself when nothing is left.
local function Animate(frame, elapsed)
    if elapsed > 0.1 then elapsed = 0.1 end -- no jump after a stall
    frame.clock = frame.clock + elapsed
    local style = frame.style
    local S = FrameLook(frame, "size")
    if style.Draw then style.Draw(frame, frame.parts[style.name], S, elapsed, frame.clock) end
    if ns.db.reachLook then UpdateReach(frame, elapsed) end
    local gatherGoal = frame.gathering and ns.db.gatherDim and 1 or 0
    frame.fade = Toward(frame.fade, frame.leaving and 0 or 1, elapsed / FADE_TIME)
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
        frame:SetPoint("CENTER", frame.plate, "BOTTOM", 0, FrameLook(frame, "height") + frame.harvestY)
        if u >= 1 then
            frame.harvestAge = nil
            if frame.burst then frame.burst:Hide() end
            if frame.glint then frame.glint:Hide() end
        end
    end
    frame:SetAlpha(FrameAlpha(frame))
    if frame.leaving and frame.fade == 0 then return Recycle(frame) end
    if not (style.Draw or ns.db.reachLook or frame.glowing or frame.burstAge or frame.leaving
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

-- Puts the sparkle area on a plate and shows the kind's style. over: a preview
-- (on any frame), with a look to show instead of the saved one (style, size, height, count).
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
    frame.rare = name and ns.db.rareGlow and RARE[ns.NodeKey(name)] or nil
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
    local S = FrameLook(frame, "size")
    frame:SetSize(S, S)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", namePlate, "BOTTOM", 0, FrameLook(frame, "height") + frame.harvestY)
    local style = STYLES[FrameLook(frame, "style")] or STYLES[1]
    local color, color2 = Colors(kind)
    if over and over.color then color, color2 = over.color, over.color2 or over.color end
    if name and ns.db.grayTooHard and (kind == "herbs" or kind == "ore") and ns.TooHard(name, kind) then
        color, color2 = TOO_HARD_GRAY, TOO_HARD_GRAY
    end
    local count = FrameLook(frame, "count")
    -- Other styles' parts hidden; this one's made again when the count or size changed.
    for name, parts in pairs(frame.parts) do
        if type(name) == "string" and name ~= style.name then HideAll(parts) end
    end
    if style.twinkle then
        ShowTwinkles(frame, count, color, color2)
    else
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
    -- A rare node's gold glow.
    frame.glowing = frame.rare
    if frame.glowing then
        if not frame.under then
            frame.under = Layer(frame, GLOW, -1)
            frame.under:SetVertexColor(RGB(RARE_COLOR))
        end
        PutGlow(frame, S)
    elseif frame.under then
        frame.under:Hide()
    end
    if frame.burst and not frame.burstAge then frame.burst:Hide() end
    frame.style = style
    frame:SetScript("OnUpdate", Animate) -- it stops itself when there is nothing to move
    frame:SetAlpha(FrameAlpha(frame))
    frame:Show()
end

-- Stops a frame's sparkles and keeps it as a spare.
function Recycle(frame)
    frame:Hide()
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

local function SetHidden(unitFrame, hide)
    unitFrame:SetAlpha(hide and 0 or 1)
    hidden[unitFrame] = hide or nil
end

-- Nothing to do: sparkles off and nothing of ours on any plate.
local function Idle()
    return not SparklesOn() and not next(hidden) and not next(sparkles)
end

-- What sparkles on an object's plate: its kind, the bobber and chests (by their
-- names, as the minimap's are) found among plain and other objects.
local function SparkleKind(unit, icon)
    local kind = ObjectKind(unit, icon)
    if kind == "plain" or kind == "others" then
        if ns.db.bobber and IsBobber(unit) then return "bobber" end
        local name = UnitName(unit)
        if not issecretvalue(name) and type(name) == "string" and ns.NodeKind(name) == "treasure" then return "chests" end
    end
    return kind
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
        local hide = ns.db.combatHide and UnitAffectingCombat("player") or ns.db.instanceHide and IsInInstance()
        -- A gathered node loses its gathering icon as it goes: its finish plays out in its own look.
        local gathered = sparkles[namePlate]
        if gathered and gathered.harvested then
            if ns.db[gathered.kind] and not hide then return end
            return HideSparkles(namePlate, true)
        end
        local kind = SparkleKind(unit, unitFrame.SoftTargetFrame.Icon)
        -- The game shows the icon only on the interact target: a herb or ore that stops
        -- being it fades out, not taken for an other object.
        if kind == "others" and known[namePlate] then return HideSparkles(namePlate, true) end
        if kind ~= "others" then known[namePlate] = kind end
        if ns.db[kind] and not hide then ShowSparkles(namePlate, kind, unit) else HideSparkles(namePlate, true) end
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
hooksecurefunc(NamePlateDriverFrame, "OnNamePlateAdded", function(_, unit)
    if Idle() then
        wipe(known)
    elseif unit:find("^nameplate%d+$") then
        local namePlate = C_NamePlate.GetNamePlateForUnit(unit)
        if namePlate then known[namePlate] = nil end -- a new object on it
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
ns.sparkles, ns.hidden, ns.leaving = sparkles, hidden, leaving
ns.HARVESTS, ns.SparklePreviews, ns.SparkleAnimate, ns.ResetHarvest = HARVESTS, previews, Animate, ResetHarvest
ns.ApplyColor, ns.NewSparkle, ns.NewSparkles = ApplyColor, NewSparkle, NewSparkles
ns.ShowSparkles, ns.HideSparkles, ns.Setup, ns.UpdateAll = ShowSparkles, HideSparkles, Setup, UpdateAll
ns.KINDS, ns.SPARKLE_KEYS, ns.SPARKLE_STYLES, ns.StyleFits = KINDS, KEYS, STYLES, StyleFits
ns.CarryOverLooks, ns.SparkleLook, ns.SparkleRGB, ns.SparkleColors = CarryOverLooks, Look, RGB, Colors
-- Is a Setup waiting for the end of combat?
function ns.SetupPending() return pendingSetup end
