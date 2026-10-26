-- NodeSight's name lists. A minimap dot only gives its name, so the kind of
-- node, its icon and the skill it needs all come from the name. English, and for
-- other clients the names in Locales (German); the rest are learned by gathering
-- (Learn in NodeSight.lua).
--
-- In order: NodeKind, NodeIcon, TooHard, NodeSkill.

local _, ns = ...

local ipairs = ipairs

-- Herbs are matched by the end of the name, ore by "vein" or "deposit" (or ORE_OTHER).
-- Names with digits, ":" or "/" are quest progress ("Peacebloom 3/8"), not nodes.
local HERB_OTHER = { "doom weed", "gloom weed", "moonroot" } -- no item icon: plain herb symbol
local ORE_OTHER = { "chunk of amber", "obsidian chunk", "moonstone formation" } -- no vein or deposit
-- Find Treasure chests, by the end of the name (crates and sacks are quest things too).
local TREASURE = { "chest", "footlocker", "strongbox", "lockbox", "coffer", icon = "Interface\\Icons\\racial_dwarf_findtreasure" }
-- Rare beasts and humanoids (Wowhead's WoW Forever data) and their zone
-- (GetRealZoneText; "a/b" for two, true if unknown). They only count in their
-- zone: a hunter's pet keeps the name of the rare it was tamed from, and some
-- ordinary NPCs elsewhere share a rare's name.
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
    -- Humanoids
    ["accursed slitherblade"] = "Desolace", ["achellios the banished"] = "Thousand Needles",
    ["aean swiftriver"] = "The Barrens", ["akubar the seer"] = "Blasted Lands",
    ["apothecary falthis"] = "Ashenvale", ["bannok grimaxe"] = "Blackrock Spire",
    ["bloodroar the stalker"] = "Feralas", ["boahn"] = true, ["boss galgosh"] = "Loch Modan",
    ["brack"] = "Westfall", ["brainwashed noble"] = true, ["brokespear"] = "The Barrens",
    ["brother ravenoak"] = "Stonetalon Mountains", ["bruegal ironknuckle"] = "The Stockade",
    ["burgle eye"] = "Dustwallow Marsh", ["captain flat tusk"] = "Durotar",
    ["captain gerogg hammertoe"] = "The Barrens", ["carnivous the breaker"] = "Darkshore",
    ["cursed centaur"] = "Desolace", ["cyclok the mad"] = "Tanaris",
    ["dalaran spellscribe"] = "Silverpine Forest", ["darbel montrose"] = "Arathi Highlands",
    ["dark iron ambassador"] = "Gnomeregan", ["darkslayer mordenthal"] = "Ashenvale",
    ["deathspeaker selendre"] = "Eastern Plaguelands", ["deeb"] = "Tirisfal Glades",
    ["desert mirage"] = "The Barrens", ["diamond head"] = "Feralas", ["digger flameforge"] = "The Barrens",
    ["digmaster shovelphlange"] = true, ["dragonmaw battlemaster"] = "Wetlands",
    ["dreadscorn"] = "Blasted Lands", ["dro'zem the blasphemous"] = "Redridge Mountains",
    ["duggan wildhammer"] = "Eastern Plaguelands", ["dustwind eggtender"] = "Durotar",
    ["dustwraith"] = "Zul'Farrak", ["earthcaller halmgar"] = "Razorfen Kraul",
    ["edan the howler"] = "Dun Morogh", ["elder finseer"] = "Elwynn Forest",
    ["elder mystic razorsnout"] = "The Barrens", ["emogg the crusher"] = "Loch Modan",
    ["enforcer emilgund"] = "Mulgore", ["engineer whirleygig"] = "The Barrens",
    ["farmer solliden"] = "Tirisfal Glades", ["fedfennel"] = "Elwynn Forest",
    ["felweaver scornn"] = "Durotar", ["fenros"] = "Duskwood", ["fingat"] = "Swamp of Sorrows",
    ["firecaller radison"] = "Darkshore", ["flagglemurk the cruel"] = "Darkshore",
    ["flamebringer kelris"] = "Searing Gorge", ["foreman grills"] = "The Barrens",
    ["foreman jerris"] = "Western Plaguelands", ["foreman marcrid"] = "Western Plaguelands",
    ["foreman rigger"] = "Stonetalon Mountains", ["foulbelly"] = "Arathi Highlands",
    ["fury shelda"] = "Teldrassil", ["galemender delanea"] = "Zephras Isle", ["galenges"] = "Searing Gorge",
    ["garneg charskull"] = "Wetlands", ["gatekeeper rageroar"] = "Azshara", ["gefell"] = "Shadowfang Keep",
    ["gemela"] = "Shadowfang Keep", ["general fangferror"] = "Azshara", ["geolord mottle"] = "Durotar",
    ["geopriest gukk'rok"] = "The Barrens", ["ghok bashguud"] = "Blackrock Spire",
    ["gibblesnik"] = "Thousand Needles", ["gibblewilt"] = "Dun Morogh", ["gilmorian"] = "Swamp of Sorrows",
    ["gluggle"] = "Stranglethorn Vale", ["gnawbone"] = "Wetlands", ["gorgon'och"] = "Burning Steppes",
    ["gravis slipknot"] = "Alterac Mountains", ["great father arctikus"] = "Dun Morogh",
    ["grimmaw"] = "Teldrassil", ["grizlak"] = "Loch Modan", ["grizzle snowpaw"] = "Winterspring",
    ["gruff swiftbite"] = "Elwynn Forest", ["gruklash"] = "Burning Steppes",
    ["hagg taurenbane"] = "The Barrens", ["hahk'zor"] = "Burning Steppes", ["hammerspine"] = "Dun Morogh",
    ["hannah bladeleaf"] = "The Barrens", ["harb foulmountain"] = "Thousand Needles",
    ["heggin stonewhisker"] = "The Barrens", ["high general abbendis"] = "Eastern Plaguelands",
    ["high priestess hai'watna"] = "Stranglethorn Vale", ["highlord mastrogonde"] = "Searing Gorge",
    ["jalinde summerdrake"] = "The Hinterlands", ["jed runewatcher"] = "Blackrock Spire",
    ["jimmy the bleeder"] = "Alterac Mountains", ["jin'zallah the sandbringer"] = "Tanaris",
    ["kazon"] = "Redridge Mountains", ["kovork"] = "Arathi Highlands", ["kregg keelhaul"] = "Tanaris",
    ["lady sesspira"] = "Azshara", ["lady szallah"] = "Feralas", ["lady vespia"] = "Ashenvale",
    ["lady vespira"] = "Darkshore", ["lady zephris"] = "Hillsbrad Foothills",
    ["lieutenant skarresh"] = "Searing Gorge", ["lo'grosh"] = "Alterac Mountains",
    ["lord angler"] = "Dustwallow Marsh", ["lord gazzran"] = "Searing Gorge",
    ["lord maldazzar"] = "Western Plaguelands", ["lord sakrasis"] = "Stranglethorn Vale",
    ["lord sinslayer"] = "Darkshore", ["lost one chieftain"] = "Swamp of Sorrows",
    ["lost one cook"] = "Swamp of Sorrows", ["lyn the ignored"] = "Alterac Mountains",
    ["ma'ruk wyrmscale"] = "Wetlands", ["magister hawkhelm"] = "Azshara", ["magosh"] = "Loch Modan",
    ["magronos the unyielding"] = "Blasted Lands", ["malgin barleybrew"] = "The Barrens",
    ["marcus bel"] = "The Barrens", ["marisa du'paige"] = true, ["master digger"] = "Westfall",
    ["mezzir the howler"] = "Winterspring", ["miner johnson"] = "The Deadmines",
    ["mith'rethis the enchanter"] = "The Hinterlands", ["mojo the twisted"] = "Blasted Lands",
    ["molok the crusher"] = "Arathi Highlands", ["morgaine the sly"] = "Elwynn Forest",
    ["mosh'ogg butcher"] = "Stranglethorn Vale", ["muad"] = "Tirisfal Glades", ["mugglefin"] = "Ashenvale",
    ["narg the taskmaster"] = "Elwynn Forest", ["nefaru"] = "Duskwood",
    ["nimar the slayer"] = "Arathi Highlands", ["oakpaw"] = "Ashenvale", ["omgorn the lost"] = "Tanaris",
    ["overseer myoleth"] = "Mount Hyjal", ["par'kourc"] = "Redridge Mountains",
    ["prince nazjak"] = "Arathi Highlands", ["ragepaw"] = "Felwood",
    ["ranger lord hawkspear"] = "Eastern Plaguelands", ["razortalon"] = "The Hinterlands",
    ["retherokk the berserker"] = "The Hinterlands", ["ribchaser"] = "Redridge Mountains",
    ["ro'bark"] = "Hillsbrad Foothills", ["rocklance"] = "The Barrens",
    ["rohh the silent"] = "Redridge Mountains", ["roloch"] = "Stranglethorn Vale",
    ["rorgish jowl"] = "Ashenvale", ["ruul onestone"] = "Arathi Highlands",
    ["sandarr dunereaver"] = "Zul'Farrak", ["scargil"] = "Hillsbrad Foothills",
    ["scarlet captain"] = "Eastern Plaguelands",
    ["scarlet executioner"] = "Scarlet Enclave/Western Plaguelands",
    ["scarlet high clerist"] = "Western Plaguelands", ["scarlet interrogator"] = "Western Plaguelands",
    ["scarlet judge"] = "Western Plaguelands", ["scarlet smith"] = "Western Plaguelands",
    ["scarshield quartermaster"] = true, ["sentinel amarassan"] = "Stonetalon Mountains",
    ["sergeant brashclaw"] = "Westfall", ["setis"] = "Silithus", ["shadowforge commander"] = "Badlands",
    ["singer"] = "Arathi Highlands", ["sister hatelash"] = "Mulgore", ["sister rathtalon"] = "The Barrens",
    ["sister riven"] = "Stonetalon Mountains", ["skarr the unbreakable"] = "Feralas",
    ["skhowl"] = "Alterac Mountains", ["slark"] = "Westfall", ["slave master blackheart"] = "Searing Gorge",
    ["snagglespear"] = "Mulgore", ["snarlsnout"] = "Mulgore", ["spirestone battle lord"] = "Blackrock Spire",
    ["spirestone butcher"] = "Blackrock Spire", ["spirestone lord magus"] = "Blackrock Spire",
    ["squiddic"] = "Redridge Mountains", ["stonearm"] = "The Barrens", ["stormherald ukta"] = "Mulgore",
    ["swinegart spearhide"] = "The Barrens", ["tamra stormpike"] = "Hillsbrad Foothills",
    ["taskmaster whipfang"] = "Stonetalon Mountains", ["tel'daeor the stormspeaker"] = "Zephras Isle",
    ["terrowulf packlord"] = "Ashenvale", ["thauris balgarr"] = "Burning Steppes", ["the behemoth"] = true,
    ["the snatcher"] = "Westfall", ["thora feathermoon"] = "The Barrens", ["thornstarter igleg"] = "Mulgore",
    ["thuros lightfingers"] = "Elwynn Forest", ["twilight lord everun"] = "Silithus",
    ["urok doomhowl"] = "Blackrock Spire", ["uruson"] = "Teldrassil", ["verifonix"] = "Stranglethorn Vale",
    ["warleader krazzilak"] = "Tanaris", ["warlord kolkanis"] = "Durotar",
    ["warlord thresh'jin"] = "Eastern Plaguelands", ["watch commander zalaphil"] = "Durotar",
    ["witherheart the stalker"] = "The Hinterlands", ["zalas witherbark"] = "Arathi Highlands",
    ["zerillis"] = "Zul'Farrak", ["zul'arek hatefowler"] = "The Hinterlands",
    ["zul'brin warpbranch"] = "Eastern Plaguelands",
}
-- Rares friendly to one faction: no symbol for that faction.
local FRIENDLY = {
    ["aean swiftriver"] = "Alliance", ["dalaran spellscribe"] = "Alliance",
    ["darkslayer mordenthal"] = "Horde", ["duggan wildhammer"] = "Alliance",
    ["hannah bladeleaf"] = "Alliance", ["heggin stonewhisker"] = "Alliance",
    ["jalinde summerdrake"] = "Alliance", ["marcus bel"] = "Alliance",
    ["ranger lord hawkspear"] = "Alliance", ["sentinel amarassan"] = "Alliance",
    ["thora feathermoon"] = "Alliance",
}
local MAX_WORDS = 5

