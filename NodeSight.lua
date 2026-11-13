-- AI has done an awful job at commenting on the code. I'm going to try and fix
-- it up within the next few updates and put most of my mods on GitHub. I did
-- not expect so many people to be going through this and to be so interested!
-- Thank you to everyone trying my addons. I appreciate you all, this has made
-- my year.
--
-- NodeSight: the herb or ore in front of you sparkles, its tooltip says the skill it
-- needs, and Find Herbs and Find Minerals can take turns as you travel.
--
-- Files, in load order (they share functions through the addon table `ns`):
--   Locales\*.lua    node names in other languages (each loads only on its client)
--   QuestObjects.lua names of quest objects, for their sparkles
--   Names.lua        node names, icons and skill levels
--   NodeSight.lua    defaults, the tooltip line, loading and events
--   Switch.lua       the finder switch: when to switch, whether it worked, and the mute of its click
--   Sparkles.lua     sparkles on the herb or ore in front of you
--   SparkleWindow.lua the sparkle window: on/off and the look for each kind, with a 3D preview
--   WhatsNew.lua     the patch notes dialog
--   MinimapButton.lua the minimap button
--   Settings.lua     the settings pages
--
-- The game hides the names of minimap dots from addons (secret values), so nothing on
-- the minimap can be read: NodeSight has no minimap symbols or arrow.
--
-- Sections: Switching finders, Tooltip, Minimap, Loading.

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
    skillLine = true, -- "Requires Herbalism (15)" in herb and ore tooltips
    popups = true, -- NodeSight's popups (ns.AfterFight)
    switchFinders = false, -- Find Herbs and Find Minerals in turn
    switchMeasure = 1, -- how the distance between switches is measured: 1 percent, 2 yards, 3 seconds
    switchPercent = 40, -- distance between switches, in percent of the minimap's view radius
    switchDistanceYards = 60, -- distance between switches in yards
    switchSeconds = 8, -- seconds on the move between switches
    switchMounted = false, -- switch only while mounted
    switchPauseBusy = true, -- no switch while casting, looting or with something on the cursor
    switchPauseStealth = true, -- no switch while stealthed
    switchAfterCast = 3, -- seconds without a switch after your own spells (0 off)
    switchEnemyYards = 40, -- no switch with an enemy this close targeted (0 off)
    switchWorld = true, switchDungeons = true, switchRaids = true, -- where to switch
    switchBattlegrounds = false, -- off, not needed there and it would rather get in the way
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
    minimapButton = true, -- the minimap button (its place: minimapIcon, LibDBIcon's)
}
local db = defaults -- NodeSightDB once it's loaded
ns.db = db -- shared with the other files

-- From Names.lua.
local NodeKind = ns.NodeKind
local skills, professions, SkillLevel = ns.skills, ns.professions, ns.SkillLevel

---------------------------------------------------------------------------
-- Switching finders
---------------------------------------------------------------------------
-- The minimap shows one finder's dots at a time. The Switch setting toggles Find Herbs
-- and Find Minerals as you move (Switch.lua decides when).

-- Tracking spell IDs: Find Herbs, Find Minerals.
local FINDERS = { [2383] = "herbs", [2580] = "ore" }
local SWITCH_WAIT = 1 -- seconds from a switch to its verdict (Switch.lua)
local turns = {} -- shared with Switch.lua

-- Active finder kind and the other's tracking index; nil unless exactly one is on.
local function Finders()
    if not (C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo) then return nil end
    local on, off, active = nil, nil, 0
    for index = 1, C_Minimap.GetNumTrackingTypes() do
        local info = C_Minimap.GetTrackingInfo(index)
        if issecretvalue(info) then return nil end
        local shows = info and not issecretvalue(info.spellID) and FINDERS[info.spellID]
        if shows then -- (not Find Treasure or creature tracking)
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
function ns.TrySwitch()
    if not Minimap:IsVisible() then return false end
    local kind, other = Finders()
    if not (kind and other and C_Minimap.SetTracking) then return false end
    local target = kind == "herbs" and "ore" or "herbs"
    if not ns.SwitchReady(target) then return false end
    ns.Mute()
    ns.switch.pending = { kind = target, at = GetTime() } -- before SetTracking, which may fire its event
    C_Minimap.SetTracking(other, true)
    return true
