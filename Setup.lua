-- NodeSight's setup: a short window, once, that asks how much the scans may interrupt you
-- and what NodeSight should show, then sets those settings. It opens again from the Setup
-- button on the settings page.
--
-- Sections: Choices, Window, Showing it.

local _, ns = ...

local ipairs = ipairs

local function Gold(text) return NORMAL_FONT_COLOR:WrapTextInColorCode(text) end

---------------------------------------------------------------------------
-- Choices
---------------------------------------------------------------------------
-- The settings a scan choice sets: the Scanning page's presets (NodeSight.lua). Keys not in a
-- choice's `set` go back to their defaults.
local SCAN_KEYS, PRESETS = ns.SCAN_KEYS, ns.SCAN_PRESETS

-- How much scans may interrupt you. "Sparkles only" turns Scan the minimap off and leaves the
-- scan settings as they are.
local CHOICES = {
    { name = "Less intrusive (recommended)",
        text = "Scans while you walk, only when your mouse is still, and a scan stops the moment you move it. "
            .. "You'll hardly notice them; symbols update a little less often.",
        set = PRESETS[2] },
    { name = "Balanced",
        text = "NodeSight's standard: a scan every " .. ns.defaults.autoScanYards .. " yards you walk, whatever your mouse is doing.",
        set = PRESETS[1] },
    { name = "Most finds",
        text = "A scan every 5 seconds, also while you stand still and in combat. Symbols are always up to date, "
            .. "and you'll notice the scans the most.",
        set = PRESETS[3] },
    { name = "Sparkles only",
        text = "No minimap scanning: NodeSight never touches your minimap. Herbs and ore near you still sparkle, "
            .. "but there are no symbols, arrow or sound.",
        noScan = true },
}
local RECOMMENDED = 1

-- What NodeSight shows: each box and the settings it turns on or off. scan: needs the scans.
local SHOWS = {
    { name = "Herb and ore symbols on the minimap", keys = { "mapIcons" }, scan = true,
        text = "The herb's or ore's own picture on each minimap dot." },
    { name = "Arrow to the nearest herb or ore", keys = { "arrow" }, scan = true,
        text = "Near the top of the screen, with its name and distance." },
    { name = "Sparkles on herbs and ore near you", keys = { "herbs", "ore" }, sparkles = true,
        text = "Gold sparkles on the ones in front of you." },
    { name = "Sound for new finds", keys = { "sound" }, scan = true,
        text = "A sound when something new shows up on your minimap." },
}

-- Which choice the settings match now, or nil.
local function CurrentChoice()
    for i, choice in ipairs(CHOICES) do
        local same = ns.db.scanMinimap == not choice.noScan
        for _, key in ipairs(choice.noScan and {} or SCAN_KEYS) do
            local want = choice.set[key]
            if want == nil then want = ns.defaults[key] end
            if ns.db[key] ~= want then same = false break end
        end
        if same then return i end
    end
end

