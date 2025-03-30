-- Get the NexusGuard Server API from globals.lua
local NexusGuardServer = exports['NexusGuard']:GetNexusGuardServerAPI()
if not NexusGuardServer then
    print("^1[NexusGuard] CRITICAL: Failed to get NexusGuardServer API from globals.lua. Resource may not function correctly.^7")
    -- Optionally add fallback logic or stop the resource here
    return
end

-- Local alias for logging for convenience in this file
local Log = NexusGuardServer.Utils.Log

-- Register built-in events
RegisterNetEvent('onResourceStart')
AddEventHandler('playerConnecting', function(playerName, setKickReason, deferrals) OnPlayerConnecting(playerName, setKickReason, deferrals) end) -- Pass args explicitly
AddEventHandler('playerDropped', function(reason) OnPlayerDropped(reason) end) -- Pass args explicitly
AddEventHandler('explosionEvent', function(sender, ev) NexusGuardServer.EventHandlers.HandleExplosion(sender, ev) end) -- Use API
-- AddEventHandler('entityCreated', ...) -- Placeholder removed

-- Local tables
local ClientsLoaded = {} -- Tracks clients that have completed the initial hash check
local OnlineAdmins = {} -- Table to store server IDs of online admins
_G.OnlineAdmins = OnlineAdmins -- TEMPORARY: Expose globally until PlayerMetrics/Notifications are fully refactored

-- Player session manager
local PlayerSessionManager = {}

PlayerSessionManager.sessions = {}

PlayerSessionManager.GetSession = function(playerId)
    if not PlayerSessionManager.sessions[playerId] then
        PlayerSessionManager.sessions[playerId] = {
            metrics = {},
            -- ...other session data...
        }
    end
    return PlayerSessionManager.sessions[playerId]
end

AddEventHandler("playerDropped", function()
    local playerId = source
    PlayerSessionManager.sessions[playerId] = nil
end)

-- Initialize the anti-cheat on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Ensure API loaded correctly
    if not NexusGuardServer or not NexusGuardServer.Utils or not NexusGuardServer.Utils.Log then
        print("^1[NexusGuard] CRITICAL: NexusGuardServer API or required modules not loaded correctly during onResourceStart.^7")
        return
    end
    Log('^2[NexusGuard]^7 Initializing NexusGuard Anti-Cheat System (Server)...', 2)

    -- Dependency Checks
    if not MySQL then
        Log("^1[NexusGuard] CRITICAL: MySQL object not found. Ensure 'oxmysql' is started BEFORE NexusGuard. Disabling database features.^7", 1)
        if NexusGuardServer.Config.Database then NexusGuardServer.Config.Database.enabled = false end
    end
    if not lib or not lib.crypto or not lib.crypto.hmac then
         Log("^1[NexusGuard] CRITICAL: ox_lib crypto functions not found (lib.crypto.hmac). Ensure 'ox_lib' is started BEFORE NexusGuard and is up-to-date. Security token system disabled.^7", 1)
         -- Consider halting resource start if security is critical
         -- return -- Uncomment to stop resource if ox_lib crypto is missing
    end

    -- Removed the block checking for individual _G.* functions as we now use the API table

    -- Basic Config Check (Ensure Config table exists - still needed as Config is loaded separately)
    NexusGuardServer.Config = _G.Config or {} -- Ensure API table has config reference
    Log("^2[NexusGuard]^7 Basic configuration table check complete. Ensure values are set correctly in config.lua.^7", 2)

    -- Load initial ban list using API
    if NexusGuardServer.Bans and NexusGuardServer.Bans.LoadList then
        NexusGuardServer.Bans.LoadList(true) -- Force load on start
    else
        Log("^1[NexusGuard] CRITICAL: Ban list functions not found in API! Ban checks will fail.^7", 1)
    end

    -- Initialize AI (if function exists and enabled) using API
    -- AI Placeholder Removed
    -- if NexusGuardServer.Config.AI and NexusGuardServer.Config.AI.enabled then
    --     if NexusGuardServer.AI and NexusGuardServer.AI.UpdateModels then -- Assuming UpdateModels is the init/update func now
    --         NexusGuardServer.AI.UpdateModels()
    --     else
    --         Log("^1[NexusGuard] AI is enabled in config, but AI module or UpdateModels function not found in API! AI features inactive.^7", 1)
    --     end
    -- end

    -- Setup local scheduled tasks
    SetupScheduledTasks() -- This function remains local to server_main.lua

    -- Register server events using EventRegistry if available
    if _G.EventRegistry then -- EventRegistry is likely still global or needs its own refactor
        RegisterNexusGuardServerEvents() -- This function remains local to server_main.lua
        Log("^2[NexusGuard]^7 Server event handlers registered via EventRegistry.^7", 2)
    else
        Log("^1[NexusGuard] CRITICAL: _G.EventRegistry not found! Cannot register server event handlers. NexusGuard will not function.^7", 1)
    end

    Log("^2[NexusGuard]^7 Server initialization sequence complete.^7", 2)
