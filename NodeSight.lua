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
    nearLook = 1, -- a symbol over your own arrow: 1 shown, 2 see-through, 3 hidden
    sound = false, -- sound when something new shows up
    soundKit = 1, -- which sound (FIND_SOUNDS)
    soundSkillUps = false, -- the sound only for herbs and ore that can give a skill-up
    autoScan = false, -- scan each time you've moved autoScanYards, out of combat, not flying
    autoScanYards = 30, -- yards between scans as you move
    autoScanSeconds = 0, -- also a scan once this many seconds have passed and you move (0: off)
    combatScan = false, -- Scan as you move and the timer in combat too
    skipRest = true, -- no Scan as you move or timer while resting (capital cities and inns)
    minimapShape = 1, -- 1 automatic (asks your UI addon), 2 round, 3 square
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
    rareGlow = false, -- a gold glow around rare herbs and ore
    harvest = 5, -- how a gathered node finishes (Sparkles.lua's HARVESTS: Fade away)
}
local db = defaults -- NodeSightDB once it's loaded
ns.db = db -- shared with the other files

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
-- Switch state: kind, scanned, picked (see ns.TrySwitch and Picked).
local turns = {}
local racialShown = false -- the last scan found a leyline or convergence

local function Enabled()
    if not Minimap.UpdateMouseoverAtPoint then return false end -- Retail: the scan is only for Forever
    return db.arrow or db.mapIcons or db.sound or db.worldMark
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

-- Switches finder between scans, once one of the current kind is done (with Scan as you
-- move or its timer; else whenever) and ns.SwitchReady agrees; true if it did.
function ns.TrySwitch()
    if (ns.KeyScanning and ns.KeyScanning()) or not Minimap:IsVisible() then return false end
    local kind, other = Finders()
    local scanning = db.autoScan or (tonumber(db.autoScanSeconds) or 0) > 0
    if not (kind and other and C_Minimap.SetTracking and (turns.scanned or not scanning)) then return false end
    local target = kind == "herbs" and "ore" or "herbs"
    if not ns.SwitchReady(target) then return false end
    ns.Mute()
    ns.switch.pending = { kind = target, at = GetTime() } -- before SetTracking, which may fire its event
    C_Minimap.SetTracking(other, true)
    turns.scanned = false
    return true
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

-- New symbol texture (sized later by ApplySize).
local function NewIcon()
    local texture = mapFrame:CreateTexture(nil, "OVERLAY")
    return { texture = texture, hard = false }
end

