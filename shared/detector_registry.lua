DetectorRegistry = {
    detectors = {},
    initialized = false
}

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

-- Start a detector by name
function DetectorRegistry.Start(name)
    local detector = DetectorRegistry.detectors[name]
    if detector and not detector.active then
        if detector.start() then
            detector.active = true
            return true
        end
    end
    return false
end

-- Stop a detector by name
function DetectorRegistry.Stop(name)
    local detector = DetectorRegistry.detectors[name]
    if detector and detector.active then
        if detector.stop() then
            detector.active = false
            return true
        end
    end
    return false
end

-- Get status of all detectors
function DetectorRegistry.GetStatus()
    local status = {}
    for name, detector in pairs(DetectorRegistry.detectors) do
        status[name] = detector.getStatus()
        status[name].active = detector.active
    end
    return status
end
