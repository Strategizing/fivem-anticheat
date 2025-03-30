-- Ensure JSON library is available (e.g., from oxmysql or another resource)
local json = json or _G.json

-- Register built-in events
RegisterNetEvent('onResourceStart')
AddEventHandler('playerConnecting', function(playerName, setKickReason, deferrals) OnPlayerConnecting(playerName, setKickReason, deferrals) end) -- Pass args explicitly
AddEventHandler('playerDropped', function(reason) OnPlayerDropped(reason) end) -- Pass args explicitly
AddEventHandler('explosionEvent', function(sender, ev) HandleExplosionEvent(sender, ev) end) -- Pass args explicitly
-- AddEventHandler('entityCreated', function(entity) HandleEntityCreation(entity) end) -- Commented out: HandleEntityCreation is only a placeholder in globals.lua

-- Local tables
local ClientsLoaded = {} -- Tracks clients that have completed the initial hash check
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

    print('^2[NexusGuard]^7 Initializing NexusGuard Anti-Cheat System (Server)...')

    -- Ensure required globals from globals.lua are present
    if not _G.Log then _G.Log = function(msg, lvl) print(msg) end; print("^1[NexusGuard] CRITICAL: _G.Log function not found! Using basic print.^7") end
    if not _G.PlayerMetrics then _G.PlayerMetrics = {}; Log("^1[NexusGuard] CRITICAL: _G.PlayerMetrics table not found! Initializing empty.^7", 1) end
    if not _G.IsPlayerAdmin then Log("^1[NexusGuard] CRITICAL: _G.IsPlayerAdmin function not found! Admin checks will fail.^7", 1) end
    if not _G.ValidateSecurityToken then Log("^1[NexusGuard] CRITICAL: _G.ValidateSecurityToken function not found! Security checks will fail.^7", 1) end
    if not _G.GenerateSecurityToken then Log("^1[NexusGuard] CRITICAL: _G.GenerateSecurityToken function not found! Security checks will fail.^7", 1) end
    if not _G.BanPlayer then Log("^1[NexusGuard] CRITICAL: _G.BanPlayer function not found! Ban actions will fail.^7", 1) end
    if not _G.IsPlayerBanned then Log("^1[NexusGuard] CRITICAL: _G.IsPlayerBanned function not found! Ban checks will fail.^7", 1) end
    if not _G.LoadBanList then Log("^1[NexusGuard] CRITICAL: _G.LoadBanList function not found! Ban list will not load.^7", 1) end
    if not _G.StoreDetection then Log("^3[NexusGuard] Warning: _G.StoreDetection function not found. Detections will not be stored.^7", 2) end
    if not _G.SavePlayerMetrics then Log("^3[NexusGuard] Warning: _G.SavePlayerMetrics function not found. Session metrics will not be saved.^7", 2) end

    -- Validate Config structure
    ValidateConfig()

    -- Load initial ban list (if function exists)
    if _G.LoadBanList then _G.LoadBanList(true) end -- Force load on start

    -- Initialize AI (if function exists and enabled)
    if Config.AI and Config.AI.enabled then
        if _G.InitializeAIModels then _G.InitializeAIModels()
        else Log("^1[NexusGuard] AI is enabled in config, but _G.InitializeAIModels function not found! AI features inactive.^7", 1) end
    end

    -- Setup local scheduled tasks
    SetupScheduledTasks()

    -- Register server events using EventRegistry if available
    if _G.EventRegistry then
        RegisterNexusGuardServerEvents()
        Log("^2[NexusGuard]^7 Server event handlers registered via EventRegistry.^7", 2)
    else
        Log("^1[NexusGuard] CRITICAL: _G.EventRegistry not found! Cannot register server event handlers. NexusGuard will not function.^7", 1)
        -- Optionally register fallback handlers here if needed, but core functionality relies on EventRegistry
    end

    Log("^2[NexusGuard]^7 Server initialization sequence complete.^7", 2)
end)

