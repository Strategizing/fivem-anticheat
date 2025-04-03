local DetectorName = "menuDetection" -- Match the key in Config.Detectors
local NexusGuard = nil -- Local variable to hold the NexusGuard instance

local Detector = {
    active = false,
    interval = 10000, -- Default, will be overridden by config if available
    lastCheck = 0
}

-- Initialize the detector (called once by the registry)
-- Receives the NexusGuard instance from the registry
function Detector.Initialize(nexusGuardInstance)
    if not nexusGuardInstance then
        print("^1[NexusGuard:" .. DetectorName .. "] CRITICAL: Failed to receive NexusGuard instance during initialization.^7")
        return false
    end
    NexusGuard = nexusGuardInstance -- Store the instance locally

    -- Update interval from global config if available
    -- Access Config via the passed instance
    local cfg = NexusGuard.Config
    if cfg and cfg.Detectors and cfg.Detectors.menuDetection and NexusGuard.intervals and NexusGuard.intervals.menuDetection then
        Detector.interval = NexusGuard.intervals.menuDetection
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
    -- Basic check for common mod menu key combinations
    -- Note: This is very basic and easily bypassed. More advanced checks are needed.
    -- Example: HOME key (178) + E key (51) - Note: Control IDs might vary, use names for clarity if possible
    -- Using 213 for INPUT_FRONTEND_SOCIAL_CLUB (HOME) and 38 for INPUT_PICKUP (E)
    if IsControlJustPressed(0, 213) and IsControlPressed(0, 38) then -- Check if E is held while HOME is pressed
        if NexusGuard and NexusGuard.ReportCheat then
            local details = { keyCombo = "HOME + E", control1 = 213, control2 = 38 }
            NexusGuard:ReportCheat(DetectorName, details)
        else
            print("^1[NexusGuard:" .. DetectorName .. "]^7 Violation: Potential mod menu key combination detected (HOME + E) (NexusGuard instance unavailable)")
        end
        return -- Report once per combination press
    end

    -- Example: F5 key (commonly used) - INPUT_FRONTEND_PAUSE_ALTERNATE (244)
    if IsControlJustPressed(0, 244) then
         if NexusGuard and NexusGuard.ReportCheat then
            local details = { keyCombo = "F5", control1 = 244 }
            NexusGuard:ReportCheat(DetectorName, details)
        else
            print("^1[NexusGuard:" .. DetectorName .. "]^7 Violation: Potential mod menu key combination detected (F5) (NexusGuard instance unavailable)")
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
-- NOTE: The registry now handles calling Initialize and Start based on config.
Citizen.CreateThread(function()
    -- Wait for DetectorRegistry to be available
    while not _G.DetectorRegistry do
        Citizen.Wait(500)
    end
    _G.DetectorRegistry.Register(DetectorName, Detector)
    -- Initialization and starting is now handled by the registry calling the methods on the registered module
end)
