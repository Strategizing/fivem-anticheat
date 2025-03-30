--[[
    NexusGuard Globals & Server-Side Helpers
    Contains shared functions and placeholder implementations.
    NOTE: Many functions here are placeholders requiring user implementation.
]]

-- Ensure JSON library is available (e.g., from oxmysql or another resource)
-- If using oxmysql, it usually provides json globally. Otherwise, add a dependency.
local json = json or _G.json

-- Simple logging utility
local function Log(message, level)
    level = level or 2
    -- Assuming Config.logLevel exists, otherwise default to showing level 2+
    local logLevel = (Config and Config.logLevel) or 2
    if logLevel >= level then
        print("[NexusGuard] " .. message)
    end
end

-- Global variable to hold the ban list (loaded from DB) - Now used as a cache
local BanCache = {}
local BanCacheExpiry = 0 -- Timestamp when cache expires
local BanCacheDuration = 300 -- Cache duration in seconds (5 minutes)

-- Database Initialization
function InitializeDatabase()
    if not Config or not Config.Database or not Config.Database.enabled then
        Log("Database integration disabled in config.", 2)
        return
    end

    if not MySQL then
        Log("^1Error: MySQL object not found. Ensure oxmysql is started before NexusGuard.^7", 1)
        return
    end

    Log("Initializing database schema...", 2)
    local schemaFile = LoadResourceFile(GetCurrentResourceName(), "sql/schema.sql")
    if not schemaFile then
        Log("^1Error: Could not load sql/schema.sql file.^7", 1)
        return
    end

    -- Split schema into individual statements (basic split on ';')
    local statements = {}
    for stmt in string.gmatch(schemaFile, "([^;]+)") do
        stmt = string.gsub(stmt, "^%s+", "") -- Trim leading whitespace
        stmt = string.gsub(stmt, "%s+$", "") -- Trim trailing whitespace
        if string.len(stmt) > 0 then
            table.insert(statements, stmt)
        end
    end

    -- Execute statements sequentially
    local function executeNext(index)
        if index > #statements then
            Log("Database schema check/creation complete.", 2)
            LoadBanList(true) -- Force load ban list after schema setup
            return
        end
        MySQL.Async.execute(statements[index], {}, function(affectedRows)
            -- Log("Executed schema statement " .. index, 4)
            executeNext(index + 1) -- Execute next statement regardless of success/failure
        end)
    end

    executeNext(1)
end

