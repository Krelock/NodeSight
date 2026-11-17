-- NodeSight's minimap button (LibDBIcon, from Libs): left click opens NodeSight's window on
-- its settings, Shift left click on the sparkles, right click turns every kind of sparkle
-- on or off, Shift right click switching between herbs and ore. Its place is saved with
-- the settings.
-- It never opens Options: Blizzard opens that window inside the caller's code, so the
-- window manager would run tainted and later break Edit Mode. Our own windows are fine.

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
    tooltip:AddLine(" ")
    Hint(tooltip, "Left Click", "NodeSight Settings")
    if not ns.OptionsOnly() then -- (no window with the gamepad UI: the settings are on pages)
        Hint(tooltip, "Shift Left Click", "Sparkle Settings")
    end
    tooltip:AddLine(" ")
    Hint(tooltip, "Right Click", AllOn() and "Turn Sparkles Off" or "Turn Sparkles On")
    Hint(tooltip, "Shift Right Click", ns.db.switchFinders and "Turn Herb/Ore Switch Off" or "Turn Herb/Ore Switch On")
end

-- The tooltip shown over the button is redrawn after a click changes it.
local function Retooltip(frame)
    local tooltip = shownTooltip
    if not (frame and tooltip and tooltip:IsOwned(frame)) then return end
    tooltip:ClearLines()
    Tooltip(tooltip)
    tooltip:Show()
end

-- Where Options has them (Esc > Options > AddOns).
local SETTINGS_PAGE = "Settings are in Options > AddOns > NodeSight."

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

-- Switch between herbs and ore (Find Herbs and Find Minerals in turn), as its checkbox does.
local function ToggleSwitch()
    ns.db.switchFinders = not ns.db.switchFinders
    ns.SwitchReset()
    ns.UpdateSwitch()
    Say(ns.db.switchFinders and "Herb/Ore Switch turned on." or "Herb/Ore Switch turned off.")
    ns.RefreshSettingsWindow()
end

local function Clicked(frame, button)
    if button == "RightButton" then
        if IsShiftKeyDown() then ToggleSwitch() else ToggleAll() end
        return Retooltip(frame)
    end
    if ns.OptionsOnly() then return Say(SETTINGS_PAGE) end -- the window isn't used (gamepad UI)
    if ns.SparkleWindowShown() then return ns.HideSparkleWindow() end
    if IsShiftKeyDown() then return ns.ShowSparkleWindow("sparkles") end
    ns.ShowSettingsWindow()
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
