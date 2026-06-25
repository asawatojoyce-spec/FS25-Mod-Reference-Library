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

ObjectStorageExtension = {}

ObjectStorageExtension.IN_GAME_MENU_ENABLED = false

local ObjectStorageExtension_mt = Class(ObjectStorageExtension)

function ObjectStorageExtension.new(customEnvironment, baseDirectory, settingsDirectory, buildId, versionString, addConsoleCommands)
    local self = setmetatable({}, ObjectStorageExtension_mt)

    self.isServer = g_server ~= nil
    self.isClient = g_client ~= nil

    self.customEnvironment = customEnvironment
    self.baseDirectory = baseDirectory
    self.settingsDirectory = settingsDirectory

    self.buildId = buildId
    self.versionString = versionString

    self.roundBaleIcons = {}
    self.squareBaleIcons = {}

    self.settings = {}
    self.settingByName = {}

    self.addConsoleCommands = addConsoleCommands

    -- Requires -consoleCommandsGtX start parameter as most users will never need the command.
    if addConsoleCommands then
        addConsoleCommand("gtxObjectStorageExtensionToggleGUI", "Toggles the availability of the Object Storage menu", "consoleCommandToggleGUI", self)
    end

    return self
end

function ObjectStorageExtension:load()
    -- g_gui:loadProfiles(self.baseDirectory .. "gui/guiProfiles.xml")
    g_overlayManager:addTextureConfigFile(self.baseDirectory .. "menu/gui.xml", "objectStorageExtension")

    if self:loadGui(g_inGameMenu or g_gui.screenControllers[InGameMenu], false) ~= nil then
        ObjectStorageExtension.IN_GAME_MENU_ENABLED = true

        Logging.devInfo("Successfully added 'ObjectStorageExtensionFrame' to InGameMenu.")
    end

    return true
end

function ObjectStorageExtension:loadGui(inGameMenu, forceReload)
    if inGameMenu == nil then
        return nil
    end

    if inGameMenu.pageObjectStorageExtension == nil or forceReload then
        InGameMenuObjectStorageExtensionFrame.register()

        local xmlFile = loadXMLFile("IngameMenuFrameRefXML", self.baseDirectory .. "gui/InGameMenuObjectStorageExtensionFrameRef.xml")

        if xmlFile ~= 0 then
            inGameMenu.controlIDs.pageObjectStorageExtension = nil

            g_gui:loadGuiRec(xmlFile, "FrameReferences", inGameMenu.pagingElement, inGameMenu)

            inGameMenu:exposeControlsAsFields("pageObjectStorageExtension")
            inGameMenu.pagingElement:updatePageMapping()

            delete(xmlFile)
        end

        local frame = g_gui:resolveFrameReference(inGameMenu.pageObjectStorageExtension)

        if frame.initialize ~= nil then
            local function enablingPredicateFunction()
                -- Only show when enabled
                if not ObjectStorageExtension.IN_GAME_MENU_ENABLED then
                    return false
                end

                -- Make sure the player is part of a farm and the tour is not running.
                return (not inGameMenu.missionDynamicInfo.isMultiplayer or inGameMenu.playerFarmId ~= FarmManager.SPECTATOR_FARM_ID) and not g_guidedTourManager:getIsTourRunning()
            end

            inGameMenu:registerPage(frame, nil, enablingPredicateFunction)
            inGameMenu:addPageTab(frame, nil, nil, "objectStorageExtension.ingameMenuIcon")

            frame:onGuiSetupFinished()
            frame:initialize()
        else
            Logging.devError("[ObjectStorageExtension] Failed to add frame element to In Game Menu!")
        end
    end

    local pageObjectStorageExtension = inGameMenu.pageObjectStorageExtension

    if pageObjectStorageExtension ~= nil then
        local positionTargetPage = inGameMenu.pageProduction

        local position = #inGameMenu.pagingElement.elements + 1

        for i, element in ipairs (inGameMenu.pagingElement.elements) do
            if element == positionTargetPage then
                position = i + 1

                break
            end
        end

        for i, element in ipairs (inGameMenu.pagingElement.elements) do
            if element == pageObjectStorageExtension then
                if i ~= position then
                    table.remove(inGameMenu.pagingElement.elements, i)
                    table.insert(inGameMenu.pagingElement.elements, position, element)
                end

                break
            end
        end

        for i, page in ipairs (inGameMenu.pagingElement.pages) do
            if page.element == pageObjectStorageExtension then
                if i ~= position then
                    table.remove(inGameMenu.pagingElement.pages, i)
                    table.insert(inGameMenu.pagingElement.pages, position, page)
                end

                break
            end
        end

        inGameMenu.pagingElement:updatePageMapping()

        for i, frame in ipairs (inGameMenu.pageFrames) do
            if frame == pageObjectStorageExtension then
                if i ~= position then
                    table.remove(inGameMenu.pageFrames, i)
                    table.insert(inGameMenu.pageFrames, position, frame)
                end

                break
            end
        end

        inGameMenu:rebuildTabList()
    end

    return pageObjectStorageExtension
