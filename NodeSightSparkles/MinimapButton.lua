-- NodeSight Sparkles' minimap button (LibDBIcon, from Libs): left click opens the sparkle
-- window (the Options page with the gamepad UI on, or after the window failed to open),
-- right click turns every kind of sparkle on or off. Its place is saved per character.

local _, ns = ...

local ipairs = ipairs

local NAME = "NodeSightSparkles"
local ICON = "Interface\\AddOns\\NodeSightSparkles\\logo"

local function AllOn()
    for _, kind in ipairs(ns.KINDS) do
        if not ns.db[kind] then return false end
    end
    return true
end

-- Every kind on, or every kind off when they all are.
local function ToggleAll()
    local on = not AllOn()
    for _, kind in ipairs(ns.KINDS) do ns.db[kind] = on end
    ns.UpdateAll()
    ns.Setup()
    ns.RefreshSparkleWindow()
end

local function Clicked(_, button)
    if button == "RightButton" then return ToggleAll() end
    if ns.OptionsOnly() then
        if ns.settingsCategory then Settings.OpenToCategory(ns.settingsCategory:GetID()) end
    elseif ns.SparkleWindowShown() then
        ns.HideSparkleWindow()
    else
        ns.ShowSparkleWindow()
    end
end

local function Tooltip(tooltip)
    tooltip:AddLine("NodeSight Sparkles")
    tooltip:AddLine("<Left Click to Open the Sparkle Settings>", GREEN_FONT_COLOR:GetRGB())
    tooltip:AddLine(AllOn() and "<Right Click to Turn Sparkles Off>" or "<Right Click to Turn Sparkles On>", GREEN_FONT_COLOR:GetRGB())
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
