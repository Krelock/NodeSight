-- NodeSight Sparkles: sparkles on the herb, ore, chest or other object in front
-- of you. NodeSight's sparkles without its minimap scan, for WoW Forever and Retail.
--
-- Files, in load order (they share functions through the addon table `ns`):
--   Locales\*.lua         node names in other languages (each loads only on its client)
--   Names.lua             chest names, and the skill each herb and ore needs
--   NodeSightSparkles.lua defaults, loading and events
--   Sparkles.lua          the sparkles on the object in front of you
--   SparkleWindow.lua     the sparkle window: on/off and the look for each kind, with a 3D preview
--   Settings.lua          the Options page
--
-- Sections: Defaults, Loading.

local ADDON_NAME, ns = ...

local ipairs, pairs = ipairs, pairs

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

local defaults = {
    herbs = true, -- sparkles on herbs
    ore = true, -- sparkles on ore
    chests = true, -- sparkles on chests
    quests = false, -- sparkles on quest objects
    others = false, -- sparkles on other objects
    bobber = true, -- Beta: sparkles on your fishing bobber
    skinning = false, -- Beta: sparkles on corpses you can skin
    gameIcons = false, -- keep the game's interact icons while sparkles are on
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
    popups = true, -- the Enable Interact Key popup
    rareGlow = false, -- a gold glow around rare herbs and ore
    harvest = 5, -- how a gathered node finishes (Sparkles.lua's HARVESTS: Fade away)
}
ns.db = defaults -- NodeSightSparklesCharDB from login on
ns.defaults = defaults

---------------------------------------------------------------------------
-- Loading
---------------------------------------------------------------------------

-- Fills in the defaults and fixes saved values the settings can't produce.
-- Settings are per character (NodeSightSparklesCharDB), started from the ones every
-- character shared before (NodeSightSparklesDB). The CVars to put back stay shared, as
-- the CVars are.
local SHARED = { questObjects = true, saved = true, applied = true }

local function LoadSaved()
    NodeSightSparklesDB = NodeSightSparklesDB or {}
    local shared = NodeSightSparklesDB
    if type(NodeSightSparklesCharDB) ~= "table" then
        NodeSightSparklesCharDB = {}
        for key, value in pairs(shared) do
            if not SHARED[key] then NodeSightSparklesCharDB[key] = type(value) == "table" and CopyTable(value) or value end
        end
    end
    local db = setmetatable(NodeSightSparklesCharDB, {
        __index = function(_, key) if SHARED[key] then return shared[key] end end,
        __newindex = function(t, key, value)
            if SHARED[key] then shared[key] = value else rawset(t, key, value) end
        end,
    })
    for key, value in pairs(defaults) do
        if db[key] == nil then db[key] = value end
    end
    if type(db.styleLooks) ~= "table" then db.styleLooks = {} end -- each style's look, per kind (the sparkle window)
    for _, kind in ipairs(ns.KINDS) do
        local keys = ns.SPARKLE_KEYS[kind]
        db[keys.color] = tostring(db[keys.color]):match("^%x%x%x%x%x%x%x%x$") or defaults[keys.color]
        local two = db[keys.color2]
        db[keys.color2] = two ~= nil and tostring(two):match("^%x%x%x%x%x%x%x%x$") or nil
        if not ns.StyleFits(db[keys.style], kind) then db[keys.style] = defaults[keys.style] end
        -- The look in use belongs to its style.
        local looks = db.styleLooks
        if type(looks[kind]) ~= "table" then looks[kind] = {} end
        if looks[kind][db[keys.style]] == nil then
            looks[kind][db[keys.style]] = { size = db[keys.size], height = db[keys.height],
                count = db[keys.count], color = db[keys.color], color2 = db[keys.color2] }
        end
    end
    if not ns.HARVESTS[db.harvest] then db.harvest = defaults.harvest end
    -- CVars changed by the addon: original (saved) and set (applied) values.
    shared.saved = shared.saved or {}
    shared.applied = shared.applied or {}
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
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
            if not (ns.TooHard and ns.Setup and ns.ShowSparkleWindow and ns.RegisterSettings) then
                events:UnregisterAllEvents()
                return
            end
            LoadSaved()
        end
    elseif event == "PLAYER_LOGIN" then
        -- Every addon has loaded by now. NodeSight has the same sparkles, so with it
        -- on this addon stays off, after putting back any CVars it changed before.
        if C_AddOns.IsAddOnLoaded("NodeSight") then
            events:UnregisterAllEvents()
            ns.db = { saved = NodeSightSparklesDB.saved, applied = NodeSightSparklesDB.applied }
            ns.Setup()
            ns.RegisterSettings(true)
            return
        end
        ns.db = NodeSightSparklesCharDB
        ns.RegisterSettings()
    elseif event == "PLAYER_ENTERING_WORLD" then
        ns.Setup() -- after every loading screen
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        -- Free the plate's sparkle frame.
        if next(ns.sparkles) or next(ns.leaving) then ns.HideSparkles(C_NamePlate.GetNamePlateForUnit(arg1)) end
    elseif event == "SKILL_LINES_CHANGED" then
        -- Herbalism or Mining went up: read them again, and gray sparkles may not be any more.
        ns.skills.herbs, ns.skills.ore = nil, nil
        wipe(ns.hasProfession) -- (a profession learned or dropped: Only for my professions)
        ns.UpdateAll()
    elseif event == "PLAYER_REGEN_DISABLED" then
        if ns.db.combatHide then ns.UpdateAll() end
    else -- PLAYER_REGEN_ENABLED
        if ns.SetupPending() then ns.Setup() end
        if ns.db.combatHide then ns.UpdateAll() end
    end
end)
