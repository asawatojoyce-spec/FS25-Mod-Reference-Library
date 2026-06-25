local index = 0

local function increaseIndex(currentTable)
    for _, value in pairs(currentTable) do
        if (type(value) == "table") then
            increaseIndex(value)
        else
            index = index + 1
        end
    end
end

increaseIndex(MessageType)

MessageType.CROP_ROTATIONS_CHANGED = index