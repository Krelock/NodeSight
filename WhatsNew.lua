-- NodeSight's What's New dialog (the patch notes).

local ADDON_NAME, ns = ...

local ipairs = ipairs

---------------------------------------------------------------------------
-- What's new
---------------------------------------------------------------------------
-- Newest version first; one without a version uses the .toc's.
local ShowWhatsNew
do
    local WHATS_NEW = {
        {
            { "New", {
                { "Leylines for Skyborne.", "Leylines on your minimap get a symbol the way herbs and ore get theirs, while Read Leyline is ready. For High Order Skyborne; turn on or off in NodeSight's settings" },
            } },
        },
        { version = "1.3.0",
            { "New", {
                { "Sparkles on far away herbs and ore (Beta) (off by default).", "Sparkles on the herb or ore you are facing, and on up to four more, from as far away as your minimap shows them. This does not work perfectly: on hills the sparkles can be above or below the herb, and it uses a lot more CPU than with it off. It will be improved in further updates. While it is on it uses the game's map pin and In-Game Navigation, in place of your own map pin and tracked quest. Turn it on under Beta, with Sparkles on herbs or Sparkles on ore on" },
                { "Rare beasts on the minimap (Beta) (on by default).", "For hunters. Track Beasts shows every beast as the same dot: with this on, a rare beast's dot gets a rare symbol (three to pick from), and the arrow, if you have it on, points to the nearest one. It needs Track Beasts on, and can be turned off under Beta. It knows the rare beasts by their English names" },
                { "Gray symbols in caves.", "A herb or ore in a cave has a gray symbol." },
                { "Sound when something new shows up (off by default).", "Plays a sound when a new herb, ore, chest or rare beast shows up on your minimap. Turn it on in NodeSight's settings" },
                { "Key binding for the symbols (no key set by default).", "Turns the herb and ore symbols on the minimap on and off with a key" },
            } },
            { "Changes", {
                "Switch between herbs and ore and Yards between switches are out of Beta and on NodeSight's own page",
                "The settings are sorted into pages. The basics are on NodeSight's own page, and Symbols, Sparkles and Beta have pages of their own under it",
                "What's New has arrows now: the right one shows the notes of the version before",
                "Small performance improvements",
            } },
        },
        { version = "1.2.0",
            { "New", {
                { "Switch between herbs and ore (Beta) (off by default).", "NodeSight turns on Find Herbs and Find Minerals on and off as you move so you find both without switching yourself. The symbols of the one that is off stay on your minimap, so you see herbs and ore together. You need both Find Herbs and Find Minerals, with one of them turned on, and it never switches in combat. Turn it on under Arrow and minimap. Thank you W8kingNightmare for the amazing suggestion" },
                { "Treasure chests for dwarves (Beta)", "With Find Treasure on, the chests on your minimap get a chest symbol the way herbs and ore get theirs, and the arrow points to the nearest one" },
                { "You can move the arrow now!", "Drag the arrow to put it where you want it" },
            } },
            { "Changes", {
                "While you stand still, NodeSight scans the minimap less and less",
                "With Sparkles on other objects on, mailboxes and things you only use, like chairs and doors no longer sparkle. Chests and quest objects still do",
            } },
            { "Fixes", {
                "The arrow no longer points to a herb or ore you don't have the skill for. It goes to the nearest one you can gather, and there is no arrow when you can't gather anything in sight.",
                "Minor fixes to the scanning logic",
                "NodeSight now only scans the minimap while Find Herbs, Find Minerals or Find Treasure is on. A character with none would still be scanning the minimap before",
                "Opening the game's Options no longer gives an error from NodeSight",
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
        frame:SetWidth(480)
        text:SetWidth(440)
        text:SetText(table.concat(lines, "\n"))
        if text:GetStringHeight() + 73 > UIParent:GetHeight() - 145 then -- the dialog's top is 135 below the screen's
            frame:SetWidth(720)
            text:SetWidth(680)
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
            frame:SetFrameStrata("DIALOG")
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
end

ns.ShowWhatsNew = ShowWhatsNew