end)

-- Player connected handler
function OnPlayerConnecting(playerName, setKickReason, deferrals)
    local source = source -- Capture source from the event context
    if not source or source <= 0 then Log("^1[NexusGuard] Invalid source in OnPlayerConnecting. Aborting.^7", 1); deferrals.done("Anti-Cheat Error: Invalid connection source."); return end

    deferrals.defer()
    Citizen.Wait(10)
    deferrals.update('Checking your profile against our security database...')

    local license = GetPlayerIdentifierByType(source, 'license')
    local ip = GetPlayerEndpoint(source)
    local discord = GetPlayerIdentifierByType(source, 'discord')

    -- Check if player is banned using API
    Citizen.Wait(200)
    local banned, banReason = false, nil
    if NexusGuardServer.Bans and NexusGuardServer.Bans.IsPlayerBanned then
        banned, banReason = NexusGuardServer.Bans.IsPlayerBanned(license, ip, discord)
    else
        Log("^1[NexusGuard] IsPlayerBanned function missing from API, cannot check ban status for " .. playerName .. "^7", 1)
    end

    if banned then
        local banMsg = (NexusGuardServer.Config.BanMessage or "You are banned.") .. " Reason: " .. (banReason or "N/A")
        deferrals.done(banMsg)
        Log("^1[NexusGuard] Connection Rejected: " .. playerName .. " (License: " .. (license or "N/A") .. ") is banned. Reason: " .. (banReason or "N/A") .. "^7", 1)
        if NexusGuardServer.Discord and NexusGuardServer.Discord.Send then
            NexusGuardServer.Discord.Send("Bans", 'Connection Rejected', playerName .. ' attempted to connect but is banned. Reason: ' .. (banReason or "N/A"), NexusGuardServer.Config.Discord.webhooks and NexusGuardServer.Config.Discord.webhooks.bans)
        end
        return
    end

    -- Check admin status using API
    local isAdmin = (NexusGuardServer.Permissions and NexusGuardServer.Permissions.IsAdmin and NexusGuardServer.Permissions.IsAdmin(source)) or false

    -- Initialize player metrics using PlayerSessionManager
    local session = PlayerSessionManager.GetSession(source)
    session.metrics = {
        connectTime = os.time(), playerName = playerName, license = license, ip = ip, discord = discord,
        lastPosition = nil, warningCount = 0, detections = {}, healthHistory = {}, movementSamples = {},
        weaponStats = {}, behaviorProfile = {}, trustScore = 100.0, securityToken = nil,
        lastServerPosition = nil, lastServerPositionTimestamp = nil, lastServerHealth = nil,
        lastServerArmor = nil, lastServerHealthTimestamp = nil, explosions = {}, entities = {},
        isAdmin = isAdmin
    }

    if isAdmin then
        OnlineAdmins[source] = true -- Use local table, exposed via _G temporarily
        Log("^2[NexusGuard]^7 Admin connected: " .. playerName .. " (ID: " .. source .. ")", 2)
    end

    Log("^2[NexusGuard]^7 Player connected: " .. playerName .. " (ID: " .. source .. ", License: " .. (license or "N/A") .. ")", 2)
    deferrals.done()
end

