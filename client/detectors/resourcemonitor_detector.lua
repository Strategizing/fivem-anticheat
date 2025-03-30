local DetectorName = "resourceMonitor" -- Using camelCase to match client_main interval key
local ConfigKey = "resourceInjection" -- Key used in Config.Detectors table
local Detector = {
    active = false,
    interval = 15000, -- Default, will be overridden by config if available
    lastCheck = 0
}

-- Initialize the detector (called once)
function Detector.Initialize()
    -- Update interval from global config if available
    if Config and Config.Detectors and Config.Detectors[ConfigKey] and NexusGuard and NexusGuard.intervals and NexusGuard.intervals.resourceMonitor then
        Detector.interval = NexusGuard.intervals.resourceMonitor
    end
    print("^2[NexusGuard:" .. DetectorName .. "]^7 Initialized with interval: " .. Detector.interval .. "ms")
    return true
end

-- Start the detector (Called by Registry)
-- The registry now handles the thread creation loop.
function Detector.Start()
    if Detector.active then return false end -- Already active
    Detector.active = true
    -- No need to create thread here, registry does it.
    -- Print statement moved to registry for consistency.
    return true -- Indicate success
end

-- Stop the detector (Called by Registry)
-- The registry relies on this setting the active flag to false.
function Detector.Stop()
    if not Detector.active then return false end -- Already stopped
    Detector.active = false
    -- Print statement moved to registry for consistency.
    return true -- Indicate success
end

-- Check for violations (Moved logic from client_main.lua)
function Detector.Check()
    -- Ensure NexusGuard global and security token are available before sending
    if not _G.NexusGuard or not _G.NexusGuard.securityToken then
        print("^3[NexusGuard:" .. DetectorName .. "]^7 Skipping check, NexusGuard or security token not ready.")
        return
    end

    -- Get all currently running resources
    local runningResources = {}
    local resourceCount = GetNumResources()
    for i = 0, resourceCount - 1 do
        local resourceName = GetResourceByFindIndex(i)
        -- Filter out default resources or resources known to be safe if needed
        if resourceName and resourceName ~= GetCurrentResourceName() then -- Don't include self
            table.insert(runningResources, resourceName)
        end
    end

    -- Send the list to the server for verification against a whitelist/blacklist
    -- The server-side event 'NexusGuard:VerifyResources' needs to implement the actual validation logic.
    TriggerServerEvent("NexusGuard:VerifyResources", runningResources, _G.NexusGuard.securityToken)

    -- Client-side doesn't typically "detect" injection directly, it reports the state for server validation.
    -- No NexusGuard:ReportCheat call here unless a specific client-side indicator is found (which is rare/unreliable).
end


-- Get detector status
function Detector.GetStatus()
    return {
        active = Detector.active,
        lastCheck = Detector.lastCheck,
        interval = Detector.interval
    }
end

-- Register with the detector system
Citizen.CreateThread(function()
    -- Wait for NexusGuard and DetectorRegistry to initialize
    while not _G.NexusGuard or not _G.DetectorRegistry do
        Citizen.Wait(500)
    end

    -- Initialize after registry is ready
    Detector.Initialize()
    -- Use the ConfigKey ('resourceInjection') for registration and checking if enabled
    _G.DetectorRegistry.Register(ConfigKey, Detector) -- Register using the key from Config

    -- Auto-start if enabled in config using the ConfigKey
    if Config and Config.Detectors and Config.Detectors[ConfigKey] then
         -- Small delay to ensure NexusGuard is fully ready
         Citizen.Wait(100)
        _G.DetectorRegistry.Start(ConfigKey) -- Start using the key from Config
    end
end)