-- No choice: the scan settings stay as they are. No shows: what shows stays too.
local function Apply(choiceIndex, shows)
    local db, defaults = ns.db, ns.defaults
    local choice = CHOICES[choiceIndex]
    local changed = {}
    local function Set(key, value)
        if db[key] ~= value then
            db[key] = value
            changed[#changed + 1] = key
        end
    end
    if choice then
        Set("scanMinimap", not choice.noScan)
        for _, key in ipairs(choice.noScan and {} or SCAN_KEYS) do
            local value = choice.set[key]
            if value == nil then value = defaults[key] end
            Set(key, value)
        end
    end
    local sparklesChanged = false
    if shows then
        for i, show in ipairs(SHOWS) do
            if not (show.scan and choice and choice.noScan) then -- (grayed out: left as it was)
                for _, key in ipairs(show.keys) do
                    if (db[key] == true) ~= shows[i] then
                        Set(key, shows[i])
                        if show.sparkles then sparklesChanged = true end
                    end
                end
            end
        end
    end
    ns.UpdateScanner()
    if sparklesChanged then
        ns.UpdateAll()
        if ns.RefreshFarSparkles then ns.RefreshFarSparkles() end
        ns.Setup()
        if ns.RefreshSparkleWindow then pcall(ns.RefreshSparkleWindow) end
    end
    if ns.SettingsChanged then ns.SettingsChanged(changed) end -- (the settings page shows them)
    db.setupDone = true
    ns.Log(("setup: scans %s"):format(choice and choice.name or "unchanged"))
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
-- In the look of NodeSight's other popups (WhatsNew.lua).
local WIDTH = 500
local window -- its frames, built on first use

-- No parent in CreateFrame (see NewSparkles in Sparkles.lua).
local function NewFrame(kind, parent, template)
    local frame = CreateFrame(kind, nil, nil, template)
    frame:SetParent(parent)
    return frame
end

local function DialogButton(parent, text, onClick)
    local button = NewFrame("Button", parent)
    button:SetSize(128, 21) -- StaticPopupButtonTemplate's size
    button:SetNormalTexture("Interface\\Buttons\\UI-DialogBox-Button-Up")
    button:GetNormalTexture():SetTexCoord(0, 1, 0, 0.71875)
    button:SetPushedTexture("Interface\\Buttons\\UI-DialogBox-Button-Down")
    button:GetPushedTexture():SetTexCoord(0, 1, 0, 0.71875)
    button:SetHighlightTexture("Interface\\Buttons\\UI-DialogBox-Button-Highlight", "ADD")
    button:GetHighlightTexture():SetTexCoord(0, 1, 0, 0.71875)
    button:SetNormalFontObject(GameFontNormal)
    button:SetHighlightFontObject(GameFontHighlight)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

-- A line of text at y (negative, from the top); returns y below it, and the line.
local function Text(parent, font, text, x, y, width)
    local line = parent:CreateFontString(nil, "ARTWORK", font)
    line:SetPoint("TOPLEFT", x, y)
    line:SetWidth(width)
    line:SetJustifyH("LEFT")
    line:SetSpacing(2)
    line:SetText(text)
    return y - line:GetStringHeight(), line
end

-- A row you can click anywhere on: a radio button or a check box, its name and what it does.
local function Row(parent, template, name, text, y, onClick)
    local row = NewFrame("Button", parent)
    row:SetPoint("TOPLEFT", 16, y)
    row:SetWidth(WIDTH - 32)
    local light = row:CreateTexture(nil, "HIGHLIGHT")
    light:SetColorTexture(1, 1, 1, 0.06)
    light:SetAllPoints()
    local box = NewFrame("CheckButton", row, template)
    box:SetPoint("TOPLEFT", 4, -3)
    box:EnableMouse(false) -- the row takes the click
    local inner, title = Text(row, "GameFontNormal", name, 32, -5, WIDTH - 80)
    local about
    inner, about = Text(row, "GameFontHighlightSmall", text, 32, inner - 3, WIDTH - 80)
    row:SetHeight(-inner + 6)
    row:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        onClick()
    end)
    row.box, row.title, row.about = box, title, about
    return row, y - row:GetHeight() - 4
end

