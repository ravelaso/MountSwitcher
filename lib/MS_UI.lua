local _, MS = ...

-- Store barFrame reference in MS table so other modules can access it
MS.barFrame = CreateFrame("Frame", "MountSwitcherBar", UIParent)
local barFrame = MS.barFrame

barFrame:SetSize(MS.BUTTON_SIZE + 12, MS.BUTTON_SIZE + 12)
barFrame:SetClampedToScreen(true)
barFrame:SetMovable(true)

-- Gold "unlocked" border
local unlockBorder = barFrame:CreateTexture(nil, "OVERLAY")
unlockBorder:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
unlockBorder:SetBlendMode("ADD")
unlockBorder:SetAllPoints(barFrame)
unlockBorder:Hide()

local function SaveBarPosition()
    local point, _, relPoint, x, y = barFrame:GetPoint()
    MountSwitcherDB.BarPosition = { point = point, relPoint = relPoint, x = x, y = y }
end

function MS:RestoreBarPosition()
    barFrame:ClearAllPoints()
    local saved = MountSwitcherDB.BarPosition
    if saved then
        barFrame:SetPoint(saved.point, UIParent, saved.relPoint, saved.x, saved.y)
    else
        barFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 230)
    end
end

local barLocked = true

function MS:SetBarLocked(locked)
    barLocked = locked
    MountSwitcherDB.BarLocked = locked
    if locked then
        barFrame:EnableMouse(false)
        barFrame:RegisterForDrag()
        unlockBorder:Hide()
    else
        barFrame:EnableMouse(true)
        barFrame:RegisterForDrag("LeftButton")
        unlockBorder:Show()
    end
end

barFrame:SetScript("OnDragStart", function(self)
    if not barLocked then self:StartMoving() end
end)
barFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveBarPosition()
end)

MS:Debug("UI module loaded")