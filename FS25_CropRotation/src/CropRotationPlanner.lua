local CropRotationPlanner = {}
local CropRotationPlanner_mt = Class(CropRotationPlanner, AbstractManager)

source(g_currentModDirectory.."src/events/SyncCropRotationPlannerEvent.lua")

function CropRotationPlanner.new(customMt)
	local self = CropRotationPlanner:superClass().new(customMt or CropRotationPlanner_mt)

    self.cropRotations = {}
    self.nextCropRotationIndex = 1

	return self
end

function CropRotationPlanner:updateCropRotation(entry)
    local index = self:getIndexForCropRotation(entry)

    if index ~= nil then
        self.cropRotations[index] = entry
    else
        Logging.error("CR: Could not find Crop Rotation with index "..entry.index)
    end

    g_messageCenter:publish(MessageType.CROP_ROTATIONS_CHANGED)
end

function CropRotationPlanner:addDeleteCropRotations(entry, shouldDelete)
    if shouldDelete then
        local index = self:getIndexForCropRotation(entry)
        self.cropRotations[index] = nil
    else
        table.insert(self.cropRotations, entry)
        self.nextCropRotationIndex = self.nextCropRotationIndex + 1
    end

    g_messageCenter:publish(MessageType.CROP_ROTATIONS_CHANGED)
end

function CropRotationPlanner:addCropRotation(name, farmId)
    local entry = {
        rotations = {},
        name = name,
        farmId = farmId,
        index = self.nextCropRotationIndex
    }

    local rotation = {
        state = g_cropRotation.FALLOW_STATE,
        yieldValue = 100,
        catchCropState = g_cropRotation.NO_CATCH_CROP_STATE
    }
    table.insert(entry.rotations, rotation)

    if g_currentMission:getIsServer() then
        self.cropRotations[self.nextCropRotationIndex] = entry
        self.nextCropRotationIndex = self.nextCropRotationIndex + 1
    else
        CropRotationEntryEvent.new(farmId, entry.name, entry.rotations, self.nextCropRotationIndex, false, false):sendOrBroadcastEvent()
    end
end

function CropRotationPlanner:removeCropRotation(cropRotation)
    if g_currentMission:getIsServer() then
        local index = self:getIndexForCropRotation(cropRotation)
        self.cropRotations[index] = nil
    else
        CropRotationEntryEvent.new(cropRotation.farmId, cropRotation.name, cropRotation.rotations, cropRotation.index, false, true):sendOrBroadcastEvent()
    end
end

function CropRotationPlanner:addCropRotationSelection(cropRotation)
    local rotation = {
        state = g_cropRotation.FALLOW_STATE,
        yieldValue = 100,
        catchCropState = g_cropRotation.NO_CATCH_CROP_STATE
    }

    table.insert(cropRotation.rotations, rotation)
    CropRotationEntryEvent.new(cropRotation.farmId, cropRotation.name, cropRotation.rotations, cropRotation.index, true, false):sendOrBroadcastEvent()
end

