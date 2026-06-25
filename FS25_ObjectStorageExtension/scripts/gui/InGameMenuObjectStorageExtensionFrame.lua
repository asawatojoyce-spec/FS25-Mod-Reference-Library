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

InGameMenuObjectStorageExtensionFrame = {}

InGameMenuObjectStorageExtensionFrame.MOD_NAME = g_currentModName
InGameMenuObjectStorageExtensionFrame.MOD_DIR = g_currentModDirectory

InGameMenuObjectStorageExtensionFrame.INFO_BOX_INTERVAL = 5000

InGameMenuObjectStorageExtensionFrame.FILTER_ALL = 1
InGameMenuObjectStorageExtensionFrame.FILTER_BALES = 2
InGameMenuObjectStorageExtensionFrame.FILTER_PALLETS = 3

InGameMenuObjectStorageExtensionFrame.OBJECT_TYPE_SQUARE_BALE = 1
InGameMenuObjectStorageExtensionFrame.OBJECT_TYPE_ROUND_BALE = 2
InGameMenuObjectStorageExtensionFrame.OBJECT_TYPE_PACKED_BALE = 3
InGameMenuObjectStorageExtensionFrame.OBJECT_TYPE_PALLET = 4
InGameMenuObjectStorageExtensionFrame.OBJECT_TYPE_BIG_BAG = 5

local InGameMenuObjectStorageExtensionFrame_mt = Class(InGameMenuObjectStorageExtensionFrame, TabbedMenuFrameElement)
local EMPTY_TABLE = {}

function InGameMenuObjectStorageExtensionFrame.register()
    local objectStorageExtensionFrame = InGameMenuObjectStorageExtensionFrame.new()
    local filename = InGameMenuObjectStorageExtensionFrame.MOD_DIR .. "gui/InGameMenuObjectStorageExtensionFrame.xml"

    g_gui:loadGui(filename, "ObjectStorageExtensionFrame", objectStorageExtensionFrame, true)

    return objectStorageExtensionFrame
end

function InGameMenuObjectStorageExtensionFrame.new(target, custom_mt)
    local self = TabbedMenuFrameElement.new(target, custom_mt or InGameMenuObjectStorageExtensionFrame_mt)

    self.hasCustomMenuButtons = true
    self.useBaleIcons = true

    self.numStoredObjects = 0
    self.maxUnloadAmount = math.huge
    self.spawnCoolDown = 0

    self.infoBoxMessage = ""
    self.infoBoxTime = 0

    self.isReloading = false
    self.isReseting = false

    self.playerFarm = nil

    self.objectStorages = {}
    self.objectStoragesBales = {}
    self.objectStoragesPallets = {}
    self.numStoredObjectsCache = {}

    self.objectTypeIndexes = {}
    self.objectTypeIndexToObjects = {}

    self.detailsTitleText = g_i18n:getText("ui_details") .. ":"
    self.fermentingTitleText = g_i18n:getText("info_fermenting") .. ":"
    self.fermentingValueText = g_i18n:getText("configuration_valueYes")

    self.typeIndexToTitle = {
        g_i18n:getText("fillType_squareBale"),
        g_i18n:getText("fillType_roundBale"),
        g_i18n:getText("ose_objectType_packedBale", InGameMenuObjectStorageExtensionFrame.MOD_NAME),
        g_i18n:getText("infohud_pallet"),
        g_i18n:getText("shopItem_bigBag")
    }

    return self
end

function InGameMenuObjectStorageExtensionFrame.createFromExistingGui(gui, guiName)
    local newGui = InGameMenuObjectStorageExtensionFrame.new()

    g_gui.frames[gui.name].target:delete()
    g_gui.frames[gui.name]:delete()
    g_gui:loadGui(gui.xmlFilename, guiName, newGui, true)

    return newGui
end