-- Map and instance IDs of the home zones (Zones.lua), so rares match on any client language.
local ZONE_IDS = ns.ZONE_IDS or {}
local PARENTS = 3 -- parent maps to check, for sub-maps of a zone such as caves (this client has none so far)

-- true if you are in the zone: by map (or a parent map) or by instance ID.
local function InZoneID(zone)
    if zone.instances then
        local instanceID = select(8, GetInstanceInfo())
        return not issecretvalue(instanceID) and tContains(zone.instances, instanceID)
    end
    local map = C_Map.GetBestMapForUnit("player")
    for _ = 0, PARENTS do
        if not map or issecretvalue(map) or map == 0 then return false end
        if tContains(zone.maps, map) then return true end
        local info = C_Map.GetMapInfo(map)
        map = info and not issecretvalue(info) and info.parentMapID
    end
    return false
end

-- true if you are in a rare's home zone ("a/b" for two). Zones without IDs go by
-- their English name, which only matches on English clients.
local function InZone(home)
    for name in home:gmatch("[^/]+") do
        local zone = ZONE_IDS[name]
        if zone then
            if InZoneID(zone) then return true end
        else
            local here = GetRealZoneText()
            if not issecretvalue(here) and here == name then return true end
        end
    end
    return false
end

-- Lowercase, with curly apostrophes made straight.
local function Plain(name)
    return (name:lower():gsub("\226\128\153", "'"))
