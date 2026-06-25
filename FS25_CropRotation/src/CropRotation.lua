CropRotation = {
    MOD_NAME = g_currentModName,
    MOD_DIRECTORY = g_currentModDirectory,
    FALLOW_STATE = 0,
    NUM_HISTORY_MAPS = 2,
    NO_CATCH_CROP_STATE = 0
}

source("dataS/scripts/internalMods/FS25_precisionFarming/scripts/maps/ValueMap.lua")

source(g_currentModDirectory.."src/maps/CropRotationMap.lua")
source(g_currentModDirectory.."src/maps/HistoryStateMap.lua")
source(g_currentModDirectory.."src/maps/FallowStateMap.lua")
source(g_currentModDirectory.."src/maps/CatchCropMap.lua")
source(g_currentModDirectory.."src/PlayerHUDUpdaterExtension.lua")
source(g_currentModDirectory.."src/FSDensityMapUtilExtension.lua")
source(g_currentModDirectory.."src/YieldCalculator.lua")

source(g_currentModDirectory.."src/manager/CatchCropManager.lua")
source(g_currentModDirectory.."src/manager/FallowStateManager.lua")
source(g_currentModDirectory.."src/manager/HistoryStateManager.lua")
source(g_currentModDirectory.."src/DebugCropRotation.lua")


local CropRotation_mt = Class(CropRotation)

function CropRotation.new(customMt)
	local self = setmetatable({}, customMt or CropRotation_mt)

    self.historyStateManager = HistoryStateManager.new(self)
    self.fallowStateManager = FallowStateManager.new(self)
    self.catchCropManager = CatchCropManager.new(self)
    self.yieldCalculator = YieldCalculator.new(self)
    self.debugManager = DebugCropRotation.new(self)

    self.overwrittenGameFunctions = {}
    self.maps = {}
    self.fruitTypeIndexToCrop = {}
    self.fruitTypeIndexToCatchCrop = {}
    self.catchCropIndexToCatchCrop = {}
    self.catchCropIndexToFruitType = {}
    self.cropsForStartup = {}
    self.settings = {}
    self.possibleCropStates = {}
    self.possibleCatchCropStates = {}
    self.ignoreFallowCrops = {}

    for i=1, CropRotation.NUM_HISTORY_MAPS do
        local historyStateMap = HistoryStateMap.new(self, i)
        local state = {
            map = historyStateMap
        }
        table.insert(self.historyStateManager.historyStates, state)
        table.insert(self.maps, historyStateMap)
    end

    self.fallowStateManager.fallowStateMap = FallowStateMap.new(self)
    table.insert(self.maps, self.fallowStateManager.fallowStateMap)
    self.catchCropManager.catchCropMap = CatchCropMap.new(self)
    table.insert(self.maps, self.catchCropManager.catchCropMap)

    return self
end

function CropRotation:initialize()
    for _, map in pairs(self.maps) do
        map:initialize(self)
        map:overwriteGameFunctions(self)
    end

    g_messageCenter:subscribe(MessageType.PERIOD_CHANGED, self.onPeriodChanged, self)
    self.debugManager:addConsoleCommands()
end

TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, function(self)
	if self.typeName == "vehicle" and g_iconGenerator == nil then
		g_cropRotation:initialize()
	end
end)

function CropRotation:loadMap(filename)
	g_currentMission:registerToLoadOnMapFinished(g_cropRotation)
end

function CropRotation:deleteMap()
    for _, map in pairs(self.maps) do
        map:delete()
    end

    for overwrittenGameFunction = #self.overwrittenGameFunctions, 1, -1 do
        local reference = self.overwrittenGameFunctions[overwrittenGameFunction]
        reference.object[reference.funcName] = reference.oldFunc
        self.overwrittenGameFunctions[overwrittenGameFunction] = nil
    end

    g_messageCenter:unsubscribeAll(self)
    self.debugManager:removeConsoleCommands()
end

function CropRotation:initTerrain(mission, terrainId, filename)
    self.mission = mission
    self.terrainId = terrainId
end

