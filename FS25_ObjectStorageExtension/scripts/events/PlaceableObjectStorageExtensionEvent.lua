--[[
Copyright (C) GtX (Andy), 2025

Author: GtX | Andy
Date: 25.02.2025
Revision: FS25-01

Contact:
https://forum.giants-software.com
https://github.com/GtX-Andy

Important:
Not to be added to any mods / maps or modified from its current release form.
No modifications may be made to this script, including conversion to other game versions without written permission from GtX | Andy
Copying or removing any part of this code for external use without written permission from GtX | Andy is prohibited.

Darf nicht zu Mods / Maps hinzugefügt oder von der aktuellen Release-Form geändert werden.
Ohne schriftliche Genehmigung von GtX | Andy dürfen keine Änderungen an diesem Skript vorgenommen werden, einschließlich der Konvertierung in andere Spielversionen
Das Kopieren oder Entfernen irgendeines Teils dieses Codes zur externen Verwendung ohne schriftliche Genehmigung von GtX | Andy ist verboten.
]]

PlaceableObjectStorageExtensionEvent = {}

PlaceableObjectStorageExtensionEvent.RESET_ALL = 0
PlaceableObjectStorageExtensionEvent.INPUT_TRIGGER = 1
PlaceableObjectStorageExtensionEvent.TOTAL_CAPACITY = 2
PlaceableObjectStorageExtensionEvent.OBJECT_TYPE = 3

local PlaceableObjectStorageExtensionEvent_mt = Class(PlaceableObjectStorageExtensionEvent, Event)
InitEventClass(PlaceableObjectStorageExtensionEvent, "PlaceableObjectStorageExtensionEvent")

function PlaceableObjectStorageExtensionEvent.emptyNew()
    return Event.new(PlaceableObjectStorageExtensionEvent_mt)
end

function PlaceableObjectStorageExtensionEvent.new(object, configurationId, isReset, value)
    local self = PlaceableObjectStorageExtensionEvent.emptyNew()

    self.object = object

    self.configurationId = configurationId
    self.isReset = isReset
    self.value = value

    return self
end

function PlaceableObjectStorageExtensionEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)

    self.configurationId = streamReadUIntN(streamId, 2)
    self.isReset = streamReadBool(streamId)

    if not self.isReset then
        if self.configurationId == PlaceableObjectStorageExtensionEvent.INPUT_TRIGGER then
            self.value = streamReadBool(streamId)
        elseif self.configurationId == PlaceableObjectStorageExtensionEvent.TOTAL_CAPACITY then
            self.value = streamReadInt32(streamId)
        elseif self.configurationId == PlaceableObjectStorageExtensionEvent.OBJECT_TYPE then
            self.value = streamReadUIntN(streamId, 2)
        end
    end

    self:run(connection)
end

function PlaceableObjectStorageExtensionEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)

    streamWriteUIntN(streamId, self.configurationId, 2)
    streamWriteBool(streamId, self.isReset)

    if not self.isReset then
        if self.configurationId == PlaceableObjectStorageExtensionEvent.INPUT_TRIGGER then
            streamWriteBool(streamId, self.value)
        elseif self.configurationId == PlaceableObjectStorageExtensionEvent.TOTAL_CAPACITY then
            streamWriteInt32(streamId, self.value)
        elseif self.configurationId == PlaceableObjectStorageExtensionEvent.OBJECT_TYPE then
            streamWriteUIntN(streamId, self.value, 2)
        end
    end
end

function PlaceableObjectStorageExtensionEvent:run(connection)
    if self.object ~= nil and self.object:getIsSynchronized() then
        if not self.isReset then
            if self.configurationId == PlaceableObjectStorageExtensionEvent.INPUT_TRIGGER then
                self.object:setObjectStorageInputTriggerDisabled(self.value, true)
            elseif self.configurationId == PlaceableObjectStorageExtensionEvent.TOTAL_CAPACITY then
                self.object:setObjectStorageTotalCapacity(self.value, true)
            elseif self.configurationId == PlaceableObjectStorageExtensionEvent.OBJECT_TYPE then
                self.object:setObjectStorageAcceptedObjectTypes(self.value, true)
            end
        else
            self.object:resetObjectStorageConfiguration(self.configurationId, true)
        end

        if not connection:getIsServer() then
            g_server:broadcastEvent(PlaceableObjectStorageExtensionEvent.new(self.object, self.configurationId, self.isReset, self.value), nil, connection, self.object)
        end
    end
end

function PlaceableObjectStorageExtensionEvent.sendEvent(object, configurationId, isReset, value, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(PlaceableObjectStorageExtensionEvent.new(object, configurationId, isReset, value), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(PlaceableObjectStorageExtensionEvent.new(object, configurationId, isReset, value))
        end
    end
end
