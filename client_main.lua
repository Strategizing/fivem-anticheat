-- client_main.lua
-- NexusGuard: Client-side anti-cheat system for FiveM
-- Provides protection against common cheating methods including god mode, 
-- weapon modification, speed hacks, teleporting, noclip, and mod menus

-- Environment compatibility layer for testing outside FiveM
if not RegisterNetEvent then
    function RegisterNetEvent(eventName) end
end

if not Citizen then
    Citizen = {
        CreateThread = function(callback) callback() end,
        Wait = function(ms) end
    }
end

if not vector3 then
    vector3 = function(x, y, z)
        return {x = x or 0, y = y or 0, z = z or 0}
    end
end

if not GetGameTimer then
    GetGameTimer = function()
        if type(GetTickCount64) == "function" then
            return GetTickCount64()
        elseif type(_G["GetTickCount"]) == "function" then
            return _G["GetTickCount"]()
        else
            return os.clock() * 1000 -- Fallback to Lua's os.clock (seconds) converted to ms
        end
    end
end

RegisterNetEvent('onClientResourceStart')

-- Main NexusGuard object with all configuration and state
local NexusGuard = {
    securityToken = nil,
    moduleStatus = {},
    scanIntervals = {
        godMode = 5000,
        weaponModification = 3000,
        speedHack = 2000,
        teleport = 1000,
        noclip = 1000,
        menuDetection = 10000,
        resourceMonitor = 15000
    },
    playerState = {
        position = vector3(0, 0, 0),
        health = 100,
        armor = 0,
        lastTeleport = GetGameTimer(),
        movementSamples = {},
        weaponStats = {}
    },
    flags = {
        suspiciousActivity = false,
        warningIssued = false
    },
    discordRichPresence = {
        appId = nil, -- Will be populated from Config
        updateInterval = 60000, -- Update Discord status every 60 seconds
        serverName = "Protected Server",
        lastUpdate = 0
    },
    lastResourceCheck = 0,
    initialized = false
}

-- Initialize client-side anti-cheat
Citizen.CreateThread(function()
    Citizen.Wait(1000) -- Wait for the resource's scripts to load
    
    -- Wait for network session to be active
    while not NetworkIsSessionActive() do
        Citizen.Wait(100)
    end
    
    print('[NexusGuard] Initializing client-side protection...')
    
    -- Generate client hash for verification
    local clientHash = GetCurrentResourceName() .. "-" .. math.random(100000, 999999)
    
    -- Request security token from server
    TriggerServerEvent('NexusGuard:RequestSecurityToken', clientHash)
    
    Citizen.Wait(2000) -- Allow time for token receipt
    
    -- Start all protection modules
    StartProtectionModules()
    
    NexusGuard.initialized = true
end)

-- Start all protection modules with optimized scheduling
function StartProtectionModules()
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(1000) -- Base check interval
            
            if not Config or not Config.Detectors or not NexusGuard.initialized then
                Citizen.Wait(1000)
                goto continue
            end
            
            local currentTime = GetGameTimer()
            
            -- Run each detector based on its configured interval
            if Config.Detectors.godMode then DetectGodMode() end
            if Config.Detectors.weaponModification then DetectWeaponModification() end
            if Config.Detectors.speedHack then DetectSpeedHack() end
            if Config.Detectors.teleporting then DetectTeleport() end
            if Config.Detectors.noclip then DetectNoClip() end
            if Config.Detectors.menuDetection then DetectModMenus() end
            
            -- Resource monitoring runs less frequently
            if Config.Detectors.resourceInjection and 
               (currentTime - NexusGuard.lastResourceCheck > NexusGuard.scanIntervals.resourceMonitor) then
                MonitorResources()
                NexusGuard.lastResourceCheck = currentTime
            end
            
            ::continue::
        end
    end)
    
    InitializeRichPresence()
end

