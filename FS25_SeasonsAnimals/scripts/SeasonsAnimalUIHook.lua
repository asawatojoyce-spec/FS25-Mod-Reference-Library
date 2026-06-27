SeasonsAnimalUIHook = {}
SeasonsAnimalUIHook.modDirectory = g_currentModDirectory
local initialized = false

function SeasonsAnimalUIHook:initialize()
    if initialized then return end

    if InGameMenu == nil then
        print("[SeasonsAnimalUIHook] ERROR: InGameMenu class is not available")
        return
    end

    initialized = true

    InGameMenu.onLoad = Utils.appendedFunction(InGameMenu.onLoad, SeasonsAnimalUIHook.onMenu)
    print("[SeasonsAnimalUIHook] InGameMenu.onLoad hook installed")
end

function SeasonsAnimalUIHook.onMenu(menu)
    print("[SeasonsAnimalUIHook] InGameMenu.onLoad fired")

    if menu == nil then
        print("[SeasonsAnimalUIHook] ERROR: menu is nil")
        return
    end

    if menu.seasonsAnimalPageFrame ~= nil then return end
    if SeasonsAnimalUI == nil then
        print("[SeasonsAnimalUIHook] ERROR: SeasonsAnimalUI class is nil")
        return
    end
    if g_gui == nil then
        print("[SeasonsAnimalUIHook] ERROR: g_gui is nil")
        return
    end
    if menu.pagingElement == nil then
        print("[SeasonsAnimalUIHook] ERROR: pagingElement is nil")
        return
    end

    local frame = SeasonsAnimalUI.new(menu)
    menu.seasonsAnimalPageFrame = frame

    local xml = SeasonsAnimalUIHook.modDirectory .. "gui/SeasonsAnimalScreen.xml"

    g_gui:loadControlFromFile(xml, "seasonsAnimalPageFrame", frame, menu)
    print("[SeasonsAnimalUIHook] XML loaded: " .. tostring(xml))

    if menu.pagingElement.addElement == nil then
        print("[SeasonsAnimalUIHook] ERROR: pagingElement.addElement is nil")
        return
    end

    menu.pagingElement:addElement(frame)

    if menu.exposeControlsAsFields ~= nil then
        menu:exposeControlsAsFields("seasonsAnimalPageFrame")
    end

    local position = #menu.pagingElement.elements

    if menu.pageAnimals ~= nil then
        for i, element in ipairs(menu.pagingElement.elements) do
            if element == menu.pageAnimals then
                position = i + 1
                break
            end
        end
    end

    for i, element in ipairs(menu.pagingElement.elements) do
        if element == frame then
            table.remove(menu.pagingElement.elements, i)
            table.insert(menu.pagingElement.elements, position, frame)
            break
        end
    end

    if menu.pagingElement.updateAbsolutePosition ~= nil then
        menu.pagingElement:updateAbsolutePosition()
    end

    if menu.pagingElement.updatePageMapping ~= nil then
        menu.pagingElement:updatePageMapping()
    end

    menu:registerPage(frame, position, nil)
    print("[SeasonsAnimalUIHook] Page registered at position " .. tostring(position))

    if menu.addPageTab ~= nil then
        menu:addPageTab(frame, nil, nil, "gui.icon_animals")
        print("[SeasonsAnimalUIHook] Page tab added")
    end

    if menu.pageFrames ~= nil then
        for i, pageFrame in ipairs(menu.pageFrames) do
            if pageFrame == frame then
                table.remove(menu.pageFrames, i)
                table.insert(menu.pageFrames, position, frame)
                break
            end
        end
    end

    if frame.onGuiSetupFinished ~= nil then
        frame:onGuiSetupFinished()
    end

    if frame.initialize ~= nil then
        frame:initialize()
    end

    if menu.rebuildTabList ~= nil then
        menu:rebuildTabList()
        print("[SeasonsAnimalUIHook] Tab list rebuilt")
    elseif menu.pagingTabList ~= nil and menu.pagingTabList.rebuildTabs ~= nil then
        menu.pagingTabList:rebuildTabs()
        print("[SeasonsAnimalUIHook] Paging tab list rebuilt")
    end
end