function InGameMenuObjectStorageExtensionFrame:initialize()
    self.backButtonInfo = {
        inputAction = InputAction.MENU_BACK
    }

    self.nextPageButtonInfo = {
        inputAction = InputAction.MENU_PAGE_NEXT,
        text = g_i18n:getText("ui_ingameMenuNext"),
        callback = self.onPageNext
    }

    self.prevPageButtonInfo = {
        inputAction = InputAction.MENU_PAGE_PREV,
        text = g_i18n:getText("ui_ingameMenuPrev"),
        callback = self.onPagePrevious
    }

    self.hotspotButtonInfo = {
        profile = "buttonHotspot",
        inputAction = InputAction.MENU_CANCEL,
        text = g_i18n:getText("button_showOnMap"),
        callback = function ()
            self:onButtonHotspot()
        end
    }

    self.visitButtonInfo = {
        profile = "buttonVisitPlace",
        inputAction = InputAction.MENU_ACTIVATE,
        text = g_i18n:getText("action_visit"),
        callback = function ()
            self:onButtonVisit()
        end
    }

    self.configurationStartButtonInfo = {
        inputAction = InputAction.MENU_EXTRA_2,
        text = g_i18n:getText("shop_configuration"),
        callback = function ()
            self:onButtonConfigurationStart()
        end
    }

    self.configurationResetButtonInfo = {
        inputAction = InputAction.MENU_EXTRA_2,
        text = g_i18n:getText("button_reset"),
        callback = function ()
            self:onButtonConfigurationReset(false)
        end
    }

    self.configurationResetAllButtonInfo = {
        inputAction = InputAction.MENU_EXTRA_1,
        text = g_i18n:getText("button_defaults"),
        callback = function ()
            self:onButtonConfigurationReset(true)
        end
    }

    self.configurationBackButtonInfo = {
        inputAction = InputAction.MENU_BACK,
        text = g_i18n:getText("button_back"),
        callback = function ()
            self:onButtonConfigurationBack()
        end
    }

    self.selectButtonInfo = {
        inputAction = InputAction.MENU_ACCEPT,
        text = g_i18n:getText("button_select"),
        callback = function ()
            self:onButtonSelect()
        end
    }

    self.spawnButtonInfo = {
        inputAction = InputAction.MENU_ACCEPT,
        text = g_i18n:getText("ose_button_spawnObjects", InGameMenuObjectStorageExtensionFrame.MOD_NAME),
        callback = function ()
            self:onButtonSpawn()
        end
    }

    self.menuButtonInfo = {
        self.backButtonInfo,
        self.nextPageButtonInfo,
        self.prevPageButtonInfo,
    }

    self.headerText = g_i18n:getText("ose_ui_headerTitle", InGameMenuObjectStorageExtensionFrame.MOD_NAME)
    self.headerConfigurationText = string.format("%s - %s", self.headerText, g_i18n:getText("shop_configuration"))

    local filterAndConfigTexts = {
        g_i18n:getText("ose_category_all", InGameMenuObjectStorageExtensionFrame.MOD_NAME),
        g_i18n:getText("category_bales"),
        g_i18n:getText("category_pallets")
    }

    -- Filter Texts
    self.objectStorageListsSelector:setTexts(filterAndConfigTexts)

    -- Configuration Texts
    self.multiAcceptedObjectTypes:setTexts(filterAndConfigTexts)

    -- Update dot elements based on selection
    for i = 1, #self.objectStorageListsDotBox.elements do
        self.objectStorageListsDotBox.elements[i].getIsSelected = function()
            return self.objectStorageListsSelector:getState() == i
        end
    end

    self.objectStorageListsDotBox:invalidateLayout()

    -- Use selected state if reference element has focus
    self.objectStorageTypesBoxBg.getIsSelected = function()
        return self.objectStorageList:getIsFocused() or self.objectStorageListsSelector:getIsFocused()
    end

    self.objectStorageTypesBoxBgArrow.getIsSelected = function()
        return self.objectStorageList:getIsFocused() or self.objectStorageListsSelector:getIsFocused()
    end

    self.objectsBoxBg.getIsSelected = function()
        return self.objectsList:getIsFocused()
    end

    self.objectsBoxBgTop.getIsSelected = function()
        return self.objectsList:getIsFocused()
    end

    self.objectsBoxBgArrow.getIsSelected = function()
        return self.objectsList:getIsFocused()
    end

    self.numObjectsBoxBg.getIsSelected = function()
        return self.numObjectsOptionSlider:getIsFocused()
    end

    local numObjectsBox = self.numObjectsBox


    self.numObjectsOptionSlider.mouseEvent = function(optionSlider, posX, posY, isDown, isUp, button, eventUsed)
        -- Ignore all mouse inputs except Left button, allows the slider to work correctly when using mouse wheel mainly
        if not self.configurationsActive and GuiUtils.checkOverlayOverlap(posX, posY, numObjectsBox.absPosition[1], numObjectsBox.absPosition[2], numObjectsBox.absSize[1], numObjectsBox.absSize[2]) then
            if (isDown or isUp) and button ~= Input.MOUSE_BUTTON_LEFT then
                return eventUsed
            end
        end

        -- Allow users to focus the slider when clicking the bar even if there is only 1 object stored
        local eventUsed = OptionSliderElement.mouseEvent(optionSlider, posX, posY, isDown, isUp, button, eventUsed)

        if optionSlider.isSliderAreaPressed and not optionSlider:getIsFocused() then
            FocusManager:setFocus(optionSlider)
        end

        return eventUsed
    end

    FocusManager:linkElements(self.objectStorageList, FocusManager.LEFT, nil)
    FocusManager:linkElements(self.objectStorageList, FocusManager.RIGHT, self.objectsList)
    FocusManager:linkElements(self.objectStorageList, FocusManager.TOP, self.objectStorageListsSelector)
    FocusManager:linkElements(self.objectStorageList, FocusManager.BOTTOM, nil)

    FocusManager:linkElements(self.objectsList, FocusManager.LEFT, self.objectStorageList)
    FocusManager:linkElements(self.objectsList, FocusManager.RIGHT, self.numObjectsOptionSlider)
    FocusManager:linkElements(self.objectsList, FocusManager.TOP, nil)
    FocusManager:linkElements(self.objectsList, FocusManager.BOTTOM, nil)

    FocusManager:linkElements(self.numObjectsOptionSlider, FocusManager.TOP, self.objectsList)
    FocusManager:linkElements(self.numObjectsOptionSlider, FocusManager.BOTTOM, self.objectsList)
end

function InGameMenuObjectStorageExtensionFrame:onFrameOpen()
    InGameMenuObjectStorageExtensionFrame:superClass().onFrameOpen(self)

    g_messageCenter:subscribe(MessageType.OSE_PLACEABLES_CHANGED, self.onPlaceablesChanged, self)
    g_messageCenter:subscribe(MessageType.OSE_OBJECT_INFOS_CHANGED, self.onObjectInfosChanged, self)

    if g_objectStorageExtension ~= nil then
        self.useBaleIcons = g_objectStorageExtension:getIsSettingEnabled("useBaleIcons", true)
    else
        self.useBaleIcons = true
    end

    self.configurationsChanged = false
    self:setConfigurationsActive(false)

    self:updateObjectStorageLists()

    if self.objectStorageList:getItemCount() > 0 then
        FocusManager:setFocus(self.objectStorageList)
    else
        FocusManager:setFocus(self.objectStorageListsSelector)
    end

    self.isOpen = true

    g_inputBinding:registerActionEvent(InputAction.AXIS_MTO_SCROLL, self, self.onNumberObjectsScroll, false, false, true, true)
end

function InGameMenuObjectStorageExtensionFrame:onFrameClose()
    InGameMenuObjectStorageExtensionFrame:superClass().onFrameClose(self)

    g_messageCenter:unsubscribe(MessageType.OSE_PLACEABLES_CHANGED, self)
    g_messageCenter:unsubscribe(MessageType.OSE_OBJECT_INFOS_CHANGED, self)

    g_inputBinding:removeActionEventsByTarget(self)

    self.isOpen = false

    self.selectedObjectStorage = nil
    self.selectedObjectInfo = nil
    self.numStoredObjects = 0

    self.configurationsChanged = false
    self:setConfigurationsActive(false)

    self:setInfoMessage("", false, true)
