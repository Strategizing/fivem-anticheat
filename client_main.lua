--[[
    NexusGuard Client 
    Advanced anti-cheat detection system for FiveM
    Version: 1.1.0
]]

-- Safer environment detection without potentially breaking Citizen
local isDebugEnvironment = type(Citizen) ~= "table" or type(Citizen.CreateThread) ~= "function"

    -- Debug compatibility layer
    if isDebugEnvironment then
        print("^3[DEBUG]^7 Debug environment detected, loading compatibility layer")
        
        -- Only create stubs if they don't exist
        RegisterNetEvent = RegisterNetEvent or function(eventName) return eventName end
        
        Citizen = Citizen or {
            CreateThread = function(callback) 
                if type(callback) == "function" then callback() end
            end,
            Wait = function(ms) end
        }
        
        vector3 = vector3 or function(x, y, z)
            local v = {x = x or 0, y = y or 0, z = z or 0}
            -- Add metatable for vector operations and tostring
            return setmetatable(v, {
                __add = function(a, b) return vector3(a.x + b.x, a.y + b.y, a.z + b.z) end,
                __sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end,
                __unm = function(a) return vector3(-a.x, -a.y, -a.z) end,
                __mul = function(a, b) 
                    if type(a) == "number" then
                        return vector3(a * b.x, a * b.y, a * b.z)
                    elseif type(b) == "number" then
                        return vector3(a.x * b, a.y * b, a.z * b)
                    end
                end,
                __len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end,
                __tostring = function(a) return string.format("(%f, %f, %f)", a.x, a.y, a.z) end
            })
        end
        
        GetGameTimer = GetGameTimer or function() return math.floor(os.clock() * 1000) end
    end
    
    -- Register required events
    RegisterNetEvent('onClientResourceStart')
    RegisterNetEvent('NexusGuard:ReceiveSecurityToken')
    RegisterNetEvent('nexusguard:initializeClient')
    RegisterNetEvent('NexusGuard:CheatWarning') 
    RegisterNetEvent('nexusguard:requestScreenshot')
    
    --[[
        NexusGuard Core Class
        Central management for all anti-cheat functionality
    ]]
    local NexusGuard = {
        -- Security
        securityToken = nil,
        
        -- Module status tracking
        moduleStatus = {},
        
        -- Detection intervals (ms)
        intervals = {
            godMode = 5000,
            weaponModification = 3000,
            speedHack = 2000,
            teleport = 1000,
            noclip = 1000,
            menuDetection = 10000,
            resourceMonitor = 15000
        },
        
        -- Player state tracking
        state = {
            position = vector3(0, 0, 0),
            health = 100,
            armor = 0,
            lastPositionUpdate = GetGameTimer(),
            lastTeleport = GetGameTimer(),
            movementSamples = {},
            weaponStats = {}
        },
        
        -- Alert flags
        flags = {
            suspiciousActivity = false,
            warningIssued = false
        },
        
        -- Discord rich presence
        richPresence = {
            appId = nil,
            updateInterval = 60000,
            serverName = "Protected Server",
            lastUpdate = 0
        },
        
        -- Resource monitoring
        resources = {
            lastCheck = 0,
            whitelist = {}
        },
        
        -- System state
        initialized = false,
        
        -- Version
        version = "1.1.0"
    }
    
    --[[
        Safe Detection Wrapper
        Wraps detection methods with error handling to prevent crashes
    ]]
    function NexusGuard:SafeDetect(detectionFn, detectionName)
        local success, error = pcall(function()
            detectionFn(self)
        end)
        
        if not success then
            print("^1[NexusGuard]^7 Error in " .. detectionName .. " detection: " .. tostring(error))
            
            -- Report critical errors to server if they occur frequently
            if not self.errors then self.errors = {} end
            if not self.errors[detectionName] then 
                self.errors[detectionName] = {count = 0, firstSeen = GetGameTimer()}
            end
            
            self.errors[detectionName].count = self.errors[detectionName].count + 1
            
            -- If errors persist, notify server
            if self.errors[detectionName].count > 5 and 
               GetGameTimer() - self.errors[detectionName].firstSeen < 60000 then
                if self.securityToken then
                    TriggerServerEvent("NexusGuard:ClientError", detectionName, tostring(error), self.securityToken)
                end
                
                -- Reset error counter to prevent spam
                self.errors[detectionName].count = 0
                self.errors[detectionName].firstSeen = GetGameTimer()
            end
        end
    end
    
    --[[
        Core Anti-Cheat Initialization
    ]]
    function NexusGuard:Initialize()
        -- Prevent duplicate initialization
        if self.initialized then return end
        
        Citizen.CreateThread(function()
            -- Wait for scripts to load
            Citizen.Wait(1000)
            
            -- Wait for network session to become active
            local sessionStartTime = GetGameTimer()
            local timeout = 30000 -- 30 second timeout
            
            while not NetworkIsSessionActive() do
                Citizen.Wait(100)
                -- Check for timeout
                if GetGameTimer() - sessionStartTime > timeout then
                    print("^1[NexusGuard]^7 Warning: NetworkIsSessionActive() timed out")
                    break
                end
            end
            
            print('^2[NexusGuard]^7 Initializing protection system...')
            
            -- Generate unique client hash for verification
            local clientHash = GetCurrentResourceName() .. "-" .. math.random(100000, 999999)
            
            -- Request security token from server
            TriggerServerEvent('NexusGuard:RequestSecurityToken', clientHash)
            
            -- Allow time for token receipt
            Citizen.Wait(2000)
            
            -- Start protection modules
            self:StartProtectionModules()
            
            self.initialized = true
            print('^2[NexusGuard]^7 Protection system initialized')
        end)
    end
    
    --[[
        Protection Module Management
        Starts and schedules all protection features
    ]]
    function NexusGuard:StartProtectionModules()
        -- Main detection thread with optimized scheduling
        Citizen.CreateThread(function()
            while true do
                -- Base loop interval
                Citizen.Wait(1000)
                
                -- Skip processing if not initialized or config missing
                if not self.initialized or not Config or not Config.Detectors then
                    Citizen.Wait(1000)
                    goto continue
                end
                
                local currentTime = GetGameTimer()
                local timeSinceLastCheck = {}
                
                -- Calculate time since last module ran
                for module, _ in pairs(self.moduleStatus) do
                    timeSinceLastCheck[module] = currentTime - (self.moduleStatus[module] or 0)
                end
                
                -- Run each detector based on its scheduled interval using safe wrapper
                if Config.Detectors.godMode and (timeSinceLastCheck.godMode or 0) > self.intervals.godMode then
                    self:SafeDetect(self.DetectGodMode, "godMode")
                    self.moduleStatus.godMode = currentTime
                end
                
                if Config.Detectors.weaponModification and (timeSinceLastCheck.weaponMod or 0) > self.intervals.weaponModification then
                    self:SafeDetect(self.DetectWeaponModification, "weaponMod")
                    self.moduleStatus.weaponMod = currentTime
                end
                
                if Config.Detectors.speedHack and (timeSinceLastCheck.speedHack or 0) > self.intervals.speedHack then
                    self:SafeDetect(self.DetectSpeedHack, "speedHack")
                    self.moduleStatus.speedHack = currentTime
                end
                
                if Config.Detectors.teleporting and (timeSinceLastCheck.teleport or 0) > self.intervals.teleport then
                    self:SafeDetect(self.DetectTeleport, "teleport")
                    self.moduleStatus.teleport = currentTime
                end
                
                if Config.Detectors.noclip and (timeSinceLastCheck.noclip or 0) > self.intervals.noclip then        if Config.Detectors.noclip and (timeSinceLastCheck.noclip or 0) > self.intervals.noclip then
                    self:SafeDetect(self.DetectNoClip, "noclip")tectNoClip, "noclip")
                    self.moduleStatus.noclip = currentTime currentTime
                end
                        
                if Config.Detectors.menuDetection and (timeSinceLastCheck.menuDetection or 0) > self.intervals.menuDetection thenuDetection and (timeSinceLastCheck.menuDetection or 0) > self.intervals.menuDetection then
                    self:SafeDetect(self.DetectModMenus, "menuDetection")tectModMenus, "menuDetection")
                    self.moduleStatus.menuDetection = currentTime
                endd
                     
                -- Resource monitoring runs less frequently        -- Resource monitoring runs less frequently
                if Config.Detectors.resourceInjection and (currentTime - self.resources.lastCheck) > self.intervals.resourceMonitor theneInjection and (currentTime - self.resources.lastCheck) > self.intervals.resourceMonitor then
                    self:SafeDetect(self.MonitorResources, "resourceMonitor")ources, "resourceMonitor")
                    self.resources.lastCheck = currentTime
                endd
                     
                ::continue::        ::continue::
            end
        end)
        
        -- Initialize rich presence if configured
        self:InitializeRichPresence():InitializeRichPresence()
    end
    
    --[[
        God Mode Detectione Detection
        Checks for invincibility and abnormal health valuescks for invincibility flags and abnormal health values
    ]]
    function NexusGuard:DetectGodMode()
        local ped = PlayerPedId()erId()
        local player = PlayerId()
        
        -- Safety checks-- Safety checks
        if not DoesEntityExist(ped) then return end(ped) then return end
        
        local health = GetEntityHealth(ped) local health = GetEntityHealth(ped)
        local maxHealth = GetPedMaxHealth(ped)    local maxHealth = GetPedMaxHealth(ped)
        local armor = GetPedArmour(ped)local armor = GetPedArmour(ped)
        
        -- Check for invincibility flag
        if GetPlayerInvincible(player) then  if GetPlayerInvincible(player) then
            self:ReportCheat("godmode", "Player has invincibility flag enabled")s invincibility flag enabled")
            return
        endend
        
        -- Check for abnormal health values
        if health > maxHealth and health > 200 thenif health > maxHealth and health > 200 then
            self:ReportCheat("godmode", "Abnormal health detected: " .. health .. "/" .. maxHealth)alth detected: " .. health .. "/" .. maxHealth)
            return    return
        end
        
        -- Track health regeneration (if enabled)
        if self.state.health < health and health < maxHealth thenth then
            local healthIncrease = health - self.state.healthlocal healthIncrease = health - self.state.health
            local threshold = (Config.Thresholds and Config.Thresholds.healthRegenerationRate) or 2.0g.Thresholds.healthRegenerationRate) or 2.0
            
            -- If health increased too rapidly without medical item use medical item use
            if healthIncrease > threshold thenshold then
                self:ReportCheat("godmode", "Abnormal health regeneration: +" .. healthIncrease .. " HP")e", "Abnormal health regeneration: +" .. healthIncrease .. " HP")
            end
        end
        
        -- Check for armor anomalies (if armor is abnormally high)rmor anomalies (if armor is abnormally high)
        if armor > 100 thenr > 100 then
            self:ReportCheat("godmode", "Abnormal armor value: " .. armor)self:ReportCheat("godmode", "Abnormal armor value: " .. armor)
        end
        
        -- Update player statepdate player state
        self.state.health = healthples or time passed
    end
    
    --[[ + 1
        Weapon Modification Detectionation Detection        return
        Checks for modified weapon damage and clip sizefor modified weapon damage and clip size
    ]]
    function NexusGuard:DetectWeaponModification()n modifications with configurable thresholds
        local ped = PlayerPedId()
        
        -- Safety checksgeThreshold then
        if not DoesEntityExist(ped) then return ende modified: " .. damage .. 
        
        local weaponHash = GetSelectedPedWeapon(ped)eaponHash = GetSelectedPedWeapon(ped)    end
        
        -- Only check if player has a weapon equipped
        if weaponHash ~= GetHashKey("WEAPON_UNARMED") thenod", "Weapon clip size modified: " .. clipSize .. 
            local damage = GetWeaponDamage(weaponHash, 0) storedStats.clipSize .. ")")
            local clipSize = GetWeaponClipSize(weaponHash)al clipSize = GetWeaponClipSize(weaponHash)
             
            -- Initialize weapon stats if not yet recorded     -- Initialize weapon stats if not yet recorded
            if weaponHash and not self.state.weaponStats[weaponHash] then        if weaponHash and not self.state.weaponStats[weaponHash] then
                self.state.weaponStats[weaponHash] = {        self.state.weaponStats[weaponHash] = {
                    damage = damage, damage,
                    clipSize = clipSize,
                    firstSeen = GetGameTimer(),              firstSeen = GetGameTimer(),
                    samples = 1
                }
                return                       " (Expected: " .. storedStats.damage .. ")")
            endcks
            
            -- Compare with previously stored values    if clipSize > storedStats.clipSize * 2 then
            local storedStats = self.state.weaponStats[weaponHash] clip size modified: " .. clipSize .. 
            
            -- Only check after collecting enough samples or time passed    end
            if GetGameTimer() - storedStats.firstSeen < 10000 and storedStats.samples < 3 then
                -- Still in learning phase, update samples
                storedStats.samples = storedStats.samples + 1
                returncle)
            endModelMaxSpeed(model)
            ks for abnormal vehicle or player movement speeds
            -- Check for weapon modifications with configurable thresholds
            local damageThreshold = (Config.Thresholds and Config.Thresholds.weaponDamageMultiplier) or 1.5 kmhSpeed = math.floor(speed * 3.6)
            
            if damage > storedStats.damage * damageThreshold then
                self:ReportCheat("weaponmod", "Weapon damage modified: " .. damage .. eed .. " km/h)")
        if not DoesEntityExist(ped) then return end       " (Expected: " .. storedStats.damage .. ")")
        
        local vehicle = GetVehiclePedIsIn(ped, false)    
        local speedThreshold = (Config.Thresholds and Config.Thresholds.speedHackMultiplier) or 1.3* 2 then
        ", "Weapon clip size modified: " .. clipSize .. 
        if vehicle ~= 0 then: " .. storedStats.clipSize .. ")")
            -- Vehicle speed check
            local speed = GetEntitySpeed(vehicle)end
            local model = GetEntityModel(vehicle)
            local maxSpeed = GetVehicleModelMaxSpeed(model)
            
            if maxSpeed > 0 and speed > maxSpeed * speedThreshold then
                local kmhSpeed = math.floor(speed * 3.6)ks for abnormal vehicle or player movement speeds
                local kmhMaxSpeed = math.floor(maxSpeed * 3.6)
                self:ReportCheat("speedhack", "Vehicle speed abnormal: " .. kmhSpeed .. 
                              " km/h (Max: " .. kmhMaxSpeed .. " km/h)")
            end
        else
            -- On-foot speed check
            local speed = GetEntitySpeed(ped)
            if speed > 10.0 and not IsPedInParachuteFreeFall(ped) thenehicle = GetVehiclePedIsIn(ped, false)
                self:ReportCheat("speedhack", "Player movement speed abnormal: " .. al speedThreshold = (Config.Thresholds and Config.Thresholds.speedHackMultiplier) or 1.3
                              math.floor(speed * 3.6) .. " km/h")
            end
        end
    end
         local model = GetEntityModel(vehicle)
    --[[        local maxSpeed = GetVehicleModelMaxSpeed(model)
        Teleport Detection    
        Checks for sudden position changes that aren't possible normally> 0 and speed > maxSpeed * speedThreshold then
    ]].6)
    function NexusGuard:DetectTeleport()          local kmhMaxSpeed = math.floor(maxSpeed * 3.6)
        local ped = PlayerPedId()dhack", "Vehicle speed abnormal: " .. kmhSpeed .. 
        m/h (Max: " .. kmhMaxSpeed .. " km/h)")
        -- Safety checks    end
        if not DoesEntityExist(ped) then return end
        
        local currentPos = GetEntityCoords(ped)
        local lastPos = self.state.positionarachuteFreeFall(ped) then
        local currentTime = GetGameTimer()        self:ReportCheat("speedhack", "Player movement speed abnormal: " .. 
        local teleportThreshold = (Config.Thresholds and Config.Thresholds.teleportDistance) or 100.0(speed * 3.6) .. " km/h")
        
        -- Only check if we have a valid previous positionend
        if lastPos and (lastPos.x ~= 0 or lastPos.y ~= 0 or lastPos.z ~= 0) then
            local distance = #(currentPos - lastPos)
            local timeDiff = currentTime - self.state.lastPositionUpdate
            
            -- If player moved more than threshold in less than 1 second without vehicle
            if distance > teleportThreshold and timeDiff < 1000 and GetVehiclePedIsIn(ped, false) == 0 then
                -- Ignore legitimate teleports (game loading screens, etc)tion NexusGuard:DetectTeleport()
                if not IsPlayerSwitchInProgress() and not IsScreenFadedOut() then
                    self:ReportCheat("teleport", "Possible teleport detected: " .. 
                                  math.floor(distance) .. " meters in " .. timeDiff .. "ms")
                end
            end
        end
        stPos = self.state.position
        -- Update player state
        self.state.position = currentPosg.Thresholds.teleportDistance) or 100.0
        self.state.lastPositionUpdate = currentTime
    endcheck if we have a valid previous position
    
    --[[os)
        NoClip Detection
        Checks for floating without proper game state
    ]]
    function NexusGuard:DetectNoClip()alse) == 0 then
        local ped = PlayerPedId()re legitimate teleports (game loading screens, etc)
        not IsPlayerSwitchInProgress() and not IsScreenFadedOut() then
        -- Safety checks     self:ReportCheat("teleport", "Possible teleport detected: " .. 
        if not DoesEntityExist(ped) then return end                       math.floor(distance) .. " meters in " .. timeDiff .. "ms")
        if GetVehiclePedIsIn(ped, false) ~= 0 then return end         end
        if IsEntityDead(ped) then return end        end
        end
        local pos = GetEntityCoords(ped)
        local tolerance = (Config.Thresholds and Config.Thresholds.noclipTolerance) or 3.0
          self.state.position = currentPos
        -- Ensure valid positioncurrentTime
        if not pos or not pos.x then return end
        
        -- Get ground information
        local success, groundZ = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z, false)
        local distanceToGround = pos.z - (groundZ or pos.z)cks for floating without proper game state
        
        -- Check if player is floating significantly above ground
        if success and distanceToGround > tolerance then
            -- Check if player is in a legitimate falling state 
            if not IsPedInParachuteFreeFall(ped) and     -- Safety checks
               not IsPedFalling(ped) and if not DoesEntityExist(ped) then return end
               not IsPedJumpingOutOfVehicle(ped) thenn(ped, false) ~= 0 then return end
                
                -- Get velocity to determine if player is stationary in air  
                local _, _, zVelocity = GetEntityVelocity(ped)
                zVelocity = zVelocity or 0nd Config.Thresholds.noclipTolerance) or 3.0
                
                -- If player is floating and not moving vertically (not falling)
                if math.abs(zVelocity) < 0.1 thenif not pos or not pos.x then return end
                    local collisionDisabled = GetEntityCollisionDisabled(ped)
                    if collisionDisabled then
                        self:ReportCheat("noclip", "NoClip detected: Collision disabled while floating " ..  GetGroundZFor_3dCoord(pos.x, pos.y, pos.z, false)
                                      math.floor(distanceToGround) .. " units above ground")pos.z)
                    end
                endCheck if player is floating significantly above ground
            endif success and distanceToGround > tolerance then
        endate
    end
            not IsPedFalling(ped) and 
    --[[           not IsPedJumpingOutOfVehicle(ped) then
        Mod Menu Detection        
        Checks for common mod menu indicatorsto determine if player is stationary in air
    ]]ty = GetEntityVelocity(ped)
    function NexusGuard:DetectModMenus()          zVelocity = zVelocity or 0
        -- Check for common mod menu key combinations
        if IsControlJustPressed(0, 178) and IsControlJustPressed(0, 51) thenoving vertically (not falling)
            -- HOME key + E key common mod menu combo
            self:ReportCheat("modmenu", "Potential mod menu key combination detected")CollisionDisabled(ped)
        end  if collisionDisabled then
                     self:ReportCheat("noclip", "NoClip detected: Collision disabled while floating " .. 
        -- Check for suspicious globals or natives that mod menus typically use                              math.floor(distanceToGround) .. " units above ground")
        -- This implementation would need to be expanded with more sophisticated detection
    end
    
    --[[
        Resource Monitoring
        Checks for injected/unauthorized resources
    ]]
    function NexusGuard:MonitorResources()n
        -- Get all currently running resourcestors
        local resources = {}
        local resourceCount = GetNumResources()xusGuard:DetectModMenus()
        heck for common mod menu key combinations
        for i = 0, resourceCount - 1 do if IsControlJustPressed(0, 178) and IsControlJustPressed(0, 51) then
            local resourceName = GetResourceByFindIndex(i)        -- HOME key + E key common mod menu combo
            if resourceName then    self:ReportCheat("modmenu", "Potential mod menu key combination detected")
                table.insert(resources, resourceName)
            end
        end  -- Check for suspicious globals or natives that mod menus typically use
         be expanded with more sophisticated detection
        -- Send to server for verification against whitelist
        TriggerServerEvent("NexusGuard:VerifyResources", resources, self.securityToken)
    end
    ource Monitoring
    --[[Checks for injected/unauthorized resources
        Rich Presence Management
        Handles Discord integration
    ]]
    function NexusGuard:InitializeRichPresence()l resources = {}
        -- Skip if Discord integration is disabled
        if not Config or not Config.Discord or not Config.Discord.RichPresence or 
           not Config.Discord.RichPresence.Enabled then 0, resourceCount - 1 do
            return local resourceName = GetResourceByFindIndex(i)
        end    if resourceName then
        
        -- Initialize Discord presence
        if Config.Discord.RichPresence.AppId then
            SetDiscordAppId(Config.Discord.RichPresence.AppId)
        end
        ServerEvent("NexusGuard:VerifyResources", resources, self.securityToken)
        -- Set up presence update thread
        Citizen.CreateThread(function()
            while true do
                self:UpdateRichPresence()
                Citizen.Wait(Config.Discord.RichPresence.UpdateInterval * 1000 or 60000)
            end
        end)
    endDiscord integration is disabled
    Config or not Config.Discord or not Config.Discord.RichPresence or 
    --[[not Config.Discord.RichPresence.Enabled then
        Update Rich Presence    return
        Updates Discord status with player info
    ]]
    function NexusGuard:UpdateRichPresence()
        if not Config.Discord or not Config.Discord.RichPresence or 
           not Config.Discord.RichPresence.Enabled then    SetDiscordAppId(Config.Discord.RichPresence.AppId)
            return
        end
        pdate thread
        -- Set rich presence assets if configured
        if Config.Discord.RichPresence.LargeImage then
            SetDiscordRichPresenceAsset(Config.Discord.RichPresence.LargeImage)        self:UpdateRichPresence()
            nfig.Discord.RichPresence.UpdateInterval * 1000 or 60000)
            if Config.Discord.RichPresence.LargeImageText then
                SetDiscordRichPresenceAssetText(Config.Discord.RichPresence.LargeImageText)
            end
        end
        [
        if Config.Discord.RichPresence.SmallImage then    Update Rich Presence
            SetDiscordRichPresenceAssetSmall(Config.Discord.RichPresence.SmallImage)Updates Discord status with player info
            
            if Config.Discord.RichPresence.SmallImageText thenence()
                SetDiscordRichPresenceAssetSmallText(Config.Discord.RichPresence.SmallImageText)  if not Config.Discord or not Config.Discord.RichPresence or 
            end then
        end
        
        -- Set action buttons
        if Config.Discord.RichPresence.buttons thenSet rich presence assets if configured
            for i, button in ipairs(Config.Discord.RichPresence.buttons) doif Config.Discord.RichPresence.LargeImage then
                if button.label and button.url and i <= 2 thenfig.Discord.RichPresence.LargeImage)
                    SetDiscordRichPresenceAction(i-1, button.label, button.url)
                endImageText then
            endText(Config.Discord.RichPresence.LargeImageText)
        endend
        
        -- Set rich presence text
        local playerName = GetPlayerName(PlayerId())n
        local serverId = GetPlayerServerId(PlayerId())
        local health = GetEntityHealth(PlayerPedId()) - 100
         if Config.Discord.RichPresence.SmallImageText then
        if health < 0 then health = 0 end         SetDiscordRichPresenceAssetSmallText(Config.Discord.RichPresence.SmallImageText)
                end
        -- Get location infoend
        local coords = GetEntityCoords(PlayerPedId())
        local streetName = GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z))  -- Set action buttons
        
        -- Format presence text.buttons) do
        local presence = string.format("ID: %s | %s | HP: %s%% | %s",         if button.label and button.url and i <= 2 then
            serverId, playerName, health, streetName or "Unknown Location")ceAction(i-1, button.label, button.url)
        
        SetRichPresence(presence)    end
    end    end
    
    --[[
        Cheat Reportinglocal playerName = GetPlayerName(PlayerId())
        Sends detection info to serverId(PlayerId())
    ]]
    function NexusGuard:ReportCheat(type, details)
        -- Skip if not initialized or no security token    if health < 0 then health = 0 end
        if not self.initialized or not self.securityToken then 
            return
        endords(PlayerPedId())
        tStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z))
        -- First detection issues a warning
        if not self.flags.warningIssued then
            self.flags.suspiciousActivity = trues", 
            self.flags.warningIssued = truetion")
            
            TriggerEvent("NexusGuard:CheatWarning", type, details)tRichPresence(presence)
        else
            -- Use both event names for compatibility
            TriggerServerEvent("NexusGuard:ReportCheat", type, details, self.securityToken)
            TriggerServerEvent("nexusguard:detection", type, details, self.securityToken)
        endtion info to server
    end
    tion NexusGuard:ReportCheat(type, details)
    --[[ity token
        Event Handlersen 
    ]]
    AddEventHandler("NexusGuard:ReceiveSecurityToken", function(token)
        if not token or type(token) ~= "string" then return end
        
        NexusGuard.securityToken = tokenelf.flags.warningIssued then
        print("[NexusGuard] Security handshake completed")
    end)
    
    AddEventHandler("nexusguard:initializeClient", function(token)s)
        if not token or type(token) ~= "string" then return end
        both event names for compatibility
        NexusGuard.securityToken = tokenggerServerEvent("NexusGuard:ReportCheat", type, details, self.securityToken)
        print("[NexusGuard] Client initialized via alternate event")   TriggerServerEvent("nexusguard:detection", type, details, self.securityToken)
    end)end
    end
    AddEventHandler("NexusGuard:CheatWarning", function(type, details)
        TriggerEvent('chat:addMessage', {
            color = { 255, 0, 0 },
            multiline = true,
            args = { veSecurityToken", function(token)
                "[NexusGuard]", ype(token) ~= "string" then return end
                "Suspicious activity detected! Type: " .. type .. 
                ". Further violations will result in automatic ban." NexusGuard.securityToken = token


































    end)        NexusGuard:Initialize()        Citizen.Wait(500)        -- Allow Config to load first                if GetCurrentResourceName() ~= resourceName then return end    AddEventHandler('onClientResourceStart', function(resourceName)    -- Initialize on resource start        end)        )            end                end                                       NexusGuard.securityToken)                                       resp.attachments[1].url,                     TriggerServerEvent('nexusguard:screenshotTaken',                 if success and resp and resp.attachments and resp.attachments[1] then                local success, resp = pcall(json.decode, data)                                if not data then return end            function(data)            'files[]',             Config.ScreenCapture.webhookURL,         exports['screenshot-basic']:requestScreenshotUpload(        -- Take screenshot and send to webhook                end            return         if not NexusGuard.initialized or not exports['screenshot-basic'] then     AddEventHandler("nexusguard:requestScreenshot", function()        end)        })            }        print("[NexusGuard] Security handshake completed")
    end)
    
    AddEventHandler("nexusguard:initializeClient", function(token)
        if not token or type(token) ~= "string" then return end
        
        NexusGuard.securityToken = token
        print("[NexusGuard] Client initialized via alternate event")
    end)
    
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
    
    AddEventHandler("nexusguard:requestScreenshot", function()
        if not NexusGuard.initialized or not exports['screenshot-basic'] then 
            return 
        end
        
        -- Take screenshot and send to webhook
        exports['screenshot-basic']:requestScreenshotUpload(
            Config.ScreenCapture.webhookURL, 
            'files[]', 
            function(data)
                if not data then return end
                
                local success, resp = pcall(json.decode, data)
                if success and resp and resp.attachments and resp.attachments[1] then
                    TriggerServerEvent('nexusguard:screenshotTaken', 
                                       resp.attachments[1].url, 
                                       NexusGuard.securityToken)
                end
            end
        )
    end)
    
    -- Initialize on resource start
    AddEventHandler('onClientResourceStart', function(resourceName)
        if GetCurrentResourceName() ~= resourceName then return end
        
        -- Allow Config to load first
        Citizen.Wait(500)
        NexusGuard:Initialize()
    end)