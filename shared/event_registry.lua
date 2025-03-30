-- EventRegistry Module
-- Standardizes event naming and handling for NexusGuard

EventRegistry = {
    -- Base prefix for all events to avoid conflicts with other resources
    prefix = "nexusguard",
    
    -- All registered events
    events = {
        -- Security events
        SECURITY_REQUEST_TOKEN = "security:requestToken",
        SECURITY_RECEIVE_TOKEN = "security:receiveToken",
        
        -- Detection events
        DETECTION_REPORT = "detection:report",
        DETECTION_VERIFY = "detection:verify",
        
        -- Admin events
        ADMIN_NOTIFICATION = "admin:notification",
        ADMIN_REQUEST_SCREENSHOT = "admin:requestScreenshot",
        ADMIN_SCREENSHOT_TAKEN = "admin:screenshotTaken",
        
        -- System events
        SYSTEM_ERROR = "system:error",
        SYSTEM_RESOURCE_CHECK = "system:resourceCheck"
    }
}

-- Get the full prefixed event name
function EventRegistry.GetEventName(event)
    if not EventRegistry.events[event] then
        print("^1[NexusGuard] Warning: Requested unknown event '" .. tostring(event) .. "'!^7")
        return nil
    end
    
    return EventRegistry.prefix .. ":" .. EventRegistry.events[event]
end

-- Register a new event handler with standardized name
function EventRegistry.RegisterEvent(event)
    local eventName = EventRegistry.GetEventName(event)
    if eventName then
        RegisterNetEvent(eventName)
        return eventName
    end
    return nil
end

-- Add handler to an event with standardized name
function EventRegistry.AddEventHandler(event, handler)
    local eventName = EventRegistry.GetEventName(event)
    if eventName then
        AddEventHandler(eventName, handler)
        return true
    end
    return false
end

-- Trigger a server event with standardized name
function EventRegistry.TriggerServerEvent(event, ...)
    local eventName = EventRegistry.GetEventName(event)
    if eventName then
        TriggerServerEvent(eventName, ...)
        return true
    end
    return false
end

-- Trigger a client event with standardized name
function EventRegistry.TriggerClientEvent(event, target, ...)
    local eventName = EventRegistry.GetEventName(event)
    if eventName then
        TriggerClientEvent(eventName, target, ...)
        return true
    end
    return false
end

-- Update event documentation for future reference
function EventRegistry.GetEventDocumentation()
    local docs = {}
    for name, path in pairs(EventRegistry.events) do
        docs[name] = {
            name = name,
            fullPath = EventRegistry.prefix .. ":" .. path,
            usage = "Use EventRegistry methods to access this event"
        }
    end
    return docs
end
