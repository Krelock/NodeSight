-- NodeSight's What's New dialog (the patch notes) and its notices.
--
-- Sections: After the fight, What's new (and the notice), Collecting news.

local ADDON_NAME, ns = ...

local ipairs = ipairs

---------------------------------------------------------------------------
-- After the fight
---------------------------------------------------------------------------
-- Popups wait for the end of a fight, so none covers the screen in one. One of each name
-- waits (the newest). None with Popups off.
local waiting = {}
-- The saved settings in use, also before they load (the restart notice); nil without any.
local function Saved()
    local db = ns.db
    if not db or db == ns.defaults then
        db = type(NodeSightCharDB) == "table" and NodeSightCharDB.own ~= false and NodeSightCharDB or NodeSightDB
    end
    return type(db) == "table" and db or nil
end
local function PopupsOff()
    local db = Saved()
    return db ~= nil and db.popups == false
end
-- A popup's "Don't show this again": Popups off.
function ns.NoMorePopups()
    local db = Saved()
    if db then db.popups = false end
end
local fightEnd = CreateFrame("Frame")
fightEnd:SetScript("OnEvent", function()
    fightEnd:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local due = waiting
    waiting = {}
    if PopupsOff() then return end
    for _, show in pairs(due) do pcall(show) end
end)
function ns.AfterFight(name, show)
    if PopupsOff() then return end
    if not InCombatLockdown() then return show() end
    waiting[name] = show
    fightEnd:RegisterEvent("PLAYER_REGEN_ENABLED")
end