-- Player disconnected handler
function OnPlayerDropped(reason)
    local source = source -- Capture source from the event context
    if not source or source <= 0 then return end

    local playerName = GetPlayerName(source) or "Unknown"
    local session = PlayerSessionManager.GetSession(source)

    -- Save detection data to database if enabled and metrics exist, using API
    if NexusGuardServer.Config.Database and NexusGuardServer.Config.Database.enabled and session.metrics then
        if NexusGuardServer.Database and NexusGuardServer.Database.SavePlayerMetrics then
            NexusGuardServer.Database.SavePlayerMetrics(source)
        else
            Log("^1[NexusGuard] SavePlayerMetrics function missing from API, cannot save session for " .. playerName .. "^7", 1)
        end
    end

    -- Clean up player data
    if session.metrics.isAdmin then
        OnlineAdmins[source] = nil -- Use local table
        Log("^2[NexusGuard]^7 Admin disconnected: " .. playerName .. " (ID: " .. source .. ") Reason: " .. reason .. "^7", 2)
    else
        Log("^2[NexusGuard]^7 Player disconnected: " .. playerName .. " (ID: " .. source .. ") Reason: " .. reason .. "^7", 2)
    end

    PlayerSessionManager.sessions[source] = nil
    ClientsLoaded[source] = nil
end

