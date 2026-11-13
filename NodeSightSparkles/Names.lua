-- NodeSight Sparkles' name lists: which objects are chests, the English name
-- of a herb or ore on any client (for the rare glow), and the skill each herb
-- and ore needs (for the gray when your skill is too low). Other clients' names
-- are in Locales.
--
-- In order: NodeKind, TooHard.

local _, ns = ...

local ipairs = ipairs

-- Herbs are matched by the end of the name, ore by "vein" or "deposit" (or ORE_OTHER).
-- Names with digits, ":" or "/" are quest progress ("Peacebloom 3/8"), not nodes.
local HERBS = {
    "silverleaf", "mageroyal", "peacebloom", "earthroot", "briarthorn", "swiftthistle", "bruiseweed",
    "steelbloom", "kingsblood", "liferoot", "khadgar's whisker", "grave moss", "fadeleaf", "wintersbite",
    "stranglekelp", "goldthorn", "firebloom", "purple lotus", "arthas' tears", "sungrass", "blindweed",
    "ghost mushroom", "gromsblood", "dreamfoil", "golden sansam", "mountain silversage", "plaguebloom",
    "icecap", "black lotus", "hive thistle", "demonsage", "death lotus", "marefoil", "stranglevine",
    "frilled lichen", "rosecap", "doom weed", "gloom weed", "moonroot", "nightmare moss", "dreamroot", "star lotus",
}
local ORE_OTHER = { "chunk of amber", "obsidian chunk", "moonstone formation" } -- no vein or deposit
-- Chests, by the end of the name (crates and sacks are quest things too).
local TREASURE = { "chest", "footlocker", "strongbox", "lockbox", "coffer" }
local MAX_WORDS = 5

-- Lowercase, with curly apostrophes made straight.
local function Plain(name)
    return (name:lower():gsub("\226\128\153", "'"))
end

-- This client's names (each Locales\*.lua loads only on its client), in one lookup.
local LOCALE = ns.LOCALE
local ENGLISH = {}
if LOCALE then
    for _, kind in ipairs({ "HERBS", "ITEM_HERBS", "ORE", "TREASURE" }) do
        for name, english in pairs(LOCALE[kind] or {}) do ENGLISH[name] = english end
    end
end

-- Plain() of the English name, if this client's name is known.
local function Key(name)
    local plain = Plain(name)
    return ENGLISH[plain] or plain
end

local function EndsWith(text, ending)
    return text:sub(-#ending) == ending
end

-- "herbs", "ore", "treasure" or nil.
local function NodeKind(name)
    name = Key(name)
    if name:find("[%d:/]") then return nil end
    local words = 0
    for _ in name:gmatch("%S+") do words = words + 1 end
    if words > MAX_WORDS then return nil end
    if EndsWith(name, " vein") or EndsWith(name, " deposit") then return "ore" end
    for _, other in ipairs(ORE_OTHER) do
        if EndsWith(name, other) then return "ore" end
    end
    for _, herb in ipairs(HERBS) do
        if EndsWith(name, herb) then return "herbs" end
    end
    for _, ending in ipairs(TREASURE) do
        if EndsWith(name, ending) then return "treasure" end
    end
    -- This client's chests, by the end of any word ("Truhe der Horde").
    if LOCALE and LOCALE.TREASURE_ENDINGS then
        for word in name:gmatch("%S+") do
            for _, ending in ipairs(LOCALE.TREASURE_ENDINGS) do
                if EndsWith(word, ending) then return "treasure" end
            end
        end
    end
    return nil
end

-- Skill needed per node (Wowhead). Unlisted nodes are never too hard.
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
}
local skills = {} -- cached skill levels (false = unknown)
local has, hasAt = {}, {} -- whether you have each kind's profession, and when a "no" was read
local RECHECK = 5 -- seconds a "no" is kept (the skill list may still be loading at login)

-- Herbalism or Mining skill including bonuses, or nil. Retail has no such call.
local function GatherSkill(kind)
    local info = C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID and C_SkillInfo.GetSkillLineInfoByID(SKILL_LINE[kind])
    if issecretvalue(info) then
        has[kind] = true
        return nil
    end
    if not info then
        has[kind], hasAt[kind] = false, GetTime()
        return nil
    end
    has[kind] = true
    local rank, bonus = info.rank, info.modifier
    if issecretvalue(rank) or issecretvalue(bonus) or not rank then return nil end
    return rank + (bonus or 0)
end

-- true if the node needs more skill than you have.
local function TooHard(name, kind)
    local need = NEEDED[kind] and NEEDED[kind][Key(name)]
    if not need then return false end
    if skills[kind] == nil then skills[kind] = GatherSkill(kind) or false end
    local skill = skills[kind]
    return skill ~= false and need > skill
end

-- Used by Sparkles.lua and the main file.
-- Whether you have the profession that gathers a kind (Herbalism, Mining, Skinning): false
-- only when the game says you don't; true for other kinds, or when it can't be read (Retail).
-- Read with the skill (one call for both), kept until the skills change.
local SKINNING_LINE = 393
local function HasProfession(kind)
    local get = C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID
    if not (get and (SKILL_LINE[kind] or kind == "skinning")) then return true end
    if has[kind] ~= nil and (has[kind] or GetTime() - hasAt[kind] < RECHECK) then return has[kind] end
    if SKILL_LINE[kind] then
        skills[kind] = GatherSkill(kind) or false
    else
        local info = get(SKINNING_LINE)
        if issecretvalue(info) or info ~= nil then has[kind] = true else has[kind], hasAt[kind] = false, GetTime() end
    end
    return has[kind] ~= false
end

ns.HasProfession, ns.hasProfession = HasProfession, has
ns.Plain, ns.NodeKind, ns.NodeKey = Plain, NodeKind, Key
ns.skills, ns.TooHard = skills, TooHard