end

function InGameMenuObjectStorageExtensionFrame:update(dt)
    InGameMenuObjectStorageExtensionFrame:superClass().update(self, dt)

    if self.spawnCoolDown > 0 then
        self.spawnCoolDown -= dt

        if self.spawnCoolDown <= 0 then
            self.spawnCoolDown = 0

            self.numObjectsOptionSlider:setState(1)

            if not self.isReloading then
                self:updateMenuButtons()
            end
        end
    end

    if self.infoBoxTime > 0 then
        self.infoBoxTime -= dt

        if self.infoBoxTime <= 0 then
            self:setInfoMessage("", false, true)
        end
    end
end

function InGameMenuObjectStorageExtensionFrame:updateObjectStorageLists()
    local objectStorages, objectStoragesBales, objectStoragesPallets, numStoredObjectsCache = {}, {}, {}, {}

    for _, placeable in ipairs(g_currentMission.placeableSystem.placeables) do
        if placeable.ownerFarmId == self.playerFarmId and placeable.spec_objectStorage ~= nil then
            if not placeable.markedForDeletion and not placeable.isDeleted and not placeable.isDeleting then
                table.insert(objectStorages, placeable)
            end
        end
    end

    table.sort(objectStorages, InGameMenuObjectStorageExtensionFrame.objectStorageSorter)

    for _, placeable in ipairs(objectStorages) do
        local spec = placeable.spec_objectStorage

        numStoredObjectsCache[placeable] = spec.numStoredObjects

        if spec.supportsBales then
            table.insert(objectStoragesBales, placeable)
        end

        if spec.supportsPallets then
            table.insert(objectStoragesPallets, placeable)
        end
    end

    self.isReloading = true

    self.objectStorages = objectStorages
    self.objectStoragesBales = objectStoragesBales
    self.objectStoragesPallets = objectStoragesPallets
    self.numStoredObjectsCache = numStoredObjectsCache

    local selectedObjectStorage = self.selectedObjectStorage
    local oldObjectInfo = self.selectedObjectInfo
    local hasObjectStorages = #objectStorages > 0
    local filterHasObjectStorages = false
    local hasObjectsStored = false
    local isFiltered = false

    self.selectedObjectStorage = nil
    self.selectedObjectInfo = nil
    self.numStoredObjects = 0

    self.objectStorageList:reloadData()

    if hasObjectStorages then
        local state = self.objectStorageListsSelector:getState()
        local filteredPlaceables = self:getFilteredObjectStorages()

        for i, placeable in ipairs(filteredPlaceables) do
            if placeable == selectedObjectStorage then
                self.objectStorageList:setSelectedIndex(i)

                break
            end
        end

        filterHasObjectStorages = self.objectStorageList:getItemCount() > 0
        isFiltered = state ~= InGameMenuObjectStorageExtensionFrame.FILTER_ALL
        self.objectStorageListsContainer:setDisabled(false)
    else
        self.objectStorageListsSelector:setState(InGameMenuObjectStorageExtensionFrame.FILTER_ALL, false)
        self.objectStorageListsContainer:setDisabled(true)

        if not self.objectStorageList:getIsFocused() then
            FocusManager:setFocus(self.objectStorageList)
        end
    end

    if filterHasObjectStorages then
        self.objectsList:reloadData()

        if self.numStoredObjects > 0 and #self.objectTypeIndexes > 0 then
            local newObjectInfo = self.selectedObjectInfo

            hasObjectsStored = true

            if newObjectInfo ~= nil and newObjectInfo.abstractObject ~= nil and oldObjectInfo ~= nil and oldObjectInfo.abstractObject ~= nil then
                local section, objectInfos = 0, nil

                for i, objectTypeIndex in ipairs (self.objectTypeIndexes) do
                    if oldObjectInfo.objectTypeIndex == objectTypeIndex then
                        objectInfos = self.objectTypeIndexToObjects[objectTypeIndex]
                        section = i

                        break
                    end
                end

                if oldObjectInfo.objectInfoIndex ~= newObjectInfo.objectInfoIndex or not oldObjectInfo.abstractObject:getIsIdentical(newObjectInfo.abstractObject) then
                    for index, objectInfo in ipairs (objectInfos or EMPTY_TABLE) do
                        if objectInfo.abstractObject ~= nil and objectInfo.abstractObject:getIsIdentical(oldObjectInfo.abstractObject) then
                            self.objectsList:setSelectedItem(section, index, false, false)
                        end
                    end
                end
            end
        end
    end

    local containerVisibile = filterHasObjectStorages and hasObjectsStored

    self.objectsBoxBg:setVisible(containerVisibile)
    self.objectsContainer:setVisible(containerVisibile)
    self.detailsContainer:setVisible(containerVisibile)

    self.noFilterObjectStoragesElement:setVisible(hasObjectStorages and isFiltered and not filterHasObjectStorages)
    self.noObjectStoragesElement:setVisible(not hasObjectStorages)
    self.storageIsEmptyElement:setVisible(hasObjectStorages and filterHasObjectStorages and not hasObjectsStored)

    if not hasObjectStorages or not hasObjectsStored then
        if not self.objectStorageList:getIsFocused() then
            FocusManager:setFocus(self.objectStorageList)
        end
    end

    if self.spawnCoolDown ~= 0 then
        self.spawnCoolDown = 0

        self.numObjectsOptionSlider:setState(1)

        if self.infoBoxIsSpawnMessage then
            self:setInfoMessage("", false, true)
        end
    end

    if self.configurationsActive then
        self:onButtonConfigurationStart()
    end

    self.isReloading = false

    self:updateMenuButtons()
end

