--[[
Revamps the Price Menu to give more user input and better display.

Author:     Reddog
Version:    1.0.0
Modified:   2026-04-28

Notes:
- Filter buttons are read from RDMPriceMenu_fillCategories.xml.
- A player override can be placed at:
  modSettings/RDM_PriceMenuFilters/RDMPriceMenu_fillCategories.xml
]]

RDM_PriceMenu = Mod:init()
RDM_PriceMenu.ModDir = g_currentModDirectory

RDM_PriceMenu.StartingShowSettings = {}
RDM_PriceMenu.buttonList = {}
RDM_PriceMenu.filterCategories = {}
RDM_PriceMenu.MaxTotalButtons = 20
RDM_PriceMenu.MaxFilterButtons = RDM_PriceMenu.MaxTotalButtons - 1 -- Reset always uses one slot
RDM_PriceMenu.TooManyFiltersWarning = nil

function RDM_PriceMenu:loadMap(savegame)
	self.debugMode = false
    self:loadFillTypes()
    self:loadGUI()
end

function RDM_PriceMenu:getSettingsCategoryFilename()
    if getUserProfileAppPath ~= nil then
        return getUserProfileAppPath() .. "modSettings/FS25_RDM_PriceMenuFilters/RDMPriceMenu_fillCategories.xml"
    end

    return nil
end

function RDM_PriceMenu:getDefaultCategoryFilename()
    return RDM_PriceMenu.ModDir .. "xml/RDMPriceMenu_fillCategories.xml"
end

function RDM_PriceMenu:getActiveCategoryFilename()
    local settingsFilename = self:getSettingsCategoryFilename()

    if settingsFilename ~= nil and fileExists(settingsFilename) then
        self:printDebug("Using player filter override: " .. settingsFilename)
        return settingsFilename, true
    end

    local defaultFilename = self:getDefaultCategoryFilename()
    self:printDebug("Using default filter categories: " .. defaultFilename)
    return defaultFilename, false
end

function RDM_PriceMenu:loadFillTypes()
    local filename = self:getActiveCategoryFilename()

    if filename ~= nil and fileExists(filename) then
        local fillTypesXML = loadXMLFile("RDM_PriceMenu", filename)
        g_fillTypeManager:loadFillTypes(fillTypesXML, RDM_PriceMenu.ModDir, false, "FS25_RDM_PriceMenu")
        self:loadFilterCategoriesFromXML(fillTypesXML)
        delete(fillTypesXML)
    else
        self:warning("Could not find RDM price menu category XML")
    end
end

function RDM_PriceMenu:loadFilterCategoriesFromXML(xmlFile)
    self.filterCategories = {}

    local i = 0
    while true do
        local baseKey = string.format("map.fillTypeCategories.fillTypeCategory(%d)", i)
        local categoryName = getXMLString(xmlFile, baseKey .. "#name")

        if categoryName == nil then
            break
        end

        local label = getXMLString(xmlFile, baseKey .. "#label")
        local labelKey = getXMLString(xmlFile, baseKey .. "#labelKey")
        local title = getXMLString(xmlFile, baseKey .. "#title")

        -- Support a few sane aliases so user override files are forgiving.
        if label == nil then
            label = getXMLString(xmlFile, baseKey .. "#text")
        end

        if label == nil then
            label = title
        end

        local displayText = self:getCategoryDisplayText(categoryName, label, labelKey)

        table.insert(self.filterCategories, {
            name = categoryName,
            text = displayText
        })

        i = i + 1
    end

end

function RDM_PriceMenu:getCategoryDisplayText(categoryName, label, labelKey)
    if labelKey ~= nil and labelKey ~= "" and g_i18n ~= nil then
        local text = g_i18n:getText(labelKey)
        if text ~= nil and text ~= "" and text ~= labelKey then
            return text
        end
    end

    if label ~= nil and label ~= "" then
        if string.sub(label, 1, 6) == "$l10n_" and g_i18n ~= nil then
            local key = string.sub(label, 7)
            local text = g_i18n:getText(key)

            if text ~= nil and text ~= "" and text ~= key then
                return text
            end
        else
            return label
        end
    end

    return self:makeFallbackCategoryLabel(categoryName)
end

function RDM_PriceMenu:makeFallbackCategoryLabel(categoryName)
    local text = tostring(categoryName or "FILTER")
    text = string.gsub(text, "^PRICECAT_", "")
    text = string.gsub(text, "_", " ")
    return text
end

function RDM_PriceMenu:loadGUI()
    local profileFilename = RDM_PriceMenu.ModDir .. "xml/guiProfiles.xml"

    if fileExists(profileFilename) then
        g_gui:loadProfiles(profileFilename)
    else
        self:warning("Missing GUI profiles: " .. tostring(profileFilename))
        return false
    end

    local guiFilename = RDM_PriceMenu.ModDir .. "xml/filterGui.xml"
    local attachParent = g_inGameMenu.pageStatistics.productList.parent

    local canLoad = loadGuiFile(self, guiFilename, attachParent, function(parent)
        fixPosition(parent:getDescendantById("rdgButtonBox"), true)
    end)

    if not canLoad then
        self:warning("Could not load GUI: " .. tostring(guiFilename))
        return false
    end

    local buttonBox = attachParent:getDescendantById("rdgButtonBox")

    if buttonBox == nil then
        self:warning("rdgButtonBox not found after loading GUI")
        return false
    end

    self:buildButtonList()
    self:populateFilterButtons(buttonBox)

    return true