-- Ban list related functions (Database Driven)
function LoadBanList(forceReload)
    if not Config or not Config.Database or not Config.Database.enabled then return end

    local currentTime = os.time()
    if not forceReload and BanCacheExpiry > currentTime then
        -- Log("Using cached ban list.", 4)
        return -- Use cached version
    end

    Log("Loading ban list from database...", 2)
    MySQL.Async.fetchAll('SELECT * FROM nexusguard_bans WHERE expire_date IS NULL OR expire_date > NOW()', {}, function(bans)
        if bans then
            BanCache = bans
            BanCacheExpiry = currentTime + BanCacheDuration
            Log("Loaded " .. #BanCache .. " active bans from database.", 2)
        else
            Log("^1Error loading bans from database.^7", 1)
            BanCache = {} -- Clear cache on error
            BanCacheExpiry = 0
        end
    end)
end

-- Checks the ban cache
function IsPlayerBanned(license, ip, discordId)
    if not Config or not Config.Database or not Config.Database.enabled then
        -- If DB disabled, maybe fall back to a simple file check? For now, assume not banned.
        return false, nil
    end

    -- Trigger reload if cache expired (non-blocking)
    if BanCacheExpiry <= os.time() then
        LoadBanList(false)
    end

    for _, ban in ipairs(BanCache) do
        local identifiersMatch = false
        if license and ban.license == license then identifiersMatch = true end
        if ip and ban.ip == ip then identifiersMatch = true end
        if discordId and ban.discord == discordId then identifiersMatch = true end

        if identifiersMatch then
            return true, ban.reason or "No reason specified"
        end
    end
    return false, nil
end

-- Stores ban in the database
-- @param banData Table containing ban details (name, reason, license, ip, discord, admin, durationSeconds)
function StorePlayerBan(banData)
    if not Config or not Config.Database or not Config.Database.enabled then return end
    if not banData or not banData.license then
        Log("^1Error: Cannot store ban without player license.^7", 1)
        return
    end

    local expireDate = nil
    if banData.durationSeconds and banData.durationSeconds > 0 then
        expireDate = os.date("!%Y-%m-%d %H:%M:%S", os.time() + banData.durationSeconds)
    end

    MySQL.Async.execute(
        'INSERT INTO nexusguard_bans (name, license, ip, discord, reason, admin, expire_date) VALUES (@name, @license, @ip, @discord, @reason, @admin, @expire_date)',
        {
            ['@name'] = banData.name,
            ['@license'] = banData.license,
            ['@ip'] = banData.ip,
            ['@discord'] = banData.discord,
            ['@reason'] = banData.reason,
            ['@admin'] = banData.admin or "NexusGuard System",
            ['@expire_date'] = expireDate
        },
        function(affectedRows)
            if affectedRows > 0 then
                Log("Ban for " .. banData.name .. " stored in database.", 2)
                LoadBanList(true) -- Force reload ban cache
            else
                Log("^1Error storing ban for " .. banData.name .. " in database.^7", 1)
            end
        end
    )
end

-- Bans a player and stores the ban
-- @param playerId The server ID of the player to ban.
-- @param reason The reason for the ban.
-- @param adminName The name of the admin issuing the ban (optional, defaults to System).
-- @param durationSeconds Duration of the ban in seconds (optional, permanent if nil).
function BanPlayer(playerId, reason, adminName, durationSeconds)
    local playerName = GetPlayerName(playerId)
    if not playerName then
        Log("^1Error: Cannot ban invalid player ID: " .. playerId .. "^7", 1)
        return
    end

    local license = GetPlayerIdentifierByType(playerId, 'license')
    local ip = GetPlayerEndpoint(playerId)
    local discord = GetPlayerIdentifierByType(playerId, 'discord')

    local banData = {
        name = playerName,
        license = license,
        ip = string.gsub(ip or "", "ip:", ""), -- Remove ip: prefix if present
        discord = discord,
        reason = reason or "Banned by NexusGuard",
        admin = adminName or "NexusGuard System",
        durationSeconds = durationSeconds
    }

    -- Store the ban (which will also update cache)
    StorePlayerBan(banData)

    -- Kick the player
    local banMessage = Config.BanMessage or "You have been banned."
    if durationSeconds and durationSeconds > 0 then
        local durationText = FormatDuration(durationSeconds) -- Requires FormatDuration helper
        banMessage = banMessage .. " Duration: " .. durationText
    end
    DropPlayer(playerId, banMessage)

    Log("^1Banned player: " .. playerName .. " (ID: " .. playerId .. ") Reason: " .. banData.reason .. "^7", 1)

    -- Send Discord notification
    if _G.SendToDiscord then
        local discordMsg = string.format(
            "**Player Banned**\n**Name:** %s\n**License:** %s\n**IP:** %s\n**Discord:** %s\n**Reason:** %s\n**Admin:** %s",
            playerName, license or "N/A", ip or "N/A", discord or "N/A", banData.reason, banData.admin
        )
        if durationSeconds and durationSeconds > 0 then
             discordMsg = discordMsg .. "\n**Duration:** " .. FormatDuration(durationSeconds)
        end
         _G.SendToDiscord("Player Banned", discordMsg)
    end
end


-- Player related functions
-- Checks if a player has admin privileges based on Config.AdminGroups
-- @param playerId The server ID of the player to check.
-- @return boolean True if the player is considered an admin, false otherwise.
function IsPlayerAdmin(playerId)
    -- Ensure Config and AdminGroups are loaded
    if not Config or not Config.AdminGroups then
        Log("^1Warning: Config.AdminGroups not found for IsPlayerAdmin check.^7", 1)
        return false -- Default to false if config is missing
    end
    -- Ensure playerId is valid and player exists
    local player = tonumber(playerId)
    if not player or player <= 0 or not GetPlayerName(player) then return false end

    -- Check using FiveM's built-in ACE permissions
    for _, group in ipairs(Config.AdminGroups) do
        if IsPlayerAceAllowed(player, "group." .. group) then
            return true
        end
    end

    -- Add framework-specific checks if needed (examples commented out)
    --[[
        -- Example ESX:
        local ESX = exports['es_extended']:getSharedObject() -- Adjust export name if needed
        if ESX then
            local xPlayer = ESX.GetPlayerFromId(player)
            if xPlayer then
                 for _, group in ipairs(Config.AdminGroups) do
                     if xPlayer.getGroup() == group then return true end
                 end
            end
        end

        -- Example QBCore:
        local QBCore = exports['qb-core']:GetCoreObject()
        if QBCore then
            local qbPlayer = QBCore.Functions.GetPlayer(player)
            if qbPlayer then
                 for _, group in ipairs(Config.AdminGroups) do
                     -- Check QBCore job/gang groups or ACE perms depending on setup
                     if qbPlayer.PlayerData.job.name == group and qbPlayer.PlayerData.job.isboss then return true end -- Example job check
                     -- Or check qbPlayer.PlayerData.permission or similar based on your permission setup
                 end
            end
        end
    ]]

    return false
end


-- #############################################################################
-- ## CRITICAL SECURITY WARNING ##
-- The following security functions are INSECURE PLACEHOLDERS.
-- They offer minimal protection against determined attackers.
-- You MUST replace these with a robust, server-authoritative implementation
-- (e.g., using HMAC signing, proper session management) for real security.
-- #############################################################################

-- Placeholder: Client hash validation - Generally considered ineffective.
-- @param hash The client-provided hash string.
-- @return boolean Always returns true in this placeholder implementation after basic checks.
function ValidateClientHash(hash)
    -- Log("^1SECURITY WARNING: Client hash validation is generally ineffective and easily bypassed.^7", 1)
    -- Consider removing this check entirely.
    return hash and type(hash) == "string" and string.len(hash) > 10
end

-- Basic pseudo-HMAC function (NOT CRYPTOGRAPHICALLY SECURE)
-- Uses simple string hashing as a stand-in for real HMAC-SHA256
local function PseudoHmac(key, message)
    -- Very basic hashing - replace with real crypto if possible
    local hash = 0
    for i = 1, string.len(message) do
        hash = (hash * 31 + string.byte(message, i)) % 1000000007
    end
    for i = 1, string.len(key) do
        hash = (hash * 31 + string.byte(key, i)) % 1000000007
    end
    return tostring(hash)
end

-- Generates a time-based token using pseudo-HMAC
-- @param playerId The server ID of the player requesting a token.
-- @return string A token string containing timestamp and hash, or nil on error.
function GenerateSecurityToken(playerId)
    if not Config or not Config.SecuritySecret or Config.SecuritySecret == "CHANGE_THIS_TO_A_VERY_LONG_RANDOM_SECRET_STRING" then
        Log("^1SECURITY ERROR: Config.SecuritySecret is not set or is default. Cannot generate secure token.^7", 1)
        return nil
    end
    local timestamp = os.time()
    local message = tostring(playerId) .. ":" .. tostring(timestamp)
    local hash = PseudoHmac(Config.SecuritySecret, message)
    local token = message .. ":" .. hash

    -- Store the generated token's timestamp for validation window
    if _G.PlayerMetrics and _G.PlayerMetrics[playerId] then
        _G.PlayerMetrics[playerId].lastTokenTime = timestamp
    end
    -- Log("Generated token for " .. playerId .. ": " .. token, 4) -- Debugging only
    return token
end

-- Validates a time-based token using pseudo-HMAC
-- @param playerId The server ID of the player sending the token.
-- @param token The token string sent by the client.
-- @return boolean True if the token is valid and within the time window, false otherwise.
function ValidateSecurityToken(playerId, token)
    if not Config or not Config.SecuritySecret or Config.SecuritySecret == "CHANGE_THIS_TO_A_VERY_LONG_RANDOM_SECRET_STRING" then
        Log("^1SECURITY ERROR: Config.SecuritySecret is not set or is default. Cannot validate token.^7", 1)
        return false
    end
    if not token or type(token) ~= "string" then return false end

    -- Split token into parts: playerID:timestamp:hash
    local parts = {}
    for part in string.gmatch(token, "[^:]+") do
        table.insert(parts, part)
    end

    if #parts ~= 3 then
        Log("^1Invalid token format received from " .. playerId .. "^7", 1)
        return false
    end

    local receivedPlayerId = tonumber(parts[1])
    local receivedTimestamp = tonumber(parts[2])
    local receivedHash = parts[3]

    -- Basic validation
    if not receivedPlayerId or receivedPlayerId ~= playerId or not receivedTimestamp or not receivedHash then
        Log("^1Invalid token content received from " .. playerId .. "^7", 1)
        return false
    end

    -- Check timestamp window (e.g., +/- 60 seconds)
    local currentTime = os.time()
    local timeDifference = math.abs(currentTime - receivedTimestamp)
    local maxTimeDifference = 60 -- Allow 1 minute difference
    if timeDifference > maxTimeDifference then
        Log("^1Token timestamp mismatch for " .. playerId .. ". Diff: " .. timeDifference .. "s^7", 1)
        return false
    end

    -- Regenerate the expected hash
    local message = tostring(playerId) .. ":" .. tostring(receivedTimestamp)
    local expectedHash = PseudoHmac(Config.SecuritySecret, message)

    -- Compare hashes
    if expectedHash == receivedHash then
        -- Log("Token validated successfully for " .. playerId, 4) -- Debugging only
        return true
    else
        Log("^1Token hash mismatch for " .. playerId .. "^7", 1)
        return false
    end
end

-- #############################################################################
-- ## END SECURITY WARNING ##
-- #############################################################################


-- Detection related functions (Placeholders/Examples)
-- Placeholder: Needs refinement based on actual detection logic
-- @param detectionType String identifier of the detection (e.g., "godmode").
-- @return number An arbitrary severity score.
function GetDetectionSeverity(detectionType)
    -- Example severities, adjust based on impact and confidence
    local severities = {
        godmode = 50,
        speedhack = 30,
        weaponmodification = 40, -- Match detector name
        teleporting = 25,       -- Match detector name
        noclip = 45,
        resourceinjection = 75, -- Match detector name (from config key)
        entityspam = 35,
        explosionspam = 40,
        menudetection = 60
        -- Add other detection types here
    }
    return severities[string.lower(detectionType)] or 20 -- Default severity
end

-- Determines if a detection warrants immediate action (kick/screenshot) based on type.
-- @param detectionType String identifier of the detection.
-- @param detectionData Table containing details about the detection.
-- @return boolean True if considered high risk, false otherwise.
function IsHighRiskDetection(detectionType, detectionData)
    -- This is a basic implementation. Refine based on server needs and detection data.
    local dtLower = string.lower(detectionType or "")
    local highRiskTypes = {
        ["resourceinjection"] = true, -- Assumed high risk
        ["menudetection"] = true,     -- Assumed high risk
        ["explosionspam"] = true,
        ["entityspam"] = true,        -- Add entity spam check
        ["godmode"] = true,           -- Persistent godmode is high risk
        ["noclip"] = true             -- Persistent noclip is high risk
    }
    -- Add checks based on detectionData if needed (e.g., high confidence score)
    -- Example: if dtLower == "speedhack" and detectionData and detectionData.multiplier > 2.0 then return true end
    return highRiskTypes[dtLower] or false
end

-- Determines if a detection warrants an automatic ban based on type.
-- @param detectionType String identifier of the detection.
-- @param detectionData Table containing details about the detection.
-- @return boolean True if considered a confirmed cheat (warrants ban), false otherwise.
function IsConfirmedCheat(detectionType, detectionData)
    -- This is a basic implementation. Refine based on server needs and detection data.
    local dtLower = string.lower(detectionType or "")
    local confirmedCheatTypes = {
        ["resourceinjection"] = true -- Assume server-verified resource injection is confirmed
        -- Add other types that are considered definitively cheating without needing AI/multiple flags
    }
    -- Add checks based on detectionData if needed
    -- Example: if dtLower == "weaponmodification" and detectionData and detectionData.damageMultiplier > 5.0 then return true end
    return confirmedCheatTypes[dtLower] or false
end

-- Stores a detection event in the database
function StoreDetection(playerId, detectionType, detectionData)
    if not Config or not Config.Database or not Config.Database.enabled or not Config.Database.storeDetectionHistory then return end
    if not MySQL then return end -- DB not available
    if not playerId or not detectionType then return end

    local playerName = GetPlayerName(playerId) or "Unknown"
    local license = GetPlayerIdentifierByType(playerId, 'license')
    local ip = GetPlayerEndpoint(playerId)

    -- Ensure JSON library is available
    if not json then
        Log("^1Error: JSON library not available for StoreDetection.^7", 1)
        return
    end

    local dataJson = "{}"
    local successEncode, result = pcall(json.encode, detectionData)
    if successEncode then
        dataJson = result
    else
        Log("^1Warning: Failed to encode detectionData for storage. Storing empty JSON. Error: " .. tostring(result) .. "^7", 1)
    end

    MySQL.Async.execute(
        'INSERT INTO nexusguard_detections (player_name, player_license, player_ip, detection_type, detection_data) VALUES (@name, @license, @ip, @type, @data)',
        {
            ['@name'] = playerName,
            ['@license'] = license,
            ['@ip'] = string.gsub(ip or "", "ip:", ""), -- Remove ip: prefix
            ['@type'] = detectionType,
            ['@data'] = dataJson
        },
        function(affectedRows)
            if affectedRows <= 0 then
                Log("^1Error storing detection event for player " .. playerId .. "^7", 1)
            -- else
                -- Log("Stored detection event: " .. detectionType .. " for player " .. playerId, 4) -- Optional debug log
            end
        end
    )
end
_G.StoreDetection = StoreDetection -- Expose globally


-- #############################################################################
-- ## AI Function Placeholders ##
-- These require a dedicated AI model and implementation.
-- #############################################################################

-- Placeholder: Needs actual feature engineering for your chosen AI model.
-- @param metrics Player's current metrics table.
-- @param detectionType String identifier of the detection.
-- @param detectionData Table containing details about the detection.
-- @return table A feature vector suitable for your AI model.
function BuildFeatureVector(metrics, detectionType, detectionData)
    Log("Placeholder: Building feature vector", 3)
    -- IMPLEMENTATION REQUIRED: Extract relevant features based on your AI model's needs.
    local featureVector = {
        warningCount = metrics and metrics.warningCount or 0,
        detectionCount = metrics and #(metrics.detections or {}) or 0,
        playTime = metrics and (os.time() - (metrics.connectTime or os.time())) or 0,
        trustScore = metrics and metrics.trustScore or 100,
        detectionType = detectionType
        -- Add more features based on detection data and metrics
    }
    return featureVector
end

-- Placeholder: Needs actual AI model inference.
-- @param featureVector The feature vector generated by BuildFeatureVector.
-- @return number An anomaly score (e.g., 0.0 to 1.0).
function CalculateAnomalyScore(featureVector)
    Log("Placeholder: Calculating anomaly score", 3)
    -- IMPLEMENTATION REQUIRED: Use your loaded anomaly detection model.
    -- Example placeholder logic:
    local score = 0.3
    if featureVector.warningCount > 1 then score = score + 0.1 end
    if featureVector.detectionCount > 2 then score = score + 0.2 end
    if featureVector.trustScore < 70 then score = score + 0.15 end
    return math.min(score, 1.0)
end

-- Placeholder: Needs actual AI model inference.
-- @param featureVector The feature vector.
-- @param behaviorProfile Stored behavior profile for the player (if used).
-- @return table Containing AI verdict (confidence, action suggestion, etc.).
function AnalyzeBehaviorPattern(featureVector, behaviorProfile)
    Log("Placeholder: Analyzing behavior pattern", 3)
    -- IMPLEMENTATION REQUIRED: Use your loaded behavior analysis model.
    -- Example placeholder logic:
    return {
        confidence = 0.4,
        suspicious = featureVector.warningCount > 0 or featureVector.detectionCount > 1,
        reasoning = "Placeholder behavior analysis"
    }
end

-- Placeholder: Needs implementation to fetch/update models from a source.
function UpdateAIModels()
    Log("Placeholder: Checking for AI model updates...", 2)
    -- IMPLEMENTATION REQUIRED: Logic to download/update AI model files if needed.
    Log("Placeholder: AI models are up to date", 2)
end

-- #############################################################################
-- ## End AI Placeholders ##
-- #############################################################################


-- Event handling functions (Example implementations)
function HandleExplosionEvent(sender, ev)
    -- Ensure sender and metrics exist
    if not sender or sender <= 0 or not _G.PlayerMetrics or not _G.PlayerMetrics[sender] then return end
    -- Ensure event data is valid
    if not ev or not ev.explosionType then return end

    local metrics = _G.PlayerMetrics[sender]
    local explosionType = ev.explosionType
    local position = vector3(ev.posX or 0, ev.posY or 0, ev.posZ or 0)

    -- Track explosions
    if not metrics.explosions then metrics.explosions = {} end
    table.insert(metrics.explosions, { type = explosionType, position = position, time = os.time() })

    -- Check for spam (e.g., > 5 in 10 seconds)
    local recentCount = 0
    local currentTime = os.time()
    local tempExplosions = {} -- Keep track of non-expired explosions
    for i = #metrics.explosions, 1, -1 do -- Iterate backwards for safe removal/filtering
        local explosion = metrics.explosions[i]
        if currentTime - explosion.time < 10 then
            recentCount = recentCount + 1
            table.insert(tempExplosions, 1, explosion) -- Keep this one (insert at beginning if order matters)
        end
    end
    metrics.explosions = tempExplosions -- Update table to only contain recent ones

    if recentCount > 5 then
        -- Ensure ProcessDetection is available globally
        if _G.ProcessDetection then
            _G.ProcessDetection(sender, "explosionspam", { count = recentCount, period = "10s" })
        else
            Log("^1Error: ProcessDetection function not found!^7", 1)
        end
    end
end

-- Placeholder: Needs implementation - Be VERY careful with performance here.
-- @param entity The handle of the created entity.
function HandleEntityCreation(entity)
    -- This requires careful implementation to avoid performance issues
    -- and false positives. Consider what entities are relevant to track (e.g., specific props, vehicles).
    -- Avoid tracking every single entity. Filter by type or model hash.
    -- Log("Placeholder: HandleEntityCreation called for entity " .. entity, 3)
    --[[
        IMPLEMENTATION REQUIRED (Example structure):
        local entityType = GetEntityType(entity)
        local model = GetEntityModel(entity)
        -- Check if model is blacklisted or type is suspicious
        if IsModelBlacklisted(model) then
             local owner = NetworkGetEntityOwner(entity)
             if owner > 0 then
                 ProcessDetection(owner, "blacklistedentity", { model = model })
             end
        end
        -- Add spam checks similar to HandleExplosionEvent if needed
    ]]
end


-- Utility functions
-- Placeholder: Needs actual database implementation if enabled.
-- This function might be better suited for specific analysis rather than generic collection.
function CollectPlayerMetrics()
    -- if not Config or not Config.Database or not Config.Database.enabled then return end
    -- Log("Placeholder: Collecting player metrics...", 3)
    -- IMPLEMENTATION REQUIRED: Logic to periodically gather and potentially store
    -- aggregated metrics in the database for analysis or long-term tracking.
    -- Example: Iterate through online players, calculate average trust score, etc.
end

-- Deletes old detection records from the database
function CleanupDetectionHistory()
    if not Config or not Config.Database or not Config.Database.enabled or not Config.Database.historyDuration or Config.Database.historyDuration <= 0 then
        return -- Disabled or invalid duration
    end
    if not MySQL then return end -- DB not available

    local historyDays = Config.Database.historyDuration
    Log("Cleaning up detection history older than " .. historyDays .. " days...", 3)

    MySQL.Async.execute(
        'DELETE FROM nexusguard_detections WHERE timestamp < DATE_SUB(NOW(), INTERVAL @days DAY)',
        { ['@days'] = historyDays },
        function(affectedRows)
            if affectedRows > 0 then
                Log("Cleaned up " .. affectedRows .. " old detection records.", 2)
            else
                -- Log("No old detection records found to clean up.", 4)
            end
        end
    )
end

-- Saves player session summary to the database on disconnect
-- @param playerId Server ID of the player whose metrics should be saved.
function SavePlayerMetrics(playerId)
    if not Config or not Config.Database or not Config.Database.enabled then return end
    if not _G.PlayerMetrics or not _G.PlayerMetrics[playerId] then return end
    if not MySQL then return end -- DB not available

    local metrics = _G.PlayerMetrics[playerId]
    local playerName = GetPlayerName(playerId) or "Unknown"
    local license = GetPlayerIdentifierByType(playerId, 'license')
    if not license then
        Log("^1Warning: Cannot save metrics for player " .. playerId .. " without license identifier.^7", 1)
        return
    end

    local connectTime = metrics.connectTime or os.time() -- Fallback if connectTime wasn't set
    local playTime = os.time() - connectTime
    local finalTrustScore = metrics.trustScore or 100.0
    local totalDetections = #(metrics.detections or {})
    local totalWarnings = metrics.warningCount or 0 -- Assuming warningCount is tracked

    Log("Saving session metrics for player " .. playerId .. " (" .. playerName .. ")", 3)

    MySQL.Async.execute(
        'INSERT INTO nexusguard_sessions (player_name, player_license, connect_time, play_time_seconds, final_trust_score, total_detections, total_warnings) VALUES (@name, @license, FROM_UNIXTIME(@connect), @playtime, @trust, @detections, @warnings)',
        {
            ['@name'] = playerName,
            ['@license'] = license,
            ['@connect'] = connectTime,
            ['@playtime'] = playTime,
            ['@trust'] = finalTrustScore,
            ['@detections'] = totalDetections,
            ['@warnings'] = totalWarnings
        },
        function(affectedRows)
            if affectedRows > 0 then
                Log("Session metrics saved for player " .. playerId, 3)
            else
                Log("^1Error saving session metrics for player " .. playerId .. "^7", 1)
            end
        end
    )
end


-- Discord related functions
function SendToDiscord(title, message)
    -- Check if logging and webhook URL are enabled/set
    if not Config or not Config.EnableDiscordLogs or not Config.DiscordWebhook or Config.DiscordWebhook == "" then
        return
    end

    local webhookURL = Config.DiscordWebhook
    local embed = {
        {
            ["color"] = 16711680, -- Red
            ["title"] = "**[NexusGuard] " .. (title or "Alert") .. "**",
            ["description"] = message or "No details provided.",
            ["footer"] = {
                ["text"] = "NexusGuard | " .. os.date("%Y-%m-%d %H:%M:%S")
            }
        }
    }

    -- Ensure JSON library is available
    if not json then
        Log("^1Error: JSON library not available for SendToDiscord.^7", 1)
        return
    end

    local payloadSuccess, payload = pcall(json.encode, { embeds = embed })
    if not payloadSuccess then
        Log("^1Error encoding Discord payload: " .. tostring(payload) .. "^7", 1)
        return
    end

    -- Perform the HTTP request asynchronously
    PerformHttpRequest(webhookURL, function(err, text, headers)
        if err then
            Log("^1Error sending Discord webhook: " .. tostring(err) .. "^7", 1)
        else
            Log("Discord notification sent: " .. title, 3)
        end
    end, 'POST', payload, { ['Content-Type'] = 'application/json' })
end


-- Helper to safely get players list
function SafeGetPlayers()
    local success, players = pcall(GetPlayers)
    if success and type(players) == "table" then
        return players
    end
    return {}
end


-- Exports for potential external use (Keep minimal and specific)
-- Note: Avoid exporting sensitive functions like BanPlayer directly if possible,
-- prefer command-based access or specific integration points.
exports('GetNexusGuardAPI', function()
    return {
        -- Expose specific, safe functions if needed by other resources
        -- Example: Check if a player is currently flagged (requires implementation)
        -- isPlayerFlagged = function(playerId) ... end,

        -- Allow reporting from other resources (requires careful validation server-side)
        -- reportSuspiciousActivity = function(reporterId, targetId, reason) ... end
    }
end)

-- Expose necessary functions globally if needed by server_main (consider alternatives)
-- These were previously defined in server_main or expected globally
_G.InitializeDatabase = InitializeDatabase
_G.LoadBanList = LoadBanList
-- SaveBanList removed (DB driven)
_G.IsPlayerBanned = IsPlayerBanned
_G.StorePlayerBan = StorePlayerBan
_G.BanPlayer = BanPlayer -- Expose the new BanPlayer function
_G.IsPlayerAdmin = IsPlayerAdmin
_G.ValidateClientHash = ValidateClientHash
_G.GenerateSecurityToken = GenerateSecurityToken
_G.ValidateSecurityToken = ValidateSecurityToken
_G.GetDetectionSeverity = GetDetectionSeverity
_G.IsHighRiskDetection = IsHighRiskDetection
_G.IsConfirmedCheat = IsConfirmedCheat
_G.BuildFeatureVector = BuildFeatureVector
_G.CalculateAnomalyScore = CalculateAnomalyScore
_G.AnalyzeBehaviorPattern = AnalyzeBehaviorPattern
_G.UpdateAIModels = UpdateAIModels
_G.HandleExplosionEvent = HandleExplosionEvent
_G.HandleEntityCreation = HandleEntityCreation
_G.CollectPlayerMetrics = CollectPlayerMetrics
_G.CleanupDetectionHistory = CleanupDetectionHistory
_G.SavePlayerMetrics = SavePlayerMetrics
_G.SendToDiscord = SendToDiscord
-- Helper function to format duration (add this)
function FormatDuration(totalSeconds)
    if not totalSeconds or totalSeconds <= 0 then return "Permanent" end

    local days = math.floor(totalSeconds / 86400)
    local hours = math.floor((totalSeconds % 86400) / 3600)
    local minutes = math.floor((totalSeconds % 3600) / 60)
    local seconds = math.floor(totalSeconds % 60)

    local parts = {}
    if days > 0 then table.insert(parts, days .. "d") end
    if hours > 0 then table.insert(parts, hours .. "h") end
    if minutes > 0 then table.insert(parts, minutes .. "m") end
    if seconds > 0 or #parts == 0 then table.insert(parts, seconds .. "s") end -- Show seconds if it's the only unit or non-zero

    return table.concat(parts, " ")
end
_G.FormatDuration = FormatDuration -- Expose globally if needed elsewhere

_G.SafeGetPlayers = SafeGetPlayers
_G.Log = Log -- Expose Log function if needed elsewhere

Log("NexusGuard globals and helpers loaded.", 2)

-- Trigger initial DB load/check after globals are defined
Citizen.CreateThread(function()
    Citizen.Wait(500) -- Short delay to ensure Config is loaded
    InitializeDatabase()
end)
