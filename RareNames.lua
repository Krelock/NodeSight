-- Rare names in the client's language. RARES and FRIENDLY (Names.lua) are keyed by NPC ID, so
-- NodeSight asks the client for each rare's name and keeps the answers per language in
-- NodeSightDB. From the next login on they count at once, and only names still missing are
-- asked, until a new game build asks for all of them again.
--
-- In order: lookup, asking the client, events.

local _, ns = ...

local pairs = pairs

local ID = {} -- Plain() of a rare's name in the client's language -> its NPC ID

-- The NPC ID of a rare by Plain() of its name, or nil.
function ns.RareID(plain)
    return ID[plain]
end

if not ns.RARES then return end

---------------------------------------------------------------------------
-- Asking the client
---------------------------------------------------------------------------

local PER_FRAME = 10 -- names asked per frame
local RETRY = 2 -- seconds before asking again for names the client has not loaded yet
local TRIES = 5 -- then give up on that NPC until the next login

local LOCALE = GetLocale()
local Plain = ns.Plain
local queue, later = {}, {} -- { id, tries } to ask now, and to ask again after RETRY
local waited = 0 -- seconds since the last pass of the queue ended
local saved -- NodeSightDB.rareNames[LOCALE]: NPC ID -> name, and the game build they are from

-- The client's name for an NPC, or nil while it has not loaded the NPC yet.
local function Ask(id)
    local data = C_TooltipInfo.GetHyperlink("unit:Creature-0-0-0-0-" .. id .. "-0")
    if not data or issecretvalue(data) or type(data.lines) ~= "table" then return nil end
    local line = data.lines[1]
    local name = line and line.leftText
    if not name or issecretvalue(name) or name == "" or name == UNKNOWNOBJECT or name == UNKNOWN then return nil end
    return name
end

local frame = CreateFrame("Frame")

local function Step(_, elapsed)
    for _ = 1, PER_FRAME do
        local entry = queue[#queue]
        if not entry then break end
        queue[#queue] = nil
        local name = Ask(entry.id)
        if name then
            ID[Plain(name)] = entry.id
            saved[entry.id] = name
        elseif entry.tries < TRIES then
            entry.tries = entry.tries + 1
            later[#later + 1] = entry
        end
    end
    if queue[1] then return end
    if not later[1] then
        frame:SetScript("OnUpdate", nil)
        return
    end
    waited = waited + elapsed
    if waited >= RETRY then queue, later, waited = later, {}, 0 end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    NodeSightDB = NodeSightDB or {}
    if NodeSightDB.rares == false then return end -- rares off: asked at the next login after turning them on
    NodeSightDB.rareNames = NodeSightDB.rareNames or {}
    NodeSightDB.rareNames[LOCALE] = NodeSightDB.rareNames[LOCALE] or {}
    saved = NodeSightDB.rareNames[LOCALE]
    local build = select(2, GetBuildInfo())
    local sameBuild = saved.build == build
    saved.build = build
    -- Saved names count at once. In the same build only missing ones are asked, after a new build all.
    for id in pairs(ns.RARES) do
        if saved[id] then ID[Plain(saved[id])] = id end
        if not (sameBuild and saved[id]) then queue[#queue + 1] = { id = id, tries = 1 } end
    end
    if queue[1] then self:SetScript("OnUpdate", Step) end
end)
