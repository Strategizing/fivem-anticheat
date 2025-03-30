local DetectorName = "teleporting" -- Match the key in Config.Detectors
local Detector = {
    active = false,
    interval = 1000, -- Default, will be overridden by config if available
    lastCheck = 0,
    state = { -- Local state for position tracking
        position = nil, -- Initialize as nil
        lastPositionUpdate = 0
    }
}

-- Initialize the detector (called once)
function Detector.Initialize()
    -- Update interval from global config if available
    if Config and Config.Detectors and Config.Detectors.teleporting and NexusGuard and NexusGuard.intervals and NexusGuard.intervals.teleport then
        Detector.interval = NexusGuard.intervals.teleport
    end
    -- Initialize position state
    Detector.state.position = GetEntityCoords(PlayerPedId())
    Detector.state.lastPositionUpdate = GetGameTimer()
    print("^2[NexusGuard:" .. DetectorName .. "]^7 Initialized with interval: " .. Detector.interval .. "ms")
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
                -- Use SafeDetect wrapper if available in NexusGuard global
                if _G.NexusGuard and _G.NexusGuard.SafeDetect then
                     _G.NexusGuard:SafeDetect(Detector.Check, DetectorName)
                else
                    -- Fallback to direct call if SafeDetect is not ready/available
                    local success, err = pcall(Detector.Check)
                    if not success then
                        print("^1[NexusGuard:" .. DetectorName .. "]^7 Error: " .. tostring(err))
                    end
                end
                Detector.lastCheck = currentTime
            end

            -- Adjust wait time dynamically based on interval
            local waitTime = math.max(100, Detector.interval / 10)
             Citizen.Wait(waitTime)
        end
    end)

    print("^2[NexusGuard:" .. DetectorName .. "]^7 Detector started")
    return true
end

-- Stop the detector
function Detector.Stop()
    Detector.active = false
    print("^2[NexusGuard:" .. DetectorName .. "]^7 Detector stopped")
    return true
end

-- Check for violations (Moved logic from client_main.lua)
function Detector.Check()
    local ped = PlayerPedId()

    -- Safety checks
    if not DoesEntityExist(ped) then return end

    local currentPos = GetEntityCoords(ped)
    local lastPos = Detector.state.position
    local currentTime = GetGameTimer()
    -- Use threshold from global config if available
    local teleportThreshold = (Config and Config.Thresholds and Config.Thresholds.teleportDistance) or 100.0
    local timeDiffThreshold = 1000 -- ms, time window to check for large distance change

    -- Only check if we have a valid previous position
    if lastPos and #(lastPos) > 0 then -- Check if lastPos is a valid vector
        local distance = #(currentPos - lastPos)
        local timeDiff = currentTime - Detector.state.lastPositionUpdate

        -- Check if player moved significantly in a short time without being in a vehicle
        -- Added check for timeDiff > 0 to avoid division by zero or issues on first check
        if timeDiff > 0 and timeDiff < timeDiffThreshold and distance > teleportThreshold then
            -- Check if player is in a vehicle (teleporting on foot is more suspicious)
            if GetVehiclePedIsIn(ped, false) == 0 then
                -- Ignore legitimate teleports (game loading screens, player switching, screen fades)
                if not IsPlayerSwitchInProgress() and not IsScreenFadedOut() and not IsScreenFadingOut() and not IsScreenFadingIn() then
                    if _G.NexusGuard and _G.NexusGuard.ReportCheat then
                        _G.NexusGuard:ReportCheat(DetectorName, "Possible teleport detected: " .. math.floor(distance) .. " meters in " .. timeDiff .. "ms")
                    else
                        print("^1[NexusGuard:" .. DetectorName .. "]^7 Violation: Possible teleport detected: " .. math.floor(distance) .. " meters in " .. timeDiff .. "ms (NexusGuard global unavailable)")
                    end
                end
            end
        end
    end

    -- Update player state regardless of detection
    Detector.state.position = currentPos
    Detector.state.lastPositionUpdate = currentTime
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
