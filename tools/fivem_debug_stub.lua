-- FiveM Debug Environment Stub
-- This file simulates the FiveM environment for local debugging

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
