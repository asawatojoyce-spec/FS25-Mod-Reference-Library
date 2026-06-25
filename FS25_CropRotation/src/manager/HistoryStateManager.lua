HistoryStateManager = {}

local HistoryStateManager_mt = Class(HistoryStateManager)

function HistoryStateManager.new(cropRotation, customMt)
	local self = setmetatable({}, customMt or HistoryStateManager_mt)

    self.cropRotation = cropRotation
    self.historyStates = {}

    return self
end

function HistoryStateManager:loadHistoryMapProperties(xmlFile, key)
    key = key..".historyStateMap"
	local numChannels = getXMLInt(xmlFile, key .. "#numChannels")

    local index = 0
    while true do
        local stateKey = string.format(key..".state(%d)", index)
        if not hasXMLProperty(xmlFile, stateKey) then
            break
        end

        local historyState = self.historyStates[index + 1]
        historyState.map.firstChannel = 0
        historyState.map.numChannels = numChannels
        historyState.map.maxValue = 2 ^ numChannels - 1

        historyState.title = g_i18n:getText(getXMLString(xmlFile, stateKey .. "#titleKey"))
        index = index + 1
    end
end

function HistoryStateManager:initLastStatesIfNeeded()
    local savegameDirectory = g_currentMission.missionInfo.savegameDirectory

    if savegameDirectory ~= nil then
        local filename = savegameDirectory.."/careerSavegame.xml"
        local key = "careerSavegame"
        local xmlFile = XMLFile.loadIfExists("careerSavegame", filename, key)
        local cropRotationKey = key..".cropRotation"
        local isInitialized = xmlFile:getBool(cropRotationKey.."#isInitialized")

        if isInitialized ~= nil and isInitialized then
            xmlFile:delete()
            return
        end

        xmlFile:delete()
    end

    local randomFruit = nil
    local fields = g_fieldManager:getFields()
    local cropsForStartup = self.cropRotation.cropsForStartup

    for i, field in pairs(fields) do
        for _, historyState in pairs(self.historyStates) do
            if field.grassMissionOnly then
                randomFruit = FruitType.GRASS
            else
                local randomIndex = math.random(#cropsForStartup)
                randomFruit = cropsForStartup[randomIndex]
            end

            historyState.map:updateFruitCoverAreaForField(field, randomFruit)
        end
    end
end

function HistoryStateManager:updateStates(state, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, fruitFilter, harvestStateFilter)
    local previousState
    local previousStateValue

    for i=#self.historyStates, 2, -1 do
        local currentState = self.historyStates[i]
        previousState = self.historyStates[i - 1]
        previousStateValue = previousState.map:getHistoryState(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, fruitFilter, harvestStateFilter)

        if previousStateValue ~= -1 then
            local currentStateModifier = currentState.map:getDynamicModifier()
            currentState.map:setParallelogrammToModifier(currentStateModifier, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
            currentStateModifier:executeSet(previousStateValue, fruitFilter, harvestStateFilter)
        end
    end

    if previousStateValue ~= -1 then
        local lastStateModifier = previousState.map:getDynamicModifier()
        previousState.map:setParallelogrammToModifier(lastStateModifier, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
        lastStateModifier:executeSet(state, fruitFilter, harvestStateFilter)
    end
end

function HistoryStateManager:getHistoryStates(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, fruitFilter, harvestStateFilter)
    local historyStateValues = {}

    for _, historyState in pairs(self.historyStates) do
        local state = historyState.map:getHistoryState(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, fruitFilter, harvestStateFilter)
        table.insert(historyStateValues, state)
    end

    return historyStateValues
end

function HistoryStateManager:updateStatesForField(state, field)
    local previousState
    local previousStateValue

    for i=#self.historyStates, 2, -1 do
        g_asyncTaskManager:addSubtask(function()
            local currentState = self.historyStates[i]
            previousState = self.historyStates[i - 1]
            local x, z = field:getCenterOfFieldWorldPosition()
            previousStateValue = previousState.map:getStateAtPos(x, z)

            if previousStateValue ~= -1 then
                local currentStateModifier = currentState.map:getDynamicModifier()
                field:getDensityMapPolygon():applyToModifier(currentStateModifier)
                currentStateModifier:executeSet(previousStateValue)
            end
        end)
    end

    if previousStateValue ~= -1 then
        g_asyncTaskManager:addSubtask(function()
            local lastStateModifier = previousState.map:getDynamicModifier()
            field:getDensityMapPolygon():applyToModifier(lastStateModifier)
            lastStateModifier:executeSet(state)
        end)
    end
end