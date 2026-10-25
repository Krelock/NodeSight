-- Loads NodeSight's files outside the game, with a stubbed game API. Every load gets its own
-- environment (setfenv), so stubs and saved variables stay inside one test: load in
-- before_each or in the test itself, never in a describe body.

local M = {}

-- Files that need far more of the game than these tests stub.
local SKIPPED = { ["NodeSight.lua"] = true, ["Sparkles.lua"] = true, ["FarSparkles.lua"] = true,
    ["WhatsNew.lua"] = true, ["Settings.lua"] = true }

-- A frame that records its events and scripts. Fire and Tick drive it like the game would.
function M.Frame()
    local frame = { events = {}, scripts = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:SetScript(kind, script) self.scripts[kind] = script end
    function frame:Fire(event, ...)
        if self.scripts.OnEvent then self.scripts.OnEvent(self, event, ...) end
    end
    -- Runs OnUpdate for this many seconds in steps of step (0.1) seconds, until it is removed.
    function frame:Tick(seconds, step)
        step = step or 0.1
        for _ = 1, math.floor(seconds / step + 0.5) do
            if not self.scripts.OnUpdate then return end
            self.scripts.OnUpdate(self, step)
        end
    end
    return frame
end

-- C_SkillInfo with Herbalism and Mining at this rank.
function M.Skill(rank)
    return { GetSkillLineInfoByID = function(id)
        return { rank = rank, modifier = 0, name = id == 182 and "Kräuterkunde" or "Bergbau" }
    end }
end

-- Loads the addon's files in .toc order and calls each with the addon's name and namespace.
-- options.locale: client language (enUS); options.api: globals to add or replace.
-- Returns the namespace, the environment and the frames the files created.
function M.Load(options)
    options = options or {}
    local frames = {}
    local env = setmetatable({}, { __index = _G })
    env.GetLocale = function() return options.locale or "enUS" end
    env.issecretvalue = function() return false end
    env.C_SkillInfo = M.Skill(1)
    env.CreateFrame = function()
        local frame = M.Frame()
        frames[#frames + 1] = frame
        return frame
    end
    for name, value in pairs(options.api or {}) do env[name] = value end
    local ns = {}
    for line in io.lines("NodeSight.toc") do
        local file = line:match("^([%w_/\\]+%.lua)%s*$")
        if file and not SKIPPED[file] then
            local chunk = assert(loadfile((file:gsub("\\", "/"))))
            setfenv(chunk, env)("NodeSight", ns)
        end
    end
    return ns, env, frames
end

return M
