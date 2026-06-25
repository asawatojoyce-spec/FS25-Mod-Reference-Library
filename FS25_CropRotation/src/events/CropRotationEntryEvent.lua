CropRotationEntryEvent = {}

local CropRotationEntryEvent_mt = Class(CropRotationEntryEvent, Event)
InitEventClass(CropRotationEntryEvent, "CropRotationEntryEvent")

function CropRotationEntryEvent.emptyNew()
    local self = Event.new(CropRotationEntryEvent_mt)

    return self
end

function CropRotationEntryEvent.new(farmId, name, rotations, index, isUpdate, shouldDelete)
    local self = CropRotationEntryEvent.emptyNew()

    self.farmId = farmId
    self.name = name
    self.rotations = rotations
    self.index = index
    self.isUpdate = isUpdate
    self.shouldDelete = shouldDelete

    return self
end

function CropRotationEntryEvent:readStream(streamId, connection)
    self.farmId = streamReadInt32(streamId)
    self.index = streamReadInt32(streamId)
    self.isUpdate = streamReadBool(streamId)
    self.shouldDelete = streamReadBool(streamId)

    local hasName = streamReadBool(streamId)
    if hasName then
        self.name = streamReadString(streamId)
    end

    local hasRotations = streamReadBool(streamId)
    if hasRotations then
        local rotationNum = streamReadInt32(streamId)
        self.rotations = {}

        for _ = 1, rotationNum do
            local rotation = {
                state = streamReadInt32(streamId),
                catchCropState = streamReadInt32(streamId),
                yieldValue = 100
            }
            table.insert(self.rotations, rotation)
        end
    end

    self:run(connection)
end

function CropRotationEntryEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.farmId)
    streamWriteInt32(streamId, self.index)
    streamWriteBool(streamId, self.isUpdate)
    streamWriteBool(streamId, self.shouldDelete)

    if self.name ~= nil then
        streamWriteBool(streamId, true)
        streamWriteString(streamId, self.name)
    else
        streamWriteBool(streamId, false)
    end

    if self.rotations ~= nil then
        streamWriteBool(streamId, true)
        streamWriteInt32(streamId, #self.rotations)

        for _, rotation in pairs(self.rotations) do
            streamWriteInt32(streamId, rotation.state)
            streamWriteInt32(streamId, rotation.catchCropState)
        end
    else
        streamWriteBool(streamId, false)
    end
end

function CropRotationEntryEvent:run(connection)
    local entry = {
        rotations = self.rotations,
        name = self.name,
        farmId = self.farmId,
        index = self.index
    }

    if self.isUpdate then
        g_cropRotationPlanner:updateCropRotation(entry)
    else
        g_cropRotationPlanner:addDeleteCropRotations(entry, self.shouldDelete)
    end

    if g_currentMission:getIsServer() then
        g_server:broadcastEvent(self, false, self.isUpdate)
    end
end

function CropRotationEntryEvent:sendOrBroadcastEvent()
    if g_currentMission:getIsServer() then
        g_server:broadcastEvent(self, false)
    else
        g_client:getServerConnection():sendEvent(self)
    end
end