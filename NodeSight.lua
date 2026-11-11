-- AI has done an awful job at commenting on the code. I'm going to try and fix
-- it up within the next few updates and put most of my mods on GitHub. I did
-- not expect so many people to be going through this and to be so interested!
-- Thank you to everyone trying my addons. I appreciate you all, this has made
-- my year.
--
-- NodeSight: herbs and ore on the minimap get their own symbols, an arrow
-- points to the nearest one, and the one in front of you sparkles.
--
-- Files, in load order (they share functions through the addon table `ns`):
--   Locales\*.lua    node names in other languages (each loads only on its client)
--   Zones.lua        map and instance IDs of the rares' home zones
--   Names.lua        node names, icons and skill levels
--   RareNames.lua    rare names in the client's language, asked from the client
--   MinimapShape.lua the minimap's shape: round, square or mixed, maybe cropped at the top and bottom
--   NodeSight.lua    defaults, the minimap scan, loading and events
--   Switch.lua       the finder switch: when to switch, whether it worked, and the mute of its click
--   Sparkles.lua     sparkles on the herb or ore in front of you
--   FarSparkles.lua  sparkles on far away herbs and ore (Beta)
--   SparkleWindow.lua the sparkle window: on/off and the look for each kind, with a 3D preview
--   WhatsNew.lua     the patch notes dialog
--   Settings.lua     the settings pages
--
-- Sections: Minimap scan, Node kinds, Learning nodes, Switching finders, Tooltip,
-- Symbols and arrow, Splitting groups, Following, Scanning, Running the scan, Loading.

local ADDON_NAME, ns = ...

local ipairs, pairs = ipairs, pairs

