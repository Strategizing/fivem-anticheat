-- Debug script for NexusGuard Anti-Cheat system testing

-- Load the FiveM environment stub
dofile("s:\\test\\anticheat\\fivem-anticheat\\NexusClone\\fivem-anticheat\\tools\\fivem_debug_stub.lua")

-- Create a debug configuration
local DEBUG_CONFIG = {
    logLevel = 3, -- 1=error, 2=warn, 3=info, 4=debug
    simulateDetections = true,
    enableConsoleOutput = true,
    basePath = "s:\\test\\anticheat\\fivem-anticheat\\NexusClone\\fivem-anticheat\\",
    mockPlayers = {
        {id = 1, name = "TestPlayer1", identifiers = {steam = "steam:123", license = "license:abc"}},
        {id = 2, name = "TestPlayer2", identifiers = {steam = "steam:456", license = "license:def"}},
        {id = 3, name = "CheaterPlayer", identifiers = {steam = "steam:789", license = "license:ghi"}}
    }
}

-- Debug logging function
function DebugLog(level, message)
    local levels = {[1] = "ERROR", [2] = "WARN", [3] = "INFO", [4] = "DEBUG"}
    if level <= DEBUG_CONFIG.logLevel then
        print(string.format("[%s] %s", levels[level], message))
    end
end

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

-- Get player identifiers (expand for more identifier types if needed)
function GetPlayerIdentifiers(playerId)
    for _, player in ipairs(DEBUG_CONFIG.mockPlayers) do
        if tostring(player.id) == tostring(playerId) then
            local identifiers = {}
            for type, value in pairs(player.identifiers) do
                table.insert(identifiers, value)
            end
            return identifiers
        end
    end
    return {}
end

function GetPlayerIdentifierByType(playerId, idType)
    for _, player in ipairs(DEBUG_CONFIG.mockPlayers) do
        if tostring(player.id) == tostring(playerId) then
            return player.identifiers[idType] or nil
        end
    end
    return nil
end

-- Test function to simulate cheat detections
function SimulateCheatDetection(playerId, detectionType, detectionData)
    DebugLog(3, string.format("Simulating cheat detection: Player %s - Type: %s", 
                              GetPlayerName(playerId), detectionType))
    
    -- Call the detection event handler directly
    TriggerEvent("NexusGuard:ReportCheat", playerId, detectionType, detectionData or {}, "debug-token")
end

-- Function to test specific detections
function TestDetections()
    DebugLog(3, "Running automated detection tests...")
    
    -- Simulate various detections
    local cheaterPlayer = "3" -- ID of our test cheater
    
    -- Wait between tests to simulate time passing
    local function wait(ms)
        local start = os.time()
        while os.time() < start + (ms/1000) do end
    end
    
    -- Godmode detection
    SimulateCheatDetection(cheaterPlayer, "godmode", {
        health = 500,
        maxHealth = 200,
        invincibilityFlag = true
    })
    wait(100)
    
    -- Weapon modification detection
    SimulateCheatDetection(cheaterPlayer, "weaponModification", {
        weaponHash = 123456789,
        damage = 500,
        clipSize = 999
    })
    wait(100)
    
    -- Vehicle modification detection
    SimulateCheatDetection(cheaterPlayer, "vehicleModification", {
        speed = 500,
        expectedSpeed = 200,
        vehicleModel = "adder"
    })
    
    DebugLog(3, "Detection tests completed")
end

-- Load main scripts from the correct paths
function LoadNexusGuardScripts()
    DebugLog(3, "Loading NexusGuard scripts from: " .. DEBUG_CONFIG.basePath)
    
    -- Load client script
    local clientPath = DEBUG_CONFIG.basePath .. "client_main.lua"
    DebugLog(3, "Loading client script: " .. clientPath)
    LoadWithFiveM(clientPath)
    
    -- Load server script
    local serverPath = DEBUG_CONFIG.basePath .. "server_main.lua"
    DebugLog(3, "Loading server script: " .. serverPath)
    LoadWithFiveM(serverPath)
    
    -- Simulate resource start events
    DebugLog(3, "Triggering resource start events")
    TriggerEvent("onResourceStart", GetCurrentResourceName())
    TriggerEvent("onClientResourceStart", GetCurrentResourceName())
    
    -- Run tests if enabled
    if DEBUG_CONFIG.simulateDetections then
        TestDetections()
    end
end

-- Run the debug environment
print("=== NexusGuard Anti-Cheat Debug Environment ===")
LoadNexusGuardScripts()
print("Debug environment loaded and ready")