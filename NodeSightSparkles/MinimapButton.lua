-- NodeSight Sparkles' minimap button (LibDBIcon, from Libs): left click opens the sparkle
-- window (the Options page with the gamepad UI on, or after the window failed to open),
-- right click turns every kind of sparkle on or off, Ctrl Shift left click hides the
-- button. Its place is saved per character.

local ADDON_NAME, ns = ...

local ipairs = ipairs

local NAME = "NodeSightSparkles"
local ICON = "Interface\\AddOns\\NodeSightSparkles\\logo"

local function AllOn()
    for _, kind in ipairs(ns.KINDS) do
        if not ns.db[kind] then return false end
    end
    return true
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
    tooltip:AddDoubleLine("NodeSight Sparkles", C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "", r, g, b, gr, gg, gb)
    Hint(tooltip, "Left Click", "Sparkle Settings")
    Hint(tooltip, "Right Click", AllOn() and "Turn Sparkles Off" or "Turn Sparkles On")
    Hint(tooltip, "Ctrl Shift Left Click", "Hide This Button")
end

local function Owned(frame)
    return frame and shownTooltip and shownTooltip:IsOwned(frame)
end

-- Every kind on, or every kind off when they all are.
local function ToggleAll()
    local on = not AllOn()
    for _, kind in ipairs(ns.KINDS) do ns.db[kind] = on end
    ns.UpdateAll()
    ns.Setup()
    ns.RefreshSparkleWindow()
end

-- As the Minimap button setting turned off (the sparkle window's General tab turns it back on).
local function HideButton(frame)
    if Owned(frame) then shownTooltip:Hide() end
    ns.db.minimapButton = false
    ns.MinimapButtonChanged()
    ns.RefreshSparkleWindow()
end

local function Clicked(frame, button)
    if button == "RightButton" then
        ToggleAll()
        -- The tooltip still shown over the button says the new state.
        if Owned(frame) then
            shownTooltip:ClearLines()
            Tooltip(shownTooltip)
            shownTooltip:Show()
        end
        return
    end
    if IsControlKeyDown() and IsShiftKeyDown() then return HideButton(frame) end
    if ns.OptionsOnly() then
        if ns.settingsCategory then Settings.OpenToCategory(ns.settingsCategory:GetID()) end
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

-- At login, once the saved settings are in use.
function ns.MinimapButton()
    local broker, icon = LibStub and LibStub("LibDataBroker-1.1", true), Icon()
    if not (broker and icon) then return end
    ns.db.minimapIcon.hide = not ns.db.minimapButton
    local object = broker:NewDataObject(NAME, { type = "launcher", text = "NodeSight Sparkles", icon = ICON,
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