-- God mode detection: Checks for invincibility and abnormal health values
function DetectGodMode()
    local player = PlayerId()
    local ped = PlayerPedId()
    local health = GetEntityHealth(ped)
    local maxHealth = GetPedMaxHealth(ped)
    
    -- Check for invincibility flag
    if GetPlayerInvincible(player) then
        ReportCheat("godmode", "Player has invincibility enabled")
        return
    end
    
    -- Check for abnormal health values
    if health > maxHealth then
        ReportCheat("godmode", "Player has abnormal health: " .. health .. "/" .. maxHealth)
    end
    
    NexusGuard.playerState.health = health
end

-- Weapon modification detection: Checks for modified weapon damage and clip size
function DetectWeaponModification()
    local ped = PlayerPedId()
    local weaponHash = GetSelectedPedWeapon(ped)
    
    -- Only check if player has a weapon equipped
    if weaponHash ~= GetHashKey("WEAPON_UNARMED") then
        local damage = GetWeaponDamage(weaponHash, 0)
        local clipSize = GetWeaponClipSize(weaponHash)
        
        -- Initialize weapon stats if not yet recorded
        if not NexusGuard.playerState.weaponStats[weaponHash] then
            NexusGuard.playerState.weaponStats[weaponHash] = {
                damage = damage,
                clipSize = clipSize
            }
            return
        end
        
        -- Compare with previously stored values
        local storedStats = NexusGuard.playerState.weaponStats[weaponHash]
        
        if damage > storedStats.damage * 1.5 then
            ReportCheat("weaponmod", "Weapon damage modified: " .. damage .. 
                        " (Expected: " .. storedStats.damage .. ")")
        end
        
        if clipSize > storedStats.clipSize * 2 then
            ReportCheat("weaponmod", "Weapon clip size modified: " .. clipSize .. 
                        " (Expected: " .. storedStats.clipSize .. ")")
        end
    end
end

-- Speed hack detection: Checks for abnormal vehicle or player movement speeds
function DetectSpeedHack()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    
    if vehicle ~= 0 then
        -- Vehicle speed check
        local speed = GetEntitySpeed(vehicle)
        local model = GetEntityModel(vehicle)
        local maxSpeed = GetVehicleModelMaxSpeed(model)
        
        if speed > maxSpeed * 1.5 then
            local kmhSpeed = math.floor(speed * 3.6)
            local kmhMaxSpeed = math.floor(maxSpeed * 3.6)
            ReportCheat("speedhack", "Vehicle speed abnormal: " .. kmhSpeed .. 
                        " km/h (Max: " .. kmhMaxSpeed .. " km/h)")
        end
    else
        -- On-foot speed check
        local speed = GetEntitySpeed(ped)
        if speed > 10.0 and not IsPedInParachuteFreeFall(ped) then
            ReportCheat("speedhack", "Player movement speed abnormal: " .. 
                        math.floor(speed * 3.6) .. " km/h")
        end
    end
end

-- Teleport detection: Checks for sudden position changes that aren't possible normally
function DetectTeleport()
    local ped = PlayerPedId()
    local currentPos = GetEntityCoords(ped)
    local lastPos = NexusGuard.playerState.position
    local currentTime = GetGameTimer()
    
    -- Only check if we have a valid previous position
    if lastPos.x ~= 0 or lastPos.y ~= 0 or lastPos.z ~= 0 then
        local distance = #(currentPos - lastPos)
        local timeDiff = currentTime - NexusGuard.playerState.lastTeleport
        
        -- If player moved more than 100 meters in less than 1 second without being in a vehicle
        if distance > 100.0 and timeDiff < 1000 and GetVehiclePedIsIn(ped, false) == 0 then
            -- Ignore legitimate teleports (game loading screens, etc)
            if not IsPlayerSwitchInProgress() and not IsScreenFadedOut() then
                ReportCheat("teleport", "Possible teleport detected: " .. 
                            math.floor(distance) .. " meters in " .. timeDiff .. "ms")
            end
        end
    end
    
    -- Update player state
    NexusGuard.playerState.position = currentPos
    NexusGuard.playerState.lastTeleport = currentTime
end

