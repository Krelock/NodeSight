-- NodeSight's own pages in the sparkle window's list, above the sparkles: General and
-- the Herb/Ore Switch, each in two columns. One window for every setting, and
-- nothing written into the game's Options list (rows changed from addon code there break
-- its dropdowns in combat).
--
-- Sections: Parts, The Switch line, The pages, In the window.

local _, ns = ...

local ipairs, floor, max = ipairs, math.floor, math.max

local refreshing -- the page is being filled in: its sliders' moves aren't changes

---------------------------------------------------------------------------
-- Parts
---------------------------------------------------------------------------
-- Frames are made with no parent, then SetParent (the gamepad UI hooks CreateFrame).

local function New(kind, parent, template)
    local frame = CreateFrame(kind, nil, nil, template)
    frame:SetParent(parent)
    return frame
end

local function Label(parent, text, font)
    local label = parent:CreateFontString(nil, "ARTWORK", font or "GameFontNormal")
    label:SetText(text)
    return label
end

local function Tooltip(frame, title, text)
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title)
        if text then GameTooltip:AddLine(text, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- What a setting does when it changes (beyond saving it). The switch reads its other settings each tick.
local AFTER = {
    switchFinders = function() ns.SwitchReset() ns.UpdateSwitch() end,
    minimapButton = function() if ns.MinimapButtonChanged then ns.MinimapButtonChanged() end end,
    townInteractOff = function() ns.Setup() end,
}

local function Set(key, value)
    if key == "own" then
        ns.SetOwnSettings(value)
        ns.AskReload()
        return ns.RefreshSparkleWindow()
    end
    ns.db[key] = value
    if AFTER[key] then AFTER[key]() end
    ns.RefreshSparkleWindow()
end

local COLUMN = 150 -- where a row's control starts, after its label
-- The columns, and how wide their words go. A slider row with its value is about 380 wide,
-- so the right column starts past the left one's widest ("100 % (233 yd)").
local LEFT, RIGHT, WIDE = 16, 400, 340

-- A checkbox with its words after it; the whole row shows the tooltip.
local function Checkbox(column, key, text, tip)
    local box = New("CheckButton", column.page, "MinimalCheckboxTemplate")
    box:SetSize(26, 26)
    box:SetScript("OnClick", function(self)
        PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        Set(key, self:GetChecked() == true)
    end)
    box.label = Label(box, text)
    box.label:SetPoint("LEFT", box, "RIGHT", 4, 0)
    box.label:SetWidth(WIDE - 34)
    box.label:SetJustifyH("LEFT")
    box.key, box.kind = key, "box"
    local hover = New("Frame", box)
    hover:SetPoint("TOPLEFT", box.label, "TOPLEFT", 0, 4)
    hover:SetPoint("BOTTOMRIGHT", box.label, "BOTTOMRIGHT", 4, -4)
    hover:EnableMouse(true)
    hover:SetScript("OnMouseDown", function() box:Click() end)
    Tooltip(box, text, tip)
    Tooltip(hover, text, tip)
    column[#column + 1] = box
    return box
end

-- A gold label on the left, a control at COLUMN.
local function Row(text, control, tip)
    local label = Label(control, text)
    label:SetWidth(COLUMN - 8)
    label:SetJustifyH("LEFT")
    label:SetPoint("LEFT", control, "LEFT", -COLUMN, 0)
    local hover = New("Frame", control)
    hover:SetPoint("TOPLEFT", label, "TOPLEFT", 0, 4)
    hover:SetPoint("BOTTOMRIGHT", label, "BOTTOMRIGHT", 0, -4)
    hover:EnableMouse(true)
    Tooltip(hover, text, tip)
    control.label, control.inRow = label, true
    return label
end

-- label(value) is the text right of the slider.
local function Slider(column, key, text, low, high, step, tip, label)
    local slider = New("Frame", column.page, "MinimalSliderWithSteppersTemplate")
    slider:SetWidth(110)
    local right = MinimalSliderWithSteppersMixin.Label.Right
    slider:Init(low, low, high, (high - low) / step, { [right] = CreateMinimalSliderFormatter(right, label) })
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        if not refreshing then Set(key, floor(value / step + 0.5) * step) end
    end, slider)
    Row(text, slider, tip)
    for _, part in ipairs({ slider.Slider, slider.Back, slider.Forward }) do Tooltip(part, text, tip) end
    slider.key, slider.kind = key, "slider"
    column[#column + 1] = slider
    return slider
end

local function Header(column, text)
    local header = New("Frame", column.page)
    header:SetSize(WIDE, 22)
    header.height, header.gap = 30, 4
    header.text = Label(header, text, "GameFontNormalLarge")
    header.text:SetPoint("LEFT")
    local line = header:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 1)
    line:SetGradient("HORIZONTAL", CreateColor(1, 0.82, 0, 0.67), CreateColor(1, 0.82, 0, 0)) -- (the logo's gold, fading out)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 2)
    line:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 2)
    column[#column + 1] = header
    return header
end

-- Places a column's shown parts top to bottom, each part's own gap above it.
local function Stack(column)
    local y = column.top
    for _, part in ipairs(column) do
        if part:IsShown() then
            y = y - (part.gap or 0)
            part:ClearAllPoints()
            if part.tall then -- (rows of boxes: placed by their top)
                part:SetPoint("TOPLEFT", column.page, "TOPLEFT", column.x, y)
            else
                part:SetPoint("LEFT", column.page, "TOPLEFT", part.inRow and column.x + COLUMN or column.x, y - 13)
            end
            y = y - (part.height or 32)
        end
    end
end

---------------------------------------------------------------------------
-- The Switch line
---------------------------------------------------------------------------
-- What the switch is doing right now, worked out again twice a second while the page shows.

local FIND = { herbs = 2383, ore = 2580 } -- Find Herbs, Find Minerals
local GREEN, GRAY, RED = "ff80ff80", "ff9d9d9d", "ffff6060"

local function SwitchLine()
    local db, switch = ns.db, ns.switch
    if not db.switchFinders then return GRAY, "Switch is off." end
    if switch.stopped then return RED, "Stopped after an error until you /reload." end
    if switch.stoppedUntil and GetTime() < switch.stoppedUntil then
        return RED, "Paused for a minute: the last two switches didn't work."
    end
    local kind = ns.Finders()
    if not kind then return GRAY, "Turn on Find Herbs or Find Minerals to start." end
    local now = ("Now: %s."):format(C_Spell.GetSpellName(FIND[kind]) or kind)
    if not ns.SwitchAllowed() then return GRAY, now .. " Not switching here (Where, Only while mounted)." end
    local goal, unit = ns.SwitchGoal()
    if not goal then return GREEN, now .. " Open the minimap once to measure the distance." end
    local left = max(0, goal - (switch.way or 0))
    if unit == "s" then return GREEN, ("%s Next switch after about %d s of moving."):format(now, floor(left + 0.5)) end
    return GREEN, ("%s Next switch in about %d yd."):format(now, floor(left + 0.5))
end

---------------------------------------------------------------------------
-- The pages
---------------------------------------------------------------------------

local function Percent(value)
    local yards = ns.SwitchDistance(value)
    if yards then return ("%d %% (%d yd)"):format(value, floor(yards + 0.5)) end
    return ("%d %%"):format(value)
end
local function Yards(value) return ("%d yd"):format(value) end
local function Seconds(value) return ("%d s"):format(value) end
local function YardsOrOff(value) return value == 0 and "Off" or Yards(value) end
local function SecondsOrOff(value) return value == 0 and "Off" or Seconds(value) end

-- General: NodeSight's own settings on the left, Towns on the right.
local function GeneralColumns(column, towns, page)
    -- The page's title alone on top with a gray line under it, then each column headed.
    page.about = Label(page, "NodeSight's own settings. The sparkles have their pages below Sparkles.", "GameFontDisableSmall")
    page.about:SetPoint("TOPLEFT", LEFT, -38)
    column.top, towns.top = -56, -56
    Header(column, "Options")
    Checkbox(column, "skillLine", "Required skill in tooltips",
        "Shows the skill a herb or ore needs in its tooltip when your mouse is on it in the world, and on herb and ore items.")
    Checkbox(column, "popups", "Popups",
        "NodeSight's popups: when Enable Interact Key is off, and when the game needs a restart after an update. They wait until a fight is over. Off: none at all.")
    Checkbox(column, "minimapButton", "Minimap button",
        "NodeSight's button on the minimap: left click opens these settings, Shift left click the sparkles, right click turns all sparkles on or off, Shift right click the Herb/Ore Switch.")
    Checkbox(column, "own", "Settings for this character only",
        "This character keeps its own NodeSight settings. Untick it to use the settings your other characters share. It offers a reload to switch.")
    Checkbox(column, "stoneBackground", "Stone background", "Blizzard's stone texture behind this window, warmed to the logo's brown. Off: plain brown.")
    Header(towns, "Towns")
    Checkbox(towns, "townInteractOff", "Interact Key off in towns (Beta)",
        "Turns the game's Interact Key off while you're in a town or inn, so it doesn't pick the NPCs there. Nothing sparkles in town then.")
end

-- The Herb/Ore Switch: its line and box over both columns, then When, Switch in and the
-- thanks on the left, Pauses on the right (its header level with When's).
local function SwitchColumns(column, right, page)
    page.line = Label(page, "", "GameFontHighlightSmall")
    page.line:SetPoint("TOPLEFT", column.x, -38)
    page.line:SetWidth(2 * WIDE)
    page.line:SetJustifyH("LEFT")
    column.top = -50
    page.finders = Checkbox(column, "switchFinders", "Switch between herbs and ore",
        "Switches between Find Herbs and Find Minerals as you travel. You need both trained and one active to start.")
    Header(column, "When")
    local measure = New("DropdownButton", page, "WowStyle1DropdownTemplate")
    measure:SetWidth(168)
    measure:SetupMenu(function(_, root)
        for i, name in ipairs(ns.SWITCH_MEASURES) do
            root:CreateRadio(name, function() return ns.db.switchMeasure == i end, function() Set("switchMeasure", i) end)
        end
    end)
    Row("Measure distance in", measure,
        "How the distance between switches is measured: percent of what your minimap shows (it changes with the zoom), yards, or seconds on the move.")
    measure.key, measure.kind = "switchMeasure", "dropdown"
    column[#column + 1] = measure
    local yards, seconds = ns.SWITCH_RANGES.switchDistanceYards, ns.SWITCH_RANGES.switchSeconds
    page.percent = Slider(column, "switchPercent", "Distance", 20, 100, 5,
        "How far you go between switches, in percent of what your minimap shows: farther when zoomed out or outdoors.", Percent)
    page.yards = Slider(column, "switchDistanceYards", "Distance", yards[1], yards[2], yards[3],
        "How far you go between switches, in yards.", Yards)
    page.seconds = Slider(column, "switchSeconds", "Time", seconds[1], seconds[2], seconds[3],
        "How long you move between switches, in seconds. Time standing still doesn't count.", Seconds)
    Checkbox(column, "switchMounted", "Only while mounted", "Switches only while you ride a mount. Travel Form and Ghost Wolf don't count.")
    Header(column, "Switch in")
    local where = New("Frame", page)
    where:SetSize(WIDE, 64)
    where.height, where.parts = 70, { page = where }
    for i, area in ipairs({ { "switchWorld", "Open world", "the open world" }, { "switchDungeons", "Dungeons", "a dungeon" },
        { "switchRaids", "Raids", "a raid" }, { "switchBattlegrounds", "Battlegrounds", "a battleground" } }) do
        local box = Checkbox(where.parts, area[1], area[2], ("Switches while you're in %s."):format(area[3]))
        box.label:SetWidth(130)
        box:SetPoint("TOPLEFT", where, "TOPLEFT", (i - 1) % 2 * 170, -floor((i - 1) / 2) * 32)
    end
    where.boxes, where.tall = where.parts, true
    column[#column + 1] = where
    local thanks = Label(page, "Thanks to tester617 for the Switch page", "GameFontDisableSmall")
    thanks.gap, thanks.height = 4, 20
    column[#column + 1] = thanks
    column = right
    column.top = -82 -- (under the box)
    Header(column, "Pauses")
    Checkbox(column, "switchPauseBusy", "Pause while casting, looting or with something on the cursor",
        "Switching pauses while you cast, gather or loot, and while a spell waits for a target or something is on your cursor.").height = 42
    Slider(column, "switchEnemyYards", "Enemy targeted within", 0, 60, 1,
        "Switching pauses while you target a living enemy this close, and for a second after you mouse over one. Distances are rough: the game doesn't give exact ones.", YardsOrOff)
    Checkbox(column, "switchPauseStealth", "Pause while stealthed", "Switching pauses while you're stealthed.")
    Slider(column, "switchAfterCast", "After your own spells", 0, 10, 1,
        "Switching pauses this long after your own spells end, and after you dismount, so the switch's global cooldown doesn't get in your way.", SecondsOrOff)
    -- The line, twice a second while the page shows.
    local elapsed = 0
    page:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < 0.5 then return end
        elapsed = 0
        local color, text = SwitchLine()
        page.line:SetText(("|c%s%s|r"):format(color, text))
    end)
end

-- A page's title and its two columns, filled by fill(left, right, page).
local function Page(page, title, fill)
    local left = { page = page, x = LEFT, top = -50 }
    local right = { page = page, x = RIGHT, top = -50 }
    page.title = Label(page, title, "GameFontHighlightLarge")
    page.title:SetPoint("TOPLEFT", LEFT, -14)
    fill(left, right, page)
    page.columns, page.parts = { left, right }, {}
    for _, column in ipairs(page.columns) do
        for _, part in ipairs(column) do page.parts[#page.parts + 1] = part end
    end
end

local function BuildGeneral(page) Page(page, GENERAL, GeneralColumns) end

local function BuildSwitch(page)
    Page(page, "Herb/Ore Switch", SwitchColumns)
    for _, part in ipairs(page.parts) do
        if part ~= page.finders then part.switch = true end
    end
end

---------------------------------------------------------------------------
-- In the window
---------------------------------------------------------------------------

local function RefreshPart(part)
    local key = part.key
    if not key then return end
    if part.kind == "box" then
        part:SetChecked(key == "own" and ns.OwnSettings() or ns.db[key] == true)
    elseif part.kind == "slider" then
        part:SetValue(ns.db[key])
    elseif part.kind == "dropdown" then
        part:GenerateMenu()
    end
end

local function Refresh(page)
    refreshing = true
    for _, part in ipairs(page.parts) do
        RefreshPart(part)
        for _, box in ipairs(part.boxes or {}) do RefreshPart(box) end
    end
    -- The Switch: everything under its box only while it's on, and one distance slider.
    if page.line then
        local on = ns.db.switchFinders == true
        for _, part in ipairs(page.parts) do
            if part.switch then part:SetShown(on) end
        end
        local measure = ns.db.switchMeasure
        for i, slider in ipairs({ page.percent, page.yards, page.seconds }) do slider:SetShown(on and measure == i) end
        local color, text = SwitchLine()
        page.line:SetText(("|c%s%s|r"):format(color, text))
    end
    for _, column in ipairs(page.columns) do Stack(column) end
    refreshing = false
end

ns.WINDOW_PAGES = {
    { key = "nodesight", name = GENERAL, build = BuildGeneral, refresh = Refresh },
    { key = "switch", name = "Herb/Ore Switch", build = BuildSwitch, refresh = Refresh },
}
ns.WindowSet = Set -- what the page's controls do, by key

function ns.ShowSettingsWindow() ns.ShowSparkleWindow("nodesight") end
-- The window is open on NodeSight's own page.
function ns.SettingsWindowShown() return ns.SparkleWindowShown() and ns.SparkleWindowPage() == "nodesight" end
function ns.HideSettingsWindow() ns.HideSparkleWindow() end
function ns.RefreshSettingsWindow() ns.RefreshSparkleWindow() end
