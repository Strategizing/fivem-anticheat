--[[
    NexusGuard Anti-Cheat Loader
    Ensures proper initialization of the anti-cheat system
]]

local resourceName = GetCurrentResourceName()
local isServer = IsDuplicityVersion()
local environment = isServer and "SERVER" or "CLIENT"

-- Check FiveM version compatibility
local function CheckCompatibility()
    -- This is a placeholder - in a real implementation,
    -- you would check for specific FiveM version requirements
    return true, "Compatible"
end

-- Log initialization steps
local function Log(message)
    local prefix = string.format("[NexusGuard:%s]", environment)
    print(string.format("%s %s", prefix, message))
end

-- Initialize the anti-cheat
local function Initialize()
    Log("Starting initialization...")
    
    -- Check compatibility
    local isCompatible, reason = CheckCompatibility()
    if not isCompatible then
        Log("COMPATIBILITY ERROR: " .. reason)
        return false
    end
    
    -- Load the appropriate environment
    if isServer then
        Log("Loading server components...")
        -- Server initialization would happen here if needed
        -- Most initialization happens in server_main.lua
    else
        Log("Loading client components...")
        -- Client initialization would happen here if needed
        -- Most initialization happens in client_main.lua
    end
    
    Log("Initialization complete")
    return true
end

-- Execute initialization
Citizen.CreateThread(function()
    Citizen.Wait(100) -- Brief delay to ensure resource is fully started
    local success = Initialize()
    
    if not success then
        Log("Failed to initialize NexusGuard")
    else
        Log("NexusGuard is now protecting your server")
    end
end)

-- Export initialization status
if isServer then
    exports('getStatus', function()
        return {
            version = "1.1.0",
            initialized = true,
            resourceName = resourceName
        }
    end -- Close the function passed to exports
    ) -- Close the exports call
end -- Close the if isServer block
