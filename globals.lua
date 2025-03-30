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

-- Initialize PlayerMetrics globally if it doesn't exist
_G.PlayerMetrics = _G.PlayerMetrics or {}

-- Database Initialization (Uses oxmysql)
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
    -- Ensure LoadResourceFile is available (should be standard)
    local successLoad, schemaFile = pcall(LoadResourceFile, GetCurrentResourceName(), "sql/schema.sql")
    if not successLoad or not schemaFile then
        Log("^1Error: Could not load sql/schema.sql file. Error: " .. tostring(schemaFile) .. "^7", 1)
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
        -- Wrap DB call in pcall
        local success, err = pcall(MySQL.Async.execute, statements[index], {})
        if not success then
            Log(string.format("^1Error executing schema statement %d: %s^7", index, tostring(err)), 1)
        end
        -- Execute next statement regardless of individual success/failure
        executeNext(index + 1)
    end

    executeNext(1) -- Start execution
end

-- Ban list related functions (Database Driven)
function LoadBanList(forceReload)
    if not Config or not Config.Database or not Config.Database.enabled then return end
    if not MySQL then return end -- DB not available

    local currentTime = os.time()
    if not forceReload and BanCacheExpiry > currentTime then
        -- Log("Using cached ban list.", 4)
        return -- Use cached version
    end

    Log("Loading ban list from database...", 2)
    -- Wrap DB call in pcall
    local success, bans = pcall(MySQL.Async.fetchAll, 'SELECT * FROM nexusguard_bans WHERE expire_date IS NULL OR expire_date > NOW()', {})

    if success and type(bans) == "table" then
        BanCache = bans
        BanCacheExpiry = currentTime + BanCacheDuration
        Log("Loaded " .. #BanCache .. " active bans from database.", 2)
    elseif not success then
        Log(string.format("^1Error loading bans from database: %s^7", tostring(bans)), 1) -- 'bans' holds error message on pcall failure
        BanCache = {} -- Clear cache on error
        BanCacheExpiry = 0
    else
        -- Query succeeded but returned nil/unexpected result
        Log("^1Warning: Received unexpected result while loading bans from database.^7", 1)
        BanCache = {} -- Clear cache
        BanCacheExpiry = 0
    end
end

-- Checks the ban cache
function IsPlayerBanned(license, ip, discordId)
    -- Always check cache even if DB is disabled (might have been loaded previously)
    -- Trigger reload if cache expired (non-blocking, only if DB enabled)
    if Config and Config.Database and Config.Database.enabled and BanCacheExpiry <= os.time() then
        LoadBanList(false) -- Request reload, but don't block
    end

    -- Check the current cache regardless of expiry status
    for _, ban in ipairs(BanCache) do
        local identifiersMatch = false
        -- Ensure ban record has the necessary fields before comparing
        if license and ban.license and ban.license == license then identifiersMatch = true end
        if ip and ban.ip and ban.ip == ip then identifiersMatch = true end
        if discordId and ban.discord and ban.discord == discordId then identifiersMatch = true end

        if identifiersMatch then
            return true, ban.reason or "No reason specified"
        end
    end
    return false, nil
end

-- Stores ban in the database
-- @param banData Table containing ban details (name, reason, license, ip, discord, admin, durationSeconds)
function StorePlayerBan(banData)
    if not Config or not Config.Database or not Config.Database.enabled then
        Log("Attempted to store ban while Database is disabled.", 3)
        return
    end
    if not MySQL then
        Log("^1Error: MySQL object not found. Cannot store ban.^7", 1)
        return
    end
    if not banData or not banData.license then
        Log("^1Error: Cannot store ban without player license identifier.^7", 1)
        return
    end

    local expireDate = nil
    if banData.durationSeconds and banData.durationSeconds > 0 then
        expireDate = os.date("!%Y-%m-%d %H:%M:%S", os.time() + banData.durationSeconds)
    end

    -- Wrap DB call in pcall
    local success, result = pcall(MySQL.Async.execute,
        'INSERT INTO nexusguard_bans (name, license, ip, discord, reason, admin, expire_date) VALUES (@name, @license, @ip, @discord, @reason, @admin, @expire_date)',
        {
            ['@name'] = banData.name,
            ['@license'] = banData.license,
            ['@ip'] = banData.ip,
            ['@discord'] = banData.discord,
            ['@reason'] = banData.reason,
            ['@admin'] = banData.admin or "NexusGuard System",
            ['@expire_date'] = expireDate
        }
    )

    if success then
        -- Check affectedRows from the result if needed (result might be number of affected rows or nil)
        if result and result > 0 then
             Log("Ban for " .. banData.name .. " stored in database.", 2)
             LoadBanList(true) -- Force reload ban cache
        else
             Log("^1Warning: Storing ban for " .. banData.name .. " reported 0 affected rows.^7", 1)
        end
    else
        Log(string.format("^1Error storing ban for %s in database: %s^7", banData.name, tostring(result)), 1) -- 'result' holds error message
    end
end

-- Bans a player and stores the ban
-- @param playerId The server ID of the player to ban.
-- @param reason The reason for the ban.
-- @param adminName The name of the admin issuing the ban (optional, defaults to System).
-- @param durationSeconds Duration of the ban in seconds (optional, permanent if nil).
function BanPlayer(playerId, reason, adminName, durationSeconds)
    local source = tonumber(playerId)
    if not source or source <= 0 then
        Log("^1Error: Invalid player ID provided to BanPlayer: " .. tostring(playerId) .. "^7", 1)
        return
    end
    local playerName = GetPlayerName(source)
    if not playerName then
        Log("^1Error: Cannot ban player ID: " .. source .. " - Player not found.^7", 1)
    end

    -- Fetch identifiers safely
    local license = GetPlayerIdentifierByType(source, 'license')
    local ip = GetPlayerEndpoint(source)
    local discord = GetPlayerIdentifierByType(source, 'discord')

    if not license then
        Log("^1Warning: Could not get license identifier for player " .. source .. ". Ban might be less effective.^7", 1)
        -- Decide if you want to proceed without a license? For now, we will.
    end

    local banData = {
        name = playerName,
        license = license,
        ip = ip and string.gsub(ip, "ip:", "") or nil, -- Remove ip: prefix if present, handle nil case
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
    DropPlayer(source, banMessage)

    Log("^1Banned player: " .. playerName .. " (ID: " .. source .. ") Reason: " .. banData.reason .. "^7", 1)

    -- Send Discord notification (Check SendToDiscord exists)
    if _G.SendToDiscord then
        local ipDisplay = banData.ip or "N/A"
        local discordDisplay = banData.discord or "N/A"
        local licenseDisplay = banData.license or "N/A"
        local discordMsg = string.format(
            "**Player Banned**\n**Name:** %s\n**License:** %s\n**IP:** %s\n**Discord:** %s\n**Reason:** %s\n**Admin:** %s",
            playerName, licenseDisplay, ipDisplay, discordDisplay, banData.reason, banData.admin
        )
        if durationSeconds and durationSeconds > 0 then
             discordMsg = discordMsg .. "\n**Duration:** " .. FormatDuration(durationSeconds)
        end
         _G.SendToDiscord("Bans", discordMsg, Config.Discord.webhooks and Config.Discord.webhooks.bans) -- Use specific ban webhook if configured
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
        IMPLEMENTATION REQUIRED: Uncomment and adapt ONE of the following blocks
        if you are using ESX or QBCore and want to check framework groups.
        Ensure the export name is correct for your framework version.

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
        -- Ensure the export name 'qb-core' and the path to player data/permissions are correct for your version.
        local QBCore = exports['qb-core']:GetCoreObject()
        if QBCore then
            local qbPlayer = QBCore.Functions.GetPlayer(player)
            if qbPlayer then
                 for _, group in ipairs(Config.AdminGroups) do
                     -- Option 1: Check QBCore permission system (Recommended if using qb-adminmenu or similar)
                     -- if QBCore.Functions.HasPermission(player, group) then return true end

                     -- Option 2: Check job/gang and grade/isboss (Adapt to your specific setup)
                     -- if qbPlayer.PlayerData.job.name == group and qbPlayer.PlayerData.job.isboss then return true end
                     -- if qbPlayer.PlayerData.gang.name == group and qbPlayer.PlayerData.gang.isboss then return true end
                 end
            end
        end
    ]]

    -- Default: If no ACE permission or framework check matches, they are not considered admin by this function.
    return false
