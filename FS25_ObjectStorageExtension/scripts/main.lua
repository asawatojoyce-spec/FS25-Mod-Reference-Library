--[[
Copyright (C) GtX (Andy), 2025

Author: GtX | Andy
Date: 25.02.2025
Revision: FS25-03

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

local modName = g_currentModName
local modDirectory = g_currentModDirectory
local modSettingsDirector = g_currentModSettingsDirectory

local versionString = "0.0.0.0"
local buildId = 3

local consoleCommandsGtX = StartParams.getIsSet("consoleCommandsGtX")
local validationFail

local function isActive()
    return g_modIsLoaded[modName] and g_objectStorageExtension ~= nil
end

local function validateMod()
    local mod = g_modManager:getModByName(modName)

    if mod == nil or g_iconGenerator ~= nil or g_isEditor then
        return false
    end

    versionString = mod.version or versionString

    if mod.modName == "FS25_ObjectStorageExtension" or mod.modName == "FS25_ObjectStorageExtension_update" then
        if mod.author ~= nil and #mod.author == 3 then
            return true
        end
    end

    local validationText = "This mod is outdated and not working properly. Please update the mod first!"

    if g_i18n:hasText("ui_modsCannotActivateBlockedModUpdate") then
        validationText = g_i18n:getText("ui_modsCannotActivateBlockedModUpdate")
    end

    validationText = string.format("- %s -\n\n%s", mod.modName, validationText)

    validationFail = {
        startUpdateTime = 2000,

        update = function(self, dt)
            self.startUpdateTime = self.startUpdateTime - dt

            if self.startUpdateTime < 0 then
                if g_dedicatedServer == nil then
                    if not g_gui:getIsGuiVisible() then
                        local yesText = g_i18n:getText("button_modHubDownload")
                        local noText = g_i18n:getText("button_ok")

                        YesNoDialog.show(self.openModHubLink, nil, validationText, mod.title, yesText, noText, DialogElement.TYPE_WARNING)
                    end
                else
                    print("\n" .. validationText .. "\n    - https://farming-simulator.com/mods.php?&title=fs2025&filter=org&org_id=129652&page=0" .. "\n")
                    self.openModHubLink(false)
                end
            end
        end,

        openModHubLink = function(yes)
            if yes then
                openWebFile("mods.php?title=fs2025&filter=org&org_id=129652&page=0", "")
            end

            removeModEventListener(validationFail)
            validationFail = nil
        end
    }

    addModEventListener(validationFail)

    return false
end

local function overwriteFunctions()
    -- Settings
    InGameMenuSettingsFrame.updateGeneralSettings = Utils.appendedFunction(InGameMenuSettingsFrame.updateGeneralSettings, function(frame)
        if not isActive() then
            return
        end

        if frame.objectStorageExtension_sectionHeader == nil then
            local generalSettingsLayout = frame.generalSettingsLayout

            for i, element in ipairs (generalSettingsLayout.elements) do
                if element.name == "sectionHeader" and element:isa(TextElement) then
                    frame.objectStorageExtension_sectionHeader = element:clone(generalSettingsLayout)
                    frame.objectStorageExtension_sectionHeader:setText(g_i18n:getText("ose_ui_sectionHeader", modName))

                    break
                end
            end

            local binaryOptionParent = nil

            for i, element in ipairs (generalSettingsLayout.elements) do
                if #element.elements > 0 and element:isa(BitmapElement) then
                    if element.elements[1]:isa(BinaryOptionElement) then
                        binaryOptionParent = element

                        break
                    end
                end
            end

            if binaryOptionParent ~= nil then
                for _, setting in ipairs (g_objectStorageExtension.settings) do
                    local parent = binaryOptionParent:clone(generalSettingsLayout, false)
                    local binaryOption = parent.elements[1]

                    function binaryOption.onClickCallback(_, state)
                        if g_objectStorageExtension ~= nil then
                            g_objectStorageExtension:applySettingState(setting, state == BinaryOptionElement.STATE_RIGHT)
                        end
                    end

                    parent.elements[2]:setText(setting.title)
                    binaryOption.elements[1]:setText(setting.toolTip)

                    binaryOption.id = setting.id

                    binaryOption:setVisible(true)
                    binaryOption:setDisabled(false)

                    binaryOption:setIsChecked(setting.state, true)
                    binaryOption:updateSelection()

                    frame[setting.id] = binaryOption

                    parent:setVisible(true)
                    parent:setDisabled(false)
                end
            end

            generalSettingsLayout:invalidateLayout()
        end

        for _, setting in ipairs (g_objectStorageExtension.settings) do
            local element = frame[setting.id]

            if element ~= nil then
                element:setIsChecked(setting.state, frame.isOpening)
            end
        end
    end)

    InGameMenuSettingsFrame.onFrameClose = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameClose, function(frame)
        if isActive() and g_objectStorageExtension.settingsChanged then
            g_objectStorageExtension:saveSettings()
        end
    end)

    -- In Game Menu
    InGameMenu.onLoadMapFinished = Utils.appendedFunction(InGameMenu.onLoadMapFinished, function(inGameMenu)
        if isActive() then
            local pageObjectStorageExtension = g_objectStorageExtension:loadGui(inGameMenu, g_gui.currentlyReloading)

            if pageObjectStorageExtension ~= nil then
                if pageObjectStorageExtension.onLoadMapFinished ~= nil then
                    pageObjectStorageExtension:onLoadMapFinished()
                end

                pageObjectStorageExtension:setPlayerFarm(inGameMenu.playerFarm)
            end
        end
    end)

    InGameMenu.setPlayerFarm = Utils.prependedFunction(InGameMenu.setPlayerFarm, function(inGameMenu, farm)
        if inGameMenu.pageObjectStorageExtension ~= nil then
            inGameMenu.pageObjectStorageExtension:setPlayerFarm(farm)
        end
    end)

    -- Fix for InGameMenu tab list not rebuilding correctly.
    -- This should be reset at the top of 'SmoothListElement.buildSectionInfo' or if the local 'contentOffset' <= 0  ( @Giants Software )
    -- To avoid possible issues in other mods this is a safe place to make this happen as the issue only occurs when the tab list rebuilds when permissions change (e.g joining/leaving a farm).
    InGameMenu.rebuildTabList = Utils.prependedFunction(InGameMenu.rebuildTabList, function(self)
        if self.pagingTabList ~= nil then
            self.pagingTabList.listItemAlignmentOffset = 0
        end
    end)

    -- Redirect error messages if the Object Storage frame is open
    local function getInfoMessage(errorId)
        if errorId == PlaceableObjectStorageErrorEvent.ERROR_NOT_ENOUGH_SPACE then
            return g_i18n:getText("warning_objectStorageNotEnoughSpace")
        end

        if errorId == PlaceableObjectStorageErrorEvent.ERROR_SLOT_LIMIT_REACHED_BALES then
            return g_i18n:getText("warning_tooManyBales")
        end

        if errorId == PlaceableObjectStorageErrorEvent.ERROR_SLOT_LIMIT_REACHED_PALLETS then
            return g_i18n:getText("warning_tooManyPallets")
        end

        return nil
    end

    PlaceableObjectStorageErrorEvent.run = Utils.overwrittenFunction(PlaceableObjectStorageErrorEvent.run, function(activatable, superFunc)
        local message = getInfoMessage(activatable.errorId)

        if message ~= nil and g_inGameMenu ~= nil and g_inGameMenu:getIsOpen() then
            local pageObjectStorageExtension = g_inGameMenu.pageObjectStorageExtension

            if pageObjectStorageExtension ~= nil and pageObjectStorageExtension.isOpen then
                if activatable.placeable ~= nil and activatable.placeable:getIsSynchronized() and activatable.placeable == pageObjectStorageExtension:getSelectedObjectStorage() then
                    pageObjectStorageExtension:setInfoMessage(message, true)

                    return
                end
            end
        end

        superFunc(activatable)
    end)

    -- Redirect dialog open requests if the user has the option enabled
    PlaceableObjectStorageActivatable.run = Utils.overwrittenFunction(PlaceableObjectStorageActivatable.run, function(activatable, superFunc)
        if ObjectStorageExtension ~= nil and ObjectStorageExtension.IN_GAME_MENU_ENABLED then
            if g_objectStorageExtension ~= nil and g_objectStorageExtension:getIsSettingEnabled("triggersUseInGameMenu", false) then
                local inGameMenu = g_inGameMenu or g_gui.screenControllers[InGameMenu]

                if inGameMenu ~= nil and inGameMenu.pageObjectStorageExtension ~= nil then
                    if not inGameMenu:getIsOpen() then
                        inGameMenu:changeScreen(InGameMenu)
                    end

                    local pageMappingIndex = inGameMenu.pagingElement:getPageMappingIndexByElement(inGameMenu.pageObjectStorageExtension)

                    if pageMappingIndex ~= nil then
                        inGameMenu.pageSelector:setState(pageMappingIndex, true)
                        inGameMenu.pageObjectStorageExtension:setSelectedObjectStorage(activatable.objectStorage)

                        return
                    end
                end
            end
        end

        superFunc(activatable)
    end)
end

local function overwriteAbstractObjects()
    -- Sync Bale colours and fermenting status.
    -- Note: (10-11-25) Removed individual bale syncing and just use the first object colour so not to waste network bandwidth as most people do not mix and match colours for the same FillType / Size.
    local AbstractBaleObject = PlaceableObjectStorage.ABSTRACT_OBJECTS_BY_CLASS_NAME["Bale"]

    if AbstractBaleObject ~= nil then
        AbstractBaleObject.readStream = Utils.overwrittenFunction(AbstractBaleObject.readStream, function(streamId, superFunc, connection)
            local abstractObject = superFunc(streamId, connection)

            if abstractObject.baleAttributes.wrappingState == 1 then
                abstractObject.baleAttributes.isFermenting = streamReadBool(streamId)

                local r, g, b = Color.readStreamRGB(streamId)
                abstractObject.baleAttributes.wrappingColor = {r, g, b}
            end

            return abstractObject
        end)

        local backupWrappingColour = Color.PRESETS.WHITE

        AbstractBaleObject.writeStream = Utils.overwrittenFunction(AbstractBaleObject.writeStream, function(abstractObject, superFunc, streamId, connection)
            superFunc(abstractObject, streamId, connection)

            if abstractObject.baleObject == nil then
                if abstractObject.baleAttributes.wrappingState ~= 0 then
                    streamWriteBool(streamId, false)

                    local wrappingColor = abstractObject.baleAttributes.wrappingColor or backupWrappingColour
                    Color.writeStreamRGB(streamId, wrappingColor[1], wrappingColor[2], wrappingColor[3])
                end
            else
                if abstractObject.baleObject.wrappingState ~= 0 then
                    streamWriteBool(streamId, abstractObject.baleObject.isFermenting == true)

                    local wrappingColor = abstractObject.baleObject.wrappingColor or backupWrappingColour
                    Color.writeStreamRGB(streamId, wrappingColor[1], wrappingColor[2], wrappingColor[3])
                end
            end
        end)
    end

    -- Fix for packed bales not working once removed from storage
    local AbstractPackedBaleObject = PlaceableObjectStorage.ABSTRACT_OBJECTS_BY_CLASS_NAME["PackedBale"]

    if AbstractPackedBaleObject ~= nil then
        AbstractPackedBaleObject.loadFromXMLFile = function(storage, xmlFile, key)
            local attributes = {}

            -- Avoid possible class / mod changes
            if PackedBale.loadBaleAttributesFromXMLFile ~= nil then
                PackedBale.loadBaleAttributesFromXMLFile(attributes, xmlFile, key, false)
            else
                Bale.loadBaleAttributesFromXMLFile(attributes, xmlFile, key, false)
            end

            if attributes.isFermenting then
                local packedBale = PackedBale.new(storage.isServer, storage.isClient)

                if packedBale:loadFromConfigXML(attributes.xmlFilename, 0, 0, 0, 0, 0, 0, attributes.uniqueId) then
                    packedBale:applyBaleAttributes(attributes)
                    storage:addObjectToObjectStorage(packedBale, true)
                end
            else
                local abstractObject = AbstractPackedBaleObject.new()
                abstractObject.baleAttributes = attributes

                storage:addAbstactObjectToObjectStorage(abstractObject)
                g_farmManager:updateFarmStats(storage:getOwnerFarmId(), "storedBales", 1)
            end
        end

        AbstractPackedBaleObject.readStream = Utils.overwrittenFunction(AbstractPackedBaleObject.readStream, function(streamId, superFunc, connection)
            local abstractBaleObject = superFunc(streamId, connection)

            -- Create the correct class and clone the bale attributes to try and avoid errors if writeStream is changed down the road
            local abstractObject = AbstractPackedBaleObject.new()
            abstractObject.baleAttributes = table.clone(abstractBaleObject.baleAttributes)

            return abstractObject
        end)

        AbstractPackedBaleObject.removeFromStorage = Utils.overwrittenFunction(AbstractPackedBaleObject.removeFromStorage, function(abstractObject, superFunc, storage, x, y, z, rx, ry, rz, spawnedCallback)
            if abstractObject.baleObject == nil then
                local packedBale = PackedBale.new(storage.isServer, storage.isClient)

                if packedBale:loadFromConfigXML(abstractObject.baleAttributes.xmlFilename, x, y, z, rx, ry, rz, abstractObject.baleAttributes.uniqueId) then
                    packedBale:applyBaleAttributes(abstractObject.baleAttributes)
                    packedBale:register()
                end

                g_farmManager:updateFarmStats(storage:getOwnerFarmId(), "storedBales", -1)
                spawnedCallback(storage, packedBale)

                return
            end

            superFunc(abstractObject, storage, x, y, z, rx, ry, rz, spawnedCallback)
        end)
    end
end

local function finalizeTypes(typeManager)
    if typeManager.typeName == "placeable" and isActive() then
        local specializationName = PlaceableObjectStorageExtension.SPEC_NAME
        local specializationObject = g_placeableSpecializationManager:getSpecializationObjectByName(specializationName)

        if specializationObject ~= nil then
            for typeName, typeEntry in pairs (typeManager:getTypes()) do
                if specializationObject.prerequisitesPresent(typeEntry.specializations) then
                    typeManager:addSpecialization(typeName, specializationName)
                end
            end
        end

        g_asyncTaskManager:addTask(function()
            overwriteFunctions()
            overwriteAbstractObjects()

            g_objectStorageExtension:createSettings()
            g_objectStorageExtension:loadSettings()

            g_objectStorageExtension:load()
        end)
    end
end

local function loadMapData(baleManager, superFunc, xmlFile, missionInfo, baseDirectory)
    local success = superFunc(baleManager, xmlFile, missionInfo, baseDirectory)

    if isActive() then
        g_objectStorageExtension:loadBaleIcons(baleManager, missionInfo)
    end

    return success
end

local function unload()
    if isActive() then
        g_objectStorageExtension:delete()
    end

    g_globalMods.objectStorageExtension = nil
    g_objectStorageExtension = nil
end

local function init()
    if g_globalMods == nil then
        g_globalMods = {}
    end

    if g_globalMods.objectStorageExtension ~= nil then
        Logging.error("Validation of '%s' failed, script set has already been loaded by '%s'.", modName, g_globalMods.objectStorageExtension.modName or "Unknown")

        return false
    end

    if validateMod() then
        source(modDirectory .. "scripts/events/PlaceableObjectStorageExtensionEvent.lua")
        source(modDirectory .. "scripts/misc/ObjectStorageExtension.lua")
        source(modDirectory .. "scripts/gui/InGameMenuObjectStorageExtensionFrame.lua")

        g_placeableSpecializationManager:addSpecialization("objectStorageExtension", "PlaceableObjectStorageExtension", modDirectory .. "scripts/placeables/PlaceableObjectStorageExtension.lua", nil)

        MessageType.OSE_PLACEABLES_CHANGED = nextMessageTypeId()
        MessageType.OSE_OBJECT_INFOS_CHANGED = nextMessageTypeId()

        if string.isNilOrWhitespace(modSettingsDirector) then
            modSettingsDirector = getUserProfileAppPath() .. "modSettings/" .. modName
        end

        g_objectStorageExtension = ObjectStorageExtension.new(modName, modDirectory, modSettingsDirector, buildId, versionString, consoleCommandsGtX)
        g_globalMods.objectStorageExtension = g_objectStorageExtension

        TypeManager.finalizeTypes = Utils.prependedFunction(TypeManager.finalizeTypes, finalizeTypes)
        BaleManager.loadMapData = Utils.overwrittenFunction(BaleManager.loadMapData, loadMapData)
        FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, unload)
    else
        Logging.error("[%s] Failed to initialise / validate mod, make sure you are using the latest release available on the Giants Official Mod Hub with no file or zip name changes!", modName)
    end
end

init()
