CropRotationMap = {
    MOD_NAME = g_currentModName
}

local CropRotationMap_mt = Class(CropRotationMap, ValueMap)

function CropRotationMap.new(cropRotationModule, customMt)
    local self = ValueMap.new(cropRotationModule, customMt or CropRotationMap_mt)
	return self
end

function CropRotationMap:initialize()
    CropRotationMap:superClass().initialize(self)
end

function CropRotationMap:delete()
	CropRotationMap:superClass().delete(self)
end

function CropRotationMap:initTerrain(mission, terrainId, filename)
	CropRotationMap:superClass().initTerrain(self, mission, terrainId, filename)
end

function CropRotationMap:update(dt)
	CropRotationMap:superClass().update(self, dt)
end

function CropRotationMap:loadFromXML(xmlFile, key, baseDirectory, configFileName, mapFilename, mapSize)
    self.mapSize = mapSize
end

function CropRotationMap:setParallelogrammToModifier(modifier, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
    modifier:setParallelogramWorldCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)
end

function CropRotationMap:getState(x, y, firstChannel, numChannels)
	local xPos = MathUtil.round((x + g_currentMission.terrainSize * 0.5) / g_currentMission.terrainSize * self.mapSize + 0.5) - 1
	local yPos = MathUtil.round((y + g_currentMission.terrainSize * 0.5) / g_currentMission.terrainSize * self.mapSize + 0.5) - 1
    return getBitVectorMapPoint(self.bitVectorMap, xPos, yPos, firstChannel, numChannels)
end

function CropRotationMap:addAsyncTask(asyncTask, name)
    g_asyncTaskManager:addSubtask(function()
		asyncTask()
	end, name)
end


function CropRotationMap:getStateAtArea(modifier, filter, fruitFilter, harvestStateFilter, possibleStates, cache)
    if cache.stateAtArea == nil then
        cache.stateAtArea = 0
    end

    filter:setValueCompareParams(DensityValueCompareType.EQUAL, cache.stateAtArea)

    local areaSum, area, totalArea = modifier:executeGet(filter, fruitFilter, harvestStateFilter)

    if area >= totalArea * 0.5 then
        return cache.stateAtArea
    else
        local currentState = -1
        local maxArea = 0

        for _, state in pairs(possibleStates) do
            filter:setValueCompareParams(DensityValueCompareType.EQUAL, state.cropIndex)

            areaSum, area, totalArea = modifier:executeGet(filter, fruitFilter, harvestStateFilter)

            if area >= totalArea * 0.5 then
                cache.stateAtArea = state.cropIndex
                return state.cropIndex
            end

            if area > maxArea then
                maxArea = area
                currentState = state.cropIndex
            end
        end

        cache.stateAtArea = currentState
        return currentState
    end
end