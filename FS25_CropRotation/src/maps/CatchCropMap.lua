CatchCropMap = {
    MOD_NAME = g_currentModName
}

local CatchCropMap_mt = Class(CatchCropMap, CropRotationMap)

function CatchCropMap.new(cropRotationModule, customMt)
    local self = CropRotationMap.new(cropRotationModule, customMt or CatchCropMap_mt)
	self.filename = "catchCropMap.grle"
	self.name = "CatchCropMap"
	self.id = "CR_CATCH_CROP_MAP"
    self.cache = {}
	return self
end

function CatchCropMap:initialize()
    CatchCropMap:superClass().initialize(self)
end

function CatchCropMap:delete()
	CatchCropMap:superClass().delete(self)
end

function CatchCropMap:loadFromXML(xmlFile, key, baseDirectory, configFileName, mapFilename, mapSize)
	CatchCropMap:superClass().loadFromXML(self, xmlFile, key, baseDirectory, configFileName, mapFilename, mapSize)
	key = key .. ".catchCropMap"
	self.numChannels = getXMLInt(xmlFile, key .. "#numChannels")
	self.maxValue = 2 ^ self.numChannels - 1
    self.firstChannel = 0

	local bitVectorMap, newBitVectorMap = self:loadSavedBitVectorMap(self.name, self.filename, self.numChannels, mapSize)
    self.bitVectorMap = bitVectorMap
    self.newBitVectorMap = newBitVectorMap
	self:addBitVectorMapToSync(self.bitVectorMap)
	self:addBitVectorMapToSave(self.bitVectorMap, self.filename)
	self:addBitVectorMapToDelete(self.bitVectorMap)

    return true
end

function CatchCropMap:initTerrain(mission, terrainId, filename)
	CatchCropMap:superClass().initTerrain(self, mission, terrainId, filename)
end

function CatchCropMap:update(dt)
	CatchCropMap:superClass().update(self, dt)
end

function CatchCropMap:getModifier()
    if self.modifier == nil then
        self.modifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels, g_terrainNode)
        self.modifier:setPolygonRoundingMode(DensityRoundingMode.INCLUSIVE)
    end

    return self.modifier
end

function CatchCropMap:getFilter()
    if self.filter == nil then
        local modifier = self:getModifier()
		self.filter = DensityMapFilter.new(modifier)
    end

    return self.filter
end

function CatchCropMap:setState(state, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, fruitFilter, harvestFilter)
    local modifier = self:getModifier()
    self:setParallelogrammToModifier(modifier, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
	modifier:executeSet(state, fruitFilter, harvestFilter)
end

function CatchCropMap:updateCatchCropStateForField(field, state)
    local modifier = self:getModifier()
    field:getDensityMapPolygon():applyToModifier(modifier)
    modifier:executeSet(state)
end

function CatchCropMap:getCatchCropState(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, fruitFilter, harvestFilter)
    local modifier = self:getModifier()
    local filter = self:getFilter()
    local possibleCatchCropStates = g_cropRotation:getPossibleCatchCropStates()
    self:setParallelogrammToModifier(modifier, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
    return self:getStateAtArea(modifier, filter, fruitFilter, harvestFilter, possibleCatchCropStates, self.cache)
end