-- Register server-side event handlers using EventRegistry
-- This function remains local, but calls API functions where appropriate
function RegisterNexusGuardServerEvents()
    if not _G.EventRegistry then Log("^1[NexusGuard] EventRegistry not found, cannot register standardized server events.^7", 1); return end

    -- Security Token Request Handler
    _G.EventRegistry.AddEventHandler('SECURITY_REQUEST_TOKEN', function(clientHash)
        local source = source; if not source or source <= 0 then return end
        local playerName = GetPlayerName(source) or "Unknown (" .. source .. ")"
        if clientHash and type(clientHash) == "string" then
            ClientsLoaded[source] = true
            local tokenData = NexusGuardServer.Security and NexusGuardServer.Security.GenerateToken and NexusGuardServer.Security.GenerateToken(source)
            if tokenData then
                _G.EventRegistry.TriggerClientEvent('SECURITY_RECEIVE_TOKEN', source, tokenData)
                Log('^2[NexusGuard]^7 Secure token sent to ' .. playerName .. ' via ' .. _G.EventRegistry.GetEventName('SECURITY_REQUEST_TOKEN') .. "^7", 2)
            else Log('^1[NexusGuard]^7 Failed to generate secure token for ' .. playerName .. ". Kicking.^7", 1); DropPlayer(source, "Anti-Cheat initialization failed (Token Generation).") end
        else
             Log('^1[NexusGuard]^7 Invalid or missing client hash received from ' .. playerName .. '. Kicking.^7', 1)
             if NexusGuardServer.Bans and NexusGuardServer.Bans.Execute then NexusGuardServer.Bans.Execute(source, 'Modified client detected (Invalid Handshake)')
             else DropPlayer(source, "Anti-Cheat validation failed (Client Handshake).") end
        end
    end)

    -- Detection Report Handler
    _G.EventRegistry.AddEventHandler('DETECTION_REPORT', function(detectionType, detectionData, tokenData)
        local source = source; if not source or source <= 0 then return end
        local playerName = GetPlayerName(source) or "Unknown (" .. source .. ")"
        if not NexusGuardServer.Security or not NexusGuardServer.Security.ValidateToken or not NexusGuardServer.Security.ValidateToken(source, tokenData) then
            Log("^1[NexusGuard] Invalid security token received with detection report from " .. playerName .. ". Banning.^7", 1)
            if NexusGuardServer.Bans and NexusGuardServer.Bans.Execute then NexusGuardServer.Bans.Execute(source, 'Invalid security token with detection report')
            else DropPlayer(source, "Anti-Cheat validation failed (Invalid Detection Token).") end
            return
        end
        if NexusGuardServer.Detections and NexusGuardServer.Detections.Process then NexusGuardServer.Detections.Process(source, detectionType, detectionData)
        else Log("^1[NexusGuard] CRITICAL: ProcessDetection function not found in API! Cannot process detection from " .. playerName .. "^7", 1) end
    end)

    -- Resource Verification Handler
    _G.EventRegistry.AddEventHandler('SYSTEM_RESOURCE_CHECK', function(resources, tokenData)
        local source = source; if not source or source <= 0 then return end
        local playerName = GetPlayerName(source) or "Unknown (" .. source .. ")"
        if not NexusGuardServer.Security or not NexusGuardServer.Security.ValidateToken or not NexusGuardServer.Security.ValidateToken(source, tokenData) then
            Log("^1[NexusGuard] Invalid security token received with resource check from " .. playerName .. ". Banning.^7", 1)
            if NexusGuardServer.Bans and NexusGuardServer.Bans.Execute then NexusGuardServer.Bans.Execute(source, 'Invalid security token during resource check')
            else DropPlayer(source, "Anti-Cheat validation failed (Resource Check Token).") end
            return
        end
        if type(resources) ~= "table" then Log("^1[NexusGuard] Invalid resource list format received from " .. playerName .. ". Kicking.^7", 1); DropPlayer(source, "Anti-Cheat validation failed (Invalid Resource List)."); return end

        Log('^3[NexusGuard]^7 Received resource list from ' .. playerName .. ' (' .. #resources .. ' resources) via ' .. _G.EventRegistry.GetEventName('SYSTEM_RESOURCE_CHECK') .. "^7", 3)
        local rvConfig = NexusGuardServer.Config and NexusGuardServer.Config.Features and NexusGuardServer.Config.Features.resourceVerification
        if rvConfig and rvConfig.enabled then
            Log("^3[NexusGuard] Performing resource verification for " .. playerName .. "...^7", 3)
            local MismatchedResources, listToCheck, clientResourcesSet = {}, {}, {}
            local checkMode = rvConfig.mode or "whitelist"
            for _, clientRes in ipairs(resources) do clientResourcesSet[clientRes] = true end
            if checkMode == "whitelist" then listToCheck = rvConfig.whitelist or {}
            elseif checkMode == "blacklist" then listToCheck = rvConfig.blacklist or {}
            else Log("^1[NexusGuard] Invalid resourceVerification mode: " .. checkMode .. ". Defaulting to 'whitelist'.^7", 1); checkMode = "whitelist"; listToCheck = rvConfig.whitelist or {} end
            local checkSet = {}; for _, resName in ipairs(listToCheck) do checkSet[resName] = true end

            if checkMode == "whitelist" then
                for clientRes, _ in pairs(clientResourcesSet) do if not checkSet[clientRes] then table.insert(MismatchedResources, clientRes .. " (Not Whitelisted)") end end
            elseif checkMode == "blacklist" then
                for clientRes, _ in pairs(clientResourcesSet) do if checkSet[clientRes] then table.insert(MismatchedResources, clientRes .. " (Blacklisted)") end end
            end

            if #MismatchedResources > 0 then
                local reason = "Unauthorized resources detected (" .. checkMode .. "): " .. table.concat(MismatchedResources, ", ")
                Log("^1[NexusGuard] Resource Mismatch for " .. playerName .. " (ID: " .. source .. "): " .. reason .. "^7", 1)
                if NexusGuardServer.Discord and NexusGuardServer.Discord.Send then NexusGuardServer.Discord.Send("general", "Resource Mismatch", playerName .. " (ID: " .. source .. ") - " .. reason, NexusGuardServer.Config.Discord.webhooks and NexusGuardServer.Config.Discord.webhooks.general) end
                if NexusGuardServer.Detections and NexusGuardServer.Detections.Process then NexusGuardServer.Detections.Process(source, "ResourceMismatch", { mismatched = MismatchedResources, mode = checkMode }) end
                if rvConfig.banOnMismatch then Log("^1[NexusGuard] Banning player " .. playerName .. " due to resource mismatch.^7", 1); if NexusGuardServer.Bans.Execute then NexusGuardServer.Bans.Execute(source, reason) end
                elseif rvConfig.kickOnMismatch then Log("^1[NexusGuard] Kicking player " .. playerName .. " due to resource mismatch.^7", 1); DropPlayer(source, "Kicked due to unauthorized resources.") end
            else Log("^2[NexusGuard] Resource check passed for " .. playerName .. " (ID: " .. source .. ")^7", 2) end
        else Log("^3[NexusGuard] Resource verification is disabled in config.^7", 3) end
    end)

    -- Client Error Handler
    _G.EventRegistry.AddEventHandler('SYSTEM_ERROR', function(detectionName, errorMessage, tokenData)
        local source = source; if not source or source <= 0 then return end
        local playerName = GetPlayerName(source) or "Unknown (" .. source .. ")"
        if not NexusGuardServer.Security or not NexusGuardServer.Security.ValidateToken or not NexusGuardServer.Security.ValidateToken(source, tokenData) then Log("^1[NexusGuard]^7 Invalid security token in error report from " .. playerName .. ". Ignoring report.^7", 1); return end
        Log("^3[NexusGuard]^7 Client error reported by " .. playerName .. " in module '" .. detectionName .. "': " .. errorMessage .. "^7", 2)
        if NexusGuardServer.Discord and NexusGuardServer.Discord.Send then NexusGuardServer.Discord.Send("general", 'Client Error Report', "Player: " .. playerName .. " (ID: " .. source .. ")\nModule: " .. detectionName .. "\nError: " .. errorMessage, NexusGuardServer.Config.Discord.webhooks and NexusGuardServer.Config.Discord.webhooks.general) end
        local session = PlayerSessionManager.GetSession(source)
        if session.metrics then
            if not session.metrics.clientErrors then session.metrics.clientErrors = {} end
            table.insert(session.metrics.clientErrors, { detection = detectionName, error = errorMessage, time = os.time() })
        end
    end)

     -- Screenshot Taken Handler
     _G.EventRegistry.AddEventHandler('ADMIN_SCREENSHOT_TAKEN', function(screenshotUrl, tokenData)
        local source = source; if not source or source <= 0 then return end
        local playerName = GetPlayerName(source) or "Unknown (" .. source .. ")"
        if not NexusGuardServer.Security or not NexusGuardServer.Security.ValidateToken or not NexusGuardServer.Security.ValidateToken(source, tokenData) then
             Log("^1[NexusGuard] Invalid security token received with screenshot from " .. playerName .. ". Banning.^7", 1)
             if NexusGuardServer.Bans.Execute then NexusGuardServer.Bans.Execute(source, 'Invalid security token with screenshot') else DropPlayer(source, "Anti-Cheat validation failed (Screenshot Token).") end
            return
        end
        Log("^2[NexusGuard]^7 Received screenshot from " .. playerName .. ": " .. screenshotUrl .. "^7", 2)
        if NexusGuardServer.Discord and NexusGuardServer.Discord.Send then NexusGuardServer.Discord.Send("general", 'Screenshot Taken', "Player: " .. playerName .. " (ID: " .. source .. ")\nURL: " .. screenshotUrl, NexusGuardServer.Config.Discord.webhooks and NexusGuardServer.Config.Discord.webhooks.general) end
        -- NotifyAdmins(source, "ScreenshotTaken", {url = screenshotUrl}) -- Example using API if NotifyAdmins is moved
    end)

    -- Position Update Handler
    _G.EventRegistry.AddEventHandler('NEXUSGUARD_POSITION_UPDATE', function(currentPos, clientTimestamp, tokenData)
        local source = source; if not source or source <= 0 then return end
        local playerName = GetPlayerName(source) or "Unknown (" .. source .. ")"
        if not NexusGuardServer.Security or not NexusGuardServer.Security.ValidateToken or not NexusGuardServer.Security.ValidateToken(source, tokenData) then Log("^1[NexusGuard] Invalid security token with position update from " .. playerName .. ". Banning.^7", 1); if NexusGuardServer.Bans.Execute then NexusGuardServer.Bans.Execute(source, 'Invalid security token with position update') else DropPlayer(source, "Anti-Cheat validation failed (Position Update Token).") end; return end
        local session = PlayerSessionManager.GetSession(source)
        if not session.metrics then Log("^1[NexusGuard] PlayerMetrics not found for " .. playerName .. " during position update.^7", 1); return end
        if type(currentPos) ~= "vector3" then Log("^1[NexusGuard] Invalid position data received from " .. playerName .. ". Kicking.^7", 1); DropPlayer(source, "Anti-Cheat validation failed (Invalid Position Data)."); return end

        local serverSpeedThreshold = (NexusGuardServer.Config.Thresholds and NexusGuardServer.Config.Thresholds.serverSideSpeedThreshold) or 50.0 -- Use new config value
        local minTimeDiff = 500
        if session.metrics.lastServerPosition and session.metrics.lastServerPositionTimestamp then
            local lastPos, lastTimestamp = session.metrics.lastServerPosition, session.metrics.lastServerPositionTimestamp
            local currentServerTimestamp = GetGameTimer()
            local timeDiffMs = currentServerTimestamp - lastTimestamp
            if timeDiffMs >= minTimeDiff then
                local distance = #(currentPos - lastPos)
                local speed = distance / (timeDiffMs / 1000.0)
                if speed > serverSpeedThreshold then
                    Log("^1[NexusGuard Server Check]^7 Suspiciously high speed detected for " .. playerName .. " (ID: " .. source .. "): " .. string.format("%.2f", speed) .. " m/s (" .. string.format("%.1f", speed * 3.6) .. " km/h). Dist: " .. string.format("%.2f", distance) .. "m in " .. timeDiffMs .. "ms.^7", 1)
                    if NexusGuardServer.Detections.Process then NexusGuardServer.Detections.Process(source, "ServerSpeedCheck", { calculatedSpeed = speed, threshold = serverSpeedThreshold, distance = distance, timeDiff = timeDiffMs }) end
                end
            end
        end
        session.metrics.lastServerPosition = currentPos; session.metrics.lastServerPositionTimestamp = GetGameTimer()
    end)

    -- Health Update Handler
    _G.EventRegistry.AddEventHandler('NEXUSGUARD_HEALTH_UPDATE', function(currentHealth, currentArmor, clientTimestamp, tokenData)
        local source = source; if not source or source <= 0 then return end
        local playerName = GetPlayerName(source) or "Unknown (" .. source .. ")"
        if not NexusGuardServer.Security or not NexusGuardServer.Security.ValidateToken or not NexusGuardServer.Security.ValidateToken(source, tokenData) then Log("^1[NexusGuard] Invalid security token with health update from " .. playerName .. ". Banning.^7", 1); if NexusGuardServer.Bans.Execute then NexusGuardServer.Bans.Execute(source, 'Invalid security token with health update') else DropPlayer(source, "Anti-Cheat validation failed (Health Update Token).") end; return end
        local session = PlayerSessionManager.GetSession(source)
        if not session.metrics then Log("^1[NexusGuard] PlayerMetrics not found for " .. playerName .. " during health update.^7", 1); return end

        -- Use the specific server-side thresholds from config
        local serverHealthRegenThreshold = (NexusGuardServer.Config.Thresholds and NexusGuardServer.Config.Thresholds.serverSideRegenThreshold) or 3.0 -- Use serverSideRegenThreshold
        local serverArmorMax = (NexusGuardServer.Config.Thresholds and NexusGuardServer.Config.Thresholds.serverSideArmorThreshold) or 105.0 -- Use serverSideArmorThreshold

        if session.metrics.lastServerHealth and session.metrics.lastServerHealthTimestamp then
            local lastHealth, lastTimestamp = session.metrics.lastServerHealth, session.metrics.lastServerHealthTimestamp
            local currentServerTimestamp = GetGameTimer()
            local timeDiffMs = currentServerTimestamp - lastTimestamp
            if currentHealth > lastHealth and timeDiffMs > 100 then
                local healthIncrease = currentHealth - lastHealth
                local regenRate = healthIncrease / (timeDiffMs / 1000.0)
                if regenRate > serverHealthRegenThreshold then
                     Log("^1[NexusGuard Server Check]^7 Suspiciously high health regeneration detected for " .. playerName .. " (ID: " .. source .. "): +" .. string.format("%.1f", healthIncrease) .. " HP in " .. timeDiffMs .. "ms (Rate: " .. string.format("%.2f", regenRate) .. " HP/s).^7", 1)
                     if NexusGuardServer.Detections.Process then NexusGuardServer.Detections.Process(source, "ServerHealthRegenCheck", { increase = healthIncrease, rate = regenRate, threshold = serverHealthRegenThreshold, timeDiff = timeDiffMs }) end
                end
            end
        end
        if currentArmor > serverArmorMax then
             Log("^1[NexusGuard Server Check]^7 Suspiciously high armor detected for " .. playerName .. " (ID: " .. source .. "): " .. currentArmor .. " (Max Allowed: " .. serverArmorMax .. ").^7", 1)
             if NexusGuardServer.Detections.Process then NexusGuardServer.Detections.Process(source, "ServerArmorCheck", { armor = currentArmor, threshold = serverArmorMax }) end
        end
        session.metrics.lastServerHealth = currentHealth; session.metrics.lastServerArmor = currentArmor; session.metrics.lastServerHealthTimestamp = GetGameTimer()
    end)

    Log("^2[NexusGuard] Standardized server event handlers registration complete.^7", 2)
end

-- Scheduled Tasks (Remains local to this file)
function SetupScheduledTasks()
    -- Player metrics collection thread (Placeholder - Needs API call if refactored)
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(60000) -- Once per minute
            -- if NexusGuardServer.Metrics and NexusGuardServer.Metrics.Collect then NexusGuardServer.Metrics.Collect() end -- Example if refactored
            if NexusGuardServer.Database and NexusGuardServer.Database.CleanupDetectionHistory then NexusGuardServer.Database.CleanupDetectionHistory() end
            if NexusGuardServer.Security and NexusGuardServer.Security.CleanupTokenCache then NexusGuardServer.Security.CleanupTokenCache() end -- Add token cache cleanup
        end
    end)

    -- AI model update thread (if enabled) using API
    -- AI Placeholder Removed
    -- if NexusGuardServer.Config and NexusGuardServer.Config.AI and NexusGuardServer.Config.AI.enabled then
    --     Citizen.CreateThread(function()
    --         while true do
    --             Citizen.Wait(86400000) -- Daily updates
    --             if NexusGuardServer.AI and NexusGuardServer.AI.UpdateModels then NexusGuardServer.AI.UpdateModels() end
    --         end
    --     end)
    -- end