end


-- #############################################################################
-- ####################################################################################################
-- ##                                                                                                ##
-- ##   ███████╗ ███████╗  ██████╗ ██╗   ██╗ ███████╗ ██╗   ██╗ ███████╗ ██╗ ███████╗ ███╗   ███╗    ##
-- ##   ██╔════╝ ██╔════╝ ██╔════╝ ██║   ██║ ██╔════╝ ██║   ██║ ██╔════╝ ██║ ██╔════╝ ████╗ ████║    ##
-- ##   ███████╗ ███████╗ ██║  ███╗ ██║   ██║ ███████╗ ██║   ██║ ███████╗ ██║ ███████╗ ██╔████╔██║    ##
-- ##   ╚════██║ ╚════██║ ██║   ██║ ██║   ██║ ╚════██║ ██║   ██║ ╚════██║ ██║ ╚════██║ ██║╚██╔╝██║    ##
-- ##   ███████║ ███████║ ╚██████╔╝ ╚██████╔╝ ███████║ ╚██████╔╝ ███████║ ██║ ███████║ ██║ ╚═╝ ██║    ##
-- ##   ╚══════╝ ╚══════╝  ╚═════╝   ╚═════╝  ╚══════╝  ╚═════╝  ╚══════╝ ╚═╝ ╚══════╝ ╚═╝     ╚═╝    ##
-- ##                                                                                                ##
-- ##   The following security functions (ValidateClientHash, GenerateSecurityToken,                 ##
-- ##   ValidateSecurityToken, PseudoHmac) are **HIGHLY INSECURE PLACEHOLDERS/EXAMPLES**.            ##
-- ##   They offer **ZERO REAL PROTECTION** against event spoofing or malicious actors.              ##
-- ##                                                                                                ##
-- ##   **DO NOT USE THESE IN A PRODUCTION ENVIRONMENT WITHOUT REPLACING THEM ENTIRELY**             ##
-- ##   with a robust, server-authoritative implementation. Examples include:                        ##
-- ##     - **HMAC-SHA256 Signing:** Use Config.SecuritySecret with a proper Lua crypto library      ##
-- ##       (like lua-lockbox, lua-resty-hmac, or potentially built-in functions if using           ##
-- ##       frameworks like ox_lib) to sign data sent between client and server. The server         ##
-- ##       generates a signature, the client includes it, and the server verifies it upon receipt.  ##
-- ##     - **Secure Session Tokens:** Generate cryptographically secure random tokens server-side,  ##
-- ##       associate them with the player's session, send to the client, and require the client     ##
-- ##       to send this token with sensitive events. Validate the token server-side.                ##
-- ##     - **Framework Secure Events:** If your framework (e.g., newer ESX/QBCore versions)         ##
-- ##       provides built-in mechanisms for secure events, leverage those instead.                  ##
-- ##                                                                                                ##
-- ##   Relying on these placeholders **WILL LEAVE YOUR SERVER EXTREMELY VULNERABLE** to event       ##
-- ##   spoofing, allowing cheaters to trigger bans/kicks on others or bypass detections.            ##
-- ##   You **MUST** implement proper security measures yourself.                                    ##
-- ##                                                                                                ##
-- ####################################################################################################

