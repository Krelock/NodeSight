-- NodeSight's recorder: numbers on what the scans did this session, kept with the saved
-- settings (NodeSightDB.sessions), so a change to the scan can be compared before and after.
-- It only watches: it reads NodeSight's own log lines and looks once a frame while a scan runs.
--
-- Sections: Session, Log lines, While a scan runs.

local ADDON_NAME, ns = ...

local SESSIONS = 12 -- sessions kept (a login or reload starts one)
local SCANS = 400 -- scans kept in a session
local SETTINGS = { "scanMinimap", "autoScanTimer", "autoScanSeconds", "scanStanding", "autoScan", "autoScanYards",
    "combatScan", "mouseStill", "mouseStop", "mobWait", "lootWait", "lootSeconds", "skipRest", "edgeScan",
    "scanMap", "scanFade", "windowWait", "switchFinders", "minimapShape" }

---------------------------------------------------------------------------
-- Session
---------------------------------------------------------------------------
local session -- this login's or reload's numbers; nil until the saved settings are loaded
local current -- the scan running now

local function Loaded(name)
    return C_AddOns.IsAddOnLoaded(name) and true or nil
end

local function NewSession()
    if type(NodeSightDB) ~= "table" then return end
    if type(NodeSightDB.sessions) ~= "table" then NodeSightDB.sessions = {} end
    local list = NodeSightDB.sessions
    local settings = {}
    for _, key in ipairs(SETTINGS) do settings[key] = ns.db[key] end
    session = {
        started = date("%Y-%m-%d %H:%M:%S"),
        version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version"),
        build = select(2, GetBuildInfo()),
        minimap = math.floor(Minimap:GetWidth() + 0.5),
        uis = { EllesmereUI = Loaded("EllesmereUI"), ElvUI = Loaded("ElvUI"), Leatrix = Loaded("Leatrix_Plus"),
            SexyMap = Loaded("SexyMap"), Questie = Loaded("Questie"), GatherMate2 = Loaded("GatherMate2") },
        settings = settings,
        at = GetTime(), -- (the game's clock at its start; seconds below is since then)
        seconds = 0,
        scans = {},
        waits = {}, -- why automatic scans waited, and how often
        errors = 0,
    }
    list[#list + 1] = session
    while #list > SESSIONS do table.remove(list, 1) end
end

local function Touch()
    if session then session.seconds = math.floor(GetTime() - session.at) end
end

---------------------------------------------------------------------------
-- Log lines
---------------------------------------------------------------------------
-- NodeSight says what each scan did in its log (the bug report): read here as it is said.
local function Count(list, key)
    list[key] = (list[key] or 0) + 1
end

local function Read(text)
    if not session then return end
    local kind, spots, rest = text:match("^scan (%a+): (%d+) spots(.*)$")
    if kind == "auto" or kind == "key" then
        local unit = UnitExists("mouseover")
        local cx, cy = GetCursorPosition()
        current = { t = math.floor(GetTime() - session.at), kind = kind, spots = tonumber(spots),
            edge = rest:find(", edge", 1, true) and true or nil,
            tip = GameTooltip:IsShown() and true or nil, -- a tooltip was open as it started
            unit = (not issecretvalue(unit) and unit) and true or nil, -- a mob or player under the mouse
            cx = cx, cy = cy, frames = 0, slowest = 0, moved = 0 }
        return
    end
    local took, found = text:match("^scan done in ([%d%.]+) s: (%d+) found")
    if not took then found = text:match("^scan done: (%d+) found") end
    local why
    if not found then took, why = text:match("^scan stopped in ([%d%.]+) s: (.*)$") end
    if not found and not why then why = text:match("^scan stopped: (.*)$") end
    if (found or why) and current then
        local scan = current
        current = nil
        scan.sec, scan.found, scan.stop = tonumber(took), tonumber(found), why
        scan.moved = math.floor(scan.moved + 0.5)
        scan.slowest = math.floor(scan.slowest * 1000 + 0.5) -- ms
        scan.cx, scan.cy = nil, nil
        local list = session.scans
        list[#list + 1] = scan
        while #list > SCANS do table.remove(list, 1) end
        Touch()
        return
    end
    local wait = text:match("^automatic scans: (.*)$") or text:match("^waiting: (.*)$") or text:match("^paused: (.*)$")
    if wait then
        -- (a frame's name after a colon would make a reason of each: only the reason itself)
        Count(session.waits, wait:match("^([^:]*)"))
    elseif text:find("^error: ") then
        session.errors = session.errors + 1
        session.lastError = text:sub(8, 200)
    end
end

local Log = ns.Log
function ns.Log(text)
    local line = Log(text)
    if type(text) == "string" then pcall(Read, text) end
    return line
end

---------------------------------------------------------------------------
-- While a scan runs
---------------------------------------------------------------------------
-- Each frame of a scan: how many there were, the slowest, how far the mouse went and
-- whether a mouse button was held.
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function(_, elapsed)
    local scan = current
    if not scan then return end
    if not ns.KeyScanning() then return end
    scan.frames = scan.frames + 1
    if elapsed > scan.slowest then scan.slowest = elapsed end
    local cx, cy = GetCursorPosition()
    local far = math.sqrt((cx - scan.cx) ^ 2 + (cy - scan.cy) ^ 2)
    if far > scan.moved then scan.moved = far end
    if not scan.button and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) then scan.button = true end
end)

-- The symbols there are after each scan.
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if ns.db == ns.defaults then return end -- (NodeSight is waiting for a game restart)
        pcall(NewSession)
        if session and NodeSightAPI and NodeSightAPI.RegisterCallback then
            NodeSightAPI.RegisterCallback(function(symbols)
                local last = session.scans[#session.scans]
                if last and type(symbols) == "table" then last.symbols = #symbols end
            end)
        end
    else
        Touch()
    end
end)
