CatchCropManager = {}

local CatchCropManager_mt = Class(CatchCropManager)

function CatchCropManager.new(cropRotation, customMt)
	local self = setmetatable({}, customMt or CatchCropManager_mt)

    self.cropRotation = cropRotation

    return self
end

function CatchCropManager:resetCatchCropForField(field)
    g_asyncTaskManager:addSubtask(function()
        local catchCropModifier = self.catchCropMap:getModifier()
        field:getDensityMapPolygon():applyToModifier(catchCropModifier)
        catchCropModifier:executeSet(0)
    end, "Reset catch crop state for field "..field:getId())
end

function CatchCropManager:setCatchCropForField(field, catchCropIndex)
    g_asyncTaskManager:addSubtask(function()
        local catchCropModifier = self.catchCropMap:getModifier()
        field:getDensityMapPolygon():applyToModifier(catchCropModifier)
        catchCropModifier:executeSet(catchCropIndex)
    end, "Set catch crop for field: "..field:getId())
end