-- Basic pseudo-HMAC function (**EXAMPLE ONLY - NOT CRYPTOGRAPHICALLY SECURE**)
-- This is **NOT** a real HMAC and provides **NO** security guarantees. Replace with proper crypto.
local function PseudoHmac(key, message)
    Log("^1SECURITY RISK: Using insecure PseudoHmac function. Replace with proper crypto (e.g., HMAC-SHA256). This offers NO real security.^7", 1)
    local hash = 0
    -- Simple hashing, easily predictable/breakable
    for i = 1, string.len(message) do hash = (hash * 31 + string.byte(message, i)) % 1000000007 end
    for i = 1, string.len(key) do hash = (hash * 31 + string.byte(key, i)) % 1000000007 end
    return tostring(hash)
end

-- Generates a time-based token using the **INSECURE** pseudo-HMAC example.
-- **THIS IS NOT SECURE. REPLACE THIS FUNCTION.**
function GenerateSecurityToken(playerId)
    Log("^1SECURITY RISK: Using insecure placeholder GenerateSecurityToken. Replace immediately.^7", 1)
    if not Config or not Config.SecuritySecret or Config.SecuritySecret == "CHANGE_THIS_TO_A_VERY_LONG_RANDOM_SECRET_STRING" then
        Log("^1SECURITY ERROR: Config.SecuritySecret is not set or is default. Cannot generate placeholder token.^7", 1)
        return nil
    end
    local timestamp = os.time()
    local message = tostring(playerId) .. ":" .. tostring(timestamp)
    local hash = PseudoHmac(Config.SecuritySecret, message) -- Uses insecure hash
    local token = message .. ":" .. hash

    -- Store the generated token's timestamp for validation window (part of the insecure mechanism)
    if _G.PlayerMetrics and _G.PlayerMetrics[playerId] then
        _G.PlayerMetrics[playerId].lastTokenTime = timestamp
    end
    return token
