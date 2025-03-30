local DetectorName = "godMode"
local Detector = {
    active = false,
    interval = 5000, -- Default, will be overridden by config if available
    lastCheck = 0,
    state = { -- Local state for this detector if needed
        health = 100
    }
}

-- Initialize the detector (called once)
function Detector.Initialize()
    -- Update interval from global config if available
    if Config and Config.Detectors and Config.Detectors.godMode and NexusGuard and NexusGuard.intervals and NexusGuard.intervals.godMode then
        Detector.interval = NexusGuard.intervals.godMode
    end
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

            -- Adjust wait time dynamically based on interval to reduce unnecessary checks
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
    local player = PlayerId()

    -- Safety checks
    if not DoesEntityExist(ped) then return end

    local health = GetEntityHealth(ped)
    local maxHealth = GetPedMaxHealth(ped) -- Use GetPedMaxHealth for accuracy
    local armor = GetPedArmour(ped)

    -- Check for invincibility flag
    if GetPlayerInvincible(player) then
        -- Ensure NexusGuard global is available before reporting
        if _G.NexusGuard and _G.NexusGuard.ReportCheat then
            _G.NexusGuard:ReportCheat(DetectorName, "Player has invincibility flag enabled")
        else
            print("^1[NexusGuard:" .. DetectorName .. "]^7 Violation: Player has invincibility flag enabled (NexusGuard global unavailable)")
        end
        return
    end

    -- Check for abnormal health values (consider max health can be > 100)
    if health > maxHealth and health > 200 then -- Keep the > 200 check as a sanity threshold
         if _G.NexusGuard and _G.NexusGuard.ReportCheat then
            _G.NexusGuard:ReportCheat(DetectorName, "Abnormal health detected: " .. health .. "/" .. maxHealth)
        else
            print("^1[NexusGuard:" .. DetectorName .. "]^7 Violation: Abnormal health detected: " .. health .. "/" .. maxHealth .. " (NexusGuard global unavailable)")
        end
        return
    end

    -- Track health regeneration (if enabled in config)
    -- Use local state for health tracking
    if Detector.state.health < health and health <= maxHealth then -- Only track regeneration up to max health
        local healthIncrease = health - Detector.state.health
        -- Use threshold from global config if available
        local threshold = (Config and Config.Thresholds and Config.Thresholds.healthRegenerationRate) or 2.0

        -- If health increased too rapidly without medical item use (basic check)
        if healthIncrease > threshold then
             if _G.NexusGuard and _G.NexusGuard.ReportCheat then
                _G.NexusGuard:ReportCheat(DetectorName, "Abnormal health regeneration: +" .. string.format("%.1f", healthIncrease) .. " HP")
            else
                print("^1[NexusGuard:" .. DetectorName .. "]^7 Violation: Abnormal health regeneration: +" .. string.format("%.1f", healthIncrease) .. " HP (NexusGuard global unavailable)")
            end
        end
    end

    -- Check for armor anomalies (if armor is abnormally high)
    if armor > 100 then -- Standard max armor is 100
         if _G.NexusGuard and _G.NexusGuard.ReportCheat then
            _G.NexusGuard:ReportCheat(DetectorName, "Abnormal armor value: " .. armor)
        else
            print("^1[NexusGuard:" .. DetectorName .. "]^7 Violation: Abnormal armor value: " .. armor .. " (NexusGuard global unavailable)")
        end
    end

    -- Update local state
    Detector.state.health = health
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
