-- NodeSight's name lists. A minimap dot only gives its name, so the kind of
-- node, its icon and the skill it needs all come from the name: English, and for
-- other clients the names in Locales; the rest are learned by gathering (Learn in
-- NodeSight.lua). Rares are listed by NPC ID: RareNames.lua asks the client for
-- their names, and Zones.lua holds the IDs of their home zones.
--
-- In order: InZone, NodeKind, NodeIcon, TooHard, NodeSkill.

local _, ns = ...

local ipairs = ipairs

-- Herbs are matched by the end of the name, ore by "vein" or "deposit" (or ORE_OTHER).
-- Names with digits, ":" or "/" are quest progress ("Peacebloom 3/8"), not nodes.
local HERB_OTHER = { "doom weed", "gloom weed", "moonroot" } -- no item icon: plain herb symbol
local ORE_OTHER = { "chunk of amber", "obsidian chunk", "moonstone formation" } -- no vein or deposit
-- Find Treasure chests, by the end of the name (crates and sacks are quest things too).
local TREASURE = { "chest", "footlocker", "strongbox", "lockbox", "coffer", icon = "Interface\\Icons\\racial_dwarf_findtreasure" }
-- Rare beasts and humanoids by NPC ID (Wowhead's WoW Forever data), with their name, and
-- their zone (English name, see Zones.lua; "a/b" for two, true if unknown). RareNames.lua
-- asks the client for their names. They only count in their zone: a hunter's pet keeps the
-- name of the rare it was tamed from, and some ordinary NPCs elsewhere share a rare's name.
local RARES = {
    [208843] = true, -- Abominable Snowman
    [6648] = "Azshara", -- Antilos
    [5347] = "Feralas", -- Antilus the Soarer
    [14222] = "Alterac Mountains", -- Araga
    [5349] = "Feralas", -- Arash-ethis
    [228814] = "Winterspring", -- Arcterris
    [5834] = "The Barrens", -- Azzere the Skyblade
    [256830] = true, -- Bannerwing Survivor
    [2753] = "Badlands", -- Barnabus
    [5796] = true, -- Ben
    [14280] = "Hillsbrad Foothills", -- Big Samras
    [1130] = "Dun Morogh", -- Bjarn
    [271080] = "Tirisfal Glades", -- Blightsculler
    [4425] = "Razorfen Kraul", -- Blind Hunter
    [2850] = "Badlands", -- Broken Tooth
    [5827] = "The Barrens", -- Brontus
    [211965] = "Wetlands", -- Carrodin
    [616] = "Redridge Mountains", -- Chatter
    [8301] = "Blasted Lands", -- Clack the Reaver
    [274300] = "Tirisfal Glades", -- Coldrasp
    [14223] = "Alterac Mountains", -- Cranky Benj
    [14279] = "Hillsbrad Foothills", -- Creepthess
    [10376] = "Blackrock Spire", -- Crystal Fang
    [4380] = "Dustwallow Marsh", -- Darkmist Widow
    [14232] = "Dustwallow Marsh", -- Dart
    [5823] = "Durotar", -- Death Flayer
    [14339] = "Felwood", -- Death Howl
    [8302] = "Blasted Lands", -- Deatheye
    [10077] = "Burning Steppes", -- Deathmaw
    [250936] = "Zephras Isle", -- Den'dralass
    [5865] = "The Barrens", -- Dishu
    [221333] = "The Hinterlands", -- Doomkin
    [14430] = "Teldrassil", -- Duskstalker
    [256492] = "Zephras Isle", -- Fernfeather
    [3056] = "Mulgore/Thunder Bluff", -- Ghost Howl
    [276111] = "Dun Morogh", -- Ghostfang
    [14228] = "Desolace", -- Giggler
    [12431] = "Silverpine Forest", -- Gorefang
    [8207] = "Tanaris", -- Greater Firebird
    [14472] = "Silithus", -- Gretheer
    [14477] = "Silithus", -- Grubthor
    [6583] = "Un'Goro Crater", -- Gruff
    [8303] = "Blasted Lands", -- Grunter
    [14234] = "Dustwallow Marsh", -- Hayoc
    [5934] = "Thousand Needles", -- Heartrazor
    [14227] = "Desolace", -- Hissperak
    [5828] = "The Barrens", -- Humar the Pridelord
    [8213] = "The Hinterlands", -- Ironback
    [5935] = "Thousand Needles", -- Ironeye the Invincible
    [208812] = "Dun Morogh", -- Jorul
    [210107] = "Loch Modan", -- Kackle
    [6584] = "Un'Goro Crater", -- King Mosh
    [211951] = "Hillsbrad Foothills", -- Koartul
    [14476] = "Silithus", -- Krellack
    [12433] = "Silverpine Forest", -- Krethis Shadowspinner
    [14491] = "Stranglethorn Vale", -- Kurmokk
    [2476] = "Loch Modan", -- Large Loch Crocolisk
    [1112] = "Wetlands", -- Leech Widow
    [14268] = "Loch Modan", -- Lord Condar
    [521] = "Duskwood", -- Lupos
    [276189] = "Elwynn Forest", -- Matriarch Bristlefur
    [3068] = "Mulgore", -- Mazzranache
    [10644] = "Ashenvale", -- Mist Howler
    [205382] = "Mulgore", -- Mokwa
    [14344] = "Felwood", -- Mongress
    [209928] = "Teldrassil", -- Mowgh
    [8208] = "Tanaris", -- Murderous Blisterpaw
    [259388] = "Zephras Isle", -- Mystmane
    [574] = "Duskwood", -- Naraxis
    [217836] = "Arathi Highlands", -- Needletooth
    [276101] = "Teldrassil", -- Nightscreech
    [8211] = "The Hinterlands", -- Old Cliff Jumper
    [5352] = "Feralas", -- Old Grizzlegut
    [261662] = true, -- Old Ironfang
    [263935] = true, -- Old Rusthowl
    [250352] = true, -- Old Thornpaw
    [12432] = "Silverpine Forest", -- Old Vicejaw
    [14343] = "Felwood", -- Olm the Wise
    [14237] = "Dustwallow Marsh", -- Oozeworm
    [4015] = "Stonetalon Mountains", -- Pridewing Patriarch
    [10200] = "Winterspring", -- Rak'shiri
    [208124] = "Durotar", -- Raluk
    [8300] = "Blasted Lands", -- Ravage
    [6581] = "Un'Goro Crater", -- Ravasaur Matriarch
    [1140] = "Wetlands", -- Razormaw Matriarch
    [8277] = "Searing Gorge", -- Rekk'tilac
    [10357] = "Tirisfal Glades", -- Ressan the Needler
    [14490] = "Stranglethorn Vale", -- Rippa
    [14233] = "Dustwallow Marsh", -- Ripscale
    [1552] = "Stranglethorn Vale", -- Scale Belly
    [13896] = "Azshara", -- Scalebeard
    [244188] = "Azshara", -- Scalebeard
    [3581] = "Stormwind City", -- Sewer Beast
    [2175] = "Darkshore", -- Shadowclaw
    [276198] = "Durotar", -- Shal'ma
    [14266] = "Loch Modan", -- Shanda the Spinner
    [255887] = "Zephras Isle", -- Slydris
    [259394] = "Zephras Isle", -- Snapbeak the Quick
    [5356] = "Feralas", -- Snarler
    [5829] = "The Barrens", -- Snort the Heckler
    [5928] = "Stonetalon Mountains", -- Sorrow Wing
    [8299] = "Blasted Lands", -- Spiteflayer
    [10359] = "Tirisfal Glades", -- Sri'skulk
    [2172] = "Darkshore", -- Strider Clutchmother
    [5831] = "The Barrens", -- Swiftmane
    [5842] = "The Barrens", -- Takk the Leaper
    [8660] = "Azshara", -- The Evalcharr
    [5807] = "Mulgore", -- The Rake
    [11497] = "Feralas", -- The Razza
    [5832] = "The Barrens", -- Thunderstomp
    [1132] = "Dun Morogh", -- Timber
    [6585] = "Un'Goro Crater", -- Uhk'loc
    [12037] = "Ashenvale", -- Ursol'lok
    [5937] = "Thousand Needles", -- Vile Sting
    [462] = "Westfall", -- Vultros
    [2931] = "Badlands", -- Zaricotl
    [222243] = "Tanaris", -- Zopilote
    -- Humanoids
    [14229] = "Desolace", -- Accursed Slitherblade
    [5933] = "Thousand Needles", -- Achellios the Banished
    [5797] = "The Barrens", -- Aean Swiftriver
    [8298] = "Blasted Lands", -- Akubar the Seer
    [3735] = "Ashenvale", -- Apothecary Falthis
    [9596] = "Blackrock Spire", -- Bannok Grimaxe
    [5346] = "Feralas", -- Bloodroar the Stalker
    [3672] = true, -- Boahn
    [1398] = "Loch Modan", -- Boss Galgosh
    [520] = "Westfall", -- Brack
    [596] = true, -- Brainwashed Noble
    [5838] = "The Barrens", -- Brokespear
    [5915] = "Stonetalon Mountains", -- Brother Ravenoak
    [1720] = "The Stockade", -- Bruegal Ironknuckle
    [14230] = "Dustwallow Marsh", -- Burgle Eye
    [5824] = "Durotar", -- Captain Flat Tusk
    [5851] = "The Barrens", -- Captain Gerogg Hammertoe
    [2186] = "Darkshore", -- Carnivous the Breaker
    [11688] = "Desolace", -- Cursed Centaur
    [8202] = "Tanaris", -- Cyclok the Mad
    [1920] = "Silverpine Forest", -- Dalaran Spellscribe
    [2598] = "Arathi Highlands", -- Darbel Montrose
    [6228] = "Gnomeregan", -- Dark Iron Ambassador
    [3736] = "Ashenvale", -- Darkslayer Mordenthal
    [10827] = "Eastern Plaguelands", -- Deathspeaker Selendre
    [1911] = "Tirisfal Glades", -- Deeb
    [209742] = "The Barrens", -- Desert Mirage
    [5345] = "Feralas", -- Diamond Head
    [5849] = "The Barrens", -- Digger Flameforge
    [7057] = true, -- Digmaster Shovelphlange
    [1037] = "Wetlands", -- Dragonmaw Battlemaster
    [8304] = "Blasted Lands", -- Dreadscorn
    [214456] = "Redridge Mountains", -- Dro'zem the Blasphemous
    [10817] = "Eastern Plaguelands", -- Duggan Wildhammer
    [276194] = "Durotar", -- Dustwind Eggtender
    [10081] = "Zul'Farrak", -- Dustwraith
    [4842] = "Razorfen Kraul", -- Earthcaller Halmgar
    [1137] = "Dun Morogh", -- Edan the Howler
    [276180] = "Elwynn Forest", -- Elder Finseer
    [3270] = "The Barrens", -- Elder Mystic Razorsnout
    [14267] = "Loch Modan", -- Emogg the Crusher
    [5787] = "Mulgore", -- Enforcer Emilgund
    [5836] = "The Barrens", -- Engineer Whirleygig
    [1936] = "Tirisfal Glades", -- Farmer Solliden
    [472] = "Elwynn Forest", -- Fedfennel
    [5822] = "Durotar", -- Felweaver Scornn
    [507] = "Duskwood", -- Fenros
    [14446] = "Swamp of Sorrows", -- Fingat
    [2192] = "Darkshore", -- Firecaller Radison
    [7015] = "Darkshore", -- Flagglemurk the Cruel
    [228728] = "Searing Gorge", -- Flamebringer Kelris
    [5835] = "The Barrens", -- Foreman Grills
    [1843] = "Western Plaguelands", -- Foreman Jerris
    [1844] = "Western Plaguelands", -- Foreman Marcrid
    [5931] = "Stonetalon Mountains", -- Foreman Rigger
    [2601] = "Arathi Highlands", -- Foulbelly
    [14431] = "Teldrassil", -- Fury Shelda
    [259398] = "Zephras Isle", -- Galemender Delanea
    [228970] = "Searing Gorge", -- Galenges
    [2108] = "Wetlands", -- Garneg Charskull
    [6651] = "Azshara", -- Gatekeeper Rageroar
    [236573] = "Azshara", -- Gatekeeper Rageroar
    [211764] = "Shadowfang Keep", -- Gefell
    [211765] = "Shadowfang Keep", -- Gemela
    [6650] = "Azshara", -- General Fangferror
    [5826] = "Durotar", -- Geolord Mottle
    [5863] = "The Barrens", -- Geopriest Gukk'rok
    [9718] = "Blackrock Spire", -- Ghok Bashguud
    [14427] = "Thousand Needles", -- Gibblesnik
    [8503] = "Dun Morogh", -- Gibblewilt
    [14447] = "Swamp of Sorrows", -- Gilmorian
    [14487] = "Stranglethorn Vale", -- Gluggle
    [14425] = "Wetlands", -- Gnawbone
    [9604] = "Burning Steppes", -- Gorgon'och
    [14221] = "Alterac Mountains", -- Gravis Slipknot
    [1260] = "Dun Morogh", -- Great Father Arctikus
    [14429] = "Teldrassil", -- Grimmaw
    [1425] = "Loch Modan", -- Grizlak
    [10199] = "Winterspring", -- Grizzle Snowpaw
    [100] = "Elwynn Forest", -- Gruff Swiftbite
    [8979] = "Burning Steppes", -- Gruklash
    [5859] = "The Barrens", -- Hagg Taurenbane
    [9602] = "Burning Steppes", -- Hahk'Zor
    [1119] = "Dun Morogh", -- Hammerspine
    [5799] = "The Barrens", -- Hannah Bladeleaf
    [14426] = "Thousand Needles", -- Harb Foulmountain
    [5847] = "The Barrens", -- Heggin Stonewhisker
    [10828] = "Eastern Plaguelands", -- High General Abbendis
    [243893] = "Eastern Plaguelands", -- High General Abbendis
    [11383] = "Stranglethorn Vale", -- High Priestess Hai'watna
    [8282] = "Searing Gorge", -- Highlord Mastrogonde
    [8214] = "The Hinterlands", -- Jalinde Summerdrake
    [10509] = "Blackrock Spire", -- Jed Runewatcher
    [14281] = "Alterac Mountains", -- Jimmy the Bleeder
    [8200] = "Tanaris", -- Jin'Zallah the Sandbringer
    [584] = "Redridge Mountains", -- Kazon
    [2603] = "Arathi Highlands", -- Kovork
    [8203] = "Tanaris", -- Kregg Keelhaul
    [6649] = "Azshara", -- Lady Sesspira
    [239942] = "Azshara", -- Lady Sesspira
    [5343] = "Feralas", -- Lady Szallah
    [10559] = "Ashenvale", -- Lady Vespia
    [7016] = "Darkshore", -- Lady Vespira
    [14277] = "Hillsbrad Foothills", -- Lady Zephris
    [228721] = "Searing Gorge", -- Lieutenant Skarresh
    [2453] = "Alterac Mountains", -- Lo'Grosh
    [14236] = "Dustwallow Marsh", -- Lord Angler
    [228969] = "Searing Gorge", -- Lord Gazzran
    [1848] = "Western Plaguelands", -- Lord Maldazzar
    [2541] = "Stranglethorn Vale", -- Lord Sakrasis
    [7017] = "Darkshore", -- Lord Sinslayer
    [763] = "Swamp of Sorrows", -- Lost One Chieftain
    [1106] = "Swamp of Sorrows", -- Lost One Cook
    [247032] = "Alterac Mountains", -- Lyn the Ignored
    [2090] = "Wetlands", -- Ma'ruk Wyrmscale
    [6647] = "Azshara", -- Magister Hawkhelm
    [246991] = "Azshara", -- Magister Hawkhelm
    [1399] = "Loch Modan", -- Magosh
    [8297] = "Blasted Lands", -- Magronos the Unyielding
    [5848] = "The Barrens", -- Malgin Barleybrew
    [5800] = "The Barrens", -- Marcus Bel
    [599] = true, -- Marisa du'Paige
    [1424] = "Westfall", -- Master Digger
    [10197] = "Winterspring", -- Mezzir the Howler
    [3586] = "The Deadmines", -- Miner Johnson
    [8217] = "The Hinterlands", -- Mith'rethis the Enchanter
    [8296] = "Blasted Lands", -- Mojo the Twisted
    [2604] = "Arathi Highlands", -- Molok the Crusher
    [99] = "Elwynn Forest", -- Morgaine the Sly
    [723] = "Stranglethorn Vale", -- Mosh'Ogg Butcher
    [1910] = "Tirisfal Glades", -- Muad
    [10643] = "Ashenvale", -- Mugglefin
    [79] = "Elwynn Forest", -- Narg the Taskmaster
    [534] = "Duskwood", -- Nefaru
    [2606] = "Arathi Highlands", -- Nimar the Slayer
    [10640] = "Ashenvale", -- Oakpaw
    [8201] = "Tanaris", -- Omgorn the Lost
    [260823] = "Mount Hyjal", -- Overseer Myoleth
    [208845] = "Redridge Mountains", -- Par'kourc
    [245332] = "Redridge Mountains", -- Par'kourc
    [2779] = "Arathi Highlands", -- Prince Nazjak
    [14342] = "Felwood", -- Ragepaw
    [10824] = "Eastern Plaguelands", -- Ranger Lord Hawkspear
    [8210] = "The Hinterlands", -- Razortalon
    [8216] = "The Hinterlands", -- Retherokk the Berserker
    [14271] = "Redridge Mountains", -- Ribchaser
    [14278] = "Hillsbrad Foothills", -- Ro'Bark
    [5841] = "The Barrens", -- Rocklance
    [947] = "Redridge Mountains", -- Rohh the Silent
    [14488] = "Stranglethorn Vale", -- Roloch
    [10639] = "Ashenvale", -- Rorgish Jowl
    [2602] = "Arathi Highlands", -- Ruul Onestone
    [10080] = "Zul'Farrak", -- Sandarr Dunereaver
    [14276] = "Hillsbrad Foothills", -- Scargil
    [243046] = "Eastern Plaguelands", -- Scarlet Captain
    [1841] = "Scarlet Enclave/Western Plaguelands", -- Scarlet Executioner
    [240797] = "Scarlet Enclave/Western Plaguelands", -- Scarlet Executioner
    [1839] = "Western Plaguelands", -- Scarlet High Clerist
    [1838] = "Western Plaguelands", -- Scarlet Interrogator
    [1837] = "Western Plaguelands", -- Scarlet Judge
    [1885] = "Western Plaguelands", -- Scarlet Smith
    [240792] = "Western Plaguelands", -- Scarlet Smith
    [9046] = true, -- Scarshield Quartermaster
    [5916] = "Stonetalon Mountains", -- Sentinel Amarassan
    [506] = "Westfall", -- Sergeant Brashclaw
    [14471] = "Silithus", -- Setis
    [2744] = "Badlands", -- Shadowforge Commander
    [2600] = "Arathi Highlands", -- Singer
    [5785] = "Mulgore", -- Sister Hatelash
    [5830] = "The Barrens", -- Sister Rathtalon
    [5930] = "Stonetalon Mountains", -- Sister Riven
    [11498] = "Feralas", -- Skarr the Unbreakable
    [2452] = "Alterac Mountains", -- Skhowl
    [519] = "Westfall", -- Slark
    [8283] = "Searing Gorge", -- Slave Master Blackheart
    [5786] = "Mulgore", -- Snagglespear
    [276109] = "Mulgore", -- Snarlsnout
    [9218] = "Blackrock Spire", -- Spirestone Battle Lord
    [9219] = "Blackrock Spire", -- Spirestone Butcher
    [9217] = "Blackrock Spire", -- Spirestone Lord Magus
    [14270] = "Redridge Mountains", -- Squiddic
    [5837] = "The Barrens", -- Stonearm
    [276105] = "Mulgore", -- Stormherald Ukta
    [5864] = "The Barrens", -- Swinegart Spearhide
    [14275] = "Hillsbrad Foothills", -- Tamra Stormpike
    [5932] = "Stonetalon Mountains", -- Taskmaster Whipfang
    [259385] = "Zephras Isle", -- Tel'daeor the Stormspeaker
    [3792] = "Ashenvale", -- Terrowulf Packlord
    [8978] = "Burning Steppes", -- Thauris Balgarr
    [8924] = true, -- The Behemoth
    [208847] = "Westfall", -- The Snatcher
    [5798] = "The Barrens", -- Thora Feathermoon
    [276108] = "Mulgore", -- Thornstarter Igleg
    [61] = "Elwynn Forest", -- Thuros Lightfingers
    [14479] = "Silithus", -- Twilight Lord Everun
    [10584] = "Blackrock Spire", -- Urok Doomhowl
    [14428] = "Teldrassil", -- Uruson
    [14492] = "Stranglethorn Vale", -- Verifonix
    [8199] = "Tanaris", -- Warleader Krazzilak
    [5808] = "Durotar", -- Warlord Kolkanis
    [10822] = "Eastern Plaguelands", -- Warlord Thresh'jin
    [5809] = "Durotar", -- Watch Commander Zalaphil
    [8218] = "The Hinterlands", -- Witherheart the Stalker
    [2605] = "Arathi Highlands", -- Zalas Witherbark
    [10082] = "Zul'Farrak", -- Zerillis
    [8219] = "The Hinterlands", -- Zul'arek Hatefowler
    [10823] = "Eastern Plaguelands", -- Zul'Brin Warpbranch
}
-- Rares friendly to one faction: no symbol for that faction.
local FRIENDLY = {
    [5797] = "Alliance", -- Aean Swiftriver
    [1920] = "Alliance", -- Dalaran Spellscribe
    [3736] = "Horde", -- Darkslayer Mordenthal
    [10817] = "Alliance", -- Duggan Wildhammer
    [5799] = "Alliance", -- Hannah Bladeleaf
    [5847] = "Alliance", -- Heggin Stonewhisker
    [8214] = "Alliance", -- Jalinde Summerdrake
    [5800] = "Alliance", -- Marcus Bel
    [10824] = "Alliance", -- Ranger Lord Hawkspear
    [5916] = "Alliance", -- Sentinel Amarassan
    [5798] = "Alliance", -- Thora Feathermoon
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
