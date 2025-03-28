-- Define vector3 function if it doesn't exist
if not vector3 then
    vector3 = function(x, y, z)
        return {x = x or 0, y = y or 0, z = z or 0}
    end
end

-- Define GetGameTimer if it doesn't exist
if not GetGameTimer then
    GetGameTimer = function()
        -- Try different ways to get tick count
        if type(GetTickCount64) == "function" then
            return GetTickCount64()
        elseif type(GetTickCount) == "function" then
            return GetTickCount()
        else
            return os.clock() * 1000 -- Fallback to Lua's os.clock (in seconds) converted to ms
        end
    end
end

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
        appId = "1234567890123456", -- Replace with your Discord application ID
        updateInterval = 60000,     -- Update Discord status every 60 seconds
        serverName = "Your Server Name",
        lastUpdate = 0
    }
}

-- Initialize client-side anti-cheat
Citizen.CreateThread(function()
    while not NetworkIsSessionActive() do
        Citizen.Wait(100)
    end
    
    print('[NexusGuard] Initializing client-side protection...')
    
    -- Get hash of client files for verification
    local clientHash = GetCurrentResourceName() .. "-" .. math.random(100000, 999999)
    
    -- Request security token from server
    TriggerServerEvent('NexusGuard:RequestSecurityToken', clientHash)
    
    -- Initialize Discord Rich Presence
    InitializeDiscordRichPresence()
    
    -- Start all protection modules
    StartProtectionModules()
end)

-- Initialize Discord Rich Presence
function InitializeDiscordRichPresence()
    SetDiscordAppId(NexusGuard.discordRichPresence.appId)
    SetDiscordRichPresenceAsset('logo')
    SetDiscordRichPresenceAssetText(NexusGuard.discordRichPresence.serverName)
    
    -- Update Discord status periodically
    Citizen.CreateThread(function()
        while true do
            local player = PlayerId()
            local playerName = GetPlayerName(player)
            local serverId = GetPlayerServerId(player)
            
            -- Set the rich presence details
            SetRichPresence(playerName .. " [ID: " .. serverId .. "] - " .. NexusGuard.discordRichPresence.serverName)
            
            -- Set the party info
            SetDiscordRichPresenceAction(0, "Join Server", "fivem://connect/yourserver.com")
            SetDiscordRichPresenceAction(1, "Discord", "https://discord.gg/yourserver")
            
            NexusGuard.discordRichPresence.lastUpdate = GetGameTimer()
            Citizen.Wait(NexusGuard.discordRichPresence.updateInterval)
        end
    end)
end

-- Start all protection modules based on scan intervals
function StartProtectionModules()
    -- God Mode Detection
    Citizen.CreateThread(function()
        while true do
            DetectGodMode()
            Citizen.Wait(NexusGuard.scanIntervals.godMode)
        end
    end)
    
    -- Weapon Modification Detection
    Citizen.CreateThread(function()
        while true do
            DetectWeaponModification()
            Citizen.Wait(NexusGuard.scanIntervals.weaponModification)
        end
    end)
    
    -- Speed Hack Detection
    Citizen.CreateThread(function()
        while true do
            DetectSpeedHack()
            Citizen.Wait(NexusGuard.scanIntervals.speedHack)
        end
    end)
    
    -- Teleport Detection
    Citizen.CreateThread(function()
        while true do
            DetectTeleport()
            Citizen.Wait(NexusGuard.scanIntervals.teleport)
        end
    end)
    
    -- NoClip Detection
    Citizen.CreateThread(function()
        while true do
            DetectNoClip()
            Citizen.Wait(NexusGuard.scanIntervals.noclip)
        end
    end)
    
    -- Menu Detection
    Citizen.CreateThread(function()
        while true do
            DetectModMenus()
            Citizen.Wait(NexusGuard.scanIntervals.menuDetection)
        end
    end)
    
    -- Resource Monitor
    Citizen.CreateThread(function()
        while true do
            MonitorResources()
            Citizen.Wait(NexusGuard.scanIntervals.resourceMonitor)
        end
    end)
end

-- Detection functions
function DetectGodMode()
    local player = PlayerId()
    local ped = PlayerPedId()
    local health = GetEntityHealth(ped)
    local maxHealth = GetPedMaxHealth(ped)
    
    -- Check for invincibility
    if GetPlayerInvincible(player) then
        ReportCheat("godmode", "Player has invincibility enabled")
    end
    
    -- Check for abnormal health values
    if health > maxHealth then
        ReportCheat("godmode", "Player has abnormal health: " .. health .. "/" .. maxHealth)
    end
    
    NexusGuard.playerState.health = health
end

function DetectWeaponModification()
    local ped = PlayerPedId()
    local weaponHash = GetSelectedPedWeapon(ped)
    
    if weaponHash ~= GetHashKey("WEAPON_UNARMED") then
        local damage = GetWeaponDamage(weaponHash)
        local clipSize = GetWeaponClipSize(weaponHash)
        
        -- Store weapon stats if not yet recorded
        if not NexusGuard.playerState.weaponStats[weaponHash] then
            NexusGuard.playerState.weaponStats[weaponHash] = {
                damage = damage,
                clipSize = clipSize
            }
        else
            -- Compare with previously stored values
            if damage > NexusGuard.playerState.weaponStats[weaponHash].damage * 1.5 then
                ReportCheat("weaponmod", "Weapon damage modified: " .. damage .. " (Expected: " .. NexusGuard.playerState.weaponStats[weaponHash].damage .. ")")
            end
            
            if clipSize > NexusGuard.playerState.weaponStats[weaponHash].clipSize * 2 then
                ReportCheat("weaponmod", "Weapon clip size modified: " .. clipSize .. " (Expected: " .. NexusGuard.playerState.weaponStats[weaponHash].clipSize .. ")")
            end
        end
    end