end

-- Command to get a list of running resources (for whitelist configuration)
RegisterCommand('nexusguard_getresources', function(source, args, rawCommand)
    if source == 0 then print("[NexusGuard] This command cannot be run from the server console."); return end
    if not NexusGuardServer.Permissions or not NexusGuardServer.Permissions.IsAdmin or not NexusGuardServer.Permissions.IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { color = {255, 0, 0}, multiline = true, args = {"NexusGuard", "You do not have permission to use this command."} })
        Log("^1[NexusGuard] Permission denied for /nexusguard_getresources by player ID: " .. source .. "^7", 1)
        return
    end
    Log("^2[NexusGuard] Admin " .. GetPlayerName(source) .. " (ID: " .. source .. ") requested resource list.^7", 2)
    local resources = {}
    local numResources = GetNumResources()
    for i = 0, numResources - 1 do local resourceName = GetResourceByFindIndex(i); if resourceName and GetResourceState(resourceName) == 'started' then table.insert(resources, resourceName) end end
    table.sort(resources)
    local output = "--- Running Resources for Whitelist ---\n{\n"
    for _, resName in ipairs(resources) do output = output .. "    \"" .. resName .. "\",\n" end
    if #resources > 0 then output = string.sub(output, 1, #output - 2) end -- Remove last comma and newline
    output = output .. "\n}\n--- Copy the list above (including braces) into Config.Features.resourceVerification.whitelist ---"
    TriggerClientEvent('chat:addMessage', source, { color = {0, 255, 0}, multiline = true, args = {"NexusGuard Resources", output} })
    print("[NexusGuard] Generated resource list for admin " .. GetPlayerName(source) .. ":\n" .. output)
