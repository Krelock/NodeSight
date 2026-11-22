-- NodeSight's own pages in the sparkle window's list, above the sparkles: General, the
-- Herb/Ore Switch, and Collecting's under its own header (General, Symbols, Areas,
-- Compass and arrow, Where to farm), each in two columns. One window for every setting, and
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
    switchFinders = function() ns.SwitchReset() ns.UpdateSwitch() ns.RefreshNodePins() end, -- (Only while tracking counts both kinds while it's on)
    minimapButton = function() if ns.MinimapButtonChanged then ns.MinimapButtonChanged() end end,
    collect = function() ns.UpdateCollect() end,
    collectMap = function() ns.RefreshNodePins() end,
    collectMapButton = function() ns.RefreshNodePins() end,
}
for _, key in ipairs({ "compass", "compassWidth", "compassRange" }) do
    AFTER[key] = function() ns.CompassChanged() end
end
AFTER.nodeArrow = function() ns.ArrowChanged() end
AFTER.nodeArrowSize = AFTER.nodeArrow
AFTER.nodeArrowRange = AFTER.nodeArrow
AFTER.collectGatherMate = function() ns.RereadNodePins() end
AFTER.collectSpawns = AFTER.collectGatherMate
AFTER.collectHideGatherMate = AFTER.collectGatherMate
for _, key in ipairs({ "collectAreas", "collectRareOnly", "collectRarePercent", "collectMapRare" }) do
    AFTER[key] = AFTER.collectGatherMate
end
for _, key in ipairs({ "collectMinimap", "collectShape", "collectSize", "collectMiniSize", "collectMiniLook", "collectMiniShared", "collectOpacity", "collectSkill", "collectOreRings",
    "collectMerge", "collectOnlyProfession", "collectOnlyTracking", "collectHideGray", "collectZoomLook", "collectMiniFade", "collectCaveNearest" }) do
    AFTER[key] = function() ns.RefreshNodePins() end
end

local function Set(key, value)
    if key == "collecting" then
        ns.SetCollecting(value)
        return ns.RefreshSparkleWindow()
    end
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
local TILES_WIDE, TILE_LINE = 330, 26 -- a row of tiles' widest (the previews sit right of it), and a wrapped line's step
local INDENT = 18 -- a row under the one it depends on
-- The columns, and how wide their words go. A slider row with its value is about 380 wide,
-- so the right column starts past the left one's widest ("100 % (233 yd)").
local LEFT, RIGHT, WIDE = 16, 400, 340
local NONE = {}

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
    control.label, control.hover, control.inRow = label, hover, true
    return label
end