end

function DetectSpeedHack()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    
    if vehicle ~= 0 then
        local speed = GetEntitySpeed(vehicle)
        local model = GetEntityModel(vehicle)
        local maxSpeed = GetVehicleModelMaxSpeed(model)
        
        if speed > maxSpeed * 1.5 then
            ReportCheat("speedhack", "Vehicle speed abnormal: " .. math.floor(speed*3.6) .. " km/h (Max: " .. math.floor(maxSpeed*3.6) .. " km/h)")
        end
    else
        local speed = GetEntitySpeed(ped)
        if speed > 10.0 and not IsPedInParachuteFreeFall(ped) then -- Normal max run speed is around 7.0
            ReportCheat("speedhack", "Player movement speed abnormal: " .. math.floor(speed*3.6) .. " km/h")
        end
    end
end

function DetectTeleport()
    local ped = PlayerPedId()
    local currentPos = GetEntityCoords(ped)
    local lastPos = NexusGuard.playerState.position
    local currentTime = GetGameTimer()
    
    if not vector3(0,0,0) == lastPos then
        local distance = #(currentPos - lastPos)
        local timeDiff = currentTime - NexusGuard.playerState.lastTeleport
        
        -- If player moved more than 100 meters in less than 1 second without being in a vehicle
        if distance > 100.0 and timeDiff < 1000 and GetVehiclePedIsIn(ped, false) == 0 then
            if not IsPlayerSwitchInProgress() and not IsScreenFadedOut() then
                ReportCheat("teleport", "Possible teleport detected: " .. math.floor(distance) .. " meters in " .. timeDiff .. "ms")
            end
        end
    end
    
    NexusGuard.playerState.position = currentPos
    NexusGuard.playerState.lastTeleport = currentTime
end

function DetectNoClip()
    local ped = PlayerPedId()
    
    -- Only check if player is not in a vehicle and not dead
    if GetVehiclePedIsIn(ped, false) == 0 and not IsEntityDead(ped) then
        local pos = GetEntityCoords(ped)
        local ground, groundZ = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z, 0)
        
        -- Check if player is floating and not falling
        if not ground and not IsPedInParachuteFreeFall(ped) and not IsPedFalling(ped) and not IsPedJumpingOutOfVehicle(ped) then
            local _, zSpeed = GetEntityVelocity(ped)
            
            -- If player is floating and not moving vertically (not falling)
            if math.abs(zSpeed) < 0.1 then
                local entFlags = GetEntityCollisionDisabled(ped)
                if entFlags then -- If collision is disabled
                    ReportCheat("noclip", "NoClip detected: Collision disabled and floating")
                end
            end
        end
    end
end

function DetectModMenus()
    -- Common mod menu natives
    local blacklistedNatives = {
        "GIVE_WEAPON_TO_PED",
        "SET_ENTITY_COORDS",
        "SET_PLAYER_INVINCIBLE",
        "SET_ENTITY_VISIBLE"
    }
    
    -- Check for common mod menu keys
    if IsControlJustPressed(0, 178) and IsControlJustPressed(0, 51) then -- HOME key + E key common mod menu combo
        ReportCheat("modmenu", "Potential mod menu key combination detected")
    end
    
    -- This is a placeholder - real mod menu detection would need more sophisticated methods
    -- and would typically involve memory scanning which is not possible in pure FiveM Lua
end

function MonitorResources()
    -- Get all resources
    local resources = {}
    local resourceCount = GetNumResources()
    
    for i = 0, resourceCount - 1 do
        local resourceName = GetResourceByFindIndex(i)
        table.insert(resources, resourceName)
    end
    
    -- Send to server for verification
    TriggerServerEvent("NexusGuard:VerifyResources", resources)
end

-- Report detected cheats to the server
function ReportCheat(type, details)
    if not NexusGuard.flags.warningIssued then
        -- First detection is just a warning
        NexusGuard.flags.suspiciousActivity = true
        NexusGuard.flags.warningIssued = true
        
        TriggerEvent("NexusGuard:CheatWarning", type, details)
    else
        -- Report to server
        TriggerServerEvent("NexusGuard:ReportCheat", type, details, NexusGuard.securityToken)
    end
end

-- Event handler for security token from server
RegisterNetEvent("NexusGuard:ReceiveSecurityToken")
AddEventHandler("NexusGuard:ReceiveSecurityToken", function(token)
    NexusGuard.securityToken = token
    print("[NexusGuard] Security handshake completed")
end)

-- Display warning to user
RegisterNetEvent("NexusGuard:CheatWarning")
AddEventHandler("NexusGuard:CheatWarning", function(type, details)
    TriggerEvent('chat:addMessage', {
        color = { 255, 0, 0 },
        multiline = true,
        args = { "[NexusGuard]", "Suspicious activity detected! Type: " .. type .. ". Further violations will result in automatic ban." }
    })
end)