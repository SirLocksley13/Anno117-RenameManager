local Consumer = {
    target = nil
}

function Consumer:SetTarget(target)
    self.target = target
    return self.target ~= nil
end

function Consumer:Handle(slot)
    local target = self.target
    if target == nil then
        return false
    end

    if target.IsReportOpen == nil or not target:IsReportOpen() then
        return false
    end

    slot = tonumber(slot)

    if slot == 0 then
        return target:BackToMenu()
    end

    if slot == nil or slot < 1 or slot > 9 then
        return false
    end

    return target:ParchmentShortcut(slot)
end

return Consumer
