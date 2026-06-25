DebugCropRotation = {}

source(g_currentModDirectory.."src/events/DebugCropRotationEvent.lua")

local DebugCropRotation_mt = Class(DebugCropRotation)

function DebugCropRotation.new(cropRotation, customMt)
	local self = setmetatable({}, customMt or DebugCropRotation_mt)

    self.cropRotation = cropRotation

    return self
end

function DebugCropRotation:addConsoleCommands()
    addConsoleCommand("crFallowState", "Get fallow state at position", "commandGetFallowState", self)
    addConsoleCommand("crCatchCropState", "Get catch crop state at position", "commandGetCatchCropState", self)
    addConsoleCommand("crSetStateToField", "Set state to current field", "commandSetStateToCurrentField", self, "historyState; state;")
    addConsoleCommand("crSetCatchCropStateToField", "Set catch crop state to current field", "commandSetCatchCropStateToCurrentField", self, "state;")
    addConsoleCommand("crCropIndexToFruit", "Shows crop index to fruit", "commandCropIndexToFruit", self)
    addConsoleCommand("crCatchCropIndexToFruit", "Shows catch crop index to fruit", "commandCatchCropIndexToFruit", self)
	addConsoleCommand("crToggleGroundDebug", "Enables debug display of ground data", "commandToggleGroundDebug", self)
    addConsoleCommand("crUpdateState", "Update state on field", "commandUpdateState", self, "state;")
end

function DebugCropRotation:removeConsoleCommands()
    removeConsoleCommand("crFallowState")
    removeConsoleCommand("crCatchCropState")
    removeConsoleCommand("crSetStateToField")
    removeConsoleCommand("crSetCatchCropStateToField")
    removeConsoleCommand("crCropIndexToFruit")
    removeConsoleCommand("crCatchCropIndexToFruit")
    removeConsoleCommand("crToggleGroundDebug")
    removeConsoleCommand("crUpdateState")
end

function DebugCropRotation:commandGetFallowState()
    local x, _, z = g_localPlayer:getPosition()
    local fallowStateManager = self.cropRotation.fallowStateManager
    Logging.info(fallowStateManager.fallowStateMap:getState(x, z, fallowStateManager.fallowStateMap.firstChannel, fallowStateManager.fallowStateMap.numChannels))
end

function DebugCropRotation:commandGetCatchCropState()
    local x, _, z = g_localPlayer:getPosition()
    local catchCropManager = self.cropRotation.catchCropManager
    Logging.info(catchCropManager.catchCropMap:getState(x, z, catchCropManager.catchCropMap.firstChannel, catchCropManager.catchCropMap.numChannels))
end

function DebugCropRotation:commandSetStateToCurrentField(historyStateIndex, stateValue)
    local fieldId = g_fieldManager:getFieldIdAtPlayerPosition()
    local field = g_fieldManager:getFieldById(fieldId)
    local state = tonumber(stateValue)

    if field == nil then
        Logging.info("No field detected")
        return
    end

    local historyStateManager = self.cropRotation.historyStateManager
    local historyState = historyStateManager.historyStates[tonumber(historyStateIndex)]

    if historyState == nil then
        Logging.info("History state index not found")
        return
    end

    if state ~= CropRotation.FALLOW_STATE then
        local crop = self.cropRotation:cropByFruitTypeIndex(state)
        if crop == nil then
            Logging.info("Crop not found")
            return
        end
    end

    self:setStateToCurrentField(fieldId, tonumber(state), tonumber(historyStateIndex))
end

function DebugCropRotation:setStateToCurrentField(fieldId, state, historyStateIndex)
    if g_currentMission:getIsServer() then
        local historyStateManager = self.cropRotation.historyStateManager
        local historyState = historyStateManager.historyStates[historyStateIndex]
        local field = g_fieldManager:getFieldById(fieldId)
        historyState.map:updateFruitCoverAreaForField(field, state)
    else
        DebugCropRotationEvent.new(DebugCropRotationEvent.SET_CROP_STATE, fieldId, state, historyStateIndex):sendEvent()
    end
end

function DebugCropRotation:commandSetCatchCropStateToCurrentField(catchCropIndexValue)
    local fieldId = g_fieldManager:getFieldIdAtPlayerPosition()
    local field = g_fieldManager:getFieldById(fieldId)
    local catchCropIndex = tonumber(catchCropIndexValue)

    if field == nil then
        Logging.info("No field detected")
        return
    end

    if catchCropIndex ~= CropRotation.NO_CATCH_CROP_STATE then
        local catchCrop = self.cropRotation:catchCropByCatchCropIndex(catchCropIndex)
        if catchCrop == nil then
            Logging.info("Catch crop not found")
            return
        end
    end

    self:setCatchCropStateToCurrentField(fieldId, catchCropIndex)
