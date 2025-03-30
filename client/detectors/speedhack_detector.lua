local DetectorName = "speedHack"
local Detector = {
    active = false,
    interval = 2000, -- Default, will be overridden by config if available
    lastCheck = 0
}

-- Initialize the detector (called once)
function Detector.Initialize()
    -- Update interval from global config if available
    if Config and Config.Detectors and Config.Detectors.speedHack and NexusGuard and NexusGuard.intervals and NexusGuard.intervals.speedHack then
        Detector.interval = NexusGuard.intervals.speedHack
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
    -- Cache config values locally
    local speedThresholdMultiplier = (Config and Config.Thresholds and Config.Thresholds.speedHackMultiplier) or 1.3
    local onFootSpeedThreshold = 10.0 -- Base threshold for on-foot speed, could also be made configurable

    local ped = PlayerPedId()

    -- Safety checks
    if not DoesEntityExist(ped) then return end

    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle ~= 0 then
        -- Vehicle speed check
        local speed = GetEntitySpeed(vehicle)
        local model = GetEntityModel(vehicle)
        local maxSpeed = GetVehicleModelMaxSpeed(model) -- Use native to get max speed for the specific model

        -- Check if maxSpeed is valid and speed exceeds threshold
        if maxSpeed > 0.1 and speed > (maxSpeed * speedThresholdMultiplier) then
            local kmhSpeed = math.floor(speed * 3.6)
            local kmhMaxSpeed = math.floor(maxSpeed * 3.6)
            if _G.NexusGuard and _G.NexusGuard.ReportCheat then
                _G.NexusGuard:ReportCheat(DetectorName, "Vehicle speed abnormal: " .. kmhSpeed .. " km/h (Max: " .. kmhMaxSpeed .. " km/h, Threshold: x" .. speedThresholdMultiplier .. ")")
            else
                 print("^1[NexusGuard:" .. DetectorName .. "]^7 Violation: Vehicle speed abnormal: " .. kmhSpeed .. " km/h (Max: " .. kmhMaxSpeed .. " km/h, Threshold: x" .. speedThresholdMultiplier .. ") (NexusGuard global unavailable)")
            end
        end
    else
        -- On-foot speed check
        local speed = GetEntitySpeed(ped)
        -- Check if player is exceeding threshold and not in a legitimate high-speed state
        if speed > onFootSpeedThreshold and not IsPedInParachuteFreeFall(ped) and not IsPedRagdoll(ped) and not IsPedFalling(ped) then
            if _G.NexusGuard and _G.NexusGuard.ReportCheat then
                _G.NexusGuard:ReportCheat(DetectorName, "Player movement speed abnormal: " .. math.floor(speed * 3.6) .. " km/h (Threshold: " .. math.floor(onFootSpeedThreshold * 3.6) .. " km/h)")
            else
                 print("^1[NexusGuard:" .. DetectorName .. "]^7 Violation: Player movement speed abnormal: " .. math.floor(speed * 3.6) .. " km/h (Threshold: " .. math.floor(onFootSpeedThreshold * 3.6) .. " km/h) (NexusGuard global unavailable)")
            end
        end
    end
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
    _G.DetectorRegistry.Register(DetectorName, Detector)

    -- Auto-start if enabled in config
    if Config and Config.Detectors and Config.Detectors[DetectorName] then
         -- Small delay to ensure NexusGuard is fully ready
         Citizen.Wait(100)
        _G.DetectorRegistry.Start(DetectorName)
    end
end)
