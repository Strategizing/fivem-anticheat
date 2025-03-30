-- Ensure JSON library is available (e.g., from oxmysql or another resource)
local json = json or _G.json

-- Register built-in events
RegisterNetEvent('onResourceStart')
AddEventHandler('playerConnecting', function(...) OnPlayerConnecting(...) end)
AddEventHandler('playerDropped', function(...) OnPlayerDropped(...) end)
AddEventHandler('explosionEvent', function(...) HandleExplosionEvent(...) end)
-- AddEventHandler('entityCreated', function(...) HandleEntityCreation(...) end) -- Commented out: HandleEntityCreation is only a placeholder in globals.lua

-- Local tables
local ClientsLoaded = {}
local OnlineAdmins = {} -- Table to store server IDs of online admins

-- Validate the main Config table (loaded via manifest)
function ValidateConfig()
    -- Apply schema validation if ConfigValidator exists
    if _G.ConfigValidator then
        -- Assuming ConfigValidator modifies the global Config table directly or returns it
        _G.Config = _G.ConfigValidator.Apply(_G.Config or {})
        print('^2[NexusGuard]^7 Schema validation applied to config.')
    else
        -- Fallback to basic validation (ensure Config exists and has key tables)
        _G.Config = _G.Config or {}
        if not Config.AI then Config.AI = {enabled = false} end
        if not Config.Actions then Config.Actions = {
            kickOnSuspicion = true,
            banOnConfirmed = true,
            reportToAdminsOnSuspicion = true
        } end
        if not Config.ScreenCapture then Config.ScreenCapture = {enabled = false} end
        if not Config.Database then Config.Database = {enabled = false, historyDuration = 30} end
        if not Config.Thresholds then Config.Thresholds = {aiDecisionConfidenceThreshold = 0.75} end
        if not Config.AdminGroups then Config.AdminGroups = {"admin", "superadmin"} end
        print('^2[NexusGuard]^7 Basic configuration validation complete.')
    end
end

-- Initialize the anti-cheat on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    print('^2[NexusGuard]^7 Initializing advanced anti-cheat system...')

    -- Ensure proper initialization sequence (Calls functions expected to be global, likely from globals.lua)
    if _G.LoadBanList then _G.LoadBanList() else print("^1[NexusGuard] LoadBanList function not found!^7") end
    ValidateConfig() -- Validate the main Config table
    if _G.InitializeAIModels then _G.InitializeAIModels() else print("^3[NexusGuard] InitializeAIModels function not found (AI disabled?).^7") end
    SetupScheduledTasks() -- Setup local scheduled tasks

    -- Register server events using EventRegistry if available (defined locally)
    RegisterNexusGuardServerEvents()

    print('^2[NexusGuard]^7 Anti-cheat system initialized successfully!')
end)