end

function ObjectStorageExtension:loadBaleIcons(baleManager, missionInfo)
    self.roundBaleIcons = {}
    self.squareBaleIcons = {}

    local function loadBaleHudOverlaysFromXML(xmlFile, baseDirectory, customEnvironment)
        local modDesc = XMLFile.loadIfExists("modDescXML", xmlFile)

        if modDesc ~= nil then
            if modDesc:hasProperty("modDesc.objectStorageBaleIcons.baleIcon(0)") then
                modDesc:iterate("modDesc.objectStorageBaleIcons.baleIcon", function (index, key)
                    local fillTypeName = modDesc:getString(key .. "#fillType")
                    local filename = modDesc:getString(key .. "#filename")

                    if fillTypeName ~= nil and filename ~= nil then
                        local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName)
                        local iconFilename = Utils.getFilename(filename, baseDirectory)

                        if fillTypeIndex ~= nil and iconFilename ~= nil and fileExists(iconFilename) then
                            if modDesc:getBool(key .. "#isRoundbale", false) then
                                if self.roundBaleIcons[fillTypeIndex] == nil or customEnvironment == self.customEnvironment then
                                    self.roundBaleIcons[fillTypeIndex] = iconFilename
                                end
                            else
                                if self.squareBaleIcons[fillTypeIndex] == nil or customEnvironment == self.customEnvironment then
                                    self.squareBaleIcons[fillTypeIndex] = iconFilename
                                end
                            end
                        end
                    end
                end)
            end

            modDesc:delete()
        end
    end

    -- First add the base icons to be used.
    loadBaleHudOverlaysFromXML(self.baseDirectory .. "modDesc.xml", self.baseDirectory, self.customEnvironment)

    -- If a mod adds bales outside of the default fill types then also check for bale icons.
    if baleManager ~= nil then
        for index, bale in ipairs(baleManager.bales) do
            if bale.customEnvironment ~= nil then
                local mod = g_modManager:getModByName(bale.customEnvironment)

                if mod ~= nil then
                    loadBaleHudOverlaysFromXML(mod.modFile, mod.modDir, mod.modName)
                end
            end
        end
    end
end

function ObjectStorageExtension:delete()
    if self.addConsoleCommands then
        removeConsoleCommand("gtxObjectStorageExtensionToggleGUI")
    end

    ObjectStorageExtension.IN_GAME_MENU_ENABLED = false
end

function ObjectStorageExtension:createSettings()
    local triggersUseInGameMenu = {
        name = "triggersUseInGameMenu",
        id = "objectStorageExtension_triggersUseInGameMenu",
        title = g_i18n:getText("ose_setting_triggersUseInGameMenu", self.customEnvironment),
        toolTip = g_i18n:getText("ose_toolTip_triggersUseInGameMenu", self.customEnvironment),
        state = true
    }

    local useBaleIcons = {
        name = "useBaleIcons",
        id = "objectStorageExtension_useBaleIcons",
        title = g_i18n:getText("ose_setting_useBaleIcons", self.customEnvironment),
        toolTip = g_i18n:getText("ose_toolTip_useBaleIcons", self.customEnvironment),
        state = true,
    }

    self.settings = {
        triggersUseInGameMenu,
        useBaleIcons
    }

    self.settingByName = {
        triggersUseInGameMenu = triggersUseInGameMenu,
        useBaleIcons = useBaleIcons
    }