end

-- The switch's way, every frame while it's on. An error in it would repeat every frame:
-- reported once, and the switch stops until the next reload.
local ticker
local function SwitchFrame()
    if db.switchFinders and not ns.switch.stopped and not xpcall(ns.SwitchUpdate, geterrorhandler()) then
        ns.switch.stopped = true
    end
end
local function UpdateSwitch()
    ns.SwitchEvents(db.switchFinders == true)
    ticker:SetScript("OnUpdate", db.switchFinders and SwitchFrame or nil)
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------
-- A herb's or ore's own tooltip (the mouse on it in the world) gets a "Requires
-- Herbalism (15)" line: red if your skill is too low, else in the profession window's
-- colors for the chance of a skill-up. Herb and ore items get "Gathered with Herbalism
-- (15)", for the easiest node they come from, in the same colors.

-- Strips color codes and inline textures from a tooltip line.
local function Clean(text)
    text = text:gsub("|A.-|a", ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return text:match("^%s*(.-)%s*$")
end

local function SkillColor(level) -- 1 too hard to 5 no skill-up (SkillLevel)
    return level == 1 and RED_FONT_COLOR or level == 2 and DIFFICULT_DIFFICULTY_COLOR or level == 3 and FAIR_DIFFICULTY_COLOR
        or level == 4 and EASY_DIFFICULTY_COLOR or TRIVIAL_DIFFICULTY_COLOR
end

-- Skills are read again at most once a second.
local SKILL_WAIT = 1
local skillsRead = 0 -- last skill refresh

-- The line, its color and the profession's name.
local function Requirement(name)
    local kind = NodeKind(name)
    local level, need = SkillLevel(name, kind) -- nothing for chests and the like
    if not level or not professions[kind] then return nil end
    return ITEM_MIN_SKILL:format(professions[kind], need), SkillColor(level), professions[kind]
end

local function FreshSkills()
    local now = GetTime()
    if now - skillsRead >= SKILL_WAIT then skills.herbs, skills.ore, skillsRead = nil, nil, now end
end

-- Herb and ore items: the node each comes from (the easiest one), by item ID.
local ITEM_NODES = {
    [765] = "silverleaf", [2447] = "peacebloom", [2449] = "earthroot", [785] = "mageroyal", [2450] = "briarthorn",
    [2452] = "mageroyal", [3820] = "stranglekelp", [2453] = "bruiseweed", [3355] = "wild steelbloom",
    [3369] = "grave moss", [3356] = "kingsblood", [3357] = "liferoot", [3818] = "fadeleaf", [3821] = "goldthorn",
    [3358] = "khadgar's whisker", [3819] = "wintersbite", [4625] = "firebloom", [8831] = "purple lotus",
    [8153] = "purple lotus", [8836] = "arthas' tears", [8838] = "sungrass", [8839] = "blindweed",
    [8845] = "ghost mushroom", [8846] = "gromsblood", [13464] = "golden sansam", [13463] = "dreamfoil",
    [13465] = "mountain silversage", [13466] = "plaguebloom", [13467] = "icecap", [13468] = "black lotus",
    [2770] = "copper vein", [2771] = "tin vein", [2772] = "iron deposit", [2775] = "silver vein", [2776] = "gold vein",
    [3858] = "mithril deposit", [7911] = "truesilver deposit", [10620] = "small thorium vein",
    [11370] = "dark iron deposit", [3340] = "incendicite mineral vein", [4278] = "lesser bloodstone deposit",
    [5833] = "indurium mineral vein",
}
local GATHERED = "Gathered with %s (%d)"

local function OnItemTooltip(tooltip, data)
    if not db.skillLine or issecretvalue(data) or not data then return end
    local id = data.id
    if issecretvalue(id) then return end
    local node = ITEM_NODES[id]
    if not node then return end
    FreshSkills()
    local kind = NodeKind(node)
    local level, need = SkillLevel(node, kind)
    if not level or not professions[kind] then return end
    tooltip:AddLine(GATHERED:format(professions[kind], need), SkillColor(level):GetRGB())
end

local function OnObjectTooltip(tooltip, data)
    if not db.skillLine then return end
    local lines = not issecretvalue(data) and data.lines
    if not lines or issecretvalue(lines) or issecretvalue(lines[1]) then return end
    local name = lines[1] and lines[1].leftText
    if not name or issecretvalue(name) then return end
    FreshSkills()
    local requires, color, profession = Requirement(Clean(name))
    if not requires then return end
    for i = 2, #lines do
        local line = lines[i]
        if issecretvalue(line) then return end
        local text = line.leftText
        if issecretvalue(text) or text == requires then return end -- the game has it already
    end
    -- The game's line with just the profession's name says it with the skill instead.
    for i = 2, tooltip:NumLines() do
        local left = tooltip:GetLeftLine(i)
        local text = left and left:GetText()
        if not issecretvalue(text) and text == profession then
            left:SetText(requires)
            left:SetTextColor(color:GetRGB())
            return
        end
    end
    tooltip:AddLine(requires, color:GetRGB())
end

---------------------------------------------------------------------------
-- Minimap
---------------------------------------------------------------------------

-- Older versions turned the game's Quest POIs tracking off and the controller's hover in
-- free look on during their scans. A scan cut short by a logout or a crash left them so:
-- put back at every login and loading screen.
local function QuestPOIIndex()
    if not (C_Minimap.GetTrackingFilter and Enum.MinimapTrackingFilter and Enum.MinimapTrackingFilter.QuestPOIs) then return nil end
    for i = 1, C_Minimap.GetNumTrackingTypes() do
        local filter = C_Minimap.GetTrackingFilter(i)
        if type(filter) == "table" and not issecretvalue(filter) and not issecretvalue(filter.filterID)
            and filter.filterID == Enum.MinimapTrackingFilter.QuestPOIs then return i end
    end
end
local function QuestAreasBack()
    if not NodeSightDB.questOff then return end
    local index = QuestPOIIndex()
    if not index then return end -- (the tracking list not there yet: at the next loading screen)
    if pcall(C_Minimap.SetTracking, index, true) then NodeSightDB.questOff = nil end
end
local function PadHoverBack()
    if not NodeSightDB.padHoverOn then return end
    local style = C_InputInterfaceStyle and C_InputInterfaceStyle.GetCurrentStyle and C_InputInterfaceStyle.GetCurrentStyle()
    NodeSightDB.padHoverOn = nil
    if Enum.InputDeviceInterfaceType and style == Enum.InputDeviceInterfaceType.Gamepad then return end -- (it keeps hover on itself)
    if C_GamePad and C_GamePad.SetAllowHoverEventsWithFreeLook then pcall(C_GamePad.SetAllowHoverEventsWithFreeLook, false) end
end
-- Far away sparkles turned In-Game Navigation on and noted how it was: back as it was.
local function NavBack(settings)
    if not settings.navWas or InCombatLockdown() then return end
    if C_CVar.GetCVar("showInGameNavigation") == "1" then C_CVar.SetCVar("showInGameNavigation", settings.navWas) end
    settings.navWas = nil
end

---------------------------------------------------------------------------
-- Loading
---------------------------------------------------------------------------

-- What the other files use of this one.
ns.defaults, ns.FINDERS, ns.Finders, ns.turns, ns.SWITCH_WAIT = defaults, FINDERS, Finders, turns, SWITCH_WAIT
function ns.UpdateSwitch() UpdateSwitch() end

-- Other addons read NodeSight's minimap symbols here. There are none any more; kept so
-- an addon that still calls it gets an empty list instead of an error.
NodeSightAPI = {
    GetSymbols = function() return {} end,
    RegisterCallback = function() end,
}

-- Settings: this character's own (NodeSightCharDB, the default, started from the
-- shared ones) or the ones shared by every character that has its own turned off
-- (NodeSightDB). Quest objects and the CVars to put back are always shared.
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

