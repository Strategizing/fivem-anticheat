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

-- Global variable to hold the ban list (loaded from file)
local BanList = {}

-- Ban list related functions
function LoadBanList()
    local success, banListJson = pcall(LoadResourceFile, GetCurrentResourceName(), "data/banlist.json")
    if success and banListJson then
        -- Ensure json library is available before decoding
        if not json then
            Log("^1Error: JSON library not available for LoadBanList.^7", 1)
            BanList = {}
            return
        end
        local decodeSuccess, decodedList = pcall(json.decode, banListJson)
        if decodeSuccess then
            BanList = decodedList or {}
            Log("Loaded " .. #BanList .. " bans from data/banlist.json", 2)
        else
            Log("^1Error decoding banlist.json: " .. tostring(decodedList) .. "^7", 1)
            BanList = {}
        end
    else
        BanList = {}
        Log("No existing ban list found (data/banlist.json), creating new one.", 2)
        -- Ensure SaveBanList exists before calling recursively, or handle differently
        if _G.SaveBanList then
             SaveBanList() -- Attempt to save an empty one
        else
             Log("^1Warning: SaveBanList not defined when trying to create initial ban list.^7", 1)
        end
    end
end

function SaveBanList()
    -- Ensure json library is available before encoding
    if not json then
        Log("^1Error: JSON library not available for SaveBanList.^7", 1)
        return
    end
    local encodeSuccess, banListJson = pcall(json.encode, BanList)
    if encodeSuccess then
        local saveSuccess, err = pcall(SaveResourceFile, GetCurrentResourceName(), "data/banlist.json", banListJson, -1)
        if saveSuccess then
            Log("Ban list saved with " .. #BanList .. " entries", 3)
        else
            Log("^1Error saving banlist.json: " .. tostring(err) .. "^7", 1)
        end
    else
        Log("^1Error encoding ban list: " .. tostring(banListJson) .. "^7", 1)
    end
end

function IsPlayerBanned(license, ip)
    if not BanList then return false end

    for _, ban in ipairs(BanList) do
        -- Ensure ban.identifiers is a table before iterating
        if type(ban.identifiers) == "table" then
            for _, identifier in ipairs(ban.identifiers) do
                -- Ensure identifier is a string before comparing
                if type(identifier) == "string" and (identifier == license or identifier == "ip:" .. ip) then
                    return true, ban.reason or "No reason specified"
                end
            end
        end
    end
    return false, nil
end

-- Placeholder: Needs actual database implementation if enabled
-- @param banData Table containing ban details (name, reason, identifiers, etc.)
function StorePlayerBan(banData)
    if Config and Config.Database and Config.Database.enabled then
        Log("Placeholder: Storing player ban in database: " .. (banData and banData.name or "Unknown"), 2)
        --[[
            IMPLEMENTATION REQUIRED:
            Use oxmysql or your preferred DB library to insert ban details.
            Example using oxmysql (ensure MySQL object is available):
            local identifiersJson = json.encode(banData.identifiers or {})
            MySQL.Async.execute(
                'INSERT INTO nexusguard_bans (name, reason, identifiers, admin, date) VALUES (@name, @reason, @identifiers, @admin, NOW())',
                {
                    ['@name'] = banData.name,
                    ['@reason'] = banData.reason,
                    ['@identifiers'] = identifiersJson,
                    ['@admin'] = banData.admin
                },
                function(affectedRows)
                    if affectedRows > 0 then
                        Log("Ban for " .. banData.name .. " stored in database.", 3)
                    else
                        Log("^1Error storing ban for " .. banData.name .. " in database.^7", 1)
                    end
                end
            )
        ]]
        -- Example: MySQL.Async.execute('INSERT INTO nexusguard_bans ...', {banData.name, banData.reason, ...})
    end
end

-- Player related functions
-- Placeholder: Needs implementation based on your server's permission system.
-- @param playerId The server ID of the player to check.
-- @return boolean True if the player is considered an admin, false otherwise.
function IsPlayerAdmin(playerId)
    -- Ensure Config and AdminGroups are loaded
    if not Config or not Config.AdminGroups then
        Log("^1Warning: Config.AdminGroups not found for IsPlayerAdmin check.^7", 1)
        -- Default to false if config is missing
        return false
    end
    -- Ensure playerId is valid
    if not playerId or tonumber(playerId) == nil then return false end

    for _, group in ipairs(Config.AdminGroups) do
    -- Check if IsPlayerAceAllowed exists before calling (for built-in ACE perms)
    if _G.IsPlayerAceAllowed and IsPlayerAceAllowed(playerId, "group." .. group) then
        return true
        --[[
            ALTERNATIVE IMPLEMENTATION (Example for ESX/QBCore):
            Replace the IsPlayerAceAllowed check with framework-specific checks.
            Example ESX:
            local xPlayer = ESX.GetPlayerFromId(playerId)
            if xPlayer and xPlayer.getGroup() == group then return true end

            Example QBCore:
            local QBCore = exports['qb-core']:GetCoreObject()
            local player = QBCore.Functions.GetPlayer(playerId)
            if player and player.PlayerData.job.name == group then return true end -- Or check ACE groups if using qb-adminmenu
        ]]
    end
    end
    return false
end


-- #############################################################################
-- ## CRITICAL SECURITY WARNING ##
-- The following security functions are INSECURE PLACEHOLDERS.
-- They offer minimal protection against determined attackers.
-- You MUST replace these with a robust, server-authoritative implementation
-- (e.g., using HMAC signing, proper session management) for real security.
-- #############################################################################

-- Placeholder: Insecure client hash validation - DO NOT USE IN PRODUCTION
-- @param hash The client-provided hash string.
-- @return boolean Always returns true in this placeholder implementation after basic checks.
function ValidateClientHash(hash)
    Log("^1SECURITY WARNING: Using insecure placeholder ValidateClientHash. This provides NO real security.^7", 1)
    -- This basic check is easily bypassed. A real implementation is complex and often futile.
    -- Consider removing client hash checks entirely unless you have a specific, robust method.
    return hash and type(hash) == "string" and string.len(hash) > 10
end

-- Placeholder: Insecure token generation - DO NOT USE IN PRODUCTION
-- @param playerId The server ID of the player requesting a token.
-- @return string An insecure, predictable token.
function GenerateSecurityToken(playerId)
    Log("^1SECURITY WARNING: Using insecure placeholder GenerateSecurityToken. This is NOT secure.^7", 1)
    -- This token is predictable and not cryptographically secure.
    -- A real implementation should use HMAC signing or similar server-authoritative methods.
    local insecureToken = GetPlayerName(playerId) .. "_" .. os.time() .. "_" .. math.random(100000, 999999)
    -- Storing token directly in PlayerMetrics is also insecure if metrics are accessible/modifiable.
    if _G.PlayerMetrics and _G.PlayerMetrics[playerId] then
        _G.PlayerMetrics[playerId].securityToken = insecureToken
    end
    return insecureToken
end

-- Placeholder: Insecure token validation - DO NOT USE IN PRODUCTION
-- @param playerId The server ID of the player sending the token.
-- @param token The token string sent by the client.
-- @return boolean True if the insecure token matches the stored one, false otherwise.
function ValidateSecurityToken(playerId, token)
    Log("^1SECURITY WARNING: Using insecure placeholder ValidateSecurityToken. This provides NO real security.^7", 1)
    -- This simply compares the received token with the insecurely stored one. It does not prevent spoofing.
    if not _G.PlayerMetrics or not _G.PlayerMetrics[playerId] then return false end
    -- Add basic type check for token
    if type(token) ~= "string" then return false end
    return _G.PlayerMetrics[playerId].securityToken == token
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

-- Placeholder: Needs refinement based on actual detection logic and severity
-- @param detectionType String identifier of the detection.
-- @param detectionData Table containing details about the detection.
-- @return boolean True if considered high risk, false otherwise.
function IsHighRiskDetection(detectionType, detectionData)
    Log("Placeholder check: IsHighRiskDetection for " .. detectionType, 3)
    -- Example: Consider resource injection and high-confidence menu detection high risk
    -- IMPLEMENTATION REQUIRED: Define which detections warrant immediate action (kick/screenshot).
    local highRiskTypes = {
        "resourceinjection",
        "menudetection"
    }
    local dtLower = string.lower(detectionType)

    for _, hrt in ipairs(highRiskTypes) do
        if dtLower == hrt then
            -- Add confidence check for menu detection maybe?
            return true
        end
    end
    return false
end

-- Placeholder: Needs refinement based on actual detection logic and severity
-- @param detectionType String identifier of the detection.
-- @param detectionData Table containing details about the detection.
-- @return boolean True if considered a confirmed cheat (warrants ban), false otherwise.
function IsConfirmedCheat(detectionType, detectionData)
    Log("Placeholder check: IsConfirmedCheat for " .. detectionType, 3)
    -- Example: Assume resource injection is always confirmed (server verified)
    -- IMPLEMENTATION REQUIRED: Define which detections are severe enough for an automatic ban.
    if string.lower(detectionType) == "resourceinjection" then
        return true
    end
    -- Add other conditions based on data/confidence if needed
    return false
end


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
function CollectPlayerMetrics()
    if not Config or not Config.Database or not Config.Database.enabled then return end
    Log("Placeholder: Collecting player metrics...", 3)
    -- IMPLEMENTATION REQUIRED: Logic to periodically gather and potentially store
    -- aggregated metrics in the database for analysis or long-term tracking.
end

-- Placeholder: Needs actual database implementation if enabled.
function CleanupDetectionHistory()
    if not Config or not Config.Database or not Config.Database.enabled then return end
    Log("Placeholder: Cleaning up detection history...", 3)
    -- IMPLEMENTATION REQUIRED: Logic to delete old detection records from the database
    -- based on Config.Database.historyDuration.
    -- Example: MySQL.Async.execute('DELETE FROM nexusguard_detections WHERE timestamp < DATE_SUB(NOW(), INTERVAL @days DAY)', {['@days'] = Config.Database.historyDuration})
end

-- Placeholder: Needs actual database implementation if enabled.
-- @param playerId Server ID of the player whose metrics should be saved.
function SavePlayerMetrics(playerId)
    if not Config or not Config.Database or not Config.Database.enabled then return end
    if not _G.PlayerMetrics or not _G.PlayerMetrics[playerId] then return end
    Log("Placeholder: Saving metrics for player " .. playerId, 3)
    -- IMPLEMENTATION REQUIRED: Logic to save relevant player metrics (e.g., final trust score,
    -- total detections, playtime) to the database when they disconnect.
    -- Example: MySQL.Async.execute('INSERT INTO nexusguard_sessions (...) VALUES (...) ON DUPLICATE KEY UPDATE ...', {...})
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
_G.LoadBanList = LoadBanList
_G.SaveBanList = SaveBanList
_G.IsPlayerBanned = IsPlayerBanned
_G.StorePlayerBan = StorePlayerBan
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
_G.SafeGetPlayers = SafeGetPlayers
_G.Log = Log -- Expose Log function if needed elsewhere

Log("NexusGuard globals and helpers loaded.", 2)
