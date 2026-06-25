InGameMenuCropRotationPlanner = {
    MOD_DIRECTORY = g_currentModDirectory
}

local InGameMenuCropRotationPlanner_mt = Class(InGameMenuCropRotationPlanner, TabbedMenuFrameElement)

function InGameMenuCropRotationPlanner.new(i18n, messageCenter)
	local self = InGameMenuCropRotationPlanner:superClass().new(nil, InGameMenuCropRotationPlanner_mt)

	self.hasCustomMenuButtons = true
    self.messageCenter = messageCenter
    self.i18n = i18n
    self.farmCropRotations = {}
    self.selectionLists = {}

    self.cropSelectionIndexToName = {}
    self.cropIndexToSelectionIndex = {}
    self.cropSelectionIndexToCropIndex = {}
    self.catchCropSelectionIndexToName = {}
    self.catchCropIndexToSelectionIndex = {}
    self.catchCropSelectionIndexToCropIndex = {}

	return self
end

function InGameMenuCropRotationPlanner:initialize()
    self:initializeButtons()
    self:updateButtons()
end

function InGameMenuCropRotationPlanner:delete()
	InGameMenuCropRotationPlanner:superClass().delete(self)
end

function InGameMenuCropRotationPlanner:initializeButtons()
	self.backButtonInfo = {
		["inputAction"] = InputAction.MENU_BACK
	}
	self.nextPageButtonInfo = {
		["inputAction"] = InputAction.MENU_PAGE_NEXT,
		["text"] = g_i18n:getText("ui_ingameMenuNext"),
		["callback"] = self.onPageNext
	}
	self.prevPageButtonInfo = {
		["inputAction"] = InputAction.MENU_PAGE_PREV,
		["text"] = g_i18n:getText("ui_ingameMenuPrev"),
		["callback"] = self.onPagePrevious
	}
	self.addCropRotationPageButtonInfo = {
		["inputAction"] = InputAction.MENU_ACTIVATE,
		["text"] = g_i18n:getText("ui_button_addCropRotation"),
		["callback"] = function()
			self:onAddEntry()
		end
	}
	self.removeCropRotationPageButtonInfo = {
		["inputAction"] = InputAction.MENU_CANCEL,
		["text"] = g_i18n:getText("ui_button_removeCropRotation"),
		["callback"] = function()
			self:openRemoveCropRotationDialog()
		end
	}
end

function InGameMenuCropRotationPlanner:updateButtons()
	self.menuButtonInfo = { self.backButtonInfo, self.nextPageButtonInfo, self.prevPageButtonInfo, self.addCropRotationPageButtonInfo }

    if #self.farmCropRotations > 0 then
		table.insert(self.menuButtonInfo, self.removeCropRotationPageButtonInfo)
    end

	self:setMenuButtonInfoDirty()
end

function InGameMenuCropRotationPlanner:onFrameOpen(element)
	InGameMenuCropRotationPlanner:superClass().onFrameOpen(self)
    self:mapPossibleStateIfNeeded()
    self:updateFarmCropRotations()
    self.entryList:reloadData()
    self:updateButtons()
    self.cropRotationPlannerIcon:setImageFilename(InGameMenuCropRotationPlanner.MOD_DIRECTORY.."images/menuIcon.png")
	g_messageCenter:subscribe(MessageType.CROP_ROTATIONS_CHANGED, self.onCropRotationsChanged, self)
end

function InGameMenuAnimalsFrame:onFrameClose()
	g_messageCenter:unsubscribe(MessageType.CROP_ROTATIONS_CHANGED, self)
end

function InGameMenuCropRotationPlanner:mapPossibleStateIfNeeded()
    if #self.cropSelectionIndexToName > 0 and #self.catchCropSelectionIndexToName > 0 then
        return
    end

    local possibleCropStates = g_cropRotation:getPossibleCropStates()
    local possibleCatchCropStates = g_cropRotation:getPossibleCatchCropStates()

    local offset = 0
    for index, state in pairs(possibleCropStates) do
        if state.ignoreInPlanner then
            offset = offset + 1
            continue
        end

        table.insert(self.cropSelectionIndexToName, state.name)
        table.insert(self.cropSelectionIndexToCropIndex, state.cropIndex)
        self.cropIndexToSelectionIndex[state.cropIndex] = index - offset
    end

    for index, state in pairs(possibleCatchCropStates) do
        table.insert(self.catchCropSelectionIndexToName, state.name)
        table.insert(self.catchCropSelectionIndexToCropIndex, state.cropIndex)
        self.catchCropIndexToSelectionIndex[state.cropIndex] = index
    end
