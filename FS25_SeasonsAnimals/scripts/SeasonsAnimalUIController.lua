SeasonsAnimalUIController = {}
local initialized = false

function SeasonsAnimalUIController:initialize()
    if initialized then return end
    initialized = true
end

function SeasonsAnimalUIController:refreshUIFrame(frame)
    if frame.debugLabel ~= nil then
        frame.debugLabel:setText("Seasons Animals FINAL BUILD ACTIVE")
    end
end
