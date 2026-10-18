-- NodeSight's name lists. A minimap dot only gives its name, so the kind of
-- node, its icon and the skill it needs all come from the name. English only;
-- other names are learned by gathering (Learn in NodeSight.lua).
--
-- In order: NodeKind, NodeIcon, TooHard.

local _, ns = ...

local ipairs = ipairs

-- Herbs are matched by the end of the name, ore by "vein" or "deposit". Names
-- with digits, ":" or "/" are quest progress ("Peacebloom 3/8"), not nodes.
local HERB_OTHER = { "doom weed", "gloom weed", "moonroot" } -- no item icon: plain herb symbol
-- Find Treasure chests, by the end of the name. Other treasure is learned when opened.
local TREASURE = { "chest", "footlocker", "strongbox", "lockbox", "coffer", icon = "Interface\\Icons\\racial_dwarf_findtreasure" }
-- Rare beasts (Wowhead's WoW Forever data) and their zone (GetRealZoneText; "a/b"
-- for two, true if unknown). They only count in their zone, since a hunter's pet
-- keeps the name of the rare it was tamed from.
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

-- Lowercase, with curly apostrophes made straight.
local function Plain(name)
    return (name:lower():gsub("\226\128\153", "'"))
end

local function EndsWith(text, ending)
    return text:sub(-#ending) == ending
end

-- Item icon by part of the node name (from Wowhead). First match wins, so
-- "dark iron" is listed before "iron deposit".
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

-- "herbs", "ore", "treasure", "leyline" or nil.
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
    if name == "leyline" or EndsWith(name, "leyline") then return "leyline" end
    return nil
end

local function NodeIcon(name)
    name = Plain(name)
    for pass = 1, 2 do -- herbs, then ore
        for _, entry in ipairs(pass == 1 and HERB_ICONS or ORE_ICONS) do
            if name:find(entry[1], 1, true) then return "Interface\\Icons\\" .. entry[2] end
        end
    end
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
    treasure = {},
    leyline = {}, -- (nor does a leyline)
    rares = {},
}
local TOO_HARD = { 1, 0.2, 0.2 } -- red tint for nodes above your skill
local skills = {} -- cached skill levels (false = unknown)
local professions = {} -- localized profession names

-- Herbalism or Mining skill including bonuses, or nil.
local function GatherSkill(kind)
    local info = C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID(SKILL_LINE[kind])
    if not info or issecretvalue(info) then return nil end
    local rank, bonus = info.rank, info.modifier
    if issecretvalue(rank) or issecretvalue(bonus) or not rank then return nil end
    local name = info.name
    if not issecretvalue(name) then professions[kind] = name end
    return rank + (bonus or 0)
end

-- true if the node needs more skill than you have, plus the skill needed.
local function TooHard(name, kind)
    local need = NEEDED[kind][Plain(name)]
    if not need then return false end
    if skills[kind] == nil then skills[kind] = GatherSkill(kind) or false end
    local skill = skills[kind]
    return skill ~= false and need > skill, need
end

-- Used by NodeSight.lua.
ns.Plain, ns.NodeKind, ns.NodeIcon = Plain, NodeKind, NodeIcon
ns.TREASURE, ns.RARES = TREASURE, RARES
ns.TOO_HARD, ns.skills, ns.professions, ns.TooHard = TOO_HARD, skills, professions, TooHard