end

-- Validates a time-based token using the **INSECURE** pseudo-HMAC example.
-- **THIS IS NOT SECURE. REPLACE THIS FUNCTION.**
function ValidateSecurityToken(playerId, token)
    Log("^1SECURITY RISK: Using insecure placeholder ValidateSecurityToken. Replace immediately.^7", 1)
    if not Config or not Config.SecuritySecret or Config.SecuritySecret == "CHANGE_THIS_TO_A_VERY_LONG_RANDOM_SECRET_STRING" then
        Log("^1SECURITY ERROR: Config.SecuritySecret is not set or is default. Cannot validate placeholder token.^7", 1)
        return false
    end
    if not token or type(token) ~= "string" then
        Log("^1Invalid token type received from " .. playerId .. "^7", 1)
        return false
    end

    -- Split token into parts: playerID:timestamp:hash
    local parts = {}
    for part in string.gmatch(token, "[^:]+") do table.insert(parts, part) end

    if #parts ~= 3 then
        Log("^1Invalid token format received from " .. playerId .. " ('" .. token .. "')^7", 1)
        return false
    end

    local receivedPlayerId = tonumber(parts[1])
    local receivedTimestamp = tonumber(parts[2])
    local receivedHash = parts[3]

    -- Basic validation
    if not receivedPlayerId or receivedPlayerId ~= playerId or not receivedTimestamp or not receivedHash then
        Log("^1Invalid token content received from " .. playerId .. " (PlayerID mismatch or missing parts)^7", 1)
        return false
    end

    -- Check timestamp window (e.g., +/- 60 seconds) - This is easily bypassed if attacker controls timestamp
    local currentTime = os.time()
    local timeDifference = math.abs(currentTime - receivedTimestamp)
    local maxTimeDifference = 60 -- Allow 1 minute difference (adjust as needed, but doesn't fix underlying insecurity)
    if timeDifference > maxTimeDifference then
        Log("^1Token timestamp mismatch for " .. playerId .. ". Diff: " .. timeDifference .. "s (Current: " .. currentTime .. ", Received: " .. receivedTimestamp .. ")^7", 1)
        return false
    end

    -- Regenerate the expected hash using the insecure function
    local message = tostring(playerId) .. ":" .. tostring(receivedTimestamp)
    local expectedHash = PseudoHmac(Config.SecuritySecret, message) -- Uses insecure hash

    -- Compare hashes
    if expectedHash == receivedHash then
        return true -- Token appears valid according to the *insecure* method
    else
        Log("^1Token hash mismatch for " .. playerId .. ". Expected: " .. expectedHash .. ", Received: " .. receivedHash .. "^7", 1)
        return false
    end
end

-- #############################################################################
-- ## END SECURITY WARNING BLOCK ##
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
    if not Config or not Config.Database or not Config.Database.enabled or not Config.Database.storeDetectionHistory then
        -- Log("Database storage for detections disabled.", 4)
        return
    end
    if not MySQL then
        Log("^1Error: MySQL object not found. Cannot store detection.^7", 1)
        return
    end
    if not playerId or playerId <= 0 or not detectionType then
        Log("^1Error: Invalid player ID or detection type provided to StoreDetection.^7", 1)
        return
    end

    local playerName = GetPlayerName(playerId) or "Unknown (" .. playerId .. ")"
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

    -- Wrap DB call in pcall
    local success, dbResult = pcall(MySQL.Async.execute,
        'INSERT INTO nexusguard_detections (player_name, player_license, player_ip, detection_type, detection_data) VALUES (@name, @license, @ip, @type, @data)',
        {
            ['@name'] = playerName,
            ['@license'] = license,
            ['@ip'] = ip and string.gsub(ip, "ip:", "") or nil, -- Remove ip: prefix, handle nil
            ['@type'] = detectionType,
            ['@data'] = dataJson
        }
    )

    if not success then
         Log(string.format("^1Error storing detection event for player %s: %s^7", playerId, tostring(dbResult)), 1)
    elseif dbResult and dbResult <= 0 then
         Log("^1Warning: Storing detection event for player " .. playerId .. " reported 0 affected rows.^7", 1)
    -- else
         -- Log("Stored detection event: " .. detectionType .. " for player " .. playerId, 4) -- Optional debug log
    end
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
    local source = tonumber(sender)
    -- Ensure sender and metrics exist
    if not source or source <= 0 or not _G.PlayerMetrics or not _G.PlayerMetrics[source] then return end
    -- Ensure event data is valid (check required fields)
    if not ev or ev.explosionType == nil or ev.posX == nil or ev.posY == nil or ev.posZ == nil then
        Log("^1Warning: Received incomplete explosionEvent data from " .. source .. "^7", 1)
        return
    end

    local metrics = _G.PlayerMetrics[source]
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
            _G.ProcessDetection(source, "explosionspam", { count = recentCount, period = "10s" })
        else
            Log("^1Error: _G.ProcessDetection function not found! Cannot report explosion spam.^7", 1)
        end
    end
end

-- Placeholder: Needs implementation - **USE WITH EXTREME CAUTION DUE TO PERFORMANCE IMPACT.**
-- Tracking all entity creations can severely impact server performance.
-- If implemented, it MUST be heavily filtered to only track specific, high-risk entity models or types.
-- @param entity The handle of the created entity.
function HandleEntityCreation(entity)
    -- Log("Placeholder: HandleEntityCreation called for entity " .. entity, 4) -- Debug log only
    --[[
        IMPLEMENTATION REQUIRED (Example structure - Requires heavy filtering):
        local entityType = GetEntityType(entity)
        local model = GetEntityModel(entity)
        -- Check if model is blacklisted or type is suspicious
        if IsModelBlacklisted(model) then -- Requires IsModelBlacklisted function
             local owner = NetworkGetEntityOwner(entity)
             if owner > 0 then
                 if _G.ProcessDetection then
                     _G.ProcessDetection(owner, "blacklistedentity", { model = model })
                 else
                     Log("^1Error: ProcessDetection function not found!^7", 1)
                 end
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
        -- Log("Detection history cleanup disabled or duration not set.", 4)
        return
    end
    if not MySQL then
        Log("^1Error: MySQL object not found. Cannot cleanup detection history.^7", 1)
        return
    end

    local historyDays = Config.Database.historyDuration
    Log("Cleaning up detection history older than " .. historyDays .. " days...", 2)

    -- Wrap DB call in pcall
    local success, result = pcall(MySQL.Async.execute,
        'DELETE FROM nexusguard_detections WHERE timestamp < DATE_SUB(NOW(), INTERVAL @days DAY)',
        { ['@days'] = historyDays }
    )

    if success then
        if result and result > 0 then
            Log("Cleaned up " .. result .. " old detection records.", 2)
        -- else
            -- Log("No old detection records found to clean up.", 4)
        end
    else
        Log(string.format("^1Error cleaning up detection history: %s^7", tostring(result)), 1)
    end
end

-- Saves player session summary to the database on disconnect
-- @param playerId Server ID of the player whose metrics should be saved.
function SavePlayerMetrics(playerId)
    local source = tonumber(playerId)
    if not source or source <= 0 then
        Log("^1Error: Invalid player ID provided to SavePlayerMetrics: " .. tostring(playerId) .. "^7", 1)
        return
    end

    if not Config or not Config.Database or not Config.Database.enabled then
        -- Log("Database saving for session metrics disabled.", 4)
        return
    end
    if not _G.PlayerMetrics or not _G.PlayerMetrics[source] then
        Log("^1Warning: PlayerMetrics not found for player " .. source .. " on disconnect. Cannot save session.^7", 1)
        return
    end
     if not MySQL then
        Log("^1Error: MySQL object not found. Cannot save session metrics for player " .. source .. ".^7", 1)
        return
    end

    local metrics = _G.PlayerMetrics[source]
    local playerName = GetPlayerName(source) or "Unknown (" .. source .. ")"
    local license = GetPlayerIdentifierByType(source, 'license')
    if not license then
        Log("^1Warning: Cannot save metrics for player " .. source .. " without license identifier. Skipping save.^7", 1)
    end

    local connectTime = metrics.connectTime or os.time() -- Fallback if connectTime wasn't set properly
    local playTime = math.max(0, os.time() - connectTime) -- Ensure playtime isn't negative
    local finalTrustScore = metrics.trustScore or 100.0 -- Default to 100 if missing
    local totalDetections = #(metrics.detections or {})
    local totalWarnings = metrics.warningCount or 0 -- Assuming warningCount is tracked

    Log("Saving session metrics for player " .. playerId .. " (" .. playerName .. ")", 3)

    -- Wrap DB call in pcall
    local success, result = pcall(MySQL.Async.execute,
        'INSERT INTO nexusguard_sessions (player_name, player_license, connect_time, play_time_seconds, final_trust_score, total_detections, total_warnings) VALUES (@name, @license, FROM_UNIXTIME(@connect), @playtime, @trust, @detections, @warnings)',
        {
            ['@name'] = playerName,
            ['@license'] = license,
            ['@connect'] = connectTime, -- Store as UNIX timestamp
            ['@playtime'] = playTime,
            ['@trust'] = finalTrustScore,
            ['@detections'] = totalDetections,
            ['@warnings'] = totalWarnings
        }
    )

    if success then
        if result and result > 0 then
            Log("Session metrics saved for player " .. source, 3)
        else
            Log("^1Warning: Saving session metrics for player " .. source .. " reported 0 affected rows.^7", 1)
        end
    else
        Log(string.format("^1Error saving session metrics for player %s: %s^7", source, tostring(result)), 1)
    end
end


-- Discord related functions
-- @param category Optional category to determine webhook URL (e.g., "bans", "kicks", "general")
-- @param specificWebhook Optional direct webhook URL to override config lookup
function SendToDiscord(category, title, message, specificWebhook)
    -- Check if Discord integration is enabled at all
    if not Config or not Config.Discord or not Config.Discord.enabled then return end

    -- Determine the webhook URL
    local webhookURL = specificWebhook -- Use specific URL if provided
    if not webhookURL then
        if Config.Discord.webhooks and category and Config.Discord.webhooks[category] and Config.Discord.webhooks[category] ~= "" then
            webhookURL = Config.Discord.webhooks[category]
        elseif Config.DiscordWebhook and Config.DiscordWebhook ~= "" then
            webhookURL = Config.DiscordWebhook -- Fallback to general webhook
        else
            -- Log("Discord webhook not configured for category '" .. (category or "general") .. "' and no general webhook set.", 3)
            return -- No valid webhook URL found
        end
    end

    -- Check if PerformHttpRequest is available
    if not PerformHttpRequest then
        Log("^1Error: PerformHttpRequest native not available. Cannot send Discord message.^7", 1)
        return
    end
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

    -- Perform the HTTP request asynchronously, wrapped in pcall
    local success, err = pcall(PerformHttpRequest, webhookURL, function(errHttp, text, headers)
        if errHttp then
            Log("^1Error sending Discord webhook (Callback): " .. tostring(errHttp) .. "^7", 1)
        else
            Log("Discord notification sent: " .. title, 3)
        end
    end, 'POST', payload, { ['Content-Type'] = 'application/json' })

    if not success then
         Log("^1Error initiating Discord HTTP request: " .. tostring(err) .. "^7", 1)
    end
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
-- _G.ValidateClientHash = ValidateClientHash -- Removed as it's ineffective
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