function InGameMenuObjectStorageExtensionFrame:updateMenuButtons()
    self.menuButtonInfo = {
        self.backButtonInfo,
        self.nextPageButtonInfo,
        self.prevPageButtonInfo
    }

    local placeable = self:getSelectedObjectStorage()

    if placeable ~= nil then
        if not self.configurationsActive then
            if self.objectStorageList:getIsFocused() or self.objectStorageListsSelector:getIsFocused() then
                local hotspot = placeable:getHotspot()

                if hotspot ~= nil then
                    if hotspot == g_currentMission.currentMapTargetHotspot then
                        self.hotspotButtonInfo.text = g_i18n:getText("action_untag")
                    else
                        self.hotspotButtonInfo.text = g_i18n:getText("action_tag")
                    end

                    table.insert(self.menuButtonInfo, self.hotspotButtonInfo)

                    if hotspot:getBeVisited() then
                        table.insert(self.menuButtonInfo, self.visitButtonInfo)
                    end
                end

                local canBeConfigured = true

                if canBeConfigured then
                    table.insert(self.menuButtonInfo, self.configurationStartButtonInfo)
                end
            elseif self.objectsList:getIsFocused() then
                table.insert(self.menuButtonInfo, self.selectButtonInfo)
            elseif self.numObjectsOptionSlider:getIsFocused() and self.spawnCoolDown <= 0 then
                table.insert(self.menuButtonInfo, self.spawnButtonInfo)
            end
        elseif placeable.spec_objectStorageExtension ~= nil then
            self.menuButtonInfo[1] = self.configurationBackButtonInfo

            local configurationId = self:getFocusedElementConfigurationId()
            local isConfigured, focusedElementIsConfigured = placeable:getObjectStorageIsConfigured(configurationId)

            if isConfigured then
                if focusedElementIsConfigured then
                    table.insert(self.menuButtonInfo, self.configurationResetButtonInfo)
                end

                table.insert(self.menuButtonInfo, self.configurationResetAllButtonInfo)
            end
        end
    end

    self:setMenuButtonInfoDirty()
end

function InGameMenuObjectStorageExtensionFrame:getFocusedElementConfigurationId()
    if self.binaryToggleInputTrigger:getIsFocused() then
        return PlaceableObjectStorageExtensionEvent.INPUT_TRIGGER
    elseif self.textTotalCapacity:getIsFocused() then
        return PlaceableObjectStorageExtensionEvent.TOTAL_CAPACITY
    elseif self.multiAcceptedObjectTypes:getIsFocused() then
        return PlaceableObjectStorageExtensionEvent.OBJECT_TYPE
    end

    return 0
end

function InGameMenuObjectStorageExtensionFrame:onConfigurationFocusedChanged(element)
    self.lastFocusedConfigurationElement = element
    self:updateMenuButtons()
end

function InGameMenuObjectStorageExtensionFrame:setConfigurationsActive(active, updateFocus)
    self.configurationsActive = active

    if not active then
        self.lastObjectTypesState = 0
        self.minTotalCapacity = 1
        self.maxTotalCapacity = 250
        self.currentTotalCapacity = 250
        self.lastFocusedConfigurationElement = nil
    end

    self.mainContainer:setVisible(not active)
    self.configurationContainer:setVisible(active)

    -- self.objectStorageListsSelector:setDisabled(active)
    -- self.objectStorageList:setDisabled(active)

    if self.menuHeaderTitle ~= nil then
        self.menuHeaderTitle:setText(active and self.headerConfigurationText or self.headerText)
    end

    if updateFocus then
        FocusManager:setFocus(active and self.binaryToggleInputTrigger or self.objectStorageList)
    end
end

function InGameMenuObjectStorageExtensionFrame:populateCellForItemInSection(list, section, index, cell)
    if list == self.objectStorageList then
        local objectStorages = self:getFilteredObjectStorages()
        local placeable = objectStorages[index]
        local spec = placeable.spec_objectStorage

        cell:getAttribute("name"):setText(placeable:getName())

        local icon = cell:getAttribute("icon")
        local iconPreplaced = cell:getAttribute("iconCustom")

        if placeable.customImageFilename == nil then
            iconPreplaced:setVisible(false)

            icon:setImageFilename(placeable:getImageFilename())
            icon:setVisible(true)
        else
            icon:setVisible(false)

            iconPreplaced:setImageFilename(placeable.customImageFilename)
            iconPreplaced:setVisible(true)
        end

        cell:getAttribute("numObjects"):setText(string.format("%d / %d", spec.numStoredObjects, spec.capacity))

        local inputTriggerState = false

        if placeable.getObjectStorageInputTriggerDisabled ~= nil then
            inputTriggerState = placeable:getObjectStorageInputTriggerDisabled()
        end

        cell:getAttribute("inputState"):applyProfile(inputTriggerState and "ose_placeablesListItemInputStateOff" or "ose_placeablesListItemInputState")
        cell:getAttribute("supportsBales"):applyProfile(not spec.supportsBales and "ose_placeablesListItemSupportsBalesOff" or "ose_placeablesListItemSupportsBales")
        cell:getAttribute("supportsPallets"):applyProfile(not spec.supportsPallets and "ose_placeablesListItemSupportsPalletsOff" or "ose_placeablesListItemSupportsPallets")
    elseif list == self.objectsList then
        local typeIndex = self.objectTypeIndexes[section]
        local objectInfos = self.objectTypeIndexToObjects[typeIndex]

        if objectInfos ~= nil and objectInfos[index] ~= nil then
            local objectInfo = objectInfos[index]
            local iconElement = cell:getAttribute("icon")

            if objectInfo.imageFilename ~= nil then
                iconElement:setImageFilename(objectInfo.imageFilename)
                iconElement:setVisible(true)
            else
                iconElement:setVisible(false)
            end

            cell:getAttribute("name"):setText(objectInfo.title)
            cell:getAttribute("numObjects"):setText(string.format("x%d", objectInfo.numObjects or 0))
            cell:getAttribute("size"):setText(objectInfo.sizeText or "")
            cell:getAttribute("fermenting"):setVisible(objectInfo.isFermenting == true)
        end
    end
end