local function Build()
    local frame = NewFrame("Frame", UIParent)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -135)
    frame:SetWidth(WIDTH)
    local background = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    background:SetAtlas("UI-DialogBox-Background-Dark", true)
    background:SetPoint("TOPLEFT", 7, -7)
    background:SetPoint("BOTTOMRIGHT", -7, 7)
    local edge = frame:CreateTexture(nil, "BACKGROUND", nil, -4)
    edge:SetAtlas("UI-DiamondDialogBox-Border", true)
    edge:SetAllPoints()
    window = { frame = frame, shows = {}, pages = {} }

    -- Page 1: how much scans may interrupt.
    local page = NewFrame("Frame", frame)
    page:SetAllPoints()
    local y = Text(page, "GameFontNormal", "Welcome to NodeSight (1/2)", 20, -20, WIDTH - 40)
    y = Text(page, "GameFontHighlight",
        "To see what each minimap dot is, NodeSight hides your minimap for a moment and reads it. "
            .. "How much may that interrupt you?", 20, y - 8, WIDTH - 40) - 10
    window.radios = {}
    for i, choice in ipairs(CHOICES) do
        local row
        row, y = Row(page, "UIRadioButtonTemplate", choice.name, choice.text, y, function()
            window.choice = i
            for j, other in ipairs(window.radios) do other.box:SetChecked(j == i) end
            if choice.noScan then -- (nothing else would show)
                for k, show in ipairs(SHOWS) do
                    if show.sparkles then window.shows[k] = true end
                end
            end
        end)
        window.radios[i] = row
    end
    page.height = -y + 50
    local skip = DialogButton(page, "Skip", function()
        if window.first then Apply(RECOMMENDED, nil) end
        frame:Hide()
    end)
    skip:SetPoint("BOTTOMRIGHT", page, "BOTTOM", -6, 16)
    skip:SetScript("OnEnter", function()
        GameTooltip:SetOwner(skip, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Skip", NORMAL_FONT_COLOR:GetRGB())
        GameTooltip:AddLine(window.first and ("Uses " .. CHOICES[RECOMMENDED].name .. " and keeps everything else as it is.")
            or "Keeps your settings as they are.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    skip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    DialogButton(page, NEXT, function() window.Show(2) end):SetPoint("BOTTOMLEFT", page, "BOTTOM", 6, 16)
    window.pages[1] = page

    -- Page 2: what NodeSight shows.
    page = NewFrame("Frame", frame)
    page:SetAllPoints()
    y = Text(page, "GameFontNormal", "What should NodeSight show? (2/2)", 20, -20, WIDTH - 40) - 10
    window.boxes = {}
    -- Sparkles only: the boxes that need the scans grayed out and unticked.
    local function Grayed(i)
        local choice = CHOICES[window.choice]
        return SHOWS[i].scan and choice and choice.noScan
    end
    for i, show in ipairs(SHOWS) do
        local row
        row, y = Row(page, "UICheckButtonTemplate", show.name, show.text, y, function()
            if Grayed(i) then return end
            window.shows[i] = not window.shows[i]
            window.boxes[i].box:SetChecked(window.shows[i])
        end)
        window.boxes[i] = row
    end
    y = Text(page, "GameFontHighlightSmall", "You can change all of this later in Options > AddOns > NodeSight, "
        .. "where the " .. Gold("Setup") .. " button opens this window again.", 20, y - 6, WIDTH - 40)
    page.height = -y + 50
    DialogButton(page, BACK, function() window.Show(1) end):SetPoint("BOTTOMRIGHT", page, "BOTTOM", -6, 16)
    DialogButton(page, DONE, function()
        Apply(window.choice, window.shows)
        frame:Hide()
    end):SetPoint("BOTTOMLEFT", page, "BOTTOM", 6, 16)
    window.pages[2] = page

    function window.Show(index)
        for i, other in ipairs(window.pages) do other:SetShown(i == index) end
        frame:SetHeight(window.pages[index].height)
        if index == 2 then
            for i, row in ipairs(window.boxes) do
                local off = Grayed(i)
                row:SetEnabled(not off)
                row.box:SetChecked(not off and window.shows[i])
                row.box:SetEnabled(not off)
                row.title:SetFontObject(off and GameFontDisable or GameFontNormal)
                row.about:SetFontObject(off and GameFontDisableSmall or GameFontHighlightSmall)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Showing it
---------------------------------------------------------------------------
-- Opens the window: a first install on the recommended scans, otherwise on the choice the
-- settings match now (none if they match none: kept as they are).
local function Open(first)
    if not window then Build() end
    window.first = first
    window.choice = first and RECOMMENDED or CurrentChoice()
    for i, row in ipairs(window.radios) do row.box:SetChecked(i == window.choice) end
    for i, show in ipairs(SHOWS) do
        local on = true
        for _, key in ipairs(show.keys) do on = on and ns.db[key] == true end
        window.shows[i] = on
    end
    window.Show(1)
    window.frame:Show()
end

-- Once, after the first loading screen (first: a new install), once a fight is over.
function ns.ShowSetupOnce(first)
    ns.AfterFight("setup", function() Open(first) end)
end

-- From the Setup button: at once.
function ns.ShowSetup() Open(false) end
