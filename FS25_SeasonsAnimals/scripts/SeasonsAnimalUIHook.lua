SeasonsAnimalUIHook = {}
SeasonsAnimalUIHook.modDirectory = g_currentModDirectory
local initialized = false

function SeasonsAnimalUIHook:initialize()
    if initialized then return end
    initialized = true

    InGameMenu.onLoad = Utils.appendedFunction(InGameMenu.onLoad, SeasonsAnimalUIHook.onMenu)
end

function SeasonsAnimalUIHook.onMenu(menu)
    if menu.seasonsAnimalPageFrame ~= nil then return end

    local frame = SeasonsAnimalUI.new(menu)
    menu.seasonsAnimalPageFrame = frame

    local xml = SeasonsAnimalUIHook.modDirectory .. "gui/SeasonsAnimalScreen.xml"

    g_gui:loadControlFromFile(xml, "seasonsAnimalPageFrame", frame, menu)

    menu:registerPage(frame, #menu.pages + 1, {"icon_animals"})

    if menu.pagingTabList ~= nil then
        menu.pagingTabList:rebuildTabs()
    end
end