function InGameMenuObjectStorageExtensionFrame:onListSelectionChanged(list, section, index)
    if list == self.objectStorageList then
        local objectStorages = self:getFilteredObjectStorages()
        local selectedObjectStorage = objectStorages[index]
        local numStoredObjects, maxUnloadAmount = 0, math.huge

        self.selectedObjectStorage = selectedObjectStorage

        self.objectTypeIndexes = {}
        self.objectTypeIndexToObjects = {}

        if selectedObjectStorage ~= nil then
            selectedObjectStorage:updateDirtyObjectStorageObjectInfos()
            numStoredObjects = selectedObjectStorage.spec_objectStorage.numStoredObjects or 0
            maxUnloadAmount = selectedObjectStorage.spec_objectStorage.maxUnloadAmount or 0

            local roundBaleText, squareBaleText, bigBagText, palletText, addedObjectTypeIndexes = nil, nil, nil, nil, {}
            local objectInfos = selectedObjectStorage:getObjectStorageObjectInfos()

            self.selectedObjectInfos = objectInfos

            for i, objectInfo in ipairs (objectInfos) do
                local abstractObject = objectInfo.objects[1]

                if abstractObject ~= nil then
                    local className = abstractObject.REFERENCE_CLASS_NAME
                    local isPackedBale = className == "PackedBale"

                    local info = {
                        isBale = className == "Bale" or isPackedBale,
                        objectInfoIndex = i
                    }

                    if info.isBale then
                        info.isPackedBale = isPackedBale

                        if abstractObject.baleObject == nil then
                            info.xmlFilename = abstractObject.baleAttributes.xmlFilename
                            info.fillTypeIndex = abstractObject.baleAttributes.fillType
                            info.fillLevel = abstractObject.baleAttributes.fillLevel
                            info.isFermenting = abstractObject.baleAttributes.isFermenting
                        else
                            info.xmlFilename = abstractObject.baleObject.xmlFilename
                            info.fillTypeIndex = abstractObject.baleObject:getFillType()
                            info.fillLevel = abstractObject.baleObject:getFillLevel()
                            info.isFermenting = abstractObject.baleObject.isFermenting

                            if info.isFermenting then
                                local fermentingPercentage = abstractObject.baleObject:getFermentingPercentage() or 0
                                local nextPercentage = fermentingPercentage

                                -- Find the highest percentage to display
                                for _, object in ipairs (objectInfo.objects) do
                                    if object.baleObject ~= nil then
                                        nextPercentage = object.baleObject:getFermentingPercentage() or 0

                                        if nextPercentage > fermentingPercentage then
                                            fermentingPercentage = nextPercentage
                                        end
                                    end
                                end

                                info.fermentingPercentage = fermentingPercentage
                            end
                        end

                        info.title = g_fillTypeManager:getFillTypeTitleByIndex(info.fillTypeIndex) or "Unknown"

                        local isRoundBale, _, _, length, diameter = g_baleManager:getBaleInfoByXMLFilename(info.xmlFilename, true)

                        info.isRoundBale = isRoundBale
                        info.diameter = diameter
                        info.length = length
                        info.objectTypeIndex = InGameMenuObjectStorageExtensionFrame[not isPackedBale and (isRoundBale and "OBJECT_TYPE_ROUND_BALE" or "OBJECT_TYPE_SQUARE_BALE") or "OBJECT_TYPE_PACKED_BALE"]
                        info.sizeText = string.format("%dcm",((isRoundBale and diameter or length) or 0) * 100)
                        info.typeName = string.format("%s  ( %s )", self.typeIndexToTitle[info.objectTypeIndex], info.sizeText)
                    else
                        local palletAttributes = abstractObject.palletAttributes

                        if palletAttributes ~= nil then
                            if palletAttributes.fillType == nil or palletAttributes.fillType == FillType.UNKNOWN then
                                local storeItem = g_storeManager:getItemByXMLFilename(palletAttributes.configFileName)

                                if storeItem ~= nil then
                                    info.title = storeItem.name or "Unknown"
                                    info.imageFilename = storeItem.imageFilename
                                else
                                    info.title = "Unknown"
                                end
                            else
                                info.fillTypeIndex = palletAttributes.fillType
                                info.fillLevel = palletAttributes.fillLevel
                                info.title = g_fillTypeManager:getFillTypeTitleByIndex(info.fillTypeIndex) or "Unknown"
                            end

                            info.isBigBag = palletAttributes.isBigBag
                        else
                            info.isBigBag = false
                            info.fillTypeIndex = FillType.UNKNOWN
                            info.fillLevel = 0
                            info.title = "Unknown Class"
                        end

                        info.objectTypeIndex = InGameMenuObjectStorageExtensionFrame[info.isBigBag and "OBJECT_TYPE_BIG_BAG" or "OBJECT_TYPE_PALLET"]
                        info.typeName = self.typeIndexToTitle[info.objectTypeIndex]
                    end

                    info.placeable = selectedObjectStorage
                    info.numObjects = objectInfo.numObjects

                    if info.imageFilename == nil then
                        info.imageFilename = InGameMenuObjectStorageExtensionFrame.getObjectImageFilename(info.fillTypeIndex, self.useBaleIcons and info.isBale, info.isRoundBale)
                    end

                    if abstractObject.getIsIdentical ~= nil then
                        info.abstractObject = abstractObject
                    end

                    local objectTypeIndex = info.objectTypeIndex

                    if not addedObjectTypeIndexes[objectTypeIndex] then
                        addedObjectTypeIndexes[objectTypeIndex] = true

                        table.insert(self.objectTypeIndexes, objectTypeIndex)
                    end

                    if self.objectTypeIndexToObjects[objectTypeIndex] == nil then
                        self.objectTypeIndexToObjects[objectTypeIndex] = {}
                    end

                    table.insert(self.objectTypeIndexToObjects[objectTypeIndex], info)
                end
            end
        end

        self.numStoredObjects = numStoredObjects
        self.maxUnloadAmount = maxUnloadAmount

        local hasObjectsStored = #self.objectTypeIndexes > 0

        self.objectsBoxBg:setVisible(hasObjectsStored)
        self.objectsContainer:setVisible(hasObjectsStored)
        self.detailsContainer:setVisible(hasObjectsStored)

        self.storageIsEmptyElement:setVisible(not hasObjectsStored)

        if hasObjectsStored then
            table.sort(self.objectTypeIndexes)

            for _, infos in pairs (self.objectTypeIndexToObjects) do
                table.sort(infos, InGameMenuObjectStorageExtensionFrame.objectInfoSorter)
            end

            self.objectsList:reloadData()

            if not self.isReloading then
                self.objectsList:setSelectedIndex(1)
            end
        end

        if self.configurationsActive and not self.isReloading then
            self:onButtonConfigurationStart()
        end
    elseif list == self.objectsList then
        local typeIndex = self.objectTypeIndexes[section]
        local objectInfos = self.objectTypeIndexToObjects[typeIndex]
        local objectInfo = objectInfos[index]

        if objectInfo.imageFilename ~= nil then
            self.detailsIcon:setImageFilename(objectInfo.imageFilename)
            self.detailsIcon:setVisible(true)
        else
            self.detailsIcon:setVisible(false)
        end

        self.detailsName:setText(objectInfo.title)
        self.detailsTypeValue:setText(objectInfo.typeName)

        self.detailsFillLevelValue:setText(g_i18n:formatFluid(objectInfo.fillLevel or 0))

        if objectInfo.isFermenting then
            self.detailsExtraTitle:setText(self.fermentingTitleText)

            if objectInfo.fermentingPercentage ~= nil then
                self.detailsExtraValue:setText(string.format("%d%%", objectInfo.fermentingPercentage * 100))
            else
                self.detailsExtraValue:setText(self.fermentingValueText)
            end
        else
            self.detailsExtraTitle:setText(self.detailsTitleText)
            self.detailsExtraValue:setText("N/A")
        end

        local maxUnloadAmount = math.min(self.maxUnloadAmount, objectInfo.numObjects)

        if objectInfo.amountTexts == nil or #objectInfo.amountTexts ~= maxUnloadAmount then
            objectInfo.amountTexts = {}

            for i = 1, maxUnloadAmount do
                table.insert(objectInfo.amountTexts, string.format("%d / %d", i, objectInfo.numObjects))
            end
        end

        self.numObjectsOptionSlider:setTexts(objectInfo.amountTexts)

        if not self.isReloading then
            self.numObjectsOptionSlider:setState(1)
        end

        self.selectedObjectInfo = objectInfo
    end

    if self.selectedObjectStorage ~= nil then
        self:updateMenuButtons()
    end