FSBaseMission.initTerrain = Utils.appendedFunction(FSBaseMission.initTerrain, function(mission, terrainId, filename)
	g_cropRotation:initTerrain(mission, terrainId, filename)
end)

function CropRotation:onLoadMapFinished()
    self:loadConfig()
    self:loadCropsXml()

    for _, map in pairs(self.maps) do
        map:initTerrain(self.mission, self.terrainId, nil)
    end

    if g_currentMission:getIsServer() then
        self.historyStateManager:initLastStatesIfNeeded()
    end
end

function CropRotation:onPeriodChanged()
    if not g_currentMission:getIsServer() then
        return
    end

    g_asyncTaskManager:addTask(function()
        self.fallowStateManager:increaseFallow()
        self.fallowStateManager:setFallowStateIfNeeded()
        self.fallowStateManager:resetFallowStateIfNeeded()
    end)
end

function CropRotation:update(dt)
    for _, map in pairs(self.maps) do
        map:update(dt)
    end
end

function CropRotation:overwriteGameFunction(object, funcName, newFunc)
	if object == nil then
		Logging.error("Failed to overwrite \'%s\'", funcName)
	else
		local oldFunc = object[funcName]
		if oldFunc ~= nil then
			object[funcName] = function(...)
				return newFunc(oldFunc, ...)
			end
		end

		table.insert(self.overwrittenGameFunctions, {
			["object"] = object,
			["funcName"] = funcName,
			["oldFunc"] = oldFunc
		})
	end
end

function CropRotation:saveToXMLFile(missionInfo)
    local savegameDirectory = g_currentMission.missionInfo.savegameDirectory

    if savegameDirectory ~= nil then
        local filename = savegameDirectory.."/careerSavegameXML.xml"
        local key = "careerSavegame"
        local xmlFile = missionInfo.xmlFile
        local cropRotationKey = key..".cropRotation"

        if xmlFile ~= nil then
            setXMLBool(xmlFile, cropRotationKey.."#isInitialized", true)
            saveXMLFile(xmlFile)
        end
    end
end

FSCareerMissionInfo.saveToXMLFile = Utils.overwrittenFunction(FSCareerMissionInfo.saveToXMLFile, function(missionInfo, superFunc)
    superFunc(missionInfo)
	g_cropRotation:saveToXMLFile(missionInfo)
end)

------------------------------------------------------------------------------------

function CropRotation:loadConfig()
    self.configFileName = Utils.getFilename("xmls/cropRotation.xml", CropRotation.MOD_DIRECTORY)
    local xmlFile = loadXMLFile("ConfigXML", self.configFileName)
    local key = "cropRotation"

	self.mapsSize = g_currentMission.terrainSize * 2

    self.historyStateManager:loadHistoryMapProperties(xmlFile, key)

    for _, map in pairs(self.maps) do
        map:loadFromXML(xmlFile, key, CropRotation.MOD_DIRECTORY, self.configFileName, nil, self.mapsSize)
        map:postLoad(xmlFile, key, CropRotation.MOD_DIRECTORY, self.configFileName, nil)
    end

    local settingsKey = key..".settings"
    self.settings.monoculturePenalty = getXMLFloat(xmlFile, settingsKey .. "#monoculturePenalty")
    self.settings.breakPeriodsPenalty = getXMLFloat(xmlFile, settingsKey .. "#breakPeriodsPenalty")

    self.settings.foreCropsPenalties = {}
    local foreCropsPenaltyStrings = string.split(getXMLString(xmlFile, settingsKey .. "#foreCropsPenalties") or "", " ")
    for _, value in pairs(foreCropsPenaltyStrings) do
        table.insert(self.settings.foreCropsPenalties, tonumber(value))
    end

    self.settings.foreCropsVeryGoodBonuses = {}
    local foreCropsVeryGoodBonusesStrings = string.split(getXMLString(xmlFile, settingsKey .. "#foreCropsVeryGoodBonuses") or "", " ")
    for _, value in pairs(foreCropsVeryGoodBonusesStrings) do
        table.insert(self.settings.foreCropsVeryGoodBonuses, tonumber(value))
    end

    self.settings.foreCropsGoodBonuses = {}
    local foreCropsGoodBonusesStrings = string.split(getXMLString(xmlFile, settingsKey .. "#foreCropsGoodBonuses") or "", " ")
    for _, value in pairs(foreCropsGoodBonusesStrings) do
        table.insert(self.settings.foreCropsGoodBonuses, tonumber(value))
    end

    self.settings.fallowStateBonus = getXMLFloat(xmlFile, settingsKey .. "#fallowStateBonus")
    self.settings.veryGoodCatchCropBonus = getXMLFloat(xmlFile, settingsKey .. "#veryGoodCatchCropBonus")
    self.settings.goodCatchCropBonus = getXMLFloat(xmlFile, settingsKey .. "#goodCatchCropBonus")
    self.settings.badCatchCropPenalty = getXMLFloat(xmlFile, settingsKey .. "#badCatchCropPenalty")

    delete(xmlFile)
