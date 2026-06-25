FieldManagerExtension = {}

function FieldManagerExtension.harvestField(self, superFunc, field)
    g_asyncTaskManager:addTask(function()
        local cropRotation = g_cropRotation
        local historyStateManager = cropRotation.historyStateManager
        local fallowStateManager = cropRotation.fallowStateManager
        local catchCropManager = cropRotation.catchCropManager

        local fieldState = field:getFieldState()
        local state = fieldState.fruitTypeIndex
        historyStateManager:updateStatesForField(state, field)
        fallowStateManager:resetFallowStateForField(field)
        catchCropManager:resetCatchCropForField(field)
    end)

    local returnValue = superFunc(self, field)
    return returnValue
end

FieldManager.harvestField = Utils.overwrittenFunction(FieldManager.harvestField, FieldManagerExtension.harvestField)

function FieldManagerExtension.sowField(self, superFunc, field, fruitTypeIndex)
    g_asyncTaskManager:addTask(function()
        local cropRotation = g_cropRotation
        local fallowStateManager = g_cropRotation.fallowStateManager
        local catchCropManager = g_cropRotation.catchCropManager
        local catchCropIndex = cropRotation:catchCropIndexByFruitIndex(fruitTypeIndex)

        fallowStateManager:resetFallowStateForField(field)

        if catchCropIndex ~= nil then
            catchCropManager:setCatchCropForField(field, catchCropIndex)
        end
    end)

    local returnValue = superFunc(self, field, fruitTypeIndex)
    return returnValue
end

FieldManager.sowField = Utils.overwrittenFunction(FieldManager.sowField, FieldManagerExtension.sowField)