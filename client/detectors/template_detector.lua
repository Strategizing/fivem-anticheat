-- Template Detector
-- Use this as a base for creating new detectors

local DetectorName = "template"
local Detector = {
    active = false,
    interval = 5000, -- ms
    lastCheck = 0
}

-- Initialize the detector (called once)
function Detector.Initialize()
    print("Initializing " .. DetectorName .. " detector")
    return true
end

-- Start the detector (begin detecting)
function Detector.Start()
    if Detector.active then return false end
    
    Detector.active = true
    Citizen.CreateThread(function()
        while Detector.active do
            local currentTime = GetGameTimer()
            
            -- Only run if enough time has passed
            if currentTime - Detector.lastCheck > Detector.interval then
                Detector.Check()
                Detector.lastCheck = currentTime
            end
            
            Citizen.Wait(1000) -- Base wait time
        end
    end)
    
    print(DetectorName .. " detector started")
    return true
end

-- Stop the detector
function Detector.Stop()
    Detector.active = false
    print(DetectorName .. " detector stopped")
    return true
end

-- Check for violations
function Detector.Check()
    -- Detection logic here
    -- if violation_detected then
    --     NexusGuard:ReportCheat(DetectorName, "Detected violation")
    -- end
end

-- Get detector status
function Detector.GetStatus()
    return {
        active = Detector.active,
        lastCheck = Detector.lastCheck
    }
end

-- Register with the detector system
Citizen.CreateThread(function()
    Citizen.Wait(1000) -- Wait for DetectorRegistry to initialize
    DetectorRegistry.Register(DetectorName, Detector)
    
    -- Auto-start if enabled in config
    if Config and Config.Detectors and Config.Detectors[DetectorName] then
        Detector.Start()
    end
end)
