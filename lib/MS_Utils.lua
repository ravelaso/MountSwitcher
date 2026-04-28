local _, MS = ...

function MS:PlayerClass()
    local _, class = UnitClass("player")
    return class
end

function MS:CanFlyHere()
    if not IsFlyableArea() then return false end
    if GetZoneText() == "Dalaran" and GetSubZoneText() ~= "Krasus' Landing" then
        return false
    end
    return true
end
