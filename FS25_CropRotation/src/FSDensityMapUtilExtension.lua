FSDensityMapUtilExtension = {
    cutAreaModifier = {},
    fruitFilters = {}
}

function FSDensityMapUtilExtension.getCutAreaModifier(fruitIndex, fruitDesc)
    if FSDensityMapUtilExtension.cutAreaModifier[fruitIndex] == nil then
        FSDensityMapUtilExtension.cutAreaModifier[fruitIndex] = DensityMapModifier.new(fruitDesc.terrainDataPlaneId, fruitDesc.startStateChannel, fruitDesc.numStateChannels, g_terrainNode)
    end

    return FSDensityMapUtilExtension.cutAreaModifier[fruitIndex]
end

function FSDensityMapUtilExtension.cutFruitArea(fruitIndex, superFunc, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, destroySpray, useMinForageState, excludedSprayType, setsWeeds, limitToField)
    local farmlandId = g_farmlandManager:getFarmlandAtWorldPosition(0.5 * (widthWorldX + heightWorldX), 0.5 * (widthWorldZ + heightWorldZ))
    if g_missionManager:getIsMissionRunningOnFarmland(farmlandId) then
        return superFunc(fruitIndex, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, destroySpray, useMinForageState, excludedSprayType, setsWeeds, limitToField)
    end

    local desc = g_fruitTypeManager:getFruitTypeByIndex(fruitIndex)

    if desc.terrainDataPlaneId == nil then
        return superFunc(fruitIndex, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, destroySpray, useMinForageState, excludedSprayType, setsWeeds, limitToField)
    end

    local fruitFilter = nil

    local fruitFilters = FSDensityMapUtilExtension.fruitFilters
    if fruitFilters ~= nil then
        fruitFilter = fruitFilters[fruitIndex]
    end

    if fruitFilter == nil then
        fruitFilter = DensityMapFilter.new(desc.terrainDataPlaneId, desc.startStateChannel, desc.numStateChannels, g_terrainNode)
        fruitFilters[fruitIndex] = fruitFilter
    end

    local minState
    if useMinForageState then
        minState = desc.minForageGrowthState
    else
        minState = desc.minHarvestingGrowthState
    end

    fruitFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, minState, desc.maxHarvestingGrowthState)

    local cropRotation = g_cropRotation
    local historyStateManager = cropRotation.historyStateManager
    local fallowStateManager = cropRotation.fallowStateManager
    local yieldCalculator = cropRotation.yieldCalculator
    local catchCropManager = cropRotation.catchCropManager

    local cutAreaModifier = FSDensityMapUtilExtension.getCutAreaModifier(fruitIndex, desc)
	cutAreaModifier:setParallelogramWorldCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)
    local cutSum, cutArea, cutTotalArea = cutAreaModifier:executeGet(fruitFilter)
    local yieldMultiplier = 1.0

    if cutArea > 0 then
        local catchCropState = catchCropManager.catchCropMap:getCatchCropState(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, fruitFilter, harvestStateFilter)
        catchCropManager.catchCropMap:setState(0, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, fruitFilter, harvestStateFilter)
        local historyStates = historyStateManager:getHistoryStates(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, fruitFilter, harvestStateFilter)

        historyStateManager:updateStates(fruitIndex, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, fruitFilter, harvestStateFilter)
        fallowStateManager.fallowStateMap:setState(0, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, fruitFilter, harvestStateFilter)

        yieldMultiplier = yieldCalculator:getYieldMultiplier(historyStates, fruitIndex, catchCropState)

        Logging.devInfo("Ertrag: "..yieldMultiplier.." : "..cutArea)
    end

    local realArea, area, sprayFactor, plowFactor, limeFactor, weedFactor, stubbleFactor, rollerFactor, beeFactor, growthState, maxArea, terrainDetailPixelsSum = superFunc(fruitIndex, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, destroySpray, useMinForageState, excludedSprayType, setsWeeds, limitToField)
    return realArea * yieldMultiplier, area, sprayFactor, plowFactor, limeFactor, weedFactor, stubbleFactor, rollerFactor, beeFactor, growthState, maxArea, terrainDetailPixelsSum
end

FSDensityMapUtil.cutFruitArea = Utils.overwrittenFunction(FSDensityMapUtil.cutFruitArea, FSDensityMapUtilExtension.cutFruitArea)

function FSDensityMapUtilExtension.updateCropRotationForSowingArea(fruitIndex, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
    local cropRotation = g_cropRotation
    local fallowStateManager = g_cropRotation.fallowStateManager
    local catchCropManager = g_cropRotation.catchCropManager
    local catchCropIndex = cropRotation:catchCropIndexByFruitIndex(fruitIndex)

    fallowStateManager.fallowStateMap:setState(0, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)

    if catchCropIndex ~= nil then
        catchCropManager.catchCropMap:setState(catchCropIndex, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
    end
end

function FSDensityMapUtilExtension.updateSowingArea(fruitIndex, superFunc, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, ...)
    FSDensityMapUtilExtension.updateCropRotationForSowingArea(fruitIndex, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
    return superFunc(fruitIndex, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, ...)
end

FSDensityMapUtil.updateSowingArea = Utils.overwrittenFunction(FSDensityMapUtil.updateSowingArea, FSDensityMapUtilExtension.updateSowingArea)

function FSDensityMapUtilExtension.updateDirectSowingArea(fruitIndex, superFunc, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, ...)
    FSDensityMapUtilExtension.updateCropRotationForSowingArea(fruitIndex, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
    return superFunc(fruitIndex, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, ...)
end

FSDensityMapUtil.updateDirectSowingArea = Utils.overwrittenFunction(FSDensityMapUtil.updateDirectSowingArea, FSDensityMapUtilExtension.updateDirectSowingArea)