SeasonsAnimalUI = {}
local SeasonsAnimalUI_mt = Class(SeasonsAnimalUI, TabbedMenuFrameElement)

function SeasonsAnimalUI.new(menu)
    local self = TabbedMenuFrameElement.new(nil, SeasonsAnimalUI_mt)
    self.menu = menu
    self.hasCustomMenuButtons = true
    return self
end

function SeasonsAnimalUI:initialize()
    self.backButtonInfo = {
        inputAction = InputAction.MENU_BACK
    }

    self.menuButtons = {
        self.backButtonInfo
    }

    self:setMenuButtonInfo(self.menuButtons)
end

function SeasonsAnimalUI:onGuiSetupFinished()
    SeasonsAnimalUI:superClass().onGuiSetupFinished(self)
    print("[SeasonsAnimalUI] GUI setup finished")
end

function SeasonsAnimalUI:onFrameOpen()
    SeasonsAnimalUI:superClass().onFrameOpen(self)
    print("[SeasonsAnimalUI] Frame opened")
    if SeasonsAnimalUIController ~= nil then
        SeasonsAnimalUIController:refreshUIFrame(self)
    end
end