end

function RDM_PriceMenu:buildButtonList()
    self.buttonList = {}
    self.TooManyFiltersWarning = nil

    table.insert(self.buttonList, {
        text = self:getResetButtonText(),
        categoryName = nil,
        isReset = true
    })

    local filterCount = #self.filterCategories
    local visibleFilterCount = math.min(filterCount, self.MaxFilterButtons)

    if filterCount > self.MaxFilterButtons then
        self.TooManyFiltersWarning = string.format(
            "RDM Price Menu Filters: %d filters are defined, but only %d can be shown. Extra filters have been ignored.",
            filterCount,
            self.MaxFilterButtons
        )
        self:warning(self.TooManyFiltersWarning)
    end

    for i = 1, visibleFilterCount do
        local category = self.filterCategories[i]

        table.insert(self.buttonList, {
            text = category.text,
            categoryName = category.name,
            isReset = false
        })
    end
end

function RDM_PriceMenu:getResetButtonText()
    if g_i18n ~= nil then
        local text = g_i18n:getText("rdm_priceCat_reset")

        if text ~= nil and text ~= "" and text ~= "rdm_priceCat_reset" then
            return text
        end
    end

    return "RESET"
end

function RDM_PriceMenu:populateFilterButtons(buttonBox)
    for i = 1, self.MaxTotalButtons do
        local buttonID = string.format("rdgButton%02d", i)
        local button = buttonBox:getDescendantById(buttonID)
        local entry = self.buttonList[i]

        if button ~= nil then
            if entry ~= nil then
                button:setVisible(true)
                button:setText(entry.text)
                button.onClickCallback = function()
                    RDM_PriceMenu:setProductsVisible(entry.categoryName)
                end
            else
                button:setVisible(false)
                button:setText("")
                button.onClickCallback = nil
            end
        else
            self:warning("Missing filter button: " .. tostring(buttonID))
        end
    end

    self:notifyPlayerIfNeeded()
    fixPosition(buttonBox, true)
end

function RDM_PriceMenu:startMission()
    for _, fillTypesDesc in pairs(g_fillTypeManager:getFillTypes()) do
        RDM_PriceMenu.StartingShowSettings[fillTypesDesc.index] = fillTypesDesc.showOnPriceTable
    end

    self:notifyPlayerIfNeeded()
end

function RDM_PriceMenu:notifyPlayerIfNeeded()
    if self.TooManyFiltersWarning ~= nil and g_currentMission ~= nil and g_currentMission.addIngameNotification ~= nil then
        g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL, self.TooManyFiltersWarning)
    end
end

function RDM_PriceMenu:setProductsVisible(categoryName)
    local filteredFillTypes = {}

    if categoryName == nil then
        for fillTypeIndex, wasShown in pairs(RDM_PriceMenu.StartingShowSettings) do
            if wasShown then
                local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)

                if fillType ~= nil then
                    table.insert(filteredFillTypes, fillType.index)
                end
            end
        end
    else
        self:printDebug(categoryName)
        filteredFillTypes = g_fillTypeManager:getFillTypesByCategoryNames(categoryName, "RDM_PriceMenu: unknown fill type category") or {}
    end

    for _, fillTypesDesc in pairs(g_fillTypeManager:getFillTypes()) do
        local found = false

        for _, fillTypeIndex in pairs(filteredFillTypes) do
            if fillTypeIndex == fillTypesDesc.index then
                found = true
                break
            end
        end

        fillTypesDesc.showOnPriceTable = found
    end

    g_inGameMenu.pageStatistics:rebuildTable()
end

-- function RDM_PriceMenu:setProductionsToNonVisible()
    -- for _, unloadingStation in pairs(g_currentMission.storageSystem:getUnloadingStations()) do
        -- if unloadingStation.isSellingPoint then
            -- if unloadingStation.ownerFarmId ~= 0 then
                -- unloadingStation.hideFromPricesMenu = "true"
            -- end
        -- end
    -- end
-- end

function RDM_PriceMenu:warning(message)
    if Logging ~= nil and Logging.warning ~= nil then
        Logging.warning("[Price Menu Filters] " .. tostring(message))
    else
        print("[Price Menu Filters] WARNING: " .. tostring(message))
    end
end

function fixPosition(element, invLayout)
    if element ~= nil and element.updateAbsolutePosition ~= nil then
        element:updateAbsolutePosition()
    end

    if invLayout and element ~= nil and element.invalidateLayout ~= nil then
        element:invalidateLayout(true)
    end
end

function loadGuiFile(self, fname, parent, initial)
    if fileExists(fname) then
        local xmlFile = loadXMLFile("Temp", fname)
        g_gui:loadGuiRec(xmlFile, "GUI", parent, self.frCon)

        if initial ~= nil then
            initial(parent)
        end

        delete(xmlFile)
    else
        return false
    end

    return true
end
