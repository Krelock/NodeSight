-- NodeSight's minimap button (LibDBIcon, from Libs): left click opens the sparkle
-- settings, Shift left click NodeSight's Options page, right click turns every kind of
-- sparkle on or off, Shift right click switching between herbs and ore, Ctrl Shift left
-- click hides the button. Its place is saved with the settings.

local ADDON_NAME, ns = ...

local ipairs = ipairs

local NAME = "NodeSight"
local ICON = "Interface\\AddOns\\NodeSight\\logo"

local function AllOn()
    for _, kind in ipairs(ns.KINDS) do
        if not ns.db[kind] then return false end
    end
    return true
end

local function OpenPage(category)
    if category then Settings.OpenToCategory(category:GetID()) end
end

-- A click and what it does: the click in gold, the action in white.
local function Hint(tooltip, click, action)
    local r, g, b = NORMAL_FONT_COLOR:GetRGB()
    local wr, wg, wb = HIGHLIGHT_FONT_COLOR:GetRGB()
    tooltip:AddDoubleLine(click, action, r, g, b, wr, wg, wb)
end

local shownTooltip -- the tooltip LibDBIcon last filled for the button

local function Tooltip(tooltip)
    shownTooltip = tooltip
    local r, g, b = NORMAL_FONT_COLOR:GetRGB()
    local gr, gg, gb = GRAY_FONT_COLOR:GetRGB()
    tooltip:AddDoubleLine("NodeSight", C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "", r, g, b, gr, gg, gb)
    Hint(tooltip, "Left Click", "Sparkle Settings")
    Hint(tooltip, "Shift Left Click", "NodeSight Settings")
    Hint(tooltip, "Right Click", AllOn() and "Turn Sparkles Off" or "Turn Sparkles On")
    Hint(tooltip, "Shift Right Click", ns.db.switchFinders and "Turn Switching Off" or "Turn Switching On")
    Hint(tooltip, "Ctrl Shift Left Click", "Hide This Button")
end

-- The tooltip shown over the button is redrawn after a click changes it.
local function Retooltip(frame)
    local tooltip = shownTooltip
    if not (frame and tooltip and tooltip:IsOwned(frame)) then return end
    tooltip:ClearLines()
    Tooltip(tooltip)
    tooltip:Show()
end

local function Say(text)
    DEFAULT_CHAT_FRAME:AddMessage(NORMAL_FONT_COLOR:WrapTextInColorCode("NodeSight") .. ": " .. text)
end

-- Every kind on, or every kind off when they all are.
local function ToggleAll()
    local on = not AllOn()
    for _, kind in ipairs(ns.KINDS) do ns.db[kind] = on end
    ns.UpdateAll()
    ns.Setup()
    ns.RefreshSparkleWindow()
    Say(on and "Sparkles turned on." or "Sparkles turned off.")
end

-- Switching between Find Herbs and Find Minerals, as its checkbox does.
local function ToggleSwitch()
    ns.db.switchFinders = not ns.db.switchFinders
    ns.SwitchReset()
    ns.UpdateSwitch()
    Say(ns.db.switchFinders and "Switching between herbs and ore turned on." or "Switching between herbs and ore turned off.")
end

-- As the Minimap button setting turned off (it turns the button back on).
local function HideButton(frame)
    if frame and shownTooltip and shownTooltip:IsOwned(frame) then shownTooltip:Hide() end
    ns.db.minimapButton = false
    ns.MinimapButtonChanged()
    ns.RefreshSparkleWindow()
end

local function Clicked(frame, button)
    if button == "RightButton" then
        if IsShiftKeyDown() then ToggleSwitch() else ToggleAll() end
        return Retooltip(frame)
    end
    if IsControlKeyDown() and IsShiftKeyDown() then return HideButton(frame) end
    if IsShiftKeyDown() then return OpenPage(ns.settingsCategory) end
    -- The sparkle window, or its page where the window isn't used (gamepad UI).
    if ns.OptionsOnly() then
        OpenPage(ns.sparklesCategory)
    elseif ns.SparkleWindowShown() then
        ns.HideSparkleWindow()
    else
        ns.ShowSparkleWindow()
    end
end

local function Icon() return LibStub and LibStub("LibDBIcon-1.0", true) end

-- LibDBIcon centers the logo on the button, but the gold ring's hole sits a little higher
-- (its center is 31% across and 29% down the ring's texture): the logo goes on the hole.
local function CenterLogo(icon)
    local button = icon.GetMinimapButton and icon:GetMinimapButton(NAME)
    if not (button and button.icon and button.border) then return end
    local width, height = button.border:GetSize()
    button.icon:ClearAllPoints()
    button.icon:SetPoint("CENTER", button.border, "TOPLEFT", width * 0.31, -height * 0.29)
end

-- At load, once the saved settings are in use.
function ns.MinimapButton()
    local broker, icon = LibStub and LibStub("LibDataBroker-1.1", true), Icon()
    if not (broker and icon) then return end
    ns.db.minimapIcon.hide = not ns.db.minimapButton
    local object = broker:NewDataObject(NAME, { type = "launcher", text = "NodeSight", icon = ICON,
        OnClick = Clicked, OnTooltipShow = Tooltip })
    if object and not icon:IsRegistered(NAME) then
        icon:Register(NAME, object, ns.db.minimapIcon)
        CenterLogo(icon)
    end
end

-- The Minimap button setting changed.
function ns.MinimapButtonChanged()
    local icon = Icon()
    if not (icon and icon:IsRegistered(NAME)) then return end
    ns.db.minimapIcon.hide = not ns.db.minimapButton
    if ns.db.minimapButton then icon:Show(NAME) else icon:Hide(NAME) end
end
