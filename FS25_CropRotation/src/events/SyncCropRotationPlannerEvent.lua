SyncCropRotationPlannerEvent = {}

local SyncCropRotationPlannerEvent_mt = Class(SyncCropRotationPlannerEvent, Event)
InitEventClass(SyncCropRotationPlannerEvent, "SyncCropRotationPlannerEvent")

function SyncCropRotationPlannerEvent.emptyNew()
    return Event.new(SyncCropRotationPlannerEvent_mt)
end

function SyncCropRotationPlannerEvent.new()
    return SyncCropRotationPlannerEvent.emptyNew()
end

function SyncCropRotationPlannerEvent:readStream(streamId, connection)
    local cropRotations = {}
    local nextCropRotationIndex = streamReadInt32(streamId)
	local numCropRotations = streamReadInt32(streamId)

	for i=1, numCropRotations do
        local cropRotation = {
            farmId = streamReadInt32(streamId),
            name = streamReadString(streamId),
            index = streamReadInt32(streamId),
            rotations = {}
        }

        local hasRotations = streamReadBool(streamId)
        if hasRotations then
            local numRotations = streamReadInt32(streamId)

            for j=1, numRotations do
                local rotation = {
                    state = streamReadInt32(streamId),
                    catchCropState = streamReadInt32(streamId)
                }
                table.insert(cropRotation.rotations, rotation)
            end
        end

        table.insert(cropRotations, cropRotation)
    end

    if connection:getIsServer() or g_currentMission.userManager:getIsConnectionMasterUser(connection) then
        local cropRotationPlanner = g_cropRotationPlanner
        cropRotationPlanner.nextCropRotationIndex = nextCropRotationIndex
        cropRotationPlanner.cropRotations = cropRotations

		if not connection:getIsServer() then
			g_server:broadcastEvent(self, false, connection)
		end
    end
end

function SyncCropRotationPlannerEvent:writeStream(streamId, connection)
    local cropRotationPlanner = g_cropRotationPlanner

    streamWriteInt32(streamId, cropRotationPlanner.nextCropRotationIndex)
    streamWriteInt32(streamId, #cropRotationPlanner.cropRotations)

    for cropRotationIndex, cropRotation in pairs(cropRotationPlanner.cropRotations) do
        streamWriteInt32(streamId, cropRotation.farmId)
        streamWriteString(streamId, cropRotation.name)
        streamWriteInt32(streamId, cropRotation.index)


        if cropRotation.rotations ~= nil then
            streamWriteBool(streamId, true)
            streamWriteInt32(streamId, #cropRotation.rotations)

            for _, rotation in pairs(cropRotation.rotations) do
                streamWriteInt32(streamId, rotation.state)
                streamWriteInt32(streamId, rotation.catchCropState)
            end
        else
            streamWriteBool(streamId, false)
        end
    end
end

function SyncCropRotationPlannerEvent.run(_, _)
    Logging.error("Error: SyncCropRotationPlannerEvent is not allowed to be executed on a local client")
end

function SyncCropRotationPlannerEvent.sendEvent(noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_currentMission:getIsServer() then
			g_server:broadcastEvent(SyncCropRotationPlannerEvent.new(), false)
		else
            g_client:getServerConnection():sendEvent(SyncCropRotationPlannerEvent.new())
        end
	end
end