SeasonsAnimalInfo = {}


function SeasonsAnimalInfo.getClusterKey(
    uniqueId,
    animalIndex
)

    return uniqueId ..
        "_" ..
        tostring(
            animalIndex
        )

end


function SeasonsAnimalInfo.getWeightKg(
    clusterKey
)

    local data =
        g_seasonsAnimals.animalManager:getCluster(
            clusterKey
        )

    if data == nil then
        return nil
    end

    return data.weightKg

end


function SeasonsAnimalInfo.getWeightText(
    clusterKey
)

    local weightKg =
        SeasonsAnimalInfo.getWeightKg(
            clusterKey
        )

    if weightKg == nil then
        return "--"
    end

    return string.format(
        "%.0f kg",
        weightKg
    )

end