end

function CropRotation:loadCropsXml()
    self.cropsFileName = Utils.getFilename("xmls/crops.xml", CropRotation.MOD_DIRECTORY)
    local xmlFile = loadXMLFile("Crops", self.cropsFileName)
    local key = "crops"

    self:loadCrops(key, xmlFile)
    self:loadCatchCrops(key, xmlFile)

    self:loadPossibleStates()
    self:loadPossibleCatchCrops()

    delete(xmlFile)
end

function CropRotation:loadCrops(key, xmlFile)
    local index = 0

	while true do
        local cropKey = string.format(key..".crop(%d)", index)
        if not hasXMLProperty(xmlFile, cropKey) then
            break
        end

        local fruitName = getXMLString(xmlFile, cropKey .. "#fruitName")
        local veryGoodCropNames = string.split(getXMLString(xmlFile, cropKey .. "#veryGoodCrops") or "", " ")
        local goodCropNames = string.split(getXMLString(xmlFile, cropKey .. "#goodCrops") or "", " ")
        local badCropNames = string.split(getXMLString(xmlFile, cropKey .. "#badCrops") or "", " ")
        local ignoreOnStartup = getXMLBool(xmlFile, cropKey .. "#ignoreOnStartup")
        local ignoreInPlanner = getXMLBool(xmlFile, cropKey .. "#ignoreInPlanner")
        local ignoreFallow = getXMLBool(xmlFile, cropKey .. "#ignoreFallow")

        local fruitType = g_fruitTypeManager:getFruitTypeByName(fruitName)

        if fruitType == nil then
            index = index + 1
            continue
        end

        local veryGoodCrops = {}
        local goodCrops = {}
        local badCrops = {}

        for _, cropName in pairs(veryGoodCropNames) do
            table.insert(veryGoodCrops, g_fruitTypeManager:getFruitTypeIndexByName(cropName))
        end

        for _, cropName in pairs(goodCropNames) do
            table.insert(goodCrops, g_fruitTypeManager:getFruitTypeIndexByName(cropName))
        end

        for _, cropName in pairs(badCropNames) do
            table.insert(badCrops, g_fruitTypeManager:getFruitTypeIndexByName(cropName))
        end

        local crop = {
            index = fruitType.index,
            fruitType = fruitType,
            breakPeriods = getXMLInt(xmlFile, cropKey .. "#breakPeriods"),
            veryGoodCrops = veryGoodCrops,
            goodCrops = goodCrops,
            badCrops = badCrops,
            ignoreInPlanner = ignoreInPlanner,
            ignoreFallow = ignoreFallow
        }

        if not ignoreOnStartup then
            table.insert(self.cropsForStartup, crop.index)
        end

        if ignoreFallow then
            table.insert(self.ignoreFallowCrops, crop)
        end

        self.fruitTypeIndexToCrop[fruitType.index] = crop
        index = index + 1
    end
end