end

-- This client's names (each Locales\*.lua loads only on its client), in one lookup.
local LOCALE = ns.LOCALE
local ENGLISH = {}
if LOCALE then
    for _, kind in ipairs({ "HERBS", "ITEM_HERBS", "ORE", "OTHER", "TREASURE" }) do
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
    { "chunk of amber", "trade_archaeology_insect-in-amber" }, { "small obsidian", "inv_misc_stonetablet_01" },
    { "large obsidian", "inv_stone_15" }, { "moonstone", "inv_misc_apexis_crystal" },
}

-- "herbs", "ore", "treasure", "leyline", "convergence" or nil.
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
    for _, entry in ipairs(HERB_ICONS) do
        if EndsWith(name, entry[1]) then return "herbs" end
    end
    for _, other in ipairs(HERB_OTHER) do
        if EndsWith(name, other) then return "herbs" end
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
    if EndsWith(name, "leyline") or EndsWith(name, "ley line") then return "leyline" end
    if EndsWith(name, "convergence") then return "convergence" end
    return nil
end

local function NodeIcon(name)
    name = Key(name)
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

-- true if the node needs more skill than you have.
local function TooHard(name, kind)
    local need = NEEDED[kind] and NEEDED[kind][Key(name)]
    if not need then return false end
    if skills[kind] == nil then skills[kind] = GatherSkill(kind) or false end
    local skill = skills[kind]
    return skill ~= false and need > skill
end

-- What a herb or ore needs (1 for one known by name but not listed, nil for one only
-- learned by gathering and for other kinds), and your skill (false if unknown).
local function NodeSkill(name, kind)
    local list = NEEDED[kind]
    local need = list and (list[Key(name)] or (NodeKind(name) == kind and 1))
    if not need then return nil end
    if skills[kind] == nil then skills[kind] = GatherSkill(kind) or false end
    return need, skills[kind]
end

-- Used by NodeSight.lua.
ns.Plain, ns.NodeKind, ns.NodeIcon = Plain, NodeKind, NodeIcon
ns.TREASURE, ns.RARES, ns.FRIENDLY, ns.InZone = TREASURE, RARES, FRIENDLY, InZone
ns.TOO_HARD, ns.skills, ns.professions, ns.TooHard, ns.NodeSkill = TOO_HARD, skills, professions, TooHard, NodeSkill
