SeasonsImporter = {}

function SeasonsImporter.run()

    print("*** Starting animal import")

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

            local weightKg =
                getXMLFloat(
                    xmlFile,
                    animalKey .. "#seasonsWeightKg"
                )

            if weightKg ~= nil then

                print(
                    "*** Loaded "
                    .. clusterKey
                    .. " weight "
                    .. weightKg
                )

            else

                local ageMonths =
                    getXMLInt(
                        xmlFile,
                        animalKey .. "#age"
                    ) or 0

                weightKg =
                    100 + ageMonths * 15

                print(
                    "*** Imported "
                    .. clusterKey
                    .. " weight "
                    .. weightKg
                )

            end

            g_seasonsAnimals.animalManager:addCluster(
                clusterKey,
                {
                    weightKg = weightKg
                }
            )

            animalIndex = animalIndex + 1

        end

        placeableIndex = placeableIndex + 1

    end

    delete(xmlFile)

    print("*** Animal import complete")

end