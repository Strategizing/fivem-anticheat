--[[
    NexusGuard Globals & Server-Side Helpers (Refactored)
    Contains shared functions and placeholder implementations, organized into modules.
]]

-- Ensure JSON library is available (e.g., from oxmysql or another resource)
local json = _G.json -- Use _G.json consistently

-- Main container for server-side logic and data
local NexusGuardServer = {
    Config = _G.Config or {}, -- Still need access to Config loaded from config.lua
    PlayerMetrics = _G.PlayerMetrics or {}, -- Keep global for now (Prompt 3 addresses this later)
    BanCache = {},
    BanCacheExpiry = 0,
    BanCacheDuration = 300, -- Cache duration in seconds (5 minutes)
    ESX = nil,
    QBCore = nil,
    Utils = {},
    Permissions = {},
    Bans = {},
    Security = {},
    Detections = {},
    Database = {},
    Discord = {},
    EventHandlers = {},
    AI = {} -- Placeholder module (content removed)
}

-- Simple logging utility
function NexusGuardServer.Utils.Log(message, level)
    level = level or 2
    -- Use the new Config.LogLevel setting
    local configLogLevel = (NexusGuardServer.Config and NexusGuardServer.Config.LogLevel) or 2 -- Default to Info if not set
    if level <= configLogLevel then -- Log if message level is less than or equal to config level
        print("[NexusGuard] " .. message)
    end
end
local Log = NexusGuardServer.Utils.Log -- Local alias for convenience within this file

-- Helper function to format duration
function NexusGuardServer.Utils.FormatDuration(totalSeconds)
    if not totalSeconds or totalSeconds <= 0 then return "Permanent" end
    local days = math.floor(totalSeconds / 86400)
    local hours = math.floor((totalSeconds % 86400) / 3600)
    local minutes = math.floor((totalSeconds % 3600) / 60)
    local seconds = math.floor(totalSeconds % 60)
    local parts = {}
    if days > 0 then table.insert(parts, days .. "d") end
    if hours > 0 then table.insert(parts, hours .. "h") end
    if minutes > 0 then table.insert(parts, minutes .. "m") end
    if seconds > 0 or #parts == 0 then table.insert(parts, seconds .. "s") end
    return table.concat(parts, " ")
end
local FormatDuration = NexusGuardServer.Utils.FormatDuration -- Local alias

-- Helper to safely get players list
function NexusGuardServer.Utils.SafeGetPlayers()
    local success, players = pcall(GetPlayers)
    if success and type(players) == "table" then
        return players
    end
    return {}
end

-- Attempt to load framework objects
Citizen.CreateThread(function()
    Citizen.Wait(1000)
    if GetResourceState('es_extended') == 'started' then
        local esxExport = exports['es_extended']
        if esxExport and esxExport.getSharedObject then
             NexusGuardServer.ESX = esxExport:getSharedObject()
             Log("ESX object loaded for permission checks.", 3)
        else
             Log("es_extended resource found, but could not get SharedObject.", 2)
        end
    end
    if GetResourceState('qb-core') == 'started' then
         local qbExport = exports['qb-core']
         if qbExport and qbExport.GetCoreObject then
             NexusGuardServer.QBCore = qbExport:GetCoreObject()
             Log("QBCore object loaded for permission checks.", 3)
         else
             Log("qb-core resource found, but could not get CoreObject.", 2)
         end
    end
end)

-- #############################################################################
-- ## Database Module ##
-- #############################################################################
NexusGuardServer.Database = {}

function NexusGuardServer.Database.Initialize()
    if not NexusGuardServer.Config or not NexusGuardServer.Config.Database or not NexusGuardServer.Config.Database.enabled then
        Log("Database integration disabled in config.", 2)
        return
    end
    if not MySQL then
        Log("^1Error: MySQL object not found. Ensure oxmysql is started before NexusGuard.^7", 1)
        return
    end

    Log("Initializing database schema...", 2)
    local successLoad, schemaFile = pcall(LoadResourceFile, GetCurrentResourceName(), "sql/schema.sql")
    if not successLoad or not schemaFile then
        Log("^1Error: Could not load sql/schema.sql file. Error: " .. tostring(schemaFile) .. "^7", 1)
        return
    end

    local statements = {}
    for stmt in string.gmatch(schemaFile, "([^;]+)") do
        stmt = string.gsub(stmt, "^%s+", ""):gsub("%s+$", "")
        if string.len(stmt) > 0 then table.insert(statements, stmt) end
    end

    local function executeNext(index)
        if index > #statements then
            Log("Database schema check/creation complete.", 2)
            NexusGuardServer.Bans.LoadList(true) -- Force load ban list after schema setup
            return
        end
        local success, err = pcall(MySQL.Async.execute, statements[index], {})
        if not success then Log(string.format("^1Error executing schema statement %d: %s^7", index, tostring(err)), 1) end
        executeNext(index + 1)
    end
    executeNext(1)
end

function NexusGuardServer.Database.CleanupDetectionHistory()
    local dbConfig = NexusGuardServer.Config and NexusGuardServer.Config.Database
    if not dbConfig or not dbConfig.enabled or not dbConfig.historyDuration or dbConfig.historyDuration <= 0 then return end
    if not MySQL then Log("^1Error: MySQL object not found. Cannot cleanup detection history.^7", 1); return end

    local historyDays = dbConfig.historyDuration
    Log("Cleaning up detection history older than " .. historyDays .. " days...", 2)
    local success, result = pcall(MySQL.Async.execute,
        'DELETE FROM nexusguard_detections WHERE timestamp < DATE_SUB(NOW(), INTERVAL @days DAY)',
        { ['@days'] = historyDays }
    )
    if success then
        if result and result > 0 then Log("Cleaned up " .. result .. " old detection records.", 2) end
    else
        Log(string.format("^1Error cleaning up detection history: %s^7", tostring(result)), 1)
    end