end, true) -- Restricted command

-- Ban Command
-- Usage: /nexusguard_ban [target_player_id] [duration_seconds] [reason]
-- Duration 0 or omitted = permanent
RegisterCommand('nexusguard_ban', function(sourceCmd, args, rawCommand)
    local adminSource = tonumber(sourceCmd)
    if adminSource == 0 then Log("This command cannot be run from console.", 1); return end
    if not NexusGuardServer.Permissions or not NexusGuardServer.Permissions.IsAdmin or not NexusGuardServer.Permissions.IsAdmin(adminSource) then
        TriggerClientEvent('chat:addMessage', adminSource, { color = {255, 0, 0}, multiline = true, args = {"NexusGuard", "Permission denied."} })
        return
    end

    local targetId = tonumber(args[1])
    local duration = tonumber(args[2]) or 0 -- Default to permanent if not specified or invalid
    local reason = table.concat(args, " ", 3) or "Banned by Admin Command"

    if not targetId or not GetPlayerName(targetId) then
        TriggerClientEvent('chat:addMessage', adminSource, { color = {255, 200, 0}, multiline = true, args = {"NexusGuard", "Invalid target player ID."} })
        return
    end

    local adminName = GetPlayerName(adminSource)
    Log("^1[NexusGuard] Admin " .. adminName .. " (ID: " .. adminSource .. ") is banning player ID " .. targetId .. " (Duration: " .. duration .. "s, Reason: " .. reason .. ")", 1)

    if NexusGuardServer.Bans and NexusGuardServer.Bans.Execute then
        NexusGuardServer.Bans.Execute(targetId, reason, adminName, duration)
        TriggerClientEvent('chat:addMessage', adminSource, { color = {0, 255, 0}, multiline = true, args = {"NexusGuard", "Ban command executed for player ID " .. targetId .. "."} })
    else
        Log("^1[NexusGuard] CRITICAL: Ban function not found in API! Cannot execute ban command.^7", 1)
        TriggerClientEvent('chat:addMessage', adminSource, { color = {255, 0, 0}, multiline = true, args = {"NexusGuard", "Error: Ban function unavailable."} })
    end
end, true) -- Restricted command

