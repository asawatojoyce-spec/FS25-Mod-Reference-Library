SeasonsAnimalManager = {}

-- =========================================================
-- Seasons Animal Manager
-- Core runtime orchestration layer
-- =========================================================

function SeasonsAnimalManager.new()
    local self = {}

    -- -----------------------------------------------------
    -- Data storage
    -- -----------------------------------------------------
    self.clusters = {}

    -- -----------------------------------------------------
    -- UI Hook system (Phase 1 integration)
    -- -----------------------------------------------------
    self.uiHook = nil

    -- -----------------------------------------------------
    -- Initialize manager systems
    -- -----------------------------------------------------
    function self:initialize()
        print("[SeasonsAnimalManager] initialized")

        -- Create UI hook instance (safe, no base game edits)
        if g_seasonsAnimalUIHook ~= nil then
            self.uiHook = g_seasonsAnimalUIHook
        end
    end

    -- -----------------------------------------------------
    -- MAIN UPDATE LOOP
    -- This is now the correct injection point for UI hook
    -- -----------------------------------------------------
    function self:update(dt)

        -- SAFE UI hook execution (Phase 1)
        if self.uiHook ~= nil then
            SeasonsAnimalUIHook_Update(dt)
        end

        -- Future: cluster updates / data sync
        -- (Phase 2 will expand this)
    end

    -- -----------------------------------------------------
    -- Cluster management (existing system preserved)
    -- -----------------------------------------------------
    function self:addCluster(key, data)
        self.clusters[key] = data
    end

    function self:getCluster(key)
        return self.clusters[key]
    end

    function self:getAllClusters()
        return self.clusters
    end

    -- -----------------------------------------------------
    -- Debug helper
    -- -----------------------------------------------------
    function self:debugPrintClusters()
        for k, v in pairs(self.clusters) do
            print("[SeasonsAnimalManager] Cluster:", k)
        end
    end

    return self
end