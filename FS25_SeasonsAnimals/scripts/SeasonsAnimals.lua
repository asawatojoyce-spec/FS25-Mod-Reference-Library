SeasonsAnimals = {}
local initialized = false

function SeasonsAnimals:loadMap()
    addModEventListener(self)
end

function SeasonsAnimals:loadMapFinished()
    if initialized then return end
    initialized = true
    print("[SeasonsAnimals] Data initialized")
end

print("[SeasonsAnimals] Boot UI hook init")
if SeasonsAnimalUIHook ~= nil then
    SeasonsAnimalUIHook:initialize()
end