local OBJECT_TOOLTIP = Enum.TooltipDataType.Object -- a herb's or ore's own tooltip
local ITEM_TOOLTIP = Enum.TooltipDataType.Item
local function OnAddonLoaded()
    local firstInstall = NodeSightDB == nil
    local settings = LoadSettings()
    NodeSightDB.report = nil -- (the old bug report's log)
    -- The old dot size setting: the game's own size back for whoever changed it.
    local oldDots = tonumber(rawget(settings, "dotScale")) or tonumber(NodeSightDB.dotScale)
    if oldDots and oldDots ~= 100 and Minimap.SetIconScale then Minimap:SetIconScale(1) end
    rawset(settings, "dotScale", nil)
    NodeSightDB.dotScale = nil
    -- A first install has no update to tell of: its notes count as seen (no glow on What's New).
    if firstInstall then NodeSightDB.notesSeen = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") end
    NavBack(settings)
    ns.CarryOverLooks(settings)
    for key, value in pairs(defaults) do
        if settings[key] == nil then settings[key] = value end
    end
    -- Fix saved values the settings can't produce.
    if type(settings.styleLooks) ~= "table" then settings.styleLooks = {} end -- each style's look, per kind (the sparkle window)
    if type(settings.minimapIcon) ~= "table" then settings.minimapIcon = {} end -- the minimap button's place
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
    if not ns.HARVESTS[settings.harvest] then settings.harvest = defaults.harvest end
    if not ns.SWITCH_MEASURES[settings.switchMeasure] then settings.switchMeasure = defaults.switchMeasure end
    -- A hand-edited distance: a number in its slider's range, else the default.
    for key, range in pairs(ns.SWITCH_RANGES) do
        local value = tonumber(settings[key]) or defaults[key]
        settings[key] = math.max(range[1], math.min(range[2], value))
    end
    db = settings
    ns.db = db
    ticker = CreateFrame("Frame")
    UpdateSwitch()
    -- CVars changed by the addon: original (saved) and set (applied) values.
    NodeSightDB.saved = NodeSightDB.saved or {}
    NodeSightDB.applied = NodeSightDB.applied or {}
    ns.RegisterSettings()
    ns.MinimapButton()
    if OBJECT_TOOLTIP then TooltipDataProcessor.AddTooltipPostCall(OBJECT_TOOLTIP, OnObjectTooltip) end
    if ITEM_TOOLTIP then TooltipDataProcessor.AddTooltipPostCall(ITEM_TOOLTIP, OnItemTooltip) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
events:RegisterEvent("SKILL_LINES_CHANGED")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            events:UnregisterEvent("ADDON_LOADED")
            -- After an update, a /reload only loads the files the old .toc listed:
            -- stay off until the game is restarted.
            if not (ns.Plain and ns.Mute and ns.Setup and ns.ShowSparkleWindow and ns.ShowWhatsNew and ns.MinimapButton and ns.RegisterSettings) then
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
        QuestAreasBack()
        PadHoverBack()
        -- Restores CVars left changed (e.g. a restore delayed by combat).
        ns.Setup() -- after every loading screen
        if not NodeSightDB.minimapNewsSeen then
            NodeSightDB.minimapNewsSeen = true
            ns.ShowMinimapNews()
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        -- Free the plate's sparkle frame.
        if next(ns.sparkles) or next(ns.leaving) then ns.HideSparkles(C_NamePlate.GetNamePlateForUnit(arg1)) end
    elseif event == "SKILL_LINES_CHANGED" then
        -- Herbalism or Mining went up: read them again, and gray sparkles may not be any more.
        skills.herbs, skills.ore = nil, nil
        wipe(ns.hasProfession) -- (a profession learned or dropped: Only for my professions)
        ns.UpdateAll()
    elseif event == "PLAYER_LOGOUT" then
        -- A reload or logout: the game settings the sparkles set, back as they were (set again
        -- at login), so turning NodeSight off leaves none changed.
        if ns.SetupOut then pcall(ns.SetupOut) end
    elseif event == "PLAYER_REGEN_DISABLED" then
        if db.combatHide then ns.UpdateAll() end
    else -- PLAYER_REGEN_ENABLED
        if ns.SetupPending() then ns.Setup() end
        if db.combatHide then ns.UpdateAll() end
    end
end)