function CropRotation:loadCatchCrops(key, xmlFile)
    local catchCropsKey = key..".catchCrops"
    local index = 0

	while true do
        local catchCropKey = string.format(catchCropsKey..".catchCrop(%d)", index)
        if not hasXMLProperty(xmlFile, catchCropKey) then
            break
        end

        local fruitName = getXMLString(xmlFile, catchCropKey .. "#fruitName")
        local veryGoodCropNames = string.split(getXMLString(xmlFile, catchCropKey .. "#veryGoodCrops"), " ")
        local goodCropNames = string.split(getXMLString(xmlFile, catchCropKey .. "#goodCrops"), " ")
        local badCropNames = string.split(getXMLString(xmlFile, catchCropKey .. "#badCrops"), " ")

        local fruitType = g_fruitTypeManager:getFruitTypeByName(fruitName)

        if fruitType == nil then
            index = index + 1
            continue
        end

        local veryGoodCrops = {}
        local goodCrops = {}
        local badCrops = {}

        for _, cropName in pairs(veryGoodCropNames) do
            table.insert(veryGoodCrops, g_fruitTypeManager:getFruitTypeIndexByName(cropName))
        end

        for _, cropName in pairs(goodCropNames) do
            table.insert(goodCrops, g_fruitTypeManager:getFruitTypeIndexByName(cropName))
        end

        for _, cropName in pairs(badCropNames) do
            table.insert(badCrops, g_fruitTypeManager:getFruitTypeIndexByName(cropName))
        end

        local catchCrop = {
            index = #self.catchCropIndexToFruitType + 1,
            fruitType = fruitType,
            veryGoodCrops = veryGoodCrops,
            goodCrops = goodCrops,
            badCrops = badCrops
        }

        self.fruitTypeIndexToCatchCrop[fruitType.index] = catchCrop
        table.insert(self.catchCropIndexToFruitType, fruitType)
        table.insert(self.catchCropIndexToCatchCrop, catchCrop)
        index = index + 1
    end
end

function CropRotation:cropByFruitTypeIndex(fruitTypeIndex)
    return self.fruitTypeIndexToCrop[fruitTypeIndex]
end

function CropRotation:catchCropIndexByFruitIndex(fruitIndex)
    local catchCrop = self.fruitTypeIndexToCatchCrop[fruitIndex]

    if catchCrop == nil then
        return nil
    else
        return catchCrop.index
    end
end

function CropRotation:catchCropByCatchCropIndex(catchCropIndex)
    local catchCrop = self.catchCropIndexToCatchCrop[catchCropIndex]
    return catchCrop
end

function CropRotation:fruitTypeByCatchCropIndex(catchCropIndex)
    local fruitType = self.catchCropIndexToFruitType[catchCropIndex]
    return fruitType
end

function CropRotation:getPossibleCropStates()
    return self.possibleCropStates
end

function CropRotation:getPossibleCatchCropStates()
    return self.possibleCatchCropStates
end

function CropRotation:loadPossibleStates()
    local fallowState = {
        cropIndex = CropRotation.FALLOW_STATE,
        name = g_i18n:getText("fallow_state")
    }
    table.insert(self.possibleCropStates, fallowState)

    for index, fruitType in pairs(g_fruitTypeManager:getFruitTypes()) do
        if self:catchCropIndexByFruitIndex(fruitType.index) ~= nil then
            continue
        end

        local crop = self:cropByFruitTypeIndex(fruitType.index)

        local ignoreInPlanner
        if crop == nil then
            ignoreInPlanner = false
        else
            ignoreInPlanner = crop.ignoreInPlanner
        end

        local state = {
            cropIndex = fruitType.index,
            name = fruitType.fillType.title,
            ignoreInPlanner = ignoreInPlanner
        }
        table.insert(self.possibleCropStates, state)
    end
end

function CropRotation:loadPossibleCatchCrops()
    local noState = {
        cropIndex = CropRotation.NO_CATCH_CROP_STATE,
        name = g_i18n:getText("ui_withoutCatchCrop")
    }
    table.insert(self.possibleCatchCropStates, noState)

    for index, fruitType in pairs(self.catchCropIndexToFruitType) do
        local state = {
            cropIndex = index,
            name = fruitType.fillType.title
        }
        table.insert(self.possibleCatchCropStates, state)
    end
end

g_cropRotation = CropRotation.new()
addModEventListener(g_cropRotation)