local defaults = {
    herbs = false, -- sparkles on herbs
    ore = false, -- sparkles on ore
    chests = false, -- sparkles on chests
    quests = false, -- sparkles on quest objects
    others = false, -- sparkles on other objects
    bobber = false, -- sparkles on your fishing bobber
    skinning = false, -- sparkles on corpses you can skin
    gameIcons = false, -- keep the game's interact icons while sparkles are on
    arrow = false, -- arrow to the nearest node
    arrowLocked = false, -- the arrow can't be dragged, and clicks go through it
    arrowSize = 40, -- arrow size
    arrowSkip = true, -- the arrow passes over the node you're at
    arrowCombat = false, -- no arrow in combat
    arrowFirst = false, -- the arrow to herbs and ore before anything else
    arrowHerbs = true, -- what the arrow points to: herbs,
    arrowOre = true, -- ore,
    arrowChests = true, -- chests,
    arrowRares = true, -- rares,
    arrowLeylines = true, -- leylines and convergences
    mapIcons = true, -- symbols on the minimap
    shape = 3, -- 1 square, 2 round, 3 round with a gold ring, 4 with a slim one
    oreRings = false, -- green and rust rings for tin and iron
    iconSize = 11, -- symbol size
    skillLook = 1, -- how symbols show your skill (SKILL.looks): red when too low
    skillLine = true, -- "Requires Herbalism (15)" in herb and ore tooltips
    popups = true, -- NodeSight's popups (ns.AfterFight)
    nearLook = 1, -- a symbol over your own arrow: 1 shown, 2 see-through, 3 hidden
    sound = false, -- sound when something new shows up
    soundKit = 1, -- which sound (FIND_SOUNDS)
    soundSkillUps = false, -- the sound only for herbs and ore that can give a skill-up
    scanMinimap = true, -- Scan the minimap: off, no scans at all (the key's neither)
    autoScanTimer = false, -- Scan on a timer: a scan every autoScanSeconds while you move
    autoScanSeconds = 10, -- seconds between timed scans (0 counts as off too)
    autoScan = true, -- Scan by distance: a scan each time you've walked autoScanYards
    autoScanYards = 25, -- yards walked between scans
    combatScan = false, -- the timer and Scan by distance in combat too
    skipRest = true, -- no timer or Scan by distance while resting (capital cities and inns)
    mobWait = true, -- no timer or Scan by distance with a mob, a corpse or a tooltip under the mouse
    mouseStill = false, -- no timer or Scan by distance while the mouse moves
    mouseStop = false, -- a timer or distance scan stops when the mouse moves
    scanStanding = true, -- the timer also while you stand still
    lootWait = true, -- the timer and Scan by distance wait a moment after a fight, for looting
    lootSeconds = 3, -- how long
    edgeScan = false, -- Beta: scans while moving read only the part of the minimap new since the last scan
    trailFrames = true, -- Beta: frames other addons place where the minimap is hidden during a scan too (Trailing)
    scanPreset = 1, -- the Scanning page's preset: worked out from the settings it sets
    minimapShape = 1, -- 1 automatic (asks your UI addon), 2 round, 3 square
    scanMap = true, -- Beta: the world map's picture where the minimap was while it scans
    hoverSave = true, -- a herb or ore dot you hover on the minimap gets its symbol at once
    windowWait = true, -- Fewer blinks: a window under the mouse or a held mouse button mid-scan: the minimap stays hidden a moment
    scanFade = false, -- the stand-in fades in over the minimap before a scan moves it, and out over it after
    switchFinders = false, -- Find Herbs and Find Minerals in turn
    switchMeasure = 1, -- how the distance between switches is measured: 1 percent, 2 yards, 3 seconds
    switchPercent = 40, -- distance between switches, in percent of the minimap's view radius
    switchDistanceYards = 60, -- distance between switches in yards
    switchSeconds = 8, -- seconds on the move between switches
    switchMounted = false, -- switch only while mounted
    switchPauseBusy = true, -- no switch while casting, looting or with something on the cursor
    switchPauseStealth = true, -- no switch while stealthed
    switchNearYards = 10, -- no switch this close to a herb or ore (0 off)
    switchAfterCast = 3, -- seconds without a switch after your own spells (0 off)
    switchEnemyYards = 40, -- no switch with an enemy this close targeted (0 off)
    switchWorld = true, switchDungeons = true, switchRaids = true, -- where to switch
    switchBattlegrounds = false, -- off, not needed there and it would rather get in the way
    rares = true, -- rare beasts and humanoids (Beta)
    rareIcon = 2, -- which of ICONS.rares
    leylines = true, -- Skyborne: leylines and elemental convergences, while the racial is ready
    worldMark = false, -- Beta: sparkles on far away herbs and ore
    worldKeepQuest = false, -- far sparkles leave a tracked quest's navigation alone (but for quick pins)
    worldSize = 150, -- far sparkles' size, in percent
    worldRealign = 5, -- with Keep my tracked quest: seconds before a quick pin lines them up again anyway
    dotScale = 100, -- the game's own dot size, in percent
    -- Each kind's sparkles (Sparkles.lua's KEYS): style (Sparkles.lua's STYLES),
    -- tint "aarrggbb" (white = none), area size, offset from the plate's bottom,
    -- and how many at once. Herbs' keys have no prefix.
    herbStyle = 1, sparkleColor = "ffffffff", size = 100, height = -60, count = 9,
    oreStyle = 1, oreColor = "ffffffff", oreSize = 100, oreHeight = -60, oreCount = 9,
    chestsStyle = 1, chestsColor = "ffffffff", chestsSize = 100, chestsHeight = -60, chestsCount = 9,
    questsStyle = 1, questsColor = "ffffffff", questsSize = 100, questsHeight = -60, questsCount = 9,
    othersStyle = 1, othersColor = "ffffffff", othersSize = 100, othersHeight = -60, othersCount = 9,
    bobberStyle = 6, bobberColor = "ffffffff", bobberSize = 100, bobberHeight = 0, bobberCount = 9,
    skinningStyle = 1, skinningColor = "ffffffff", skinningSize = 100, skinningHeight = -115, skinningCount = 9,
    brightness = 100, -- sparkle alpha, in percent
    reachLook = false, -- dimmer out of reach, a flash in reach
    combatHide = false, -- no sparkles in combat
    instanceHide = false, -- no sparkles in dungeons and raids
    sparkleSound = false, -- a sound when something near you starts sparkling
    gatherDim = true, -- sparkles fade back while you gather the node
    grayTooHard = false, -- gray sparkles on herbs and ore above your skill
    myProfessions = true, -- herb, ore and skinning sparkles only with Herbalism, Mining or Skinning
    rareGlow = false, -- a gold glow around rare herbs and ore
    harvest = 5, -- how a gathered node finishes (Sparkles.lua's HARVESTS: Fade away)
}
local db = defaults -- NodeSightDB once it's loaded
ns.db = db -- shared with the other files

-- The bug report (its button is by What's New): a short log of what scans did, the newest
-- lines kept with the saved settings so a /reload doesn't lose them.
local REPORT_LINES = 300
local reportLines = {} -- (until the saved settings load)
function ns.Log(text)
    local list = type(NodeSightDB) == "table" and type(NodeSightDB.report) == "table" and NodeSightDB.report or reportLines
    list[#list + 1] = ("%.1f %s"):format(GetTime(), text)
    while #list > REPORT_LINES do table.remove(list, 1) end
end
-- Once a session for each key (a frame hidden every scan is said once).
local logged = {}
function ns.LogOnce(key, text)
    if logged[key] then return end
    logged[key] = true
    ns.Log(text)
end
-- A frame's name for the log.
function ns.NameOf(frame)
    if issecretvalue(frame) then return "a secret frame" end
    if type(frame) ~= "table" then return "nothing" end
    for _, method in ipairs({ "GetDebugName", "GetName" }) do
        local ok, name = pcall(function() return frame[method](frame) end)
        if ok and type(name) == "string" and not issecretvalue(name) and name ~= "" then return name end
    end
    return "an unnamed frame"
end
-- A scan's parts timed for the bug report (the game's clock, in ms; nothing without it).
local function Now() return debugprofilestop and debugprofilestop() end
local function Took(s, part, began)
    if s and began then
        s.parts = s.parts or {}
        s.parts[part] = (s.parts[part] or 0) + debugprofilestop() - began
    end
    return Now()
end
-- An error in NodeSight's own code: into the log, then to the game's error handler as ever.
local function Oops(err)
    pcall(function() ns.Log("error: " .. tostring(err):sub(1, 300)) end)
    return geterrorhandler()(err)
end

---------------------------------------------------------------------------
-- Minimap scan
---------------------------------------------------------------------------
-- Addons can't see where herbs are, but the minimap's tracking dots can be read:
-- the minimap names the dot under the real mouse. The scan (Key scan) moves the
-- minimap under the mouse spot by spot and reads each.

-- Tracking spell IDs: Find Herbs, Find Minerals, Find Treasure.
local FINDERS = { [2383] = "herbs", [2580] = "ore", [2481] = "treasure" }
FINDERS[1494] = "rares" -- Track Beasts (only with the rares setting)
FINDERS[19883], FINDERS[5225] = "rares", "rares" -- Track Humanoids: hunters', druids'
local MAX_ICONS = 40
local ICONS = { herbs = "Professions_Tracking_Herb", ore = "Professions_Tracking_Ore" }
ICONS.rares = { "VignetteKill", "VignetteKillElite", "Rare-Elite-Star" }
-- Skyborne racials and what each finds, shown while it is ready: High Order Skyborne's
-- Read Leyline leylines, Windshaper Skyborne's Skysight elemental convergences. The
-- icon is the spell's, for when the game gives none.
local RACIALS = {
    leyline = { spell = 1259705, icon = "Interface\\Icons\\ability_mage_incantersabsorbtion" },
    convergence = { spell = 1259686, icon = "Interface\\Icons\\ability_skyreach_lens_flare" },
}
local ICON_SIZE = 12 -- the size the gold ring is fitted to
local NORMAL_DOTS = 100 -- the game's own dot size (%)
-- Round shapes use Blizzard's circle mask; the gold ring is MiniMap-TrackingBorder.
local SHAPES = { "Square", "Round", "Round, gold ring", "Round, slim gold ring" }
local CIRCLE = "CircleMask"
local GOLD_BORDER = 136430
-- Gold ring size and top-left offset that center its hole on the symbol.
local GOLD_SIZE, GOLD_X, GOLD_Y = 30, -9.3, 8.7
-- High visibility tin and iron: the Necrolord covenant ring, half desaturated
-- and tinted. Its hole is 58 of its 80x82 pixels, hence the size ratios.
local oreRing = {
    atlas = "CovenantChoice-Offering-Ability-Ring-Necrolord",
    width = 80 / 58, height = 82 / 58, gray = 0.5,
    tints = {
        ["Interface\\Icons\\inv_ore_tin_01"] = { 0.374, 1, 0.972 }, -- #43B3AE
        ["Interface\\Icons\\inv_ore_iron_01"] = { 0.82, 0.55, 0.36 },
    },
}
oreRing.ok = C_Texture.GetAtlasExists(oreRing.atlas)
-- The gold ring's outer edge across, per symbol size (measured on Blizzard's art).
local GOLD_OUTER = 17.6 / 12
local SLIM = 26 -- the slim gold ring: the gold ring cut to this share of its width (%)
local ARROW = "MiniMap-QuestArrow" -- points up
-- The arrow's checkbox for each kind, and how near the node you're at is (yards).
local ARROW_TO = { herbs = "arrowHerbs", ore = "arrowOre", treasure = "arrowChests", rares = "arrowRares", leyline = "arrowLeylines", convergence = "arrowLeylines" }
local SKIP_YARDS = 5
-- Symbols near you: the game draws your own arrow under addons' textures, so a symbol
-- over it (half its size plus this many minimap units from the middle) can be see-through or hidden.
local PLAYER_ARROW, CLEAR = 8, 0.35
local NEAR_LOOKS = { "Shown", "See-through", "Hidden" }
-- Sound for new finds: the game's own sounds, by their SOUNDKIT names.
local FIND_SOUNDS = { { "Minimap ping", "MAP_PING" }, { "Coins", "LOOT_WINDOW_COIN_SOUND" }, { "Whisper", "TELL_MESSAGE" },
    { "Ready check", "READY_CHECK" }, { "Raid warning", "RAID_WARNING" }, { "Auction bell", "AUCTION_WINDOW_OPEN" } }
local CAVE = 0.4 -- alpha of a herb or ore in a cave
-- Skill colors: how a symbol shows your skill against its node. Ring and gem use the
-- profession window's colors for a skill-up. The gems are the original game's; it
-- has no orange one, so the yellow one is tinted.
local SKILL = {
    looks = { "Red when too low", "Colored ring", "Colored gem", "Off" },
    RED = 1, RING = 2, GEM = 3, OFF = 4,
    gems = { "Interface\\Common\\Indicator-Red", "Interface\\Common\\Indicator-Yellow", "Interface\\Common\\Indicator-Yellow",
        "Interface\\Common\\Indicator-Green", "Interface\\Common\\Indicator-Gray" },
    orange = { 1, 0.55, 0.3 },
    gem = 0.76, gemAt = 0.43, -- gem size, and its offset to the lower right, per symbol size
}
function SKILL.Color(level) -- 1 too hard to 5 no skill-up (SkillLevel)
    return level == 1 and RED_FONT_COLOR or level == 2 and DIFFICULT_DIFFICULTY_COLOR or level == 3 and FAIR_DIFFICULTY_COLOR
        or level == 4 and EASY_DIFFICULTY_COLOR or TRIVIAL_DIFFICULTY_COLOR
end

local scan -- a finished key scan's places, for FinishScan
local markers = {} -- the places the last scan found, nearest first
local tracker, arrow, arrowTexture, arrowText
local mapFrame, mapIcons = nil, {}
local heard = {} -- recent finds, for the Sound setting
local shownText
local arrowOn = false
local arrowAngle -- the arrow's rotation, set only when it changes
local turning -- the minimap was rotating at the last scan
-- Switch state: kind and picked (see ns.TrySwitch and Picked).
local turns = {}
local racialShown = false -- the last scan found a leyline or convergence

local function Enabled()
    if not Minimap.UpdateMouseoverAtPoint then return false end -- Retail: the scan is only for Forever
    return db.scanMinimap and (db.arrow or db.mapIcons or db.sound or db.worldMark)
end

-- Seconds between timed scans; 0 with Scan on a timer off.
local function TimerSeconds()
    return db.autoScanTimer and tonumber(db.autoScanSeconds) or 0
end

-- Facing in radians (counterclockwise from north), or nil.
local function PlayerFacing()
    local facing = GetPlayerFacing()
    if issecretvalue(facing) then return nil end
    return facing
end

-- Map ID, your x and y on it (0-1) and its size in yards; nil if unknown.
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

-- From Names.lua.
local Plain, NodeKind, NodeIcon = ns.Plain, ns.NodeKind, ns.NodeIcon
local TREASURE, RARES, FRIENDLY = ns.TREASURE, ns.RARES, ns.FRIENDLY
local TOO_HARD, skills, professions, TooHard, SkillLevel = ns.TOO_HARD, ns.skills, ns.professions, ns.TooHard, ns.SkillLevel

---------------------------------------------------------------------------
-- Node kinds
---------------------------------------------------------------------------
-- What a minimap dot's name stands for, and the picture its symbol gets.

-- The racial that finds `kind` known and ready, with the setting on. Its global
-- cooldown counts as ready. isActive and isOnGCD are never secret; the times are in a fight.
local function RacialReady(kind)
    local spell = RACIALS[kind].spell
    if not db.leylines or not (C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spell)) then return false end
    local info = C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(spell)
    if issecretvalue(info) or type(info) ~= "table" or issecretvalue(info.isActive) or not info.isActive then return true end
    return not issecretvalue(info.isOnGCD) and info.isOnGCD == true
end

-- Is a finder on? true if the game won't say. A ready racial needs none.
local function FinderOn()
    if not (C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo) then return true end
    for index = 1, C_Minimap.GetNumTrackingTypes() do
        local info = C_Minimap.GetTrackingInfo(index)
        if issecretvalue(info) then return true end
        if info then
            if issecretvalue(info.active) or issecretvalue(info.spellID) then return true end
            local shows = info.spellID and FINDERS[info.spellID]
            if shows == "rares" and not db.rares then shows = nil end
            if shows and info.active then return true end
        end
    end
    return RacialReady("leyline") or RacialReady("convergence")
end

-- Players' names: your arrow and a party member's dot on the minimap show a full
-- name, which can end like a herb's ("Bob Silverleaf"). Read again with your skills.
local groupNames, groupRead = {}, false

-- The full name only (every character has a surname), so a herb called just
-- "Silverleaf" stays one. The game can give both in the first value.
local function AddName(unit)
    local first, surname = UnitName(unit)
    if issecretvalue(first) or type(first) ~= "string" then return end
    if not issecretvalue(surname) and type(surname) == "string" and surname ~= "" then
        groupNames[Plain(first .. " " .. surname)] = true
    elseif first:find(" ", 1, true) then
        groupNames[Plain(first)] = true
    end
end

local function InGroup(plain)
    if not groupRead then
        groupRead = true
        wipe(groupNames)
        AddName("player")
        local raid = IsInRaid()
        for i = 1, raid and GetNumGroupMembers() or GetNumSubgroupMembers() do
            AddName((raid and "raid" or "party") .. i)
        end
    end
    return groupNames[plain] == true
end

-- "herbs", "ore", "treasure", "rares" (with that setting), "leyline" or "convergence"
-- (while its racial is ready) or nil.
local function KindOf(name)
    if InGroup(Plain(name)) then return nil end
    if db.rares then
        local id = ns.RareID(Plain(name)) -- by NPC ID, the names come from the client (RareNames.lua)
        local home = id and RARES[id]
        if id and FRIENDLY[id] == UnitFactionGroup("player") then home = nil end
        -- Only in its home zone.
        if home == true or (home and ns.InZone(home)) then
            -- Not your own pet (a tamed rare keeps its name).
            local pet = UnitName("pet")
            if not issecretvalue(pet) and (not pet or ns.RareID(Plain(pet)) ~= id) then return "rares" end
        end
    end
    -- Learned herbs and ore. Chests go by their names: a chest is one whatever it gave.
    local known = db.learned and db.learned[Plain(name)]
    local listed = NodeKind(name)
    local kind = listed ~= "treasure" and known and known.kind ~= "treasure" and known.kind or listed
    if RACIALS[kind] and not RacialReady(kind) then return nil end
    return kind
end

local function IconOf(name, kind)
    if kind == "treasure" then return TREASURE.icon end
    if kind == "rares" then return nil end -- the rare symbol, though a name can hold an ore's ("Dark Iron ...")
    local racial = RACIALS[kind]
    if racial then
        local file = C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(racial.spell)
        if issecretvalue(file) or type(file) ~= "number" or file <= 0 then file = racial.icon end
        return file
    end
    local known = db.learned and db.learned[Plain(name)]
    return NodeIcon(name) or (known and known.icon)
end

---------------------------------------------------------------------------
-- Learning nodes
---------------------------------------------------------------------------
-- Nodes missing from the English lists are learned when gathered, from the loot.

local TRADE_GOODS, HERB, METAL_AND_STONE = 7, 9, 7 -- item class/subclasses
-- What else a herb or vein gives: other trade goods (Forever's gems are those), gems,
-- quest items and junk. Anything else (gear, potions, ...) means it wasn't a node.
local ALSO_LOOT = { [TRADE_GOODS] = true, [3] = true, [12] = true, [15] = true }
local castTarget -- target of your last cast
local lastSource -- GUID of the last looted object

local function NoteCast(target)
    castTarget = nil
    if issecretvalue(target) or type(target) ~= "string" or target == "" then return end
    castTarget = target
end

-- "herbs" or "ore" if a node gave this loot, and its items as { item, icon }.
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
        elseif not ALSO_LOOT[class] then
            return nil
        end
    end
    return kind, gave
end

local function SourceName(guid)
    local name = UnitNameFromGUID and UnitNameFromGUID(guid)
    if issecretvalue(name) or type(name) ~= "string" or name == "" or name == UNKNOWNOBJECT then name = castTarget end
    return name
end

-- LOOT_READY: learn the node the loot came from.
local function Learn()
    local guid = GetLootSourceInfo(1)
    if issecretvalue(guid) or type(guid) ~= "string" or guid == lastSource then return end
    lastSource = guid
    if guid:sub(1, 11) ~= "GameObject-" then return end
    local name = SourceName(guid)
    castTarget = nil
    local kind, gave = LootKind()
    local chest = name and NodeKind(name) == "treasure"
    if chest then kind = nil end -- a chest's bars or herbs
    turns.picked, turns.pickedName = chest and "treasure" or kind, name -- (see Picked)
    if not (name and kind) then return end -- no name, or not a herb or ore
    local key = Plain(name)
    local known = db.learned[key] or { seen = {}, most = 0 }
    known.kind = kind
    for _, pair in ipairs(gave) do
        local count = (known.seen[pair[1]] or 0) + 1
        known.seen[pair[1]] = count
        if count > known.most then known.most, known.icon = count, pair[2] end
    end
    db.learned[key] = known
end

---------------------------------------------------------------------------
-- Switching finders
---------------------------------------------------------------------------
-- The minimap shows one finder's dots at a time. The Switch setting toggles
-- Find Herbs and Find Minerals as you move (Switch.lua decides when), keeping the other
-- kind's symbols meanwhile (marker.held).
local SWITCH_WAIT = 1 -- seconds from a switch to the next scan
local PICK_REACH = 10 -- yards: looting removes a held symbol this close

-- Active finder kind and the other's tracking index; nil unless exactly one is on.
local function Finders()
    if not (C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo) then return nil end
    local on, off, active = nil, nil, 0
    for index = 1, C_Minimap.GetNumTrackingTypes() do
        local info = C_Minimap.GetTrackingInfo(index)
        if issecretvalue(info) then return nil end
        local shows = info and not issecretvalue(info.spellID) and FINDERS[info.spellID]
        if shows == "herbs" or shows == "ore" then -- (not Find Treasure or creature tracking)
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

-- The other finder on now, if ns.SwitchReady agrees; true if it switched.
local function SwitchNow()
    if (ns.KeyScanning and ns.KeyScanning()) or not Minimap:IsVisible() then return false end
    local kind, other = Finders()
    if not (kind and other and C_Minimap.SetTracking) then return false end
    local target = kind == "herbs" and "ore" or "herbs"
    if not ns.SwitchReady(target) then return false end
    ns.Mute()
    ns.switch.pending = { kind = target, at = GetTime() } -- before SetTracking, which may fire its event
    C_Minimap.SetTracking(other, true)
    return true
end

-- Switch's own timing (its distance or time): only without automatic scans, which switch
-- right before each scan instead (ns.SwitchBeforeScan).
function ns.TrySwitch()
    if (db.autoScan or TimerSeconds() > 0) and Enabled() then return false end
    return SwitchNow()
end

-- With Switch on, right before an automatic scan: so each scan reads the other finder's dots.
function ns.SwitchBeforeScan()
    return db.switchFinders == true and SwitchNow()
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------

-- Strips color codes and inline textures from a tooltip line.
local function Clean(text)
    text = text:gsub("|A.-|a", ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return text:match("^%s*(.-)%s*$")
end

-- Gray text means the node is in a cave.
local function Gray(r, g, b)
    if issecretvalue(r) or issecretvalue(g) or issecretvalue(b) or not (r and g and b) then return false end
    return math.abs(r - g) < 0.1 and math.abs(g - b) < 0.1 and r < 0.9
end

-- Names in a tooltip line (one per row), cached by text; list.gray marks gray ones.
local lineNames, lineCount = {}, 0
local function NamesIn(text)
    local list = lineNames[text]
    if not list then
        list = {}
        for name in text:gmatch("[^\n]+") do
            local r, g, b = name:match("|c%x%x(%x%x)(%x%x)(%x%x)") -- before Clean strips it
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

-- Adds a "Requires Herbalism (15)" line to the minimap tooltip, red if your skill
-- is too low, else in the profession window's colors for the chance of a skill-up.
-- It's rebuilt every frame, so skills are reread at most once a second.
local SKILL_WAIT = 1
local skillsRead = 0 -- last skill refresh
local said = {} -- lines added this frame

-- The line and its color.
local function Requirement(name)
    local kind = KindOf(name)
    local level, need = SkillLevel(name, kind) -- nothing for chests, rares and the like
    if not level or not professions[kind] then return nil end
    return ITEM_MIN_SKILL:format(professions[kind], need), SKILL.Color(level)
end

local function FreshSkills()
    local now = GetTime()
    if now - skillsRead >= SKILL_WAIT then skills.herbs, skills.ore, skillsRead, groupRead = nil, nil, now, false end
end

local function OnMinimapTooltip(tooltip, data)
    if not db.skillLine then return end
    local lines = not issecretvalue(data) and data.lines
    if not lines or issecretvalue(lines) then return end
    FreshSkills()
    if next(said) then wipe(said) end
    for _, line in ipairs(lines) do
        local text = line.leftText
        if text and not issecretvalue(text) then
            for _, name in ipairs(NamesIn(text)) do
                local requires, color = Requirement(name)
                if requires and not said[requires] then
                    said[requires] = true
                    tooltip:AddLine(requires, color:GetRGB())
                end
            end
        end
    end
end

-- The same line on a herb's or ore's own tooltip, when the mouse is over it.
local function OnObjectTooltip(tooltip, data)
    if not db.skillLine then return end
    local lines = not issecretvalue(data) and data.lines
    if not lines or issecretvalue(lines) or issecretvalue(lines[1]) then return end
    local name = lines[1] and lines[1].leftText
    if not name or issecretvalue(name) then return end
    FreshSkills()
    local requires, color = Requirement(Clean(name))
    if not requires then return end
    for i = 2, #lines do
        local line = lines[i]
        if issecretvalue(line) then return end
        local text = line.leftText
        if issecretvalue(text) or text == requires then return end -- the game has it already
    end
    tooltip:AddLine(requires, color:GetRGB())
end

---------------------------------------------------------------------------
-- Symbols and arrow
---------------------------------------------------------------------------

-- New symbol texture (sized later by ApplySize). Symbols, rings, gems and masks glide
-- between screen pixels as the minimap's dots do, rather than stepping from one to the next.
local function NewIcon()
    local texture = mapFrame:CreateTexture(nil, "OVERLAY")
    texture:SetSnapToPixelGrid(false)
    texture:SetTexelSnappingBias(0)
    return { texture = texture, hard = false }
end

-- Circle mask for a symbol or its ring.
local function NewMask(region)
    local mask = mapFrame:CreateMaskTexture()
    mask:SetSnapToPixelGrid(false)
    mask:SetTexelSnappingBias(0)
    mask:SetAtlas(CIRCLE)
    mask:SetAllPoints(region)
    region:AddMaskTexture(mask)
    return mask
end

-- How much of the ring's width a shape shows (%): the slim gold ring is cut.
local function RingCut(shape) return shape == 4 and SLIM or 100 end

-- The slim gold ring is the gold ring cut thin: it goes under the symbol, which
-- hides its dark inner edge, and a circle on the symbol's middle cuts it from the
-- outside, so what shows is an even band between two circles around the same point.
local function CutRing(icon)
    icon.cut = RingCut(icon.shape)
    local cut = icon.cut < 100
    if cut then
        if not icon.cutMask then
            icon.cutMask = mapFrame:CreateMaskTexture()
            icon.cutMask:SetSnapToPixelGrid(false)
            icon.cutMask:SetTexelSnappingBias(0)
            -- Clear outside its square, or the game stretches the circle's edge outward.
            icon.cutMask:SetAtlas(CIRCLE, false, nil, nil, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            icon.cutMask:SetPoint("CENTER", icon.texture, "CENTER")
        end
        local outer = icon.tint and oreRing.width or GOLD_OUTER
        local across = icon.size * (1 + (outer - 1) * icon.cut / 100)
        icon.cutMask:SetSize(across, across)
    end
    if cut ~= (icon.ringCut or false) then
        icon.ringCut = cut
        if cut then
            icon.border:AddMaskTexture(icon.cutMask)
            icon.border:SetDrawLayer("OVERLAY", -1)
        else
            icon.border:RemoveMaskTexture(icon.cutMask)
            icon.border:SetDrawLayer("OVERLAY", 1)
        end
    end
end

-- The gold ring scales with the symbol; the ore rings are centered on it.
local function SizeRing(icon)
    CutRing(icon)
    local scale = icon.size / ICON_SIZE
    icon.border:ClearAllPoints() -- the rings use different anchors
    if icon.tint then
        icon.border:SetSize(icon.size * oreRing.width, icon.size * oreRing.height)
        icon.border:SetPoint("CENTER", icon.texture, "CENTER")
        return
    end
    icon.border:SetSize(GOLD_SIZE * scale, GOLD_SIZE * scale)
    icon.border:SetPoint("TOPLEFT", icon.texture, "CENTER", GOLD_X * scale, GOLD_Y * scale)
end

-- The gem sits on the symbol's lower right.
local function SizeGem(icon)
    local size, at = icon.size * SKILL.gem, icon.size * SKILL.gemAt
    icon.gem:SetSize(size, size)
    icon.gem:SetPoint("CENTER", icon.texture, "CENTER", at, -at)
end

local function ApplySize(icon)
    icon.size = db.iconSize
    icon.texture:SetSize(icon.size, icon.size)
    if icon.border then SizeRing(icon) end
    if icon.gem then SizeGem(icon) end
end

-- Applies a shape; the mask and ring are created on first use.
local function ApplyShape(icon, shape)
    icon.shape = shape
    local ringed = shape == 3 or shape == 4
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
            -- Drawn over the symbol, anchored to it.
            icon.border = mapFrame:CreateTexture(nil, "OVERLAY", nil, 1)
            icon.border:SetSnapToPixelGrid(false)
            icon.border:SetTexelSnappingBias(0)
            icon.border:SetTexture(GOLD_BORDER)
            SizeRing(icon)
        end
        icon.ring = icon.border
        icon.ring:Show() -- the symbol itself is shown by ShowMarkers
    elseif icon.ring then
        icon.ring:Hide()
        icon.ring = nil
    end
end

-- The arrow's node: the nearest you can gather (not too hard, not in a cave) of the
-- kinds it points to, on the minimap; with those settings past the one you're at,
-- herbs and ore first.
local function Target()
    local other
    for _, marker in ipairs(markers) do
        if not marker.hard and not marker.dim and not marker.far and db[ARROW_TO[marker.kind]]
            and not (db.arrowSkip and marker.yards and marker.yards < SKIP_YARDS) then
            if not db.arrowFirst or marker.kind == "herbs" or marker.kind == "ore" then return marker end
            other = other or marker
        end
    end
    return other
end

-- A symbol's picture: the item icon, or the plain herb, ore or rare symbol.
local function ShowPicture(icon, marker)
    local picture = marker.file or ICONS[marker.kind]
    if marker.kind == "rares" then picture = picture[db.rareIcon] end
    if icon.picture ~= picture then
        icon.picture = picture
        if marker.file then
            icon.texture:SetTexture(picture)
            icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- without the icon's border
        else
            icon.texture:SetAtlas(picture)
        end
    end
end

-- A symbol's size, shape and ring.
local function ShowShape(icon, marker)
    if icon.size ~= db.iconSize then ApplySize(icon) end -- before ApplyShape, so a new ring gets this size
    -- Rare symbols keep Blizzard's own look: square, no ring.
    local shape = marker.kind == "rares" and 1 or db.shape
    if icon.shape ~= shape then ApplyShape(icon, shape) end
    -- Colored ring or gem: the node's skill-up chance, once per marker.
    local look = db.skillLook
    if marker.level == nil and (look == SKILL.RING or look == SKILL.GEM) then
        marker.level = SkillLevel(marker.name, marker.kind) or false
    end
    -- High visibility tin and iron: swap the gold ring for the tinted one, unless the
    -- ring shows your skill.
    local tint = icon.ring and db.oreRings and not (look == SKILL.RING and marker.level)
        and oreRing.ok and oreRing.tints[marker.file] or false
    local swap = not icon.tint ~= not tint -- tin to iron is just a new tint
    icon.tint = tint
    if swap then
        if tint then
            icon.border:SetAtlas(oreRing.atlas)
        else
            icon.border:SetTexture(GOLD_BORDER)
            icon.border:SetTexCoord(0, 1, 0, 1) -- SetTexture keeps the atlas's coords
        end
        SizeRing(icon)
    end
    if icon.ring and icon.cut ~= RingCut(shape) then CutRing(icon) end
end

-- A symbol's look: Skill colors, faded in a cave, see-through over your arrow. After
-- a color change the alpha is set again, not left to what the color did to it.
local function ShowLook(icon, marker)
    local look = db.skillLook
    local hard = (look == SKILL.RED and marker.hard) or false
    if icon.hard ~= hard then
        icon.hard = hard
        if hard then
            icon.texture:SetVertexColor(TOO_HARD[1], TOO_HARD[2], TOO_HARD[3])
        else
            icon.texture:SetVertexColor(1, 1, 1)
        end
        icon.alpha = nil -- set again below
    end
    -- The ring: the skill's color in grays tinted, the ore tint, or gold. Done here
    -- because ApplyShape may have just created or re-shown it.
    local level = look == SKILL.RING and marker.level
    local ringLook = level or icon.tint or false
    if icon.ring and (icon.ringLook or false) ~= ringLook then
        icon.ringLook = ringLook
        if level then
            icon.ring:SetDesaturated(true)
            icon.ring:SetVertexColor(SKILL.Color(level):GetRGB())
        elseif icon.tint then
            icon.ring:SetVertexColor(icon.tint[1], icon.tint[2], icon.tint[3])
            icon.ring:SetDesaturation(oreRing.gray)
        else
            icon.ring:SetVertexColor(1, 1, 1)
            icon.ring:SetDesaturated(false)
        end
        icon.ringAlpha = nil
    end
    -- The gem, made on first use.
    level = look == SKILL.GEM and marker.level or false
    if level and not icon.gem then
        icon.gem = mapFrame:CreateTexture(nil, "OVERLAY", nil, 2)
        icon.gem:SetSnapToPixelGrid(false)
        icon.gem:SetTexelSnappingBias(0)
        SizeGem(icon)
    end
    if icon.gem and icon.gemLevel ~= level then
        icon.gemLevel = level
        if level then
            icon.gem:SetTexture(SKILL.gems[level])
            local tint = level == 2 and SKILL.orange
            if tint then icon.gem:SetVertexColor(tint[1], tint[2], tint[3]) else icon.gem:SetVertexColor(1, 1, 1) end
            icon.gemAlpha = nil
        end
        icon.gem:SetShown(level ~= false)
    end
    -- Faded in a cave; see-through or hidden while over your own arrow.
    local alpha = marker.dim and CAVE or 1
    if db.nearLook ~= 1 and marker.distance < icon.size / 2 + PLAYER_ARROW then
        alpha = db.nearLook == 3 and 0 or math.min(alpha, CLEAR)
    end
    if icon.alpha ~= alpha then
        icon.alpha = alpha
        icon.texture:SetAlpha(alpha)
    end
    if icon.ring and icon.ringAlpha ~= alpha then
        icon.ringAlpha = alpha
        icon.ring:SetAlpha(alpha)
    end
    if icon.gem and icon.gemLevel and icon.gemAlpha ~= alpha then
        icon.gemAlpha = alpha
        icon.gem:SetAlpha(alpha)
    end
end

-- Updates the symbols and the arrow's text.
local function ShowMarkers()
    local target = db.arrow and Target()
    if target then -- arrow text
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
            ShowPicture(icon, marker)
            ShowShape(icon, marker)
            ShowLook(icon, marker)
            -- Setting the same point again moves it; no ClearAllPoints needed.
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
            if icon.gem then
                icon.gem:Hide()
                icon.gemLevel = nil
            end
        end
    end
end

local function UpdateArrow()
    local target = db.arrow and not (db.arrowCombat and UnitAffectingCombat("player")) and Target()
    local facing = target and PlayerFacing()
    if not facing then
        if arrowOn then
            arrowOn = false
            arrow:Hide()
        end
        return
    end
    -- Bearings are clockwise from north; facing and texture rotation counterclockwise.
    local angle = -(target.world + facing)
    if angle ~= arrowAngle then
        arrowAngle = angle
        arrowTexture:SetRotation(angle)
    end
    if not arrowOn then
        arrowOn = true
        arrow:Show()
    end
end

-- A locked arrow takes no mouse: it can't be dragged, and clicks go through it.
local function ApplyArrowLock()
    arrow:EnableMouse(not db.arrowLocked)
end

-- The name and distance grow with the arrow: the font's own height at the default size.
local function ApplyArrowSize()
    arrow:SetSize(db.arrowSize, db.arrowSize)
    local font, height, flags = GameFontNormal:GetFont()
    arrowText:SetFont(font, math.max(8, height * db.arrowSize / defaults.arrowSize), flags)
end

---------------------------------------------------------------------------
-- Following
---------------------------------------------------------------------------
-- Between scans, places stay fixed on the zone map and their minimap position
-- is recomputed every frame as you move.
local function ByDistance(a, b) return a.distance < b.distance end

local lastMap, lastX, lastY, lastFacing, lastRadius -- inputs of the last Follow

local function Follow()
    if not markers[1] or not markers[1].map then return end
    -- A symbol 5 seconds off the minimap goes: its node may well be gathered by the time you're
    -- back. Looked at once a second.
    local now = GetTime()
    if now >= (markers.dropAt or 0) then
        markers.dropAt = now + 1
        local dropped = false
        for i = #markers, 1, -1 do
            if markers[i].farAt and now - markers[i].farAt >= 5 then
                table.remove(markers, i)
                dropped = true
            end
        end
        if dropped then
            ShowMarkers()
            if not markers[1] then return end
        end
    end
    -- Not moved (your place in yards the same), the zoom, facing and shape the same: nothing to
    -- do, and no map position asked for (the game makes a new table for each answer).
    local wx, wy = UnitPosition("player")
    if issecretvalue(wx) or issecretvalue(wy) or not wy then wx, wy = nil, nil end
    if wx and lastMap and wx == markers.wx and wy == markers.wy then
        local zoom = C_Minimap.GetViewRadius()
        if zoom and not issecretvalue(zoom) and zoom == lastRadius and (not turning or PlayerFacing() == lastFacing)
            and markers.quarters == ns.MinimapQuarters() then return end
    end
    local map, x, y, width, height = MapPosition()
    local radius = C_Minimap.GetViewRadius()
    local facing = turning and PlayerFacing() -- only needed when rotating
    if not map or not radius or issecretvalue(radius) or (turning and not facing) then return end
    local quarters = ns.MinimapQuarters()
    -- Nothing moved, and the shape is the same.
    if map == lastMap and x == lastX and y == lastY and radius == lastRadius and (not turning or facing == lastFacing)
        and markers.quarters == quarters then
        return
    end
    lastMap, lastX, lastY, lastFacing, lastRadius = map, x, y, facing, radius
    markers.wx, markers.wy = wx, wy
    markers.quarters = quarters -- like lastMap, but kept on the list: no new file-level local (Lua allows 200)
    local half = Minimap:GetWidth() / 2
    local sorted, last = true, 0
    for _, marker in ipairs(markers) do
        if marker.map == map then
            local east, north = (marker.mx - x) * width, (y - marker.my) * height
            marker.yards = math.sqrt(east * east + north * north)
            marker.world = math.atan2(east, north)
            marker.distance = marker.yards / radius * half
            local way = turning and marker.world + facing or marker.world -- clockwise from the minimap's top
            marker.x, marker.y = half + marker.distance * math.sin(way), half + marker.distance * math.cos(way)
            marker.far = not ns.InShape(marker.x - half, marker.y - half, half, quarters)
        else
            -- Another map (a zone border crossed): it can't be followed. It stays while you
            -- stand still, and hides once you've walked 5 yards (until you're back, or a scan).
            local away = markers.away
            if not away or away.map ~= map then
                away = { map = map, x = x, y = y }
                markers.away = away
            end
            if ((x - away.x) * width) ^ 2 + ((y - away.y) * height) ^ 2 > 25 then marker.far = true end
        end
        marker.farAt = marker.far and (marker.farAt or GetTime()) or nil
        if marker.distance < last then sorted = false end
        last = marker.distance
    end
    -- Keep nearest first.
    if not sorted then table.sort(markers, ByDistance) end
    ShowMarkers()
end

-- A herb seen again (same name, within MERGE yards) is averaged with its old
-- place over up to AVERAGE scans, so symbols don't jump.
local MERGE = 15 -- yards
local AVERAGE = 8

local function Smooth(found, before, width, height, used)
    for _, marker in ipairs(found) do
        local best, bestGap
        for _, old in ipairs(before) do
            if marker.map and old.map == marker.map and old.name == marker.name and not used[old] and not old.rough then
                local gap = ((old.mx - marker.mx) * width) ^ 2 + ((old.my - marker.my) * height) ^ 2
                if gap < MERGE * MERGE and (not bestGap or gap < bestGap) then best, bestGap = old, gap end
            end
        end
        -- Rares move, and a rough place is measured again next scan: no averaging.
        if marker.kind == "rares" or marker.rough then best = nil end
        if marker.pinned then
            marker.count = marker.count or 1
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

---------------------------------------------------------------------------
-- Scanning
---------------------------------------------------------------------------

-- A herb or ore you can still get a skill-up from: not gray (the ones too hard are left out already).
local function SkillUp(marker)
    local level = (marker.kind == "herbs" or marker.kind == "ore") and SkillLevel(marker.name, marker.kind)
    return level and level <= 4 or false
end

local function PlayFindSound()
    PlaySound(SOUNDKIT[FIND_SOUNDS[db.soundKit] and FIND_SOUNDS[db.soundKit][2]] or SOUNDKIT.MAP_PING)
end

-- A scan finished: its places become the markers. Also keeps held symbols and plays
-- the Sound setting's sound.
-- Other addons' functions to call after each scan (NodeSightAPI.RegisterCallback).
local apiCallbacks = {}
local function Symbols()
    local list = {}
    for _, m in ipairs(markers) do
        list[#list + 1] = { name = m.name, kind = m.kind, map = m.map, x = m.mx, y = m.my, yards = m.yards, held = m.held or nil }
    end
    return list
end

local function FinishScan()
    local places = scan.places
    scan = nil
    local width = Minimap:GetWidth()
    local radius = C_Minimap.GetViewRadius()
    if issecretvalue(radius) then radius = nil end
    local rotating = C_CVar.GetCVar("rotateMinimap") == "1"
    local facing = PlayerFacing()
    local found, pinOf, kept = {}, {}, {}
    skills.herbs, skills.ore, groupRead = nil, nil, false -- reread when needed
    racialShown = false
    -- A rotating minimap has your facing at the top; otherwise north.
    if not (rotating and not facing) then
        for _, place in ipairs(places) do
            local name, x, y = place.name, place.x, place.y
            -- Skip names that stopped being nodes mid-scan (zone change, pet called).
            local kind = KindOf(name)
            if kind then
                if RACIALS[kind] then racialShown = true end
                local dx, dy = x - width / 2, y - width / 2
                local bearing = math.atan2(dx, dy) -- clockwise from the top of the minimap
                local distance = math.sqrt(dx * dx + dy * dy)
                local marker = {
                    name = name, kind = kind, file = IconOf(name, kind),
                    hard = (db.skillLook == SKILL.RED or db.arrow or db.sound or db.worldMark) and TooHard(name, kind),
                    x = x, y = y, distance = distance, age = place.age, exact = place.exact, missed = place.missed, rough = place.rough,
                    yards = radius and distance / (width / 2) * radius,
                    world = rotating and bearing - facing or bearing,
                    dim = place.dim or false, -- in a cave: the minimap named it in gray
                }
                found[#found + 1] = marker
                pinOf[marker] = place.pin
            end
        end
    end
    table.sort(found, ByDistance)
    -- Zone map positions, for Follow.
    local map, x, y, mapWidth, mapHeight = MapPosition()
    if map then
        for _, marker in ipairs(found) do
            if marker.yards then
                marker.map = map
                local pin = pinOf[marker]
                if pin and pin.map == map then
                    -- Pinned earlier: keep that spot.
                    marker.mx, marker.my, marker.count, marker.pinned = pin.mx, pin.my, pin.count + 1, true
                    kept[pin] = true
                else
                    marker.mx = x + marker.yards * math.sin(marker.world) / mapWidth
                    marker.my = y - marker.yards * math.cos(marker.world) / mapHeight
                    marker.pinned = marker.exact -- exact spot found this scan
                end
            end
        end
    end
    if map then Smooth(found, markers, mapWidth, mapHeight, kept) end
    -- Switch setting: keep the other kind's symbols until its turn (held).
    local shown = db.switchFinders and turns.kind
    if shown and map then
        local other = shown == "herbs" and "ore" or "herbs" -- kind whose finder is off
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
    -- Sound setting: one sound per scan for anything not seen in the last minute
    -- (same name within 25 minimap units; rares by name only). Not for nodes too hard,
    -- and with Only for skill-ups only for herbs and ore that can still give one.
    if db.sound then
        local now, new = GetTime(), false
        local reach = radius and (25 * radius * 2 / width) ^ 2 -- yards, squared
        for i = #heard, 1, -1 do
            if now - heard[i].at > 60 then table.remove(heard, i) end
        end
        for _, marker in ipairs(found) do
            if not marker.hard and (not db.soundSkillUps or SkillUp(marker)) then
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
        if new then PlayFindSound() end
    end
    turning = rotating
    markers = found
    lastMap = nil -- make Follow recompute
    ShowMarkers()
    if apiCallbacks[1] then
        local list = Symbols()
        for _, callback in ipairs(apiCallbacks) do xpcall(callback, geterrorhandler(), list) end
    end
end

---------------------------------------------------------------------------
-- Key scan
---------------------------------------------------------------------------

-- The minimap only names the dot under the real mouse, worked out once a frame
-- from where the minimap is then. A key scan moves the minimap under the mouse
-- one spot a frame (hidden: see-through, its dots and your arrow shrunk,
-- Blizzard's coordinates faded) and reads each spot the frame after. Then a
-- line of close spots across each find and up and down through it puts it on
-- the dot's middle. The finds go to FinishScan as the old scan's places did.

-- The key scan's state and functions, in one table (the main chunk is at Lua's 200 locals).
-- key.scan: the scan running; key.wanted: pressed while turning the camera.
local key = {}

-- Quests' blue areas show even on a see-through minimap: while it scans, the game's
-- Quest POIs tracking (always on, not in its menu) is off.
local function QuestPOIIndex()
    if not (C_Minimap.GetTrackingFilter and Enum.MinimapTrackingFilter and Enum.MinimapTrackingFilter.QuestPOIs) then return nil end
    for i = 1, C_Minimap.GetNumTrackingTypes() do
        local filter = C_Minimap.GetTrackingFilter(i)
        if type(filter) == "table" and not issecretvalue(filter) and not issecretvalue(filter.filterID)
            and filter.filterID == Enum.MinimapTrackingFilter.QuestPOIs then return i end
    end
end
function ns.HideQuestAreas(s, on)
    if on and s.questIndex == nil then
        local index = QuestPOIIndex()
        local info = index and C_Minimap.GetTrackingInfo(index)
        if type(info) == "table" and not issecretvalue(info) and info.active == true then s.questIndex = index end
    end
    if not s.questIndex then return end
    if on then
        NodeSightDB.questOff = true -- (put back at the next login if it can't be now)
        pcall(C_Minimap.SetTracking, s.questIndex, false)
    -- Back on where the list has it now (the list may have changed mid-scan).
    elseif pcall(C_Minimap.SetTracking, QuestPOIIndex() or s.questIndex, true) then
        NodeSightDB.questOff = nil
    end
end
-- Every login and loading screen: the quest areas are on. The game keeps them always on
-- with no way to turn them off, so off can only be a scan cut short (a logout or a crash).
-- The controller's hover in free look a scan turned on, left on when putting it back failed as
-- the game closed: off again. Not with the gamepad UI on (it keeps hover on itself).
function ns.PadHoverBack()
    if not NodeSightDB.padHoverOn or (ns.KeyScanning and ns.KeyScanning()) then return end
    local style = C_InputInterfaceStyle and C_InputInterfaceStyle.GetCurrentStyle and C_InputInterfaceStyle.GetCurrentStyle()
    if Enum.InputDeviceInterfaceType and style == Enum.InputDeviceInterfaceType.Gamepad then
        NodeSightDB.padHoverOn = nil
        return
    end
    if C_GamePad and C_GamePad.SetAllowHoverEventsWithFreeLook then pcall(C_GamePad.SetAllowHoverEventsWithFreeLook, false) end
    NodeSightDB.padHoverOn = nil
end
function ns.QuestAreasBack()
    if ns.KeyScanning and ns.KeyScanning() then return end
    local index = QuestPOIIndex()
    if not index then return end -- (the tracking list not there yet: at the next loading screen)
    local info = C_Minimap.GetTrackingInfo(index)
    local off = type(info) == "table" and not issecretvalue(info) and info.active == false
    if (off or NodeSightDB.questOff) and pcall(C_Minimap.SetTracking, index, true) then NodeSightDB.questOff = nil end
end
;(function() -- a function, not a do block: its locals don't count against the main chunk's 200
    local FIRST_STEP = 20 -- spot spacing until a dot is measured: no gap for a dot 25 across
    local GUESS_DOT = 24 -- a dot's width in minimap units until enough are measured
    local DOT_SAMPLES = 25 -- dot widths kept (NodeSight's saved dotWidths)

    local function Middle(list)
        local sorted = {}
        for i, width in ipairs(list) do sorted[i] = width end
        table.sort(sorted)
        return sorted[math.floor((#sorted + 1) / 2)]
    end

    -- A dot's width: the middle of the widths measured up and down through single round dots
    -- (saved); until there are 3 (learned), the guess. A dot answers the mouse over the same
    -- area on screen whatever the minimap's scale, so the scan keeps the minimap at its own
    -- size: shrunk, every dot would be wider for its size and close nodes would run together.
    local function Dot()
        local list = type(db.dotWidths) == "table" and db.dotWidths or {}
        if #list >= 3 then return Middle(list), true end
        return GUESS_DOT, false
    end

    local function LearnDot(width)
        if type(width) ~= "number" or width < 6 or width > 120 then return end
        if type(db.dotWidths) ~= "table" then db.dotWidths = {} end
        local list = db.dotWidths
        list[#list + 1] = width
        if #list > DOT_SAMPLES then table.remove(list, 1) end
    end
    local TINY = 0 -- icon scale while scanning: no dots or arrow left under the mouse
    local quietUntil = 0 -- the minimap's tooltip is closed until then
    local nextCheck = 0 -- when Scan by distance looks again
    local STILL_WAIT = 0.5 -- seconds the mouse stays put before a scan (Only while the mouse is still)
    local phase = 0 -- which of the three honeycombs this scan uses (see StartKeyScan)
    local scans = 0 -- scans so far (every third checks the symbols already measured)

    -- A controller's stick camera is mouselook to the game, but with hover events allowed in
    -- free look (on while a scan runs) the minimap can still be read under the hidden cursor.
    local function PadLooking()
        return C_GamePad and C_GamePad.IsEnabled and C_GamePad.IsEnabled() and IsGamePadFreelookEnabled and IsGamePadFreelookEnabled()
    end
    -- Walking with a controller's stick: the game centers the cursor and acts as if a mouse
    -- button is held (GamePadCursorCenteredEmulation), so that mustn't count as the mouse.
    local function PadSticks()
        if not (C_GamePad and C_GamePad.IsEnabled and C_GamePad.IsEnabled() and C_GamePad.GetDeviceMappedState) then return false end
        local ok, state = pcall(C_GamePad.GetDeviceMappedState)
        if not ok or issecretvalue(state) or type(state) ~= "table" or type(state.sticks) ~= "table" then return false end
        for _, stick in ipairs(state.sticks) do
            if type(stick) == "table" and not issecretvalue(stick.len) and type(stick.len) == "number" and stick.len > 0.2 then return true end
        end
        return false
    end
    -- With the controller's circle in the middle of the screen the game hovers nothing at
    -- all, so the minimap can't be read there. Only asked while the controller is in use: a
    -- mouse over a nameplate hovers nothing too.
    local function Hovering()
        if not (GetMouseFoci and IsUsingGamepad and IsUsingGamepad() == true) then return true end
        local foci = GetMouseFoci()
        return type(foci) ~= "table" or foci[1] ~= nil
    end
    -- Turning the camera with either mouse button (the left one doesn't count as mouselook),
    -- or nothing under the mouse at all (a controller's camera; in its free look a scan turns
    -- hovering on, so that waits for the scan).
    local function Mouselooking()
        local looking = (IsMouselooking and IsMouselooking() and not PadLooking())
            or (IsMouseButtonDown and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")))
        return (looking and not (PadSticks() and Hovering())) or not (PadLooking() or Hovering())
    end
    -- A mouse button down: a click, or the camera turned with it.
    local function Pressed()
        return IsMouseButtonDown and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton"))
            and not (PadSticks() and Hovering())
    end

    -- A window or button under the mouse that isn't the minimap's or NodeSight's (bags opened
    -- mid-scan, an item in them): the minimap can't be read through it.
    local COVERED_WAIT = 2 -- seconds a scan waits paused for the mouse to leave a window
    local LOOK_WAIT = 1 -- Fewer blinks: seconds the minimap stays hidden while the camera turns without a mouse button
    local BLIND_WAIT = 0.3 -- seconds a scan goes on with nothing under the mouse before it stops
    -- A frame drawn under the minimap (a UI addon's full-screen layer) doesn't count: the
    -- minimap is on top of it once it's under the mouse.
    local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
    local function Under(frame)
        local ok, strata, level = pcall(function() return frame:GetFrameStrata(), frame:GetFrameLevel() end)
        if not ok or issecretvalue(strata) or issecretvalue(level) then return false end
        local ours, ourLevel = Minimap:GetFrameStrata(), Minimap:GetFrameLevel()
        if issecretvalue(ours) or issecretvalue(ourLevel) then return false end
        local theirs, mine = STRATA[strata], STRATA[ours]
        if not (theirs and mine) then return false end
        return theirs < mine or (theirs == mine and level < ourLevel)
    end
    -- An NPC's window open (a vendor, quest giver, bank, mailbox, trade): no scans, so addons
    -- that sell or turn in quests right away aren't in a scan's way.
    local NPC_WINDOWS = { "TradePartner", "Gossip", "QuestGiver", "Merchant", "Banker", "MailInfo", "Auctioneer" }
    local function AtNpc()
        local types = Enum and Enum.PlayerInteractionType
        local manager = C_PlayerInteractionManager
        if not (types and manager and manager.IsInteractingWithNpcOfType) then return false end
        for _, name in ipairs(NPC_WINDOWS) do
            local open = types[name] and manager.IsInteractingWithNpcOfType(types[name])
            if not issecretvalue(open) and open then return true end
        end
        return false
    end
    local function Covered()
        local foci = GetMouseFoci and GetMouseFoci()
        local focus = type(foci) == "table" and foci[1] or nil
        if focus == nil or focus == WorldFrame then return false end
        local first = focus
        local riding = key.scan and key.scan.riding
        for _ = 1, 20 do
            if focus == nil then break end -- (the top: a window of its own)
            if focus == Minimap or focus == mapFrame or focus == arrow or (riding and riding[focus]) then return false end
            local ok, parent = pcall(focus.GetParent, focus)
            if not ok then break end
            focus = parent
        end
        return not Under(first)
    end

    -- Blizzard's coordinates under the minimap: anchored to it, so they move with it.
    local function Coords()
        local parent = Minimap:GetParent()
        return parent and parent.PlayerCoords
    end

    -- The dots' size set by Edit Mode's Icon Size (the minimap has no getter), to put back.
    local iconScale, ourScale = 1, false
    if Minimap.SetIconScale then
        hooksecurefunc(Minimap, "SetIconScale", function(_, scale)
            if not ourScale and type(scale) == "number" then iconScale = scale end
        end)
    end

    -- While scanning, the minimap is hidden by an empty mask, not alpha: the game draws its
    -- terrain blank if it redraws below alpha 1. The mask has no getter: the last one set is
    -- kept, else a square one if GetMinimapShape says so, else the game's own.
    local EMPTY_MASK = "Interface\\AddOns\\NodeSight\\EmptyMask"
    local FOREVER_MASK = "ui-hud-minimap-frame-generic-mask" -- set by Blizzard_Minimap before addons load
    local maskSet, ourMask
    if Minimap.SetMaskTexture then
        hooksecurefunc(Minimap, "SetMaskTexture", function(_, mask)
            if not ourMask then maskSet = mask end
        end)
    end
    local function Mask()
        if maskSet ~= nil then return maskSet end
        if GetMinimapShape then
            local ok, shape = pcall(GetMinimapShape)
            if ok and shape == "SQUARE" then return "Interface\\BUTTONS\\WHITE8X8" end
        end
        if C_Texture and C_Texture.GetAtlasExists and C_Texture.GetAtlasExists(FOREVER_MASK) then return FOREVER_MASK end
        return "Textures\\MinimapMask"
    end

    -- While scanning the minimap is under the mouse: its mouse wheel (zoom) and clicks
    -- (a ping) are off, so the wheel zooms the camera; hovering stays on for the scan.
    -- The group finder's eye is anchored to the minimap but not on it: hidden too.
    local function Apart(frame)
        return frame == mapFrame or frame == QueueStatusButton
    end
    -- No clicks or hover on a frame for the scan, given back with the minimap's own.
    local function QuietOne(s, frame)
        if Apart(frame) or (InCombatLockdown() and frame:IsProtected()) then return end
        if frame.IsMouseClickEnabled and frame:IsMouseClickEnabled() then
            s.noClicks[#s.noClicks + 1] = frame
            frame:SetMouseClickEnabled(false)
        end
        if frame.IsMouseMotionEnabled and frame:IsMouseMotionEnabled() then
            s.noMotion[#s.noMotion + 1] = frame
            frame:SetMouseMotionEnabled(false)
        end
    end
    local function QuietTree(s, parent, depth)
        if not parent.GetChildren then return end -- (text or a texture: no children)
        for _, child in ipairs({ parent:GetChildren() }) do
            if not issecretvalue(child) then
                QuietOne(s, child)
                if depth < 6 then QuietTree(s, child, depth + 1) end
            end
        end
    end

    -- Fade in and out: the frames the scan hid, fading back with the stand-in after it.
    local fadeBack = {}

    -- A frame hidden until the minimap is hovered (a UI's zoom buttons, addon buttons shown on
    -- mouseover), as it is in a scan: shrunk from the start, so it never shows at the mouse.
    -- (One that was shown and comes back: KeepHidden.)
    -- After the scan the minimap leaving the mouse reads as the mouse leaving it, and some show
    -- them a moment before fading them out (LibDBIcon: a second): they stay shrunk until
    -- hidden again, unless the mouse really is over the minimap.
    local settling, settledAt = {}, 0
    -- Hidden by its alpha or by Hide() (EllesmereUI's zoom buttons).
    local function Unseen(frame, alpha)
        if alpha == 0 then return true end
        local ok, shown = pcall(frame.IsShown, frame)
        return ok and not issecretvalue(shown) and not shown
    end
    local function ShrinkHidden(f)
        local was = settling[f.frame]
        if was then -- (still settling from the last scan or a pause: the alpha and size it had then)
            f.alpha, f.scale, f.hover = was.alpha, was.scale, true
            settling[f.frame] = nil
            return
        end
        if not Unseen(f.frame, f.alpha) then return end
        local fine, scale = pcall(f.frame.GetScale, f.frame)
        if fine and type(scale) == "number" and not issecretvalue(scale) and scale >= 0.01 then
            f.scale, f.hover = scale, true
            pcall(f.frame.SetScale, f.frame, 0.001)
        end
    end
    local function Unshrink(f)
        if f.hover then
            settling[f.frame], settledAt = { alpha = f.alpha, scale = f.scale }, GetTime()
        else
            pcall(f.frame.SetScale, f.frame, f.scale)
        end
    end
    -- A fade on the frame still to come or going (LibDBIcon's waits 1 s after the minimap
    -- leaves the mouse, then draws its buttons from 1 down to 0).
    local function Animating(frame)
        local ok, groups = pcall(function() return { frame:GetAnimationGroups() } end)
        if not ok then return false end
        for _, group in ipairs(groups) do
            local fine, playing = pcall(group.IsPlaying, group)
            if fine and not issecretvalue(playing) and playing then return true end
        end
        return false
    end
    -- Each frame without a scan: their size back once hidden again (or after 3 seconds).
    local function Settle()
        if not next(settling) then return end
        local wait = GetTime() - settledAt
        if wait < 0.3 then return end
        local over = Minimap:IsMouseOver()
        for frame, was in pairs(settling) do
            local ok, alpha = pcall(frame.GetAlpha, frame)
            if (over or wait > 3 or not ok or issecretvalue(alpha) or Unseen(frame, alpha) and not Animating(frame))
                and not (InCombatLockdown() and frame:IsProtected()) then
                pcall(frame.SetScale, frame, was.scale)
                settling[frame] = nil
            end
        end
    end

    -- Safety net: each frame a scan hid, as it was before the scan. 3 s after it, one still
    -- shrunk, or left invisible though it was seen before, is put back as it was.
    local guard, guardAt = {}, 0
    local function Remember(s, f)
        s.first = s.first or {}
        if s.first[f.frame] then return end -- (a pause: the first look stands)
        local scale = f.scale
        if scale == nil then
            local ok, now = pcall(f.frame.GetScale, f.frame)
            if ok and type(now) == "number" and not issecretvalue(now) then scale = now end
        end
        s.first[f.frame] = { alpha = f.alpha, scale = scale }
    end
    -- A frame on the minimap hidden as a scan starts (Questie keeps hundreds of hidden pins
    -- there) is left alone: it draws nothing and takes no mouse. Shown mid-scan (a UI's buttons
    -- shown on the minimap's hover), it's hidden and shrunk at once, as the others were.
    local hooked = setmetatable({}, { __mode = "k" })
    local function Shown(frame)
        local s = key.scan
        if not (s and s.waiting and s.waiting[frame]) then return end
        s.waiting[frame] = nil
        local ok, alpha = pcall(frame.GetAlpha, frame)
        if not ok or issecretvalue(alpha) or (InCombatLockdown() and frame:IsProtected()) then return end
        local kid = { frame = frame, alpha = alpha }
        s.kids[#s.kids + 1] = kid
        if s.kidSet then s.kidSet[frame] = true end
        frame:SetAlpha(0)
        if settling[frame] then
            ShrinkHidden(kid)
        else
            local fine, scale = pcall(frame.GetScale, frame)
            if fine and type(scale) == "number" and not issecretvalue(scale) and scale >= 0.01 then
                kid.scale, kid.hover = scale, true
                pcall(frame.SetScale, frame, 0.001)
            end
        end
        Remember(s, kid)
        if s.noClicks then
            QuietOne(s, frame)
            QuietTree(s, frame, 1)
        end
    end
    local function Wait(s, frame)
        local ok, shown = pcall(frame.IsShown, frame)
        if not ok or issecretvalue(shown) or shown or type(frame.HookScript) ~= "function" then return false end
        if not hooked[frame] then
            if not pcall(frame.HookScript, frame, "OnShow", Shown) then return false end
            hooked[frame] = true
        end
        s.waiting[frame] = true
        return true
    end
    local function Guard(s)
        for frame, first in pairs(s.first or {}) do
            first.restored = s.restored and s.restored[frame]
            guard[frame] = first
        end
        guardAt = GetTime() + 3
    end
    local function Recheck(now)
        if not next(guard) or not now and GetTime() < guardAt then return end
        local over = Minimap:IsMouseOver()
        for frame, first in pairs(guard) do
            local ok, protected = pcall(frame.IsProtected, frame)
            if not (InCombatLockdown() and (not ok or protected)) then
                local was = settling[frame] -- (its size is Settle's)
                local fine, scale = pcall(frame.GetScale, frame)
                if not was and fine and type(scale) == "number" and not issecretvalue(scale) and scale < 0.01
                    and type(first.scale) == "number" and first.scale >= 0.01 then
                    pcall(frame.SetScale, frame, first.scale)
                end
                local got, alpha = pcall(frame.GetAlpha, frame)
                local stuck = got and not issecretvalue(alpha) and alpha == 0 and first.restored == 0
                    and type(first.alpha) == "number" and first.alpha > 0
                if stuck and not over and not Animating(frame) then
                    pcall(frame.SetAlpha, frame, first.alpha)
                    if was then was.alpha = first.alpha end
                end
                if not (stuck and over) then guard[frame] = nil end -- (under the mouse: again once it leaves)
            end
        end
    end

    local ourPad = false
    -- A frame's middle on the screen, in screen units; nil if the game won't say.
    local function Spot(frame)
        local ok, x, y = pcall(frame.GetCenter, frame)
        local fine, scale = pcall(frame.GetEffectiveScale, frame)
        if not (ok and fine) or issecretvalue(x) or issecretvalue(y) or issecretvalue(scale)
            or type(x) ~= "number" or type(y) ~= "number" or type(scale) ~= "number" then return nil end
        return x * scale, y * scale
    end
    -- A frame that moves with the minimap: hidden, no clicks and no hover for the scan.
    local function Ride(s, frame, why)
        if s.riding[frame] then return end -- (once: a second time would note its alpha as 0)
        -- Never a frame the minimap is in: hiding it would hide the minimap.
        local holder = Minimap
        for _ = 1, 20 do
            local ok, parent = pcall(holder.GetParent, holder)
            if not ok or not parent then break end
            if parent == frame then return end
            holder = parent
        end
        local clicks = frame.IsMouseClickEnabled and frame:IsMouseClickEnabled()
        local motion = frame.IsMouseMotionEnabled and frame:IsMouseMotionEnabled()
        local follower = { frame = frame, alpha = s.orig and s.orig[frame] or frame:GetAlpha(), clicks = clicks, motion = motion }
        s.followers[#s.followers + 1] = follower
        frame:SetAlpha(0)
        ShrinkHidden(follower)
        Remember(s, follower)
        if clicks then frame:SetMouseClickEnabled(false) end
        if motion then frame:SetMouseMotionEnabled(false) end
        -- Its buttons too (the mail icon a minimap addon put there).
        if s.noClicks then QuietTree(s, frame, 1) end
        s.riding[frame] = true
        if why then ns.LogOnce(frame, ("hid %s while scanning: %s"):format(ns.NameOf(frame), why)) end
    end

    local function DisguiseNow(s, on)
        if on and s.wheel == nil and Minimap.IsMouseWheelEnabled and Minimap.IsMouseClickEnabled then
            s.wheel, s.clicks = Minimap:IsMouseWheelEnabled(), Minimap:IsMouseClickEnabled()
        end
        if s.wheel ~= nil then
            pcall(Minimap.EnableMouseWheel, Minimap, not on and s.wheel)
            pcall(Minimap.SetMouseClickEnabled, Minimap, not on and s.clicks)
        end
        if Minimap.SetMaskTexture then
            -- The empty mask goes past hooks on the frame: one that puts its own mask back at once
            -- (Leatrix Plus' square minimap) would undo it. The real one goes back the usual way.
            local set = Minimap.SetMaskTexture
            local mt = on and getmetatable(Minimap)
            if type(mt) == "table" and type(mt.__index) == "table" and type(mt.__index.SetMaskTexture) == "function" then
                set = mt.__index.SetMaskTexture
            end
            ourMask = true
            pcall(set, Minimap, on and EMPTY_MASK or Mask())
            ourMask = false
        else
            pcall(Minimap.SetAlpha, Minimap, on and 0 or s.alpha)
        end
        -- The mask clips only the map: the frames on it (its ring, the zoom buttons, addons'
        -- buttons) are hidden by their own alpha, which doesn't touch the map's drawing.
        -- Hidden ones too: some fade in when the minimap is hovered (KeepHidden).
        -- Text and textures drawn on the minimap itself (a UI's coordinates) the same way.
        if on and Minimap.SetMaskTexture and not s.kids then
            s.kids, s.kidCount, s.waiting = {}, Minimap:GetNumChildren(), {}
            local parts = { Minimap:GetChildren() }
            for _, region in ipairs({ Minimap:GetRegions() }) do parts[#parts + 1] = region end
            for _, child in ipairs(parts) do
                local ok, alpha = false, nil
                if not issecretvalue(child) then ok, alpha = pcall(child.GetAlpha, child) end
                if ok and not Apart(child) and not issecretvalue(alpha) and not settling[child]
                    and not (InCombatLockdown() and child:IsProtected()) and Wait(s, child) then
                    -- (hidden: left until it shows, with the alpha a fade-in took back)
                    if s.orig and s.orig[child] then pcall(child.SetAlpha, child, s.orig[child]) end
                elseif ok and not Apart(child) and not issecretvalue(alpha)
                    and not (InCombatLockdown() and child:IsProtected()) then
                    local kid = { frame = child, alpha = s.orig and s.orig[child] or alpha }
                    s.kids[#s.kids + 1] = kid
                    child:SetAlpha(0)
                    ShrinkHidden(kid)
                    Remember(s, kid)
                end
            end
        elseif not on and s.kids then
            s.restored = s.restored or {}
            for _, kid in ipairs(s.kids) do
                pcall(kid.frame.SetAlpha, kid.frame, kid.alpha)
                if kid.scale then Unshrink(kid) end
                s.restored[kid.frame] = kid.alpha
            end
            s.kids, s.kidSet, s.waiting = nil, nil, nil
        end
        if not on and s.orig then -- (a fade-in cut short)
            s.restored = s.restored or {}
            for frame, alpha in pairs(s.orig) do
                pcall(frame.SetAlpha, frame, alpha)
                s.restored[frame] = alpha
            end
            s.orig = nil
        end
        -- Playing with a controller: hover events in free look, so the minimap is read under the
        -- stick camera. Only while the controller is in use: a mouse player's is left alone.
        if on and s.padHover == nil and C_GamePad and C_GamePad.IsEnabled and C_GamePad.IsEnabled()
            and IsUsingGamepad and IsUsingGamepad() == true and C_GamePad.GetAllowHoverEventsWithFreeLook then
            s.padHover = C_GamePad.GetAllowHoverEventsWithFreeLook() and true or false
        end
        if s.padHover == false then
            ourPad = true
            pcall(C_GamePad.SetAllowHoverEventsWithFreeLook, on)
            ourPad = false
            NodeSightDB.padHoverOn = on or nil -- (a game setting: put back at the next login if putting it back fails)
        end
        if s.coords then pcall(s.coords.SetAlpha, s.coords, on and 0 or s.coordsAlpha) end
        if Minimap.SetIconScale then
            ourScale = true
            pcall(Minimap.SetIconScale, Minimap, on and TINY or db.dotScale ~= NORMAL_DOTS and db.dotScale / 100 or iconScale)
            ourScale = false
        end
        -- Buttons on the minimap (an addon's calendar or clock, map pins) move with it under the
        -- mouse: no clicks on them either (a quick click would land on one), back after.
        -- No hover either: a frame over the whole map (BasicMinimap's click catcher) would be
        -- under the mouse instead of the minimap, and the game names no dot then.
        -- The game's protected ones can't be changed in a fight: left alone.
        if on and not s.noClicks then
            s.noClicks, s.noMotion = {}, {}
            local function Walk(frame, depth)
                for _, child in ipairs({ frame:GetChildren() }) do
                    if s.waiting and s.waiting[child] then
                        -- (hidden: quieted when it shows)
                    else
                        if not Apart(child) and child.IsMouseClickEnabled and child:IsMouseClickEnabled()
                            and not (InCombatLockdown() and child:IsProtected()) then
                            s.noClicks[#s.noClicks + 1] = child
                            child:SetMouseClickEnabled(false)
                        end
                        if not Apart(child) and child.IsMouseMotionEnabled and child:IsMouseMotionEnabled()
                            and not (InCombatLockdown() and child:IsProtected()) then
                            s.noMotion[#s.noMotion + 1] = child
                            child:SetMouseMotionEnabled(false)
                        end
                        if depth < 6 then Walk(child, depth + 1) end
                    end
                end
            end
            pcall(Walk, Minimap, 1)
            -- The group finder's eye moves with the minimap too, and the animated eye in it
            -- takes the mouse (it looks up when hovered).
            if QueueStatusButton then pcall(QuietTree, s, QueueStatusButton, 1) end
        elseif not on and s.noClicks then
            for _, child in ipairs(s.noClicks) do pcall(child.SetMouseClickEnabled, child, true) end
            for _, child in ipairs(s.noMotion) do pcall(child.SetMouseMotionEnabled, child, true) end
            s.noClicks, s.noMotion = nil, nil
        end
        local eye = QueueStatusButton
        if eye then
            if on and s.eyeAlpha == nil then s.eyeAlpha, s.eyeMouse = eye:GetAlpha(), eye:IsMouseEnabled() end
            if s.eyeAlpha ~= nil then
                pcall(eye.SetAlpha, eye, on and 0 or s.eyeAlpha)
                pcall(eye.EnableMouse, eye, not on and s.eyeMouse)
            end
        end
        -- Frames anchored to the minimap from outside it (a UI addon's border, a clock or the
        -- day/night dial moved onto it) move with it but don't fade with it: hidden too, no
        -- clicks and no hover (one above the minimap would pause the scan every other frame).
        if on and not s.followers then
            s.followers, s.riding = {}, {}
            local seen = { [mapFrame] = "own", [arrow] = "own" } -- (the eye and the coordinates have their own)
            if QueueStatusButton then seen[QueueStatusButton] = "own" end
            -- (Left anchored to the minimap by its last tooltip: closed by its OnShow hook instead.)
            seen[GameTooltip] = "own"
            if s.coords then seen[s.coords] = "own" end
            local function Inside(frame)
                for _ = 1, 10 do
                    if frame == Minimap then return true end
                    local ok, parent = pcall(frame.GetParent, frame)
                    if not ok or not parent then return false end
                    frame = parent
                end
                return false
            end
            -- Each frame answered once: frames anchored by two points each (a grid) would
            -- otherwise be walked again for every path through them.
            local answered = {}
            local function Follows(frame)
                if answered[frame] ~= nil then return answered[frame] end
                answered[frame] = false
                local ok, count = pcall(frame.GetNumPoints, frame)
                if not ok or type(count) ~= "number" or issecretvalue(count) then return false end
                for i = 1, count do
                    local fine, _, relative = pcall(frame.GetPoint, frame, i)
                    if fine and type(relative) == "table" and not issecretvalue(relative)
                        and (Inside(relative) or Follows(relative)) then
                        answered[frame] = true
                        return true
                    end
                end
                return false
            end
            local function Look(parent, depth)
                local ok, kids = pcall(function() return { parent:GetChildren() } end)
                if not ok then return end
                for _, frame in ipairs(kids) do
                    if not seen[frame] and frame ~= Minimap then
                        seen[frame] = true
                        if Follows(frame) and not Inside(frame) and not (InCombatLockdown() and frame:IsProtected())
                            and not issecretvalue(frame:GetAlpha()) then
                            Ride(s, frame, "anchored to the minimap")
                        elseif depth < 3 and parent ~= UIParent then
                            Look(frame, depth + 1)
                        end
                    end
                end
            end
            pcall(Look, UIParent, 1)
            if MinimapCluster then pcall(Look, MinimapCluster, 1) end
            -- Frames an addon's code places where the minimap is (not anchored to it) move
            -- with it too: each shown frame's place now, for Trailing and Unhover to compare.
            -- Those near the minimap are watched all scan. Hide frames that follow the minimap (Beta).
            if db.trailFrames then
                local ok, problem = pcall(function()
                    local mx, my = Spot(Minimap)
                    if not mx then return end
                    local size = Minimap:GetWidth() * Minimap:GetEffectiveScale()
                    local reach = size * 1.5
                    local list, places, count = {}, {}, 0
                    -- Each frame on its own: some of the game's own are off-limits to addons,
                    -- and one that errors mustn't cost the others.
                    local function Add(frame, depth)
                        if issecretvalue(frame) or s.riding[frame] or seen[frame] == "own" or frame == GameTooltip then return end
                        local fine, shown, kids = pcall(function()
                            local forbidden = frame.IsForbidden and frame:IsForbidden()
                            if issecretvalue(forbidden) or forbidden or Inside(frame) or not frame:IsVisible() then return false end
                            return true, depth < 2 and { frame:GetChildren() } or nil
                        end)
                        if not (fine and shown) then return end
                        local x, y = Spot(frame)
                        -- (A frame over twice the minimap's size is a UI's layer or a window, not a follower.)
                        local ok, w, h = pcall(function() return frame:GetWidth() * frame:GetEffectiveScale(), frame:GetHeight() * frame:GetEffectiveScale() end)
                        if not ok or issecretvalue(w) or issecretvalue(h) or w > size * 2 or h > size * 2 then x = nil end
                        if x then
                            places[frame], count = { x = x, y = y }, count + 1
                            if (x - mx) ^ 2 + (y - my) ^ 2 <= reach ^ 2 then list[#list + 1] = { frame = frame, x = x, y = y } end
                        end
                        for _, kid in ipairs(kids or {}) do Add(kid, depth + 1) end
                    end
                    for _, frame in ipairs({ UIParent:GetChildren() }) do Add(frame, 1) end
                    s.trail = { x = mx, y = my, list = list, places = places, moves = {} }
                    ns.LogOnce("watching", ("watching %d frames for ones that follow the minimap, %d near it"):format(count, #list))
                end)
                if not ok then ns.LogOnce("watch error", "couldn't note the frames' places: " .. tostring(problem)) end
            end
        elseif not on and s.followers then
            s.restored = s.restored or {}
            for _, f in ipairs(s.followers) do
                pcall(f.frame.SetAlpha, f.frame, f.alpha)
                if f.scale then Unshrink(f) end
                s.restored[f.frame] = f.alpha
                if f.clicks then pcall(f.frame.SetMouseClickEnabled, f.frame, true) end
                if f.motion then pcall(f.frame.SetMouseMotionEnabled, f.frame, true) end
            end
            s.followers, s.riding, s.trail = nil, nil, nil
        end
        ns.HideQuestAreas(s, on)
    end
    local function Disguise(s, on)
        local t = Now()
        DisguiseNow(s, on)
        Took(s, on and "hiding setup" or "putting back", t)
    end

    -- Each frame of a scan: frames that faded in (an addon's buttons shown on the minimap's
    -- hover) hidden again. One that comes back (an addon raising it on a timer, between our
    -- frames) is also shrunk out of sight for the rest of the scan; its size back after.
    -- A shrunk one can't be seen whatever its alpha: looked at every 4th frame (Questie keeps
    -- hundreds of hidden pins on the minimap).
    local function KeepHidden(s)
        s.turn = (s.turn or 0) + 1
        local turn, count, shrunk = s.turn % 4, 0, 0
        for _, list in ipairs({ s.kids, s.followers }) do
            count = count + #list
            for i, f in ipairs(list) do
                if f.scale then shrunk = shrunk + 1 end
                local ok, alpha = false, nil
                if not f.scale or i % 4 == turn then ok, alpha = pcall(f.frame.GetAlpha, f.frame) end
                if ok and not issecretvalue(alpha) and alpha > 0 then
                    pcall(f.frame.SetAlpha, f.frame, 0)
                    local fine, scale = pcall(f.frame.GetScale, f.frame)
                    if f.scale == nil and fine and type(scale) == "number" and not issecretvalue(scale) then
                        f.scale = scale
                        pcall(f.frame.SetScale, f.frame, 0.001)
                    end
                end
            end
        end
        if count > (s.hidMost or 0) then s.hidMost, s.shrunkMost = count, shrunk end
    end

    -- Mappy fades its minimap buttons in while the minimap is hovered, as it is in a scan,
    -- setting their alpha every frame of the fade: hidden again right after.
    local mappyHooked = false
    local function HookMappy()
        if mappyHooked or type(Mappy) ~= "table" or type(Mappy.SetButtonsAlpha) ~= "function" then return end
        mappyHooked = true
        hooksecurefunc(Mappy, "SetButtonsAlpha", function()
            if key.scan then KeepHidden(key.scan) end
        end)
    end

    -- Frames put on the minimap mid-scan (a map pin added): hidden and quiet too.
    -- May ride: not protected in a fight, its alpha readable.
    local function Rideable(frame)
        return not (InCombatLockdown() and frame:IsProtected()) and not issecretvalue(frame:GetAlpha())
    end
    -- Each frame of a scan: a frame near the minimap that has moved just as far as the minimap
    -- has at one of its last 30 places (code that places it a frame late or on a timer) rides
    -- with it.
    local MOVES_KEPT = 30
    local function Trailing(s)
        local trail = s.trail
        if not trail or not s.followers then return end
        local mx, my = Spot(Minimap)
        if not mx then
            s.trail = nil
            return
        end
        local moves, dx, dy = trail.moves, mx - trail.x, my - trail.y
        if not (moves[1] and moves[1][1] == dx and moves[1][2] == dy) then
            table.insert(moves, 1, { dx, dy })
            moves[MOVES_KEPT + 1] = nil
        end
        for i = #trail.list, 1, -1 do
            local f = trail.list[i]
            local x, y = Spot(f.frame)
            local fx, fy = x and x - f.x, y and y - f.y
            if fx and fx * fx + fy * fy >= 100 and Rideable(f.frame) then -- (moved: not just a frame that stays)
                for _, move in ipairs(moves) do
                    if math.abs(fx - move[1]) < 0.5 and math.abs(fy - move[2]) < 0.5 then
                        table.remove(trail.list, i)
                        Ride(s, f.frame, "it moves with the minimap")
                        break
                    end
                end
            end
        end
    end

    local function Adopt(s)
        if not s.kids or not s.noClicks then return end
        local count = Minimap:GetNumChildren()
        if issecretvalue(count) or count == s.kidCount then return end
        s.kidCount = count
        local known = s.kidSet
        if not known then
            known = {}
            for _, kid in ipairs(s.kids) do known[kid.frame] = true end
            s.kidSet = known
        end
        for _, child in ipairs({ Minimap:GetChildren() }) do
            if not known[child] and not issecretvalue(child) and not Apart(child) and not (s.waiting and s.waiting[child])
                and not (InCombatLockdown() and child:IsProtected()) then
                local ok, alpha = pcall(child.GetAlpha, child)
                if ok and not issecretvalue(alpha) then
                    s.kids[#s.kids + 1] = { frame = child, alpha = alpha } -- (KeepHidden hides it)
                    known[child] = true
                    Remember(s, s.kids[#s.kids])
                    QuietOne(s, child)
                    QuietTree(s, child, 1)
                end
            end
        end
    end

    -- Anything on the minimap, or riding with it, that still has the mouse: quieted now (the
    -- game names no dot while another frame has the mouse; Covered counts it as no window,
    -- so its tooltip is closed like the minimap's).
    local function Unhover(s)
        if not s.noMotion then return end
        local foci = GetMouseFoci and GetMouseFoci()
        local focus = type(foci) == "table" and foci[1] or nil
        if focus == nil or issecretvalue(focus) or focus == Minimap or focus == WorldFrame or focus == arrow or Apart(focus) then return end
        local tied, frame = s.riding and s.riding[focus], focus
        for _ = 1, 20 do
            if tied then break end
            local ok, parent = pcall(frame.GetParent, frame)
            if not ok or not parent then break end
            tied = parent == Minimap or (s.riding and s.riding[parent])
            frame = parent
        end
        -- Under the mouse and moved since the scan began (Trailing didn't catch it: it isn't
        -- quite where the minimap went): it rides too, so its tooltip closes like any other in a
        -- scan. A window that stays where it was (bags) is left alone: it pauses the scan.
        local places = not tied and s.trail and s.trail.places
        frame = focus
        for _ = 1, 20 do
            if not places then break end
            local was = places[frame]
            if was then
                local x, y = Spot(frame)
                if x and (x - was.x) ^ 2 + (y - was.y) ^ 2 >= 4 and Rideable(frame) then
                    places[frame], tied = nil, true
                    Ride(s, frame, "it moved under the mouse")
                end
                break
            end
            local ok, parent = pcall(frame.GetParent, frame)
            if not ok or not parent then break end
            frame = parent
        end
        if tied then QuietOne(s, focus) end
    end

    -- Clicks and hover can't be given back to a protected frame in a fight: a scan that
    -- took them stops as the fight starts, while that's still allowed.
    function key.HoldsProtected()
        local s = key.scan
        if not s then return false end
        local function Any(list, field)
            for _, f in ipairs(list or {}) do
                local frame = field and f[field] or f
                local ok, protected = pcall(frame.IsProtected, frame)
                if ok and protected then return true end
            end
            return false
        end
        return Any(s.noClicks) or Any(s.noMotion) or Any(s.followers, "frame")
    end
    -- Something else (Blizzard's gamepad menus) changed the hover switch mid-scan: theirs to keep.
    function key.PadHoverChanged()
        if not ourPad and key.scan then key.scan.padHover, NodeSightDB.padHoverOn = nil, nil end
    end

    -- Stand-in while the minimap moves about unseen: our symbols' frame goes onto UIParent
    -- over the minimap's spot (same size and scale), over copies of a dark ground, its gold
    -- frame, your arrow and the coordinates; all back after.
    local stand -- the copies' frame
    local StandDecor -- (below)

    -- A region's offset from the minimap's middle and its size, in stand units (eff: stand's scale).
    local function Measure(region, eff)
        local x, y = region:GetCenter()
        local mx, my = Minimap:GetCenter()
        local own = region:GetEffectiveScale()
        if not (x and mx) or issecretvalue(x) or issecretvalue(y) or issecretvalue(own) then return nil end
        return (x * own - mx * Minimap:GetEffectiveScale()) / eff, (y * own - my * Minimap:GetEffectiveScale()) / eff,
            region:GetWidth() * own / eff, region:GetHeight() * own / eff
    end

    -- What the minimap's own frames draw (a UI's border, buttons that stay shown) leaves with
    -- the minimap as a scan moves it: copied onto the stand-in at full strength, so it stays
    -- put while the real ones fade out under the copies. Their text too (a UI's clock and zone
    -- name). No masked texture (a round icon), none under the map.
    -- Loaded before it's first drawn: the first scan after a login would show it late.
    local function Ready(texture) texture:SetBlockingLoadsRequested(true) end
    local DECOR_LAYERS = { "BORDER", "ARTWORK", "OVERLAY" }
    local LAYER_ORDER = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4, HIGHLIGHT = 5 }
    local function Readable(...)
        for i = 1, select("#", ...) do
            local v = select(i, ...)
            if v == nil or issecretvalue(v) then return false end
        end
        return true
    end
    local function CopyTexture(copy, real, alpha, eff)
        local x, y, w, h = Measure(real, eff)
        if not x then return false end
        local atlas = real:GetAtlas()
        if atlas and not issecretvalue(atlas) then
            copy:SetAtlas(atlas)
        else
            local file = real:GetTexture()
            local coords = { real:GetTexCoord() }
            if not Readable(file) or not Readable(unpack(coords, 1, 8)) then return false end
            copy:SetTexture(file)
            copy:SetTexCoord(unpack(coords, 1, 8))
        end
        local r, g, b = real:GetVertexColor()
        if not Readable(r, g, b) then r, g, b = 1, 1, 1 end
        copy:SetVertexColor(r, g, b)
        copy:SetAlpha(alpha)
        local blend = real:GetBlendMode()
        copy:SetBlendMode(Readable(blend) and blend or "BLEND")
        local turn = real:GetRotation()
        copy:SetRotation(Readable(turn) and turn or 0)
        local gray = real.GetDesaturation and real:GetDesaturation()
        copy:SetDesaturation(Readable(gray) and gray or 0)
        copy:SetHorizTile(real:GetHorizTile() and true or false)
        copy:SetVertTile(real:GetVertTile() and true or false)
        copy:SetSize(w, h)
        copy:ClearAllPoints()
        copy:SetPoint("CENTER", stand.decor, "CENTER", x, y)
        return true
    end
    local function CopyText(copy, real, alpha, eff)
        local x, y, w, h = Measure(real, eff)
        local font, size, flags = real:GetFont()
        local text, own = real:GetText(), real:GetEffectiveScale()
        if not x or not Readable(font, size, text, own) then return false end
        copy:SetFont(font, size * own / eff, Readable(flags) and flags or "")
        copy:SetText(text)
        local r, g, b = real:GetTextColor()
        if not Readable(r, g, b) then r, g, b = 1, 1, 1 end
        copy:SetTextColor(r, g, b)
        copy:SetAlpha(alpha)
        local justify = real:GetJustifyH()
        copy:SetJustifyH(Readable(justify) and justify or "CENTER")
        copy:SetWordWrap(false)
        copy:SetSize(w, h)
        copy:ClearAllPoints()
        copy:SetPoint("CENTER", stand.decor, "CENTER", x, y)
        return true
    end
    -- Hidden by a finished fade that keeps its last alpha (LibDBIcon's buttons shown on
    -- hover): GetAlpha still says 1.
    local function Faded(frame)
        for _, group in ipairs({ frame:GetAnimationGroups() }) do
            if group:IsDone() and group:IsSetToFinalAlpha() then
                local last
                for _, anim in ipairs({ group:GetAnimations() }) do
                    if anim:GetObjectType() == "Alpha" then last = anim end
                end
                local to = last and last:GetToAlpha()
                if Readable(to) and to == 0 then return true end
            end
        end
        return false
    end
    -- Map icons placed by HereBeDragons (Questie's own copy of it, GatherMate2, HandyNotes,
    -- TomTom): they stay put in the world, so their copies move with you. Not one floating
    -- on the minimap's edge.
    local PIN_LIBS = { "HereBeDragons-Pins-2.0", "HereBeDragonsQuestie-Pins-2.0" }
    local function MapIcon(frame)
        local stub = _G.LibStub
        if type(stub) ~= "table" or type(stub.GetLibrary) ~= "function" then return false end
        for _, name in ipairs(PIN_LIBS) do
            local ok, lib = pcall(stub.GetLibrary, stub, name, true)
            local data = ok and type(lib) == "table" and type(lib.minimapPins) == "table" and lib.minimapPins[frame]
            if type(data) == "table" then return not data.onEdge end
        end
        return false
    end
    function StandDecor(eff)
        local found, words, base = {}, {}, Minimap:GetFrameLevel()
        stand.moving = {}
        local wx, wy = UnitPosition("player")
        stand.from = Readable(wx, wy) and { x = wx, y = wy, facing = PlayerFacing() } or nil
        local icon -- (the Minimap child walked now, when it's a map icon)
        local function Walk(frame, depth)
            if issecretvalue(frame) or Apart(frame) or not frame:IsVisible() or Faded(frame) then return end
            local level, seen = frame:GetFrameLevel(), frame:GetEffectiveAlpha()
            if not Readable(level, seen) or level < base or seen <= 0 then return end
            for _, region in ipairs({ frame:GetRegions() }) do
                local kind = not issecretvalue(region) and region:GetObjectType()
                if #words < 20 and kind == "FontString" and region:IsVisible() then
                    local alpha, text = region:GetAlpha(), region:GetText()
                    if Readable(alpha, text) and alpha > 0 and text ~= "" then
                        words[#words + 1] = { region = region, alpha = seen * alpha }
                    end
                elseif #found < 200 and kind == "Texture" and region ~= MinimapCompassTexture and region:IsVisible() then
                    local alpha, masks = region:GetAlpha(), region:GetNumMaskTextures()
                    local layer, sub = region:GetDrawLayer()
                    -- (Not a button's hover glow: the HIGHLIGHT layer is drawn only under the mouse.)
                    if Readable(alpha, masks, layer, sub) and alpha > 0 and masks == 0 and layer ~= "HIGHLIGHT" then
                        found[#found + 1] = { region = region, alpha = seen * alpha, order = level * 100 + (LAYER_ORDER[layer] or 3) * 20 + sub, icon = icon }
                    end
                end
            end
            if depth < 4 then
                for _, child in ipairs({ frame:GetChildren() }) do Walk(child, depth + 1) end
            end
        end
        for _, child in ipairs({ Minimap:GetChildren() }) do
            icon = stand.from and not issecretvalue(child) and MapIcon(child) or nil
            pcall(Walk, child, 1)
        end
        table.sort(found, function(a, b) return a.order < b.order end)
        local used = 0
        for _, f in ipairs(found) do
            local copy = stand.copies[used + 1]
            if not copy then
                copy = stand.decor:CreateTexture()
                Ready(copy)
                stand.copies[used + 1] = copy
            end
            local slot = math.min(used, #DECOR_LAYERS * 16 - 1)
            copy:SetDrawLayer(DECOR_LAYERS[math.floor(slot / 16) + 1], slot % 16 - 8)
            local ok, laid = pcall(CopyTexture, copy, f.region, f.alpha, eff)
            if ok and laid then
                copy:Show()
                used = used + 1
                if f.icon then
                    local _, _, _, x, y = copy:GetPoint(1)
                    stand.moving[#stand.moving + 1] = { copy = copy, x = x, y = y }
                end
            end
        end
        for i = used + 1, #stand.copies do stand.copies[i]:Hide() end
        used = 0
        for _, f in ipairs(words) do
            local copy = stand.words[used + 1]
            if not copy then
                copy = stand.decor:CreateFontString(nil, "OVERLAY", nil, 7)
                stand.words[used + 1] = copy
            end
            local ok, laid = pcall(CopyText, copy, f.region, f.alpha, eff)
            if ok and laid then
                copy:Show()
                used = used + 1
            end
        end
        for i = used + 1, #stand.words do stand.words[i]:Hide() end
    end

    local function StandArrow()
        if not stand or not stand:IsShown() then return end
        local rotating = C_CVar.GetCVar("rotateMinimap") == "1"
        local atlas = rotating and "Rotating-MinimapArrow" or "UI-HUD-Minimap-Arrow-Player"
        local angle = not rotating and PlayerFacing() or 0
        local coords = Coords()
        local text = coords and coords.CoordText and coords.CoordText:GetText()
        if issecretvalue(text) or not text then text = "" end
        -- Only what changed.
        if atlas ~= stand.atlas then stand.atlas = atlas stand.arrow:SetAtlas(atlas) end
        if angle ~= stand.angle then stand.angle = angle stand.arrow:SetRotation(angle) end
        if text ~= stand.text then stand.text = text stand.coords:SetText(text) end
    end

    local TILE = 1600 / 3 -- yards a minimap tile covers
    -- The game draws its minimap's pictures (ground, arrow, icons) this much darker.
    local MINIMAP_TINT = { 0.87, 0.84, 0.80 }
    local ARROW_TINT = { 1, 1, 0.97 } -- the arrow hardly at all
    local ART_TINT = { 0.6, 0.6, 0.6 } -- the world map's art: nearer the minimap's colors
    -- Glides between screen pixels as the minimap does, rather than stepping from one to the next.
    local function Smooth(texture)
        texture:SetSnapToPixelGrid(false)
        texture:SetTexelSnappingBias(0)
        Ready(texture)
    end

    -- Where you are in the world (yards) and the minimap's own pictures of that continent
    -- (MinimapTiles.lua), or nil: indoors the minimap shows the building's plan instead.
    local function Ground()
        local tiles = ns.MINIMAP_TILES
        if not tiles or IsIndoors() then return nil end
        local wx, wy, _, continent = UnitPosition("player")
        if issecretvalue(wx) or issecretvalue(wy) or issecretvalue(continent) or not (wx and wy and continent) then return nil end
        return tiles[continent], wx, wy
    end

    -- A map under the copies, centered on you at the minimap's zoom: the minimap's own
    -- pictures of the ground where the game has them, else the world map's art of the zone
    -- (its base art and the parts you explored, as the world map lays them). Each piece is
    -- cut to the minimap's square. Each frame of a scan it moves with you, as the minimap
    -- would; laid again only when something changed.
    -- Only with Map while scanning on; not with a rotating minimap, or where there's neither.
    local function StandArt(width, height, round)
        local radius = C_Minimap.GetViewRadius()
        local ground, wx, wy = Ground()
        local map, px, py, mapWidth, mapHeight
        if not ground then map, px, py, mapWidth, mapHeight = MapPosition() end
        if not ground and map ~= stand.artMap then -- the art's list: once a scan, and on a new map
            stand.artMap = map
            stand.layer = map and (C_Map.GetMapArtLayers(map) or {})[1]
            stand.files = stand.layer and C_Map.GetMapArtLayerTextures(map, 1)
            stand.explored = stand.files and C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures(map) or {}
        end
        local layer, files, explored = stand.layer, stand.files, stand.explored
        if not db.scanMap or not (ground or files and files[1]) or not radius or issecretvalue(radius) or radius <= 0
            or C_CVar.GetCVar("rotateMinimap") == "1" then
            for _, tile in ipairs(stand.tiles) do tile:Hide() end
            stand.artKey = nil
            return
        end
        local artKey = ground and table.concat({ "ground", wx, wy, radius, width, height, tostring(round) }, " ")
            or table.concat({ map, px, py, radius, width, height, tostring(round), layer.tileWidth, #files, #explored }, " ")
        if artKey == stand.artKey then return end
        stand.artKey = artKey
        local mask = round and stand.mask or nil
        local perYard = width / 2 / radius -- stand units per yard
        local hw, hh = width / 2, height / 2
        local used = 0
        -- One picture from left, top to right, bottom (stand units from its middle), filling
        -- umax, vmax of its file: the part inside the minimap's square, tinted.
        local function Put(file, left, top, right, bottom, umax, vmax, sublevel, tint)
            local l, r = math.max(left, -hw), math.min(right, hw)
            local t, b = math.min(top, hh), math.max(bottom, -hh)
            if l >= r or b >= t then return end
            used = used + 1
            local tile = stand.tiles[used]
            if not tile then
                tile = stand:CreateTexture(nil, "BACKGROUND", nil, 1)
                Smooth(tile)
                stand.tiles[used] = tile
            end
            if tile.tint ~= tint then tile.tint = tint tile:SetVertexColor(tint[1], tint[2], tint[3]) end
            if tile.mask ~= mask then
                if tile.mask then tile:RemoveMaskTexture(tile.mask) end
                if mask then tile:AddMaskTexture(mask) end
                tile.mask = mask
            end
            tile:SetDrawLayer("BACKGROUND", sublevel)
            tile:SetTexture(file, nil, nil, "TRILINEAR")
            tile:SetTexCoord((l - left) / (right - left) * umax, (r - left) / (right - left) * umax,
                (top - t) / (top - bottom) * vmax, (top - b) / (top - bottom) * vmax)
            tile:SetSize(r - l, t - b)
            tile:ClearAllPoints()
            tile:SetPoint("TOPLEFT", stand, "CENTER", l, t)
            tile:Show()
        end
        if ground then
            -- Tile x reaches from world Y (west) (32 - x) * TILE down, tile y from world X
            -- (north) (32 - y) * TILE down; north is up.
            local reach, size = math.max(hw, hh) / perYard, TILE * perYard
            for x = math.floor(32 - (wy + reach) / TILE), math.floor(32 - (wy - reach) / TILE) do
                for y = math.floor(32 - (wx + reach) / TILE), math.floor(32 - (wx - reach) / TILE) do
                    local file = ground[x * 64 + y]
                    if file then
                        local left, top = (wy - (32 - x) * TILE) * perYard, ((32 - y) * TILE - wx) * perYard
                        Put(file, left, top, left + size, top - size, 1, 1, 1, MINIMAP_TINT)
                    end
                end
            end
            for i = used + 1, #stand.tiles do stand.tiles[i]:Hide() end
            return
        end
        local sx, sy = perYard * mapWidth / layer.layerWidth, perYard * mapHeight / layer.layerHeight
        local tw, th = layer.tileWidth, layer.tileHeight
        -- One piece of art at x, y (from the map's top left) w by h in the art's units.
        local function Lay(file, x, y, w, h, umax, vmax, sublevel)
            local left, top = (x - px * layer.layerWidth) * sx, (py * layer.layerHeight - y) * sy
            Put(file, left, top, left + w * sx, top - h * sy, umax, vmax, sublevel, ART_TINT)
        end
        local cols = math.ceil(layer.layerWidth / tw)
        for row = 1, math.ceil(layer.layerHeight / th) do
            for col = 1, cols do
                Lay(files[(row - 1) * cols + col], (col - 1) * tw, (row - 1) * th, tw, th, 1, 1, 1)
            end
        end
        -- The explored parts: tiles of the art's size, the last ones in a row or column
        -- partly filled (their file rounded up to a power of two), as the world map does.
        for _, info in ipairs(explored) do
            if not info.isShownByMouseOver then
                local wide, tall = math.ceil(info.textureWidth / tw), math.ceil(info.textureHeight / th)
                for j = 1, tall do
                    local h, fileH = th, th
                    if j == tall then
                        h = info.textureHeight % th
                        if h == 0 then h = th end
                        fileH = 16
                        while fileH < h do fileH = fileH * 2 end
                    end
                    for k = 1, wide do
                        local w, fileW = tw, tw
                        if k == wide then
                            w = info.textureWidth % tw
                            if w == 0 then w = tw end
                            fileW = 16
                            while fileW < w do fileW = fileW * 2 end
                        end
                        Lay(info.fileDataIDs[(j - 1) * wide + k], info.offsetX + tw * (k - 1), info.offsetY + th * (j - 1),
                            w, h, w / fileW, h / fileH, info.isDrawOnTopLayer and 3 or 2)
                    end
                end
            end
        end
        for i = used + 1, #stand.tiles do stand.tiles[i]:Hide() end
    end

    -- Icons the minimap shows that the game also gives addons: flight masters, your quests
    -- (a ? when done) and rares or treasures, drawn around you at the minimap's zoom. The
    -- list is read once a scan (and on a new map); each frame they move as you walk.
    -- What you track (the minimap's tracking menu): its types (Enum.MinimapTrackingFilter)
    -- on, with each one's icon, in the menu's order; listed[type]: in the menu at all.
    -- Read again only once the menu changed, so a scan doesn't ask.
    local trackedOn, trackedListed
    function key.TrackingChanged() trackedOn = nil end
    local function Tracked()
        if trackedOn then return trackedOn, trackedListed end
        local on, listed = {}, {}
        trackedOn, trackedListed = on, listed
        local count = C_Minimap.GetNumTrackingTypes()
        if not Readable(count) or not C_Minimap.GetTrackingFilter then return on, listed end
        for i = 1, count do
            local info, filter = C_Minimap.GetTrackingInfo(i), C_Minimap.GetTrackingFilter(i)
            local id = Readable(filter) and filter.filterID
            if Readable(info, id) and id ~= 0 then
                listed[id] = true
                if Readable(info.active, info.texture) and info.active then on[#on + 1] = { id = id, icon = info.texture } end
            end
        end
        return on, listed
    end
    local TAXI = Enum.MinimapTrackingFilter and Enum.MinimapTrackingFilter.TaxiNode or 8
    local function PinList(map, on, listed)
        local list, areas = {}, {}
        local function Add(atlas, x, y)
            if Readable(atlas, x, y) and type(x) == "number" and type(y) == "number" then
                list[#list + 1] = { atlas = atlas, x = x, y = y }
            end
        end
        local flights = not listed[TAXI]
        for _, kind in ipairs(on) do flights = flights or kind.id == TAXI end
        if flights and C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap then
            for _, node in ipairs(C_TaxiMap.GetTaxiNodesForMap(map) or {}) do
                if node.position then Add("FlightMaster", node.position:GetXY()) end
            end
        end
        if C_QuestLog.GetQuestsOnMap then
            for _, quest in ipairs(C_QuestLog.GetQuestsOnMap(map) or {}) do
                local done = C_QuestLog.IsComplete(quest.questID)
                -- A quest not done: the minimap shows its area, not an icon.
                if Readable(done) and done then Add("QuestTurnin", quest.x, quest.y) end
                if Readable(done, quest.questID) and not done and type(quest.questID) == "number" then areas[#areas + 1] = quest.questID end
            end
        end
        if C_VignetteInfo and C_VignetteInfo.GetVignettes then
            for _, guid in ipairs(C_VignetteInfo.GetVignettes() or {}) do
                local info = Readable(guid) and C_VignetteInfo.GetVignetteInfo(guid)
                if info and Readable(info.onMinimap, info.isDead) and info.onMinimap and not info.isDead then
                    local at = C_VignetteInfo.GetVignettePosition(guid, map)
                    if Readable(at) then Add(info.atlasName, at:GetXY()) end
                end
            end
        end
        return list, areas
    end
    -- The town NPCs and mailboxes you track near you (TownNPCs.lua), each with the first of
    -- its types you track: { x, y (world yards north and west), icon }.
    local function TownList(continent, wx, wy, reach, on)
        local list, spots = {}, ns.TOWN_SPOTS and ns.TOWN_SPOTS[continent]
        if not spots or not on[1] then return list end
        for i = 1, #spots, 3 do
            local x, y, types = spots[i], spots[i + 1], spots[i + 2]
            if math.abs(x - wx) <= reach and math.abs(y - wy) <= reach then
                for _, kind in ipairs(on) do
                    if math.floor(types / kind.id) % 2 == 1 then
                        list[#list + 1] = { x = x, y = y, icon = kind.icon }
                        break
                    end
                end
            end
        end
        return list
    end
    -- The quest-area widget can't be masked round, so it's drawn in thin strips, each in a
    -- frame that cuts it to its own size: one for a square minimap, all for a round one.
    -- nil if the game has no such widget.
    local STRIPS = 32
    -- Quest outlines on the stand-in: off, as the game doesn't draw them there yet.
    ns.questOutlines = false
    local function AreaFrame()
        if stand.areas then return stand.areas end
        if stand.noAreas then return nil end
        local holder = CreateFrame("Frame")
        holder:SetParent(stand)
        holder:SetAllPoints()
        holder.strips = {}
        for i = 1, STRIPS do
            local ok, blob = pcall(CreateFrame, "QuestPOIFrame")
            if not ok or not blob or not blob.DrawBlob then
                stand.noAreas = true
                holder:Hide()
                return nil
            end
            local clip = CreateFrame("Frame")
            clip:SetParent(holder)
            clip:SetClipsChildren(true)
            blob:SetParent(clip)
            -- The minimap's own quest-area pictures; only the outline, as the minimap shows it.
            blob:SetFillTexture("Interface\\Minimap\\UI-QuestBlobMinimap-Inside")
            blob:SetBorderTexture("Interface\\Minimap\\UI-QuestBlobMinimap-Outside")
            blob:SetFillAlpha(0)
            blob:SetBorderAlpha(255)
            blob:SetBorderScalar(1)
            clip.blob = blob
            holder.strips[i] = clip
        end
        stand.areas = holder
        return holder
    end
    local function StandPins(width, height, round)
        local map, px, py, mapWidth, mapHeight = MapPosition()
        local radius = C_Minimap.GetViewRadius()
        local on = db.scanMap and map and Readable(radius) and radius > 0 and C_CVar.GetCVar("rotateMinimap") ~= "1"
        local wx, wy, _, continent = UnitPosition("player")
        if not Readable(wx, wy, continent) then wx = nil end
        if on and map ~= stand.pinMap then
            stand.pinMap = map
            local fine, tracked, listed = pcall(Tracked)
            if not fine then tracked, listed = {}, {} end
            local ok, list, areas = pcall(PinList, map, tracked, listed)
            stand.pinList, stand.areaList = ok and list or {}, ok and areas or {}
            local near, town = false, nil
            if wx then near, town = pcall(TownList, continent, wx, wy, radius * 3 + 300, tracked) end
            stand.townList = near and town or {}
        end
        local used = 0
        if on then
            local perYard, hw, hh = width / 2 / radius, width / 2, height / 2
            local size = 16 * (db.dotScale or 100) / 100 -- about the game's own icons, at the dots' size
            local function Pin(x, y, atlas, file)
                if round and x * x + y * y <= hw * hw or not round and math.abs(x) <= hw and math.abs(y) <= hh then
                    used = used + 1
                    local icon = stand.pins[used]
                    if not icon then
                        icon = stand:CreateTexture(nil, "ARTWORK")
                        Smooth(icon)
                        icon:SetVertexColor(MINIMAP_TINT[1], MINIMAP_TINT[2], MINIMAP_TINT[3])
                        stand.pins[used] = icon
                    end
                    if atlas then
                        icon:SetAtlas(atlas)
                    else
                        icon:SetTexture(file)
                        icon:SetTexCoord(0, 1, 0, 1) -- (an atlas set before keeps its part of the sheet)
                    end
                    icon:SetSize(size, size)
                    icon:ClearAllPoints()
                    icon:SetPoint("CENTER", stand, "CENTER", x, y)
                    icon:Show()
                end
            end
            for _, pin in ipairs(stand.pinList) do
                Pin((pin.x - px) * mapWidth * perYard, (py - pin.y) * mapHeight * perYard, pin.atlas)
            end
            if wx then
                for _, spot in ipairs(stand.townList) do
                    Pin((wy - spot.y) * perYard, (spot.x - wx) * perYard, nil, spot.icon)
                end
            end
        end
        for i = used + 1, #stand.pins do stand.pins[i]:Hide() end
        -- Quests' areas: their outlines, drawn by the game's own quest-area widget over the
        -- whole zone at the minimap's zoom, inside the minimap's shape. Only when the minimap
        -- showed them before the scan hid them.
        local scan = key.scan
        if ns.questOutlines and on and stand.areaList[1] and scan and scan.questIndex and C_CVar.GetCVar("questPOI") ~= "0" and AreaFrame() then
            local holder = stand.areas
            local perYard = width / 2 / radius
            local w, h = mapWidth * perYard, mapHeight * perYard
            local count = round and STRIPS or 1
            local areaKey = table.concat({ map, w, h, width, height, count, unpack(stand.areaList) }, " ")
            local level = stand:GetFrameLevel() + 1 -- over the ground and icons, under the copies
            for i, clip in ipairs(holder.strips) do
                local blob = clip.blob
                if i > count then
                    clip:Hide()
                else
                    if areaKey ~= holder.drawn then
                        -- A strip of a round minimap is as wide as the circle at its narrower
                        -- end, so none of it is outside.
                        local top = height / 2 - (i - 1) * height / count
                        local bottom = top - height / count
                        local half = width / 2
                        if round then
                            local far = (top > 0 and bottom < 0) and 0 or math.max(math.abs(top), math.abs(bottom))
                            half = math.sqrt(math.max(0, half * half - far * far))
                        end
                        clip:ClearAllPoints()
                        clip:SetPoint("TOPLEFT", stand, "CENTER", -half, top)
                        clip:SetSize(2 * half, height / count)
                        blob:SetSize(w, h)
                        blob:DrawNone()
                        blob:SetMapID(map)
                        for _, quest in ipairs(stand.areaList) do pcall(blob.DrawBlob, blob, quest, true) end
                    end
                    if clip:GetFrameLevel() ~= level then
                        clip:SetFrameLevel(level)
                        blob:SetFrameLevel(level)
                    end
                    blob:ClearAllPoints()
                    blob:SetPoint("TOPLEFT", stand, "CENTER", -px * w, py * h)
                    clip:Show()
                end
            end
            holder.drawn = areaKey
            holder:Show()
        elseif stand.areas then
            stand.areas:Hide()
        end
    end

    -- The stand-in fades in over the minimap before a scan moves it away, and out over it
    -- when it's back (Fade in and out): the minimap itself can't fade (drawn below full
    -- alpha it draws wrong), the stand-in over it can. Returns the seconds left to fade in.
    local FADE = 0.3
    local StandMove -- (below)
    -- The symbols' frame back on the minimap, at its own level, once the stand-in is gone.
    local mapHome -- its level on the minimap
    local function MapHome()
        if mapFrame:GetParent() == Minimap then return end
        mapFrame:SetParent(Minimap)
        mapFrame:SetScale(1)
        if mapHome then mapFrame:SetFrameLevel(mapHome) end
        mapFrame:ClearAllPoints()
        mapFrame:SetAllPoints(Minimap)
    end

    local function StandFading(self)
        StandMove() -- it goes on moving with you while it fades
        local t = (GetTime() - self.fadeAt) / FADE
        if t >= 1 then
            self:SetAlpha(self.fadeTo)
            self:SetScript("OnUpdate", nil)
            if self.fadeTo == 0 then
                self:Hide()
                MapHome()
            end
        else
            self:SetAlpha(self.fadeFrom + (self.fadeTo - self.fadeFrom) * t)
        end
        if self.fadeTo == 0 then -- the minimap's frames back as it goes
            local done = t >= 1
            for frame, alpha in pairs(fadeBack) do
                pcall(frame.SetAlpha, frame, done and alpha or alpha * (1 - self:GetAlpha()))
            end
            if done then wipe(fadeBack) end
        end
    end
    local function StandFade(to)
        if not db.scanFade then
            if stand:GetScript("OnUpdate") then stand:SetScript("OnUpdate", nil) end
            if stand:GetAlpha() ~= 1 then stand:SetAlpha(1) end
            stand:SetShown(to == 1)
            if to == 0 then MapHome() end
            return 0
        end
        local from = stand:IsShown() and stand:GetAlpha() or 0
        stand.fadeTo, stand.fadeFrom, stand.fadeAt = to, from, GetTime() - FADE * (to == 1 and from or 1 - from)
        stand:SetAlpha(from)
        stand:Show()
        stand:SetScript("OnUpdate", StandFading)
        return FADE * (1 - from) * to
    end

    local function PinSymbolsNow(s, on)
        if on then
            local left, bottom = Minimap:GetLeft(), Minimap:GetBottom()
            if not left or not bottom then return end
            local width, height = Minimap:GetWidth(), Minimap:GetHeight()
            local eff = Minimap:GetEffectiveScale()
            if mapFrame:GetParent() == Minimap then mapHome = mapFrame:GetFrameLevel() end
            s.pinned = { level = mapHome or mapFrame:GetFrameLevel() }
            if not stand then
                stand = CreateFrame("Frame")
                stand:SetParent(UIParent)
                stand:Hide() -- (shown by its fade)
                stand.ground = stand:CreateTexture(nil, "BACKGROUND")
                stand.ground:SetColorTexture(0, 0, 0, 0.35) -- light: the world shows through
                stand.mask = stand:CreateMaskTexture()
                stand.mask:SetAtlas(CIRCLE)
                stand.mask:SetAllPoints(stand.ground)
                stand.tiles = {}
                stand.decor = CreateFrame("Frame") -- copies of the minimap's own frames' pictures
                stand.decor:SetParent(stand)
                stand.decor:SetAllPoints()
                stand.decor:SetIgnoreParentAlpha(true)
                stand.copies, stand.words = {}, {}
                stand.pins = {}
                stand.round = false -- the mask goes on when the minimap is round
                stand.frame = stand:CreateTexture(nil, "OVERLAY")
                stand.arrow = stand:CreateTexture(nil, "OVERLAY", nil, 1)
                Ready(stand.arrow)
                stand.arrow:SetVertexColor(ARROW_TINT[1], ARROW_TINT[2], ARROW_TINT[3])
                stand.arrow:SetPoint("CENTER")
                stand.coords = stand:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                stand.dielBack = stand:CreateTexture(nil, "OVERLAY", nil, 2) -- the day/night dial, over the frame
                stand.dielRim = stand:CreateTexture(nil, "OVERLAY", nil, 3)
            end
            for _, f in ipairs({ stand, mapFrame }) do
                f:SetParent(UIParent)
                f:SetScale(eff / UIParent:GetEffectiveScale())
                f:SetFrameStrata(Minimap:GetFrameStrata())
                f:ClearAllPoints()
                f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
                f:SetSize(width, height)
            end
            -- Over the minimap, not level with it: of two frames of one level the game may draw
            -- either on top, and the fades would go on under the minimap. The symbols over it.
            stand:SetFrameLevel(math.max(Minimap:GetFrameLevel() + 1, s.pinned.level - 1))
            stand.decor:SetFrameLevel(stand:GetFrameLevel() + 2) -- over the symbols, as on the minimap
            StandDecor(eff)
            mapFrame:SetFrameLevel(stand:GetFrameLevel() + 1)
            -- Ground: round, or the square (maybe cropped) of a UI addon's minimap.
            local quarters = ns.MinimapQuarters()
            local round = (quarters[1] or quarters[2] or quarters[3] or quarters[4]) and true or false
            stand.ground:ClearAllPoints()
            stand.ground:SetPoint("CENTER")
            stand.ground:SetSize(width, round and height or height * (quarters.height or 1))
            if round ~= stand.round then
                stand.round = round
                if round then stand.ground:AddMaskTexture(stand.mask) else stand.ground:RemoveMaskTexture(stand.mask) end
            end
            stand.artWidth, stand.artHeight = width, round and height or height * (quarters.height or 1)
            stand.artMap, stand.pinMap = false, false
            StandArt(stand.artWidth, stand.artHeight, round)
            StandPins(stand.artWidth, stand.artHeight, round)
            -- Blizzard's gold frame, where shown (UI addons hide it).
            local compass = MinimapCompassTexture
            local cx, cy, cw, ch
            if compass and compass:IsVisible() and compass:GetAtlas() then cx, cy, cw, ch = Measure(compass, eff) end
            stand.frame:SetShown(cx ~= nil)
            if cx then
                stand.frame:SetAtlas(compass:GetAtlas())
                stand.frame:SetSize(cw, ch)
                stand.frame:SetPoint("CENTER", cx, cy)
            end
            -- Forever's day/night dial sits on the gold frame, beside the minimap (it doesn't move
            -- with it): copied over the copied frame too, so the frame's line doesn't cross it.
            -- Only as much as the real one is seen: a UI that hides or fades it does the same to the copy.
            local diel = MinimapCluster and MinimapCluster.DielFrame
            local seen = diel and diel:IsVisible() and diel.GetEffectiveAlpha and diel:GetEffectiveAlpha()
            if seen and (issecretvalue(seen) or seen <= 0) then seen = nil end
            local back = seen and diel.Background
            local rim
            if back then
                for _, region in ipairs({ diel:GetRegions() }) do
                    if region ~= back and region.GetAtlas and region:GetAtlas() then rim = region end
                end
            end
            for _, pair in ipairs({ { stand.dielBack, back }, { stand.dielRim, rim } }) do
                local copy, real = pair[1], pair[2]
                local x, y, w, h
                local alpha = real and real:IsShown() and real:GetAtlas() and real:GetAlpha()
                if alpha and (issecretvalue(alpha) or alpha <= 0) then alpha = nil end
                if alpha then x, y, w, h = Measure(real, eff) end
                copy:SetShown(x ~= nil)
                if x then
                    copy:SetAlpha(seen * alpha)
                    copy:SetAtlas(real:GetAtlas())
                    copy:SetSize(w, h)
                    copy:ClearAllPoints()
                    copy:SetPoint("CENTER", x, y)
                end
            end
            local size = 19 * (db.dotScale or 100) / 100 -- the game's arrow, at the dots' size
            stand.arrow:SetSize(size, size)
            -- The coordinates, where shown.
            local coords = Coords()
            local tx, ty
            if coords and coords.CoordText and coords:IsVisible() and coords:GetAlpha() > 0 then tx, ty = Measure(coords, eff) end
            stand.coords:SetShown(tx ~= nil)
            if tx then
                stand.coords:SetFontObject(coords.CoordText:GetFontObject() or GameFontHighlightSmall)
                stand.coords:SetPoint("CENTER", tx, ty)
            end
            s.fadeIn = StandFade(1) > 0 and GetTime() + FADE * (1 - stand:GetAlpha()) or nil
            StandArrow()
        elseif s.pinned then
            if db.scanFade then -- the frames the scan hid fade back with it
                for frame, alpha in pairs(s.restored or {}) do
                    pcall(frame.SetAlpha, frame, 0)
                    fadeBack[frame] = alpha
                end
            end
            s.restored = nil
            StandFade(0)
            s.pinned = nil
        end
    end
    local function PinSymbols(s, on)
        local t = Now()
        PinSymbolsNow(s, on)
        Took(s, "stand-in", t)
    end

    -- The names the minimap gives for where it was last frame; names.gray[name]: named
    -- in gray (in a cave).
    local function KeyNames()
        local data = C_TooltipInfo.GetMinimapMouseover()
        local lines = data and not issecretvalue(data) and data.lines
        local names = { gray = {} }
        if lines and not issecretvalue(lines) then
            for _, line in ipairs(lines) do
                local text = line.leftText
                local color = line.leftColor
                local gray = color and not issecretvalue(color) and Gray(color.r, color.g, color.b)
                if text and not issecretvalue(text) then
                    local list = NamesIn(text)
                    for i, name in ipairs(list) do
                        names[#names + 1] = name
                        local own = list.gray and list.gray[i]
                        if own == nil then own = gray end
                        if own then names.gray[name] = true end
                    end
                end
            end
        end
        return names
    end

    local function Has(names, want)
        for _, name in ipairs(names) do
            if name == want then return true end
        end
        return false
    end

    -- A move in yards east and north as minimap units (the rotating minimap turned).
    local function Units(east, north, half)
        local radius = C_Minimap.GetViewRadius()
        local facing = C_CVar.GetCVar("rotateMinimap") == "1" and PlayerFacing() or 0
        if not radius or issecretvalue(radius) or radius <= 0 or not facing then return nil end
        local length = math.sqrt(east * east + north * north) / radius * half
        local way = math.atan2(east, north) + facing
        return length * math.sin(way), length * math.cos(way)
    end

    -- Moving mid-scan: the whole scan is kept where the minimap was at its start.
    -- How far the minimap's picture moved since then, in minimap units (0, 0 if off or unknown).
    local function Drift(s)
        if not s.p0 then return 0, 0 end
        local map, x, y = MapPosition()
        if map ~= s.p0.map then return 0, 0 end
        local dx, dy = Units((x - s.p0.x) * s.p0.width, (s.p0.y - y) * s.p0.height, s.width / 2)
        return dx or 0, dy or 0
    end

    -- A minimap kept on screen (EllesmereUI's) would stop short of a mouse near the screen's
    -- edge: free while it's moved, as it was after.
    local function Unclamp(s)
        if s.clamped ~= nil or (InCombatLockdown() and Minimap:IsProtected()) then return end
        local ok, clamped = pcall(Minimap.IsClampedToScreen, Minimap)
        s.clamped = ok and not issecretvalue(clamped) and clamped == true
        if s.clamped then Minimap:SetClampedToScreen(false) end
    end
    local function Reclamp(s)
        if s.clamped and not (InCombatLockdown() and Minimap:IsProtected()) then Minimap:SetClampedToScreen(true) end
        s.clamped = nil
    end

    -- Puts spot i (where it was at the scan's start) under the mouse, where it will be next
    -- frame when the game looks (as far as it moved over the last frame).
    local function KeyPlaceNow(s, i)
        Unclamp(s)
        local spot = s.spots[i]
        local dx, dy = Drift(s)
        local scale = Minimap:GetEffectiveScale()
        local nowX, nowY = GetCursorPosition()
        local cx, cy = 2 * nowX - (s.lastX or nowX), 2 * nowY - (s.lastY or nowY)
        s.lastX, s.lastY = nowX, nowY
        local wantX, wantY = cx / scale - (spot[1] - dx) - s.left, cy / scale - (spot[2] - dy) - s.bottom
        Minimap:AdjustPointsOffset(wantX - s.ox, wantY - s.oy)
        s.ox, s.oy, s.at = wantX, wantY, i
        s.cx, s.cy, s.cursorScale = cx, cy, scale
    end
    local function KeyPlace(s, i)
        local t = Now()
        KeyPlaceNow(s, i)
        Took(s, "placing", t)
    end

    -- The mouse on the minimap's own place (the buttons round it too), where it is when not
    -- scanning: the player wants the minimap.
    local REACH = 16 -- how far past its edge counts (addons' buttons stick out)
    local function OnHome(s)
        local scale = Minimap:GetEffectiveScale()
        local x, y = GetCursorPosition()
        x, y = x / scale, y / scale
        return x > s.left - REACH and x < s.left + s.width + REACH and y > s.bottom - REACH and y < s.bottom + s.height + REACH
    end

    -- Hits of one name on neighbouring spots are one find, at their middle.
    local function KeyGroup(hits, step)
        local finds = {}
        for _, hit in ipairs(hits) do
            local into
            for _, find in ipairs(finds) do
                if find.name == hit.name then
                    for _, other in ipairs(find.hits) do
                        if (other.x - hit.x) ^ 2 + (other.y - hit.y) ^ 2 <= (step * 1.5) ^ 2 then into = find end
                    end
                end
            end
            if into then
                into.hits[#into.hits + 1] = hit
                into.dim = into.dim or hit.dim
            else
                finds[#finds + 1] = { name = hit.name, hits = { hit }, dim = hit.dim }
            end
        end
        for _, find in ipairs(finds) do
            local sx, sy, minX, maxX, minY, maxY = 0, 0, math.huge, -math.huge, math.huge, -math.huge
            for _, hit in ipairs(find.hits) do
                sx, sy = sx + hit.x, sy + hit.y
                minX, maxX = math.min(minX, hit.x), math.max(maxX, hit.x)
                minY, maxY = math.min(minY, hit.y), math.max(maxY, hit.y)
            end
            find.x, find.y = sx / #find.hits, sy / #find.hits
            find.spreadX, find.spreadY = maxX - minX, maxY - minY
            find.n, find.seeds, find.hits = #find.hits, find.hits, nil
        end
        return finds
    end

    -- The close-up pass: from a grid spot that named a find, the dot's edges are found one
    -- spot a frame: across through that spot (their middle is the dot's middle across),
    -- then up and down through that middle. Each edge: out a quarter dot at a time to the
    -- first miss, so it stops at this dot's edge and not at a neighbour's a gap further on,
    -- then halving between the last hit and that miss. Dots that overlap make one span,
    -- too wide for one dot.
    -- Symbols with another of their name within a dot and a fifth: in a pile, a spot between
    -- two nodes is still inside one of their dots, so a symbol there passes every check.
    -- They're measured each scan instead.
    local function Crowded()
        local crowded, reach = {}, (Dot() * 1.2) ^ 2
        for i, a in ipairs(markers) do
            for j = i + 1, #markers do
                local b = markers[j]
                if a.x and b.x and a.name == b.name and (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 <= reach then
                    crowded[a], crowded[b] = true, true
                end
            end
        end
        return crowded
    end

    local PRECISION = 1 -- minimap units: the close-up pass halves each edge's gap down to this
    local MAX_JOBS = 12 -- dots measured closely in one scan; more keep their grid place
    -- A span this many dots long is two dots or more: one dot measures its own size within a
    -- unit or two, and two that overlap (their reach is wider than they look) make at least this.
    local SPLIT = 1.3

    local function Halves(job)
        job.low, job.high = { hit = 0, dir = -1 }, { hit = 0, dir = 1 }
    end

    -- The next dot to measure: a find's grid spots its measured dots don't cover yet.
    local function NextJob(s)
        while s.queue[1] do
            local find = s.queue[1]
            local seed = table.remove(find.seeds, 1)
            if not seed then
                table.remove(s.queue, 1)
            elseif s.jobs >= MAX_JOBS then
                -- No close look left: one rough place, the middle of the find's spots left.
                local x, y, n = seed.x, seed.y, 1
                for _, other in ipairs(find.seeds) do x, y, n = x + other.x, y + other.y, n + 1 end
                find.seeds = {}
                s.done[#s.done + 1] = { name = find.name, x = x / n, y = y / n, dim = find.dim }
            else
                s.jobs = s.jobs + 1
                s.job = { find = find, x = seed.x, y = seed.y, axis = "x" }
                Halves(s.job)
                return
            end
        end
        s.job = nil
    end

    -- The next spot for the edge being found: a quarter dot past its last hit, or halfway
    -- between its last hit and miss.
    local function JobSpot(s)
        local job = s.job
        local side = job.low.done and job.high or job.low
        local off = side.miss and (side.hit + side.miss) / 2 or side.hit + side.dir * Dot() / 4
        local x, y = job.x, job.y
        if job.axis == "y" then y = y + off else x = x + off end
        s.spots[#s.spots + 1] = { x, y, side = side, off = off }
    end

    -- After each answer: on to the other edge, the other axis, or the dot is measured.
    -- A span much wider than one dot is dots that overlap, split evenly.
    local function JobStep(s)
        local job = s.job
        for _, side in ipairs({ job.low, job.high }) do
            if side.miss and math.abs(side.miss - side.hit) <= s.precision then
                side.done = true
            elseif not side.miss and math.abs(side.hit) >= 3 * Dot() then -- no end: stop there
                side.miss, side.done = side.hit, true
            end
        end
        if not (job.low.done and job.high.done) then return end
        local low = (job.low.hit + job.low.miss) / 2
        local high = (job.high.hit + job.high.miss) / 2
        if job.axis == "x" then
            job.x, job.wx, job.axis = job.x + (low + high) / 2, high - low, "y"
            Halves(job)
            return
        elseif job.axis == "y" then
            job.wy, job.cy, job.row = high - low, job.y + (low + high) / 2, (low + high) / 2
            if not select(2, Dot()) then
                -- Until the dot's size is known, its width across the middle too: one round dot
                -- is as wide there as it is tall, two that overlap are narrow where they meet.
                job.axis, job.y = "across", job.cy
                Halves(job)
                return
            end
        else
            job.x, job.across = job.x + (low + high) / 2, high - low
        end
        local wy, cy = job.wy, job.cy
        local dot, learned = Dot()
        -- Before the size is known: two equal round dots that overlap give their size from the
        -- span and the width where they meet (one round dot gives its own: both the same).
        if not learned and job.across then
            local long, short = math.max(wy, job.across), math.min(wy, job.across)
            dot, learned = (long * long + short * short) / (2 * long), true
        end
        local found = {}
        -- Dots in a row that overlap: their middles run from half a dot in from one end of
        -- the span to half a dot in from the other, evenly.
        if learned and wy > SPLIT * dot then
            local parts, inner = math.max(2, math.floor(wy / dot + 0.5)), wy - dot
            for j = 1, parts do found[j] = { name = job.find.name, x = job.x, y = cy - inner / 2 + inner * (j - 1) / (parts - 1), fine = 2, dim = job.find.dim } end
        elseif learned and (job.across or job.wx) > SPLIT * dot then
            local wx = job.across or job.wx -- across the middle when measured there
            local parts, inner = math.max(2, math.floor(wx / dot + 0.5)), wx - dot
            for j = 1, parts do found[j] = { name = job.find.name, x = job.x - inner / 2 + inner * (j - 1) / (parts - 1), y = cy, fine = 2, dim = job.find.dim } end
        else
            -- One dot, as far as can be told. Its size is learned only from a round one (a tall
            -- one may be two that overlap): as wide across its middle as it is tall, or once the
            -- size is known, its width across the grid spot's row, that row's distance from the
            -- middle and its height agreeing on one circle. Before the size is known, one that
            -- isn't round is placed roughly and measured again next scan.
            local round
            if job.across then
                round = math.abs(wy - job.across) <= 0.15 * wy
            else
                round = math.abs(wy - 2 * math.sqrt((job.wx / 2) ^ 2 + job.row * job.row)) <= 0.15 * wy
            end
            found[1] = { name = job.find.name, x = job.x, y = cy, fine = (learned or round) and 2 or nil, dim = job.find.dim }
            if round then LearnDot(wy) end
        end
        -- Grid spots inside a measured dot are done. A dot on a symbol already measured
        -- enough is that symbol, moved to where it was measured now.
        local seeds = job.find.seeds
        local dx, dy = Drift(s)
        local before = #s.done -- (dots split from one span are apart by measure: only earlier ones count as twice)
        for _, dotFound in ipairs(found) do
            local same
            for _, old in ipairs(markers) do
                if old.name == dotFound.name and old.x and not old.held and not old.rough
                    and (old.x + dx - dotFound.x) ^ 2 + (old.y + dy - dotFound.y) ^ 2 <= (dot * 0.75) ^ 2 then same = old end
            end
            local twice
            for i = 1, before do
                local done = s.done[i]
                if done.name == dotFound.name and (done.x - dotFound.x) ^ 2 + (done.y - dotFound.y) ^ 2 <= (dot * 0.75) ^ 2 then twice = true end
            end
            if same then s.moved[same] = true end
            if not twice then s.done[#s.done + 1] = dotFound end
            for i = #seeds, 1, -1 do
                if (seeds[i].x - dotFound.x) ^ 2 + (seeds[i].y - dotFound.y) ^ 2 <= (dot / 2 + 2) ^ 2 then table.remove(seeds, i) end
            end
        end
        s.job = nil
    end

    -- After the spots so far: true when another was added. First the grid, then each
    -- new find's close-up pass.
    local function KeyNextPass(s)
        if not s.queue then
            s.finds = KeyGroup(s.hits, s.step)
            -- A grid spot inside the dot of a symbol of its name, already measured, is that
            -- symbol: it keeps its place (not a rare: rares walk). The find's other spots may be
            -- a new herb or ore beside it, and get the close-up pass.
            local dot = Dot()
            local dx, dy = Drift(s)
            s.queue, s.done, s.jobs, s.known, s.moved, s.knownBy = {}, {}, 0, {}, {}, {}
            local crowded = Crowded()
            for _, find in ipairs(s.finds) do
                local left = {}
                for _, seed in ipairs(find.seeds) do
                    local near
                    for _, old in ipairs(markers) do
                        if old.name == find.name and old.x and not old.held and not old.rough and not crowded[old] and old.kind ~= "rares"
                            and (old.x + dx - seed.x) ^ 2 + (old.y + dy - seed.y) ^ 2 <= (dot / 2 + 2) ^ 2 then near = old end
                    end
                    if near then
                        s.known[near] = { dim = seed.dim or false }
                        s.knownBy[near] = s.knownBy[near] or { name = find.name, dim = find.dim, seeds = {} }
                        table.insert(s.knownBy[near].seeds, seed)
                    else
                        left[#left + 1] = seed
                    end
                end
                find.seeds = left
                if left[1] then
                    -- The spot nearest the find's middle first.
                    table.sort(find.seeds, function(a, b)
                        return (a.x - find.x) ^ 2 + (a.y - find.y) ^ 2 < (b.x - find.x) ^ 2 + (b.y - find.y) ^ 2
                    end)
                    s.queue[#s.queue + 1] = find
                end
            end
        end
        if not s.job then NextJob(s) end
        if s.job then
            JobSpot(s)
            return true
        end
        -- A symbol the grid didn't name may sit in a gap between its spots: a spot on it
        -- (and a third of a dot to each side, above and below, for one placed a little off)
        -- says whether it's still there; one not found goes. Symbols whose grid spots were
        -- skipped are checked this way too, so one gathered by someone else goes at once.
        -- A symbol the grid named is checked on its middle only (strict): a dot just beside
        -- it means it's off, and that dot is measured, so the symbol moves there.
        if not s.probes then
            s.probes, s.gone = {}, {}
            local dot, half = Dot(), s.width / 2
            local dx, dy = Drift(s)
            for old in pairs(s.knownBy) do
                s.probes[#s.probes + 1] = { old = old, x = old.x + dx, y = old.y + dy, tries = 0, strict = true }
            end
            for _, old in ipairs(markers) do
                local other = db.switchFinders and turns.kind and (old.kind == "herbs" or old.kind == "ore") and old.kind ~= turns.kind
                if old.x and not old.held and not old.far and not other and not s.known[old] and not s.unread[old] then
                    local x, y = old.x + dx, old.y + dy
                    local covered = false
                    for _, found in ipairs(s.done) do
                        if found.name == old.name and (found.x - x) ^ 2 + (found.y - y) ^ 2 <= (dot * 0.75) ^ 2 then covered = true end
                    end
                    if not covered then s.probes[#s.probes + 1] = { old = old, x = x, y = y, tries = 0 } end
                end
            end
        end
        while s.probes[1] do
            local probe = s.probes[1]
            if probe.strict and (probe.found or probe.tries >= 1) then
                table.remove(s.probes, 1)
                if not probe.found then
                    s.known[probe.old], s.gone[probe.old] = nil, true
                    s.queue[#s.queue + 1] = s.knownBy[probe.old]
                    NextJob(s)
                    if s.job then
                        JobSpot(s)
                        return true
                    end
                end
            elseif probe.found or probe.tries >= 5 then
                if probe.found then s.known[probe.old] = true else s.gone[probe.old] = true end
                table.remove(s.probes, 1)
            else
                probe.tries = probe.tries + 1
                local third = Dot() / 3
                local off = ({ { 0, 0 }, { third, 0 }, { -third, 0 }, { 0, third }, { 0, -third } })[probe.tries]
                s.spots[#s.spots + 1] = { probe.x + off[1], probe.y + off[2], probe = probe }
                return true
            end
        end
        local out = {}
        -- (a known symbol read on a spot this scan: in a cave or not as read now)
        for old, read in pairs(s.known) do
            if not s.moved[old] then
                local dim
                if type(read) == "table" then dim = read.dim end
                out[#out + 1] = { name = old.name, known = old, dim = dim }
            end
        end
        for _, found in ipairs(s.done) do out[#out + 1] = found end
        s.finds = out
        return false
    end

    -- The minimap back as it was; with finds, they become the symbols.
    local function KeyStopNow(finds)
        local s = key.scan
        key.scan = nil
        local took = s.startedAt and (" in %.1f s"):format(GetTime() - s.startedAt) or ""
        ns.Log(finds and ("scan done%s: %d found"):format(took, #finds) or ("scan stopped%s: %s"):format(took, key.stopWhy or "other"))
        key.stopWhy = nil
        key.lastJobs, key.lastSpots = s.jobs or 0, s.gridSpots -- dots measured closely, grid spots
        quietUntil = GetTime() + 0.25
        pcall(Minimap.AdjustPointsOffset, Minimap, -s.ox, -s.oy)
        Reclamp(s)
        Disguise(s, false)
        Guard(s)
        PinSymbols(s, false)
        if not finds then return end
        local dx, dy = Drift(s)
        local places = {}
        for _, find in ipairs(finds) do
            local old = find.known
            if old then
                local dim = find.dim
                if dim == nil then dim = old.dim end
                places[#places + 1] = { name = old.name, x = old.x, y = old.y, pin = old, exact = true, dim = dim }
            else
                -- From where the minimap was at the start to where it is now. Not exact
                -- while symbols are measured more than once: averaged with their earlier places.
                -- rough: not measured closely (given up, or past the most a scan measures):
                -- measured again next scan.
                places[#places + 1] = { name = find.name, x = find.x - dx, y = find.y - dy, dim = find.dim, rough = find.fine ~= 2,
                    exact = find.fine == 2 }
            end
        end
        -- A symbol checked on its spot and not found goes.
        for _, old in ipairs(markers) do
            local other = db.switchFinders and turns.kind and (old.kind == "herbs" or old.kind == "ore") and old.kind ~= turns.kind
            local seen = false
            for _, place in ipairs(places) do
                if place.pin == old or (old.x and not place.pin and place.name == old.name
                    and (place.x - old.x) ^ 2 + (place.y - old.y) ^ 2 <= (Dot() * 0.75) ^ 2) then seen = true end
            end
            local gone = s.gone and s.gone[old] -- checked on its spot, nothing there
            if not gone and not seen and s.skipped[old] then
                places[#places + 1] = { name = old.name, x = old.x, y = old.y, pin = old, exact = true, missed = old.missed, dim = old.dim, rough = old.rough }
            elseif not gone and not seen and old.x and not old.held and not old.far and not other then
                local missed = (old.missed or 0) + 1
                if missed <= 1 then
                    places[#places + 1] = { name = old.name, x = old.x, y = old.y, pin = old, exact = true, missed = missed, dim = old.dim, rough = old.rough }
                end
            end
        end
        scan = { places = places, hits = {} }
        FinishScan()
    end
    local function KeyStop(finds)
        local s, t = key.scan, Now()
        KeyStopNow(finds)
        Took(s, "finishing", t)
    end

    -- A mouse button held mid-scan (the game hides and holds the cursor): the scan pauses
    -- with the minimap back as it looks, and goes on from the same spot when it's let go.
    local function Pause(s, on)
        if on then
            pcall(Minimap.AdjustPointsOffset, Minimap, -s.ox, -s.oy)
            s.ox, s.oy = 0, 0
            Reclamp(s)
            Disguise(s, false)
            PinSymbols(s, false)
        else
            PinSymbols(s, true)
            if not s.fadeIn then Disguise(s, true) end
            s.lastX, s.lastY = nil, nil -- the mouse's last move says nothing now
        end
        s.paused = on
    end

    -- Fade in and out: the minimap's own frames and their alpha, to fade with the stand-in
    -- (ones still fading back from the last scan: their own alpha, taken from there).
    local function MinimapAlphas()
        local alphas = {}
        for frame, alpha in pairs(fadeBack) do alphas[frame] = alpha end
        wipe(fadeBack)
        local parts = { Minimap:GetChildren() }
        for _, region in ipairs({ Minimap:GetRegions() }) do parts[#parts + 1] = region end
        for _, child in ipairs(parts) do
            if alphas[child] == nil and not issecretvalue(child) and not Apart(child)
                and not (InCombatLockdown() and child:IsProtected()) then
                local ok, alpha = pcall(child.GetAlpha, child)
                if ok and not issecretvalue(alpha) then alphas[child] = alpha end
            end
        end
        return alphas
    end

    -- The stand-in each frame of a scan (and of its fades): its arrow turned, its map moved with you.
    -- The map icons' copies where the icons would be now, as you walk; off the minimap: hidden.
    local function StandIcons()
        local from = stand.from
        if not (from and stand.moving and stand.moving[1]) then return end
        local wx, wy = UnitPosition("player")
        local radius = C_Minimap.GetViewRadius()
        local width, height = stand.artWidth, stand.artHeight
        if not Readable(wx, wy, radius) or not (width and height) or radius <= 0 then return end
        local perYard = width / 2 / radius
        local dx, dy = (wy - from.y) * perYard, (from.x - wx) * perYard
        if C_CVar.GetCVar("rotateMinimap") == "1" and from.facing then
            local c, n = math.cos(from.facing), math.sin(from.facing)
            dx, dy = dx * c + dy * n, dy * c - dx * n
        end
        local hw, hh = width / 2, height / 2
        for _, m in ipairs(stand.moving) do
            local x, y = m.x + dx, m.y + dy
            local inside = stand.round and x * x + y * y <= hw * hw or not stand.round and math.abs(x) <= hw and math.abs(y) <= hh
            m.copy:ClearAllPoints()
            m.copy:SetPoint("CENTER", stand.decor, "CENTER", x, y)
            m.copy:SetShown(inside)
        end
    end
    function StandMove()
        StandArrow()
        if stand and stand:IsShown() then
            StandArt(stand.artWidth, stand.artHeight, stand.round)
            StandPins(stand.artWidth, stand.artHeight, stand.round)
            StandIcons()
        end
    end

    local function KeyScanFrame()
        local s = key.scan
        if not Minimap:IsVisible() or AtNpc() then
            key.stopWhy = Minimap:IsVisible() and "talking to an NPC" or "the minimap was hidden"
            return KeyStop()
        end
        -- The mouse onto the minimap's place: stopped at once, so its icons can be used.
        -- (A scan begun from there goes on until the mouse has left it once.)
        if not OnHome(s) then
            s.away = true
        elseif s.away then
            key.stopWhy = "the mouse went onto the minimap"
            return KeyStop()
        end
        -- Fade in and out: the minimap goes once the stand-in over it is in.
        if s.fadeIn then
            s.orig = s.orig or MinimapAlphas()
            if GetTime() < s.fadeIn then
                local t = stand and stand:GetAlpha() or 1
                for frame, alpha in pairs(s.orig) do pcall(frame.SetAlpha, frame, alpha * (1 - t)) end
                return
            end
            s.fadeIn = nil
            Disguise(s, true)
            s.orig = nil
            if s.at then return KeyPlace(s, s.at) end -- after a pause: that spot looked at again
        end
        -- A rotating minimap turned mid-scan has turned its picture: the scan stops (the
        -- minimap back, the symbols as they were) and runs again a moment after.
        local facing = s.facing and PlayerFacing()
        if facing and math.abs((facing - s.facing + math.pi) % (2 * math.pi) - math.pi) > 0.03 then
            key.stopWhy = "the minimap turned"
            KeyStop()
            key.wanted, key.wantedAt = true, GetTime() + 0.3
            return
        end
        -- Stop when the mouse moves: an automatic scan ends as you move the mouse (over 15 pixels,
        -- not a hand's jitter), so what you move onto (a mob, a herb) gets its tooltip at once.
        if db.mouseStop and s.auto then
            local cx, cy = GetCursorPosition()
            if (cx - s.cursorX) ^ 2 + (cy - s.cursorY) ^ 2 > 225 then
                key.stopWhy = "the mouse moved"
                return KeyStop()
            end
        end
        -- A window under the mouse (bags opened mid-scan) pauses it too, for 2 s at most: then
        -- it's dropped (the symbols as they were), so the minimap doesn't vanish much later.
        Unhover(s)
        local covered = Covered()
        if covered then
            s.coveredAt = s.coveredAt or GetTime()
            if GetTime() - s.coveredAt > COVERED_WAIT then
                key.stopWhy = "a window stayed under the mouse: " .. ns.NameOf(GetMouseFoci and (GetMouseFoci() or {})[1])
                return KeyStop()
            end
        else
            s.coveredAt = nil
        end
        local looking = Mouselooking()
        if not looking then s.lookAt = nil end
        -- Fewer blinks: the minimap stays hidden where it is while a window is under the mouse
        -- (up to 2 s, above) or the camera turns (up to 1 s, then paused). Not when a mouse
        -- button is pressed: paused at once, so the click reaches the world, not the minimap.
        if db.windowWait and not s.paused and not Pressed() and (covered or looking) then
            s.lookAt = looking and (s.lookAt or GetTime()) or nil
            if not looking or GetTime() - s.lookAt <= LOOK_WAIT then
                if not s.waited then
                    ns.Log("waiting: " .. (covered and ("window under the mouse: " .. ns.NameOf(GetMouseFoci and (GetMouseFoci() or {})[1])) or "the camera turned"))
                end
                s.waited = true
                KeepHidden(s)
                return StandMove()
            end
        end
        if looking or covered then
            if not s.paused then
                ns.Log("paused: " .. (covered and ("window under the mouse: " .. ns.NameOf(GetMouseFoci and (GetMouseFoci() or {})[1]))
                    or "a mouse button held or the camera turned"))
                Pause(s, true)
            end
            return
        end
        if s.paused then
            Pause(s, false)
            if s.fadeIn then return end -- placed once the stand-in is in (above)
            if s.at then return KeyPlace(s, s.at) end -- that spot looked at again
        end
        if s.waited then
            s.waited, s.lastX, s.lastY = nil, nil, nil -- the mouse's last move says nothing now
            if s.at then return KeyPlace(s, s.at) end
        end
        -- Still nothing under the mouse (a controller's free look that hovers nothing): the
        -- minimap can't be read, so the scan stops with the symbols as they were.
        if not Hovering() then
            s.blindAt = s.blindAt or GetTime()
            if GetTime() - s.blindAt > BLIND_WAIT then
                key.stopWhy = "nothing under the mouse"
                return KeyStop()
            end
            s.waited = true
            KeepHidden(s)
            return StandMove()
        end
        s.blindAt = nil
        local t = Now()
        HookMappy()
        Adopt(s)
        t = Took(s, "new frames", t)
        Trailing(s)
        t = Took(s, "following", t)
        KeepHidden(s)
        t = Took(s, "keeping hidden", t)
        StandMove()
        Took(s, "stand-in", t)
        if s.at then
            local spot = s.spots[s.at]
            -- The game looks under the mouse a frame after the minimap was placed: where the
            -- mouse moved since, it looked that much further on, and that's where the answer
            -- counts. An edge's answer past its last hit or miss only counts when it agrees
            -- (no dot past the miss, the dot inside the hit). One that doesn't, one off the
            -- edge's line, or a symbol's check over a third of a dot off is placed again, up
            -- to half a second in all a scan (s.waits). After that a dot being measured goes
            -- where its edges so far put it (no width learned from it, no split) and a
            -- checked symbol counts as there.
            local cx, cy = GetCursorPosition()
            local mx, my = (cx - s.cx) / s.cursorScale, (cy - s.cy) / s.cursorScale
            local names = KeyNames()
            local off, useless = spot.off, false
            if spot.side then
                local along, across = mx, my
                if s.job.axis == "y" then along, across = my, mx end
                local a, b, at = spot.side.hit, spot.side.miss or spot.side.hit + spot.side.dir * Dot() / 2, off + along
                local hit = Has(names, s.job.find.name)
                local confirms = false
                if (at - a) * (at - b) < 0 then
                    off = at
                elseif (at - b) * (b - a) >= 0 then -- past the miss (none yet while stepping out)
                    off, confirms = spot.side.miss and not hit and b or nil, spot.side.miss ~= nil and not hit
                else -- inside the hit
                    off, confirms = hit and a or nil, hit
                end
                useless = off == nil or math.abs(across) > 2
                -- An answer that only agrees tells nothing new: looked at again (3 times at most).
                if confirms and not useless and (spot.confirms or 0) < 3 then
                    spot.confirms = (spot.confirms or 0) + 1
                    return KeyPlace(s, s.at)
                end
            elseif spot.probe then
                useless = mx * mx + my * my > (Dot() / 3) ^ 2
            end
            if useless and (s.waits or 0) < 30 then
                s.waits = (s.waits or 0) + 1
                return KeyPlace(s, s.at)
            end
            if spot.side and useless then
                local job, dot = s.job, Dot()
                local low = (job.low.hit + (job.low.miss or job.low.hit)) / 2
                local high = (job.high.hit + (job.high.miss or job.high.hit)) / 2
                if job.axis == "y" then job.y = job.y + (low + high) / 2 else job.x = job.x + (low + high) / 2 end
                s.done[#s.done + 1] = { name = job.find.name, x = job.x, y = job.y, dim = job.find.dim }
                local seeds = job.find.seeds
                for i = #seeds, 1, -1 do
                    if (seeds[i].x - job.x) ^ 2 + (seeds[i].y - job.y) ^ 2 <= dot * dot then table.remove(seeds, i) end
                end
                s.job = nil
            elseif spot.side then
                if Has(names, s.job.find.name) then spot.side.hit = off else spot.side.miss = off end
                JobStep(s)
            elseif spot.probe then
                if useless or Has(names, spot.probe.old.name) then spot.probe.found = true end
            else
                -- Only names of things NodeSight shows: a quest's blue area names its quest
                -- all over it, and that's no dot to measure.
                for _, name in ipairs(names) do
                    if KindOf(name) then
                        s.hits[#s.hits + 1] = { name = name, x = spot[1] + mx, y = spot[2] + my, dim = names.gray[name] }
                    end
                end
            end
            if s.at >= #s.spots and not KeyNextPass(s) then return KeyStop(s.finds or {}) end
        end
        KeyPlace(s, (s.at or 0) + 1)
    end

    -- auto: from Scan by distance or its timer (it skips spots inside symbols already measured
    -- two scans in three).
    -- Edge scans: where the last scan's middle is on the minimap now (minimap units from its
    -- middle), or nil for a whole scan (no last scan here, another zoom, a turn, or standing).
    local function Behind(half)
        local last = key.last
        if db.switchFinders then last = turns.kind and key.lastOf and key.lastOf[turns.kind] end -- (scans take turns)
        local map, px, py, mapWidth, mapHeight = MapPosition()
        local radius = C_Minimap.GetViewRadius()
        if not (last and map and last.map == map and last.radius and Readable(radius)) or radius ~= last.radius or radius <= 0 then return nil end
        local rotating = C_CVar.GetCVar("rotateMinimap") == "1"
        local facing = PlayerFacing()
        if rotating and not (facing and last.facing and math.abs(facing - last.facing) < 0.05) then return nil end
        local east, north = (px - last.x) * mapWidth, (last.y - py) * mapHeight
        local yards = math.sqrt(east * east + north * north)
        if yards < 1 then return nil end
        local bearing = math.atan2(east, north) + (rotating and facing or 0) -- clockwise from the minimap's top
        local units = yards / radius * half
        return { -units * math.sin(bearing), -units * math.cos(bearing) }
    end

    local function StartKeyScan(auto)
        if key.scan or not tracker or not Enabled() or not Minimap:IsVisible() or not Minimap:GetLeft() then return end
        -- Not in dungeons, raids, battlegrounds or arenas (there the game gives no map
        -- position to follow the symbols by).
        local inside = IsInInstance()
        if issecretvalue(inside) or inside then return end
        if (InCombatLockdown() and Minimap:IsProtected()) or Covered() or AtNpc() then return end
        if Mouselooking() then
            key.wanted = true
            return
        end
        -- Just after a finder switch the new finder's dots aren't on the minimap yet: the scan
        -- waits for them.
        local pending = ns.switch and ns.switch.pending
        if pending and GetTime() < pending.at + SWITCH_WAIT then
            key.wanted, key.wantedAt = auto and "auto" or true, pending.at + SWITCH_WAIT
            return
        end
        -- A rotating minimap: not while you turn (the scan would stop at once).
        if C_CVar.GetCVar("rotateMinimap") == "1" then
            local facing = PlayerFacing()
            if facing and facing ~= key.facing then
                key.facing = facing
                key.wanted, key.wantedAt = auto and "auto" or true, GetTime() + 0.1 -- (an automatic scan stays one)
                return
            end
        end
        -- With Switch, the finder on now (the other kind's symbols are held until its turn).
        if db.switchFinders then turns.kind = Finders() end
        local width = Minimap:GetWidth()
        local half = width / 2
        local quarters = ns.MinimapQuarters()
        -- Spots in a honeycomb (rows half a step apart sideways), spaced from the measured
        -- dot: 0.87 dots apart, no point is further than half a dot from a spot, so no dot
        -- is missed (a little closer than that, to be safe).
        -- Scans take turns with three honeycombs, the 2nd and 3rd moved onto the 1st's
        -- gaps (the middles of its triangles), so each measures dots from other spots.
        local dot, learned = Dot()
        local step = learned and dot * 0.866 * 0.95 or FIRST_STEP
        local rowGap = step * 0.866
        scans = scans + 1
        phase = (phase + 1) % 3
        local shiftX, shiftY = phase == 1 and step / 2 or 0, ({ 0, 1 / 3, 2 / 3 })[phase + 1] * rowGap
        -- Spots inside a symbol already measured would only name it again: skipped,
        -- except on a key press and every third scan, which check that they're still there.
        local skip, skipped = {}, {}
        if auto and scans % 3 ~= 0 then
            local crowded = Crowded()
            for _, old in ipairs(markers) do
                if old.x and not old.held and not old.far and not old.rough and not crowded[old] then skip[#skip + 1] = old end
            end
        end
        -- Edge scans (Beta): while you move, only what wasn't on the minimap at the last scan
        -- (half a step more, for dots cut by its edge then); its symbols elsewhere stay as they
        -- are. Every third scan, standing, a turn or a zoom: all of it.
        local behind = auto and db.edgeScan and scans % 3 ~= 0 and Behind(half) or nil
        local unread = {} -- (not checked on their spots either: the next whole scan does)
        if behind then
            for _, old in ipairs(markers) do
                if old.x and ns.InShape(old.x - half - behind[1], old.y - half - behind[2], half - step / 2, quarters) then
                    skipped[old], unread[old] = true, true
                end
            end
        end
        local spots, row, skippedSpots = {}, 0, 0
        for y = rowGap / 2 - half + shiftY, half, rowGap do
            local start = (row % 2 == 1 and step / 2 or 0) + shiftX
            row = row + 1
            for x = -half + start % step, half, step do
                if ns.InShape(x, y, half, quarters) and not (behind and ns.InShape(x - behind[1], y - behind[2], half - step / 2, quarters)) then
                    local inside
                    for _, old in ipairs(skip) do
                        if (old.x - half - x) ^ 2 + (old.y - half - y) ^ 2 <= (dot / 2 - 2) ^ 2 then
                            inside = true
                            skipped[old] = true
                        end
                    end
                    if inside then skippedSpots = skippedSpots + 1 else spots[#spots + 1] = { x, y } end
                end
            end
        end
        if not spots[1] then return end
        local map, px, py, mapWidth, mapHeight = MapPosition()
        key.last = map and { map = map, x = px, y = py, radius = C_Minimap.GetViewRadius(), facing = PlayerFacing() } or nil
        key.lastOf = key.lastOf or {}
        if turns.kind then key.lastOf[turns.kind] = key.last end
        key.lastAt, key.edge = GetTime(), behind ~= nil
        -- Spots are from the minimap's middle; KeyPlace wants them from its bottom left.
        for _, spot in ipairs(spots) do spot[1], spot[2] = spot[1] + half, spot[2] + half end
        key.lastSkipped = skippedSpots
        local gridSpots = #spots
        Recheck(true) -- (the last scan's frames checked before this one looks at them)
        local pin = {}
        PinSymbols(pin, true)
        local cursorX, cursorY = GetCursorPosition()
        key.scan = { auto = auto or nil, cursorX = cursorX, cursorY = cursorY, pinned = pin.pinned, fadeIn = pin.fadeIn, facing = C_CVar.GetCVar("rotateMinimap") == "1" and PlayerFacing() or nil, spots = spots, gridSpots = gridSpots, width = width, step = step, skipped = skipped, unread = unread, precision = PRECISION,
            ox = 0, oy = 0, hits = {},
            p0 = map and { map = map, x = px, y = py, width = mapWidth, height = mapHeight } or nil,
            left = Minimap:GetLeft(), bottom = Minimap:GetBottom(), height = Minimap:GetHeight(), alpha = Minimap:GetAlpha(), coords = Coords() }
        if key.scan.coords then key.scan.coordsAlpha = key.scan.coords:GetAlpha() end
        key.scan.startedAt = GetTime()
        ns.Log(("scan %s: %d spots%s, map %s"):format(auto and "auto" or "key", #spots, behind and ", edge" or "", tostring(map)))
        if not key.scan.fadeIn then Disguise(key.scan, true) end
        -- Most addons' round minimap buttons (LibDBIcon) open their own tooltip, not
        -- GameTooltip, as the moving minimap passes them under the mouse: closed too.
        local iconTip = _G["LibDBIconTooltip"]
        if not key.iconTip and type(iconTip) == "table" and iconTip.HookScript then
            key.iconTip = true
            iconTip:HookScript("OnShow", function(tip)
                if (key.scan or GetTime() < quietUntil) and not Covered() then tip:Hide() end
            end)
        end
        if type(iconTip) == "table" and iconTip.IsShown and iconTip:IsShown() then iconTip:Hide() end
    end

    -- The minimap opens its tooltip every frame the mouse is over it, and buttons and map
    -- pins on it (addons' and Blizzard's) move with it, unseen, opening theirs as they pass
    -- under the mouse: every tooltip is closed while scanning. A moment after, only those of
    -- things on the minimap (the minimap's own is closed below): a mob's opens only once, as
    -- the mouse reaches it. Not a window's own (an item in your bags hovered mid-scan).
    local function OnMinimap(tip)
        local ok, frame = pcall(tip.GetOwner, tip)
        for _ = 1, 20 do
            if not ok or frame == nil or issecretvalue(frame) then return false end
            if frame == Minimap then return true end
            ok, frame = pcall(frame.GetParent, frame)
        end
        return false
    end
    GameTooltip:HookScript("OnShow", function(tip)
        if (key.scan or GetTime() < quietUntil and OnMinimap(tip)) and not Covered() then tip:Hide() end
    end)
    -- A tooltip already shown (a unit's, say) gets the minimap's text without opening again:
    -- closed after the minimap fills it.
    -- A dot you hover yourself (Symbols for hovered dots): its symbol at once, where the mouse
    -- is on it. Marked rough, so the next scan measures it again.
    function key.Hovered()
        if not Enabled() then return end
        local names = KeyNames()
        if not names[1] then return end
        local left, bottom, width = Minimap:GetLeft(), Minimap:GetBottom(), Minimap:GetWidth()
        local radius = C_Minimap.GetViewRadius()
        local map, px, py, mapWidth, mapHeight = MapPosition()
        if not (map and left and bottom and Readable(left, bottom, width, radius)) or radius <= 0 then return end
        local rotating = C_CVar.GetCVar("rotateMinimap") == "1"
        local facing = PlayerFacing()
        if rotating and not facing then return end
        local scale = Minimap:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        local dx, dy = cx / scale - left - width / 2, cy / scale - bottom - width / 2
        local yards = math.sqrt(dx * dx + dy * dy) / (width / 2) * radius
        local bearing = math.atan2(dx, dy) -- clockwise from the top of the minimap
        local world = rotating and bearing - facing or bearing
        local mx, my = px + yards * math.sin(world) / mapWidth, py - yards * math.cos(world) / mapHeight
        local near = (Dot() / 2 / (width / 2) * radius) ^ 2 -- yards, squared: a symbol within half a dot is this one
        local added = false
        for _, name in ipairs(names) do
            local kind = KindOf(name)
            local known = false
            for _, old in ipairs(markers) do
                if old.name == name and old.map == map and old.mx
                    and ((old.mx - mx) * mapWidth) ^ 2 + ((old.my - my) * mapHeight) ^ 2 <= near then
                    known = true
                    break
                end
            end
            if kind and not known then
                markers[#markers + 1] = {
                    name = name, kind = kind, file = IconOf(name, kind),
                    hard = (db.skillLook == SKILL.RED or db.arrow or db.sound or db.worldMark) and TooHard(name, kind),
                    dim = names.gray[name] or false, map = map, mx = mx, my = my, rough = true, distance = 0,
                }
                added = true
            end
        end
        if added then
            lastMap = nil
            Follow()
            ShowMarkers()
            UpdateArrow()
        end
    end
    ns.hoverSymbols = false -- (symbols for dots you hover: off, not ready yet)
    if GameTooltip.SetMinimapMouseover then
        hooksecurefunc(GameTooltip, "SetMinimapMouseover", function(tip)
            if key.scan or GetTime() < quietUntil then
                tip:Hide()
            elseif ns.hoverSymbols and db.hoverSave then
                pcall(key.Hovered)
            end
        end)
    end
    -- Scan by distance and the timer: out of combat (unless Scan in combat), not resting (in
    -- a city or an inn, unless that's turned off), not flying (on a mount or a flight path),
    -- with a finder on and the mouse over the world.
    -- Why automatic scans aren't running now (the bug report); a lasting reason goes in its log.
    local function Why(reason, passing)
        if reason == key.why then return end
        key.why = reason
        if not passing then ns.Log("automatic scans: " .. reason) end
    end
    function key.Auto()
        local now = GetTime()
        if now < nextCheck then return end
        nextCheck = now + 0.25
        if key.wanted == "auto" then return end -- (a scan waits for a switch's dots)
        local seconds = TimerSeconds()
        if not (db.autoScan or seconds > 0) then return Why("Scan on a timer and Scan by distance off") end
        if not Enabled() then return Why("Scan the minimap off, or nothing to show its finds on") end
        if db.mouseStill then -- (the cursor's place each look: still once it stays put)
            local cx, cy = GetCursorPosition()
            if cx ~= key.cursorX or cy ~= key.cursorY then key.cursorX, key.cursorY, key.stillAt = cx, cy, now end
        end
        if not FinderOn() then
            Why("no Find Herbs or Find Minerals on")
            if markers[1] and not key.scan and not (ns.switch and ns.switch.pending) then
                markers = {}
                ShowMarkers()
                UpdateArrow()
            end
            return
        end
        if InCombatLockdown() and not db.combatScan then return Why("in combat") end
        if db.lootWait and key.foughtAt and now < key.foughtAt + (tonumber(db.lootSeconds) or 3) then return Why("looting after a fight", true) end
        if db.skipRest and IsResting() then return Why("resting (Not in cities and inns)") end
        if not (PadLooking() or Hovering()) then return Why("nothing under the mouse (a controller)", true) end
        if Mouselooking() then return Why("the camera turning", true) end
        if (IsFlying and IsFlying()) or (UnitOnTaxi and UnitOnTaxi("player")) then return Why("flying") end
        local foci = GetMouseFoci and GetMouseFoci()
        local focus = type(foci) == "table" and foci[1] or nil
        if focus ~= nil and focus ~= WorldFrame and not Under(focus) then return Why("the mouse over " .. ns.NameOf(focus), true) end
        -- A mob or corpse under the mouse: about to loot or click it. Anything else with a
        -- tooltip there (a herb, a chest, a mailbox): a scan would take its tooltip away.
        if db.mobWait and UnitExists("mouseover") then return Why("a mob under the mouse", true) end
        local tip = db.mobWait and GameTooltip:IsVisible()
        if not issecretvalue(tip) and tip then return Why("a tooltip under the mouse", true) end
        if db.mouseStill and now - (key.stillAt or now) < STILL_WAIT then return Why("the mouse moving", true) end
        -- Casting or gathering, looting, aiming a spell or holding an item.
        if ns.Busy() then return Why("busy (casting, looting or gathering)", true) end
        local map, x, y, width, height = MapPosition()
        if not map then return Why("no map position here") end
        local last = key.last
        -- After logging in, a reload or a loading screen (no last scan, or another map): no
        -- scan where you stand, only once you've moved the distance from here.
        if not last or last.map ~= map then
            key.last, key.lastAt = { map = map, x = x, y = y }, now
            return
        end
        local moved = db.autoScan and ((x - last.x) * width) ^ 2 + ((y - last.y) * height) ^ 2 >= db.autoScanYards ^ 2
        -- The timer: its time has passed and you're moving (half a yard since the last look).
        local here = key.here
        local stepping = here and here.map == map and ((x - here.x) * width) ^ 2 + ((y - here.y) * height) ^ 2 > 0.25
        key.here = { map = map, x = x, y = y }
        local timed = seconds > 0 and now - (key.lastAt or now) >= seconds and (stepping or db.scanStanding)
        Why((moved or timed) and "scanning" or "waiting for the timer or the distance", true)
        if moved or timed then
            -- Switch on: the other finder first; the scan waits a second for its dots.
            if ns.SwitchBeforeScan() then
                key.wanted, key.wantedAt = "auto", GetTime() + SWITCH_WAIT
                return
            end
            StartKeyScan(true)
        end
    end
    key.Start, key.Frame, key.Stop, key.Mouselooking = StartKeyScan, KeyScanFrame, KeyStop, Mouselooking
    function key.Settle()
        Settle()
        Recheck()
    end
    function key.Settling() return next(settling) ~= nil or next(guard) ~= nil end
    -- Leaving the world (a reload, logout or loading screen): what the last scan would put back
    -- over the next moments (fading back, sizes, the guard), put back now, before addons save.
    function key.Flush()
        for frame, alpha in pairs(fadeBack) do pcall(frame.SetAlpha, frame, alpha) end
        wipe(fadeBack)
        for frame, was in pairs(settling) do
            local ok, protected = pcall(frame.IsProtected, frame)
            if not (InCombatLockdown() and (not ok or protected)) then
                pcall(frame.SetScale, frame, was.scale)
                settling[frame] = nil
            end
        end
        Recheck(true)
    end
    function ns.KeyScanning() return key.scan ~= nil end -- (Switch: no switch during a scan)
    function ns.AutoWhy() return key.why end
    function ns.WorstScanFrame() return key.worstEver or 0 end
    function ns.MemoryUsed() return key.made or 0, key.madeSince or GetTime() end
end)()

---------------------------------------------------------------------------
-- Running the scan
---------------------------------------------------------------------------

-- The far sparkles (Beta): FarSparkles.lua fills this table.
local world = { others = {} }

-- The switch's way, every frame. An error in it would repeat every frame: reported once,
-- and the switch stops until the next reload.
local function SwitchFrame()
    if db.switchFinders and not ns.switch.stopped and not xpcall(ns.SwitchUpdate, Oops) then
        ns.switch.stopped = true
    end
end

-- A scan's own work this frame (began: debugprofilestop() before it), added to the scan;
-- at its end, the bug report's log gets its total and its worst frame.
local function Timed(s, began, memory)
    if s and memory then s.garbage = (s.garbage or 0) + math.max(0, collectgarbage("count") - memory) end
    if not (s and began) then return end
    local took = debugprofilestop() - began
    s.work, s.frames = (s.work or 0) + took, (s.frames or 0) + 1
    if took > (s.worst or 0) then s.worst, s.worstAt = took, s.frames end
    if key.scan ~= s then
        local parts = {}
        for part, ms in pairs(s.parts or {}) do parts[#parts + 1] = ("%s %.1f"):format(part, ms) end
        table.sort(parts)
        ns.Log(("  its work: %.1f ms over %d frames, the most in one frame %.1f ms (frame %d); looked again %d times, %d dots measured closely; %d frames hidden (%d shrunk); %d KB of memory used; in ms: %s"):format(
            s.work, s.frames, s.worst or 0, s.worstAt or 0, s.waits or 0, s.jobs or 0, s.hidMost or 0, s.shrunkMost or 0, s.garbage or 0, table.concat(parts, ", ")))
        if (s.worst or 0) > (key.worstEver or 0) then key.worstEver = s.worst end
    end
end

-- Every frame: the scan or its wait, then the places, arrow, far sparkles and the switch's way.
local function OnUpdate()
    local memory = collectgarbage("count") -- (what NodeSight's work takes, for the bug report)
    -- Quest areas a scan couldn't put back on (the game refused): tried again each second.
    if NodeSightDB.questOff and not key.scan and GetTime() >= (key.backAt or 0) then
        key.backAt = GetTime() + 1
        ns.QuestAreasBack()
    end
    -- The scan: on its key, or as you move (Scan by distance).
    if not key.scan then xpcall(key.Settle, Oops) end
    local s, began, scanMemory = key.scan, debugprofilestop and debugprofilestop(), collectgarbage("count")
    if key.scan then
        if not xpcall(key.Frame, Oops) then
            key.stopWhy = "an error"
            pcall(key.Stop)
        end
    elseif key.stopped then -- (an error starting a scan: reported once, off until a reload)
    elseif key.wanted and not key.Mouselooking() and GetTime() >= (key.wantedAt or 0) then
        local auto = key.wanted == "auto" -- (an automatic scan waiting for a switch's dots)
        key.wanted = nil
        if not xpcall(function() key.Start(auto) end, Oops) then ns.ScansStopped() end
    elseif db.autoScan or TimerSeconds() > 0 then
        if not xpcall(key.Auto, Oops) then ns.ScansStopped() end
    end
    Timed(s or key.scan, began, scanMemory)
    -- A failed symbol or arrow update would fail again every frame: report it once and
    -- clear the symbols, so there is nothing to update until a scan finds them again.
    if not (xpcall(Follow, Oops) and xpcall(UpdateArrow, Oops)) then
        markers = {}
        pcall(ShowMarkers)
        pcall(UpdateArrow) -- no target left: hides the arrow
    end
    -- A failed far marker would fail again every frame: report it once, hide its sparkles
    -- and stop it until the next reload (world.Update then only puts your map pin back).
    if not xpcall(world.Update, Oops) and not world.stopped then
        world.stopped, world.hide = true, false
        pcall(world.Out)
    end
    SwitchFrame()
    key.made, key.madeSince = (key.made or 0) + math.max(0, collectgarbage("count") - memory), key.madeSince or GetTime()
end

-- After a loading screen, old places are stale.
local function NewPlace()
    if key.scan then -- a scan under way read the old place: dropped
        key.stopWhy = "a loading screen"
        pcall(key.Stop)
    end
    scan, markers = nil, {}
    ShowMarkers()
    UpdateArrow()
end

-- Loot closed: the symbol of that kind nearest you goes (you just took it), and any held
-- one of that kind this close. By name when the game gave the node's.
local function Picked()
    local kind, name, gone = turns.picked, turns.pickedName and Plain(turns.pickedName), false
    turns.picked, turns.pickedName = nil, nil
    if not kind then return end
    local nearest, best
    for i, marker in ipairs(markers) do
        if marker.kind == kind and marker.yards and marker.yards <= PICK_REACH and (not name or Plain(marker.name) == name)
            and (not best or marker.yards < best) then nearest, best = i, marker.yards end
    end
    if nearest then
        table.remove(markers, nearest)
        gone = true
    end
    for i = #markers, 1, -1 do
        local marker = markers[i]
        if marker.held and marker.kind == kind and marker.yards and marker.yards <= PICK_REACH then
            table.remove(markers, i)
            gone = true
        end
    end
    if gone then ShowMarkers() end
end

-- A cooldown changed: a Skyborne racial just used takes its symbols away at once.
local function RacialsChanged()
    local gone = false
    for kind in pairs(RACIALS) do
        if not RacialReady(kind) and racialShown then
            for i = #markers, 1, -1 do
                if markers[i].kind == kind then
                    table.remove(markers, i)
                    gone = true
                end
            end
        end
    end
    if gone then ShowMarkers() end
end

-- After a settings change: start or stop the scan and rescan now.
-- Scanning off: frames a scan shrank still get their size back, then only Switch runs.
local function SettleOnly()
    xpcall(key.Settle, Oops)
    if db.switchFinders then SwitchFrame() end
    if not key.Settling() then tracker:SetScript("OnUpdate", db.switchFinders and SwitchFrame or nil) end
end
local function UpdateScanner()
    local on = Enabled()
    if not on and key.scan then -- the minimap back now, not when it's on again
        key.stopWhy = "scanning turned off"
        pcall(key.Stop)
    end
    -- Switch works without scans too: then only its own way runs each frame.
    ns.SwitchEvents(db.switchFinders == true)
    tracker:SetScript("OnUpdate", on and OnUpdate or (key.Settling() and SettleOnly) or (db.switchFinders and SwitchFrame) or nil)
    scan = nil
    if not on then markers = {} end
    for i = #markers, 1, -1 do
        if not KindOf(markers[i].name) then table.remove(markers, i) end
    end
    ShowMarkers()
    UpdateArrow()
    world.Update() -- clears the far marker when off
end

-- Key binding (Bindings.xml): toggles the minimap symbols.
BINDING_HEADER_NODESIGHT = "NodeSight"
BINDING_NAME_NODESIGHT_SYMBOLS = "Toggle Herb and Ore Symbols"
BINDING_NAME_NODESIGHT_SCAN = "Scan the minimap"
function NodeSight_ScanMinimap()
    local memory = collectgarbage("count")
    key.Start()
    if key.scan then key.scan.garbage = math.max(0, collectgarbage("count") - memory) end
end
function NodeSight_ToggleSymbols()
    if not tracker then return end -- (not loaded yet)
    db.mapIcons = not db.mapIcons
    UpdateScanner()
end

-- Scales the game's own minimap dots; left alone at 100 unless the slider moved.
local function ApplyDotScale()
    if Minimap.SetIconScale then Minimap:SetIconScale(db.dotScale / 100) end
end

-- Scan frame, draggable arrow (position saved in NodeSightDB.arrowPlace) and
-- the symbols' frame, all created without a parent (see NewSparkles).
local function NewScanner()
    tracker = CreateFrame("Frame")
    arrow = CreateFrame("Frame")
    arrow:SetParent(UIParent)
    local place = db.arrowPlace
    if place then
        arrow:SetPoint(place[1], UIParent, place[2], place[3], place[4])
    else
        arrow:SetPoint("TOP", UIParent, "TOP", 0, -170)
    end
    arrow:Hide()
    arrow:SetMovable(true)
    arrow:SetClampedToScreen(true)
    ApplyArrowLock()
    arrow:RegisterForDrag("LeftButton")
    local dragging = false
    -- Save the position on drop (or if hidden mid-drag).
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
    ApplyArrowSize()
    mapFrame = CreateFrame("Frame")
    mapFrame:SetParent(Minimap)
    mapFrame:SetAllPoints(Minimap)
end

---------------------------------------------------------------------------
-- Loading
---------------------------------------------------------------------------

-- What the other files use of this one.
ns.defaults, ns.SHAPES, ns.world = defaults, SHAPES, world
ns.FINDERS = FINDERS
ns.SKILL_LOOKS = SKILL.looks
ns.NEAR_LOOKS = NEAR_LOOKS
ns.PlayFindSound = PlayFindSound
ns.FIND_SOUND_NAMES = {}
for i, sound in ipairs(FIND_SOUNDS) do ns.FIND_SOUND_NAMES[i] = sound[1] end
ns.Clean, ns.MapPosition, ns.PlayerFacing = Clean, MapPosition, PlayerFacing
ns.UpdateScanner, ns.ApplyDotScale, ns.ApplyArrowLock = UpdateScanner, ApplyDotScale, ApplyArrowLock
ns.ApplyArrowSize = ApplyArrowSize
ns.turns, ns.SWITCH_WAIT, ns.Finders = turns, SWITCH_WAIT, Finders
-- A getter, since each scan replaces the list.
function ns.Markers() return markers end

-- For other addons: the symbols NodeSight has, each { name, kind ("herbs", "ore", "treasure",
-- "rares", "leyline", "convergence"), map (uiMapID), x, y (0-1 on that map), yards (from you,
-- as of the last update), held (another finder's, kept by Switch) }. A fresh list each call.
NodeSightAPI = {
    GetSymbols = function() return Symbols() end,
    -- callback(symbols) after each scan; an error in it is reported and doesn't stop NodeSight.
    RegisterCallback = function(callback)
        if type(callback) == "function" then apiCallbacks[#apiCallbacks + 1] = callback end
    end,
}
function ns.KeyLastJobs() return key.lastJobs, key.lastSkipped, key.lastSpots end

local MINIMAP_TOOLTIP = Enum.TooltipDataType.MinimapMouseover -- the minimap dots' tooltip type
local OBJECT_TOOLTIP = Enum.TooltipDataType.Object -- a herb's or ore's own tooltip

-- Settings: this character's own (NodeSightCharDB, the default, started from the
-- shared ones) or the ones shared by every character that has its own turned off
-- (NodeSightDB). Learned nodes and quest objects, rare names and the CVars to put
-- back are always shared.
local function LoadSettings()
    NodeSightDB = NodeSightDB or {}
    local SHARED = { learned = true, questObjects = true, saved = true, applied = true, rareNames = true, report = true }
    if type(NodeSightCharDB) ~= "table" then
        NodeSightCharDB = { own = true }
        for key, value in pairs(NodeSightDB) do
            if not SHARED[key] then NodeSightCharDB[key] = type(value) == "table" and CopyTable(value) or value end
        end
    end
    if NodeSightCharDB.own == false then return NodeSightDB end
    return setmetatable(NodeSightCharDB, {
        __index = function(_, key) if SHARED[key] then return NodeSightDB[key] end end,
        __newindex = function(t, key, value)
            if SHARED[key] then NodeSightDB[key] = value else rawset(t, key, value) end
        end,
    })
end

-- The notice shown once, and the settings page's first line.
local function Gold(text) return NORMAL_FONT_COLOR:WrapTextInColorCode(text) end
ns.SCAN_NOTICE = {
    "NodeSight: all features are working again",
    "WoW Forever's latest update broke how NodeSight read the minimap, so it now scans it a new way.\n\n"
        .. "It scans each time you've walked " .. defaults.autoScanYards .. " yards (" .. Gold("Scan by distance") .. "). On NodeSight's "
        .. "Scanning page you can change that, scan every few seconds instead (" .. Gold("Scan on a timer") .. "), or set a "
        .. Gold("Scan key") .. " (also in Options > Keybindings > AddOns > NodeSight).\n\n"
        .. "While it scans, under a second, your minimap is hidden, and zooming or clicking it does nothing. Holding a "
        .. "mouse button to turn pauses a scan until you let go. Automatic scans only happen while your mouse is over "
        .. "the world, not over a window, and out of combat unless you turn on " .. Gold("Scan in combat") .. ".\n\n"
        .. "A future Blizzard update could break this again.",
}

-- Lueur (another addon) scans the minimap the same way while its Herb icons or Ore icons are on
-- (on unless saved off): two scans at once break each other. Warned of at each login while both are on.
ns.LUEUR_NOTICE = {
    "NodeSight and Lueur both scan the minimap",
    "Lueur's " .. Gold("Herb icons") .. " and " .. Gold("Ore icons") .. " scan the minimap the same way NodeSight does. "
        .. "With both on they fight over your minimap and break each other.\n\n"
        .. "Turn off Lueur's Herb icons and Ore icons (type " .. Gold("/lueur nodes") .. ", or in Lueur's settings, Herbs and ore on the minimap), "
        .. "or turn off " .. Gold("Scan the minimap") .. " on NodeSight's page.",
}
local function LueurScans()
    if not db.scanMinimap or not C_AddOns.IsAddOnLoaded("Lueur") then return false end
    local saved = _G["LueurDB"]
    if type(saved) ~= "table" then return true end
    return saved.nodeHerbs ~= false or saved.nodeOre ~= false
end

-- Why the minimap scans aren't working: a red line at the top of the settings page (its
-- tooltip the rest), and for an error a notice when it happens.
ns.TROUBLE = {
    stopped = { "Automatic scans stopped after an error: type /reload", "NodeSight: automatic scans stopped after an error",
        "An error stopped NodeSight's scans on a timer and by distance until you type " .. Gold("/reload") .. ". "
            .. "Your Scan key still tries.\n\n"
            .. "If it happens again, please post the error on NodeSight's CurseForge page." },
    lueur = { "Lueur scans the minimap too: they break each other", ns.LUEUR_NOTICE[1], ns.LUEUR_NOTICE[2] },
    hidden = { "Your minimap is hidden: nothing to scan", "NodeSight: your minimap is hidden",
        "NodeSight finds herbs and ore by scanning your minimap, so it can't while the minimap is hidden." },
    finder = { "Find Herbs and Find Minerals are off: no scans as you move", "NodeSight: Find Herbs and Find Minerals are off",
        "Scans on a timer and by distance only run while Find Herbs or Find Minerals is on. "
            .. "Turn one on in your minimap's tracking menu." },
    nofinder = { "No Find Herbs or Find Minerals: learn Herbalism or Mining", "NodeSight: no Find Herbs or Find Minerals",
        "NodeSight finds herbs and ore by the dots Find Herbs and Find Minerals put on your minimap, and this character "
            .. "has neither. Learn Herbalism or Mining for the symbols and the arrow. Sparkles work without them." },
}
local function KnowsFinder()
    if not (C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo) then return false end
    for index = 1, C_Minimap.GetNumTrackingTypes() do
        local info = C_Minimap.GetTrackingInfo(index)
        if issecretvalue(info) then return false end
        local shows = info and not issecretvalue(info.spellID) and FINDERS[info.spellID]
        if shows == "herbs" or shows == "ore" then return true end
    end
    return false
end
-- The reason's key, line, title and text; nil when scanning works (or is off).
function ns.Trouble()
    local id
    if key.stopped then
        id = "stopped"
    elseif not Enabled() then
        return nil
    elseif LueurScans() then
        id = "lueur"
    elseif not Minimap:IsVisible() then
        id = "hidden"
    elseif (db.autoScan or TimerSeconds() > 0) and not FinderOn() then
        id = KnowsFinder() and "finder" or "nofinder"
    else
        return nil
    end
    local words = ns.TROUBLE[id]
    return id, words[1], words[2], words[3]
end
-- The bug report: NodeSight's setup and why scans may not run, then the log.
function ns.ReportText()
    local out = { "NodeSight bug report" }
    local function Line(fn)
        local ok, text = pcall(fn)
        out[#out + 1] = ok and text or ("(couldn't read: " .. tostring(text) .. ")")
    end
    local function On(v) return issecretvalue(v) and "secret" or tostring(v) end
    Line(function()
        local version, build = GetBuildInfo()
        return ("NodeSight %s, WoW %s (%s), %s, %s"):format(tostring(C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")), tostring(version),
            tostring(build), GetLocale(), date("%Y-%m-%d %H:%M"))
    end)
    Line(function()
        local id, line = ns.Trouble()
        return "Not scanning: " .. (id and (id .. ": " .. line) or "no")
    end)
    Line(function() return "Automatic scans now: " .. (ns.AutoWhy() or "not checked yet") end)
    Line(function()
        local chain, frame = {}, Minimap
        for _ = 1, 6 do
            local parent = frame:GetParent()
            if not parent then break end
            chain[#chain + 1] = ns.NameOf(parent)
            frame = parent
        end
        return ("Minimap: %s, %.0f x %.0f, scale %.2f, shape %s, rotating %s, in %s"):format(Minimap:IsVisible() and "shown" or "hidden",
            Minimap:GetWidth(), Minimap:GetHeight(), Minimap:GetEffectiveScale(), tostring(GetMinimapShape and GetMinimapShape() or "round"),
            tostring(C_CVar.GetCVar("rotateMinimap")), table.concat(chain, " < "))
    end)
    Line(function()
        return ("Screen: %.0f x %.0f, UI scale %.2f; gamepad: on %s, in use %s; finder on: %s, known: %s"):format(GetScreenWidth(), GetScreenHeight(),
            UIParent:GetEffectiveScale(), On(C_GamePad and C_GamePad.IsEnabled and C_GamePad.IsEnabled()), On(IsUsingGamepad and IsUsingGamepad()),
            tostring(FinderOn()), tostring(KnowsFinder()))
    end)
    Line(function()
        local P, M = C_AddOnProfiler, Enum and Enum.AddOnProfilerMetric
        if not (P and P.GetAddOnMetric and M and P.IsEnabled and P.IsEnabled()) then return "CPU: the game's profiler is off" end
        local function Readable(...)
            for i = 1, select("#", ...) do
                local v = select(i, ...)
                if issecretvalue(v) or type(v) ~= "number" then return false end
            end
            return true
        end
        -- As the game's addon list shows it: NodeSight's share of the time the game and it took.
        local function Share(metric)
            local mine, app, all = P.GetAddOnMetric(ADDON_NAME, M[metric]), P.GetApplicationMetric(M[metric]), P.GetOverallMetric(M[metric])
            if not (Readable(mine, app, all) and app - all + mine > 0) then return "?" end
            return ("%.1f%% (%.2f ms)"):format(mine / (app - all + mine) * 100, mine)
        end
        local function Count(metric)
            local n = P.GetAddOnMetric(ADDON_NAME, M[metric])
            return Readable(n) and tostring(n) or "?"
        end
        return ("CPU: average %s, now %s, peak %s; frames over 5 ms %s, over 10 ms %s, over 50 ms %s; the slowest scan frame this session %s"):format(
            Share("SessionAverageTime"), Share("RecentAverageTime"), Share("PeakTime"), Count("CountTimeOver5Ms"), Count("CountTimeOver10Ms"),
            Count("CountTimeOver50Ms"), ns.WorstScanFrame and ("%.1f ms"):format(ns.WorstScanFrame()) or "?")
    end)
    -- Lua frees what's no longer used now and then, so the game's number climbs and drops.
    Line(function()
        local now = "?"
        if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
            UpdateAddOnMemoryUsage()
            local kb = GetAddOnMemoryUsage(ADDON_NAME)
            if type(kb) == "number" and not issecretvalue(kb) then now = ("%.1f MB"):format(kb / 1024) end
        end
        local used, since = ns.MemoryUsed()
        local minutes = math.max(1 / 60, (GetTime() - since) / 60)
        return ("Memory: %s now (it climbs as NodeSight works and drops when the game clears what's no longer used); %d KB used a minute since loading"):format(
            now, used / minutes)
    end)
    Line(function()
        local changed = {}
        for key, value in pairs(defaults) do
            local now = db[key]
            if type(value) ~= "table" and type(now) ~= "table" and now ~= value then changed[#changed + 1] = key .. "=" .. tostring(now) end
        end
        table.sort(changed)
        return "Settings changed: " .. (changed[1] and table.concat(changed, ", ") or "none")
    end)
    Line(function()
        local list = {}
        for i = 1, C_AddOns.GetNumAddOns() do
            local name = C_AddOns.GetAddOnInfo(i)
            if type(name) == "string" and C_AddOns.IsAddOnLoaded(i) and not name:find("^Blizzard_") then
                local version = C_AddOns.GetAddOnMetadata(i, "Version")
                list[#list + 1] = version and (name .. " " .. version) or name
            end
        end
        return "Addons on: " .. table.concat(list, ", ")
    end)
    out[#out + 1] = "Log (seconds since the game started; newest last):"
    for _, line in ipairs(type(NodeSightDB) == "table" and NodeSightDB.report or reportLines) do out[#out + 1] = line end
    return table.concat(out, "\n")
end

-- Scans stopped by an error: off until a reload, and the notice says so.
function ns.ScansStopped()
    key.stopped = true
    if ns.ShowNotice then pcall(ns.ShowNotice, ns.TROUBLE.stopped[2], ns.TROUBLE.stopped[3]) end
end

local function OnAddonLoaded()
    local firstInstall = NodeSightDB == nil
    local settings = LoadSettings()
    if type(NodeSightDB.report) ~= "table" then NodeSightDB.report = {} end
    for _, line in ipairs(reportLines) do table.insert(NodeSightDB.report, line) end -- (said before it loaded)
    reportLines = {}
    ns.Log(("loaded %s, %s"):format(tostring(C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")), date("%Y-%m-%d %H:%M")))
    -- A first install has no update to tell of: its notes count as seen (no glow on What's New).
    if firstInstall then NodeSightDB.notesSeen = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") end
    ns.noticeDue = not NodeSightDB.scanNotice -- the notice about the scan, once, after the first loading screen
    ns.firstInstall = firstInstall -- a first install gets the setup window instead of that notice (Setup.lua)
    -- Far away sparkles don't work as well since build 70862: turned off once where they were on.
    if not settings.farTurnedOff then
        settings.worldMark, settings.farTurnedOff = false, true
        -- In-Game Navigation back as it was before they turned it on (if it still is on).
        if settings.navWas then
            if C_CVar.GetCVar("showInGameNavigation") == "1" then C_CVar.SetCVar("showInGameNavigation", settings.navWas) end
            settings.navWas = nil
        end
    end
    -- Scan in combat was on by default for the old scan; the new one hides the minimap: off once.
    if not settings.combatScanReset then settings.combatScan, settings.combatScanReset = false, true end
    -- Scan every (seconds) was off by default; now 10: moved there once, unless they scan as
    -- they move or chose another number.
    if not settings.autoScanTimerOn then
        if tonumber(settings.autoScanSeconds) == 0 and not settings.autoScan then settings.autoScanSeconds = 10 end
        settings.autoScanTimerOn = true
    end
    -- The stand-in looks like the minimap now: Map while scanning on and Fade in and out off,
    -- once for everyone.
    if not settings.groundLookSet then
        settings.scanMap, settings.scanFade, settings.groundLookSet = true, false, true
    end
    -- Scan on a timer has its own checkbox now: a timer at 0 (off) is the checkbox off. (A new
    -- install has no seconds saved: the defaults.)
    if settings.autoScanTimer == nil and settings.autoScanSeconds ~= nil then
        local seconds = tonumber(settings.autoScanSeconds)
        settings.autoScanTimer = seconds ~= 0
        if seconds == 0 then settings.autoScanSeconds = defaults.autoScanSeconds end
    end
    -- Automatic scans by default went from a timer every 10 seconds to Scan by distance every 25
    -- yards: moved once, only for those whose four settings are all the old defaults.
    if not settings.distanceDefault then
        if settings.autoScanTimer == true and tonumber(settings.autoScanSeconds) == 10
            and settings.autoScan == false and tonumber(settings.autoScanYards) == 30 then
            settings.autoScanTimer, settings.autoScan, settings.autoScanYards = false, true, 25
        end
        settings.distanceDefault = true
    end
    ns.CarryOverLooks(settings)
    -- Red symbols turned off, from before Skill colors: Off.
    if settings.skillLook == nil and settings.hard == false then settings.skillLook = SKILL.OFF end
    -- See-through near you ticked, from before Symbols near you.
    if settings.nearLook == nil and settings.clearNear == true then settings.nearLook = 2 end
    for key, value in pairs(defaults) do
        if settings[key] == nil then settings[key] = value end
    end
    -- Fix saved values the settings can't produce.
    if type(settings.styleLooks) ~= "table" then settings.styleLooks = {} end -- each style's look, per kind (the sparkle window)
    for _, kind in ipairs(ns.KINDS) do
        local keys = ns.SPARKLE_KEYS[kind]
        settings[keys.color] = tostring(settings[keys.color]):match("^%x%x%x%x%x%x%x%x$") or defaults[keys.color]
        local two = settings[keys.color2]
        settings[keys.color2] = two ~= nil and tostring(two):match("^%x%x%x%x%x%x%x%x$") or nil
        if not ns.StyleFits(settings[keys.style], kind) then settings[keys.style] = defaults[keys.style] end
        -- The look in use belongs to its style (one from before the window has no entry yet).
        local looks = settings.styleLooks
        if type(looks[kind]) ~= "table" then looks[kind] = {} end
        if looks[kind][settings[keys.style]] == nil then
            looks[kind][settings[keys.style]] = { size = settings[keys.size], height = settings[keys.height],
                count = settings[keys.count], color = settings[keys.color], color2 = settings[keys.color2] }
        end
    end
    if not SHAPES[settings.shape] then settings.shape = defaults.shape end
    if not SKILL.looks[settings.skillLook] then settings.skillLook = defaults.skillLook end
    if not ns.MAP_SHAPES[settings.minimapShape] then settings.minimapShape = defaults.minimapShape end
    if not NEAR_LOOKS[settings.nearLook] then settings.nearLook = defaults.nearLook end
    if not FIND_SOUNDS[settings.soundKit] then settings.soundKit = defaults.soundKit end
    if not ns.HARVESTS[settings.harvest] then settings.harvest = defaults.harvest end
    if not ICONS.rares[settings.rareIcon] then settings.rareIcon = defaults.rareIcon end
    if not ns.SWITCH_MEASURES[settings.switchMeasure] then settings.switchMeasure = defaults.switchMeasure end
    -- A hand-edited distance: a number in its slider's range, else the default.
    for key, range in pairs(ns.SWITCH_RANGES) do
        local value = tonumber(settings[key]) or defaults[key]
        settings[key] = math.max(range[1], math.min(range[2], value))
    end
    settings.switchYards = nil -- (replaced by switchPercent)
    settings.clearNear = nil -- (replaced by nearLook)
    db = settings
    ns.db = db
    NewScanner()
    UpdateScanner()
    -- CVars changed by the addon: original (saved) and set (applied) values.
    NodeSightDB.saved = NodeSightDB.saved or {}
    NodeSightDB.applied = NodeSightDB.applied or {}
    -- Nodes learned by gathering (see Learn).
    NodeSightDB.learned = NodeSightDB.learned or {}
    -- Registered with the gamepad UI on too; it works there.
    ns.RegisterSettings()
    -- The "Requires ..." line in the minimap's tooltip and a node's own.
    if MINIMAP_TOOLTIP then TooltipDataProcessor.AddTooltipPostCall(MINIMAP_TOOLTIP, OnMinimapTooltip) end
    if OBJECT_TOOLTIP then TooltipDataProcessor.AddTooltipPostCall(OBJECT_TOOLTIP, OnObjectTooltip) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_LEAVING_WORLD")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("GAME_PAD_ALLOW_HOVER_EVENTS_WITH_FREE_LOOK_CHANGED")
events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
events:RegisterEvent("LOOT_READY")
events:RegisterEvent("LOOT_CLOSED")
events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
events:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
events:RegisterEvent("SKILL_LINES_CHANGED")
events:RegisterEvent("MINIMAP_UPDATE_TRACKING")
events:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            events:UnregisterEvent("ADDON_LOADED")
            -- After an update, a /reload only loads the files the old .toc listed:
            -- stay off until the game is restarted.
            if not (ns.Plain and ns.RareID and ns.MinimapQuarters and ns.Mute and ns.Setup and world.Update and ns.ShowSparkleWindow and ns.ShowWhatsNew and ns.RegisterSettings) then
                events:UnregisterAllEvents()
                if ns.ShowNotice then
                    pcall(ns.ShowNotice, "NodeSight needs a game restart", "NodeSight was updated while the game was running, "
                        .. "and the game only loads its new files when it starts. It stays off until you exit the game and start it again.")
                end
                return
            end
            OnAddonLoaded()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        ns.QuestAreasBack()
        ns.PadHoverBack()
        if world.PinBack then pcall(world.PinBack) end
        if world.NavIn then pcall(world.NavIn) end
        if (arg1 or arg2) and LueurScans() then -- (a login or reload; the scan notice waits)
            ns.ShowNotice(ns.LUEUR_NOTICE[1], ns.LUEUR_NOTICE[2])
        elseif ns.noticeDue then
            ns.noticeDue = false
            NodeSightDB.scanNotice = true
            if ns.firstInstall and ns.ShowSetupOnce then
                ns.ShowSetupOnce()
            else
                ns.ShowNotice(ns.SCAN_NOTICE[1], ns.SCAN_NOTICE[2])
            end
        end
        NewPlace()
        if db.dotScale ~= NORMAL_DOTS then ApplyDotScale() end
        -- Restores CVars left changed (e.g. a restore delayed by combat).
        ns.Setup() -- after every loading screen
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        -- Free the plate's sparkle frame.
        if next(ns.sparkles) or next(ns.leaving) then ns.HideSparkles(C_NamePlate.GetNamePlateForUnit(arg1)) end
    elseif event == "UNIT_SPELLCAST_SENT" then
        NoteCast(arg2)
    elseif event == "LOOT_READY" then
        Learn()
    elseif event == "LOOT_CLOSED" then
        Picked() -- you may have just picked a herb
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        RacialsChanged()
    elseif event == "MINIMAP_UPDATE_TRACKING" then
        key.TrackingChanged()
    elseif event == "SKILL_LINES_CHANGED" then
        -- Herbalism or Mining went up: read them again, and gray sparkles may not be any more.
        skills.herbs, skills.ore = nil, nil
        wipe(ns.hasProfession) -- (a profession learned or dropped: Only for my professions)
        ns.UpdateAll()
    elseif event == "PLAYER_LOGOUT" then
        -- A reload or logout: the game settings the sparkles and far sparkles set, back as they
        -- were (set again at login), so turning NodeSight off leaves none changed.
        if ns.SetupOut then pcall(ns.SetupOut) end
        if world.NavOut then pcall(world.NavOut) end
    elseif event == "PLAYER_LEAVING_WORLD" then
        -- A reload, a logout or a loading screen: a scan under way stops now, so the quest
        -- areas and the minimap are put back before the game saves anything.
        if ns.KeyScanning() then
            key.stopWhy = "a reload, logout or loading screen"
            pcall(key.Stop)
        end
        if world.at or world.peek then pcall(world.Back) end -- (your map pin, from the far sparkles)
        pcall(key.Flush)
    elseif event == "GAME_PAD_ALLOW_HOVER_EVENTS_WITH_FREE_LOOK_CHANGED" then
        key.PadHoverChanged()
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Another addon made the minimap protected: put it back before the lockdown.
        if key.scan and (Minimap:IsProtected() or key.HoldsProtected()) then
            key.stopWhy = "a fight started (the minimap or a frame on it is protected)"
            pcall(key.Stop)
        end
        world.Fight()
        if db.combatHide then ns.UpdateAll() end
    else -- PLAYER_REGEN_ENABLED
        world.fight = nil
        key.foughtAt = GetTime()
        if ns.SetupPending() then ns.Setup() end
        if db.combatHide then ns.UpdateAll() end
    end
end)
