YieldCalculator = {}

local YieldCalculator_mt = Class(YieldCalculator)

function YieldCalculator.new(cropRotation, customMt)
	local self = setmetatable({}, customMt or YieldCalculator_mt)

    self.cropRotation = cropRotation

    return self
end

function YieldCalculator:potentialYieldAtPosition(x, y, cropIndex)
    local historyStateManager = self.cropRotation.historyStateManager
    local catchCropManager = self.cropRotation.catchCropManager
    local positionHistoryStates = {}

    for _, historyState in pairs(historyStateManager.historyStates) do
        local state = historyState.map:getState(x, y, historyState.map.firstChannel, historyState.map.numChannels)
        table.insert(positionHistoryStates, state)
    end

    local catchCropIndex = catchCropManager.catchCropMap:getState(x, y, catchCropManager.catchCropMap.firstChannel, catchCropManager.catchCropMap.numChannels)
    local yield = self:getYieldMultiplier(positionHistoryStates, cropIndex, catchCropIndex)
    return yield
end

function YieldCalculator:getYieldMultiplier(historyStates, currentCropIndex, catchCropIndex)
    local multiplier = 1.0

    if #historyStates == 0 then
        return multiplier
    end

    local crop = self.cropRotation:cropByFruitTypeIndex(currentCropIndex)

    if crop == nil then
        return multiplier
    end

    local monocultureMultiplier = self:calculateMonocultureMultiplier(currentCropIndex, historyStates, crop.breakPeriods)
    local breakPeriodsMultiplier = self:calculateBreakPeriodsMultiplier(currentCropIndex, crop.breakPeriods, historyStates)
    local foreCropsMultiplier = self:calculateForeCropsMultiplier(historyStates, crop)
    local fallowMultiplier = self:calculateFallowMultiplier(historyStates)
    local catchCropMultiplier = self:calculateCatchCropMultiplier(currentCropIndex, catchCropIndex)

    multiplier = multiplier + monocultureMultiplier + breakPeriodsMultiplier + foreCropsMultiplier + fallowMultiplier + catchCropMultiplier

    return multiplier
end

function YieldCalculator:calculateFallowMultiplier(historyStates)
    local fallowMultiplier = 0

    for _, state in pairs(historyStates) do
        if state == CropRotation.FALLOW_STATE then
            fallowMultiplier = fallowMultiplier + self.cropRotation.settings.fallowStateBonus
        end
    end

    return fallowMultiplier
end

function YieldCalculator:calculateForeCropsMultiplier(historyStates, crop)
    local foreCropsMultiplier = 0.0
    local fruitTypeManager = g_fruitTypeManager

    for index, historyState in pairs(historyStates) do
        local fruitType = fruitTypeManager:getFruitTypeByIndex(historyState)

        if fruitType == nil then
            continue
        end

        local fruitTypeIndex = fruitType.index

        if table.hasElement(crop.veryGoodCrops, fruitTypeIndex) and self.cropRotation.settings.foreCropsVeryGoodBonuses[index] ~= nil then
            foreCropsMultiplier = foreCropsMultiplier + self.cropRotation.settings.foreCropsVeryGoodBonuses[index]
        end

        if table.hasElement(crop.goodCrops, fruitTypeIndex) and self.cropRotation.settings.foreCropsGoodBonuses[index] ~= nil then
            foreCropsMultiplier = foreCropsMultiplier + self.cropRotation.settings.foreCropsGoodBonuses[index]
        end

        if table.hasElement(crop.badCrops, fruitTypeIndex) and self.cropRotation.settings.foreCropsPenalties[index] ~= nil then
            foreCropsMultiplier = foreCropsMultiplier + self.cropRotation.settings.foreCropsPenalties[index]
        end
    end

    return foreCropsMultiplier
end

function YieldCalculator:calculateMonocultureMultiplier(currentCropIndex, historyStates, breakPeriods)
    if breakPeriods == 0 then
        return 0.0
    end

    local monocultureMultiplier = self.cropRotation.settings.monoculturePenalty
    for _, historyState in pairs(historyStates) do
        if historyState ~= currentCropIndex then
            monocultureMultiplier = 0.0
        end
    end
    return monocultureMultiplier
end

function YieldCalculator:calculateBreakPeriodsMultiplier(currentCropIndex, breakPeriods, historyStates)
    local multiplier = 0.0
    for i=1, CropRotation.NUM_HISTORY_MAPS do
        local historyState = historyStates[i]
        if (i - 1) < breakPeriods and currentCropIndex == historyState then
            multiplier = multiplier + self.cropRotation.settings.breakPeriodsPenalty
        end
    end

    return multiplier
end

function YieldCalculator:calculateCatchCropMultiplier(currentCropIndex, catchCropIndex)
    local multiplier = 0.0
    local catchCrop = self.cropRotation:catchCropByCatchCropIndex(catchCropIndex)

    if catchCrop == nil then
        return multiplier
    end

    local fruitTypeManager = g_fruitTypeManager
    local fruitType = fruitTypeManager:getFruitTypeByIndex(currentCropIndex)
    local fruitTypeIndex = fruitType.index

    if table.hasElement(catchCrop.veryGoodCrops, fruitTypeIndex) then
        multiplier = self.cropRotation.settings.veryGoodCatchCropBonus
    end

    if table.hasElement(catchCrop.goodCrops, fruitTypeIndex) then
        multiplier = self.cropRotation.settings.goodCatchCropBonus
    end

    if table.hasElement(catchCrop.badCrops, fruitTypeIndex) then
        multiplier = self.cropRotation.settings.badCatchCropPenalty
    end

    return multiplier
end