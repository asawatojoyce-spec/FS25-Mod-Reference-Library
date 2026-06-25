FallowStateMap = {
    MOD_NAME = g_currentModName
}

local FallowStateMap_mt = Class(FallowStateMap, CropRotationMap)

function FallowStateMap.new(cropRotationModule, customMt)
    local self = CropRotationMap.new(cropRotationModule, customMt or FallowStateMap_mt)
	self.filename = "fallowStateMap.grle"
	self.name = "FallowStateMap"
	self.id = "CR_FALLOW_STATE_MAP"
	return self
end

function FallowStateMap:initialize()
    FallowStateMap:superClass().initialize(self)
end

function FallowStateMap:delete()
	FallowStateMap:superClass().delete(self)
end

function FallowStateMap:loadFromXML(xmlFile, key, baseDirectory, configFileName, mapFilename, mapSize)
	FallowStateMap:superClass().loadFromXML(self, xmlFile, key, baseDirectory, configFileName, mapFilename, mapSize)
	key = key .. ".fallowStateMap"
	self.numChannels = getXMLInt(xmlFile, key .. "#numChannels")
	self.maxValue = 2 ^ self.numChannels - 1
    self.firstChannel = 0

	self.maxFallowState = getXMLInt(xmlFile, key .. "#maxFallowState")

	local bitVectorMap, newBitVectorMap = self:loadSavedBitVectorMap(self.name, self.filename, self.numChannels, mapSize)
    self.bitVectorMap = bitVectorMap
    self.newBitVectorMap = newBitVectorMap
	self:addBitVectorMapToSync(self.bitVectorMap)
	self:addBitVectorMapToSave(self.bitVectorMap, self.filename)
	self:addBitVectorMapToDelete(self.bitVectorMap)

    return true
end

function FallowStateMap:initTerrain(mission, terrainId, filename)
	FallowStateMap:superClass().initTerrain(self, mission, terrainId, filename)
end

function FallowStateMap:update(dt)
	FallowStateMap:superClass().update(self, dt)
end

function FallowStateMap:getWorldModifier()
    if self.worldModifier == nil then
        self.worldModifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels, g_terrainNode)
    end

    return self.worldModifier
end

function FallowStateMap:getModifier()
    if self.modifier == nil then
        self.modifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels, g_terrainNode)
    end

    return self.modifier
end

function FallowStateMap:getFilter()
    if self.filter == nil then
        local modifier = self:getModifier()
		self.filter = DensityMapFilter.new(modifier)
		self.filter:setValueCompareParams(DensityValueCompareType.EQUAL, 0)
    end

    return self.filter
end

function FallowStateMap:getMaxFilter()
    if self.maxStateFilter == nil then
        local modifier = self:getModifier()
		self.maxStateFilter = DensityMapFilter.new(modifier)
		self.maxStateFilter:setValueCompareParams(DensityValueCompareType.GREATER, self.maxFallowState)
    end

    return self.maxStateFilter
end

function FallowStateMap:setState(state, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, fruitFilter, harvestFilter)
    local modifier = self:getModifier()
    self:setParallelogrammToModifier(modifier, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
	modifier:executeSet(state, fruitFilter, harvestFilter)
end