---------------------------------------------------------------------------
-- What's new
---------------------------------------------------------------------------
-- Newest version first (older versions' notes can be added below it); one without a version uses the .toc's.
local ShowWhatsNew, ShowNotice
do
    local WHATS_NEW = {
        { version = "4.0.4",
            { "New", {
                { "Glow around the node.", "Off by default. A soft glow around the node in the sparkles' first color, under any style. Turn it on for each kind in the sparkle window, under Count" },
                { "Pause while falling.", "On by default. The Herb/Ore Switch doesn't switch while you're jumping or falling. On Herb/Ore Switch, under Pauses" },
                { "Thank you page.", "A thanks to our supporter, with a Buy me a coffee link, at the bottom of the settings list" },
            } },
        },
        { version = "4.0.3.4",
            { "New", {
                { "Collecting (Beta), much bigger.", "Off by default. Every herb and ore spawn is built in and marked on your world map and minimap, with a map button to hide them, filters and a quick setup. Turn it on in General, on Collecting (Beta) or with Ctrl Left Click on the minimap button" },
                { "Compass bar and next node arrow.", "Off by default. Find the herbs and ore around you from the top of the screen. On Collecting (Beta) > Compass and arrow" },
                { "Where to farm.", "The best zones for skill-ups, on Collecting (Beta) > Where to farm" },
                { "GatherMate2 support.", "Off by default. Shows GatherMate2's herbs and ore with NodeSight's symbols. On Collecting (Beta) > General" },
                { "Sparkle Maker (Beta).", "Make your own sparkles from Blizzard's effects, in the sparkle window" },
                { "Caves: nearest only.", "On by default. In a cave the minimap shows only the 5 nearest spawns, so a mine's tunnels and levels don't pile up. On Collecting (Beta) > General" },
            } },
            { "Changes", {
                { "Cleaner settings.", "Each setting shows once, with live previews" },
                { "Interact Key off in towns.", "Off by default again, and turned off once for everyone, so the Interact Key works in towns as before. You can turn it on in Sparkle settings" },
                { "New Collecting look.", "If you tried Collecting before, its symbols move to the new look once. It stays on or off as you had it" },
                { "Herbs grouped too.", "Close spawns of one herb now show as one symbol with a count, like mines" },
                { "Own icons only.", "The symbols' Picture setting is gone: each herb and ore always shows its own icon" },
                { "Lighter.", "Collecting's minimap symbols and the compass use far less CPU and memory" },
                { "Out of the way near you.", "A minimap symbol fades out as you get within 20 yards of it, where you can see the node itself" },
            } },
            { "Fixes", {
                { "Interact Key pop-up at login.", "Blizzard's tip asking you to assign an Interact Key binding no longer shows every time you log in while sparkles are on. Sparkles don't need a key" },
            } },
        },
        { version = "3.2.3",
            { "Fixes", {
                { "Fighting with Angleur and other addons.", "NodeSight no longer sets interact settings back right away when another addon or Options changes them, so it stops fighting fishing addons like Angleur and the \"Something keeps turning off SoftTargetInteractRange\" popup is gone. It sets them again at the next loading screen, as before 3.2.1" },
                { "Interact range.", "A range of 15 or more set by another addon is now left as it is. Sparkles only show within 15 yards anyway" },
            } },
        },
        { version = "3.2.1",
            { "New", {
                { "Collecting (Beta).", "Off by default. NodeSight remembers each place you gather a herb or ore and marks it on your world map and minimap with the node's own icon. Pick the symbols' picture, shape, size, minimap opacity and skill colors on the new Collecting (Beta) page, where you turn it on with Remember where I gather and Forget all clears them. Thanks to Urfoks for Collecting" },
                { "Show when Cultivation is ready.", "Off by default. For Tauren: the Cultivation icon over a herb you can cultivate right now. Works without herb sparkles and without Herbalism. Tick it on Sparkle settings. Thanks to tester617" },
                { "Why sparkles aren't showing.", "The sparkle window now says when something keeps sparkles away: waiting for a fight to end, in a town, Hide in combat or Hide in instances, no Herbalism, Mining or Skinning with Only for my professions on, or a setting that keeps being turned off. When one of your settings is the reason, click the warning to go to it, and it flashes" },
            } },
            { "Changes", {
                { "Interact settings put back.", "If Options or another addon changes a setting sparkles need, NodeSight sets it back right away instead of at the next loading screen. If it keeps being changed, NodeSight leaves it and tells you" },
                { "Interact Key off in towns (Beta).", "Moved from the General page to Sparkle settings, next to the other sparkle settings" },
                { "Logo.", "The NodeSight logo now sits in the settings window's own bronze ring" },
                { "Checkboxes.", "Now right of their names, lined up with the sliders and dropdowns" },
                { "Performance improvements.", "" },
            } },
            { "Fixes", {
                { "No sparkles with Only for my professions.", "The game has a second skill line for Herbalism, Mining and Skinning, and NodeSight only checked the first, so it could think you didn't have the profession. It checks both now" },
            } },
        },
        { version = "3.1.0",
            { "New", {
                { "Settings window.", "All of NodeSight's settings are now in one window with the sparkles: General and Herb/Ore Switch at the top of the list, then each kind of sparkle and Sparkle settings. Left Click the minimap button to open it, or NodeSight settings in Options > AddOns. Drag it by any empty part to move it" },
                { "Lootable corpses.", "Off by default. Corpses that still have loot sparkle, so you don't walk past them. Tick Lootable corpses in the settings window's list" },
                { "Interact Key off in towns (Beta).", "Off by default. Turns the Interact Key off in towns and inns so it doesn't pick the NPCs there. Nothing sparkles in town then. Turn it on under Towns on the General page" },
                { "Stone background.", "Off by default. Blizzard's stone texture behind the settings window, warmed to NodeSight's brown. On the General page" },
                { "Examples in the preview.", "On Sparkle settings, ticking Rare nodes stand out, Dimmer out of reach or Gray when your skill is too low shows it on the preview for a few seconds" },
            } },
            { "Changes", {
                { "Keep the game's icons.", "Now under the preview on each kind's page, and the preview shows the game's icon over the node while it's on" },
                { "Skinning.", "No longer Beta" },
                { "The preview.", "Shows no sparkles while that kind is off" },
                { "Herb and ore tooltips.", "In your bags, \"Gathered with ...\" is on the Crafting Reagent line instead of under the vendor and auction prices" },
            } },
            { "Fixes", {
                { "Options error in combat.", "Opening a dropdown in Blizzard's Options during a fight could be blocked with an error naming NodeSight. NodeSight's settings are no longer in Options, so this can't happen" },
            } },
        },
        { version = "3.0.2",
            { "Changes", {
                { "Minimap button tooltip.", "Spaced into groups, and Shift Right Click now says Herb/Ore Switch" },
                { "Shift Left Click on the minimap button.", "Says in chat where NodeSight's settings are (Options > AddOns > NodeSight) instead of opening them. With the gamepad UI on, Left Click says where the sparkle settings are" },
                { "Hiding the minimap button.", "Ctrl Shift Left Click no longer hides it; untick Minimap button in NodeSight's settings or the sparkle window's General tab" },
                { "Herb/Ore Switch page.", "The Switch page in Options is now called Herb/Ore Switch" },
            } },
            { "Fixes", {
                { "Edit Mode error.", "After opening NodeSight's settings from the minimap button, opening Edit Mode could fill your error log (\"tainted by NodeSight\") until a reload. The button no longer opens Options" },
            } },
        },
        { version = "3.0.1",
            { "New", {
                { "Settings for this character only and Minimap button.", "In the sparkle window's General tab, at the top right" },
                { "Hide the minimap button.", "With Ctrl Shift Left Click on it. Minimap button turns it back on" },
            } },
            { "Changes", {
                { "Settings for this character only.", "Now offers a reload when you change it, so the switch happens right away" },
                { "Sparkles page.", "Opening it in Options no longer opens the sparkle window; its Sparkle window button does" },
            } },
        },
        { version = "3.0.0",
            { "New", {
                { "Minimap button.", "On by default. Left Click opens the sparkle settings, Shift Left Click NodeSight's settings, Right Click turns all sparkles on or off, Shift Right Click turns switching on or off. Turn it off with Minimap button on NodeSight's settings page" },
                { "Skill on herb and ore items.", "Herbs and ore in your bags show the skill they're gathered with, like \"Gathered with Mining (65)\", in the same colors as the node's tooltip. It goes with Required skill in tooltips" },
                { "NodeSight's logo.", "In the addon list" },
            } },
            { "Changes", {
                { "Minimap features removed.", "Blizzard's latest update patched out every way for addons to read the nodes on the minimap. Scanning, the symbols, far sparkles, the arrow, the sounds, the minimap tooltip's skill line, Switch's Pause near a herb or ore, the Advanced page and the bug report are gone" },
                { "Sparkle settings.", "All on the Sparkles page and in the sparkle window, like NodeSight Sparkles. Only for my professions is on the window's General tab" },
                { "Size of the game's own dots.", "Removed. If you had changed it, the game's own size comes back" },
            } },
        },
    }
    -- No parent in CreateFrame (see NewSparkles in Sparkles.lua).
    local function NewFrame(kind, parent)
        local frame = CreateFrame(kind)
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
    local dialog = { page = 1 } -- the dialog's frames and current page
    local WIDTHS = { 480, 720, 960 } -- tried in turn until the notes fit on the screen
    -- Shows a version's notes, sizing the dialog to fit.
    function dialog.ShowPage()
        local notes = WHATS_NEW[dialog.page]
        local lines = { NORMAL_FONT_COLOR:WrapTextInColorCode(("NodeSight %s"):format(
            notes.version or C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version"))) }
        for _, section in ipairs(notes) do
            lines[#lines + 1] = "\n" .. NORMAL_FONT_COLOR:WrapTextInColorCode(section[1])
            for _, item in ipairs(section[2]) do
                if type(item) == "table" then item = NORMAL_FONT_COLOR:WrapTextInColorCode(item[1]) .. " " .. item[2] end
                lines[#lines + 1] = "- " .. item
            end
        end
        local frame, text = dialog.frame, dialog.text
        text:SetText(table.concat(lines, "\n"))
        for _, width in ipairs(WIDTHS) do
            frame:SetWidth(width)
            text:SetWidth(width - 40)
            if text:GetStringHeight() + 73 <= UIParent:GetHeight() - 145 then break end -- the dialog's top is 135 below the screen's
        end
        frame:SetHeight(text:GetStringHeight() + 73)
        dialog.older:SetEnabled(dialog.page < #WHATS_NEW)
        dialog.newer:SetEnabled(dialog.page > 1)
    end
    -- Page arrows: 1 = older, -1 = newer.
    function dialog.Turn(by)
        if not WHATS_NEW[dialog.page + by] then return end
        dialog.page = dialog.page + by
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        dialog.ShowPage()
    end
    function ShowWhatsNew()
        if not dialog.frame then
            local frame = NewFrame("Frame", UIParent)
            frame:SetFrameStrata("FULLSCREEN_DIALOG") -- (over the settings window, whose button opens it)
            frame:SetToplevel(true)
            frame:EnableMouse(true)
            frame:SetPoint("TOP", UIParent, "TOP", 0, -135)
            local background = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
            background:SetAtlas("UI-DialogBox-Background-Dark", true)
            background:SetPoint("TOPLEFT", 7, -7)
            background:SetPoint("BOTTOMRIGHT", -7, 7)
            local edge = frame:CreateTexture(nil, "BACKGROUND", nil, -4)
            edge:SetAtlas("UI-DiamondDialogBox-Border", true)
            edge:SetAllPoints()
            local text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            text:SetPoint("TOP", 0, -20)
            text:SetJustifyH("LEFT")
            text:SetSpacing(3)
            text:SetIndentedWordWrap(true) -- indent wrapped lines
            -- Blizzard's page arrows, top right: right = older, left = newer.
            local function ArrowButton(way, by)
                local button = NewFrame("Button", frame)
                button:SetSize(32, 32)
                button:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. way .. "Page-Up")
                button:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. way .. "Page-Down")
                button:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. way .. "Page-Disabled")
                button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
                button:SetScript("OnClick", function() dialog.Turn(by) end)
                return button
            end
            dialog.frame, dialog.text = frame, text
            dialog.older = ArrowButton("Next", 1)
            dialog.older:SetPoint("TOPRIGHT", -14, -10)
            dialog.newer = ArrowButton("Prev", -1)
            dialog.newer:SetPoint("RIGHT", dialog.older, "LEFT", 0, 0)
            DialogButton(frame, OKAY, function() frame:Hide() end):SetPoint("BOTTOM", 0, 16)
        end
        dialog.page = 1 -- open on the newest
        dialog.ShowPage()
        dialog.frame:Show()
    end

    -- Notice: one message in the same look, with an OK button.
    local notice
    local function Show(title, body, once, action)
        if not notice then
            notice = NewFrame("Frame", UIParent)
            notice:SetFrameStrata("FULLSCREEN_DIALOG")
            notice:SetToplevel(true)
            notice:EnableMouse(true)
            notice:SetPoint("TOP", UIParent, "TOP", 0, -135)
            notice:SetWidth(WIDTHS[1])
            local background = notice:CreateTexture(nil, "BACKGROUND", nil, -7)
            background:SetAtlas("UI-DialogBox-Background-Dark", true)
            background:SetPoint("TOPLEFT", 7, -7)
            background:SetPoint("BOTTOMRIGHT", -7, 7)
            local edge = notice:CreateTexture(nil, "BACKGROUND", nil, -4)
            edge:SetAtlas("UI-DiamondDialogBox-Border", true)
            edge:SetAllPoints()
            notice.text = notice:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            notice.text:SetPoint("TOP", 0, -20)
            notice.text:SetWidth(WIDTHS[1] - 40)
            notice.text:SetJustifyH("LEFT")
            notice.text:SetSpacing(3)
            notice.okay = DialogButton(notice, OKAY, function() notice:Hide() end)
            notice.never = DialogButton(notice, CONFIRM_POPUP_DONT_SHOW_AGAIN, function()
                ns.NoMorePopups()
                notice:Hide()
            end)
            notice.never:SetWidth(math.max(128, notice.never:GetTextWidth() + 24))
            notice.never:SetPoint("BOTTOMLEFT", notice, "BOTTOM", 6, 16)
            notice.action = DialogButton(notice, "", nil)
            notice.action:SetPoint("BOTTOMRIGHT", notice, "BOTTOM", -6, 16)
        end
        -- A message shown only once has no use for "Don't show this again"; one with its own
        -- button (only those) has it left of Okay.
        notice.okay:ClearAllPoints()
        if action then
            notice.okay:SetPoint("BOTTOMLEFT", notice, "BOTTOM", 6, 16)
        elseif once then
            notice.okay:SetPoint("BOTTOM", 0, 16)
        else
            notice.okay:SetPoint("BOTTOMRIGHT", notice, "BOTTOM", -6, 16)
        end
        notice.never:SetShown(not once)
        notice.action:SetShown(action ~= nil)
        if action then
            notice.action:SetText(action[1])
            notice.action:SetScript("OnClick", function()
                notice:Hide()
                action[2]()
            end)
        end
        notice.text:SetText(NORMAL_FONT_COLOR:WrapTextInColorCode(title) .. "\n\n" .. body)
        notice:SetHeight(notice.text:GetStringHeight() + 73)
        notice:Show()
    end
    function ShowNotice(title, body, once, action)
        ns.AfterFight("notice", function() Show(title, body, once, action) end)
    end
end

ns.ShowWhatsNew, ns.ShowNotice = ShowWhatsNew, ShowNotice

---------------------------------------------------------------------------
-- Collecting news
---------------------------------------------------------------------------
-- Collecting is off until a player turns it on, and its marks aren't live: told once per account.
local COLLECT_NEWS = RED_FONT_COLOR:WrapTextInColorCode("NodeSight can't see live herbs and ore anymore: Blizzard's update "
    .. "blocked addons from reading the minimap.")
    .. "\n\nNew: Collecting (Beta) shows every spot a herb or ore can spawn on your world map and minimap. They're spawn "
    .. "points, so a node may already be picked."
local COLLECT_ON = "\n\n%s on NodeSight's General page or with Ctrl Left Click on the minimap button."
    .. "\n\nYour sparkles work as before."

function ns.ShowCollectNews()
    if ns.OptionsOnly() then return ShowNotice("NodeSight", COLLECT_NEWS .. COLLECT_ON:format("Turn it on any time"), true) end
    ShowNotice("NodeSight", COLLECT_NEWS .. COLLECT_ON:format("Click Set up to try it, or turn it on any time"), true,
        { "Set up", function() ns.ShowCollectSetup() end })
end
