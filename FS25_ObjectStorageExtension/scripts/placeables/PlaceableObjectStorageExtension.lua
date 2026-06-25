--[[
Copyright (C) GtX (Andy), 2025

Author: GtX | Andy
Date: 25.02.2025
Revision: FS25-02

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


PlaceableObjectStorageExtension = {}

PlaceableObjectStorageExtension.MOD_NAME = g_currentModName
PlaceableObjectStorageExtension.SPEC_NAME = string.format("%s.objectStorageExtension", g_currentModName)
PlaceableObjectStorageExtension.SPEC_TABLE_NAME = string.format("spec_%s", PlaceableObjectStorageExtension.SPEC_NAME)

PlaceableObjectStorageExtension.NO_UNLOAD_MARKER = g_currentModDirectory .. "shared/markerIconNoUnload.i3d"
PlaceableObjectStorageExtension.BASE_GAME_STORAGE = "data/placeables/mapUS/objectStorage/objectStorage.xml"

PlaceableObjectStorageExtension.OBJECT_TYPE_ALL = 1
PlaceableObjectStorageExtension.OBJECT_TYPE_BALES = 2
PlaceableObjectStorageExtension.OBJECT_TYPE_PALLETS = 3

function PlaceableObjectStorageExtension.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(PlaceableObjectStorage, specializations)
end

function PlaceableObjectStorageExtension.registerOverwrittenFunctions(placeableType)
    SpecializationUtil.registerOverwrittenFunction(placeableType, "setName", PlaceableObjectStorageExtension.setName)
    SpecializationUtil.registerOverwrittenFunction(placeableType, "updateInfo", PlaceableObjectStorageExtension.updateInfo)
    SpecializationUtil.registerOverwrittenFunction(placeableType, "updateObjectStorageVisualAreas", PlaceableObjectStorageExtension.updateObjectStorageVisualAreas)
    SpecializationUtil.registerOverwrittenFunction(placeableType, "onObjectStorageObjectTriggerCallback", PlaceableObjectStorageExtension.onObjectStorageObjectTriggerCallback)
    SpecializationUtil.registerOverwrittenFunction(placeableType, "addAbstactObjectToObjectStorage", PlaceableObjectStorageExtension.addAbstactObjectToObjectStorage)
end

function PlaceableObjectStorageExtension.registerFunctions(placeableType)
    SpecializationUtil.registerFunction(placeableType, "onObjectStorageDisabledMarkerLoaded", PlaceableObjectStorageExtension.onObjectStorageDisabledMarkerLoaded)
    SpecializationUtil.registerFunction(placeableType, "setObjectStorageAcceptedObjectTypes", PlaceableObjectStorageExtension.setObjectStorageAcceptedObjectTypes)
    SpecializationUtil.registerFunction(placeableType, "setObjectStorageTotalCapacity", PlaceableObjectStorageExtension.setObjectStorageTotalCapacity)
    SpecializationUtil.registerFunction(placeableType, "setObjectStorageInputTriggerDisabled", PlaceableObjectStorageExtension.setObjectStorageInputTriggerDisabled)
    SpecializationUtil.registerFunction(placeableType, "resetObjectStorageConfiguration", PlaceableObjectStorageExtension.resetObjectStorageConfiguration)
    SpecializationUtil.registerFunction(placeableType, "getObjectStorageInputTriggerDisabled", PlaceableObjectStorageExtension.getObjectStorageInputTriggerDisabled)
    SpecializationUtil.registerFunction(placeableType, "getObjectStorageIsConfigured", PlaceableObjectStorageExtension.getObjectStorageIsConfigured)
end

function PlaceableObjectStorageExtension.registerEventListeners(placeableType)
    SpecializationUtil.registerEventListener(placeableType, "onPreLoad", PlaceableObjectStorageExtension)
    SpecializationUtil.registerEventListener(placeableType, "onPostLoad", PlaceableObjectStorageExtension)
    SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", PlaceableObjectStorageExtension)
    SpecializationUtil.registerEventListener(placeableType, "onDelete", PlaceableObjectStorageExtension)
    SpecializationUtil.registerEventListener(placeableType, "onReadStream", PlaceableObjectStorageExtension)
    SpecializationUtil.registerEventListener(placeableType, "onWriteStream", PlaceableObjectStorageExtension)
end

function PlaceableObjectStorageExtension.registerXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("ObjectStorageExtension")

    schema:register(XMLValueType.BOOL, basePath .. ".objectStorageExtension#supportsObjectTypesConfiguration", "Override the ability for user to configure the permitted object types", true)
    schema:register(XMLValueType.BOOL, basePath .. ".objectStorageExtension#supportsTotalCapacityConfiguration", "Override the ability for user to configure the storage capacity", true)

    schema:register(XMLValueType.NODE_INDEX, basePath .. ".objectStorageExtension.disabledTriggerMarker#linkNode", "Link node to attach default 'red' tipping disabled marker to. The visibility of this node will be changed so it should not have children you do not want affected by this.")

    schema:register(XMLValueType.BOOL, basePath .. ".objectStorageExtension.disabledTriggerMarker#adjustToGround", "Trigger marker adjusted to ground", false)
    schema:register(XMLValueType.FLOAT, basePath .. ".objectStorageExtension.disabledTriggerMarker#groundOffset", "Height of the trigger marker above the ground if adjustToGround is enabled", 0.03)
    schema:register(XMLValueType.BOOL, basePath .. ".objectStorageExtension.disabledTriggerMarker#showAllPlayers", "Show marker for all players even if they do not have access to the placeable", false)
    schema:register(XMLValueType.BOOL, basePath .. ".objectStorageExtension.disabledTriggerMarker#showOnlyIfOwned", "Show marker only if owned", false)

    ObjectChangeUtil.registerObjectChangeXMLPaths(schema, basePath .. ".objectStorageExtension.disabledTriggerMarker") -- Changes are based on input state (trigger disabled = active) using standard 'objectChange' options

    schema:setXMLSpecializationType()
end

function PlaceableObjectStorageExtension.registerSavegameXMLPaths(schema, basePath)
    schema:register(XMLValueType.BOOL, basePath .. "#objectTriggerDisabled", "Is the object input trigger disabled", false)
    schema:register(XMLValueType.INT, basePath .. "#supportedTypeId", "Object type ID for the supported object types", "Building Default")
    schema:register(XMLValueType.INT, basePath .. "#capacity", "Maximum capacity", "Building Default")
end

function PlaceableObjectStorageExtension:onPreLoad(savegame)
    self.spec_objectStorageExtension = self[PlaceableObjectStorageExtension.SPEC_TABLE_NAME]

    local spec = self.spec_objectStorageExtension

    spec.supportsObjectTypesConfiguration = false
    spec.supportsTotalCapacityConfiguration = false

    spec.supportedTypeId = 1
    spec.defualtSupportedTypeId = 1

    spec.capacity = 250
    spec.defaultCapacity = 250

    spec.objectTriggerDisabled = false
    spec.objectTriggerStateChanging = false

    spec.infoTableTriggerDisabled = {
        title = g_i18n:getText("ose_message_objectTriggerDisabled", PlaceableObjectStorageExtension.MOD_NAME),
        accentuate = true
    }
end

function PlaceableObjectStorageExtension:onPostLoad(savegame)
    local spec = self[PlaceableObjectStorageExtension.SPEC_TABLE_NAME]
    local objectStorageSpec = self.spec_objectStorage

    local supportedTypeId, supportsObjectTypesConfiguration = PlaceableObjectStorageExtension.getSupportedObjectTypeId(objectStorageSpec.supportsBales, objectStorageSpec.supportsPallets)

    spec.supportsObjectTypesConfiguration = self.xmlFile:getValue("placeable.objectStorageExtension#supportsObjectTypesConfiguration", supportsObjectTypesConfiguration)
    spec.supportsTotalCapacityConfiguration = self.xmlFile:getValue("placeable.objectStorageExtension#supportsTotalCapacityConfiguration", true)

    local linkNode = self.xmlFile:getValue("placeable.objectStorageExtension.disabledTriggerMarker#linkNode", nil, self.components, self.i3dMappings)
    local adjustToGroundDefault = false

    if linkNode == nil and self.configFileName == PlaceableObjectStorageExtension.BASE_GAME_STORAGE then
        if self.i3dMappings.objectStorage ~= nil and self.i3dMappings.objectTriggerMarker ~= nil then
            spec.objectStorageNode = I3DUtil.indexToObject(self.components, "objectStorage", self.i3dMappings)
            spec.objectTriggerMarker = I3DUtil.indexToObject(self.components, "objectTriggerMarker", self.i3dMappings)

            if spec.objectStorageNode ~= nil and spec.objectTriggerMarker ~= nil then
                adjustToGroundDefault = true

                linkNode = createTransformGroup("disabledTriggerMarker")
                setTranslation(linkNode, getTranslation(spec.objectTriggerMarker))
                link(spec.objectStorageNode, linkNode)
            end
        end
    end

    if linkNode ~= nil and fileExists(PlaceableObjectStorageExtension.NO_UNLOAD_MARKER) then
        local adjustToGround = self.xmlFile:getValue("placeable.objectStorageExtension.disabledTriggerMarker#adjustToGround", adjustToGroundDefault)
        local groundOffset = self.xmlFile:getValue("placeable.objectStorageExtension.disabledTriggerMarker#groundOffset", 0.03)

        local showAllPlayers = self.xmlFile:getValue("placeable.objectStorageExtension.disabledTriggerMarker#showAllPlayers", false)
        local showOnlyIfOwned = self.xmlFile:getValue("placeable.objectStorageExtension.disabledTriggerMarker#showOnlyIfOwned", false)

        local marker = {
            node = linkNode,
            adjustToGround = adjustToGround,
            groundOffset = groundOffset,
            showAllPlayers = showAllPlayers,
            showOnlyIfOwned = showOnlyIfOwned,
            i3dFilename = PlaceableObjectStorageExtension.NO_UNLOAD_MARKER
        }

        local loadingTask = self:createLoadingTask()
        local args = {marker = marker, loadingTask = loadingTask}

        spec.disabledMarkerLoadRequestId = g_i3DManager:loadSharedI3DFileAsync(marker.i3dFilename, false, false, self.onObjectStorageDisabledMarkerLoaded, self, args)

        spec.disabledMarker = marker
        spec.disabledMarkerLinkNode = linkNode

        setVisibility(linkNode, false)
    end

    if self.xmlFile:hasProperty("placeable.objectStorageExtension.disabledTriggerMarker.objectChange(0)") then
        spec.objectTriggerObjectChanges = {}

        ObjectChangeUtil.loadObjectChangeFromXML(self.xmlFile, "placeable.objectStorageExtension.disabledTriggerMarker", spec.objectTriggerObjectChanges, self.components, self)
        ObjectChangeUtil.setObjectChanges(spec.objectTriggerObjectChanges, false)
    end

    spec.supportedTypeId = supportedTypeId
    spec.defualtSupportedTypeId = supportedTypeId

    spec.capacity = objectStorageSpec.capacity
    spec.defaultCapacity = spec.capacity

    -- TO_DO (UPDATE): Load custom spawn area nodes into 'storageArea'.
    --                 Fixed visibility types and/or backup options depending on mod.
    --                 Fill level based effects, sounds and objectChange.
    --                 Display options?
end

function PlaceableObjectStorageExtension:onFinalizePlacement()
    if self.configFileName == PlaceableObjectStorageExtension.BASE_GAME_STORAGE then
        local spec = self[PlaceableObjectStorageExtension.SPEC_TABLE_NAME]

        -- Adjust trigger markers to support disabled/enabled set.
        if spec.objectStorageNode ~= nil and spec.objectTriggerMarker ~= nil then
            local objectTriggerMarkerIndex = getChildIndex(spec.objectTriggerMarker)
            local enabledMarkerLinkNode = createTransformGroup("objectTriggerMarkerHolder")

            link(spec.objectStorageNode, enabledMarkerLinkNode, objectTriggerMarkerIndex)
            link(enabledMarkerLinkNode, spec.objectTriggerMarker)

            setVisibility(enabledMarkerLinkNode, not spec.objectTriggerDisabled)
            spec.enabledMarkerLinkNode = enabledMarkerLinkNode

            spec.objectStorageNode = nil
            spec.objectTriggerMarker = nil
        end

        -- Allow players to rename, no reason not to do this.
        self.canBeRenamed = true
    end

    if self.isServer then
        g_messageCenter:publish(MessageType.OSE_PLACEABLES_CHANGED, self, false)
    end
end

function PlaceableObjectStorageExtension:onObjectStorageDisabledMarkerLoaded(i3dNode, failedReason, args)
    local linkNode = args.marker.node
    local loadingTask = args.loadingTask

    if i3dNode ~= 0 then
        link(linkNode, i3dNode)

        args.marker.node = i3dNode

        -- If the trigger markers spec is available then we add to it to handle visibility
        if self.spec_triggerMarkers ~= nil and self.spec_triggerMarkers.triggerMarkers ~= nil then
            table.insert(self.spec_triggerMarkers.triggerMarkers, args.marker)
        end
    end

    self:finishLoadingTask(loadingTask)
end

function PlaceableObjectStorageExtension:onDelete()
    local spec = self[PlaceableObjectStorageExtension.SPEC_TABLE_NAME]

    g_messageCenter:publish(MessageType.OSE_PLACEABLES_CHANGED, self, false)

    if spec.disabledMarkerLoadRequestId ~= nil then
        g_i3DManager:releaseSharedI3DFile(spec.disabledMarkerLoadRequestId)
        spec.disabledMarkerLoadRequestId = nil
    end
end

function PlaceableObjectStorageExtension:onReadStream(streamId, connection)
    if connection:getIsServer() then
        local spec = self[PlaceableObjectStorageExtension.SPEC_TABLE_NAME]

        spec.ignoreMessages = true

        self:setObjectStorageInputTriggerDisabled(streamReadBool(streamId), true)

        self:setObjectStorageAcceptedObjectTypes(streamReadUIntN(streamId, 2), true)

        self:setObjectStorageTotalCapacity(streamReadInt32(streamId), true)

        spec.ignoreMessages = false

        g_messageCenter:publish(MessageType.OSE_PLACEABLES_CHANGED, self, false)
    end
end

function PlaceableObjectStorageExtension:onWriteStream(streamId, connection)
    if not connection:getIsServer() then
        local spec = self[PlaceableObjectStorageExtension.SPEC_TABLE_NAME]

        streamWriteBool(streamId, spec.objectTriggerDisabled)

        streamWriteUIntN(streamId, spec.supportedTypeId, 2)

        streamWriteInt32(streamId, spec.capacity)
    end
end

function PlaceableObjectStorageExtension:loadFromXMLFile(xmlFile, key)
    local spec = self[PlaceableObjectStorageExtension.SPEC_TABLE_NAME]

    spec.ignoreMessages = true

    self:setObjectStorageInputTriggerDisabled(xmlFile:getValue(key .. "#objectTriggerDisabled", false), true)

    if spec.supportsObjectTypesConfiguration then
        self:setObjectStorageAcceptedObjectTypes(xmlFile:getValue(key .. "#supportedTypeId", spec.defualtSupportedTypeId), true)
    end

    if spec.supportsTotalCapacityConfiguration then
        self:setObjectStorageTotalCapacity(xmlFile:getValue(key .. "#capacity", spec.defaultCapacity), true)
    end

    spec.ignoreMessages = false
end

function PlaceableObjectStorageExtension:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self[PlaceableObjectStorageExtension.SPEC_TABLE_NAME]

    if spec.objectTriggerDisabled then
        xmlFile:setValue(key .. "#objectTriggerDisabled", true)
    end

    if spec.supportsObjectTypesConfiguration then
        xmlFile:setValue(key .. "#supportedTypeId", spec.supportedTypeId)
    end

    if spec.supportsTotalCapacityConfiguration and spec.capacity ~= spec.defaultCapacity then
        xmlFile:setValue(key .. "#capacity", spec.capacity)
    end
end

function PlaceableObjectStorageExtension:setObjectStorageAcceptedObjectTypes(supportedTypeId, noEventSend)
    local spec = self[PlaceableObjectStorageExtension.SPEC_TABLE_NAME]
    local supportsBales, supportsPallets, typeId = PlaceableObjectStorageExtension.getSupportedObjectTypesById(supportedTypeId or spec.supportedTypeId, spec.defualtSupportedTypeId)

    spec.supportedTypeId = typeId

    self.spec_objectStorage.supportsBales = supportsBales
    self.spec_objectStorage.supportsPallets = supportsPallets

    PlaceableObjectStorageExtensionEvent.sendEvent(self, PlaceableObjectStorageExtensionEvent.OBJECT_TYPE, false, typeId, noEventSend)

    if not self.isLoadingFromSavegameXML then
        if not spec.objectTriggerDisabled then
            local oldIgnoreMessages = spec.ignoreMessages

            spec.ignoreMessages = true
            self:setObjectStorageInputTriggerDisabled(false, true)
            spec.ignoreMessages = oldIgnoreMessages
        end

        if not spec.ignoreMessages then
            g_messageCenter:publish(MessageType.OSE_PLACEABLES_CHANGED, self, false)
        end
    end
end

function PlaceableObjectStorageExtension:setObjectStorageTotalCapacity(capacity, noEventSend)
    local spec = self[PlaceableObjectStorageExtension.SPEC_TABLE_NAME]

    spec.capacity = capacity or spec.defaultCapacity
    self.spec_objectStorage.capacity = spec.capacity

    PlaceableObjectStorageExtensionEvent.sendEvent(self, PlaceableObjectStorageExtensionEvent.TOTAL_CAPACITY, false, spec.capacity, noEventSend)

    if not spec.ignoreMessages then
        g_messageCenter:publish(MessageType.OSE_PLACEABLES_CHANGED, self, false)
    end
end

function PlaceableObjectStorageExtension:setObjectStorageInputTriggerDisabled(disabled, noEventSend)
    local spec = self[PlaceableObjectStorageExtension.SPEC_TABLE_NAME]

    if disabled == nil then
        disabled = false
    end

    spec.objectTriggerDisabled = disabled

    if spec.disabledMarkerLinkNode ~= nil then
        -- Base game placeable only, mods can use object change
        if spec.enabledMarkerLinkNode ~= nil then
            setVisibility(spec.enabledMarkerLinkNode, not disabled)
        end

        setVisibility(spec.disabledMarkerLinkNode, disabled)
    end

    ObjectChangeUtil.setObjectChanges(spec.objectTriggerObjectChanges, disabled)

    PlaceableObjectStorageExtensionEvent.sendEvent(self, PlaceableObjectStorageExtensionEvent.INPUT_TRIGGER, false, disabled, noEventSend)

    -- Switch collision filter mask and wake up objects to try and add them to storage if they were added while trigger was disabled.
    if self.isServer and not self.isLoadingFromSavegameXML and not disabled and not spec.objectTriggerStateChanging then
        local objectStorageSpec = self.spec_objectStorage
        local objectTriggerNode = objectStorageSpec.objectTriggerNode or 0

        if objectTriggerNode ~= 0 then
            local collisionMask = getCollisionFilterMask(objectTriggerNode) or 0

            if collisionMask == 0 then
                collisionMask = CollisionFlag.VEHICLE + CollisionFlag.DYNAMIC_OBJECT
            end

            spec.objectTriggerStateChanging = true
            setCollisionFilterMask(objectTriggerNode, 0)

            local triggerObjects, maxDistance = {}, 20

            if objectStorageSpec.supportsPallets then
                for _, vehicle in ipairs (g_currentMission.vehicleSystem.vehicles) do
                    if vehicle.isPallet and vehicle.rootNode ~= nil and calcDistanceFrom(vehicle.rootNode, objectTriggerNode) <= maxDistance then
                        table.insert(triggerObjects, vehicle)
                    end
                end
            end

            if objectStorageSpec.supportsBales then
                for object, _ in pairs (g_currentMission.itemSystem.itemsToSave) do
                    if object.nodeId ~= nil and (object.isa ~= nil and object:isa(Bale)) and calcDistanceFrom(object.nodeId, objectTriggerNode) <= maxDistance then
                        table.insert(triggerObjects, object)
                    end
                end
            end

            Timer.createOneshot(800, function()
                setCollisionFilterMask(objectTriggerNode, collisionMask)

                for _, object in ipairs(triggerObjects) do
                    if object.nodeId ~= nil and entityExists(object.nodeId) then
                        I3DUtil.wakeUpObject(object.nodeId)
                    elseif object.rootNode ~= nil and entityExists(object.rootNode) then
                        I3DUtil.wakeUpObject(object.rootNode)
                    end
                end

                spec.objectTriggerStateChanging = false
            end)
        end
    end

    if not spec.ignoreMessages then
        g_messageCenter:publish(MessageType.OSE_PLACEABLES_CHANGED, self, false)
    end
end

function PlaceableObjectStorageExtension:resetObjectStorageConfiguration(configurationId, noEventSend)
    if not self:getObjectStorageIsConfigured() or configurationId == nil then
        return false
    end

    local spec = self[PlaceableObjectStorageExtension.SPEC_TABLE_NAME]
    local resetAll = configurationId == PlaceableObjectStorageExtensionEvent.RESET_ALL

    spec.ignoreMessages = true

    if resetAll or configurationId == PlaceableObjectStorageExtensionEvent.OBJECT_TYPE then
        self:setObjectStorageAcceptedObjectTypes(spec.defualtSupportedTypeId, true)
    end

    if resetAll or configurationId == PlaceableObjectStorageExtensionEvent.TOTAL_CAPACITY then
        self:setObjectStorageTotalCapacity(spec.defaultCapacity, true)
    end

    if resetAll or configurationId == PlaceableObjectStorageExtensionEvent.INPUT_TRIGGER then
        self:setObjectStorageInputTriggerDisabled(false, true)
    end

    spec.ignoreMessages = false

    PlaceableObjectStorageExtensionEvent.sendEvent(self, configurationId, true, nil, noEventSend)

    g_messageCenter:publish(MessageType.OSE_PLACEABLES_CHANGED, self, true)

    return true
end

function PlaceableObjectStorageExtension:getObjectStorageInputTriggerDisabled()
    return self[PlaceableObjectStorageExtension.SPEC_TABLE_NAME].objectTriggerDisabled == true
end

function PlaceableObjectStorageExtension:getObjectStorageIsConfigured(configurationId)
    local spec = self[PlaceableObjectStorageExtension.SPEC_TABLE_NAME]
    local isConfigured = false

    if spec.objectTriggerDisabled then
        if configurationId == PlaceableObjectStorageExtensionEvent.INPUT_TRIGGER then
            return true, true
        end

        isConfigured = true
    end

    if spec.supportedTypeId ~= spec.defualtSupportedTypeId then
        if configurationId == PlaceableObjectStorageExtensionEvent.OBJECT_TYPE then
            return true, true
        end

        isConfigured = true
    end

    if spec.capacity ~= spec.defaultCapacity then
        if configurationId == PlaceableObjectStorageExtensionEvent.TOTAL_CAPACITY then
            return true, true
        end

        isConfigured = true
    end

    return isConfigured, false
end

function PlaceableObjectStorageExtension:setName(superFunc, name, noEventSend)
    local oldName = self.nameCustom
    local success = superFunc(self, name, noEventSend)

    -- PlaceableHandToolHolders does not correctly return superFunc so also check for name change manually in case spec is used on placeable
    if success or oldName ~= self.nameCustom then
        g_messageCenter:publish(MessageType.OSE_PLACEABLES_CHANGED, self, false)
    end

    return success
end

function PlaceableObjectStorageExtension:updateInfo(superFunc, infoTable)
    superFunc(self, infoTable)

    local spec = self[PlaceableObjectStorageExtension.SPEC_TABLE_NAME]

    if spec ~= nil and spec.objectTriggerDisabled then
        table.insert(infoTable, spec.infoTableTriggerDisabled)
    end
end

function PlaceableObjectStorageExtension:onObjectStorageObjectTriggerCallback(superFunc, triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
    if onEnter then
        local spec = self[PlaceableObjectStorageExtension.SPEC_TABLE_NAME]

        if spec ~= nil and spec.objectTriggerDisabled then
            return
        end
    end

    superFunc(self, triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
end

function PlaceableObjectStorageExtension:updateObjectStorageVisualAreas(superFunc)
    -- Always called after objectInfos are updated so perfect place to notify of change
    g_messageCenter:publish(MessageType.OSE_OBJECT_INFOS_CHANGED, self, self.spec_objectStorage.objectInfos)

    superFunc(self)
end

function PlaceableObjectStorageExtension:addAbstactObjectToObjectStorage(superFunc, abstractObject)
    local baleObject = abstractObject.baleObject

    if baleObject ~= nil and baleObject.isFermenting then
        -- Fix for fermenting object being shown as Silage when not all objects have completed.
        -- Also stops multiple groups of the same fill type requiring a restart to be shown as one, with the added benefit of removing static bale objects
        local onFermentationEnd = baleObject.onFermentationEnd

        baleObject.onFermentationEnd = function(bale)
            if bale.isServer and bale.isFermenting then
                onFermentationEnd(bale)

                if not bale.isFermenting and PlaceableObjectStorageExtension.onAbstractBaleObjectFermentationEnd(self, bale) then
                    self:setObjectStorageObjectInfosDirty()
                end

                return
            end

            onFermentationEnd(bale)
        end
    end

    superFunc(self, abstractObject)
end

function PlaceableObjectStorageExtension.onAbstractBaleObjectFermentationEnd(storage, bale)
    if storage ~= nil and not storage.isDeleting and not storage.isDeleted then
        for i, abstractObject in ipairs (storage.spec_objectStorage.storedObjects) do
            if abstractObject.baleObject == bale then
                abstractObject.baleAttributes = bale:getBaleAttributes()

                if abstractObject.baleAttributes ~= nil then
                    abstractObject.baleObject = nil
                    bale:delete()
                end

                return true
            end
        end
    end

    return false
end

function PlaceableObjectStorageExtension.getSupportedObjectTypesById(supportedTypeId, defualtSupportedTypeId)
    if supportedTypeId == PlaceableObjectStorageExtension.OBJECT_TYPE_BALES then
        return true, false, PlaceableObjectStorageExtension.OBJECT_TYPE_BALES
    end

    if supportedTypeId == PlaceableObjectStorageExtension.OBJECT_TYPE_PALLETS then
        return false, true, PlaceableObjectStorageExtension.OBJECT_TYPE_PALLETS
    end

    if supportedTypeId == PlaceableObjectStorageExtension.OBJECT_TYPE_ALL or defualtSupportedTypeId == nil then
        return true, true, PlaceableObjectStorageExtension.OBJECT_TYPE_ALL
    end

    return PlaceableObjectStorageExtension.getSupportedObjectTypesById(defualtSupportedTypeId, nil)
end

function PlaceableObjectStorageExtension.getSupportedObjectTypeId(supportsBales, supportsPallets)
    if supportsBales then
        if supportsPallets then
            return PlaceableObjectStorageExtension.OBJECT_TYPE_ALL, true
        end

        return PlaceableObjectStorageExtension.OBJECT_TYPE_BALES, false
    end

    if supportsPallets then
        return PlaceableObjectStorageExtension.OBJECT_TYPE_PALLETS, false
    end

    return PlaceableObjectStorageExtension.OBJECT_TYPE_ALL, true
end
