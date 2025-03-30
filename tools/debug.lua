-- Create a debug script in your tools directory
-- filepath: s:\test\anticheat\fivem-anticheat\NexusGuard\tools\debug.lua

-- Load the FiveM environment stub
dofile("s:\\test\\anticheat\\fivem-anticheat\\NexusGuard\\tools\\fivem_debug_stub.lua")

-- Create a debug configuration
local DEBUG_CONFIG = {
    logLevel = 3, -- 1=error, 2=warn, 3=info, 4=debug
    simulateDetections = true,
    mockPlayers = {
        {id = 1, name = "TestPlayer1", identifiers = {steam = "steam:123", license = "license:abc"}},
        {id = 2, name = "TestPlayer2", identifiers = {steam = "steam:456", license = "license:def"}}
    }
}

-- Override GetPlayers function to return mock players
function GetPlayers()
    local playerIds = {}
    for i, player in ipairs(DEBUG_CONFIG.mockPlayers) do
        table.insert(playerIds, tostring(player.id))
    end
    return playerIds
end

function GetPlayerName(playerId)
    for _, player in ipairs(DEBUG_CONFIG.mockPlayers) do
        if tostring(player.id) == tostring(playerId) then
            return player.name
        end
    end
    return "Unknown"
end

-- Now load your main scripts
LoadWithFiveM("s:\\test\\anticheat\\fivem-anticheat\\client_main.lua")