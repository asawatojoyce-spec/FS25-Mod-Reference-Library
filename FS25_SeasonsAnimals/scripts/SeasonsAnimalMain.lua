-- =========================================================
-- SeasonsAnimalMain.lua
-- Phase 1: Engine update loop binding (CRITICAL)
-- =========================================================

SeasonsAnimalMain = {}

local SeasonsAnimalMain_mt = Class(SeasonsAnimalMain)

-- Global manager instance (must exist before update)
g_seasonsAnimalManager = nil

-- ---------------------------------------------------------
-- Initialize mod system
-- ---------------------------------------------------------
function SeasonsAnimalMain:load()
    print("[SeasonsAnimalMain] loading Seasons Animals system")

    -- Create manager instance
    g_seasonsAnimalManager = SeasonsAnimalManager.new()
    g_seasonsAnimalManager:initialize()

    -- Attach update hook into engine loop safely
    self:injectIntoGameLoop()
end

-- ---------------------------------------------------------
-- SAFE ENGINE HOOK (no register(), no base edits)
-- ---------------------------------------------------------
function SeasonsAnimalMain:injectIntoGameLoop()

    if g_currentMission == nil then
        print("[SeasonsAnimalMain] ERROR: g_currentMission not available yet")
        return
    end

    local oldUpdate = g_currentMission.update

    g_currentMission.update = function(mission, dt, ...)

        -- call original game update FIRST
        if oldUpdate ~= nil then
            oldUpdate(mission, dt, ...)
        end

        -- OUR MOD UPDATE CHAIN
        if g_seasonsAnimalManager ~= nil then
            g_seasonsAnimalManager:update(dt)
        end
    end

    print("[SeasonsAnimalMain] Successfully injected into game loop")
end

-- ---------------------------------------------------------
-- FS Mod entry point
-- ---------------------------------------------------------
function SeasonsAnimalMain:loadMap(name)
    self:load()
end

function SeasonsAnimalMain:delete()
    print("[SeasonsAnimalMain] shutting down Seasons Animals system")
end