-- Circle mask for a symbol or its ring.
local function NewMask(region)
    local mask = mapFrame:CreateMaskTexture()
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
    local target = db.arrow and Target()
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
    turns.scanned = true
    turning = rotating
    markers = found
    lastMap = nil -- make Follow recompute
    ShowMarkers()
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
    local TINY = 0.05 -- icon scale while scanning: hides your arrow too
    local quietUntil = 0 -- the minimap's tooltip is closed until then
    local nextCheck = 0 -- when Scan as you move looks again
    local phase = 0 -- which of the three honeycombs this scan uses (see StartKeyScan)
    local scans = 0 -- scans so far (every third checks the symbols already measured)

    -- Turning the camera with either mouse button (the left one doesn't count as mouselook).
    local function Mouselooking()
        return (IsMouselooking and IsMouselooking())
            or (IsMouseButtonDown and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")))
    end

    -- A window or button under the mouse that isn't the minimap's or NodeSight's (bags opened
    -- mid-scan, an item in them): the minimap can't be read through it.
    local COVERED_WAIT = 2 -- seconds a scan waits paused for the mouse to leave a window
    local function Covered()
        local foci = GetMouseFoci and GetMouseFoci()
        local focus = type(foci) == "table" and foci[1] or nil
        if focus == nil or focus == WorldFrame then return false end
        for _ = 1, 20 do
            if focus == nil then return true end -- (the top: a window of its own)
            if focus == Minimap or focus == mapFrame or focus == arrow then return false end
            local ok, parent = pcall(focus.GetParent, focus)
            if not ok then return true end
            focus = parent
        end
        return true
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

    -- While scanning the minimap is under the mouse: its mouse wheel (zoom) and clicks
    -- (a ping) are off, so the wheel zooms the camera; hovering stays on for the scan.
    -- The group finder's eye is anchored to the minimap but not on it: hidden too.
    local function Disguise(s, on)
        if on and s.wheel == nil and Minimap.IsMouseWheelEnabled and Minimap.IsMouseClickEnabled then
            s.wheel, s.clicks = Minimap:IsMouseWheelEnabled(), Minimap:IsMouseClickEnabled()
        end
        if s.wheel ~= nil then
            pcall(Minimap.EnableMouseWheel, Minimap, not on and s.wheel)
            pcall(Minimap.SetMouseClickEnabled, Minimap, not on and s.clicks)
        end
        pcall(Minimap.SetAlpha, Minimap, on and 0 or s.alpha)
        if s.coords then pcall(s.coords.SetAlpha, s.coords, on and 0 or s.coordsAlpha) end
        if Minimap.SetIconScale then
            ourScale = true
            pcall(Minimap.SetIconScale, Minimap, on and TINY or db.dotScale ~= NORMAL_DOTS and db.dotScale / 100 or iconScale)
            ourScale = false
        end
        -- Buttons on the minimap (an addon's calendar or clock, map pins) move with it under the
        -- mouse: no clicks on them either (a quick click would land on one), back after.
        -- The game's protected ones can't be changed in a fight: left alone.
        if on and not s.noClicks then
            s.noClicks = {}
            local function Walk(frame, depth)
                for _, child in ipairs({ frame:GetChildren() }) do
                    if child ~= mapFrame and child.IsMouseClickEnabled and child:IsMouseClickEnabled()
                        and not (InCombatLockdown() and child:IsProtected()) then
                        s.noClicks[#s.noClicks + 1] = child
                        child:SetMouseClickEnabled(false)
                    end
                    if depth < 3 then Walk(child, depth + 1) end
                end
            end
            pcall(Walk, Minimap, 1)
        elseif not on and s.noClicks then
            for _, child in ipairs(s.noClicks) do pcall(child.SetMouseClickEnabled, child, true) end
            s.noClicks = nil
        end
        local eye = QueueStatusButton
        if eye then
            if on and s.eyeAlpha == nil then s.eyeAlpha, s.eyeMouse = eye:GetAlpha(), eye:IsMouseEnabled() end
            if s.eyeAlpha ~= nil then
                pcall(eye.SetAlpha, eye, on and 0 or s.eyeAlpha)
                pcall(eye.EnableMouse, eye, not on and s.eyeMouse)
            end
        end
        ns.HideQuestAreas(s, on)
    end

    -- Stand-in while the minimap moves about unseen: our symbols' frame goes onto UIParent
    -- over the minimap's spot (same size and scale), over copies of a dark ground, its gold
    -- frame, your arrow and the coordinates; all back after.
    local stand -- the copies' frame

    -- A region's offset from the minimap's middle and its size, in stand units (eff: stand's scale).
    local function Measure(region, eff)
        local x, y = region:GetCenter()
        local mx, my = Minimap:GetCenter()
        local own = region:GetEffectiveScale()
        if not (x and mx) or issecretvalue(x) or issecretvalue(y) or issecretvalue(own) then return nil end
        return (x * own - mx * Minimap:GetEffectiveScale()) / eff, (y * own - my * Minimap:GetEffectiveScale()) / eff,
            region:GetWidth() * own / eff, region:GetHeight() * own / eff
    end

    local function StandArrow()
        if not stand or not stand:IsShown() then return end
        local rotating = C_CVar.GetCVar("rotateMinimap") == "1"
        local atlas = rotating and "Rotating-MinimapArrow" or "MinimapArrow"
        local angle = not rotating and PlayerFacing() or 0
        local coords = Coords()
        local text = coords and coords.CoordText and coords.CoordText:GetText()
        if issecretvalue(text) or not text then text = "" end
        -- Only what changed.
        if atlas ~= stand.atlas then stand.atlas = atlas stand.arrow:SetAtlas(atlas) end
        if angle ~= stand.angle then stand.angle = angle stand.arrow:SetRotation(angle) end
        if text ~= stand.text then stand.text = text stand.coords:SetText(text) end
    end

    local function PinSymbols(s, on)
        if on then
            local left, bottom = Minimap:GetLeft(), Minimap:GetBottom()
            if not left or not bottom then return end
            local width, height = Minimap:GetWidth(), Minimap:GetHeight()
            local eff = Minimap:GetEffectiveScale()
            s.pinned = { level = mapFrame:GetFrameLevel() }
            if not stand then
                stand = CreateFrame("Frame")
                stand:SetParent(UIParent)
                stand.ground = stand:CreateTexture(nil, "BACKGROUND")
                stand.ground:SetColorTexture(0, 0, 0, 0.35) -- light: the world shows through
                stand.mask = stand:CreateMaskTexture()
                stand.mask:SetAtlas(CIRCLE)
                stand.mask:SetAllPoints(stand.ground)
                stand.round = false -- the mask goes on when the minimap is round
                stand.frame = stand:CreateTexture(nil, "OVERLAY")
                stand.arrow = stand:CreateTexture(nil, "OVERLAY", nil, 1)
                stand.arrow:SetPoint("CENTER")
                stand.coords = stand:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            end
            for _, f in ipairs({ stand, mapFrame }) do
                f:SetParent(UIParent)
                f:SetScale(eff / UIParent:GetEffectiveScale())
                f:SetFrameStrata(Minimap:GetFrameStrata())
                f:ClearAllPoints()
                f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
                f:SetSize(width, height)
            end
            stand:SetFrameLevel(math.max(0, s.pinned.level - 1))
            mapFrame:SetFrameLevel(s.pinned.level)
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
            local size = 20 * (db.dotScale or 100) / 100 -- about the game's arrow, at the dots' size
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
            stand:Show()
            StandArrow()
        elseif s.pinned then
            mapFrame:SetParent(Minimap)
            mapFrame:SetScale(1)
            mapFrame:SetFrameLevel(s.pinned.level)
            mapFrame:ClearAllPoints()
            mapFrame:SetAllPoints(Minimap)
            stand:Hide()
            s.pinned = nil
        end
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

    -- Puts spot i (where it was at the scan's start) under the mouse, where it will be next
    -- frame when the game looks (as far as it moved over the last frame).
    local function KeyPlace(s, i)
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
                if old.x and not old.held and not old.far and not other and not s.known[old] then
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
    local function KeyStop(finds)
        local s = key.scan
        key.scan = nil
        key.lastJobs, key.lastSpots = s.jobs or 0, s.gridSpots -- dots measured closely, grid spots
        quietUntil = GetTime() + 0.25
        pcall(Minimap.AdjustPointsOffset, Minimap, -s.ox, -s.oy)
        Disguise(s, false)
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

    -- A mouse button held mid-scan (the game hides and holds the cursor): the scan pauses
    -- with the minimap back as it looks, and goes on from the same spot when it's let go.
    local function Pause(s, on)
        if on then
            pcall(Minimap.AdjustPointsOffset, Minimap, -s.ox, -s.oy)
            s.ox, s.oy = 0, 0
            Disguise(s, false)
            PinSymbols(s, false)
        else
            PinSymbols(s, true)
            Disguise(s, true)
            s.lastX, s.lastY = nil, nil -- the mouse's last move says nothing now
        end
        s.paused = on
    end

    local function KeyScanFrame()
        local s = key.scan
        if not Minimap:IsVisible() then return KeyStop() end
        -- A rotating minimap turned mid-scan has turned its picture: the scan stops (the
        -- minimap back, the symbols as they were) and runs again a moment after.
        local facing = s.facing and PlayerFacing()
        if facing and math.abs((facing - s.facing + math.pi) % (2 * math.pi) - math.pi) > 0.03 then
            KeyStop()
            key.wanted, key.wantedAt = true, GetTime() + 0.3
            return
        end
        -- A window under the mouse (bags opened mid-scan) pauses it too, for 2 s at most: then
        -- it's dropped (the symbols as they were), so the minimap doesn't vanish much later.
        local covered = Covered()
        if covered then
            s.coveredAt = s.coveredAt or GetTime()
            if GetTime() - s.coveredAt > COVERED_WAIT then return KeyStop() end
        else
            s.coveredAt = nil
        end
        if covered or Mouselooking() then
            if not s.paused then Pause(s, true) end
            return
        end
        if s.paused then
            Pause(s, false)
            if s.at then return KeyPlace(s, s.at) end -- that spot looked at again
        end
        StandArrow()
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

    -- auto: from Scan as you move or its timer (it skips spots inside symbols already measured
    -- two scans in three).
    local function StartKeyScan(auto)
        if key.scan or not tracker or not Enabled() or not Minimap:IsVisible() or not Minimap:GetLeft() then return end
        -- Not in dungeons, raids, battlegrounds or arenas (there the game gives no map
        -- position to follow the symbols by).
        local inside = IsInInstance()
        if issecretvalue(inside) or inside then return end
        if (InCombatLockdown() and Minimap:IsProtected()) or Covered() then return end
        if Mouselooking() then
            key.wanted = true
            return
        end
        -- Just after a finder switch the new finder's dots aren't on the minimap yet: the scan
        -- waits for them.
        local pending = ns.switch and ns.switch.pending
        if pending and GetTime() < pending.at + SWITCH_WAIT then
            key.wanted, key.wantedAt = true, pending.at + SWITCH_WAIT
            return
        end
        -- A rotating minimap: not while you turn (the scan would stop at once).
        if C_CVar.GetCVar("rotateMinimap") == "1" then
            local facing = PlayerFacing()
            if facing and facing ~= key.facing then
                key.facing = facing
                key.wanted, key.wantedAt = true, GetTime() + 0.1
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
        local spots, row, skippedSpots = {}, 0, 0
        for y = rowGap / 2 - half + shiftY, half, rowGap do
            local start = (row % 2 == 1 and step / 2 or 0) + shiftX
            row = row + 1
            for x = -half + start % step, half, step do
                if ns.InShape(x, y, half, quarters) then
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
        key.last = map and { map = map, x = px, y = py } or nil
        key.lastAt = GetTime()
        -- Spots are from the minimap's middle; KeyPlace wants them from its bottom left.
        for _, spot in ipairs(spots) do spot[1], spot[2] = spot[1] + half, spot[2] + half end
        key.lastSkipped = skippedSpots
        local gridSpots = #spots
        local pin = {}
        PinSymbols(pin, true)
        key.scan = { pinned = pin.pinned, facing = C_CVar.GetCVar("rotateMinimap") == "1" and PlayerFacing() or nil, spots = spots, gridSpots = gridSpots, width = width, step = step, skipped = skipped, precision = PRECISION,
            ox = 0, oy = 0, hits = {},
            p0 = map and { map = map, x = px, y = py, width = mapWidth, height = mapHeight } or nil,
            left = Minimap:GetLeft(), bottom = Minimap:GetBottom(), alpha = Minimap:GetAlpha(), coords = Coords() }
        if key.scan.coords then key.scan.coordsAlpha = key.scan.coords:GetAlpha() end
        Disguise(key.scan, true)
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
    -- under the mouse: every tooltip is closed while scanning and a moment after.
    -- Not a window's own (an item in your bags hovered mid-scan): that one stays.
    GameTooltip:HookScript("OnShow", function(tip)
        if (key.scan or GetTime() < quietUntil) and not Covered() then tip:Hide() end
    end)
    -- A tooltip already shown (a unit's, say) gets the minimap's text without opening again:
    -- closed after the minimap fills it.
    if GameTooltip.SetMinimapMouseover then
        hooksecurefunc(GameTooltip, "SetMinimapMouseover", function(tip)
            if key.scan or GetTime() < quietUntil then tip:Hide() end
        end)
    end
    -- Scan as you move and the timer: out of combat (unless Scan in combat), not resting (in
    -- a city or an inn, unless that's turned off), not flying (on a mount or a flight path),
    -- with a finder on and the mouse over the world.
    function key.Auto()
        local now = GetTime()
        if now < nextCheck then return end
        nextCheck = now + 0.25
        local seconds = tonumber(db.autoScanSeconds) or 0
        if not (db.autoScan or seconds > 0) or not Enabled() then return end
        if not FinderOn() then
            if markers[1] and not key.scan and not (ns.switch and ns.switch.pending) then
                markers = {}
                ShowMarkers()
                UpdateArrow()
            end
            return
        end
        if (InCombatLockdown() and not db.combatScan) or (db.skipRest and IsResting()) or Mouselooking() or (IsFlying and IsFlying())
            or (UnitOnTaxi and UnitOnTaxi("player")) then return end
        local foci = GetMouseFoci and GetMouseFoci()
        local focus = type(foci) == "table" and foci[1] or nil
        if focus ~= nil and focus ~= WorldFrame then return end
        local map, x, y, width, height = MapPosition()
        if not map then return end
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
        local timed = seconds > 0 and now - (key.lastAt or now) >= seconds and stepping
        if moved or timed then StartKeyScan(true) end
    end
    key.Start, key.Frame, key.Stop, key.Mouselooking = StartKeyScan, KeyScanFrame, KeyStop, Mouselooking
    function ns.KeyScanning() return key.scan ~= nil end -- (Switch: no switch during a scan)
end)()

---------------------------------------------------------------------------
-- Running the scan
---------------------------------------------------------------------------

-- The far sparkles (Beta): FarSparkles.lua fills this table.
local world = { others = {} }

-- Every frame: the scan or its wait, then the places, arrow, far sparkles and the switch's way.
local function OnUpdate()
    -- Quest areas a scan couldn't put back on (the game refused): tried again each second.
    if NodeSightDB.questOff and not key.scan and GetTime() >= (key.backAt or 0) then
        key.backAt = GetTime() + 1
        ns.QuestAreasBack()
    end
    -- The scan: on its key, or as you move (Scan as you move).
    if key.scan then
        if not xpcall(key.Frame, geterrorhandler()) then pcall(key.Stop) end
    elseif key.stopped then -- (an error starting a scan: reported once, off until a reload)
    elseif key.wanted and not key.Mouselooking() and GetTime() >= (key.wantedAt or 0) then
        key.wanted = nil
        if not xpcall(key.Start, geterrorhandler()) then key.stopped = true end
    elseif db.autoScan or (tonumber(db.autoScanSeconds) or 0) > 0 then
        if not xpcall(key.Auto, geterrorhandler()) then key.stopped = true end
    end
    -- A failed symbol or arrow update would fail again every frame: report it once and
    -- clear the symbols, so there is nothing to update until a scan finds them again.
    if not (xpcall(Follow, geterrorhandler()) and xpcall(UpdateArrow, geterrorhandler())) then
        markers = {}
        pcall(ShowMarkers)
        pcall(UpdateArrow) -- no target left: hides the arrow
    end
    -- A failed far marker would fail again every frame: report it once, hide its sparkles
    -- and stop it until the next reload (world.Update then only puts your map pin back).
    if not xpcall(world.Update, geterrorhandler()) and not world.stopped then
        world.stopped, world.hide = true, false
        pcall(world.Out)
    end
    -- An error in the switch would repeat every frame: report it once and stop it until
    -- the next reload.
    if db.switchFinders and not ns.switch.stopped and not xpcall(ns.SwitchUpdate, geterrorhandler()) then
        ns.switch.stopped = true
    end
end

-- After a loading screen, old places are stale.
local function NewPlace()
    if key.scan then pcall(key.Stop) end -- a scan under way read the old place: dropped
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
local function UpdateScanner()
    local on = Enabled()
    if not on and key.scan then pcall(key.Stop) end -- the minimap back now, not when it's on again
    ns.SwitchEvents(on and db.switchFinders == true)
    tracker:SetScript("OnUpdate", on and OnUpdate or nil)
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
function NodeSight_ScanMinimap() key.Start() end
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
function ns.KeyLastJobs() return key.lastJobs, key.lastSkipped, key.lastSpots end

local MINIMAP_TOOLTIP = Enum.TooltipDataType.MinimapMouseover -- the minimap dots' tooltip type
local OBJECT_TOOLTIP = Enum.TooltipDataType.Object -- a herb's or ore's own tooltip

-- Settings: this character's own (NodeSightCharDB, the default, started from the
-- shared ones) or the ones shared by every character that has its own turned off
-- (NodeSightDB). Learned nodes and quest objects, rare names and the CVars to put
-- back are always shared.
local function LoadSettings()
    NodeSightDB = NodeSightDB or {}
    local SHARED = { learned = true, questObjects = true, saved = true, applied = true, rareNames = true }
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
        .. "Set a key with " .. Gold("Scan key") .. " on NodeSight's Scanning page (or Options > Keybindings > AddOns > "
        .. "NodeSight), or turn on " .. Gold("Scan as you move") .. " there.\n\n"
        .. "While it scans, under a second, your minimap is hidden, and zooming or clicking it does nothing. Holding a "
        .. "mouse button to turn pauses a scan until you let go. Scan as you move only scans while your mouse is over "
        .. "the world, not over a window, and out of combat unless you turn on " .. Gold("Scan in combat") .. ".\n\n"
        .. "A future Blizzard update could break this again.",
}

local function OnAddonLoaded()
    local firstInstall = NodeSightDB == nil
    local settings = LoadSettings()
    -- A first install has no update to tell of: its notes count as seen (no glow on What's New).
    if firstInstall then NodeSightDB.notesSeen = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") end
    ns.noticeDue = not NodeSightDB.scanNotice -- the notice about the scan, once, after the first loading screen
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
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
events:RegisterEvent("LOOT_READY")
events:RegisterEvent("LOOT_CLOSED")
events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
events:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
events:RegisterEvent("SKILL_LINES_CHANGED")
events:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            events:UnregisterEvent("ADDON_LOADED")
            -- After an update, a /reload only loads the files the old .toc listed:
            -- stay off until the game is restarted.
            if not (ns.Plain and ns.RareID and ns.MinimapQuarters and ns.Mute and ns.Setup and world.Update and ns.ShowSparkleWindow and ns.ShowWhatsNew and ns.RegisterSettings) then
                events:UnregisterAllEvents()
                return
            end
            OnAddonLoaded()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        ns.QuestAreasBack()
        if ns.noticeDue then
            ns.noticeDue = false
            NodeSightDB.scanNotice = true
            ns.ShowNotice(ns.SCAN_NOTICE[1], ns.SCAN_NOTICE[2])
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
    elseif event == "SKILL_LINES_CHANGED" then
        -- Herbalism or Mining went up: read them again, and gray sparkles may not be any more.
        skills.herbs, skills.ore = nil, nil
        ns.UpdateAll()
    elseif event == "PLAYER_LEAVING_WORLD" then
        -- A reload, a logout or a loading screen: a scan under way stops now, so the quest
        -- areas and the minimap are put back before the game saves anything.
        if ns.KeyScanning() then pcall(key.Stop) end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Another addon made the minimap protected: put it back before the lockdown.
        if key.scan and Minimap:IsProtected() then pcall(key.Stop) end
        world.Fight()
        if db.combatHide then ns.UpdateAll() end
    else -- PLAYER_REGEN_ENABLED
        world.fight = nil
        if ns.SetupPending() then ns.Setup() end
        if db.combatHide then ns.UpdateAll() end
    end
end)
