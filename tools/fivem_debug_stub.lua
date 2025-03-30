-- FiveM Debug Environment Stub
-- This file simulates the FiveM environment for local debugging
-- WARNING: This file should NEVER be included in production server files

-- Only load debug environment if we're not in a real FiveM environment
if not IsDuplicityVersion and not GetCurrentResourceName then

print("🔧 Loading FiveM debug environment stub")

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
function IsPedArmed() return false end
function GetSelectedPedWeapon() return -1569615261 end -- WEAPON_UNARMED
function GetWeaponDamage() return 10.0 end
function GetWeaponClipSize() return 30 end
function GetVehiclePedIsIn() return 0 end
function GetVehicleMaxSpeed() return 30.0 end
function GetVehicleEngineHealth() return 1000.0 end
function IsVehicleDamaged() return false end
function GetVehicleClass() return 0 end
function NetworkGetPlayerIndexFromPed() return 0 end
function IsEntityVisible() return true end
function GetEntityAlpha() return 255 end
function IsEntityAttachedToEntity() return false end
function IsControlPressed() return false end
function IsDisabledControlPressed() return false end

-- Citizen namespace
Citizen = {
    CreateThread = function(callback) 
        print("🧵 Creating thread") 
        callback()
    end,
    Wait = function(ms) 
        print("⏱️ Waiting for " .. ms .. "ms")
        -- Actually sleep to simulate async behavior
        local startTime = os.clock()
        while os.clock() - startTime < (ms/1000) do end
    end,
    Trace = function(message)
        print("🔍 Trace: " .. message)
    end
}

-- FiveM events
local eventHandlers = {}

function RegisterNetEvent(eventName)
    print("📡 Registered network event: " .. eventName)
    return eventName
end

function AddEventHandler(eventName, callback)
    print("🔄 Added handler for event: " .. eventName)
    eventHandlers[eventName] = callback
    return eventName, callback
end

function TriggerEvent(eventName, ...)
    print("🔔 Triggered event: " .. eventName)
    local args = {...}
    if eventHandlers[eventName] then
        local status, err = pcall(function()
            eventHandlers[eventName](table.unpack(args))
        end)
        if not status then
            print("❌ Error in event handler for " .. eventName .. ": " .. tostring(err))
        end
    else
        print("⚠️ No handler for event: " .. eventName)
    end
end

function TriggerServerEvent(eventName, ...)
    print("📤 Triggered server event: " .. eventName)
    -- Simulate server-side handling by checking if there's a corresponding "onServer" event
    local serverEventName = "onServer" .. eventName:sub(eventName:find(":") or 0)
    if eventHandlers[serverEventName] then
        TriggerEvent(serverEventName, ...)
    end
    
    -- Also trigger some special events for testing
    if eventName == "NexusGuard:RequestSecurityToken" then
        TriggerEvent("NexusGuard:ReceiveSecurityToken", "DEBUG_TOKEN_123456")
    end
end

function TriggerClientEvent(eventName, target, ...)
    print("📥 Triggered client event: " .. eventName .. " for target: " .. target)
    local args = {...}
    -- In debug environment, treat client events as local events
    if eventHandlers[eventName] then
        local status, err = pcall(function()
            eventHandlers[eventName](table.unpack(args))
        end)
        if not status then
            print("❌ Error in client event handler for " .. eventName .. ": " .. tostring(err))
        end
    end
end

-- Vector handling
function vector3(x, y, z)
    return {x = x or 0, y = y or 0, z = z or 0, 
        __tostring = function(self)
            return string.format("(%0.1f, %0.1f, %0.1f)", self.x, self.y, self.z)
        end
    }
end

-- JSON handling
json = {
    encode = function(data)
        return DEBUG.formatJson(data)
    end,
    decode = function(jsonStr)
        -- Simple JSON decoder for debug purposes
        -- In a real environment, use a proper JSON library
        if not jsonStr or type(jsonStr) ~= "string" then return {} end
        local success, result = pcall(function()
            -- Use loadstring for simple JSON-like strings
            local str = jsonStr:gsub('"([^"]+)":', '["%1"]=')
            return assert(load("return " .. str))()
        end)
        return success and result or {}
    end
}

-- Debugging utilities
_G.DEBUG = {
    enabled = true,
    
    -- Print a table's contents recursively
    printTable = function(tbl, indent)
        if not tbl or type(tbl) ~= "table" then
            print(tostring(tbl))
            return
        end
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
    
    -- Format value for display
    formatValue = function(value)
        if type(value) == "table" then
            local result = "{"
            local first = true
            for k, v in pairs(value) do
                if not first then result = result .. ", " end
                first = false
                if type(v) == "table" then
                    result = result .. k .. "=" .. DEBUG.formatValue(v)
                else
                    result = result .. k .. "=" .. tostring(v)
                end
            end
            return result .. "}"
        else
            return tostring(value)
        end
    end,
    
    -- Format table as JSON
    formatJson = function(tbl)
        if type(tbl) ~= "table" then return tostring(tbl) end
        
        local function encodeValue(val)
            if type(val) == "string" then
                return '"' .. val:gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
            elseif type(val) == "table" then
                return DEBUG.formatJson(val)
            elseif type(val) == "boolean" or type(val) == "number" then
                return tostring(val)
            else
                return '"' .. tostring(val) .. '"'
            end
        end
        
        local isArray = #tbl > 0
        local result = isArray and "[" or "{"
        local first = true
        
        if isArray then
            for _, v in ipairs(tbl) do
                if not first then result = result .. "," end
                first = false
                result = result .. encodeValue(v)
            end
        else
            for k, v in pairs(tbl) do
                if not first then result = result .. "," end
                first = false
                result = result .. '"' .. tostring(k) .. '":' .. encodeValue(v)
            end
        end
        
        result = result .. (isArray and "]" or "}")
        return result
    end,
    
    -- Simulate a cheat detection
    simulateDetection = function(type, data)
        print("⚠️ Simulating cheat detection: " .. type)
        if eventHandlers["NexusGuard:ReportCheat"] then
            TriggerEvent("NexusGuard:ReportCheat", type, data or {}, "DEBUG_TOKEN_123456")
        else
            print("❌ No handler registered for NexusGuard:ReportCheat")
        end
    end,
    
    -- Execute a step with error handling
    runStep = function(name, func)
        print("🔍 Running step: " .. name)
        local status, result = pcall(func)
        if status then
            print("✅ Step completed: " .. name)
            return result
        else
            print("❌ Step failed: " .. name .. " - " .. tostring(result))
            return nil
        end
    end
}

-- Exports system
exports = setmetatable({}, {
    __index = function(_, resourceName)
        return setmetatable({}, {
            __index = function(_, exportName)
                return function(...)
                    print("📦 Export called: " .. resourceName .. ":" .. exportName)
                    return nil
                end
            end
        })
    end
})

-- Helper to load your script with FiveM environment
_G.LoadWithFiveM = function(scriptPath)
    print("📂 Loading " .. scriptPath .. " with FiveM environment")
    local chunk, err = loadfile(scriptPath)
    if chunk then
        local status, error = pcall(chunk)
        if status then
            print("✅ Successfully loaded " .. scriptPath)
        else
            print("❌ Error executing " .. scriptPath .. ": " .. tostring(error))
        end
    else
        print("❌ Error loading " .. scriptPath .. ": " .. tostring(err))
    end
end

print("✅ FiveM debug environment loaded")

else
    print("⚠️ Real FiveM environment detected - debug stub disabled")
end
