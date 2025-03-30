--[[
    Enhanced Vehicle Detection System
    Monitors for vehicle modifications and performance hacks
]]

-- Vehicle data cache to track modifications
local VehicleCache = {}

-- Known top speeds for reference (km/h)
local VehicleTopSpeeds = {
    -- Sports cars
    ["adder"] = 220,
    ["zentorno"] = 230,
    ["t20"] = 220,
    ["nero"] = 225,
    ["nero2"] = 235,
    ["vagner"] = 240,
    ["deveste"] = 245,
    ["krieger"] = 240,
    ["emerus"] = 235,
    ["furia"] = 230,
    ["vigilante"] = 240,
    
    -- Motorcycles
    ["bati"] = 210,
    ["bati2"] = 210,
    ["hakuchou"] = 215,
    ["hakuchou2"] = 225,
    ["shotaro"] = 215,
    
    -- Default for unknown vehicles
    ["default"] = 200
}

-- Monitor vehicle modifications
function MonitorVehicleModifications()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end
    
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    
    local vehicleModel = GetEntityModel(vehicle)
    local vehicleClass = GetVehicleClass(vehicle)
    
    -- Get current vehicle properties
    local speed = GetEntitySpeed(vehicle) * 3.6 -- Convert to km/h
    local health = GetVehicleEngineHealth(vehicle)
    local handling = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveForce')
    local maxSpeed = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveMaxFlatVel')
    
    -- Check for vehicle hash in cache, create entry if it doesn't exist
    if not VehicleCache[vehicleModel] then
        VehicleCache[vehicleModel] = {
            baseSpeed = maxSpeed,
            baseHealth = health,
            baseHandling = handling,
            topSpeed = 0,
            samples = 1,
            lastCheck = GetGameTimer()
        }
        return
    end
    
    -- Update tracked top speed if we're going faster
    if speed > VehicleCache[vehicleModel].topSpeed then
        VehicleCache[vehicleModel].topSpeed = speed
    end
    
    -- Only analyze after we have enough samples
    if VehicleCache[vehicleModel].samples < 5 then
        VehicleCache[vehicleModel].samples = VehicleCache[vehicleModel].samples + 1
        return
    end
    
    -- Get threshold from config
    local speedThreshold = (Config.Thresholds and Config.Thresholds.vehicleSpeedMultiplier) or 1.5
    local maxAllowedSpeed = 0
    
    -- Get expected top speed
    local modelName = GetDisplayNameFromVehicleModel(vehicleModel):lower()
    local expectedTopSpeed = VehicleTopSpeeds[modelName] or VehicleTopSpeeds.default
    
    -- Calculate max allowed speed based on vehicle class
    if vehicleClass == 16 then -- Planes
        maxAllowedSpeed = 500 -- Planes can go very fast
    elseif vehicleClass == 14 then -- Boats
        maxAllowedSpeed = 120 -- Boats are relatively slow
    elseif vehicleClass == 15 or vehicleClass == 16 then -- Helicopters
        maxAllowedSpeed = 300 -- Helicopters are fast but not as fast as planes
    else
        maxAllowedSpeed = expectedTopSpeed * speedThreshold
    end
    
    -- Check for speed modifications
    if speed > maxAllowedSpeed then
        -- Report speed modification
        local detectionDetails = {
            speed = math.floor(speed),
            maxAllowed = math.floor(maxAllowedSpeed),
            vehicleName = GetLabelText(GetDisplayNameFromVehicleModel(vehicleModel)),
            vehicleClass = vehicleClass
        }
        
        -- Use core NexusGuard API to report the cheat
        if NexusGuard and NexusGuard.ReportCheat then
            NexusGuard:ReportCheat("vehiclespeed", 
                "Vehicle speed hack detected: " .. detectionDetails.vehicleName .. 
                " - " .. detectionDetails.speed .. " km/h (Max: " .. detectionDetails.maxAllowed .. " km/h)")
        end
    end
    
    -- Check for engine health modifications
    if health > 1000 and not IsVehicleDamaged(vehicle) then
        -- Report engine health modification
        if NexusGuard and NexusGuard.ReportCheat then
            NexusGuard:ReportCheat("vehiclemod", 
                "Vehicle health modification detected: Engine health " .. 
                math.floor(health) .. "/1000")
        end
    end
end

-- Create thread to run monitor periodically
Citizen.CreateThread(function()
    while true do
        -- Check if the feature is enabled
        if Config and Config.Detectors and Config.Detectors.vehicleModification then
            MonitorVehicleModifications()
        end
        
        Citizen.Wait(3000) -- Check every 3 seconds
    end
end)