end

function InGameMenuCropRotationPlanner:updateFarmCropRotations()
    self.farmCropRotations = {}
    local cropRotations = g_cropRotationPlanner.cropRotations

    for _, cropRotation in pairs(cropRotations) do
        if cropRotation.farmId == g_localPlayer.farmId then
            table.insert(self.farmCropRotations, cropRotation)
            self:updateYieldValues(cropRotation)
        end
    end
end

function InGameMenuCropRotationPlanner:onCropRotationsChanged()
    self:updateFarmCropRotations()
    self.entryList:reloadData()
    self:updateButtons()
end

function InGameMenuCropRotationPlanner:getNumberOfSections(element)
	return 1
end

function InGameMenuCropRotationPlanner:getTitleForSectionHeader(element, section)
	return ""
end

function InGameMenuCropRotationPlanner:getNumberOfItemsInSection(element, section)
    if element == self.entryList then
        return #self.farmCropRotations
    else
        local cropRotation = self:getCropRotationWithIndex(element.cropRotationIndex)
        if cropRotation == nil then
            return 0
        else
            return #cropRotation.rotations
        end
    end
end

function InGameMenuCropRotationPlanner:getCropRotationWithIndex(index)
    for _, cropRotation in pairs(self.farmCropRotations) do
        if cropRotation.index == index then
            return cropRotation
        end
    end
    Logging.error("Could not find crop rotation for index "..index)
	return nil
end

function InGameMenuCropRotationPlanner:getSelectionListIndex(cropRotation)
    for index, currentCropRotation in pairs(self.farmCropRotations) do
        if cropRotation.index == currentCropRotation.index then
            return index
        end
    end
    Logging.error("Could not find selection list for crop rotation index "..cropRotation.index)
	return nil
end

function InGameMenuCropRotationPlanner:populateCellForItemInSection(element, section, index, cell)
    if element == self.entryList then
        self:populateCellForEntry(index, cell)
    else
        self:populateCellForSelection(element, index, cell)
    end
end

function InGameMenuCropRotationPlanner:populateCellForEntry(index, cell)
    local cropRotation = self.farmCropRotations[index]

    local entryName = cell:getAttribute("entryName")
    entryName:setText(cropRotation.name)

    local removeButton = cell:getAttribute("removeSelection")
    function removeButton.onClickCallback()
        self:onRemoveSelection(index)
    end

    local addButton = cell:getAttribute("addSelection")
    function addButton.onClickCallback()
        self:onAddSelection(index)
    end

    local selectionList = cell:getAttribute("selectionList")
    self.selectionLists[index] = selectionList
    selectionList.cropRotationIndex = cropRotation.index
    selectionList:reloadData()
end

function InGameMenuCropRotationPlanner:populateCellForSelection(selectionList, index, cell)
    local cropRotationIndex = selectionList.cropRotationIndex
    local cropRotation = self:getCropRotationWithIndex(cropRotationIndex)
    local rotation = cropRotation.rotations[index]

    local fruitMultiTextOption = cell:getAttribute("fruitMultiTextOption")
    fruitMultiTextOption:setTexts(self.cropSelectionIndexToName)
    fruitMultiTextOption:setState(self.cropIndexToSelectionIndex[rotation.state])

    local catchCropTextOption = cell:getAttribute("catchCropTextOption")
    catchCropTextOption:setTexts(self.catchCropSelectionIndexToName)
    catchCropTextOption:setState(self.catchCropIndexToSelectionIndex[rotation.catchCropState])

    local yieldFactor = cell:getAttribute("yieldFactor")
    yieldFactor:setText(string.format("%.0f", rotation.yieldValue).."%")

    local yieldArrow = cell:getAttribute("yieldArrow")
    yieldArrow:setVisible(index > 1)

    function fruitMultiTextOption.onClickCallback(_, currentState)
        self:onClickSelectionChanged(currentState, index, cropRotationIndex)
    end

    function catchCropTextOption.onClickCallback(_, currentState)
        self:onClickCatchCropChanged(currentState, index, cropRotationIndex)
    end
end

