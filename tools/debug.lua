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

-- Initialize global test results container
_G.testResults = {
    detections = {},
    passed = 0,
    failed = 0,
    total = 0,
    startTime = os.time()
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

-- Add detection record
function RecordDetection(type, data)
    table.insert(testResults.detections, {
        type = type,
        data = data,
        timestamp = os.time()
    })
    DebugLog(3, "Recorded detection: " .. type)
end

-- Test function to simulate cheat detections
function SimulateCheatDetection(playerId, detectionType, detectionData)
    DebugLog(3, string.format("Simulating cheat detection: Player %s - Type: %s", 
                              GetPlayerName(playerId), detectionType))
    
    -- Record the detection
    RecordDetection(detectionType, detectionData)
    
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

-- Load and run test cases from test_cases.lua
function LoadAndRunTestCases()
    local testCasesPath = DEBUG_CONFIG.basePath .. "tools\\test_cases.lua"
    DebugLog(3, "Loading test cases from: " .. testCasesPath)
    
    local status, testCases = pcall(function()
        local chunk, err = loadfile(testCasesPath)
        if not chunk then
            DebugLog(1, "Failed to load test cases: " .. tostring(err))
            return {}
        end
        return chunk() or {}
    end)
    
    if not status or type(testCases) ~= "table" then
        DebugLog(1, "Error loading test cases: " .. tostring(testCases))
        return false
    end
    
    DebugLog(3, "Loaded " .. #testCases .. " test cases")
    
    -- Clear previous test results
    testResults.detections = {}
    testResults.passed = 0
    testResults.failed = 0
    testResults.total = #testCases
    testResults.startTime = os.time()
    
    -- Expose required DEBUG functions for test cases
    DEBUG.logResult = function(name, passed, message)
        if passed then
            testResults.passed = testResults.passed + 1
            DebugLog(3, "✅ PASS: " .. name .. (message and " - " .. message or ""))
        else
            testResults.failed = testResults.failed + 1
            DebugLog(2, "❌ FAIL: " .. name .. (message and " - " .. message or ""))
        end
    end
    
    -- Run all test cases
    for i, testCase in ipairs(testCases) do
        DebugLog(3, "Running test case " .. i .. ": " .. testCase.name)
        
        -- Setup test
        if testCase.setup then
            local setupStatus, setupErr = pcall(testCase.setup)
            if not setupStatus then
                DebugLog(1, "Error in test setup: " .. tostring(setupErr))
            end
        end
        
        -- Run test
        local runStatus, result, message = pcall(testCase.run)
        
        -- Process result
        if runStatus then
            DEBUG.logResult(testCase.name, result == testCase.expectation, message)
        else
            DebugLog(1, "Error executing test: " .. tostring(result))
            DEBUG.logResult(testCase.name, false, "Test execution error")
        end
        
        -- Teardown
        if testCase.teardown then
            local teardownStatus, teardownErr = pcall(testCase.teardown)
            if not teardownStatus then
                DebugLog(1, "Error in test teardown: " .. tostring(teardownErr))
            end
        end
    end
    
    -- Report results
    local duration = os.time() - testResults.startTime
    print(string.format("\n===== Test Results ====="))
    print(string.format("Total tests: %d", testResults.total))
    print(string.format("Passed: %d (%d%%)", testResults.passed, 
                      testResults.total > 0 and math.floor(testResults.passed/testResults.total*100) or 0))
    print(string.format("Failed: %d", testResults.failed))
    print(string.format("Duration: %d seconds", duration))
    print("========================\n")
    
    return true
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

-- Interactive debug console
function StartDebugConsole()
    print("\n===== NexusGuard Debug Console =====")
    print("Available commands:")
    print("  help          - Show this help message")
    print("  test          - Run all test cases")
    print("  detect [type] - Simulate a detection (godmode, weapon, vehicle)")
    print("  status        - Show current status and test results")
    print("  exit          - Exit the debug console")
    
    while true do
        io.write("\nDebug> ")
        local input = io.read()
        if not input then break end
        
        local command = input:match("^(%S+)")
        local args = input:sub(#command + 2)
        
        if command == "exit" then
            print("Exiting debug console...")
            break
            
        elseif command == "help" then
            print("Available commands:")
            print("  help          - Show this help message")
            print("  test          - Run all test cases")
            print("  detect [type] - Simulate a detection (godmode, weapon, vehicle)")
            print("  status        - Show current status and test results")
            print("  exit          - Exit the debug console")
            
        elseif command == "test" then
            print("Running test cases...")
            LoadAndRunTestCases()
            
        elseif command == "detect" then
            local detType = args:match("^(%S+)")
            if detType == "godmode" then
                SimulateCheatDetection("3", "godmode", {health = 500, maxHealth = 200})
                print("Simulated godmode detection")
            elseif detType == "weapon" then
                SimulateCheatDetection("3", "weaponmod", {damage = 500, clipSize = 999})
                print("Simulated weapon modification detection")
            elseif detType == "vehicle" then
                SimulateCheatDetection("3", "vehiclemod", {speed = 500, expectedSpeed = 200})
                print("Simulated vehicle modification detection")
            else
                print("Unknown detection type. Use: godmode, weapon, or vehicle")
            end
            
        elseif command == "status" then
            print("Debug Status:")
            print("  Detections recorded: " .. #testResults.detections)
            print("  Tests passed: " .. testResults.passed)
            print("  Tests failed: " .. testResults.failed)
            
        else
            print("Unknown command: " .. command .. ". Type 'help' for available commands.")
        end
    end
end

-- Run the debug environment
print("=== NexusGuard Anti-Cheat Debug Environment ===")
LoadNexusGuardScripts()
print("Debug environment loaded and ready")

-- Start interactive console
StartDebugConsole()