end

function NexusGuardServer.Database.SavePlayerMetrics(playerId)
    local source = tonumber(playerId)
    if not source or source <= 0 then Log("^1Error: Invalid player ID provided to SavePlayerMetrics: " .. tostring(playerId) .. "^7", 1); return end
    local dbConfig = NexusGuardServer.Config and NexusGuardServer.Config.Database
    if not dbConfig or not dbConfig.enabled then return end
    local metrics = NexusGuardServer.PlayerMetrics and NexusGuardServer.PlayerMetrics[source]
    if not metrics then Log("^1Warning: PlayerMetrics not found for player " .. source .. " on disconnect. Cannot save session.^7", 1); return end
    if not MySQL then Log("^1Error: MySQL object not found. Cannot save session metrics for player " .. source .. ".^7", 1); return end

    local playerName = GetPlayerName(source) or "Unknown (" .. source .. ")"
    local license = GetPlayerIdentifierByType(source, 'license')
    if not license then Log("^1Warning: Cannot save metrics for player " .. source .. " without license identifier. Skipping save.^7", 1); return end

    local connectTime = metrics.connectTime or os.time()
    local playTime = math.max(0, os.time() - connectTime)
    local finalTrustScore = metrics.trustScore or 100.0
    local totalDetections = #(metrics.detections or {})
    local totalWarnings = metrics.warningCount or 0

    Log("Saving session metrics for player " .. playerId .. " (" .. playerName .. ")", 3)
    local success, result = pcall(MySQL.Async.execute,
        'INSERT INTO nexusguard_sessions (player_name, player_license, connect_time, play_time_seconds, final_trust_score, total_detections, total_warnings) VALUES (@name, @license, FROM_UNIXTIME(@connect), @playtime, @trust, @detections, @warnings)',
        {
            ['@name'] = playerName, ['@license'] = license, ['@connect'] = connectTime,
            ['@playtime'] = playTime, ['@trust'] = finalTrustScore,
            ['@detections'] = totalDetections, ['@warnings'] = totalWarnings
        }
    )
    if success then
        if not result or result <= 0 then Log("^1Warning: Saving session metrics for player " .. source .. " reported 0 affected rows.^7", 1) end
    else
        Log(string.format("^1Error saving session metrics for player %s: %s^7", source, tostring(result)), 1)
    end
end

-- #############################################################################
-- ## Bans Module ##
-- #############################################################################
NexusGuardServer.Bans = {}