-- NoClip detection: Checks for floating without proper game state
function DetectNoClip()
    local ped = PlayerPedId()
    
    -- Only check if player is not in a vehicle and not dead
    if GetVehiclePedIsIn(ped, false) == 0 and not IsEntityDead(ped) then
        local pos = GetEntityCoords(ped)
        local ground, groundZ = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z, false)
        
        -- Check if player is floating and not in a legitimate falling state
        if not ground and not IsPedInParachuteFreeFall(ped) and 
           not IsPedFalling(ped) and not IsPedJumpingOutOfVehicle(ped) then
            
            local _, _, zSpeed = GetEntityVelocity(ped)
            zSpeed = zSpeed or 0  -- Default to 0 if zSpeed is nil
            
            -- If player is floating and not moving vertically (not falling)
            if math.abs(zSpeed) < 0.1 then
                local collisionDisabled = GetEntityCollisionDisabled(ped)
                if collisionDisabled then
                    ReportCheat("noclip", "NoClip detected: Collision disabled and floating")
                end
            end
        end
    end
end

-- Mod menu detection: Checks for common mod menu indicators
function DetectModMenus()
    -- Check for common mod menu key combinations
    if IsControlJustPressed(0, 178) and IsControlJustPressed(0, 51) then
        -- HOME key + E key common mod menu combo
        ReportCheat("modmenu", "Potential mod menu key combination detected")
    end
    
    -- Note: Real mod menu detection would need more sophisticated methods
    -- This is a simplified placeholder implementation
end

-- Resource monitoring: Checks for injected/unauthorized resources
function MonitorResources()
    -- Get all currently running resources
    local resources = {}
    local resourceCount = GetNumResources()
    
    for i = 0, resourceCount - 1 do
        local resourceName = GetResourceByFindIndex(i)
        table.insert(resources, resourceName)
    end
    
    -- Send to server for verification against whitelist
    TriggerServerEvent("NexusGuard:VerifyResources", resources)
end

-- Discord Rich Presence initialization (placeholder)
function InitializeRichPresence()
    -- Placeholder - would be implemented based on Discord API
end

-- Report detected cheats to the server
function ReportCheat(type, details)
    if not NexusGuard.initialized or not NexusGuard.securityToken then 
        return
    end
    
    if not NexusGuard.flags.warningIssued then
        -- First detection issues a warning
        NexusGuard.flags.suspiciousActivity = true
        NexusGuard.flags.warningIssued = true
        
        TriggerEvent("NexusGuard:CheatWarning", type, details)
    else
        -- Subsequent detections report to server
        TriggerServerEvent("NexusGuard:ReportCheat", type, details, NexusGuard.securityToken)
    end
end

-- Event handlers
RegisterNetEvent("NexusGuard:ReceiveSecurityToken")
AddEventHandler("NexusGuard:ReceiveSecurityToken", function(token)
    NexusGuard.securityToken = token
    print("[NexusGuard] Security handshake completed")
end)

RegisterNetEvent("nexusguard:initializeClient")
AddEventHandler("nexusguard:initializeClient", function(token)
    NexusGuard.securityToken = token
    print("[NexusGuard] Client initialized via alternate event")
end)

RegisterNetEvent("NexusGuard:CheatWarning")
AddEventHandler("NexusGuard:CheatWarning", function(type, details)
    TriggerEvent('chat:addMessage', {
        color = { 255, 0, 0 },
        multiline = true,
        args = { 
            "[NexusGuard]", 
            "Suspicious activity detected! Type: " .. type .. 
            ". Further violations will result in automatic ban." 
        }
    })
end)

RegisterNetEvent("nexusguard:requestScreenshot")
AddEventHandler("nexusguard:requestScreenshot", function()
    if not NexusGuard.initialized or not exports['screenshot-basic'] then 
        return 
    end
    
    exports['screenshot-basic']:requestScreenshotUpload(
        Config.ScreenCapture.webhookURL, 
        'files[]', 
        function(data)
            local resp = json.decode(data)
            if resp and resp.attachments and resp.attachments[1] then
                TriggerServerEvent('nexusguard:screenshotTaken', 
                                   resp.attachments[1].url, 
                                   NexusGuard.securityToken)
            end
        end
    )
end)