-- A checkbox right of its words, as in Blizzard's options; its words click it too.
local function Checkbox(column, key, text, tip)
    local box = New("CheckButton", column.page, "MinimalCheckboxTemplate")
    box:SetSize(26, 26)
    box:SetScript("OnClick", function(self)
        PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        Set(key, self:GetChecked() == true)
    end)
    Row(text, box, tip)
    box.hover:SetScript("OnMouseDown", function() if box:IsEnabled() then box:Click() end end)
    box.key, box.kind = key, "box"
    Tooltip(box, text, tip)
    column[#column + 1] = box
    return box
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
                part:SetPoint("LEFT", column.page, "TOPLEFT", part.inRow and column.x + COLUMN or column.x, y - 13 - (part.drop or 0))
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

-- General: NodeSight's own settings.
local function GeneralColumns(column, _, page)
    -- The page's title alone on top with a gray line under it, then each column headed.
    page.about = Label(page, "NodeSight's own settings. The sparkles have their pages below Sparkles.", "GameFontDisableSmall")
    page.about:SetPoint("TOPLEFT", LEFT, -38)
    column.top = -56
    Header(column, "Options")
    Checkbox(column, "skillLine", "Required skill in tooltips",
        "Shows the skill a herb or ore needs in its tooltip when your mouse is on it in the world, and on herb and ore items.")
    Checkbox(column, "popups", "Popups", "Popups when Enable Interact Key is off or the game needs a restart.")
    Checkbox(column, "minimapButton", "Minimap button", "Left click opens these settings, right click turns all sparkles on or off.")
    Checkbox(column, "collecting", "Collecting (Beta)",
        "Marks herbs and ore on your world map and minimap, from the places you gather and every known spawn. Its pages below set it up.")
    Checkbox(column, "own", "This character only",
        "This character keeps its own NodeSight settings. Untick it to use the settings your other characters share. It offers a reload to switch.")
    Checkbox(column, "stoneBackground", "Stone background", "Blizzard's stone texture behind this window, warmed to the logo's brown. Off: plain brown.")
end

-- A row of choice tiles, the setup cards' art in small: the picked one lit. `short`: the words on
-- the tiles; the full names show in their tooltips, with a tile's own line from `notes`. A false
-- word is a choice taken out: no tile, the others keep their saved numbers.
local function Choices(column, key, text, choices, short, tip, notes, tips)
    local row = New("Frame", column.page)
    row:SetSize(1, 22)
    row.tiles = {}
    local x, line, wide, at = 0, 0, 0, {}
    for i, name in ipairs(short) do
        if name then
            local tile = New("Button", row)
            local back = tile:CreateTexture(nil, "BACKGROUND")
            back:SetAtlas("collections-background-tile")
            back:SetAllPoints()
            tile.border = tile:CreateTexture(nil, "BORDER")
            tile.border:SetAllPoints()
            tile.border:SetTextureSliceMargins(8, 8, 8, 8)
            local hover = tile:CreateTexture(nil, "HIGHLIGHT")
            hover:SetAtlas("PetList-ButtonHighlight")
            hover:SetAllPoints()
            hover:SetTextureSliceMargins(8, 8, 8, 8)
            tile.text = Label(tile, name, "GameFontNormalSmall")
            tile.text:SetPoint("CENTER")
            local width = math.ceil(tile.text:GetStringWidth()) + 18
            tile:SetSize(width, 22)
            if x > 0 and x + width > TILES_WIDE then x, line = 0, line + 1 end
            at[#at + 1] = { x, line }
            x = x + width + 4
            wide = math.max(wide, x - 4)
            tile:SetScript("OnClick", function()
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                Set(key, i)
            end)
            -- (`tips`: each tile's own text in place of the row's)
            Tooltip(tile, choices[i], tips and tips[i] or notes and notes[i] and tip .. " " .. notes[i] or tip)
            tile.value = i
            row.tiles[#row.tiles + 1] = tile
        end
    end
    -- A row too wide for the page wraps; its label stays by the first line.
    local drop = line * TILE_LINE / 2
    for i, tile in ipairs(row.tiles) do tile:SetPoint("LEFT", row, "LEFT", at[i][1], drop - at[i][2] * TILE_LINE) end
    row:SetSize(math.max(1, wide), 22 + line * TILE_LINE)
    Row(text, row, tip)
    if line > 0 then
        row.label:SetPoint("LEFT", row, "LEFT", -COLUMN, drop)
        row.drop, row.height = drop, 32 + line * TILE_LINE
    end
    row.key, row.kind = key, "choices"
    column[#column + 1] = row
    return row
end

-- A box or slider that only does something while `needs()` says so: grayed out otherwise, and
-- set in under the row it depends on (`under`).
local function Needs(part, needs, under)
    part.needs = needs
    if under then
        part.label:ClearAllPoints()
        part.label:SetPoint("LEFT", part, "LEFT", -COLUMN + INDENT, part.drop or 0)
        part.label:SetWidth(COLUMN - 8 - INDENT)
    end
    return part
end
local function On(key) return function() return ns.db[key] == true end end

-- The Herb/Ore Switch: its line and box over both columns, then When, Switch in and the
-- thanks on the left, Pauses on the right (its header level with When's).
local function SwitchColumns(column, right, page)
    page.line = Label(page, "", "GameFontHighlightSmall")
    page.line:SetPoint("TOPLEFT", column.x, -38)
    page.line:SetWidth(2 * WIDE)
    page.line:SetJustifyH("LEFT")
    column.top = -50
    page.finders = Checkbox(column, "switchFinders", "Herb/Ore Switch",
        "Switches between Find Herbs and Find Minerals as you travel. You need both trained and one active to start.")
    Header(column, "When")
    Choices(column, "switchMeasure", "Measure by", ns.SWITCH_MEASURES, { "Minimap %", "Yards", "Time" },
        "How the distance between switches is measured: percent of what your minimap shows (it changes with the zoom), yards, or seconds on the move.")
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
        -- Two to a row: each name with its box right after it.
        box.label:SetWidth(100)
        box.label:ClearAllPoints()
        box.label:SetPoint("LEFT", box, "LEFT", -104, 0)
        box:SetPoint("TOPLEFT", where, "TOPLEFT", (i - 1) % 2 * 170 + 104, -floor((i - 1) / 2) * 32)
    end
    where.boxes, where.tall = where.parts, true
    column[#column + 1] = where
    local thanks = Label(page, "Thanks to tester617 for the Switch page", "GameFontDisableSmall")
    thanks.gap, thanks.height = 4, 20
    column[#column + 1] = thanks
    column = right
    column.top = -82 -- (under the box)
    Header(column, "Pauses")
    Checkbox(column, "switchPauseBusy", "While busy",
        "Switching pauses while you cast, gather or loot, and while a spell waits for a target or something is on your cursor.")
    Slider(column, "switchEnemyYards", "Enemy targeted within", 0, 60, 1,
        "Switching pauses while you target a living enemy this close, and for a second after you mouse over one. Distances are rough: the game doesn't give exact ones.", YardsOrOff)
    Checkbox(column, "switchPauseStealth", "While stealthed", "Switching pauses while you're stealthed.")
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

local function Percent100(value) return ("%d %%"):format(value) end
local function Whole(value) return ("%d"):format(value) end

-- Collecting's pages. A gray line under a page's title says what it is for.
local function About(page, text, column, other)
    page.about = Label(page, text, "GameFontDisableSmall")
    page.about:SetPoint("TOPLEFT", LEFT, -38)
    page.about:SetWidth(2 * WIDE)
    page.about:SetJustifyH("LEFT")
    column.top, other.top = -56, -56
end

-- Collecting's General: where the marks come from on the left; where they show, which ones and the
-- places remembered on the right.
local function CollectColumns(column, places, page)
    About(page, "Remembers where you gather herbs and ore and marks the places on your world map and minimap.", column, places)
    Header(column, "Sources")
    Checkbox(column, "collect", "Places I gather",
        "Remembers each place you gather a herb or ore. Off: nothing new is remembered and the world map shows no marks; the places remembered are kept.")
    Checkbox(column, "collectSpawns", "Every known spawn",
        "Marks every known herb and ore spawn in Forever, whether or not you've been there. A known spawn is where one can grow, not one that's up now.")
    local function GatherMate() return ns.GatherMateLoaded() end
    page.gatherMate = Needs(Checkbox(column, "collectGatherMate", "GatherMate2's places", "Marks the herbs and ore GatherMate2 knows too."), GatherMate)
    Needs(Checkbox(column, "collectHideGatherMate", "Hide its own icons", "Turns off GatherMate2's own herb and ore icons while its places show here."),
        function() return ns.GatherMateLoaded() and ns.db.collectGatherMate == true end, true)
    page.noGatherMate = Label(page, "GatherMate2 isn't loaded.", "GameFontDisableSmall")
    page.noGatherMate.gap, page.noGatherMate.height = 0, 20
    column[#column + 1] = page.noGatherMate
    -- At the page's bottom: the thanks, and that Collecting is new right above it.
    page.thanks = Label(page, "Thanks to Urfoks for helping with Collecting", "GameFontDisableSmall")
    page.thanks:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", LEFT, 16)
    page.future = Label(page, "Collecting is new and will be improved in future updates.", "GameFontDisableSmall")
    page.future:SetPoint("BOTTOMLEFT", page.thanks, "TOPLEFT", 0, 4)
    Header(places, "Show on")
    Checkbox(places, "collectMap", "World map", "A symbol on the world map for each marked place. Put your mouse on one to see what it was.")
    Needs(Checkbox(places, "collectMapButton", "Map button", "A button at the world map's top right that shows or hides these symbols."), nil, true)
    Needs(Checkbox(places, "collectMapRare", "Rares and near you", "Far from you, the world map shows only rare herbs and ore, such as silver and Kingsblood."),
        function() return ns.db.collectMap == true and not ns.db.collectRareOnly end, true)
    Checkbox(places, "collectMinimap", "Minimap", "The same symbols on the minimap for the places near you. They let the mouse through to the game's own dots.")
    Needs(Checkbox(places, "collectMiniFade", "Fade toward the edge", "Symbols farther from you fade, so the ones near you stand out."), On("collectMinimap"), true)
    Needs(Checkbox(places, "collectCaveNearest", "Caves: nearest only", "In a cave the minimap shows only the 5 nearest spawns, so a mine's tunnels and levels don't pile up."), On("collectMinimap"), true)
    Header(places, "Only show")
    Checkbox(places, "collectOnlyProfession", "My professions", "Herbs are marked only on characters with Herbalism, ore only with Mining.")
    Checkbox(places, "collectOnlyTracking", "While tracking",
        "Herbs are marked only while Find Herbs is on, ore only while Find Minerals is on. With the Herb/Ore Switch on, both are.")
    Checkbox(places, "collectHideGray", "Skill-ups", "Leaves out herbs and ore that no longer give you a skill-up (gray in your profession window).")
    Checkbox(places, "collectRareOnly", "Rare ones", "Marks only rare herbs and ore, such as gold and Black Lotus.")
    local rare = ns.COLLECT_RANGES.collectRarePercent
    Needs(Slider(places, "collectRarePercent", "Or under", rare[1], rare[2], rare[3],
        "Herbs or ore that make up less than this share of a zone's count as rare there too. 0: only the list.", Percent100), On("collectRareOnly"), true)
    Header(places, "Remembered places")
    page.count = Label(page, "", "GameFontHighlight")
    page.count.height = 28
    places[#places + 1] = page.count
    page.forget = New("Button", page, "UIPanelButtonTemplate")
    page.forget:SetSize(128, 22)
    page.forget:SetText("Forget all")
    page.forget:SetScript("OnClick", function() ns.AskForget() end)
    Tooltip(page.forget, "Forget all", "Forgets every place NodeSight remembered, for all your characters. It asks first.")
    places[#places + 1] = page.forget
end

-- The rows setup's maps step shares with the Symbols and Areas pages.
local function AreasBox(column)
    Checkbox(column, "collectAreas", "Group close spawns", "Close spawns of one herb or ore, like a mine, show as one symbol with a count.")
end
local function MergeBox(column)
    Checkbox(column, "collectMerge", "Merge overlaps", "Symbols of one herb or ore that would cover each other on the world map show as one, with how many there are. Zoom in to see each one.")
end
local function ShapeRow(column)
    Choices(column, "collectShape", "Shape", ns.COLLECT_SHAPES, { "Square", "Round", "Gold ring", "Slim ring" },
        "The symbols' shape, on the world map and the minimap.")
end
local function MiniLookRows(column, look)
    Choices(column, "collectMiniLook", look, ns.COLLECT_MINI_LOOKS, { "Whole", "Hole", "See-through", "Pin" },
        "How a minimap symbol leaves room for the game's own dot under it.", nil, {
            "The full symbol sits on the spot, over the game's own dot.",
            "A hole in the middle of the symbol shows the game's own dot under it. Best with Minimap size 30.",
            "The middle of the symbol is faded, so the game's own dot shows through it.",
            "The symbol sits above the spot on a short stem, leaving the game's own dot clear.",
        })
    Choices(column, "collectMiniShared", "Shared spots", ns.COLLECT_MINI_SHARED, { "Common one", "Split", "Badge" },
        "Where two herbs or ores can spawn at one spot, how a minimap symbol shows both.", nil, {
            "Only the more common one shows, for example copper where tin can spawn too. Its tooltip names both.",
            "Both show, each icon on one half of the symbol.",
            "The more common one shows, with the other's symbol small at its top left.",
        })
end
local function MiniSize(column, text)
    local mini = ns.COLLECT_RANGES.collectMiniSize
    Slider(column, "collectMiniSize", text, mini[1], mini[2], mini[3], "How big the symbols are on the minimap.", Whole)
end
local function MapSize(column, text)
    local size = ns.COLLECT_RANGES.collectSize
    Slider(column, "collectSize", text, size[1], size[2], size[3], "How big the symbols are on the world map.", Whole)
end
local function Opacity(column, text)
    local opacity = ns.COLLECT_RANGES.collectOpacity
    Slider(column, "collectOpacity", text, opacity[1], opacity[2], opacity[3],
        "How much of a minimap symbol's picture shows; its ring stays solid. Lower lets the game's dot under it show through.", Percent100)
end
local function ZoomRow(column)
    Choices(column, "collectZoomLook", "Zoomed out", ns.COLLECT_ZOOM_LOOKS, { "Symbols", false, false, "Hex tiles", "Rings", "Groups", false, "Dots", "Regions" },
        "How spawns show on the world map at its widest zoom, for example groups: one symbol with a count for each group of herbs or ore.")
end
local function SkillRow(column)
    Choices(column, "collectSkill", "Skill colors", ns.COLLECT_SKILL_LOOKS, { "Red if too low", "Ring", "Gem", "Off" },
        "How a symbol shows your skill, for example a gem in the profession window's colors. Ring needs a ring shape.")
end

-- The settings that change the maps most, each one a click: setup's maps step.
local function MapRows(column)
    MiniSize(column, "Minimap size")
    MapSize(column, "World map size")
    Opacity(column, "Minimap opacity")
    ShapeRow(column)
    MiniLookRows(column, "Minimap look")
    ZoomRow(column)
    SkillRow(column)
    AreasBox(column)
    MergeBox(column)
end

-- Symbols: what both maps share, then the minimap's and the world map's own, in the previews' order.
local function SymbolColumns(column, other, page)
    About(page, "How the herb and ore symbols look on the world map and the minimap.", column, other)
    Header(column, "Both maps")
    ShapeRow(column)
    SkillRow(column)
    Needs(Checkbox(column, "collectOreRings", "Tin and iron rings",
        "Tin gets a green ring and iron a rust one, so they're easy to tell apart. Needs a ring shape."), function() return ns.db.collectShape > 2 end)
    AreasBox(column)
    Header(column, "Minimap")
    MiniSize(column, "Size")
    Opacity(column, "Opacity")
    MiniLookRows(column, "Look")
    Header(column, "World map")
    MapSize(column, "Size")
    MergeBox(column)
    ZoomRow(column)
end

-- Compass and arrow: the compass bar on the left, the next node arrow on the right. Both can be
-- dragged while this page shows.
local function CompassColumns(column, other, page)
    About(page, "A compass strip and an arrow at the top of the screen for the herbs and ore marked near you. Drag them to move them while this page is open.",
        column, other)
    Header(column, "Compass bar")
    Checkbox(column, "compass", "Show", "A strip at the top of the screen with the herbs and ore near you.")
    local width, range = ns.COLLECT_RANGES.compassWidth, ns.COLLECT_RANGES.compassRange
    Needs(Slider(column, "compassWidth", "Width", width[1], width[2], width[3], "How wide the compass bar is.", Whole), On("compass"), true)
    Needs(Slider(column, "compassRange", "Range", range[1], range[2], range[3], "How far away a place can be to show on the compass bar.", Yards), On("compass"), true)
    Header(other, "Next node arrow")
    Checkbox(other, "nodeArrow", "Show", "Points to the nearest marked herb or ore you can gather.")
    local arrowRange = ns.COLLECT_RANGES.nodeArrowRange
    Needs(Slider(other, "nodeArrowRange", "Range", arrowRange[1], arrowRange[2], arrowRange[3], "How far away a place can be for the arrow to point to it.", Yards),
        On("nodeArrow"), true)
    local arrowSize = ns.COLLECT_RANGES.nodeArrowSize
    Needs(Slider(other, "nodeArrowSize", "Size", arrowSize[1], arrowSize[2], arrowSize[3], "How big the arrow is.", Percent100), On("nodeArrow"), true)
    page:HookScript("OnShow", function()
        ns.CompassMovable(true)
        ns.ArrowMovable(true)
    end)
    page:HookScript("OnHide", function()
        ns.CompassMovable(false)
        ns.ArrowMovable(false)
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

-- Where to farm: the zones with the most marked places that still give a skill-up,
-- herbs on the left and ore on the right. Worked out when the page shows.
local FARM_ROWS = 12
local KIND_WORDS = { herbs = { "Herbs", "Herbalism" }, ore = { "Ore", "Mining" } }

local function FarmColumn(column, page, kind)
    Header(column, KIND_WORDS[kind][1])
    local rows = {}
    for i = 1, FARM_ROWS do
        local row = New("Frame", page)
        row:SetSize(WIDE, 18)
        row.height = 22
        row.name = Label(row, "", "GameFontHighlight")
        row.name:SetPoint("LEFT")
        row.name:SetWidth(WIDE - 110)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.count = Label(row, "", "GameFontHighlight")
        row.count:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        row.count:SetJustifyH("RIGHT")
        rows[i] = row
        column[#column + 1] = row
    end
    local none = Label(page, "", "GameFontDisableSmall")
    none:SetWidth(WIDE)
    none:SetJustifyH("LEFT")
    none.height = 22
    column[#column + 1] = none
    page.farm[kind] = { rows = rows, none = none }
end

local function FarmColumns(left, right, page)
    page.about = Label(page, "Zones with the most marked herbs and ore that still give you skill-ups: orange, yellow and green, as in your profession window. "
        .. "From your own places, the known spawns and GatherMate2's.", "GameFontDisableSmall")
    page.about:SetPoint("TOPLEFT", LEFT, -38)
    page.about:SetWidth(2 * WIDE)
    page.about:SetJustifyH("LEFT")
    left.top, right.top = -66, -66
    page.farm = {}
    FarmColumn(left, page, "herbs")
    FarmColumn(right, page, "ore")
    page.future = Label(page, "This page will be improved greatly in new updates.", "GameFontDisableSmall")
    page.future:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", LEFT, 16)
end

-- One kind's column: its zones, or why there are none.
local function FillFarm(column, list, kind)
    local C = ns.Collecting
    local why
    if not ns.HasProfession(kind) then
        why = ("No %s on this character."):format(KIND_WORDS[kind][2])
    elseif not (ns.db.collect or ns.db.collectSpawns or ns.db.collectGatherMate) then
        why = "Turn on Remember where I gather, Every known spawn or GatherMate2's places on the Collecting page."
    elseif #list == 0 then
        why = "No marked places give you a skill-up yet."
    end
    for i, row in ipairs(column.rows) do
        local zone = not why and list[i]
        row:SetShown(zone ~= nil and zone ~= false)
        if zone then
            row.name:SetText(zone.name)
            local parts = {}
            for _, level in ipairs(C.FARM_LEVELS) do
                if zone[level] > 0 then parts[#parts + 1] = C.SkillColor(level):WrapTextInColorCode(zone[level]) end
            end
            row.count:SetText(table.concat(parts, "  "))
        end
    end
    column.none:SetText(why or "")
    column.none:SetShown(why ~= nil)
end

---------------------------------------------------------------------------
-- Collecting's setup
---------------------------------------------------------------------------
-- Steps over the Collecting page the first time it opens, and from its Set up button,
-- each one question: where the marks come from and when (picture cards), which herbs
-- and ore, and the look with a minimap preview. Refresh fills the step shown.

local SETUP_STEPS = {
    { "Sources", "Where should your marks come from?" },
    { "Show", "When should herbs and ore be marked?" },
    { "Herbs", "Which herbs should be marked?" },
    { "Ore", "Which ore should be marked?" },
    { "Maps", "How should the maps look?" },
}
local CONTENT = -126 -- where a step's own parts start
local CARD_W, CARD_H, CARD_GAP = 214, 128, 24
local DOTS_WIDE, DOT = 520, 24
local LIST_ROWS, LIST_STEP, LIST_COLUMN = 14, 19, 250 -- a herbs or ore step's rows per column, row and column width
local HERB, ORE, NOTE = "Interface\\Icons\\INV_Misc_Herb_01", "Interface\\Icons\\INV_Ore_Copper_01", "Interface\\Icons\\INV_Misc_Note_01"
local PREVIEW = 200
-- The preview's ground: one of the game's own minimap pictures (Elwynn Forest by Goldshire,
-- a tile of 1600/3 yards), the 300 yards a minimap at its usual zoom shows, as much darker as
-- the game draws its minimap's pictures.
local GROUND, GROUND_YARDS = 204454, 1600 / 3
-- The minimap's zooms, widest first: yards across at each (the original game's outdoor sizes,
-- 466 2/3 down to 133 1/3).
local function ZoomYards(zoom) return 200 * (7 - zoom) / 3 end
local MINIMAP_TINT = { 0.87, 0.84, 0.80 }
-- The game's yellow node dot under each sample, which the minimap's see-through shows: the
-- gold blip from the minimap's own icon sheet (its dot and dark edge, 22 of 256 pixels), as
-- many pixels across as the minimap draws it.
local NODE_DOT = { file = "Interface\\Minimap\\ObjectIcons", 198 / 256, 220 / 256, 3.5 / 256, 25.5 / 256, across = 11 }

local function Button(parent, text, width, onClick)
    local button = New("Button", parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function Step(setup)
    local step = New("Frame", setup)
    step:SetAllPoints()
    step.column = { page = step, x = LEFT, top = CONTENT }
    step.cards = {}
    setup.steps[#setup.steps + 1] = step
    return step
end

-- A picture card, as the sparkle gallery's tiles: a gold border while it's picked.
local function Card(step, title, about, icons, tip, onClick)
    local card = New("Button", step)
    card:SetSize(CARD_W, CARD_H)
    card:SetPoint("TOP", step, "TOP", (#step.cards - 1) * (CARD_W + CARD_GAP), CONTENT)
    local back = card:CreateTexture(nil, "BACKGROUND")
    back:SetAtlas("collections-background-tile")
    back:SetAllPoints()
    card.border = card:CreateTexture(nil, "BORDER")
    card.border:SetAllPoints()
    card.border:SetTextureSliceMargins(10, 10, 10, 10) -- (the art's corners kept at any size)
    local hover = card:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAtlas("PetList-ButtonHighlight")
    hover:SetAllPoints()
    hover:SetTextureSliceMargins(10, 10, 10, 10)
    card.icons = {}
    for i, icon in ipairs(icons) do
        local texture = card:CreateTexture(nil, "ARTWORK")
        texture:SetSize(36, 36)
        texture:SetPoint("TOP", card, "TOP", (i - (#icons + 1) / 2) * 42, -14)
        texture:SetTexture(icon[1])
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- (without the icon's border)
        texture:SetDesaturated(icon.gray == true)
        card.icons[i] = texture
    end
    card.title = Label(card, title, "GameFontNormal")
    card.title:SetPoint("TOP", 0, -62)
    card.about = Label(card, about, "GameFontDisableSmall")
    card.about:SetPoint("TOP", card.title, "BOTTOM", 0, -6)
    card.about:SetWidth(CARD_W - 24)
    card.tick = card:CreateTexture(nil, "OVERLAY")
    card.tick:SetAtlas("common-icon-checkmark-yellow")
    card.tick:SetSize(18, 18)
    card.tick:SetPoint("TOPRIGHT", -8, -8)
    card:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        onClick()
    end)
    Tooltip(card, title, tip)
    step.cards[#step.cards + 1] = card
    return card
end

local function LightCard(card, on)
    card.border:SetAtlas(on and "PetList-ButtonSelect" or "PetList-ButtonBackground")
    card.title:SetFontObject(on and "GameFontHighlight" or "GameFontNormal")
    card.tick:SetShown(on)
end

-- A checkbox with its words right of it.
local function SmallBox(step, key, text, tip)
    local box = New("CheckButton", step, "MinimalCheckboxTemplate")
    box:SetSize(26, 26)
    box.text = Label(box, text, "GameFontHighlight")
    box.text:SetPoint("LEFT", box, "RIGHT", 4, 0)
    box:SetScript("OnClick", function(self)
        PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        Set(key, self:GetChecked() == true)
    end)
    box.key, box.kind = key, "box"
    Tooltip(box, text, tip)
    step.small = step.small or {}
    step.small[#step.small + 1] = box
    return box
end

-- The numbered dots along the top: the step shown gold, the ones before it ticked.
local function Dots(setup)
    setup.dots = {}
    local gap = DOTS_WIDE / (#SETUP_STEPS - 1)
    for i, info in ipairs(SETUP_STEPS) do
        local x = -DOTS_WIDE / 2 + (i - 1) * gap
        if i > 1 then
            local line = setup:CreateTexture(nil, "BORDER")
            line:SetSize(gap - DOT, 2)
            line:SetPoint("CENTER", setup, "TOP", x - gap / 2, -44)
            setup.dots[i - 1].line = line
        end
        local dot = New("Button", setup)
        dot:SetSize(DOT, DOT)
        dot:SetPoint("CENTER", setup, "TOP", x, -44)
        for _, part in ipairs({ { "ring", DOT, "ARTWORK" }, { "fill", DOT - 4, "ARTWORK", 1 } }) do
            local texture = dot:CreateTexture(nil, part[3], nil, part[4])
            texture:SetSize(part[2], part[2])
            texture:SetPoint("CENTER")
            local mask = dot:CreateMaskTexture()
            mask:SetAtlas("CircleMask")
            mask:SetAllPoints(texture)
            texture:AddMaskTexture(mask)
            dot[part[1]] = texture
        end
        dot.number = Label(dot, tostring(i), "GameFontNormalSmall")
        dot.number:SetPoint("CENTER", 0, 1)
        dot.tick = dot:CreateTexture(nil, "OVERLAY")
        dot.tick:SetAtlas("common-icon-checkmark-yellow")
        dot.tick:SetSize(14, 14)
        dot.tick:SetPoint("CENTER")
        dot.label = Label(dot, info[1], "GameFontDisableSmall")
        dot.label:SetPoint("TOP", dot, "BOTTOM", 0, -3)
        dot:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            setup.step = i
            ns.RefreshSparkleWindow()
        end)
        setup.dots[i] = dot
    end
end

local function LightDots(setup)
    for i, dot in ipairs(setup.dots) do
        local done, now = i < setup.step, i == setup.step
        if done or now then dot.ring:SetColorTexture(1, 0.82, 0, 1) else dot.ring:SetColorTexture(0.43, 0.41, 0.37, 1) end
        if done then
            dot.fill:SetColorTexture(0.59, 0.45, 0.08, 1)
        elseif now then
            dot.fill:SetColorTexture(0.27, 0.22, 0.08, 1)
        else
            dot.fill:SetColorTexture(0.1, 0.09, 0.08, 1)
        end
        dot.number:SetShown(not done)
        dot.number:SetFontObject(now and "GameFontNormalSmall" or "GameFontDisableSmall")
        dot.tick:SetShown(done)
        dot.label:SetFontObject(now and "GameFontNormalSmall" or "GameFontDisableSmall")
        if dot.line then
            if done then dot.line:SetColorTexture(0.78, 0.63, 0.12, 1) else dot.line:SetColorTexture(0.35, 0.31, 0.22, 1) end
        end
    end
end

-- A step with a box for each herb or ore: ticked ones are marked.
local function NodeStep(setup, kind)
    local step = Step(setup)
    step.boxes = {}
    for i, entry in ipairs(ns.NODE_LIST[kind]) do
        local box = New("CheckButton", step, "MinimalCheckboxTemplate")
        box:SetSize(22, 22)
        box:SetPoint("TOPLEFT", step, "TOPLEFT", LEFT + floor((i - 1) / LIST_ROWS) * LIST_COLUMN, CONTENT - (i - 1) % LIST_ROWS * LIST_STEP)
        local need = ns.NODE_NEEDS[kind][entry]
        box.label = Label(box, ns.Collecting.DisplayName(entry) .. (need and need > 1 and ("  |cff9d9d9d%d|r"):format(need) or ""),
            "GameFontHighlightSmall")
        box.label:SetPoint("LEFT", box, "RIGHT", 2, 0)
        box.entry = entry
        box:SetScript("OnClick", function(self)
            PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
            ns.db.collectHidden[entry] = not self:GetChecked() or nil
            ns.RefreshNodePins()
        end)
        step.boxes[i] = box
    end
    local function All(on)
        for _, entry in ipairs(ns.NODE_LIST[kind]) do ns.db.collectHidden[entry] = not on or nil end
        ns.RefreshNodePins()
        ns.RefreshSparkleWindow()
    end
    step.all = Button(step, "All", 70, function() All(true) end)
    step.all:SetPoint("TOPLEFT", step, "TOPLEFT", LEFT, CONTENT - LIST_ROWS * LIST_STEP - 10)
    step.none = Button(step, "None", 70, function() All(false) end)
    step.none:SetPoint("LEFT", step.all, "RIGHT", 6, 0)
    return step
end

-- A preview round like the minimap, on one of the game's own minimap pictures, its top left
-- at x, y on parent.
local function PreviewGround(parent, x, y)
    local preview = New("Frame", parent)
    preview:SetSize(PREVIEW, PREVIEW)
    preview:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    preview.x, preview.y, preview.fit = x, y, 1
    preview.mask = preview:CreateMaskTexture()
    preview.mask:SetAtlas("CircleMask", false, nil, nil, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    preview.mask:SetAllPoints()
    preview.back = preview:CreateTexture(nil, "BACKGROUND")
    preview.back:SetAllPoints()
    preview.back:SetColorTexture(0.12, 0.1, 0.07, 1)
    preview.back:AddMaskTexture(preview.mask)
    preview.ground = preview:CreateTexture(nil, "BORDER")
    preview.ground:SetAllPoints()
    preview.ground:SetTexture(GROUND, nil, nil, "TRILINEAR")
    preview.ground:SetVertexColor(MINIMAP_TINT[1], MINIMAP_TINT[2], MINIMAP_TINT[3])
    preview.ground:AddMaskTexture(preview.mask)
    preview.border = preview:CreateTexture(nil, "OVERLAY")
    preview.arrow = preview:CreateTexture(nil, "OVERLAY", nil, 1)
    preview.arrow:SetAtlas("MinimapArrow")
    preview.arrow:SetSize(24, 24)
    preview.arrow:SetPoint("CENTER")
    preview.symbols, preview.dots = {}, {}
    -- Zoomed all the way out at first; the minimap's own zoom buttons and the mouse wheel.
    preview.zoom = 0
    local function Zoom(step)
        local levels = preview.levels or 1
        local zoom = math.min(math.max(preview.zoom + step, 0), levels - 1)
        if zoom == preview.zoom then return end
        preview.zoom = zoom
        PlaySound(step > 0 and SOUNDKIT.IG_MINIMAP_ZOOM_IN or SOUNDKIT.IG_MINIMAP_ZOOM_OUT)
        if preview.refresh then preview.refresh(preview) end
    end
    for _, button in ipairs({ { "In", 1, 17, -2, 30 }, { "Out", -1, 9, -2, 14 } }) do
        local zoom = New("Button", preview)
        zoom:SetSize(17, button[3])
        zoom:SetPoint("BOTTOMRIGHT", preview, "BOTTOMRIGHT", button[4], button[5])
        zoom:SetNormalAtlas("UI-HUD-Minimap-Zoom-" .. button[1])
        zoom:SetPushedAtlas("UI-HUD-Minimap-Zoom-" .. button[1] .. "-Down")
        zoom:SetHighlightAtlas("UI-HUD-Minimap-Zoom-" .. button[1] .. "-Mouseover")
        zoom:SetDisabledAtlas("UI-HUD-Minimap-Zoom-" .. button[1])
        zoom:GetDisabledTexture():SetDesaturated(true)
        zoom:SetScript("OnClick", function() Zoom(button[2]) end)
        preview["zoom" .. button[1]] = zoom
    end
    preview:EnableMouseWheel(true)
    preview:SetScript("OnMouseWheel", function(_, delta) Zoom(delta > 0 and 1 or -1) end)
    return preview
end

-- The minimap's own dot for a found herb or ore, in the preview's dots (or the list given).
local function Coin(preview, list)
    local dot = preview:CreateTexture(nil, "ARTWORK")
    dot:SetTexture(NODE_DOT.file)
    dot:SetTexCoord(NODE_DOT[1], NODE_DOT[2], NODE_DOT[3], NODE_DOT[4])
    dot:SetSize(NODE_DOT.across, NODE_DOT.across)
    dot.across = NODE_DOT.across
    list = list or preview.dots
    list[#list + 1] = dot
    return dot
end

-- The minimap's own ring, at the preview's size, where the game has one.
local function PreviewBorder(preview)
    local ring = _G.MinimapCompassTexture
    local atlas = ring and ring.GetAtlas and ring:GetAtlas()
    local across = Minimap and Minimap:GetWidth()
    if type(atlas) ~= "string" or issecretvalue(atlas) or issecretvalue(across) or not (across and across > 0) then
        preview.border:Hide()
        return
    end
    local scale = PREVIEW / across
    preview.border:SetAtlas(atlas)
    preview.border:SetSize(ring:GetWidth() * scale, ring:GetHeight() * scale)
    preview.border:SetPoint("CENTER")
    preview.border:Show()
end

-- The preview as big on screen as the real minimap, and its symbols as big as the minimap
-- draws them at its zoom now (smaller zoomed out). Kept within reason for the page.
local FIT = { 0.6, 1.4 }
local function FitPreview(preview)
    local across, scale = Minimap and Minimap:GetWidth(), Minimap and Minimap:GetEffectiveScale()
    local here = preview:GetParent():GetEffectiveScale()
    local fit, unit = 1, 1 -- (the preview's scale; minimap pixels a preview pixel)
    if type(across) == "number" and type(scale) == "number" and not (issecretvalue(across) or issecretvalue(scale)) and across > 0 and here > 0 then
        fit = math.min(math.max(across * scale / (PREVIEW * here), FIT[1]), FIT[2])
        unit = PREVIEW / across
    end
    if preview.fit ~= fit then
        preview.fit = fit
        preview:SetScale(fit)
        preview:ClearAllPoints()
        preview:SetPoint("TOPLEFT", preview:GetParent(), "TOPLEFT", preview.x / fit, preview.y / fit) -- (offsets are in its own scale)
    end
    preview.unit = unit
    for _, dot in ipairs(preview.dots) do dot:SetSize(dot.across * unit, dot.across * unit) end
    -- The zoom: the ground's yards, the samples spread by it, the symbols smaller zoomed out.
    local levels = Minimap and Minimap:GetZoomLevels()
    levels = type(levels) == "number" and not issecretvalue(levels) and levels > 1 and math.min(levels, 6) or 6
    preview.levels = levels
    preview.zoom = math.min(preview.zoom, levels - 1)
    preview.zoomIn:SetEnabled(preview.zoom < levels - 1)
    preview.zoomOut:SetEnabled(preview.zoom > 0)
    local yards = ZoomYards(preview.zoom)
    local part = yards / GROUND_YARDS
    preview.ground:SetTexCoord(0.5 - part / 2, 0.5 + part / 2, 0.5 - part / 2, 0.5 + part / 2)
    return ns.Collecting.Shrink(preview.zoom / (levels - 1)) * unit, PREVIEW / yards
end

-- The Areas page's preview: a few spawns on a made-up map, grouped into areas by the area
-- settings as a map's are. Node, kind, yards east and south of the middle, skill color.
local AREA_SAMPLES = {
    -- A copper mine.
    { "copper vein", "ore", -60, -50, 4 }, { "copper vein", "ore", -48, -44, 4 }, { "copper vein", "ore", -70, -42, 4 },
    { "copper vein", "ore", -54, -62, 4 }, { "copper vein", "ore", -68, -60, 4 }, { "copper vein", "ore", -44, -54, 4 },
    { "copper vein", "ore", -62, -34, 4 },
    -- Tin along a ridge, about 30 yards apart.
    { "tin vein", "ore", -110, 60, 3 }, { "tin vein", "ore", -80, 65, 3 }, { "tin vein", "ore", -50, 70, 3 }, { "tin vein", "ore", -20, 75, 3 },
    { "tin vein", "ore", 10, 80, 3 }, { "tin vein", "ore", 40, 85, 3 }, { "tin vein", "ore", 70, 90, 3 }, { "tin vein", "ore", 100, 96, 3 },
    -- A patch of peacebloom.
    { "peacebloom", "herbs", 70, -60, 5 }, { "peacebloom", "herbs", 80, -52, 5 }, { "peacebloom", "herbs", 61, -54, 5 },
    { "peacebloom", "herbs", 75, -71, 5 }, { "peacebloom", "herbs", 64, -68, 5 },
    -- And some alone.
    { "mageroyal", "herbs", -20, -110, 4, empty = true }, { "silverleaf", "herbs", 115, -5, 5 }, { "earthroot", "herbs", -125, 0, 5, empty = true },
    { "silver vein", "ore", 35, 25, 2 }, -- (rare: what Rare ones only keeps)
}
-- On the setup's maps step also: a spot copper and tin share, and the game's own node dot under
-- every symbol but the empty spawns', for the minimap looks and shared spots to show on.
local MAP_EXTRAS = { shared = { "copper vein", "ore", 120, 60, 4, "tin vein" } }
local AREA_MAP, AREA_MIDDLE = 1000, 500 -- the made-up map's yards across (a unit a yard), and its middle
local areaPlaces, areaLevels -- [key] = { place, ... } and [key] = skill color, made once

local function AreaSymbol(preview, n, key, kind, dx, dy, count, look, size, second)
    local C = ns.Collecting
    local symbol = preview.symbols[n]
    if not symbol then
        symbol = C.NewSymbol(preview)
        symbol:SetFrameLevel(preview:GetFrameLevel() + 2)
        preview.symbols[n] = symbol
    end
    symbol.key, symbol.sampleLevel = key, areaLevels[key]
    C.ApplyShape(symbol, look)
    C.ApplyLook(symbol, key, kind, look)
    C.MiniShared(symbol, second, kind, look)
    C.ShowCount(symbol, count)
    symbol:SetScale(size)
    symbol:SetPoint("CENTER", preview, "CENTER", dx / size, dy / size)
    symbol:Show()
end

local function RefreshAreaPreview(preview)
    preview.refresh = RefreshAreaPreview
    PreviewBorder(preview)
    local size, perYard = FitPreview(preview)
    local C = ns.Collecting
    if not areaPlaces then
        areaPlaces, areaLevels = {}, {}
        for _, sample in ipairs(AREA_SAMPLES) do
            local key = sample[1]
            areaPlaces[key] = areaPlaces[key] or {}
            table.insert(areaPlaces[key], (AREA_MIDDLE + sample[3]) * C.PACK + AREA_MIDDLE + sample[4])
            areaLevels[key] = sample[5]
        end
    end
    local look = C.CurrentLook(true) -- (the minimap's look)
    local common = C.Common(nil, areaPlaces, nil) or NONE -- (Rare ones only: the ones left out)
    local areas, inAreas
    if preview.zoom <= 1 then -- (as the minimap: closer in, a symbol each)
        areas, inAreas = C.AreasIn(AREA_MAP, AREA_MAP, areaPlaces, nil)
    end
    local n, glows = 0, 0
    for _, sample in ipairs(AREA_SAMPLES) do
        local key = sample[1]
        local place = (AREA_MIDDLE + sample[3]) * C.PACK + AREA_MIDDLE + sample[4]
        if not common[key] and not (inAreas and inAreas[key] and inAreas[key][place]) then
            n = n + 1
            AreaSymbol(preview, n, key, sample[2], sample[3] * perYard, -sample[4] * perYard, nil, look, size)
        end
    end
    for _, area in ipairs(areas or NONE) do
        if not common[area.key] then
            glows = glows + 1
            n = n + 1
            AreaSymbol(preview, n, area.key, area.kind, (area.x - AREA_MIDDLE) * perYard, (AREA_MIDDLE - area.y) * perYard, area.count, look, size)
            local dot = preview.areaDots and (preview.areaDots[glows] or Coin(preview, preview.areaDots))
            if dot then
                dot:SetSize(dot.across * preview.unit, dot.across * preview.unit)
                dot:SetPoint("CENTER", preview, "CENTER", (area.x - AREA_MIDDLE) * perYard, (AREA_MIDDLE - area.y) * perYard)
                dot:Show()
            end
        end
    end
    for i = glows + 1, preview.areaDots and #preview.areaDots or 0 do preview.areaDots[i]:Hide() end
    if preview.extras then
        local shared = MAP_EXTRAS.shared
        if not common[shared[1]] then
            n = n + 1
            AreaSymbol(preview, n, shared[1], shared[2], shared[3] * perYard, -shared[4] * perYard, nil, look, size, shared[6])
        end
        for _, dot in ipairs(preview.dots) do
            local sample = dot.sample
            local place = (AREA_MIDDLE + sample[3]) * C.PACK + AREA_MIDDLE + sample[4]
            dot:SetShown(not common[sample[1]] and not (inAreas and inAreas[sample[1]] and inAreas[sample[1]][place])) -- (the shared spot is in none)
            dot:SetPoint("CENTER", preview, "CENTER", sample[3] * perYard, -sample[4] * perYard)
        end
    end
    for i = n + 1, #preview.symbols do preview.symbols[i]:Hide() end
end

-- The maps step's world map preview: a piece of Elwynn Forest's own map art with made-up spawns,
-- drawn by the world map's own code as it draws them zoomed all the way out, in the zoomed-out
-- look set. Node, kind, pixels from the top left, skill color.
local WORLD_W, WORLD_H, WORLD_MAP, WORLD_TILE = 210, 140, 1429, 6 -- (a tile of 256: about 900 yards)
local WORLD_YARDS = 900 -- the preview's width in yards
-- Elwynn's explored parts over that tile, so it looks explored whoever opens it: the game's map
-- draws each part from tiles of 256 art pixels (the last row and column cut from a smaller
-- file), as its exploration pins do. Width, height, x, y, files row by row (Forever's map art
-- 2153: WorldMapOverlay and WorldMapOverlayTile). The tile is art pixels 256 to 512 each way.
local WORLD_OVERLAYS = { { 256, 256, 422, 332, { 8061956 } }, { 256, 341, 124, 327, { 8061971, 8061972 } },
    { 256, 256, 250, 270, { 8061973 } }, { 256, 256, 381, 147, { 8061975 } }, { 512, 512, 0, 0, { 8061980, 8061981, 8061982, 8061983 } } }
local WORLD_ART = 256 -- (the tile's top left, and a tile's size, in art pixels)
local WORLD_SAMPLES = {
    { "copper vein", "ore", 36, 30, 4 }, { "copper vein", "ore", 42, 33, 4 }, { "copper vein", "ore", 39, 38, 4 },
    { "copper vein", "ore", 46, 36, 4 }, { "copper vein", "ore", 34, 37, 4 }, { "copper vein", "ore", 44, 29, 4 },
    { "tin vein", "ore", 70, 100, 3 }, { "tin vein", "ore", 86, 104, 3 }, { "tin vein", "ore", 102, 102, 3 },
    { "tin vein", "ore", 118, 108, 3 }, { "tin vein", "ore", 134, 104, 3 }, { "tin vein", "ore", 150, 110, 3 },
    { "iron deposit", "ore", 160, 35, 2 }, { "iron deposit", "ore", 168, 42, 2 }, { "iron deposit", "ore", 172, 34, 2 },
    { "iron deposit", "ore", 163, 46, 2 }, { "gold vein", "ore", 120, 60, 1 }, { "silver vein", "ore", 185, 90, 2 },
    { "peacebloom", "herbs", 20, 80, 5 }, { "peacebloom", "herbs", 30, 110, 5 }, { "peacebloom", "herbs", 55, 70, 5 },
    { "peacebloom", "herbs", 95, 30, 5 }, { "peacebloom", "herbs", 140, 25, 5 }, { "peacebloom", "herbs", 190, 125, 5 },
    { "peacebloom", "herbs", 25, 125, 5 }, { "silverleaf", "herbs", 60, 120, 5 }, { "silverleaf", "herbs", 110, 80, 5 },
    { "silverleaf", "herbs", 130, 50, 5 }, { "silverleaf", "herbs", 80, 55, 5 }, { "earthroot", "herbs", 200, 60, 4 },
    { "earthroot", "herbs", 15, 60, 4 },
}
local function WorldPreview(step, above)
    local C = ns.Collecting
    local frame = New("Frame", step)
    frame:SetSize(WORLD_W, WORLD_H)
    frame:SetPoint("TOP", above, "BOTTOM", 0, -26)
    frame.back = frame:CreateTexture(nil, "BACKGROUND")
    frame.back:SetAllPoints()
    frame.back:SetColorTexture(0.24, 0.2, 0.13, 1)
    frame.ground = frame:CreateTexture(nil, "BORDER")
    frame.ground:SetAllPoints()
    local files = C_Map.GetMapArtLayerTextures(WORLD_MAP, 1)
    if type(files) == "table" and files[WORLD_TILE] then
        frame.ground:SetTexture(files[WORLD_TILE])
        frame.ground:SetTexCoord(0, 1, 0, WORLD_H / WORLD_W)
    end
    -- The explored parts, each tile cut to the part of it in view.
    local k = WORLD_W / WORLD_ART -- (preview pixels an art pixel)
    local x1, y1 = 2 * WORLD_ART, WORLD_ART + WORLD_H / k
    frame.overlays = {}
    for _, part in ipairs(WORLD_OVERLAYS) do
        local wide, tall = math.ceil(part[1] / WORLD_ART), math.ceil(part[2] / WORLD_ART)
        for row = 1, tall do
            local high = row < tall and WORLD_ART or (part[2] - (tall - 1) * WORLD_ART)
            local fileHigh = WORLD_ART
            if row == tall then
                fileHigh = 16
                while fileHigh < high do fileHigh = fileHigh * 2 end
            end
            for col = 1, wide do
                local across = col < wide and WORLD_ART or (part[1] - (wide - 1) * WORLD_ART)
                local fileWide = WORLD_ART
                if col == wide then
                    fileWide = 16
                    while fileWide < across do fileWide = fileWide * 2 end
                end
                local left, top = part[3] + (col - 1) * WORLD_ART, part[4] + (row - 1) * WORLD_ART
                local l, t = math.max(left, WORLD_ART), math.max(top, WORLD_ART)
                local r, b = math.min(left + across, x1), math.min(top + high, y1)
                if r > l and b > t then
                    local tile = frame:CreateTexture(nil, "BORDER", nil, 1)
                    tile:SetTexture(part[5][(row - 1) * wide + col], nil, nil, "TRILINEAR")
                    tile:SetTexCoord((l - left) / fileWide, (r - left) / fileWide, (t - top) / fileHigh, (b - top) / fileHigh)
                    tile:SetSize((r - l) * k, (b - t) * k)
                    tile:SetPoint("TOPLEFT", frame, "TOPLEFT", (l - WORLD_ART) * k, -(t - WORLD_ART) * k)
                    frame.overlays[#frame.overlays + 1] = tile
                end
            end
        end
    end
    frame.edges = {}
    for i, side in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 2 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 2 }, { "TOPLEFT", "BOTTOMLEFT", 2, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", 2, 0 } }) do
        local edge = frame:CreateTexture(nil, "OVERLAY")
        edge:SetColorTexture(0.55, 0.45, 0.22, 1)
        edge:SetPoint(side[1])
        edge:SetPoint(side[2])
        if side[3] > 0 then edge:SetWidth(side[3]) else edge:SetHeight(side[4]) end
        frame.edges[i] = edge
    end
    frame.title = Label(step, "World map, zoomed out", "GameFontNormalSmall")
    frame.title:SetPoint("BOTTOM", frame, "TOP", 0, 5)
    -- The spawns as a map's places, and a symbol for each (never more show: areas take some in).
    frame.symbols, frame.own, frame.levels = {}, {}, {}
    for i, sample in ipairs(WORLD_SAMPLES) do
        local key = sample[1]
        frame.own[key] = frame.own[key] or {}
        table.insert(frame.own[key], math.floor(sample[3] / WORLD_W * C.UNITS + 0.5) * C.PACK + math.floor(sample[4] / WORLD_H * C.UNITS + 0.5))
        frame.levels[key] = sample[5]
        frame.symbols[i] = C.NewSymbol(frame)
    end
    return frame
end
-- The minimap preview with the extras and the world map one under it, right of the widest row of
-- tiles (setup's maps step, the Symbols page).
local function MapPreviews(parent, y)
    local preview = PreviewGround(parent, RIGHT + 100, y)
    preview.glows, preview.extras, preview.areaDots = {}, true, {}
    for _, sample in ipairs(AREA_SAMPLES) do
        if not sample.empty then Coin(preview).sample = sample end
    end
    Coin(preview).sample = MAP_EXTRAS.shared
    parent.areaPreview, parent.worldPreview = preview, WorldPreview(parent, preview)
end
local function RefreshWorldPreview(frame)
    ns.Collecting.Regions.Preview(frame, frame.own, frame.levels, WORLD_YARDS, WORLD_YARDS * WORLD_H / WORLD_W, frame:GetFrameLevel() + 3)
end

local function ShowSetup(setup, step)
    setup.step = step
    setup:Show()
    ns.RefreshSparkleWindow()
end

local function CloseSetup(setup)
    ns.db.collectSetupDone = true
    setup:Hide()
    ns.RefreshSparkleWindow()
end

-- Where the marks come from: Collecting's own, every known spawn, or both.
local SOURCES = { { true, false }, { false, true }, { true, true } }
-- When: the second step's cards, in order.
local FILTERS = { "collectOnlyProfession", "collectOnlyTracking", "collectHideGray" }
local function PickSources(i)
    Set("collect", SOURCES[i][1])
    Set("collectSpawns", SOURCES[i][2])
end

local function BuildSetup(page)
    local setup = New("Frame", page)
    setup:SetAllPoints()
    setup:Hide()
    setup.steps, setup.step = {}, 1
    page.setup = setup
    Dots(setup)
    setup.heading = Label(setup, "", "GameFontNormalHuge")
    setup.heading:SetPoint("TOP", 0, -78)

    local step = Step(setup)
    Card(step, "Places I gather", "NodeSight remembers each herb and ore you pick.", { { HERB }, { ORE } },
        "Remembers each place you gather a herb or ore and marks it, from now on.", function() PickSources(1) end)
    Card(step, "Every known spawn", "Every known herb and ore spawn, built in.", { { NOTE } },
        "Marks every known herb and ore spawn in Forever, whether or not you've been there.", function() PickSources(2) end)
    Card(step, "Both", "The known spawns and yours, marked once each.", { { HERB }, { NOTE } },
        "Your own places and every known spawn. A place in both is marked once.", function() PickSources(3) end)
    step.sources = true
    step.note = Label(step, "A known spawn is where a herb or ore can grow, not one that's up now: near you, the game's yellow dot shows that.",
        "GameFontDisableSmall")
    step.note:SetPoint("TOPLEFT", step.cards[1], "BOTTOMLEFT", 0, -22)
    step.note:SetWidth(2 * WIDE)
    step.note:SetJustifyH("LEFT")

    step = Step(setup)
    local finder = C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(2383)
    Card(step, "Only my professions", "Herbs with Herbalism, ore with Mining.", { { HERB }, { ORE } },
        "Herbs are marked only on characters with Herbalism, ore only with Mining.", function() Set(FILTERS[1], not ns.db[FILTERS[1]]) end)
    Card(step, "Only while tracking", "While Find Herbs or Find Minerals is on.", { { finder or HERB } },
        "Herbs are marked only while Find Herbs is on, ore only while Find Minerals is on. With the Herb/Ore Switch on, both are.",
        function() Set(FILTERS[2], not ns.db[FILTERS[2]]) end)
    Card(step, "Only skill-ups", "Herbs and ore that still raise your skill.", { { HERB, gray = true }, { ORE, gray = true } },
        "Leaves out herbs and ore that no longer give you a skill-up (gray in your profession window).",
        function() Set(FILTERS[3], not ns.db[FILTERS[3]]) end)
    step.showOn = Label(step, "Show them on", "GameFontNormal")
    step.showOn:SetPoint("TOPLEFT", step.cards[1], "BOTTOMLEFT", 0, -30)
    local map = SmallBox(step, "collectMap", "World map", "A symbol on the world map for each marked place. Put your mouse on one to see what it was.")
    map:SetPoint("LEFT", step.showOn, "LEFT", 130, 0)
    local mini = SmallBox(step, "collectMinimap", "Minimap", "The same symbols on the minimap for the places near you. They let the mouse through to the game's own dots.")
    mini:SetPoint("LEFT", map, "LEFT", 140, 0)

    NodeStep(setup, "herbs")
    NodeStep(setup, "ore")

    step = Step(setup)
    MapRows(step.column)
    MapPreviews(step, CONTENT - 4)

    setup.skip = Button(setup, "Skip setup", 110, function() CloseSetup(setup) end)
    setup.skip:SetPoint("BOTTOMLEFT", LEFT, 40) -- (clear of the window's version line)
    setup.next = Button(setup, NEXT, 100, function()
        if setup.step >= #setup.steps then return CloseSetup(setup) end
        ShowSetup(setup, setup.step + 1)
    end)
    setup.next:SetPoint("BOTTOMRIGHT", -16, 40)
    setup.back = Button(setup, BACK, 100, function() ShowSetup(setup, math.max(1, setup.step - 1)) end)
    setup.back:SetPoint("RIGHT", setup.next, "LEFT", -6, 0)

    -- The page's own button to go through it again, and the first time it opens.
    page.setupButton = Button(page, "Set up", 96, function() ShowSetup(setup, 1) end)
    page.setupButton:SetPoint("TOPRIGHT", -16, -12)
    Tooltip(page.setupButton, "Set up", "Goes through Collecting's setup again: where the marks come from, when they show, which herbs and ore, the look and the areas.")
    page:HookScript("OnShow", function()
        if not ns.db.collectSetupDone and not setup:IsShown() then
            setup.step = 1
            setup:Show()
        end
    end)
end

local function BuildGeneral(page) Page(page, GENERAL, GeneralColumns) end
local function BuildFarm(page) Page(page, "Where to farm", FarmColumns) end
local function BuildCollect(page)
    Page(page, "General", CollectColumns)
    page.parts[#page.parts + 1] = page.future -- (hidden with the page's rows while the setup shows)
    page.parts[#page.parts + 1] = page.thanks
    BuildSetup(page)
end
local function BuildSymbols(page)
    Page(page, "Symbols", SymbolColumns)
    MapPreviews(page, -60)
end
-- Everything on the Compass and arrow page but its on and off boxes, back to the defaults.
local COMPASS_RESET = { "compassX", "compassY", "compassWidth", "compassRange", "nodeArrowX", "nodeArrowY", "nodeArrowRange", "nodeArrowSize" }
local function BuildCompass(page)
    Page(page, "Compass and arrow", CompassColumns)
    page.reset = Button(page, DEFAULTS, 96, function()
        for _, key in ipairs(COMPASS_RESET) do ns.db[key] = ns.defaults[key] end
        ns.CompassChanged()
        ns.ArrowChanged()
        ns.RefreshSparkleWindow()
    end)
    page.reset:SetPoint("TOPRIGHT", -16, -12)
    Tooltip(page.reset, DEFAULTS, "Puts the compass bar and the arrow back where they started, at their first sizes and ranges.")
end

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
    if part.needs then
        local on = part.needs() and true or false
        if part.usable ~= on then
            part.usable = on
            part.label:SetFontObject(on and "GameFontNormal" or "GameFontDisable")
            part:SetEnabled(on)
        end
    end
    if part.kind == "box" then
        local db = ns.db
        if key == "own" then
            part:SetChecked(ns.OwnSettings())
        elseif key == "collecting" then
            part:SetChecked(ns.CollectingOn())
        else
            part:SetChecked(db[key] == true)
        end
    elseif part.kind == "slider" then
        part:SetValue(ns.db[key])
    elseif part.kind == "choices" then
        for _, tile in ipairs(part.tiles) do
            local on = ns.db[key] == tile.value
            tile.border:SetAtlas(on and "PetList-ButtonSelect" or "PetList-ButtonBackground")
            tile.text:SetFontObject(on and "GameFontHighlightSmall" or "GameFontNormalSmall")
        end
    end
end

local function RefreshSetup(setup)
    for i, step in ipairs(setup.steps) do step:SetShown(i == setup.step) end
    local step, info, db = setup.steps[setup.step], SETUP_STEPS[setup.step], ns.db
    setup.heading:SetText(info[2])
    LightDots(setup)
    setup.back:SetEnabled(setup.step > 1)
    setup.next:SetText(setup.step == #setup.steps and DONE or NEXT)
    for _, part in ipairs(step.column) do RefreshPart(part) end
    for _, box in ipairs(step.small or {}) do RefreshPart(box) end
    for _, box in ipairs(step.boxes or {}) do box:SetChecked(not db.collectHidden[box.entry]) end
    for i, card in ipairs(step.cards) do
        if step.sources then
            LightCard(card, db.collect == SOURCES[i][1] and db.collectSpawns == SOURCES[i][2])
        else
            LightCard(card, db[FILTERS[i]] == true)
        end
    end
    if step.areaPreview then RefreshAreaPreview(step.areaPreview) end
    if step.worldPreview then RefreshWorldPreview(step.worldPreview) end
    Stack(step.column)
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
    if page.farm then
        local zones = ns.Collecting.FarmZones()
        FillFarm(page.farm.herbs, zones.herbs, "herbs")
        FillFarm(page.farm.ore, zones.ore, "ore")
    end
    -- Collecting's setup in place of the page while it shows.
    local inSetup = page.setup ~= nil and page.setup:IsShown()
    if page.setup then
        for _, part in ipairs(page.parts) do part:SetShown(not inSetup) end
        page.about:SetShown(not inSetup)
        page.title:SetShown(not inSetup)
        page.setupButton:SetShown(not inSetup)
        if inSetup then RefreshSetup(page.setup) end
    end
    if page.count then
        local all, herbs, ore = ns.NodeCount()
        page.count:SetText(("%d herbs, %d ore"):format(herbs, ore))
        page.forget:SetEnabled(all > 0)
        page.noGatherMate:SetShown(not inSetup and not ns.GatherMateLoaded())
    end
    if page.worldPreview then RefreshWorldPreview(page.worldPreview) end
    if page.areaPreview then RefreshAreaPreview(page.areaPreview) end
    for _, column in ipairs(page.columns) do Stack(column) end
    refreshing = false
end

ns.WINDOW_PAGES = {
    { key = "nodesight", name = GENERAL, build = BuildGeneral, refresh = Refresh },
    { key = "switch", name = "Herb/Ore Switch", build = BuildSwitch, refresh = Refresh },
    { key = "collect", header = "Collecting (Beta)", name = "General", build = BuildCollect, refresh = Refresh },
    { key = "symbols", name = "Symbols", build = BuildSymbols, refresh = Refresh },
    { key = "compass", name = "Compass and arrow", build = BuildCompass, refresh = Refresh },
    { key = "farm", name = "Where to farm", build = BuildFarm, refresh = Refresh },
}
ns.WindowSet = Set -- what the page's controls do, by key

function ns.ShowSettingsWindow() ns.ShowSparkleWindow("nodesight") end
-- Collecting's page with its setup from the first step, also for one who went through it before.
function ns.ShowCollectSetup()
    ns.ShowSparkleWindow("collect")
    for _, entry in ipairs(ns.WINDOW_PAGES) do
        if entry.key == "collect" and entry.page.setup and ns.SparkleWindowPage() == "collect" then ShowSetup(entry.page.setup, 1) end
    end
end
-- The window is open on NodeSight's own page.
function ns.SettingsWindowShown() return ns.SparkleWindowShown() and ns.SparkleWindowPage() == "nodesight" end
function ns.HideSettingsWindow() ns.HideSparkleWindow() end
function ns.RefreshSettingsWindow() ns.RefreshSparkleWindow() end