-- Player connected handler
function OnPlayerConnecting(playerName, setKickReason, deferrals)
    local source = source -- Capture source from the event context (this is how FiveM events work)
    if not source or source <= 0 then
        Log("^1[NexusGuard] Invalid source in OnPlayerConnecting. Aborting.^7", 1)
        deferrals.done("Anti-Cheat Error: Invalid connection source.")
        return
    end

    deferrals.defer()
    Citizen.Wait(10) -- Minimal wait
    deferrals.update('Checking your profile against our security database...')

    -- Fetch identifiers safely
    local license = GetPlayerIdentifierByType(source, 'license')
    local ip = GetPlayerEndpoint(source)
    local discord = GetPlayerIdentifierByType(source, 'discord') -- Get discord ID too

    -- Check if player is banned (Use global IsPlayerBanned)
    Citizen.Wait(200) -- Allow some time for ban list loading/cache
    local banned, banReason = false, nil
    if _G.IsPlayerBanned then
        banned, banReason = _G.IsPlayerBanned(license, ip, discord) -- Check all identifiers
    else
        Log("^1[NexusGuard] IsPlayerBanned function missing, cannot check ban status for " .. playerName .. "^7", 1)
        -- Decide whether to allow connection if ban check fails. Defaulting to allow for now.
    end

    if banned then
        local banMsg = (Config.BanMessage or "You are banned.") .. " Reason: " .. (banReason or "N/A")
        deferrals.done(banMsg)
        Log("^1[NexusGuard] Connection Rejected: " .. playerName .. " (License: " .. (license or "N/A") .. ") is banned. Reason: " .. (banReason or "N/A") .. "^7", 1)
        -- Send Discord notification (Use global SendToDiscord)
        if _G.SendToDiscord then
            _G.SendToDiscord("Bans", 'Connection Rejected', playerName .. ' attempted to connect but is banned. Reason: ' .. (banReason or "N/A"), Config.Discord.webhooks and Config.Discord.webhooks.bans)
        end
        return
    end

    -- Check admin status (Use global IsPlayerAdmin)
    local isAdmin = (_G.IsPlayerAdmin and _G.IsPlayerAdmin(source)) or false

    -- Initialize player metrics (Use global PlayerMetrics table)
    _G.PlayerMetrics[source] = {
        connectTime = os.time(),
        playerName = playerName, -- Store name
        license = license,       -- Store license
        ip = ip,                 -- Store IP
        discord = discord,       -- Store Discord ID
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
        Log("^2[NexusGuard]^7 Admin connected: " .. playerName .. " (ID: " .. source .. ")", 2)
    end

    Log("^2[NexusGuard]^7 Player connected: " .. playerName .. " (ID: " .. source .. ", License: " .. (license or "N/A") .. ")", 2)
    deferrals.done()
end

-- Player disconnected handler
function OnPlayerDropped(reason)
    local source = source -- Capture source from the event context
    if not source or source <= 0 then return end -- Ignore invalid source

    local playerName = GetPlayerName(source) or "Unknown"
    local metrics = _G.PlayerMetrics and _G.PlayerMetrics[source]

    -- Save detection data to database if enabled and metrics exist
    if Config and Config.Database and Config.Database.enabled and metrics then
        if _G.SavePlayerMetrics then
            _G.SavePlayerMetrics(source)
        else
            Log("^1[NexusGuard] SavePlayerMetrics function missing, cannot save session for " .. playerName .. "^7", 1)
        end
    end

    -- Clean up player data
    if metrics and metrics.isAdmin then
        OnlineAdmins[source] = nil -- Remove from admin list
        Log("^2[NexusGuard]^7 Admin disconnected: " .. playerName .. " (ID: " .. source .. ") Reason: " .. reason .. "^7", 2)
    else
        Log("^2[NexusGuard]^7 Player disconnected: " .. playerName .. " (ID: " .. source .. ") Reason: " .. reason .. "^7", 2)
    end

    -- Always remove from metrics and loaded clients
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
        local source = source -- Capture source from event context
        if not source or source <= 0 then return end -- Ignore invalid source
        local playerName = GetPlayerName(source) or "Unknown (" .. source .. ")"

        -- Validate client hash (Uses global ValidateClientHash - INSECURE PLACEHOLDER)
        -- Note: This check provides minimal security.
        if _G.ValidateClientHash and _G.ValidateClientHash(clientHash) then
            ClientsLoaded[source] = true -- Mark client as having passed initial check
            -- Generate token (Uses global GenerateSecurityToken - INSECURE PLACEHOLDER)
            local token = _G.GenerateSecurityToken and _G.GenerateSecurityToken(source)
            if token then
                _G.EventRegistry.TriggerClientEvent('SECURITY_RECEIVE_TOKEN', source, token)
                Log('^2[NexusGuard]^7 Security token sent to ' .. playerName .. ' via ' .. _G.EventRegistry.GetEventName('SECURITY_REQUEST_TOKEN') .. "^7", 2)
            else
                 Log('^1[NexusGuard]^7 Failed to generate security token for ' .. playerName .. ". Kicking.^7", 1)
                 DropPlayer(source, "Anti-Cheat initialization failed (Token Generation).")
            end
        else
            Log('^1[NexusGuard]^7 Invalid client hash received from ' .. playerName .. '. Kicking.^7', 1)
            -- Ban or kick player for potentially modified client (Use global BanPlayer)
            if _G.BanPlayer then _G.BanPlayer(source, 'Modified client detected (Invalid Hash)')
            else DropPlayer(source, "Anti-Cheat validation failed (Client Hash).") end
        end
    end)

    -- Detection Report Handler
    _G.EventRegistry.AddEventHandler('DETECTION_REPORT', function(detectionType, detectionData, securityToken)
        local source = source -- Capture source from event context
        if not source or source <= 0 then return end -- Ignore invalid source
        local playerName = GetPlayerName(source) or "Unknown (" .. source .. ")"

        -- Validate security token (Uses global ValidateSecurityToken - INSECURE PLACEHOLDER)
        if not _G.ValidateSecurityToken or not _G.ValidateSecurityToken(source, securityToken) then
            Log("^1[NexusGuard] Invalid security token received with detection report from " .. playerName .. ". Banning.^7", 1)
            if _G.BanPlayer then _G.BanPlayer(source, 'Invalid security token with detection report')
            else DropPlayer(source, "Anti-Cheat validation failed (Invalid Detection Token).") end
            return
        end

        -- Process the detection (Use global ProcessDetection)
        if _G.ProcessDetection then
            _G.ProcessDetection(source, detectionType, detectionData)
        else
             Log("^1[NexusGuard] CRITICAL: ProcessDetection function not found! Cannot process detection from " .. playerName .. "^7", 1)
        end
    end)

    -- Resource Verification Handler
    _G.EventRegistry.AddEventHandler('SYSTEM_RESOURCE_CHECK', function(resources, securityToken)
        local source = source -- Capture source from event context
        if not source or source <= 0 then return end -- Ignore invalid source
        local playerName = GetPlayerName(source) or "Unknown (" .. source .. ")"

        -- Validate security token (Uses global ValidateSecurityToken - INSECURE PLACEHOLDER)
        if not _G.ValidateSecurityToken or not _G.ValidateSecurityToken(source, securityToken) then
            Log("^1[NexusGuard] Invalid security token received with resource check from " .. playerName .. ". Banning.^7", 1)
            if _G.BanPlayer then _G.BanPlayer(source, 'Invalid security token during resource check')
            else DropPlayer(source, "Anti-Cheat validation failed (Resource Check Token).") end
            return
        end

        -- Ensure resources is a table
        if type(resources) ~= "table" then
            Log("^1[NexusGuard] Invalid resource list format received from " .. playerName .. ". Kicking.^7", 1)
            DropPlayer(source, "Anti-Cheat validation failed (Invalid Resource List).")
            return
        end

        Log('^3[NexusGuard]^7 Received resource list from ' .. playerName .. ' (' .. #resources .. ' resources) via ' .. _G.EventRegistry.GetEventName('SYSTEM_RESOURCE_CHECK') .. "^7", 3)

        -- Resource Verification Logic
        local rvConfig = Config and Config.Features and Config.Features.resourceVerification
        if rvConfig and rvConfig.enabled then
            Log("^3[NexusGuard] Performing resource verification for " .. playerName .. "...^7", 3)
            local MismatchedResources = {}

            --[[
                IMPLEMENTATION REQUIRED: Resource Verification Logic
                ----------------------------------------------------
                This placeholder needs to be replaced with actual logic to compare
                the client's 'resources' list against the configured whitelist or blacklist.
                Remember to handle potential errors and edge cases.
            ]]
            Log("^1[NexusGuard] WARNING: Resource verification is enabled but the core logic in server_main.lua (SYSTEM_RESOURCE_CHECK handler) is NOT IMPLEMENTED. This check will currently do nothing.^7", 1)
            -- Example structure (needs implementation):
            -- local listToCheck, mode = {}, rvConfig.mode
            -- if mode == "whitelist" then listToCheck = rvConfig.whitelist or {} -- Build set for efficiency
            -- elseif mode == "blacklist" then listToCheck = rvConfig.blacklist or {} -- Build set for efficiency
            -- end
            -- -- Compare 'resources' against 'listToCheck' based on 'mode'
            -- -- Populate MismatchedResources table if discrepancies found
            -- if #MismatchedResources > 0 then
            --     local reason = "Unauthorized resources detected: " .. table.concat(MismatchedResources, ", ")
            --     Log("^1[NexusGuard] " .. playerName .. " - " .. reason .. "^7", 1)
            --     if _G.SendToDiscord then _G.SendToDiscord("general", "Resource Mismatch", playerName .. " - " .. reason, Config.Discord.webhooks and Config.Discord.webhooks.general) end
            --     if rvConfig.banOnMismatch then
            --         if _G.BanPlayer then _G.BanPlayer(source, reason) end
            --     elseif rvConfig.kickOnMismatch then
            --         DropPlayer(source, "Kicked due to unauthorized resources.")
            --     end
            --     if _G.ProcessDetection then _G.ProcessDetection(source, "ResourceMismatch", {mismatched = MismatchedResources}) end
            -- else
            --     Log("^2[NexusGuard] Resource check passed for " .. playerName .. "^7", 2)
            -- end
        else
             Log("^3[NexusGuard] Resource verification is disabled in config.^7", 3)
        end
    end)

    -- Client Error Handler
    _G.EventRegistry.AddEventHandler('SYSTEM_ERROR', function(detectionName, errorMessage, securityToken)
        local source = source -- Capture source from event context
        if not source or source <= 0 then return end -- Ignore invalid source
        local playerName = GetPlayerName(source) or "Unknown (" .. source .. ")"

        -- Validate security token (Uses global ValidateSecurityToken - INSECURE PLACEHOLDER)
        if not _G.ValidateSecurityToken or not _G.ValidateSecurityToken(source, securityToken) then
            Log("^1[NexusGuard]^7 Invalid security token in error report from " .. playerName .. ". Ignoring report.^7", 1)
            return -- Don't process errors with invalid tokens
        end

        Log("^3[NexusGuard]^7 Client error reported by " .. playerName .. " in module '" .. detectionName .. "': " .. errorMessage .. "^7", 2)

        -- Log the error to Discord (Use global SendToDiscord)
        if Config and Config.Discord and Config.Discord.enabled and _G.SendToDiscord then
            _G.SendToDiscord("general", 'Client Error Report',
                "Player: " .. playerName .. " (ID: " .. source .. ")\n" ..
                "Module: " .. detectionName .. "\n" ..
                "Error: " .. errorMessage,
                Config.Discord.webhooks and Config.Discord.webhooks.general
            )
        end

        -- Track client errors in player metrics (Use global PlayerMetrics table)
        if _G.PlayerMetrics and _G.PlayerMetrics[source] then
            local metrics = _G.PlayerMetrics[source]
            if not metrics.clientErrors then metrics.clientErrors = {} end
            table.insert(metrics.clientErrors, {
                detection = detectionName,
                error = errorMessage,
                time = os.time()
            })
        end
    end)

     -- Screenshot Taken Handler
     _G.EventRegistry.AddEventHandler('ADMIN_SCREENSHOT_TAKEN', function(screenshotUrl, securityToken)
        local source = source -- Capture source from event context
        if not source or source <= 0 then return end -- Ignore invalid source
        local playerName = GetPlayerName(source) or "Unknown (" .. source .. ")"

        -- Validate security token (Uses global ValidateSecurityToken - INSECURE PLACEHOLDER)
        if not _G.ValidateSecurityToken or not _G.ValidateSecurityToken(source, securityToken) then
             Log("^1[NexusGuard] Invalid security token received with screenshot from " .. playerName .. ". Banning.^7", 1)
             if _G.BanPlayer then _G.BanPlayer(source, 'Invalid security token with screenshot')
             else DropPlayer(source, "Anti-Cheat validation failed (Screenshot Token).") end
            return
        end

        Log("^2[NexusGuard]^7 Received screenshot from " .. playerName .. ": " .. screenshotUrl .. "^7", 2)
        -- Log to Discord or notify admins (Use global SendToDiscord)
        if Config and Config.Discord and Config.Discord.enabled and _G.SendToDiscord then
            _G.SendToDiscord("general", 'Screenshot Taken', "Player: " .. playerName .. " (ID: " .. source .. ")\nURL: " .. screenshotUrl, Config.Discord.webhooks and Config.Discord.webhooks.general)
        end
        -- Notify relevant admins if needed (e.g., the one who requested it, if tracked)
        -- NotifyAdmins(source, "ScreenshotTaken", {url = screenshotUrl}) -- Example
    end)

    Log("^2[NexusGuard] Standardized server event handlers registration complete.^7", 2)
end


-- Process Detection Logic (Relies on global functions from globals.lua)
-- This function coordinates the response to a detection event.
function ProcessDetection(playerId, detectionType, detectionData)
    -- Check for valid input
    if not playerId or playerId <= 0 or not detectionType then
        Log("^1[NexusGuard] Invalid arguments received by ProcessDetection.^7", 1)
        return
    end
    local playerName = GetPlayerName(playerId) or "Unknown (" .. playerId .. ")"

    Log('^1[NexusGuard]^7 Detection: ' .. playerName .. ' (ID: '..playerId..') - Type: ' .. detectionType .. "^7", 1)

    -- Store detection in database if enabled (Use global StoreDetection)
    if Config.Database and Config.Database.enabled and Config.Database.storeDetectionHistory then
        if _G.StoreDetection then _G.StoreDetection(playerId, detectionType, detectionData)
        else Log("^1[NexusGuard] StoreDetection function missing, cannot store detection.^7", 1) end
    end

    -- Record detection in player's history (Use global PlayerMetrics table)
    if _G.PlayerMetrics and _G.PlayerMetrics[playerId] then
        local metrics = _G.PlayerMetrics[playerId]
        if not metrics.detections then metrics.detections = {} end
        table.insert(metrics.detections, {
            type = detectionType,
            data = detectionData,
            type = detectionType,
            data = detectionData,
            timestamp = os.time()
        })

        -- Update trust score based on detection severity (Use global GetDetectionSeverity)
        local severityImpact = (_G.GetDetectionSeverity and _G.GetDetectionSeverity(detectionType)) or 20
        metrics.trustScore = math.max(0, (metrics.trustScore or 100) - severityImpact)
        Log('^3[NexusGuard]^7 Player ' .. playerName .. ' trust score updated to: ' .. string.format("%.2f", metrics.trustScore) .. "^7", 2)
    else
        Log("^1Warning: PlayerMetrics table not found for player " .. playerId .. " during detection processing.^7", 1)
    end

    -- AI-based detection analysis (Use global AI functions - PLACEHOLDERS)
    if Config.AI and Config.AI.enabled then
        if _G.ProcessAIVerification then
            local aiVerdict = _G.ProcessAIVerification(playerId, detectionType, detectionData)
            if aiVerdict then -- Ensure verdict is not nil
                Log('^3[NexusGuard]^7 AI Verdict: ' .. (json and json.encode(aiVerdict) or "Error encoding verdict") .. "^7", 3) -- Log AI verdict
                if aiVerdict.confidence and aiVerdict.confidence > (Config.Thresholds.aiDecisionConfidenceThreshold or 0.75) then
                    if aiVerdict.action == 'ban' then
                        Log("^1[NexusGuard] AI Ban Triggered for " .. playerName .. " (Type: " .. detectionType .. ", Confidence: " .. aiVerdict.confidence .. ")^7", 1)
                        if _G.BanPlayer then _G.BanPlayer(playerId, 'AI-confirmed cheat: ' .. detectionType) end
                        return -- Stop further processing if banned by AI
                    elseif aiVerdict.action == 'kick' then
                        Log("^1[NexusGuard] AI Kick Triggered for " .. playerName .. " (Type: " .. detectionType .. ", Confidence: " .. aiVerdict.confidence .. ")^7", 1)
                        DropPlayer(playerId, Config.KickMessage or "Kicked by Anti-Cheat (AI).")
                        return -- Stop further processing if kicked by AI
                    end
                end
            else
                 Log("^1[NexusGuard] AI verification process returned nil verdict for " .. playerName .. "^7", 1)
            end
        else
             Log("^1[NexusGuard] AI enabled but ProcessAIVerification function not found! Cannot perform AI analysis.^7", 1)
        end
    end

    -- Rule-based detection handling
    if Config.Actions then
        -- Handle detection based on configuration (Use global helper functions)
        local confirmed = (_G.IsConfirmedCheat and _G.IsConfirmedCheat(detectionType, detectionData)) or false
        local highRisk = (_G.IsHighRiskDetection and _G.IsHighRiskDetection(detectionType, detectionData)) or false

        if Config.Actions.banOnConfirmed and confirmed then
            Log("^1[NexusGuard] Confirmed Cheat Ban Triggered for " .. playerName .. " (Type: " .. detectionType .. ")^7", 1)
            if _G.BanPlayer then _G.BanPlayer(playerId, 'Confirmed cheat: ' .. detectionType) end
            return -- Stop further processing if banned
        elseif Config.Actions.kickOnSuspicion and highRisk then
             Log("^1[NexusGuard] High Risk Kick Triggered for " .. playerName .. " (Type: " .. detectionType .. ")^7", 1)
             -- Optionally trigger screenshot before kick
             if Config.ScreenCapture and Config.ScreenCapture.enabled and Config.ScreenCapture.includeWithReports then
                 if _G.EventRegistry then _G.EventRegistry.TriggerClientEvent('ADMIN_REQUEST_SCREENSHOT', playerId) end
             end
             DropPlayer(playerId, Config.KickMessage or "Kicked for suspicious activity.")
             return -- Stop further processing if kicked
        elseif Config.ScreenCapture and Config.ScreenCapture.enabled and Config.ScreenCapture.includeWithReports and (highRisk or confirmed) then
            -- Trigger screenshot for high risk or confirmed cheats if not already kicked/banned
             Log("^2[NexusGuard] Requesting screenshot for high risk/confirmed detection: " .. playerName .. " (Type: " .. detectionType .. ")^7", 2)
             if _G.EventRegistry then _G.EventRegistry.TriggerClientEvent('ADMIN_REQUEST_SCREENSHOT', playerId) end
        end

        -- Notify admins (Use local NotifyAdmins function)
        if Config.Actions.reportToAdminsOnSuspicion then
            NotifyAdmins(playerId, detectionType, detectionData)
        end
    end

    -- Log to Discord (Use global SendToDiscord)
    if Config.Discord and Config.Discord.enabled and _G.SendToDiscord then
        local dataStr = (json and json.encode(detectionData)) or "{}"
        _G.SendToDiscord("general", 'Detection Alert', playerName .. ' (ID: '..playerId..') - Type: ' .. detectionType .. ' - Data: ' .. dataStr, Config.Discord.webhooks and Config.Discord.webhooks.general)
    end
end
-- Expose ProcessDetection globally AFTER it's defined
_G.ProcessDetection = ProcessDetection


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
    local playerName = GetPlayerName(playerId) or "Unknown (" .. playerId .. ")"
    -- Ensure JSON library is available
    if not json then Log("^1[NexusGuard] JSON library not available for NotifyAdmins.^7", 1); return end

    local dataString = "N/A"
    local successEncode, result = pcall(json.encode, detectionData)
    if successEncode then dataString = result else Log("^1[NexusGuard] Failed to encode detectionData for admin notification.^7", 1) end

    -- Log to server console first
    Log('^1[NexusGuard]^7 Admin Notify: ' .. playerName .. ' (ID: ' .. playerId .. ') - ' .. detectionType .. ' - Data: ' .. dataString .. "^7", 1)

    -- Check if there are any admins online
    local adminCount = 0
    for _ in pairs(OnlineAdmins) do adminCount = adminCount + 1 end
    if adminCount == 0 then
        Log("^3[NexusGuard] No admins online to notify.^7", 3)
        return
    end

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
                -- Fallback if EventRegistry failed (though unlikely if we got this far)
                TriggerClientEvent('nexusguard:adminNotification', adminId, {
                    player = playerName,
                    playerId = playerId,
                    type = detectionType,
                    data = detectionData,
                    timestamp = os.time()
                })
             end
        else
            -- Admin might have disconnected between checks, remove them
            OnlineAdmins[adminId] = nil
            Log("^3[NexusGuard] Removed disconnected admin ID " .. adminId .. " from notification list.^7", 3)
        end
    end
end

-- Note: Functions like InitializeAIModels, ProcessAIVerification etc. are expected
-- to be defined globally (likely in globals.lua) and are marked as placeholders there.