-- Unban Command
-- Usage: /nexusguard_unban [identifier_type] [identifier_value]
-- identifier_type: license, ip, discord
RegisterCommand('nexusguard_unban', function(sourceCmd, args, rawCommand)
    local adminSource = tonumber(sourceCmd)
    if adminSource == 0 then Log("This command cannot be run from console.", 1); return end
    if not NexusGuardServer.Permissions or not NexusGuardServer.Permissions.IsAdmin or not NexusGuardServer.Permissions.IsAdmin(adminSource) then
        TriggerClientEvent('chat:addMessage', adminSource, { color = {255, 0, 0}, multiline = true, args = {"NexusGuard", "Permission denied."} })
        return
    end

    local idType = args[1]
    local idValue = args[2]

    if not idType or not idValue then
        TriggerClientEvent('chat:addMessage', adminSource, { color = {255, 200, 0}, multiline = true, args = {"NexusGuard", "Usage: /nexusguard_unban [license|ip|discord] [identifier_value]"} })
        return
    end

    local adminName = GetPlayerName(adminSource)
    Log("^2[NexusGuard] Admin " .. adminName .. " (ID: " .. adminSource .. ") is attempting to unban " .. idType .. ": " .. idValue, 2)

    if NexusGuardServer.Bans and NexusGuardServer.Bans.Unban then
        local success, message = NexusGuardServer.Bans.Unban(idType, idValue, adminName)
        local color = success and {0, 255, 0} or {255, 200, 0}
        -- Send feedback after a short delay to allow async operation to potentially log first
        SetTimeout(500, function()
            TriggerClientEvent('chat:addMessage', adminSource, { color = color, multiline = true, args = {"NexusGuard", message} })
        end)
    else
        Log("^1[NexusGuard] CRITICAL: Unban function not found in API! Cannot execute unban command.^7", 1)
        TriggerClientEvent('chat:addMessage', adminSource, { color = {255, 0, 0}, multiline = true, args = {"NexusGuard", "Error: Unban function unavailable."} })
    end
end, true) -- Restricted command
