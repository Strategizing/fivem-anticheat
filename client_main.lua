--[[
    NexusGuard Client
    Advanced anti-cheat detection system for FiveM
    Version: 1.1.0
]]

-- Ensure JSON library is available (e.g., from oxmysql or another resource)
local json = json or _G.json

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

    -- Register required events using EventRegistry if available
    -- Note: onClientResourceStart is a built-in event, doesn't need registry
    if _G.EventRegistry then
        _G.EventRegistry.RegisterEvent('SECURITY_RECEIVE_TOKEN')
        _G.EventRegistry.RegisterEvent('ADMIN_NOTIFICATION') -- Used for admin alerts from server
        _G.EventRegistry.RegisterEvent('ADMIN_REQUEST_SCREENSHOT')
        -- Register the local warning event name for consistency, though handled locally
        RegisterNetEvent("NexusGuard:CheatWarning")
    else
        -- Fallback if EventRegistry hasn't loaded somehow (shouldn't happen with manifest order)
        print("^1[NexusGuard] EventRegistry not found, using fallback event names.^7")
        RegisterNetEvent('NexusGuard:ReceiveSecurityToken')
        RegisterNetEvent('NexusGuard:CheatWarning')
        RegisterNetEvent('nexusguard:requestScreenshot')
        RegisterNetEvent('nexusguard:adminNotification')
    end

    --[[
        NexusGuard Core Class
        Central management for all anti-cheat functionality
    ]]
    local NexusGuard = {
        -- Security
        securityToken = nil,

        -- Module status tracking (potentially redundant if registry handles status)
        moduleStatus = {},

        -- Detection intervals (ms) - Used by detectors during their Initialize
        intervals = {
            godMode = 5000,
            weaponModification = 3000,
            speedHack = 2000,
            teleport = 1000,
            noclip = 1000,
            menuDetection = 10000,
            resourceMonitor = 15000
        },

        -- Player state tracking (some state might move to specific detectors)
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

        -- Resource monitoring (state handled by detector)
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
        (Called by DetectorRegistry's CreateDetectorThread)
    ]]
    function NexusGuard:SafeDetect(detectionFn, detectionName)
        local success, err = pcall(detectionFn) -- Call the detector's Check function directly

        if not success then
            print("^1[NexusGuard]^7 Error in " .. detectionName .. " detection: " .. tostring(err))

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
                    -- Use EventRegistry if available
                    if _G.EventRegistry then
                        _G.EventRegistry.TriggerServerEvent('SYSTEM_ERROR', detectionName, tostring(err), self.securityToken)
                    else
                        TriggerServerEvent("NexusGuard:ClientError", detectionName, tostring(err), self.securityToken) -- Fallback
                    end
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
            -- Wait for scripts to load (Config, Registry etc.)
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

            -- Generate unique client hash for verification (Note: This hash isn't securely validated currently)
            local clientHash = GetCurrentResourceName() .. "-" .. math.random(100000, 999999)

            -- Request security token from server
            if _G.EventRegistry then
                _G.EventRegistry.TriggerServerEvent('SECURITY_REQUEST_TOKEN', clientHash)
            else
                TriggerServerEvent('NexusGuard:RequestSecurityToken', clientHash) -- Fallback
            end

            -- Allow time for token receipt
            Citizen.Wait(2000)

            -- Start auxiliary protection modules (like Rich Presence)
            -- Detectors are started automatically via their registration block
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
        print("^2[NexusGuard]^7 Starting auxiliary modules...")
        self:InitializeRichPresence()
        print("^2[NexusGuard]^7 Auxiliary modules started.")
    end

    --[[
        Rich Presence Management
        Handles Discord integration
    ]]
    function NexusGuard:InitializeRichPresence()
        local rpConfig = Config and Config.Discord and Config.Discord.RichPresence
        if not rpConfig or not rpConfig.Enabled then
            return
        end

        if rpConfig.AppId then
            SetDiscordAppId(rpConfig.AppId)
        else
            print("^3[NexusGuard] Rich Presence enabled but AppId is missing in config.^7")
            return -- Don't start update thread if AppId is missing
        end

        -- Set up presence update thread
        Citizen.CreateThread(function()
            while true do -- Loop continues as long as the resource is running
                 -- Check config again inside loop in case it changes dynamically (unlikely here)
                 local currentRpConfig = Config and Config.Discord and Config.Discord.RichPresence
                 if not currentRpConfig or not currentRpConfig.Enabled then
                     -- If disabled dynamically, stop the thread by breaking loop
                     print("^3[NexusGuard] Rich Presence disabled, stopping update thread.^7")
                     break
                 end

                self:UpdateRichPresence()
                local interval = (currentRpConfig.UpdateInterval or 60) * 1000
                Citizen.Wait(interval)
            end
        end)
        print("^2[NexusGuard] Rich Presence update thread started.^7")
    end

    --[[
        Update Rich Presence
        Updates Discord status with player info
    ]]
    function NexusGuard:UpdateRichPresence()
        local rpConfig = Config and Config.Discord and Config.Discord.RichPresence
        if not rpConfig or not rpConfig.Enabled then return end -- Should be caught by loop check, but double-check

        -- Set rich presence assets if configured
        if rpConfig.LargeImage then
            SetDiscordRichPresenceAsset(rpConfig.LargeImage)
            if rpConfig.LargeImageText then SetDiscordRichPresenceAssetText(rpConfig.LargeImageText) end
        end
        if rpConfig.SmallImage then
            SetDiscordRichPresenceAssetSmall(rpConfig.SmallImage)
            if rpConfig.SmallImageText then SetDiscordRichPresenceAssetSmallText(rpConfig.SmallImageText) end
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
        local ped = PlayerPedId()
        local health = GetEntityHealth(ped) - 100 -- Assuming 100 is base health
        if health < 0 then health = 0 end

        local coords = GetEntityCoords(ped)
        local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
        local streetName = streetHash ~= 0 and GetStreetNameFromHashKey(streetHash) or "Unknown Location"

        -- Format presence text (Example)
        local presence = string.format("ID: %s | %s | HP: %s%% | %s",
            serverId, playerName, health, streetName)

        SetRichPresence(presence)
    end

    --[[
        Cheat Reporting (Called by Detectors)
        Sends detection info to server
    ]]
    function NexusGuard:ReportCheat(type, details)
        -- Skip if not initialized or no security token
        if not self.initialized or not self.securityToken then
            print("^3[NexusGuard] ReportCheat skipped: Not initialized or no security token.^7")
            return
        end

        -- First detection issues a local warning
        if not self.flags.warningIssued then
            self.flags.suspiciousActivity = true
            self.flags.warningIssued = true
            -- Trigger local warning event
            TriggerEvent("NexusGuard:CheatWarning", type, details)
        else
            -- Report subsequent detections to server
            if _G.EventRegistry then
                _G.EventRegistry.TriggerServerEvent('DETECTION_REPORT', type, details, self.securityToken)
            else
                -- Fallback to old names
                TriggerServerEvent("NexusGuard:ReportCheat", type, details, self.securityToken)
                TriggerServerEvent("nexusguard:detection", type, details, self.securityToken)
            end
        end
    end

    --[[
        Event Handlers
    ]]
    -- Use EventRegistry for handlers where possible
    local receiveTokenEvent = (_G.EventRegistry and _G.EventRegistry.GetEventName('SECURITY_RECEIVE_TOKEN')) or "NexusGuard:ReceiveSecurityToken"
    AddEventHandler(receiveTokenEvent, function(token)
        if not token or type(token) ~= "string" then return end
        NexusGuard.securityToken = token
        print("[NexusGuard] Security handshake completed via " .. receiveTokenEvent)
    end)

    -- Handler for the local warning event (doesn't need registry)
    AddEventHandler("NexusGuard:CheatWarning", function(type, details)
        -- Use chat resource if available
        if exports.chat then
            exports.chat:addMessage({
                color = { 255, 0, 0 },
                multiline = true,
                args = {
                    "[NexusGuard]",
                    "Suspicious activity detected! Type: " .. type ..
                    ". Further violations will result in automatic ban."
                }
            })
        else
            -- Fallback print if chat resource isn't available
            print("^1[NexusGuard] Suspicious activity detected! Type: " .. type .. ". Further violations will result in automatic ban.^7")
        end
    end)

    -- Handler for screenshot request from server
    local requestScreenshotEvent = (_G.EventRegistry and _G.EventRegistry.GetEventName('ADMIN_REQUEST_SCREENSHOT')) or "nexusguard:requestScreenshot"
    AddEventHandler(requestScreenshotEvent, function()
        if not NexusGuard.initialized then print("^3[NexusGuard] Screenshot requested but not initialized.^7") return end
        if not exports['screenshot-basic'] then print("^1[NexusGuard] Screenshot requested but 'screenshot-basic' export not found.^7") return end

        -- Ensure Config and webhookURL are available
        local webhookURL = Config and Config.ScreenCapture and Config.ScreenCapture.webhookURL
        if not webhookURL or webhookURL == "" then
            print("^1[NexusGuard] Screenshot requested but webhookURL is not configured.^7")
            return
        end

        -- Take screenshot and send to webhook
        exports['screenshot-basic']:requestScreenshotUpload(
            webhookURL,
            'files[]',
            function(data)
                if not data then return end

                -- Ensure JSON library is available
                if not json then
                    print("^1[NexusGuard] JSON library not available for screenshot callback.^7")
                    return
                end

                local success, resp = pcall(json.decode, data)
                if success and resp and resp.attachments and resp.attachments[1] then
                    -- Report screenshot taken back to server
                    if _G.EventRegistry then
                         _G.EventRegistry.TriggerServerEvent('ADMIN_SCREENSHOT_TAKEN', resp.attachments[1].url, NexusGuard.securityToken)
                    else
                        TriggerServerEvent('nexusguard:screenshotTaken', resp.attachments[1].url, NexusGuard.securityToken) -- Fallback
                    end
                else
                    print("^1[NexusGuard] Failed to decode screenshot response or response invalid: " .. tostring(data) .. "^7")
                end
            end
        )
    end)

    -- Initialize on resource start
    AddEventHandler('onClientResourceStart', function(resourceName)
        if GetCurrentResourceName() ~= resourceName then return end
        -- Allow Config and other shared scripts to load first
        Citizen.Wait(500)
        NexusGuard:Initialize()
    end)
