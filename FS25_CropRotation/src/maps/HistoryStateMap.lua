HistoryStateMap = {
    MOD_NAME = g_currentModName
}

local HistoryStateMap_mt = Class(HistoryStateMap, CropRotationMap)

function HistoryStateMap.new(cropRotationModule, index, customMt)
    local self = CropRotationMap.new(cropRotationModule, customMt or HistoryStateMap_mt)
	self.filename = "historyStateMap-"..index..".grle"
	self.name = "HistoryStateMap-"..index
	self.id = "CR_HISTORY_STATE_MAP_"..index
    self.cache = {}
	return self
end

function HistoryStateMap:initialize()
    HistoryStateMap:superClass().initialize(self)
end

function HistoryStateMap:delete()
	HistoryStateMap:superClass().delete(self)
end

function HistoryStateMap:loadFromXML(xmlFile, key, baseDirectory, configFileName, mapFilename, mapSize, numChannels)
	HistoryStateMap:superClass().loadFromXML(self, xmlFile, key, baseDirectory, configFileName, mapFilename, mapSize)

	local bitVectorMap, newBitVectorMap = self:loadSavedBitVectorMap(self.name, self.filename, self.numChannels, mapSize)
    self.bitVectorMap = bitVectorMap
    self.newBitVectorMap = newBitVectorMap
	self:addBitVectorMapToSync(self.bitVectorMap)
	self:addBitVectorMapToSave(self.bitVectorMap, self.filename)
	self:addBitVectorMapToDelete(self.bitVectorMap)

    return true
end

function HistoryStateMap:initTerrain(mission, terrainId, filename)
	HistoryStateMap:superClass().initTerrain(self, mission, terrainId, filename)
end

function HistoryStateMap:update(dt)
	HistoryStateMap:superClass().update(self, dt)
end

function HistoryStateMap:updateFruitCoverAreaForField(field, fruitType)
    local modifier = self:getDynamicModifier()
    field:getDensityMapPolygon():applyToModifier(modifier)
    modifier:executeSet(fruitType)
end

function HistoryStateMap:getStateAtPos(x, y)
    return self:getState(x, y, self.firstChannel, self.numChannels)
end

function HistoryStateMap:getStateTitleAtWorldPos(x, y)
    local value = self:getState(x, y, self.firstChannel, self.numChannels)

    if value == CropRotation.FALLOW_STATE then
        return g_i18n:getText("fallow_state")
    else
        local fruitTypeManager = g_fruitTypeManager
        local fruitType = fruitTypeManager:getFruitTypeByIndex(value)
        if fruitType ~= nil then
            return fruitType.fillType.title
        end
    end

    return nil
end

function HistoryStateMap:moveFruitIfNeeded(stateIndex, modifier, fallowFilter, fruitFilter)
    self:addAsyncTask(function()
        fruitFilter:setValueCompareParams(DensityValueCompareType.EQUAL, stateIndex)
        modifier:executeSet(stateIndex, fallowFilter, fruitFilter)
    end, "Move state with index: "..stateIndex)
end

function HistoryStateMap:getDynamicModifier()
    if self.dynamicModifier == nil then
        self.dynamicModifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels, g_terrainNode)
        self.dynamicModifier:setPolygonRoundingMode(DensityRoundingMode.INCLUSIVE)
    end

    return self.dynamicModifier
end

function HistoryStateMap:getStaticModifier()
    if self.staticModifier == nil then
        self.staticModifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels, g_terrainNode)
        self.staticModifier:setPolygonRoundingMode(DensityRoundingMode.INCLUSIVE)
    end

    return self.staticModifier
end

function HistoryStateMap:getStateFilter()
    if self.stateFilter == nil then
        self.stateFilter = DensityMapFilter.new(self.bitVectorMap, 0, self.numChannels)
    end

    return self.stateFilter
end

function HistoryStateMap:getHistoryState(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, fruitFilter, harvestStateFilter)
    local modifier = self:getDynamicModifier()
    local filter = self:getStateFilter()
    local possibleStates = g_cropRotation:getPossibleCropStates()
    self:setParallelogrammToModifier(modifier, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
    return self:getStateAtArea(modifier, filter, fruitFilter, harvestStateFilter, possibleStates, self.cache)
end