end

function DebugCropRotation:setCatchCropStateToCurrentField(fieldId, catchCropIndex)
    if g_currentMission:getIsServer() then
        local catchCropManager = self.cropRotation.catchCropManager
        local field = g_fieldManager:getFieldById(fieldId)
        catchCropManager.catchCropMap:updateCatchCropStateForField(field, catchCropIndex)
    else
        DebugCropRotationEvent.new(DebugCropRotationEvent.SET_CATCH_CROP_STATE, fieldId, catchCropIndex):sendEvent()
    end
end

function DebugCropRotation:commandCropIndexToFruit()
    for index, crop in pairs(self.cropRotation:getPossibleCropStates()) do
        Logging.info("Crop Index: "..crop.cropIndex.." - "..crop.name)
    end
end

function DebugCropRotation:commandCatchCropIndexToFruit()
    for index, crop in pairs(self.cropRotation.catchCropIndexToCatchCrop) do
        local fruitType = self.cropRotation.catchCropIndexToFruitType[index]
        Logging.info("Catch Crop Index: "..index.." - "..fruitType.fillType.title)
    end
end

function DebugCropRotation:commandToggleGroundDebug()
    if self.groundDebugArea == nil then
		local catchCropMap = self.cropRotation.catchCropManager.catchCropMap
		local fallowStateMap = self.cropRotation.fallowStateManager.fallowStateMap
		local historyStateMap1 = self.cropRotation.historyStateManager.historyStates[1]
		local historyStateMap2 = self.cropRotation.historyStateManager.historyStates[2]
		local data = {}
		self.groundDebugArea = DebugBitVectorMap.newSimple(50, 2, false, 0.01, 0.1)
		self.groundDebugArea:createWithCustomFunc(function(_, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
			local centerX = (startWorldX + widthWorldX + heightWorldX) / 3
			local centerZ = (startWorldZ + widthWorldZ + heightWorldZ) / 3
			
            data.catchCropState = catchCropMap:getState(centerX, centerZ, catchCropMap.firstChannel, catchCropMap.numChannels)
            data.fallowState = fallowStateMap:getState(centerX, centerZ, fallowStateMap.firstChannel, fallowStateMap.numChannels)
            data.historyState1 = historyStateMap1.map:getState(centerX, centerZ, historyStateMap1.map.firstChannel, historyStateMap1.map.numChannels)
            data.historyState2 = historyStateMap2.map:getState(centerX, centerZ, historyStateMap2.map.firstChannel, historyStateMap2.map.numChannels)

			return 1, 0
		end)
		self.groundDebugArea:setAdditionalDrawInfoFunc(function(_, x, z, area, totalArea)
			local y = getTerrainHeightAtWorldPos(g_terrainNode, x, 0, z) + 0.1
            local catchCropFruitType = self.cropRotation:fruitTypeByCatchCropIndex(data.catchCropState)
            local catchCropTitle = "None"
            if catchCropFruitType ~= nil then
                catchCropTitle = catchCropFruitType.fillType.title
            end

			Utils.renderTextAtWorldPosition(x, y, z, string.format("Catch crop: %s\nFallow state: %d\nLast crop state: %d\nPenultimate state: %d", catchCropTitle, data.fallowState, data.historyState1, data.historyState2), getCorrectTextSize(0.01), 0)
		end)
		g_debugManager:addElement(self.groundDebugArea)
	else
		g_debugManager:removeElement(self.groundDebugArea)
		self.groundDebugArea = nil
	end
end

function DebugCropRotation:commandUpdateState(cropIndexValue)
    local fieldId = g_fieldManager:getFieldIdAtPlayerPosition()
    local field = g_fieldManager:getFieldById(fieldId)
    local cropIndex = tonumber(cropIndexValue)

    if field == nil then
        Logging.info("No field detected")
        return
    end

    if cropIndex ~= CropRotation.FALLOW_STATE then
        local crop = self.cropRotation:cropByFruitTypeIndex(cropIndex)
        if crop == nil then
            Logging.info("Crop not found")
            return
        end
    end

    self:updateState(cropIndex, fieldId)
end


function DebugCropRotation:updateState(cropIndex, fieldId)
    if g_currentMission:getIsServer() then
        local historyStateManager = self.cropRotation.historyStateManager
        local field = g_fieldManager:getFieldById(fieldId)
        g_asyncTaskManager:addTask(function()
            historyStateManager:updateStatesForField(cropIndex, field)
        end)
    else
        DebugCropRotationEvent.new(DebugCropRotationEvent.UPDATE_STATE, cropIndex, fieldId):sendEvent()
    end
end