end

function InGameMenuObjectStorageExtensionFrame:onNumberObjectsScroll(_, inputValue)
    if inputValue ~= 0 and self.numObjectsOptionSlider:getIsFocused() then
        self.numObjectsOptionSlider:setState(self.numObjectsOptionSlider:getState() + inputValue, true)
    end
end

function InGameMenuObjectStorageExtensionFrame:onButtonHotspot()
    local placeable = self:getSelectedObjectStorage()

    if placeable ~= nil then
        local hotspot = placeable:getHotspot()

        if hotspot ~= nil then
            if g_currentMission.currentMapTargetHotspot == hotspot then
                g_currentMission:setMapTargetHotspot(nil)
            else
                g_currentMission:setMapTargetHotspot(hotspot)
            end

            self:updateMenuButtons()

            return
        end

        g_currentMission:setMapTargetHotspot(nil)
    end
end

function InGameMenuObjectStorageExtensionFrame:onButtonVisit()
    local placeable = self:getSelectedObjectStorage()

    if placeable ~= nil then
        local hotspot = placeable:getHotspot()

        if hotspot ~= nil then
            local x, y, z = hotspot:getTeleportWorldPosition()

            if x ~= nil and y ~= nil and z ~= nil then
                if g_localPlayer:getCurrentVehicle() ~= nil then
                    g_localPlayer:leaveVehicle()
                end

                g_localPlayer:teleportTo(x, y, z)
                g_gui:changeScreen(nil)
            end
        end
    end
end

function InGameMenuObjectStorageExtensionFrame:onButtonConfigurationStart()
    local placeable = self:getSelectedObjectStorage()

    if placeable == nil or placeable.spec_objectStorageExtension == nil then
        self:setInfoMessage(g_i18n:getText("warning_actionNotAllowedNow"), true, true, 2000)

        return
    end

    if not g_currentMission:getHasPlayerPermission(Farm.PERMISSION.BUY_PLACEABLE) then
        self:setInfoMessage(string.format("%s\n\n%s", g_i18n:getText("shop_messageNoPermissionGeneral"), g_i18n:getText("ui_permissions_buyPlaceable")), true, true, 2000)

        return
    end

    local spec = placeable.spec_objectStorageExtension
    local objectStorageSpec = placeable.spec_objectStorage

    self.binaryToggleInputTrigger:setIsChecked(not spec.objectTriggerDisabled, not self.isReloading or self.isReseting, false)

    self.currentTotalCapacity = objectStorageSpec.capacity
    self.minTotalCapacity = math.max(objectStorageSpec.numStoredObjects, 1)
    self.maxTotalCapacity = math.max(spec.defaultCapacity, 1000)

    local capacityString = tostring(objectStorageSpec.capacity)

    self.textTotalCapacity.lastValidText = capacityString

    if not self.textTotalCapacity.isCapturingInput then
        self.textTotalCapacity:setText(capacityString)
    end

    self.textTotalCapacity:setDisabled(not spec.supportsTotalCapacityConfiguration)
    self.multiAcceptedObjectTypes:setDisabled(not spec.supportsObjectTypesConfiguration)

    if not self.isReloading or self.isReseting then
        -- local lastObjectTypesState = PlaceableObjectStorageExtension.getSupportedObjectTypeId(objectStorageSpec.supportsBales, objectStorageSpec.supportsPallets)

        self.multiAcceptedObjectTypes:setState(spec.supportedTypeId)
        self.lastObjectTypesState = spec.supportedTypeId

        self.configurationsChanged = false
    end

    if not self.configurationsActive then
        self:setConfigurationsActive(true, true)
    end

    if self.lastFocusedConfigurationElement ~= nil then
        FocusManager:setFocus(self.lastFocusedConfigurationElement)
    end

    self:updateMenuButtons()
