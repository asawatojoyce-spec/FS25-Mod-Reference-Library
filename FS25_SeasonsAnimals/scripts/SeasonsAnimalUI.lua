SeasonsAnimalUI = {}
local SeasonsAnimalUI_mt = Class(SeasonsAnimalUI, TabbedMenuFrameElement)

function SeasonsAnimalUI.new(menu)
    local self = TabbedMenuFrameElement.new(nil, SeasonsAnimalUI_mt)
    self.menu = menu
    return self
end

function SeasonsAnimalUI:onGuiSetupFinished()
    SeasonsAnimalUI:superClass().onGuiSetupFinished(self)
end

function SeasonsAnimalUI:onFrameOpen()
    SeasonsAnimalUI:superClass().onFrameOpen(self)
    if SeasonsAnimalUIController ~= nil then
        SeasonsAnimalUIController:refreshUIFrame(self)
    end
end