function InGameMenuCropRotationPlanner:onClickSelectionChanged(currentState, index, cropRotationIndex)
    local cropRotation = self:getCropRotationWithIndex(cropRotationIndex)
    local cropIndex = self.cropSelectionIndexToCropIndex[currentState]

    g_cropRotationPlanner:updateCropSelection(cropRotation, index, cropIndex)

    self:updateYieldValues(cropRotation)

    local selectionListIndex = self:getSelectionListIndex(cropRotation)
    local selectionList = self.selectionLists[selectionListIndex]
    selectionList:reloadData()
end

function InGameMenuCropRotationPlanner:onClickCatchCropChanged(currentState, index, cropRotationIndex)
    local cropRotation = self:getCropRotationWithIndex(cropRotationIndex)
    local cropIndex = self.catchCropSelectionIndexToCropIndex[currentState]

    g_cropRotationPlanner:updateCatchCropSelection(cropRotation, index, cropIndex)

    self:updateYieldValues(cropRotation)

    local selectionListIndex = self:getSelectionListIndex(cropRotation)
    local selectionList = self.selectionLists[selectionListIndex]
    selectionList:reloadData()
end

function InGameMenuCropRotationPlanner:updateYieldValues(cropRotation)
    for rotationIndex, rotation in pairs(cropRotation.rotations) do
        local yieldMultiplier = self:getYieldMultiplier(cropRotation, rotation.state, rotationIndex, rotation.catchCropState)
        local percentage = 100 * yieldMultiplier
        rotation.yieldValue = percentage
    end
end

function InGameMenuCropRotationPlanner:onRemoveSelection(index)
    local cropRotation = self.farmCropRotations[index]

    if #cropRotation.rotations <= 1 then
        return
    end

    g_cropRotationPlanner:removeCropRotationSelection(cropRotation)
    self:updateYieldValues(cropRotation)
    local selectionListIndex = self:getSelectionListIndex(cropRotation)
    local selectionList = self.selectionLists[selectionListIndex]
    selectionList:reloadData()
end

function InGameMenuCropRotationPlanner:onAddSelection(index)
    local cropRotation = self.farmCropRotations[index]
    g_cropRotationPlanner:addCropRotationSelection(cropRotation)
    self:updateYieldValues(cropRotation)
    local selectionListIndex = self:getSelectionListIndex(cropRotation)
    local selectionList = self.selectionLists[selectionListIndex]
    selectionList:reloadData()
end

function InGameMenuCropRotationPlanner:onAddEntry()
	local title = g_i18n:getText("ui_add_entry_title")
	local buttonText = g_i18n:getText("button_accept")
	TextInputDialog.show(self.addEntryCallback, self, nil, title, nil, 40, buttonText, nil, nil, false)
end

function InGameMenuCropRotationPlanner:addEntryCallback(name, success)
    if not success then
        return
    end

    local farmId = g_localPlayer.farmId
    g_cropRotationPlanner:addCropRotation(name, farmId)

    self:updateFarmCropRotations()
    self.entryList:reloadData()
    self:updateButtons()
end

function InGameMenuCropRotationPlanner:openRemoveCropRotationDialog()
    local cropRotation = self.farmCropRotations[self.entryList.selectedIndex]

    if cropRotation == nil then
        return
    end

    local text = string.format(g_i18n:getText("ui_remove_crop_rotation"), cropRotation.name)
    local title = g_i18n:getText("ui_remove_crop_rotation_title")
    local callbackAction = InGameMenuCropRotationPlanner.onRemoveEntry
    local callbackArgs = {
        cropRotation = cropRotation
    }
    YesNoDialog.show(callbackAction, self, text, title, nil, nil, nil, nil, nil, callbackArgs)
end

function InGameMenuCropRotationPlanner:onRemoveEntry(success, callbackArgs)
    if not success then
        return
    end

    local cropRotation = callbackArgs.cropRotation
    g_cropRotationPlanner:removeCropRotation(cropRotation)

    self:updateFarmCropRotations()
    self.entryList:reloadData()
    self:updateButtons()
end

function InGameMenuCropRotationPlanner:getYieldMultiplier(cropRotation, currentState, rotationIndex, catchCropIndex)
    local yieldCalculator = g_cropRotation.yieldCalculator
    local historyStates = {}

    for i=1, CropRotation.NUM_HISTORY_MAPS do
        local moduloIndex = ((rotationIndex - 1) - i) % #cropRotation.rotations
        local rotation = cropRotation.rotations[moduloIndex + 1]
        table.insert(historyStates, rotation.state)
    end

    local yieldMultiplier = yieldCalculator:getYieldMultiplier(historyStates, currentState, catchCropIndex)
    return yieldMultiplier
end