end

function InGameMenuObjectStorageExtensionFrame:onButtonConfigurationReset(resetAll)
    if not self.configurationsActive then
        return
    end

    local placeable = self:getSelectedObjectStorage()

    if placeable == nil or placeable.spec_objectStorageExtension == nil then
        return
    end

    if not g_currentMission:getHasPlayerPermission(Farm.PERMISSION.BUY_PLACEABLE) then
        self.configurationsChanged = false
        self:onButtonConfigurationBack()

        self:setInfoMessage(string.format("%s\n\n%s", g_i18n:getText("shop_messageNoPermissionGeneral"), g_i18n:getText("ui_permissions_buyPlaceable")), true, true, 2000)

        return
    end

    if resetAll then
        local function resetToDefaultCallback(yes)
            if yes then
                placeable:resetObjectStorageConfiguration(0)
            end
        end

        YesNoDialog.show(resetToDefaultCallback, nil, g_i18n:getText("ose_ui_resetAll", InGameMenuObjectStorageExtensionFrame.MOD_NAME))
    else
        placeable:resetObjectStorageConfiguration(self:getFocusedElementConfigurationId())
    end
end

function InGameMenuObjectStorageExtensionFrame:onButtonConfigurationBack()
    self:setConfigurationsActive(false, true)

    self.minTotalCapacity = 1
    self.maxTotalCapacity = 250
    self.currentTotalCapacity = 250

    self:updateObjectStorageLists()

    if self.configurationsChanged then
        self.configurationsChanged = false

        self:setInfoMessage(g_i18n:getText("shop_messageConfigurationChanged"), false, true, 2000)
    end
end

function InGameMenuObjectStorageExtensionFrame:onButtonSelect()
    if self.objectStorageList:getIsFocused() then
        FocusManager:setFocus(self.objectsList)
    elseif self.objectsList:getIsFocused() then
        FocusManager:setFocus(self.numObjectsOptionSlider)

        return true
    end

    return false
end

function InGameMenuObjectStorageExtensionFrame:onButtonSpawn()
    if self.spawnCoolDown > 0 then
        self:playSample(GuiSoundPlayer.SOUND_SAMPLES.ERROR)

        return true
    end

    if self.selectedObjectInfo ~= nil then
        local placeable = self.selectedObjectInfo.placeable
        local objectInfoIndex = self.selectedObjectInfo.objectInfoIndex
        local amount = math.min(self.numObjectsOptionSlider:getState(), self.selectedObjectInfo.numObjects)

        if placeable ~= nil and objectInfoIndex ~= nil and amount > 0 then
            g_client:getServerConnection():sendEvent(PlaceableObjectStorageUnloadEvent.new(placeable, objectInfoIndex, amount))

            self.spawnCoolDown = math.max(g_currentDt * amount, 1500)
            self:updateMenuButtons()

            self:setInfoMessage(g_i18n:getText("ose_ui_updating", InGameMenuObjectStorageExtensionFrame.MOD_NAME), false, true, self.spawnCoolDown)
            self.infoBoxIsSpawnMessage = true

            return false
        end
    end

    self:setInfoMessage(g_i18n:getText("warning_actionNotAllowedNow"), true)
end

function InGameMenuObjectStorageExtensionFrame:onClickToggleInputTrigger(state, binaryOptionElement)
    self:onConfigurationChanged(PlaceableObjectStorageExtensionEvent.INPUT_TRIGGER, state == 1)
end

function InGameMenuObjectStorageExtensionFrame:onEnterTotalCapacity(textInputElement, mouseClickedOutside)
    FocusManager:setFocus(textInputElement) -- hadFocusOnCapture fix

    local value = tonumber(textInputElement.text)

    if value == nil then
        textInputElement.lastValidText = tostring(self.currentTotalCapacity)
        textInputElement:setText(textInputElement.lastValidText)

        return
    end

    if value >= self.minTotalCapacity and value <= self.maxTotalCapacity then
        self:onConfigurationChanged(PlaceableObjectStorageExtensionEvent.TOTAL_CAPACITY, value)
    else
        local message = g_i18n:getText("warning_actionNotAllowedNow")

        if self.minTotalCapacity == 1 or value > self.minTotalCapacity then
            message = string.format("%s\n\n%s: %d > %d", message, g_i18n:getText("infohud_range"), self.minTotalCapacity, self.maxTotalCapacity)
        else
            local fillLevelText = "Fill Level" -- Incorrectly written in EN translation so fixed here :-)

            if g_languageShort ~= "en" then
                fillLevelText = g_i18n:getText("infohud_fillLevel")
            end

            message = string.format("%s\n\n%s: %d", message, fillLevelText, self.minTotalCapacity)
        end

        InfoDialog.show(message, nil, nil, DialogElement.TYPE_WARNING)

        textInputElement.lastValidText = tostring(self.currentTotalCapacity)
        textInputElement:setText(textInputElement.lastValidText)
    end
end

function InGameMenuObjectStorageExtensionFrame:onEscTotalCapacity(textInputElement, mouseClickedOutside)
    FocusManager:setFocus(textInputElement) -- hadFocusOnCapture fix

    textInputElement.lastValidText = tostring(self.currentTotalCapacity)
    textInputElement:setText(textInputElement.lastValidText)
end

function InGameMenuObjectStorageExtensionFrame:onTextChangedTotalCapacity(textInputElement, text)
    if not string.isNilOrWhitespace(text) then
        if string.match(text, "^[0-9]+$") ~= nil then
            local value = tonumber(text)

            if value >= self.minTotalCapacity and value <= self.maxTotalCapacity then
                textInputElement.lastValidText = text
            end
        else
            textInputElement:setText(textInputElement.lastValidText or "250")
        end
    end
end

function InGameMenuObjectStorageExtensionFrame:onClickAcceptedObjectTypes(state, multiTextOptionElement)
    if self.lastObjectTypesState ~= state then
        self.lastObjectTypesState = state

        self:onConfigurationChanged(PlaceableObjectStorageExtensionEvent.OBJECT_TYPE, state)
    end
