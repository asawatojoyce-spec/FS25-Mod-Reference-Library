--
-- AdditionalSettingsUtil
--
-- @author Rockstar
-- @date 27/03/2021
--
--
--	@fs22 24/11/2021
--
--
-- @fs25 07/12/2024
--


AdditionalSettingsUtil = {
	eventListeners = {}
}

function AdditionalSettingsUtil.registerEvent(eventName)
	AdditionalSettingsUtil.eventListeners[eventName] = {}
end

function AdditionalSettingsUtil.registerEventListener(eventName, target)
	table.insert(AdditionalSettingsUtil.eventListeners[eventName], target)
end

function AdditionalSettingsUtil.raiseEvent(eventName, ...)
	for _, target in pairs(AdditionalSettingsUtil.eventListeners[eventName]) do
		target[eventName](target, ...)
	end
end

function AdditionalSettingsUtil.prependedFunction(oldTarget, oldFunc, newTarget, newFunc)
	local superFunc = oldTarget[oldFunc]

	oldTarget[oldFunc] = function(...)
		newTarget[newFunc](newTarget, ...)
		superFunc(...)
	end
end

function AdditionalSettingsUtil.appendedFunction(oldTarget, oldFunc, newTarget, newFunc)
	local superFunc = oldTarget[oldFunc]

	oldTarget[oldFunc] = function(...)
		superFunc(...)
		newTarget[newFunc](newTarget, ...)
	end
end

function AdditionalSettingsUtil.overwrittenFunction(oldTarget, oldFunc, newTarget, newFunc, isStatic)
	local superFunc = oldTarget[oldFunc]

	if isStatic then
		oldTarget[oldFunc] = function(...)
			return newTarget[newFunc](newTarget, superFunc, ...)
		end
	else
		oldTarget[oldFunc] = function(self, ...)
			return newTarget[newFunc](newTarget, self, superFunc, ...)
		end
	end
end

function AdditionalSettingsUtil.callFunction(target, funcName, ...)
	local func = target[funcName]

	if func ~= nil then
		return func(target, ...)
	end
end

function AdditionalSettingsUtil.copyFiles(directory, targetDirectory, filenames, force)
	if targetDirectory == "" or #filenames == 0 then
		return
	end

	createFolder(targetDirectory)

	for _, filename in pairs(filenames) do
		copyFile(directory .. filename, targetDirectory .. filename, force or false)
	end
end

function AdditionalSettingsUtil.info(infoMessage, ...)
	print(string.format("\nAdditionalGameSettings Info: " .. infoMessage, ...))
end

function AdditionalSettingsUtil.error(errorMessage, ...)
	printError(string.format("\nAdditionalGameSettings Error: " .. errorMessage, ...))
end

function AdditionalSettingsUtil.warning(warningMessage, ...)
	printWarning(string.format("\nAdditionalSettingsUtil Warning: " .. warningMessage, ...))
end

function AdditionalSettingsUtil.tableCount(tbl)
    local i = 0

    for _ in pairs(tbl) do
        i = i + 1
    end

    return i
end