function CropRotationPlanner:removeCropRotationSelection(cropRotation)
    table.remove(cropRotation.rotations, #cropRotation.rotations)
    CropRotationEntryEvent.new(cropRotation.farmId, cropRotation.name, cropRotation.rotations, cropRotation.index, true, false):sendOrBroadcastEvent()
end

function CropRotationPlanner:updateCropSelection(cropRotation, rotationIndex, cropIndex)
    local currentRotation = cropRotation.rotations[rotationIndex]
    currentRotation.state = cropIndex
    CropRotationEntryEvent.new(cropRotation.farmId, cropRotation.name, cropRotation.rotations, cropRotation.index, true, false):sendOrBroadcastEvent()
end

function CropRotationPlanner:updateCatchCropSelection(cropRotation, rotationIndex, catchCropIndex)
    local currentRotation = cropRotation.rotations[rotationIndex]
    currentRotation.catchCropState = catchCropIndex
    CropRotationEntryEvent.new(cropRotation.farmId, cropRotation.name, cropRotation.rotations, cropRotation.index, true, false):sendOrBroadcastEvent()
end

function CropRotationPlanner:getCropRotationWithIndex(index)
    for _, cropRotation in pairs(self.cropRotations) do
        if cropRotation.index == index then
            return cropRotation
        end
    end

    return nil
end

function CropRotationPlanner:getIndexForCropRotation(cropRotation)
    for index, currrentCropRotation in pairs(self.cropRotations) do
        if currrentCropRotation.index == cropRotation.index then
            return index
        end
    end

    return nil
end

function CropRotationPlanner:saveToXMLFile(missionInfo)
    local savegameDirectory = g_currentMission.missionInfo.savegameDirectory

    if savegameDirectory ~= nil then
        local saveGamePath = savegameDirectory.."/cropRotationPlanner.xml"
        local key = "cropRotations"
        local xmlFile = XMLFile.create("cropRotations", saveGamePath, key)
        xmlFile:setInt(key.."#nextCropRotationIndex", self.nextCropRotationIndex)

        if xmlFile ~= nil then
            local cropRotationIndex = 0
            for _, cropRotation in pairs(self.cropRotations) do
                local cropRotationKey = string.format(key..".cropRotation(%d)", cropRotationIndex)
                xmlFile:setInt(cropRotationKey.."#farmId", cropRotation.farmId)
                xmlFile:setString(cropRotationKey.."#name", cropRotation.name)
                xmlFile:setInt(cropRotationKey.."#index", cropRotation.index)

                for rotationIndex, rotation in pairs(cropRotation.rotations) do
                    local rotationKey = string.format(cropRotationKey..".rotation(%d)", rotationIndex - 1)
                    xmlFile:setInt(rotationKey.."#state", rotation.state)
                    xmlFile:setInt(rotationKey.."#catchCropState", rotation.catchCropState)
                end
                cropRotationIndex = cropRotationIndex + 1
            end

            xmlFile:save()
            xmlFile:delete()
        end
    end
end

FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, function(missionInfo)
	g_cropRotationPlanner:saveToXMLFile(missionInfo)
end)

function CropRotationPlanner:loadFromXMLFile()
    local savegameDirectory = g_currentMission.missionInfo.savegameDirectory

    if savegameDirectory ~= nil then
        local filename = savegameDirectory.."/cropRotationPlanner.xml"
        local key = "cropRotations"
        local xmlFile = XMLFile.loadIfExists("cropRotations", filename, key)

        if xmlFile ~= nil then
            local nextCropRotationIndex = xmlFile:getInt(key.."#nextCropRotationIndex")
            local cropRotationIndex = 0
            while true do
                local cropRotationKey = string.format(key..".cropRotation(%d)", cropRotationIndex)

                if not xmlFile:hasProperty(cropRotationKey) then
                    break
                end

                local farmId = xmlFile:getInt(cropRotationKey.."#farmId")
                local name = xmlFile:getString(cropRotationKey.."#name")
                local index = xmlFile:getInt(cropRotationKey.."#index")

                local rotationIndex = 0
                local rotations = {}

                while true do
                    local rotationKey = string.format(cropRotationKey..".rotation(%d)", rotationIndex)

                    if not xmlFile:hasProperty(rotationKey) then
                        break
                    end

                    local rotation = {
                        state = xmlFile:getInt(rotationKey.."#state"),
                        catchCropState = xmlFile:getInt(rotationKey.."#catchCropState")
                    }
                    table.insert(rotations, rotation)

                    rotationIndex = rotationIndex + 1
                end

                local cropRotation = {
                    farmId = farmId,
                    name = name,
                    rotations = rotations,
                    index = index or #self.cropRotations + 1
                }
                table.insert(self.cropRotations, cropRotation)
                cropRotationIndex = cropRotationIndex + 1
            end

            self.nextCropRotationIndex = nextCropRotationIndex or #self.cropRotations + 1

            xmlFile:delete()
        end
    end
end

Mission00.loadItemsFinished = Utils.appendedFunction(Mission00.loadItemsFinished, function()
	g_cropRotationPlanner:loadFromXMLFile()
end)

function CropRotationPlanner:sendInitialClientState(connection)
    connection:sendEvent(SyncCropRotationPlannerEvent.new())
end

FSBaseMission.sendInitialClientState = Utils.appendedFunction(FSBaseMission.sendInitialClientState, function(_, connection, user, farm)
	g_cropRotationPlanner:sendInitialClientState(connection)
end)


g_cropRotationPlanner = CropRotationPlanner.new()