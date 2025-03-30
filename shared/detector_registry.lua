DetectorRegistry = {
    detectors = {},
    initialized = false,
    activeThreads = {} -- Keep track of active threads
}

-- Helper function to create the standard detector loop thread
local function CreateDetectorThread(detectorInfo)
    local detectorName = detectorInfo.name
    local detector = detectorInfo.detector
    local interval = detector.interval -- Use the detector's specific interval

    -- Cancel existing thread if any
    if DetectorRegistry.activeThreads[detectorName] then
        -- Lua doesn't have a direct thread cancellation. We rely on the 'active' flag.
        -- For robustness, ensure the old thread reference is cleared.
        DetectorRegistry.activeThreads[detectorName] = nil
    end

    local threadId = Citizen.CreateThread(function()
        print("^2[NexusGuard:" .. detectorName .. "]^7 Thread started.")
        while detector.active do -- Check the detector's own active flag
            local currentTime = GetGameTimer()

            -- Only run if enough time has passed
            if currentTime - detector.lastCheck >= interval then
                -- Use SafeDetect wrapper if available in NexusGuard global
                if _G.NexusGuard and _G.NexusGuard.SafeDetect then
                     _G.NexusGuard:SafeDetect(detector.Check, detectorName)
                else
                    -- Fallback to direct call if SafeDetect is not ready/available
                    local success, err = pcall(detector.Check)
                    if not success then
                        print("^1[NexusGuard:" .. detectorName .. "]^7 Error: " .. tostring(err))
                    end
                end
                detector.lastCheck = currentTime
            end

            -- Adjust wait time dynamically based on interval to reduce unnecessary checks
            -- Ensure wait time is reasonable, e.g., at least 50ms
            local waitTime = math.max(50, math.min(interval, 1000)) -- Wait between 50ms and 1s, but no more than interval
            Citizen.Wait(waitTime)
        end
        print("^2[NexusGuard:" .. detectorName .. "]^7 Thread stopped.")
        DetectorRegistry.activeThreads[detectorName] = nil -- Clean up thread reference
    end)
    DetectorRegistry.activeThreads[detectorName] = threadId -- Store thread reference (though direct cancellation isn't possible)
end

-- Register a new detector
function DetectorRegistry.Register(name, detector)
    if not DetectorRegistry.detectors[name] then
        DetectorRegistry.detectors[name] = {
            name = name,
            active = false,
            detector = detector,
            initialize = detector.Initialize or function() return true end,
            start = detector.Start or function() return true end,
            stop = detector.Stop or function() return true end,
            getStatus = detector.GetStatus or function() return { active = false } end
        }
        return true
    end
    return false
end

-- Start a detector by name (Updated to use helper)
function DetectorRegistry.Start(name)
    local detectorInfo = DetectorRegistry.detectors[name]
    if detectorInfo and not detectorInfo.detector.active then -- Check detector's internal active flag
        -- Call the detector's specific Start function first (if it exists and does more than just set active=true)
        local startSuccess = true
        if detectorInfo.start then
            startSuccess = detectorInfo.start() -- This should ideally just set detector.active = true now
        else
            detectorInfo.detector.active = true -- Fallback if no Start function
        end

        if startSuccess then
            -- detectorInfo.active = true -- Registry's flag (might be redundant if detector.active is primary)
            CreateDetectorThread(detectorInfo) -- Create the loop thread
            print("^2[NexusGuard:" .. name .. "]^7 Detector started via Registry.")
            return true
        else
            print("^1[NexusGuard:" .. name .. "]^7 Detector failed to start.")
        end
    elseif detectorInfo and detectorInfo.detector.active then
        print("^3[NexusGuard:" .. name .. "]^7 Detector already active.")
    elseif not detectorInfo then
        print("^1[NexusGuard]^7 Attempted to start unknown detector: " .. name)
    end
    return false
end

-- Stop a detector by name (Updated to rely on detector's Stop)
function DetectorRegistry.Stop(name)
    local detectorInfo = DetectorRegistry.detectors[name]
    if detectorInfo and detectorInfo.detector.active then
         -- Call the detector's specific Stop function (which should set detector.active = false)
        if detectorInfo.stop() then
            -- detectorInfo.active = false -- Registry's flag (might be redundant)
            -- The thread will stop itself based on detector.active flag
            print("^2[NexusGuard:" .. name .. "]^7 Detector stopped via Registry.")
            return true
        else
             print("^1[NexusGuard:" .. name .. "]^7 Detector failed to stop.")
        end
    elseif detectorInfo and not detectorInfo.detector.active then
         print("^3[NexusGuard:" .. name .. "]^7 Detector already stopped.")
    elseif not detectorInfo then
        print("^1[NexusGuard]^7 Attempted to stop unknown detector: " .. name)
    end
    return false
end

-- Get status of all detectors
function DetectorRegistry.GetStatus()
    local status = {}
    for name, detectorInfo in pairs(DetectorRegistry.detectors) do
        -- Get status from the detector itself
        local detStatus = detectorInfo.getStatus()
        -- Ensure 'active' status reflects the detector's internal state
        detStatus.active = detectorInfo.detector.active
        status[name] = detStatus
    end
    return status
end

-- Function to stop all detectors (e.g., on resource stop)
function DetectorRegistry.StopAll()
    print("^2[NexusGuard]^7 Stopping all detectors...")
    for name, detectorInfo in pairs(DetectorRegistry.detectors) do
        if detectorInfo.detector.active then
            DetectorRegistry.Stop(name)
        end
    end
    print("^2[NexusGuard]^7 All detectors stopped.")
end

-- Add handler for resource stopping
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        DetectorRegistry.StopAll()
    end
end)