end

function ObjectStorageExtension:loadSettings()
    if g_dedicatedServerInfo == nil then
        local xmlFile = XMLFile.loadIfExists("objectStorageExtensionXML", self.settingsDirectory .. "settings.xml")

        if xmlFile ~= nil then
            for _, setting in ipairs (self.settings) do
                setting.state = xmlFile:getBool(string.format("objectStorageExtension.%s#state", setting.name), setting.state)
            end

            xmlFile:delete()
        end
    end
end

function ObjectStorageExtension:saveSettings()
    self.settingsChanged = false

    if g_dedicatedServerInfo == nil then
        if not fileExists(self.settingsDirectory) then
            createFolder(self.settingsDirectory)
        end

        local xmlFile = XMLFile.create("objectStorageExtensionXML", self.settingsDirectory .. "settings.xml", "objectStorageExtension")

        if xmlFile ~= nil then
            xmlFile:setString("objectStorageExtension#version", self.versionString)
            xmlFile:setFloat("objectStorageExtension#buildId", self.buildId)

            for _, setting in ipairs (self.settings) do
                xmlFile:setBool(string.format("objectStorageExtension.%s#state", setting.name), setting.state)
            end

            xmlFile:save()
            xmlFile:delete()
        end
    end
end

function ObjectStorageExtension:applySettingState(setting, state, immediateSave)
    if setting ~= nil and setting.state ~= state then
        setting.state = state

        self.settingsChanged = true

        if immediateSave then
            self:saveSettings()
        end
    end
end

function ObjectStorageExtension:getIsSettingEnabled(name, default)
    local setting = self.settingByName[name]

    if setting ~= nil then
        return setting.state == true
    end

    return default == true
end

function ObjectStorageExtension:getBaleIconFilename(fillTypeIndex, isRoundBale)
    if isRoundBale then
        return self.roundBaleIcons[fillTypeIndex]
    end

    return self.squareBaleIcons[fillTypeIndex]
end

function ObjectStorageExtension:consoleCommandToggleGUI()
    ObjectStorageExtension.IN_GAME_MENU_ENABLED = not ObjectStorageExtension.IN_GAME_MENU_ENABLED

    -- Try and rebuild table list if the menu is open
    local inGameMenu = g_inGameMenu

    if inGameMenu ~= nil and inGameMenu.isOpen then
        inGameMenu:updatePages()

        return "In Game Menu - Object Storage GUI: " .. tostring(ObjectStorageExtension.IN_GAME_MENU_ENABLED) .. "  ( Menu open, updating now... )"
    end

    return "In Game Menu - Object Storage GUI: " .. tostring(ObjectStorageExtension.IN_GAME_MENU_ENABLED)
end

function ObjectStorageExtension.loadAdditionalElement(filename, parentGuiElement, target)
    local element = nil

    if parentGuiElement ~= nil then
        local xmlFile = loadXMLFile("AdditionalElementsXML", self.baseDirectory .. filename) or 0

        if xmlFile ~= 0 then
            local gui = g_gui
            local numElements = #parentGuiElement.elements

            gui:loadProfileSet(xmlFile, "GUI.GuiProfiles", gui.presets)
            gui:loadGuiRec(xmlFile, "GUI", parentGuiElement, target)

            if math.max(#parentGuiElement.elements - numElements, 0) > 0 then
                element = parentGuiElement.elements[#parentGuiElement.elements]
                element:updateAbsolutePosition()
            end

            target:exposeControlsAsFields()
            target:onGuiSetupFinished()

            delete(xmlFile)
        end
    end

    return element
end
