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
    -- Expose NexusGuard globally for detectors
    _G.NexusGuard = NexusGuard

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
        Initializes features like Rich Presence. Detectors are now self-managed.
    ]]
    function NexusGuard:StartProtectionModules()
        -- The individual detectors will register and start themselves
        -- based on the DetectorRegistry and Config settings.
        -- This function now primarily handles other non-detector initializations.

        print("^2[NexusGuard]^7 Starting auxiliary modules...")

        -- Initialize rich presence if configured
        self:InitializeRichPresence()

        print("^2[NexusGuard]^7 Auxiliary modules started.")
    end

    --[[
        Rich Presence Management
        Handles Discord integration
    ]]
    function NexusGuard:InitializeRichPresence()
        -- Skip if Discord integration is disabled
        if not Config or not Config.Discord or not Config.Discord.RichPresence or 
           not Config.Discord.RichPresence.Enabled then
            return
        end
        
        -- Initialize Discord presence
        if Config.Discord.RichPresence.AppId then
            SetDiscordAppId(Config.Discord.RichPresence.AppId)
        end
        
        -- Set up presence update thread
        Citizen.CreateThread(function()
            while true do
                self:UpdateRichPresence()
                Citizen.Wait(Config.Discord.RichPresence.UpdateInterval * 1000 or 60000)
            end
        end)
    end
    
    --[[
        Update Rich Presence
        Updates Discord status with player info
    ]]
    function NexusGuard:UpdateRichPresence()
        -- Cache config table locally for minor optimization
        local rpConfig = Config and Config.Discord and Config.Discord.RichPresence

        if not rpConfig or not rpConfig.Enabled then
            return
        end

        -- Set rich presence assets if configured
        if rpConfig.LargeImage then
            SetDiscordRichPresenceAsset(rpConfig.LargeImage)
            if rpConfig.LargeImageText then
                SetDiscordRichPresenceAssetText(rpConfig.LargeImageText)
            end
        end

        if rpConfig.SmallImage then
            SetDiscordRichPresenceAssetSmall(rpConfig.SmallImage)
            if rpConfig.SmallImageText then
                SetDiscordRichPresenceAssetSmallText(rpConfig.SmallImageText)
            end
        end

        -- Set action buttons
        if rpConfig.buttons then
            for i, button in ipairs(rpConfig.buttons) do
                if button.label and button.url and i <= 2 then -- Discord allows max 2 buttons
                    SetDiscordRichPresenceAction(i - 1, button.label, button.url)
                end
            end
        end
        
        -- Set rich presence text
        local playerName = GetPlayerName(PlayerId())
        local serverId = GetPlayerServerId(PlayerId())
        local health = GetEntityHealth(PlayerPedId()) - 100
        
        if health < 0 then health = 0 end
        
        -- Get location info
        local coords = GetEntityCoords(PlayerPedId())
        local streetName = GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z))
        
        -- Format presence text
        local presence = string.format("ID: %s | %s | HP: %s%% | %s", 
            serverId, playerName, health, streetName or "Unknown Location")
        
        SetRichPresence(presence)
    end
    
    --[[
        Cheat Reporting
        Sends detection info to server
    ]]
    function NexusGuard:ReportCheat(type, details)
        -- Skip if not initialized or no security token
        if not self.initialized or not self.securityToken then 
            return
        end
        
        -- First detection issues a warning
        if not self.flags.warningIssued then
            self.flags.suspiciousActivity = true
            self.flags.warningIssued = true
            
            TriggerEvent("NexusGuard:CheatWarning", type, details)
        else
            -- Use both event names for compatibility
            TriggerServerEvent("NexusGuard:ReportCheat", type, details, self.securityToken)
            TriggerServerEvent("nexusguard:detection", type, details, self.securityToken)
        end
    end
    
    --[[
        Event Handlers
    ]]
    AddEventHandler("NexusGuard:ReceiveSecurityToken", function(token)
        if not token or type(token) ~= "string" then return end
        
        NexusGuard.securityToken = token
        print("[NexusGuard] Security handshake completed")
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
