FallowStateManager = {}

local FallowStateManager_mt = Class(FallowStateManager)

function FallowStateManager.new(cropRotation, customMt)
	local self = setmetatable({}, customMt or FallowStateManager_mt)

    self.cropRotation = cropRotation
    self.increaseFallowStateFilters = {}
    self.historyStateModifier = {}

    return self
end

function FallowStateManager:getFieldFilter()
    local fieldFilter = self.fieldFilter

    if fieldFilter == nil then
        local fieldGroundSystem = g_currentMission.fieldGroundSystem
        local groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels = fieldGroundSystem:getDensityMapData(FieldDensityMap.GROUND_TYPE)
        self.fieldFilter = DensityMapFilter.new(groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels)
        self.fieldFilter:setValueCompareParams(DensityValueCompareType.GREATER, 0)
        fieldFilter = self.fieldFilter
    end

    return fieldFilter
end

function FallowStateManager:increaseFallow()
    local cropRotation = g_cropRotation
    local fallowModifier = self.fallowStateMap:getWorldModifier()
    local fieldFilter = self:getFieldFilter()

    g_asyncTaskManager:addSubtask(function()
        fallowModifier:executeAdd(1, fieldFilter)
	end, "Increase fallow state")

    for index, crop in cropRotation.ignoreFallowCrops do
        local fruitType = crop.fruitType
        local fruitFilter = self.increaseFallowStateFilters[fruitType.index]
        if fruitFilter == nil then
            fruitFilter = DensityMapFilter.new(fruitType.terrainDataPlaneId, fruitType.startStateChannel, fruitType.numStateChannels)
            fruitFilter:setValueCompareParams(DensityValueCompareType.NOTEQUAL, 0)
            self.increaseFallowStateFilters[fruitType.index] = fruitFilter
        end

        g_asyncTaskManager:addSubtask(function()
            fallowModifier:executeSet(0, fieldFilter, fruitFilter)
        end, "Reset for ignore fallow crop index: "..index)
    end
end

function FallowStateManager:setFallowStateIfNeeded()
    local multiModifier = self.fallowStateMultiModifier
    if multiModifier == nil then
        self:initFallowStateUpdateModifier()
        multiModifier = self.fallowStateMultiModifier
    end

    g_asyncTaskManager:addSubtask(function()
        local terrainSize = g_currentMission.terrainSize
        multiModifier:updateParallelogramWorldCoords(-(terrainSize/2), -(terrainSize/2), terrainSize, -terrainSize, -terrainSize, terrainSize, DensityCoordType.POINT_POINT_POINT)
        multiModifier:resetStats()
        multiModifier:execute()
    end, "Set fallow state to history if needed")
end

function FallowStateManager:initFallowStateUpdateModifier()
    local fallowFilter = self.fallowStateMap:getMaxFilter()
    local historyStates = self.cropRotation.historyStateManager.historyStates
    local fieldFilter = self:getFieldFilter()

    self.fallowStateMultiModifier = DensityMapMultiModifier.new()
    local multiModifier = self.fallowStateMultiModifier

    for i=1, #historyStates - 1, 1 do
        local currentState = historyStates[i]
        local nextState = historyStates[i + 1]
        local nextModifier = nextState.map:getStaticModifier()
        local currentFruitFilter = currentState.map:getStateFilter()
        local possibleStates = self.cropRotation:getPossibleCropStates()

        for _, state in pairs(possibleStates) do
            currentFruitFilter:setValueCompareParams(DensityValueCompareType.EQUAL, state.cropIndex)
            multiModifier:addExecuteSet(state.cropIndex, nextModifier, fallowFilter, currentFruitFilter)
        end
    end

    local lastState = historyStates[1]
    local modifier = lastState.map:getStaticModifier()
    multiModifier:addExecuteSet(0, modifier, fieldFilter, fallowFilter)
end

function FallowStateManager:resetFallowStateIfNeeded()
    g_asyncTaskManager:addSubtask(function()
        local fallowModifier = self.fallowStateMap:getWorldModifier()
        local fallowFilter = self.fallowStateMap:getMaxFilter()
        local fieldFilter = self:getFieldFilter()
        fallowModifier:executeSet(0, fieldFilter, fallowFilter)
    end, "Reset fallow state if max reached")
end

function FallowStateManager:resetFallowStateForField(field)
    g_asyncTaskManager:addSubtask(function()
        local fallowModifier = self.fallowStateMap:getModifier()
        field:getDensityMapPolygon():applyToModifier(fallowModifier)
        fallowModifier:executeSet(0)
    end, "Reset fallow state for field "..field:getId())
end