print("*** SeasonsAnimalsFrame.lua loaded")

SeasonsAnimalsFrame = {}

function SeasonsAnimalsFrame.register()

    local modDir = nil

    if g_currentModDirectory ~= nil then
        modDir = g_currentModDirectory
    elseif g_modsDirectory ~= nil and g_currentModName ~= nil then
        modDir = g_modsDirectory .. g_currentModName .. "/"
    end

    if modDir == nil then

        print("*** ERROR: Unable to determine mod directory")

        return nil

    end

    local xmlFilename =
        modDir ..
        "gui/SeasonsAnimalsFrame.xml"

    print("*** Loading SeasonsAnimalsFrame XML")
    print("*** XML = " .. tostring(xmlFilename))

    local frame =
        g_gui:loadGui(
            xmlFilename,
            "SeasonsAnimalsFrame",
            nil
        )

    if frame ~= nil then

        print("*** SeasonsAnimalsFrame created")

    else

        print("*** SeasonsAnimalsFrame creation FAILED")

    end

    return frame

end