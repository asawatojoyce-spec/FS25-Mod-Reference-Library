PlayerHUDUpdaterExtension = {}

function PlayerHUDUpdaterExtension.addHistoryStateLine(fieldBox, x, y, title, stateTitle)
    if stateTitle ~= nil then
        fieldBox:addLine(title, stateTitle)
    end
end

function PlayerHUDUpdaterExtension.addPotentialYieldLineIfNeeded(fieldBox, x, y, fieldInfo)
    if not PlayerHUDUpdaterExtension.hadPotentialFruit(fieldInfo) then
        return
    end

    local cropRotation = g_cropRotation
    local yieldCalculator = cropRotation.yieldCalculator
    local fruitTypeIndex = fieldInfo.fruitTypeIndex
    local title = g_i18n:getText("ui_potential_yield")
    local yield = yieldCalculator:potentialYieldAtPosition(x, y, fruitTypeIndex)
    fieldBox:addLine(title, string.format("%.0f", yield * 100).."%")
end

function PlayerHUDUpdaterExtension.addCatchCropLine(fieldBox, x, y, fieldInfo)
    if not PlayerHUDUpdaterExtension.hadPotentialFruit(fieldInfo) then
        return
    end

    local cropRotation = g_cropRotation
    local catchCropManager = cropRotation.catchCropManager

    local title = g_i18n:getText("ui_had_catch_crop")
    local value = g_i18n:getText("ui_no_catch_crop")
    local catchCropIndex = catchCropManager.catchCropMap:getState(x, y, catchCropManager.catchCropMap.firstChannel, catchCropManager.catchCropMap.numChannels)
    local fruitType = cropRotation:fruitTypeByCatchCropIndex(catchCropIndex)
    if fruitType ~= nil then
        value = fruitType.fillType.title
    end
    fieldBox:addLine(title, value)
end

function PlayerHUDUpdaterExtension.hadPotentialFruit(fieldInfo)
    local fruitTypeIndex = fieldInfo.fruitTypeIndex
	local fruitType = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)
	local growthState = fieldInfo.growthState

    if fruitTypeIndex == nil then
        return false
    elseif fruitTypeIndex == 0 then
        return false
    elseif fruitType:getIsCut(growthState) or fruitType:getIsWithered(growthState) then
        return false
    end

    return true
end

function PlayerHUDUpdaterExtension.showFieldInfo(self, superFunc, x, y, z, rotY)
    superFunc(self, x, y, z, rotY)
    local fieldInfo = self.fieldInfo
    local historyStateManager = g_cropRotation.historyStateManager
    if fieldInfo.groundType ~= FieldGroundType.NONE then
        for _, historyState in pairs(historyStateManager.historyStates) do
            local stateTitle = historyState.map:getStateTitleAtWorldPos(x, y)
            PlayerHUDUpdaterExtension.addHistoryStateLine(self.fieldBox, x, y, historyState.title, stateTitle)
        end

        PlayerHUDUpdaterExtension.addPotentialYieldLineIfNeeded(self.fieldBox, x, y, fieldInfo)
        PlayerHUDUpdaterExtension.addCatchCropLine(self.fieldBox, x, y, fieldInfo)
    end
end

PlayerHUDUpdater.showFieldInfo = Utils.overwrittenFunction(PlayerHUDUpdater.showFieldInfo, PlayerHUDUpdaterExtension.showFieldInfo)