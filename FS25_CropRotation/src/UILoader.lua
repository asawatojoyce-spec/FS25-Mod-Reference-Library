UILoader = {
    MOD_NAME = g_currentModName,
    MOD_DIRECTORY = g_currentModDirectory
}

source(g_currentModDirectory.."src/gui/InGameMenuCropRotationPlanner.lua")
source(g_currentModDirectory.."src/events/CropRotationEntryEvent.lua")

function init()
    Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, loadedMission)
end

function loadedMission()
	local inGameMenuCropRotationPlanner = InGameMenuCropRotationPlanner.new(g_i18n, g_messageCenter)
	g_gui:loadGui(UILoader.MOD_DIRECTORY.."gui/InGameMenuCropRotationPlanner.xml", "InGameMenuCropRotationPlanner", inGameMenuCropRotationPlanner, true)
    fixInGameMenu(inGameMenuCropRotationPlanner, "InGameMenuCropRotationPlanner", {0, 0, 1024, 1024}, 7, nil)
    inGameMenuCropRotationPlanner:initialize()

	g_overlayManager:addTextureConfigFile(UILoader.MOD_DIRECTORY .. "images/helplineCropRotation.xml", "helplineCropRotation")
end

function fixInGameMenu(frame, pageName, uvs, position, predicateFunc)
	local inGameMenu = g_gui.screenControllers[InGameMenu]

	for k, v in pairs({pageName}) do
		inGameMenu.controlIDs[v] = nil
	end
	
	inGameMenu[pageName] = frame
	inGameMenu.pagingElement:addElement(inGameMenu[pageName])

	inGameMenu:exposeControlsAsFields(pageName)

	for i = 1, #inGameMenu.pagingElement.elements do
		local child = inGameMenu.pagingElement.elements[i]
		if child == inGameMenu[pageName] then
			table.remove(inGameMenu.pagingElement.elements, i)
			table.insert(inGameMenu.pagingElement.elements, position, child)
			break
		end
	end

	for i = 1, #inGameMenu.pagingElement.pages do
		local child = inGameMenu.pagingElement.pages[i]
		if child.element == inGameMenu[pageName] then
			table.remove(inGameMenu.pagingElement.pages, i)
			table.insert(inGameMenu.pagingElement.pages, position, child)
			break
		end
	end

	inGameMenu.pagingElement:updateAbsolutePosition()
	inGameMenu.pagingElement:updatePageMapping()
	
	inGameMenu:registerPage(inGameMenu[pageName], position, predicateFunc)
	local iconFileName = Utils.getFilename('images/menuIcon.dds', UILoader.MOD_DIRECTORY)
	inGameMenu:addPageTab(inGameMenu[pageName], iconFileName, GuiUtils.getUVs(uvs))

	for i = 1, #inGameMenu.pageFrames do
		local child = inGameMenu.pageFrames[i]
		if child == inGameMenu[pageName] then
			table.remove(inGameMenu.pageFrames, i)
			table.insert(inGameMenu.pageFrames, position, child)
			break
		end
	end

	inGameMenu:rebuildTabList()
end

init()