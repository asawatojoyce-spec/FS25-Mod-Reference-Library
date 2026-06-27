SeasonsPersistence = {}

function SeasonsPersistence.save()

    print("*** Saving Seasons animal data")

    local filename =
        g_currentMission.missionInfo.savegameDirectory ..
        "/placeables.xml"

    local xmlFile =
        loadXMLFile(
            "placeablesXML",
            filename
        )

    local placeableIndex = 0

    while true do

        local placeableKey =
            string.format(
                "placeables.placeable(%d)",
                placeableIndex
            )

        if not hasXMLProperty(
            xmlFile,
            placeableKey
        ) then
            break
        end

        local uniqueId =
            getXMLString(
                xmlFile,
                placeableKey .. "#uniqueId"
            )

        local animalIndex = 0

        while true do

            local animalKey =
                string.format(
                    "%s.husbandryAnimals.clusters.animal(%d)",
                    placeableKey,
                    animalIndex
                )

            if not hasXMLProperty(
                xmlFile,
                animalKey
            ) then
                break
            end

            local clusterKey =
                uniqueId .. "_" .. animalIndex

            local data =
                g_seasonsAnimals.animalManager:getCluster(
                    clusterKey
                )

            if data ~= nil then

                setXMLFloat(
                    xmlFile,
                    animalKey .. "#seasonsWeightKg",
                    data.weightKg
                )

                print(
                    "*** Saved "
                    .. clusterKey
                    .. " weight "
                    .. data.weightKg
                )

            end

            animalIndex = animalIndex + 1

        end

        placeableIndex = placeableIndex + 1

    end

    saveXMLFile(
        xmlFile
    )

    delete(xmlFile)

end