-- FiveM Debug Environment Stub
-- This file simulates the FiveM environment for local debugging
-- WARNING: This file should NEVER be included in production server files

-- Only load debug environment if we're not in a real FiveM environment
if not IsDuplicityVersion and not GetCurrentResourceName then

-- Global FiveM natives that may be used in your code
function GetPlayerPed() return 1 end
function PlayerId() return 0 end
function PlayerPedId() return 1 end
function GetEntityCoords() return {x=0, y=0, z=0} end
function GetEntityHealth() return 200 end
function GetPedArmour() return 0 end
function NetworkIsSessionActive() return true end
function GetCurrentResourceName() return "fivem-anticheat" end
function GetNumResources() return 10 end
function GetResourceByFindIndex(i) return "resource_" .. i end
function GetPedMaxHealth(ped) return 200 end
function GetPlayerInvincible() return false end
function IsEntityDead() return false end
function GetEntityVelocity() return 0, 0, 0 end
function GetEntityCollisionDisabled() return false end
function IsPedInParachuteFreeFall() return false end
function IsPedFalling() return false end
function IsPedJumpingOutOfVehicle() return false end
function IsPlayerSwitchInProgress() return false end
function IsScreenFadedOut() return false end
function GetGroundZFor_3dCoord() return true, 0 end

-- Citizen namespace
Citizen = {
    CreateThread = function(callback) 
        print("Creating thread") 
        callback()
    end,
    Wait = function(ms) 
        print("Waiting for " .. ms .. "ms")
    end
}

-- FiveM events
local eventHandlers = {}

function RegisterNetEvent(eventName)
    print("Registered network event: " .. eventName)
end

function AddEventHandler(eventName, callback)
    print("Added handler for event: " .. eventName)
    eventHandlers[eventName] = callback
end

function TriggerEvent(eventName, ...)
    print("Triggered event: " .. eventName)
    if eventHandlers[eventName] then
        eventHandlers[eventName](...)
    end
end

function TriggerServerEvent(eventName, ...)
    print("Triggered server event: " .. eventName)
end

function TriggerClientEvent(eventName, target, ...)
    print("Triggered client event: " .. eventName .. " for target: " .. target)
end

-- Other FiveM functions
function vector3(x, y, z)
    return {x = x or 0, y = y or 0, z = z or 0}
end

-- Debugging utilities
_G.DEBUG = {
    enabled = true,
    
    -- Print a table's contents recursively
    printTable = function(tbl, indent)
        indent = indent or 0
        for k, v in pairs(tbl) do
            local formatting = string.rep("  ", indent) .. k .. ": "
            if type(v) == "table" then
                print(formatting)
                DEBUG.printTable(v, indent + 1)
            else
                print(formatting .. tostring(v))
            end
        end
    end,
    
    -- Simulate a cheat detection
    simulateDetection = function(type, data)
        print("⚠️ Simulating cheat detection: " .. type)
        if eventHandlers["NexusGuard:CheatDetected"] then
            eventHandlers["NexusGuard:CheatDetected"](type, data or {})
        else
            print("❌ No handler registered for NexusGuard:CheatDetected")
        end
    end
}

-- Add this function to your debug stub
function DebugStep(name, func)
    print("🔍 DEBUG STEP: " .. name)
    local status, result = pcall(func)
    if status then
        print("✅ Step completed successfully")
        return result
    else
        print("❌ Step failed: " .. tostring(result))
        return nil
    end
end

-- Helper to load your script with FiveM environment
-- Changed from global to local function
local function LoadWithFiveM(scriptPath)
    print("Loading " .. scriptPath .. " with FiveM environment")
    local chunk, err = loadfile(scriptPath)
    if chunk then
        chunk()
        print("Successfully loaded " .. scriptPath)
    else
        print("Error loading " .. scriptPath .. ": " .. err)
    end
end

-- Export the LoadWithFiveM function globally so it can be used from outside
_G.LoadWithFiveM = LoadWithFiveM

print("FiveM debug environment loaded")
print("Use LoadWithFiveM('path/to/your/script.lua') to load a script")
print("WARNING: This is a debug environment and should not be used in production")

else
    print("Real FiveM environment detected - debug stub disabled")
end