function NexusGuardServer.Bans.LoadList(forceReload)
    local dbConfig = NexusGuardServer.Config and NexusGuardServer.Config.Database
    if not dbConfig or not dbConfig.enabled then return end
    if not MySQL then return end

    local currentTime = os.time()
    if not forceReload and NexusGuardServer.BanCacheExpiry > currentTime then return end

    Log("Loading ban list from database...", 2)
    local success, bans = pcall(MySQL.Async.fetchAll, 'SELECT * FROM nexusguard_bans WHERE expire_date IS NULL OR expire_date > NOW()', {})
    if success and type(bans) == "table" then
        NexusGuardServer.BanCache = bans
        NexusGuardServer.BanCacheExpiry = currentTime + NexusGuardServer.BanCacheDuration
        Log("Loaded " .. #NexusGuardServer.BanCache .. " active bans from database.", 2)
    elseif not success then
        Log(string.format("^1Error loading bans from database: %s^7", tostring(bans)), 1)
        NexusGuardServer.BanCache = {}
        NexusGuardServer.BanCacheExpiry = 0
    else
        Log("^1Warning: Received unexpected result while loading bans from database.^7", 1)
        NexusGuardServer.BanCache = {}
        NexusGuardServer.BanCacheExpiry = 0
    end
end

function NexusGuardServer.Bans.IsPlayerBanned(license, ip, discordId)
    local dbConfig = NexusGuardServer.Config and NexusGuardServer.Config.Database
    if dbConfig and dbConfig.enabled and NexusGuardServer.BanCacheExpiry <= os.time() then
        NexusGuardServer.Bans.LoadList(false)
    end
    for _, ban in ipairs(NexusGuardServer.BanCache) do
        local identifiersMatch = false
        if license and ban.license and ban.license == license then identifiersMatch = true end
        if ip and ban.ip and ban.ip == ip then identifiersMatch = true end
        if discordId and ban.discord and ban.discord == discordId then identifiersMatch = true end
        if identifiersMatch then return true, ban.reason or "No reason specified" end
    end
    return false, nil
end

function NexusGuardServer.Bans.Store(banData)
    local dbConfig = NexusGuardServer.Config and NexusGuardServer.Config.Database
    if not dbConfig or not dbConfig.enabled then Log("Attempted to store ban while Database is disabled.", 3); return end
    if not MySQL then Log("^1Error: MySQL object not found. Cannot store ban.^7", 1); return end
    if not banData or not banData.license then Log("^1Error: Cannot store ban without player license identifier.^7", 1); return end

    local expireDate = nil
    if banData.durationSeconds and banData.durationSeconds > 0 then
        expireDate = os.date("!%Y-%m-%d %H:%M:%S", os.time() + banData.durationSeconds)
    end

    local success, result = pcall(MySQL.Async.execute,
        'INSERT INTO nexusguard_bans (name, license, ip, discord, reason, admin, expire_date) VALUES (@name, @license, @ip, @discord, @reason, @admin, @expire_date)',
        {
            ['@name'] = banData.name, ['@license'] = banData.license, ['@ip'] = banData.ip,
            ['@discord'] = banData.discord, ['@reason'] = banData.reason,
            ['@admin'] = banData.admin or "NexusGuard System", ['@expire_date'] = expireDate
        }
    )
    if success then
        if result and result > 0 then
             Log("Ban for " .. banData.name .. " stored in database.", 2)
             NexusGuardServer.Bans.LoadList(true) -- Force reload ban cache
        else
             Log("^1Warning: Storing ban for " .. banData.name .. " reported 0 affected rows.^7", 1)
        end
    else
        Log(string.format("^1Error storing ban for %s in database: %s^7", banData.name, tostring(result)), 1)
    end
end

function NexusGuardServer.Bans.Execute(playerId, reason, adminName, durationSeconds)
    local source = tonumber(playerId)
    if not source or source <= 0 then Log("^1Error: Invalid player ID provided to BanPlayer: " .. tostring(playerId) .. "^7", 1); return end
    local playerName = GetPlayerName(source)
    if not playerName then Log("^1Error: Cannot ban player ID: " .. source .. " - Player not found.^7", 1); return end

    local license = GetPlayerIdentifierByType(source, 'license')
    local ip = GetPlayerEndpoint(source)
    local discord = GetPlayerIdentifierByType(source, 'discord')
    if not license then Log("^1Warning: Could not get license identifier for player " .. source .. ". Ban might be less effective.^7", 1) end

    local banData = {
        name = playerName, license = license, ip = ip and string.gsub(ip, "ip:", "") or nil,
        discord = discord, reason = reason or "Banned by NexusGuard",
        admin = adminName or "NexusGuard System", durationSeconds = durationSeconds
    }
    NexusGuardServer.Bans.Store(banData)

    local banMessage = NexusGuardServer.Config.BanMessage or "You have been banned."
    if durationSeconds and durationSeconds > 0 then
        banMessage = banMessage .. " Duration: " .. FormatDuration(durationSeconds)
    end
    DropPlayer(source, banMessage)
    Log("^1Banned player: " .. playerName .. " (ID: " .. source .. ") Reason: " .. banData.reason .. "^7", 1)

    if NexusGuardServer.Discord.Send then
        local discordMsg = string.format(
            "**Player Banned**\n**Name:** %s\n**License:** %s\n**IP:** %s\n**Discord:** %s\n**Reason:** %s\n**Admin:** %s",
            playerName, license or "N/A", banData.ip or "N/A", discord or "N/A", banData.reason, banData.admin
        )
        if durationSeconds and durationSeconds > 0 then discordMsg = discordMsg .. "\n**Duration:** " .. FormatDuration(durationSeconds) end
        NexusGuardServer.Discord.Send("Bans", discordMsg, NexusGuardServer.Config.Discord.webhooks and NexusGuardServer.Config.Discord.webhooks.bans)
    end
end

-- Unbans a player based on identifier
-- @param identifierType String: "license", "ip", or "discord"
-- @param identifierValue String: The actual identifier value
-- @param adminName String: Name of the admin performing the unban
-- @return boolean, string: True if successful, false + error message otherwise
function NexusGuardServer.Bans.Unban(identifierType, identifierValue, adminName)
    local dbConfig = NexusGuardServer.Config and NexusGuardServer.Config.Database
    if not dbConfig or not dbConfig.enabled then return false, "Database is disabled." end
    if not MySQL then Log("^1Error: MySQL object not found. Cannot unban.^7", 1); return false, "Database connection error." end
    if not identifierType or not identifierValue then return false, "Identifier type and value required." end

    local fieldName = string.lower(identifierType)
    if fieldName ~= "license" and fieldName ~= "ip" and fieldName ~= "discord" then
        return false, "Invalid identifier type. Use 'license', 'ip', or 'discord'."
    end

    Log("Attempting to unban identifier: " .. fieldName .. "=" .. identifierValue .. " by " .. (adminName or "System"), 2)

    -- Use async execute for the DELETE operation
    local promise = MySQL.Async.execute(
        'DELETE FROM nexusguard_bans WHERE ' .. fieldName .. ' = @identifier',
        { ['@identifier'] = identifierValue }
    )

    -- Handle the promise result (this part runs asynchronously)
    promise:next(function(result)
        if result and result.affectedRows and result.affectedRows > 0 then
            Log("Successfully unbanned identifier: " .. fieldName .. "=" .. identifierValue .. ". Rows affected: " .. result.affectedRows, 2)
            NexusGuardServer.Bans.LoadList(true) -- Force reload cache
            -- Optionally notify admin/discord
            if NexusGuardServer.Discord.Send then
                NexusGuardServer.Discord.Send("Bans", "Identifier Unbanned",
                    "Identifier **" .. fieldName .. ":** `" .. identifierValue .. "` was unbanned by **" .. (adminName or "System") .. "**.",
                    NexusGuardServer.Config.Discord.webhooks and NexusGuardServer.Config.Discord.webhooks.bans)
            end
            -- How to notify the command source? This requires a callback or different structure.
            -- For now, success is logged server-side. Command feedback needs adjustment.
        elseif result and result.affectedRows == 0 then
            Log("Unban attempt for identifier: " .. fieldName .. "=" .. identifierValue .. " found no matching active ban.", 2)
            -- Notify admin?
        else
            Log("^1Error during unban operation for identifier: " .. fieldName .. "=" .. identifierValue .. ". Result: " .. json.encode(result), 1)
            -- Notify admin?
        end
    end, function(err)
        Log("^1Error executing unban query for identifier: " .. fieldName .. "=" .. identifierValue .. ". Error: " .. tostring(err), 1)
        -- Notify admin?
    end)

    -- NOTE: Because this uses MySQL.Async, the command handler cannot directly return true/false based on DB result.
    -- It can only confirm the command was received and the async operation started.
    -- Feedback to the admin in chat will be immediate, not reflecting DB success.
    return true, "Unban process initiated. Check server console for details."
end


-- #############################################################################
-- ## Permissions Module ##
-- #############################################################################
NexusGuardServer.Permissions = {}

function NexusGuardServer.Permissions.IsAdmin(playerId)
    local player = tonumber(playerId)
    if not player or player <= 0 or not GetPlayerName(player) then return false end
    local cfg = NexusGuardServer.Config
    if not cfg or not cfg.AdminGroups then Log("^1Warning: Config.AdminGroups not found for IsPlayerAdmin check.^7", 1); return false end

    local frameworkSetting = cfg.PermissionsFramework or "ace"
    local ESX = NexusGuardServer.ESX -- Use locally stored framework object
    local QBCore = NexusGuardServer.QBCore -- Use locally stored framework object

    local function checkESX()
        if ESX then
            local xPlayer = ESX.GetPlayerFromId(player)
            if xPlayer then
                local playerGroup = xPlayer.getGroup()
                for _, group in ipairs(cfg.AdminGroups) do if playerGroup == group then return true end end
            else Log("^1Warning: Could not get xPlayer object for player " .. player .. " in IsPlayerAdmin (ESX check).^7", 1) end
        else if frameworkSetting == "esx" then Log("^1Warning: Config.PermissionsFramework set to 'esx' but ESX object was not loaded.^7", 1) end end
        return false
    end
    local function checkQBCore()
        if QBCore then
            for _, group in ipairs(cfg.AdminGroups) do if QBCore.Functions.HasPermission(player, group) then return true end end
        else if frameworkSetting == "qbcore" then Log("^1Warning: Config.PermissionsFramework set to 'qbcore' but QBCore object was not loaded.^7", 1) end end
        return false
    end
    local function checkACE()
        for _, group in ipairs(cfg.AdminGroups) do if IsPlayerAceAllowed(player, "group." .. group) then return true end end
        return false
    end
    local function checkCustom() Log("IsPlayerAdmin: Config.PermissionsFramework set to 'custom'. Implement your logic here.", 3); return false end

    if frameworkSetting == "esx" then return checkESX()
    elseif frameworkSetting == "qbcore" then return checkQBCore()
    elseif frameworkSetting == "custom" then return checkCustom()
    elseif frameworkSetting == "ace" then
        if ESX and checkESX() then return true end
        if QBCore and checkQBCore() then return true end
        return checkACE()
    else Log("^1Warning: Invalid Config.PermissionsFramework value: '" .. frameworkSetting .. "'. Defaulting to ACE check.^7", 1); return checkACE() end
end

-- #############################################################################
-- ## Security Module ##
-- #############################################################################
NexusGuardServer.Security = {
    recentTokens = {}, -- Cache for anti-replay { [signature] = expiryTimestamp }
    tokenCacheCleanupInterval = 60000, -- ms (e.g., clean up every minute)
    lastTokenCacheCleanup = 0
}

function NexusGuardServer.Security.GenerateToken(playerId)
    if not lib or not lib.crypto or not lib.crypto.hmac or not lib.crypto.hmac.sha256 then Log("^1SECURITY ERROR: ox_lib crypto functions not available.^7", 1); return nil end
    local secret = NexusGuardServer.Config and NexusGuardServer.Config.SecuritySecret
    if not secret or secret == "CHANGE_THIS_TO_A_VERY_LONG_RANDOM_SECRET_STRING" then Log("^1SECURITY ERROR: Config.SecuritySecret is not set or is default.^7", 1); return nil end

    local timestamp = os.time()
    local message = tostring(playerId) .. ":" .. tostring(timestamp)
    local success, signature = pcall(lib.crypto.hmac.sha256, secret, message)
    if not success or not signature then Log("^1SECURITY ERROR: Failed to generate HMAC signature: " .. tostring(signature) .. "^7", 1); return nil end
    return { timestamp = timestamp, signature = signature }
end

function NexusGuardServer.Security.ValidateToken(playerId, tokenData)
    if not lib or not lib.crypto or not lib.crypto.hmac or not lib.crypto.hmac.sha256 then Log("^1SECURITY ERROR: ox_lib crypto functions not available.^7", 1); return false end
    local secret = NexusGuardServer.Config and NexusGuardServer.Config.SecuritySecret
    if not secret or secret == "CHANGE_THIS_TO_A_VERY_LONG_RANDOM_SECRET_STRING" then Log("^1SECURITY ERROR: Config.SecuritySecret is not set or is default.^7", 1); return false end
    if not tokenData or type(tokenData) ~= "table" or not tokenData.timestamp or not tokenData.signature then Log("^1Invalid token data structure received from player " .. playerId .. "^7", 1); return false end

    local receivedTimestamp = tonumber(tokenData.timestamp)
    local receivedSignature = tokenData.signature
    if not receivedTimestamp or type(receivedSignature) ~= "string" then Log("^1Invalid token data types received from player " .. playerId .. "^7", 1); return false end

    local currentTime = os.time()
    local maxTimeDifference = 60
    if math.abs(currentTime - receivedTimestamp) > maxTimeDifference then Log("^1Token timestamp expired/invalid for player " .. playerId .. "^7", 1); return false end

    local message = tostring(playerId) .. ":" .. tostring(receivedTimestamp)
    local success, expectedSignature = pcall(lib.crypto.hmac.sha256, secret, message)
    if not success or not expectedSignature then Log("^1SECURITY ERROR: Failed to recalculate HMAC signature: " .. tostring(expectedSignature) .. "^7", 1); return false end

    if expectedSignature ~= receivedSignature then Log("^1Token signature mismatch for player " .. playerId .. "^7", 1); return false end

    -- Anti-Replay Check
    local cacheKey = receivedSignature -- Use the signature as the key
    local expiryTime = NexusGuardServer.Security.recentTokens[cacheKey]

    if expiryTime and currentTime < expiryTime then
        Log("^1Token replay detected for player " .. playerId .. ". Signature: " .. cacheKey .. "^7", 1)
        return false -- Token already used recently
    end

    -- Add token to cache with expiry slightly longer than validation window
    local buffer = 5 -- Add 5 seconds buffer
    NexusGuardServer.Security.recentTokens[cacheKey] = currentTime + maxTimeDifference + buffer
    -- Log("Token validated and cached for " .. playerId, 4) -- Debugging only

    return true
end

-- Function to clean up expired tokens from the cache
function NexusGuardServer.Security.CleanupTokenCache()
    local currentTime = os.time()
    if GetGameTimer() - NexusGuardServer.Security.lastTokenCacheCleanup < NexusGuardServer.Security.tokenCacheCleanupInterval then
        return -- Not time to clean yet
    end

    local cleanupCount = 0
    for signature, expiryTimestamp in pairs(NexusGuardServer.Security.recentTokens) do
        if currentTime >= expiryTimestamp then
            NexusGuardServer.Security.recentTokens[signature] = nil
            cleanupCount = cleanupCount + 1
        end
    end

    if cleanupCount > 0 then
        Log("Cleaned up " .. cleanupCount .. " expired entries from token cache.", 3)
    end
    NexusGuardServer.Security.lastTokenCacheCleanup = GetGameTimer()
end

-- #############################################################################
-- ## Detections Module ##
-- #############################################################################
NexusGuardServer.Detections = {}

-- Helper function for server-side weapon damage validation
function NexusGuardServer.Detections.ValidateWeaponDamage(playerId, detectionData)
    local cfg = NexusGuardServer.Config
    local weaponHash = detectionData.weaponHash
    local detectedDamage = detectionData.detectedValue
    local serverBaseline = cfg.WeaponBaseDamage and cfg.WeaponBaseDamage[weaponHash]

    if serverBaseline then
        local serverThresholdMultiplier = (cfg.Thresholds and cfg.Thresholds.weaponDamageMultiplier) or 1.5
        local serverDamageLimit = serverBaseline * serverThresholdMultiplier
        if detectedDamage > serverDamageLimit then
            Log('^1[NexusGuard Server Check]^7 Weapon damage CONFIRMED for player ' .. playerId .. ' (Weapon: ' .. weaponHash .. '). Detected: ' .. detectedDamage .. ', Server Baseline: ' .. serverBaseline .. ', Limit: ' .. serverDamageLimit .. '^7', 1)
            detectionData.serverValidated = true; detectionData.serverBaseline = serverBaseline; detectionData.serverLimit = serverDamageLimit
            return true -- Validation failed (damage too high)
        else
            Log('^3[NexusGuard Server Check]^7 Weapon damage for player ' .. playerId .. ' within server limits. Detected: ' .. detectedDamage .. ', Server Limit: ' .. serverDamageLimit .. '^7', 3)
        end
    else
        Log('^3[NexusGuard Server Check]^7 No server baseline damage found for weapon ' .. weaponHash .. '. Cannot validate damage.^7', 3)
    end
    return false -- Validation passed or couldn't be performed
end

-- Helper function for server-side weapon clip size validation
function NexusGuardServer.Detections.ValidateWeaponClipSize(playerId, detectionData)
    local cfg = NexusGuardServer.Config
    local weaponHash = detectionData.weaponHash
    local detectedClipSize = detectionData.detectedValue
    local serverBaselineClip = cfg.WeaponBaseClipSize and cfg.WeaponBaseClipSize[weaponHash]

    if serverBaselineClip then
        local serverClipLimit = serverBaselineClip -- No multiplier usually needed
        if detectedClipSize > serverClipLimit then
            Log('^1[NexusGuard Server Check]^7 Weapon clip size CONFIRMED for player ' .. playerId .. ' (Weapon: ' .. weaponHash .. '). Detected: ' .. detectedClipSize .. ', Server Baseline: ' .. serverBaselineClip .. '^7', 1)
            detectionData.serverValidated = true
            detectionData.serverBaselineClip = serverBaselineClip
            return true -- Validation failed (clip size too high)
        else
            Log('^3[NexusGuard Server Check]^7 Weapon clip size for player ' .. playerId .. ' within server limits. Detected: ' .. detectedClipSize .. ', Server Limit: ' .. serverBaselineClip .. '^7', 3)
        end
    else
        Log('^3[NexusGuard Server Check]^7 No server baseline clip size found for weapon ' .. weaponHash .. '. Cannot validate clip size.^7', 3)
    end
    return false -- Validation passed or couldn't be performed
end

function NexusGuardServer.Detections.GetSeverity(detectionType)
    local severities = {
        godmode = 50, speedhack = 30, weaponmodification = 40, teleporting = 25,
        noclip = 45, resourceinjection = 75, entityspam = 35, explosionspam = 40,
        menudetection = 60, serverspeedcheck = 60, serverhealthregencheck = 55, serverarmorcheck = 50
    }
    return severities[string.lower(detectionType or "")] or 20
end

function NexusGuardServer.Detections.IsHighRisk(detectionType, detectionData)
    local dtLower = string.lower(detectionType or "")
    local highRiskTypes = {
        ["resourceinjection"] = true, ["menudetection"] = true, ["explosionspam"] = true,
        ["entityspam"] = true, ["godmode"] = true, ["noclip"] = true, ["serverspeedcheck"] = true
    }
    -- Check if serverValidated flag exists and is true
    if type(detectionData) == "table" and detectionData.serverValidated then -- Ensure detectionData is a table before indexing
        if dtLower == "weaponmodification" then return true end -- Any server-validated weapon mod is high risk
        if dtLower == "serverhealthregencheck" then return true end -- Consider high regen high risk
        if dtLower == "serverarmorcheck" then return true end -- Consider high armor high risk
    end
    return highRiskTypes[dtLower] or false
end

function NexusGuardServer.Detections.IsConfirmedCheat(detectionType, detectionData)
    local dtLower = string.lower(detectionType or "")
    local confirmedCheatTypes = {
        ["resourceinjection"] = true, ["serverspeedcheck"] = true
    }
    -- Check if serverValidated flag exists and is true
    if type(detectionData) == "table" and detectionData.serverValidated then -- Ensure detectionData is a table before indexing
        if dtLower == "weaponmodification" then return true end -- Weapon mod confirmed by server is confirmed cheat
        if dtLower == "serverhealthregencheck" then return true end -- Consider server-confirmed regen confirmed
        if dtLower == "serverarmorcheck" then return true end -- Consider server-confirmed armor confirmed
    end
    return confirmedCheatTypes[dtLower] or false
end

function NexusGuardServer.Detections.Store(playerId, detectionType, detectionData)
    local dbConfig = NexusGuardServer.Config and NexusGuardServer.Config.Database
    if not dbConfig or not dbConfig.enabled or not dbConfig.storeDetectionHistory then return end
    if not MySQL then Log("^1Error: MySQL object not found. Cannot store detection.^7", 1); return end
    if not playerId or playerId <= 0 or not detectionType then Log("^1Error: Invalid player ID or detection type provided to StoreDetection.^7", 1); return end

    local playerName = GetPlayerName(playerId) or "Unknown (" .. playerId .. ")"
    local license = GetPlayerIdentifierByType(playerId, 'license')
    local ip = GetPlayerEndpoint(playerId)
    if not json then Log("^1Error: JSON library not available for StoreDetection.^7", 1); return end

    local dataJson = "{}"
    -- Handle both table and string data types for encoding
    if type(detectionData) == "table" then
        local successEncode, result = pcall(json.encode, detectionData)
        if successEncode then dataJson = result else Log("^1Warning: Failed to encode detectionData table for storage. Error: " .. tostring(result) .. "^7", 1) end
    elseif type(detectionData) == "string" then
         -- If it's already a string, wrap it in a simple JSON structure
         local simpleData = { message = detectionData }
         local successEncode, result = pcall(json.encode, simpleData)
         if successEncode then dataJson = result else Log("^1Warning: Failed to encode detectionData string for storage. Error: " .. tostring(result) .. "^7", 1) end
    else
        Log("^1Warning: Invalid detectionData type received by StoreDetection: " .. type(detectionData) .. "^7", 1)
    end

    local success, dbResult = pcall(MySQL.Async.execute,
        'INSERT INTO nexusguard_detections (player_name, player_license, player_ip, detection_type, detection_data) VALUES (@name, @license, @ip, @type, @data)',
        {
            ['@name'] = playerName, ['@license'] = license, ['@ip'] = ip and string.gsub(ip, "ip:", "") or nil,
            ['@type'] = detectionType, ['@data'] = dataJson
        }
    )
    if not success then Log(string.format("^1Error storing detection event for player %s: %s^7", playerId, tostring(dbResult)), 1)
    elseif dbResult and dbResult <= 0 then Log("^1Warning: Storing detection event for player " .. playerId .. " reported 0 affected rows.^7", 1) end
end

function NexusGuardServer.Detections.Process(playerId, detectionType, detectionData)
    if not playerId or playerId <= 0 or not detectionType then Log("^1[NexusGuard] Invalid arguments received by ProcessDetection.^7", 1); return end
    local playerName = GetPlayerName(playerId) or "Unknown (" .. playerId .. ")"
    local cfg = NexusGuardServer.Config
    local metrics = NexusGuardServer.PlayerMetrics and NexusGuardServer.PlayerMetrics[playerId]

    local dataStrForLog = (json and json.encode(detectionData)) or (type(detectionData) == "string" and detectionData or "{}")
    Log('^1[NexusGuard]^7 Detection: ' .. playerName .. ' (ID: '..playerId..') - Type: ' .. detectionType .. ' - Data: ' .. dataStrForLog .. "^7", 1)

    local serverValidated = false
    -- --- Server-Side Validation Checks ---
    if detectionType == "weaponModification" and type(detectionData) == "table" then
        if detectionData.type == "damage" then
            serverValidated = NexusGuardServer.Detections.ValidateWeaponDamage(playerId, detectionData)
        elseif detectionData.type == "clipSize" then
            serverValidated = NexusGuardServer.Detections.ValidateWeaponClipSize(playerId, detectionData)
        end
    end
    -- Add calls to other validation functions here (e.g., for speed, health) if they are moved out of event handlers

    -- Store detection (pass potentially modified detectionData)
    NexusGuardServer.Detections.Store(playerId, detectionType, detectionData)

    -- Update metrics
    if metrics then
        if not metrics.detections then metrics.detections = {} end
        table.insert(metrics.detections, { type = detectionType, data = detectionData, timestamp = os.time(), serverValidated = serverValidated })
        local severityImpact = NexusGuardServer.Detections.GetSeverity(detectionType)
        if serverValidated then severityImpact = severityImpact * 1.5 end
        metrics.trustScore = math.max(0, (metrics.trustScore or 100) - severityImpact)
        Log('^3[NexusGuard]^7 Player ' .. playerName .. ' trust score updated to: ' .. string.format("%.2f", metrics.trustScore) .. "^7", 2)
    else Log("^1Warning: PlayerMetrics not found for player " .. playerId .. " during detection processing.^7", 1) end

    -- AI Placeholder (Remove if AI is removed)
    --[[ -- Commenting out AI section as per Prompt 16
    if cfg.AI and cfg.AI.enabled then
        if NexusGuardServer.AI.ProcessVerification then
            local aiVerdict = NexusGuardServer.AI.ProcessVerification(playerId, detectionType, detectionData)
            if aiVerdict then
                Log('^3[NexusGuard]^7 AI Verdict: ' .. (json and json.encode(aiVerdict) or "Error encoding verdict") .. "^7", 3)
                if aiVerdict.confidence and aiVerdict.confidence > (cfg.Thresholds.aiDecisionConfidenceThreshold or 0.75) then
                    if aiVerdict.action == 'ban' then Log("^1[NexusGuard] AI Ban Triggered for " .. playerName .. "^7", 1); NexusGuardServer.Bans.Execute(playerId, 'AI-confirmed cheat: ' .. detectionType); return end
                    if aiVerdict.action == 'kick' then Log("^1[NexusGuard] AI Kick Triggered for " .. playerName .. "^7", 1); DropPlayer(playerId, cfg.KickMessage or "Kicked by Anti-Cheat (AI)."); return end
                end
            else Log("^1[NexusGuard] AI verification process returned nil verdict for " .. playerName .. "^7", 1) end
        else Log("^1[NexusGuard] AI enabled but ProcessAIVerification function not found!^7", 1) end
    end
    --]]

    -- Rule-based Actions
    if cfg.Actions then
        local confirmed = serverValidated or NexusGuardServer.Detections.IsConfirmedCheat(detectionType, detectionData)
        local highRisk = NexusGuardServer.Detections.IsHighRisk(detectionType, detectionData)

        if cfg.Actions.banOnConfirmed and confirmed then
            local banReason = (serverValidated and 'Server-confirmed cheat: ' or 'Confirmed cheat: ') .. detectionType
            Log("^1[NexusGuard] " .. (serverValidated and 'Server-Confirmed' or 'Confirmed') .. " Cheat Ban Triggered for " .. playerName .. "^7", 1)
            NexusGuardServer.Bans.Execute(playerId, banReason)
            return
        elseif cfg.Actions.kickOnSuspicion and highRisk then
             Log("^1[NexusGuard] High Risk Kick Triggered for " .. playerName .. "^7", 1)
             if cfg.ScreenCapture and cfg.ScreenCapture.enabled and cfg.ScreenCapture.includeWithReports and _G.EventRegistry then _G.EventRegistry.TriggerClientEvent('ADMIN_REQUEST_SCREENSHOT', playerId) end
             DropPlayer(playerId, cfg.KickMessage or "Kicked for suspicious activity.")
             return
        elseif cfg.ScreenCapture and cfg.ScreenCapture.enabled and cfg.ScreenCapture.includeWithReports and (highRisk or confirmed) then
             Log("^2[NexusGuard] Requesting screenshot for high risk/confirmed detection: " .. playerName .. "^7", 2)
             if _G.EventRegistry then _G.EventRegistry.TriggerClientEvent('ADMIN_REQUEST_SCREENSHOT', playerId) end
        end

        if cfg.Actions.reportToAdminsOnSuspicion and NexusGuardServer.EventHandlers.NotifyAdmins then
            local notifyData = detectionData; if type(notifyData) ~= "table" then notifyData = { clientData = notifyData } end
            notifyData.serverValidated = serverValidated
            NexusGuardServer.EventHandlers.NotifyAdmins(playerId, detectionType, notifyData)
        end
    end

    -- Discord Log
    if NexusGuardServer.Discord.Send then
        local discordData = detectionData; if type(discordData) ~= "table" then discordData = { clientData = discordData } end
        discordData.serverValidated = serverValidated
        local dataStr = (json and json.encode(discordData)) or "{}"
        local alertTitle = (serverValidated and 'Server-Confirmed Detection Alert' or 'Detection Alert')
        NexusGuardServer.Discord.Send("general", alertTitle, playerName .. ' (ID: '..playerId..') - Type: ' .. detectionType .. ' - Data: ' .. dataStr, cfg.Discord.webhooks and cfg.Discord.webhooks.general)
    end
end

-- #############################################################################
-- ## Discord Module ##
-- #############################################################################
NexusGuardServer.Discord = {}

function NexusGuardServer.Discord.Send(category, title, message, specificWebhook)
    local discordConfig = NexusGuardServer.Config and NexusGuardServer.Config.Discord
    if not discordConfig or not discordConfig.enabled then return end

    local webhookURL = specificWebhook
    if not webhookURL then
        if discordConfig.webhooks and category and discordConfig.webhooks[category] and discordConfig.webhooks[category] ~= "" then webhookURL = discordConfig.webhooks[category]
        elseif NexusGuardServer.Config.DiscordWebhook and NexusGuardServer.Config.DiscordWebhook ~= "" then webhookURL = NexusGuardServer.Config.DiscordWebhook
        else return end -- No valid webhook URL found
    end

    if not PerformHttpRequest then Log("^1Error: PerformHttpRequest native not available.^7", 1); return end
    if not json then Log("^1Error: JSON library not available for SendToDiscord.^7", 1); return end

    local embed = {{ ["color"] = 16711680, ["title"] = "**[NexusGuard] " .. (title or "Alert") .. "**", ["description"] = message or "No details provided.", ["footer"] = { ["text"] = "NexusGuard | " .. os.date("%Y-%m-%d %H:%M:%S") } }}
    local payloadSuccess, payload = pcall(json.encode, { embeds = embed })
    if not payloadSuccess then Log("^1Error encoding Discord payload: " .. tostring(payload) .. "^7", 1); return end

    local success, err = pcall(PerformHttpRequest, webhookURL, function(errHttp, text, headers)
        if errHttp then Log("^1Error sending Discord webhook (Callback): " .. tostring(errHttp) .. "^7", 1) else Log("Discord notification sent: " .. title, 3) end
    end, 'POST', payload, { ['Content-Type'] = 'application/json' })
    if not success then Log("^1Error initiating Discord HTTP request: " .. tostring(err) .. "^7", 1) end
end

-- #############################################################################
-- ## Event Handlers Module (Server-Side Logic) ##
-- #############################################################################
NexusGuardServer.EventHandlers = {}

function NexusGuardServer.EventHandlers.HandleExplosion(sender, ev)
    local source = tonumber(sender)
    local metrics = NexusGuardServer.PlayerMetrics and NexusGuardServer.PlayerMetrics[source]
    if not source or source <= 0 or not metrics then return end
    if not ev or ev.explosionType == nil or ev.posX == nil or ev.posY == nil or ev.posZ == nil then Log("^1Warning: Received incomplete explosionEvent data from " .. source .. "^7", 1); return end

    local explosionType = ev.explosionType
    local position = vector3(ev.posX or 0, ev.posY or 0, ev.posZ or 0)
    if not metrics.explosions then metrics.explosions = {} end
    table.insert(metrics.explosions, { type = explosionType, position = position, time = os.time() })

    local recentCount, currentTime = 0, os.time()
    local tempExplosions = {}
    for i = #metrics.explosions, 1, -1 do
        local explosion = metrics.explosions[i]
        if currentTime - explosion.time < 10 then recentCount = recentCount + 1; table.insert(tempExplosions, 1, explosion) end
    end
    metrics.explosions = tempExplosions

    if recentCount > 5 then
        NexusGuardServer.Detections.Process(source, "explosionspam", { count = recentCount, period = "10s" })
    end
end

function NexusGuardServer.EventHandlers.HandleEntityCreation(entity)
    -- Placeholder - Requires careful implementation and filtering
    -- Log("Placeholder: HandleEntityCreation called for entity " .. entity, 4)
end

function NexusGuardServer.EventHandlers.NotifyAdmins(playerId, detectionType, detectionData)
    local playerName = GetPlayerName(playerId) or "Unknown (" .. playerId .. ")"
    if not json then Log("^1[NexusGuard] JSON library not available for NotifyAdmins.^7", 1); return end

    local dataString = "N/A"
    local successEncode, result = pcall(json.encode, detectionData)
    if successEncode then dataString = result else Log("^1[NexusGuard] Failed to encode detectionData for admin notification.^7", 1) end

    Log('^1[NexusGuard]^7 Admin Notify: ' .. playerName .. ' (ID: ' .. playerId .. ') - ' .. detectionType .. ' - Data: ' .. dataString .. "^7", 1)

    local adminCount = 0; for _ in pairs(_G.OnlineAdmins or {}) do adminCount = adminCount + 1 end -- Still need OnlineAdmins table from server_main for now
    if adminCount == 0 then Log("^3[NexusGuard] No admins online to notify.^7", 3); return end

    for adminId, _ in pairs(_G.OnlineAdmins or {}) do
        if GetPlayerName(adminId) then
             if _G.EventRegistry then -- EventRegistry is still likely global
                 _G.EventRegistry.TriggerClientEvent('ADMIN_NOTIFICATION', adminId, {
                    player = playerName, playerId = playerId, type = detectionType,
                    data = detectionData, timestamp = os.time()
                 })
             else Log("^1[NexusGuard] CRITICAL: _G.EventRegistry not found. Cannot send admin notification.^7", 1) end
        else if _G.OnlineAdmins then _G.OnlineAdmins[adminId] = nil end end -- Clean up disconnected admin
    end
end

-- #############################################################################
-- ## Initialization and Exports ##
-- #############################################################################

-- Expose the main server logic table
exports('GetNexusGuardServerAPI', function()
    return NexusGuardServer
end)

Log("NexusGuard globals refactored and helpers loaded.", 2)

-- Trigger initial DB load/check after globals are defined
Citizen.CreateThread(function()
    Citizen.Wait(500) -- Short delay to ensure Config is loaded
    NexusGuardServer.Database.Initialize()
end)