-- Player connected handler
function OnPlayerConnecting(playerName, setKickReason, deferrals)
    local source = source -- Capture source from the event context
    local license = GetPlayerIdentifierByType(source, 'license')
    local ip = GetPlayerEndpoint(source)
    -- Check admin status early (Uses global IsPlayerAdmin - REQUIRES USER IMPLEMENTATION)
    local isAdmin = _G.IsPlayerAdmin and _G.IsPlayerAdmin(source) or false

    deferrals.defer()
    deferrals.update('Checking your profile against our anti-cheat database...')

    -- Check if player is banned (Uses global IsPlayerBanned - checks BanList loaded in globals.lua)
    Citizen.Wait(200) -- Reduced wait slightly
    local banned, banReason = _G.IsPlayerBanned and _G.IsPlayerBanned(license, ip) or false
    if banned then
        deferrals.done(Config.BanMessage or "You are banned.")
        -- Uses global SendToDiscord - REQUIRES USER CONFIGURATION (Webhook URL)
        if _G.SendToDiscord then _G.SendToDiscord('Connection Rejected', playerName .. ' attempted to connect but is banned. Reason: ' .. (banReason or "N/A")) end
        return
    end

    -- Initialize player metrics (Uses global PlayerMetrics table - ensure it's initialized in globals.lua or here)
    if not _G.PlayerMetrics then _G.PlayerMetrics = {} end
    _G.PlayerMetrics[source] = {
        connectTime = os.time(),
        lastPosition = nil,
        warningCount = 0,
        detections = {},
        healthHistory = {},
        movementSamples = {},
        weaponStats = {},
        behaviorProfile = {},
        trustScore = 100.0,
        securityToken = nil, -- Will be set upon successful handshake
        explosions = {},
        entities = {},
        isAdmin = isAdmin -- Store admin status
    }

    -- Add to online admin list if applicable
    if isAdmin then
        OnlineAdmins[source] = true
        print("^2[NexusGuard]^7 Admin connected: " .. playerName .. " (ID: " .. source .. ")")
    end

    deferrals.done()
end

-- Player disconnected handler
function OnPlayerDropped(reason)
    local source = source -- Capture source from the event context
    local playerName = GetPlayerName(source) or "Unknown"

    -- Save detection data to database if enabled (Uses global SavePlayerMetrics - REQUIRES USER IMPLEMENTATION)
    if Config and Config.Database and Config.Database.enabled and _G.PlayerMetrics and _G.PlayerMetrics[source] then
        if _G.SavePlayerMetrics then _G.SavePlayerMetrics(source) end
    end

    -- Clean up player data (Uses global PlayerMetrics table)
    if _G.PlayerMetrics and _G.PlayerMetrics[source] and _G.PlayerMetrics[source].isAdmin then
        OnlineAdmins[source] = nil -- Remove from admin list
        print("^2[NexusGuard]^7 Admin disconnected: " .. playerName .. " (ID: " .. source .. ")")
    end
    if _G.PlayerMetrics then _G.PlayerMetrics[source] = nil end
    ClientsLoaded[source] = nil
end

-- Register server-side event handlers using EventRegistry
function RegisterNexusGuardServerEvents()
    if not _G.EventRegistry then
        print("^1[NexusGuard] EventRegistry not found, cannot register standardized server events.^7")
        -- Consider registering fallback handlers here if EventRegistry is critical and might fail
        return
    end

    -- Security Token Request Handler
    _G.EventRegistry.AddEventHandler('SECURITY_REQUEST_TOKEN', function(clientHash)
        local source = source
        -- Validate client hash (Uses global ValidateClientHash - INSECURE PLACEHOLDER)
        if _G.ValidateClientHash and _G.ValidateClientHash(clientHash) then
            ClientsLoaded[source] = true
            -- Generate token (Uses global GenerateSecurityToken - INSECURE PLACEHOLDER)
            local token = _G.GenerateSecurityToken and _G.GenerateSecurityToken(source)
            if token then
                _G.EventRegistry.TriggerClientEvent('SECURITY_RECEIVE_TOKEN', source, token)
                print('^2[NexusGuard]^7 Security token sent to ' .. GetPlayerName(source) .. ' via ' .. _G.EventRegistry.GetEventName('SECURITY_REQUEST_TOKEN'))
            else
                 print('^1[NexusGuard]^7 Failed to generate security token for ' .. GetPlayerName(source))
                 -- Consider kicking the player if token generation fails
                 DropPlayer(source, "Anti-Cheat initialization failed (Token Generation).")
            end
        else
            print('^1[NexusGuard]^7 Invalid client hash received from ' .. GetPlayerName(source) .. '. Kicking.')
            -- Ban or kick player for potentially modified client (Uses global BanPlayer)
            if _G.BanPlayer then _G.BanPlayer(source, 'Modified client detected (Invalid Hash)')
            else DropPlayer(source, "Anti-Cheat validation failed (Client Hash).") end
        end
    end)

    -- Detection Report Handler
    _G.EventRegistry.AddEventHandler('DETECTION_REPORT', function(detectionType, detectionData, securityToken)
        local source = source
        -- Validate security token (Uses global ValidateSecurityToken - INSECURE PLACEHOLDER)
        if not _G.ValidateSecurityToken or not _G.ValidateSecurityToken(source, securityToken) then
            if _G.BanPlayer then _G.BanPlayer(source, 'Invalid security token')
            else DropPlayer(source, "Anti-Cheat validation failed (Invalid Token).") end
            return
        end
        -- Process the detection (Uses global ProcessDetection - defined below, relies on other globals)
        if _G.ProcessDetection then
            _G.ProcessDetection(source, detectionType, detectionData)
        else
             print("^1[NexusGuard] ProcessDetection function not found!^7")
        end
    end)

    -- Resource Verification Handler
    _G.EventRegistry.AddEventHandler('SYSTEM_RESOURCE_CHECK', function(resources, securityToken)
        local source = source
        if not source or source <= 0 then return end

        -- Validate security token (Uses global ValidateSecurityToken - INSECURE PLACEHOLDER)
        if not _G.ValidateSecurityToken or not _G.ValidateSecurityToken(source, securityToken) then
            if _G.BanPlayer then _G.BanPlayer(source, 'Invalid security token during resource check')
            else DropPlayer(source, "Anti-Cheat validation failed (Resource Check Token).") end
            return
        end

        print('^3[NexusGuard]^7 Received resource list from ' .. GetPlayerName(source) .. ' with ' .. #resources .. ' resources via ' .. _G.EventRegistry.GetEventName('SYSTEM_RESOURCE_CHECK'))

        -- Resource Verification Logic
        local rvConfig = Config and Config.Features and Config.Features.resourceVerification
        if rvConfig and rvConfig.enabled then
            local playerName = GetPlayerName(source)
            local MismatchedResources = {}

            if rvConfig.mode == "whitelist" then
                local allowedSet = {}
                for _, resName in ipairs(rvConfig.whitelist or {}) do
                    allowedSet[resName] = true
                end
                -- Check client resources against whitelist
                for _, clientRes in ipairs(resources) do
                    if not allowedSet[clientRes] then
                        table.insert(MismatchedResources, clientRes .. " (Not Whitelisted)")
                    end
                end
            elseif rvConfig.mode == "blacklist" then
                local disallowedSet = {}
                for _, resName in ipairs(rvConfig.blacklist or {}) do
                    disallowedSet[resName] = true
                end
                -- Check client resources against blacklist
                for _, clientRes in ipairs(resources) do
                    if disallowedSet[clientRes] then
                        table.insert(MismatchedResources, clientRes .. " (Blacklisted)")
                    end
                end
            end

            -- Take action if mismatches found
            if #MismatchedResources > 0 then
                local reason = "Unauthorized resources detected: " .. table.concat(MismatchedResources, ", ")
                Log("^1[NexusGuard] " .. playerName .. " - " .. reason .. "^7", 1)
                if _G.SendToDiscord then _G.SendToDiscord("Resource Mismatch", playerName .. " - " .. reason) end

                if rvConfig.banOnMismatch then
                    if _G.BanPlayer then _G.BanPlayer(source, reason) end
                elseif rvConfig.kickOnMismatch then
                    DropPlayer(source, "Kicked due to unauthorized resources.")
                end
                -- Potentially add to PlayerMetrics detections as well
                if _G.ProcessDetection then _G.ProcessDetection(source, "ResourceMismatch", {mismatched = MismatchedResources}) end
            else
                 Log("^2[NexusGuard] Resource check passed for " .. playerName .. "^7", 2)
            end
        else
             Log("^3[NexusGuard] Resource verification is disabled in config.^7", 3)
        end
    end)

    -- Client Error Handler
    _G.EventRegistry.AddEventHandler('SYSTEM_ERROR', function(detectionName, errorMessage, securityToken)
        local source = source
        -- Validate security token (Uses global ValidateSecurityToken - INSECURE PLACEHOLDER)
        if not _G.ValidateSecurityToken or not _G.ValidateSecurityToken(source, securityToken) then
            print("^1[NexusGuard]^7 Invalid security token in error report from " .. GetPlayerName(source))
            return -- Don't ban for errors with invalid tokens
        end

        print("^3[NexusGuard]^7 Client error in " .. detectionName .. " from " .. GetPlayerName(source) .. ": " .. errorMessage)

        -- Log the error to Discord (Uses global SendToDiscord)
        if Config and Config.EnableDiscordLogs and _G.SendToDiscord then
            _G.SendToDiscord('Client Error',
                "Player: " .. GetPlayerName(source) .. "\n" ..
                "Detection: " .. detectionName .. "\n" ..
                "Error: " .. errorMessage
            )
        end

        -- Track client errors in player metrics (Uses global PlayerMetrics table)
        if _G.PlayerMetrics and _G.PlayerMetrics[source] then
            if not _G.PlayerMetrics[source].clientErrors then
                _G.PlayerMetrics[source].clientErrors = {}
            end
            table.insert(_G.PlayerMetrics[source].clientErrors, {
                detection = detectionName,
                error = errorMessage,
                time = os.time()
            })
        end
    end)

     -- Screenshot Taken Handler
     _G.EventRegistry.AddEventHandler('ADMIN_SCREENSHOT_TAKEN', function(screenshotUrl, securityToken)
        local source = source
        -- Validate security token (Uses global ValidateSecurityToken - INSECURE PLACEHOLDER)
        if not _G.ValidateSecurityToken or not _G.ValidateSecurityToken(source, securityToken) then
             if _G.BanPlayer then _G.BanPlayer(source, 'Invalid security token with screenshot')
             else DropPlayer(source, "Anti-Cheat validation failed (Screenshot Token).") end
            return
        end
        local playerName = GetPlayerName(source) or "Unknown"
        print("^2[NexusGuard]^7 Received screenshot from " .. playerName .. ": " .. screenshotUrl)
        -- Log to Discord or notify admins (Uses global SendToDiscord)
        if Config and Config.EnableDiscordLogs and _G.SendToDiscord then
            _G.SendToDiscord('Screenshot Taken', "Player: " .. playerName .. " (ID: " .. source .. ")\nURL: " .. screenshotUrl)
        end
        -- Potentially notify admins via ADMIN_NOTIFICATION as well
        -- NotifyAdmins(source, "ScreenshotTaken", {url = screenshotUrl}) -- Example
    end)

    print("^2[NexusGuard] Registered standardized server event handlers.^7")
end


-- Process Detection Logic (Relies on global functions from globals.lua)
-- This function coordinates the response to a detection event.
function ProcessDetection(playerId, detectionType, detectionData)
    -- Check for valid input
    if not playerId or not detectionType then return end
    local playerName = GetPlayerName(playerId) or "Unknown"

    print('^1[NexusGuard]^7 Detection: ' .. playerName .. ' (ID: '..playerId..') - Type: ' .. detectionType)

    -- Store detection in database if enabled
    if _G.StoreDetection then _G.StoreDetection(playerId, detectionType, detectionData) end

    -- Record detection in player's history (Uses global PlayerMetrics table)
    -- Add extra check to ensure metrics table exists for the player
    if _G.PlayerMetrics and _G.PlayerMetrics[playerId] then
        local metrics = _G.PlayerMetrics[playerId] -- Use local variable for clarity
        if not metrics.detections then metrics.detections = {} end
        table.insert(metrics.detections, {
            type = detectionType,
            data = detectionData,
            timestamp = os.time()
        })

        -- Update trust score based on detection severity (Uses global GetDetectionSeverity)
        local severityImpact = (_G.GetDetectionSeverity and _G.GetDetectionSeverity(detectionType)) or 20
        metrics.trustScore = math.max(0, (metrics.trustScore or 100) - severityImpact)
        print('^3[NexusGuard]^7 Player ' .. playerName .. ' trust score updated to: ' .. metrics.trustScore)
    else
        Log("^1Warning: PlayerMetrics table not found for player " .. playerId .. " during detection processing.^7", 1)
    end

    -- AI-based detection analysis (Uses global AI functions - PLACEHOLDERS)
    if Config and Config.AI and Config.AI.enabled then
        if _G.ProcessAIVerification then
            local aiVerdict = _G.ProcessAIVerification(playerId, detectionType, detectionData)
            print('^3[NexusGuard]^7 AI Verdict: ', json.encode(aiVerdict)) -- Log AI verdict for debugging
            if aiVerdict and aiVerdict.confidence > (Config.Thresholds.aiDecisionConfidenceThreshold or 0.75) then
                if aiVerdict.action == 'ban' then
                    if _G.BanPlayer then _G.BanPlayer(playerId, 'AI-confirmed cheat: ' .. detectionType) end
                    return -- Stop further processing if banned by AI
                elseif aiVerdict.action == 'kick' then
                    DropPlayer(playerId, Config.KickMessage or "Kicked by Anti-Cheat.")
                    return -- Stop further processing if kicked by AI
                end
            end
        else
             print("^1[NexusGuard] AI enabled but ProcessAIVerification function not found!^7")
        end
    end

    -- Rule-based detection handling
    if Config and Config.Actions then
        -- Handle detection based on configuration (Uses global helper functions)
        local confirmed = _G.IsConfirmedCheat and _G.IsConfirmedCheat(detectionType, detectionData)
        local highRisk = _G.IsHighRiskDetection and _G.IsHighRiskDetection(detectionType, detectionData)

        if Config.Actions.banOnConfirmed and confirmed then
            if _G.BanPlayer then _G.BanPlayer(playerId, 'Confirmed cheat: ' .. detectionType) end
            return -- Stop further processing if banned
        elseif Config.Actions.kickOnSuspicion and highRisk then
             DropPlayer(playerId, Config.KickMessage or "Kicked for suspicious activity.")
             -- Optionally trigger screenshot before kick
             if Config.ScreenCapture and Config.ScreenCapture.enabled and Config.ScreenCapture.includeWithReports then
                 if _G.EventRegistry then _G.EventRegistry.TriggerClientEvent('ADMIN_REQUEST_SCREENSHOT', playerId) end
             end
             return -- Stop further processing if kicked
        elseif Config.ScreenCapture and Config.ScreenCapture.enabled and Config.ScreenCapture.includeWithReports and (highRisk or confirmed) then
            -- Trigger screenshot for high risk or confirmed cheats if not already kicked/banned
             if _G.EventRegistry then _G.EventRegistry.TriggerClientEvent('ADMIN_REQUEST_SCREENSHOT', playerId) end
        end

        -- Notify admins (Uses local NotifyAdmins function)
        if Config.Actions.reportToAdminsOnSuspicion then
            NotifyAdmins(playerId, detectionType, detectionData)
        end
    end

    -- Log to Discord (Uses global SendToDiscord)
    if Config and Config.EnableDiscordLogs and _G.SendToDiscord then
        _G.SendToDiscord('Detection Alert', playerName .. ' (ID: '..playerId..') - Type: ' .. detectionType .. ' - Data: ' .. (json.encode(detectionData) or "{}"))
    end
end


-- Scheduled Tasks
function SetupScheduledTasks()
    -- Player metrics collection thread (Uses global functions)
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(60000) -- Once per minute
            if _G.CollectPlayerMetrics then _G.CollectPlayerMetrics() end
            if _G.CleanupDetectionHistory then _G.CleanupDetectionHistory() end
        end
    end)

    -- AI model update thread (if enabled) (Uses global function)
    if Config and Config.AI and Config.AI.enabled then
        Citizen.CreateThread(function()
            while true do
                Citizen.Wait(86400000) -- Daily updates
                if _G.UpdateAIModels then _G.UpdateAIModels() end
            end
        end)
    end
end


-- Send notification to online admins
function NotifyAdmins(playerId, detectionType, detectionData)
    local playerName = GetPlayerName(playerId) or "Unknown"
    -- Ensure JSON library is available
    if not json then print("^1[NexusGuard] JSON library not available for NotifyAdmins.^7") return end

    local dataString = "N/A"
    local successEncode, result = pcall(json.encode, detectionData)
    if successEncode then dataString = result else print("^1[NexusGuard] Failed to encode detectionData for admin notification.^7") end

    -- Send to all online admins stored in our list
    for adminId, _ in pairs(OnlineAdmins) do
        -- Ensure the admin player still exists before sending
        if GetPlayerName(adminId) then
             if _G.EventRegistry then
                 _G.EventRegistry.TriggerClientEvent('ADMIN_NOTIFICATION', adminId, {
                    player = playerName,
                    playerId = playerId, -- Send player ID as well
                    type = detectionType,
                    data = detectionData, -- Send original data table
                    timestamp = os.time()
                 })
             else
                TriggerClientEvent('nexusguard:adminNotification', adminId, { -- Fallback
                    player = playerName,
                    playerId = playerId,
                    type = detectionType,
                    data = detectionData,
                    timestamp = os.time()
                })
             end
        end
    end
    -- Also log it to server console for visibility
    print('^1[NexusGuard]^7 Admin Notify: ' .. playerName .. ' (ID: ' .. playerId .. ') - ' .. detectionType .. ' - Data: ' .. dataString)
end

-- Note: Functions like BanPlayer, InitializeAIModels, ProcessAIVerification etc. are expected
-- to be defined globally (likely in globals.lua) and are marked as placeholders there.
