DebugCropRotationEvent = {
    SET_CROP_STATE = 1,
    SET_CATCH_CROP_STATE = 2,
    UPDATE_STATE = 3
}

local DebugCropRotationEvent_mt = Class(DebugCropRotationEvent, Event)
InitEventClass(DebugCropRotationEvent, "DebugCropRotationEvent")

function DebugCropRotationEvent.emptyNew()
    local self = Event.new(DebugCropRotationEvent_mt)

    return self
end

function DebugCropRotationEvent.new(eventType, param1, param2, param3)
    local self = DebugCropRotationEvent.emptyNew()

    self.eventType = eventType
    self.param1 = param1
    self.param2 = param2
    self.param3 = param3

    return self
end

function DebugCropRotationEvent:readStream(streamId, connection)
    self.eventType = streamReadInt32(streamId)
    self.param1 = streamReadInt32(streamId)
    self.param2 = streamReadInt32(streamId)
    self.param3 = streamReadInt32(streamId)
    self:run(connection)
end

function DebugCropRotationEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.eventType)
    streamWriteInt32(streamId, self.param1)
    streamWriteInt32(streamId, self.param2)
    streamWriteInt32(streamId, self.param3)
end

function DebugCropRotationEvent:run(connection)
    if g_currentMission:getIsServer() then
        if self.eventType == DebugCropRotationEvent.SET_CROP_STATE then
            g_cropRotation.debugManager:setStateToCurrentField(self.param1, self.param2, self.param3)
        elseif self.eventType == DebugCropRotationEvent.SET_CATCH_CROP_STATE then
            g_cropRotation.debugManager:setCatchCropStateToCurrentField(self.param1, self.param2)
        elseif self.eventType == DebugCropRotationEvent.UPDATE_STATE then
            g_cropRotation.debugManager:updateState(self.param1, self.param2)
        end
    end
end

function DebugCropRotationEvent:sendEvent()
    if not g_currentMission:getIsServer() then
        g_client:getServerConnection():sendEvent(self)
    end
end