local DetectorName = "menuDetection" -- Match the key in Config.Detectors
local Detector = {
    active = false,
    interval = 10000, -- Default, will be overridden by config if available
    lastCheck = 0
}

-- Initialize the detector (called once)
function Detector.Initialize()
    -- Update interval from global config if available
    if Config and Config.Detectors and Config.Detectors.menuDetection and NexusGuard and NexusGuard.intervals and NexusGuard.intervals.menuDetection then
        Detector.interval = NexusGuard.intervals.menuDetection
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
    -- Basic check for common mod menu key combinations
    -- Note: This is very basic and easily bypassed. More advanced checks are needed.
    -- Example: HOME key (178) + E key (51)
    if IsControlJustPressed(0, 178) and IsControlPressed(0, 51) then -- Check if E is held while HOME is pressed
        if _G.NexusGuard and _G.NexusGuard.ReportCheat then
            _G.NexusGuard:ReportCheat(DetectorName, "Potential mod menu key combination detected (HOME + E)")
        else
            print("^1[NexusGuard:" .. DetectorName .. "]^7 Violation: Potential mod menu key combination detected (HOME + E) (NexusGuard global unavailable)")
        end
        return -- Report once per combination press
    end

    -- Example: F5 key (commonly used)
    if IsControlJustPressed(0, 166) then -- INPUT_REPLAY_START_STOP_RECORDING (F5)
         if _G.NexusGuard and _G.NexusGuard.ReportCheat then
            _G.NexusGuard:ReportCheat(DetectorName, "Potential mod menu key combination detected (F5)")
        else
            print("^1[NexusGuard:" .. DetectorName .. "]^7 Violation: Potential mod menu key combination detected (F5) (NexusGuard global unavailable)")
        end
        return
    end

    -- TODO: Add more sophisticated checks:
    -- 1. Monitor for blacklisted natives frequently used by menus (e.g., drawing natives, certain SET_* natives).
    -- 2. Check for suspicious global variable modifications.
    -- 3. Look for unexpected UI elements or scaleforms.
    -- 4. Analyze registered commands/keybinds for suspicious patterns.
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