end

function InGameMenuObjectStorageExtensionFrame:onConfigurationChanged(configurationId, value)
    local placeable = self:getSelectedObjectStorage()

    if placeable == nil or placeable.spec_objectStorageExtension == nil or configurationId == nil or value == nil then
        return
    end

    if not g_currentMission:getHasPlayerPermission(Farm.PERMISSION.BUY_PLACEABLE) then
        self.configurationsChanged = false
        self:onButtonConfigurationBack()

        InfoDialog.show(string.format("%s\n\n%s", g_i18n:getText("shop_messageNoPermissionGeneral"), g_i18n:getText("ui_permissions_buyPlaceable")), nil, nil, DialogElement.TYPE_WARNING)

        return
    end

    self.configurationsChanged = true

    if configurationId == PlaceableObjectStorageExtensionEvent.TOTAL_CAPACITY then
        placeable:setObjectStorageTotalCapacity(value)
    elseif configurationId == PlaceableObjectStorageExtensionEvent.OBJECT_TYPE then
        placeable:setObjectStorageAcceptedObjectTypes(value)
    elseif configurationId == PlaceableObjectStorageExtensionEvent.INPUT_TRIGGER then
        placeable:setObjectStorageInputTriggerDisabled(value)
    end
end

function InGameMenuObjectStorageExtensionFrame:onPlaceablesChanged(placeable, isReseting)
    if self.isOpen then
        self.isReseting = isReseting == true
        self:updateObjectStorageLists()
        self.isReseting = false
    end
end

function InGameMenuObjectStorageExtensionFrame:onObjectInfosChanged(placeable, objectInfos)
    if self.isOpen then
        self:updateObjectStorageLists()
    end
end

function InGameMenuObjectStorageExtensionFrame:setSelectedObjectStorage(objectStorage)
    self.objectStorageListsSelector:setState(InGameMenuObjectStorageExtensionFrame.FILTER_ALL, true)

    local objectStorages = self:getFilteredObjectStorages()

    if #objectStorages > 0 then
        for i, placeable in ipairs(objectStorages) do
            if placeable == objectStorage then
                self.objectStorageList:setSelectedIndex(i)

                return true
            end
        end

        self.objectStorageList:setSelectedIndex(1)
    end

    return false
end

function InGameMenuObjectStorageExtensionFrame:setInfoMessage(message, isError, force, displayTime)
    if string.isNilOrWhitespace(message) then
        isError = false
        message = ""
        displayTime = 0
    end

    if self.infoBoxMessage ~= message or force then
        self.infoBoxIsSpawnMessage = nil
        self.infoBoxMessage = message
        self.infoBoxTime = displayTime or InGameMenuObjectStorageExtensionFrame.INFO_BOX_INTERVAL

        if self.infoBoxIcon ~= nil then
            if isError then
                self.infoBoxIcon:setImageColor(nil, 0.53328, 0.06301, 0.00335, 1) -- fs25_colorOrangeDark
            else
                self.infoBoxIcon:setImageColor(nil, 0.20156, 0.20156, 0.20156, 1) -- fs25_colorGreyLight
            end
        end

        if self.infoBoxText ~= nil then
            self.infoBoxText:setText(message)
        end
    end
end

function InGameMenuObjectStorageExtensionFrame:setPlayerFarm(playerFarm)
    self.playerFarm = playerFarm

    if playerFarm ~= nil then
        self.playerFarmId = playerFarm.farmId
    end
end

function InGameMenuObjectStorageExtensionFrame.getObjectImageFilename(fillTypeIndex, isBale, isRoundBale)
    local imageFilename

    if isBale and g_objectStorageExtension ~= nil then
        imageFilename = g_objectStorageExtension:getBaleIconFilename(fillTypeIndex, isRoundBale)
    end

    if imageFilename == nil then
        local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)

        if fillType ~= nil then
            imageFilename = fillType.hudOverlayFilename
        end
    end

    return imageFilename
end

function InGameMenuObjectStorageExtensionFrame:getNumberOfSections(list, section)
    if list == self.objectsList then
        return #self.objectTypeIndexes
    end

    return 1
end

function InGameMenuObjectStorageExtensionFrame:getNumberOfItemsInSection(list, section)
    if list == self.objectStorageList then
        return #self:getFilteredObjectStorages()
    end

    if list == self.objectsList then
        local typeIndex = self.objectTypeIndexes[section]

        return #self.objectTypeIndexToObjects[typeIndex] or 0
    end

    return 0
end

function InGameMenuObjectStorageExtensionFrame:getTitleForSectionHeader(list, section)
    if list == self.objectsList then
        local typeIndex = self.objectTypeIndexes[section]

        return self.typeIndexToTitle[typeIndex] or "Unknown Type"
    end

    return nil
end

function InGameMenuObjectStorageExtensionFrame:getFilteredObjectStorages()
    local state = self.objectStorageListsSelector:getState()

    if state == InGameMenuObjectStorageExtensionFrame.FILTER_BALES then
        return self.objectStoragesBales
    end

    if state == InGameMenuObjectStorageExtensionFrame.FILTER_PALLETS then
        return self.objectStoragesPallets
    end

    return self.objectStorages
end

function InGameMenuObjectStorageExtensionFrame:getSelectedObjectStorage()
    return self.selectedObjectStorage
end

function InGameMenuObjectStorageExtensionFrame.objectStorageSorter(a, b)
    return a:getName() < b:getName()
end

function InGameMenuObjectStorageExtensionFrame.objectInfoSorter(a, b)
    if a.isBale and a.title == b.title then
        if a.isRoundBale then
            if a.diameter == b.diameter then
                if a.isFermenting == b.isFermenting then
                    return false
                end

                return not a.isFermenting
            end

            return a.diameter < b.diameter
        end

        if a.length == b.length then
            if a.isFermenting == b.isFermenting then
                return false
            end

            return not a.isFermenting
        end

        return a.length < b.length
    end

    return a.title < b.title
end
