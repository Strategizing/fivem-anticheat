--[[
    FiveM Anti-Cheat System
    Global definitions and configurations
]]

-- Configuration settings
AC = {}
AC.config = {
    enabled = true,
    debugMode = false,
    banEnabled = true,
    kickEnabled = true,
    maxWarnings = 3,
    detectionThreshold = 0.85,
    screenCaptureEnabled = true,
    logLevel = 2, -- 0: None, 1: Critical, 2: Normal, 3: Debug
}

-- Detection types
AC.detectionTypes = {
    SPEEDHACK = 1,
    TELEPORT = 2,
    WEAPON_HACK = 3,
    GOD_MODE = 4,
    RESOURCE_INJECTION = 5,
    ENTITY_SPAWNING = 6,
    MENU_DETECTION = 7,
    BLACKLISTED_EVENT = 8,
    BLACKLISTED_COMMAND = 9,
    UNAUTHORIZED_RESOURCE = 10
}

-- Action types
AC.actionTypes = {
    WARN = 1,
    KICK = 2,
    BAN = 3,
    LOG = 4
}

-- Utility functions
AC.utils = {}

-- Format and log messages
AC.utils.log = function(message, level)
    level = level or 2
    if AC.config.logLevel >= level then
        print("[FiveM-AntiCheat] " .. message)
    end
end

-- Tracking data
AC.players = {}
AC.suspiciousPlayers = {}
AC.banList = {}

-- Events
AC.events = {
    detection = "anticheat:detection",
    action = "anticheat:action",
    screenCapture = "anticheat:screencapture",
    adminNotify = "anticheat:adminNotify"
}

-- NexusGuard global functions
if not _G.NexusGuard then
    _G.NexusGuard = {}
end

-- Ban list related functions
function LoadBanList()
    local banListJson = LoadResourceFile(GetCurrentResourceName(), "data/banlist.json")
    if banListJson then
        BanList = json.decode(banListJson) or {}
        AC.utils.log("Loaded " .. #BanList .. " bans from database", 2)
    else
        BanList = {}
        AC.utils.log("No existing ban list found, creating new one", 2)
        SaveBanList()
    end
end

function SaveBanList()
    local banListJson = json.encode(BanList)
    SaveResourceFile(GetCurrentResourceName(), "data/banlist.json", banListJson, -1)
    AC.utils.log("Ban list saved with " .. #BanList .. " entries", 3)
end

function IsPlayerBanned(license, ip)
    if not BanList then return false end
    
    for _, ban in ipairs(BanList) do
        for _, identifier in ipairs(ban.identifiers or {}) do
            if identifier == license or identifier == "ip:" .. ip then
                return true
            end
        end
    end
    return false
end

function StorePlayerBan(banData)
    if Config.Database.enabled then
        -- Database implementation would go here
        AC.utils.log("Stored player ban in database: " .. banData.name, 2)
    end
end

-- Player related functions
function IsPlayerAdmin(playerId)
    for _, group in ipairs(Config.AdminGroups) do
        if IsPlayerAceAllowed(playerId, "group." .. group) then
            return true
        end
    end
    return false
end

-- Security related functions
function ValidateClientHash(hash)
    -- In a real implementation, this would validate against expected values
    return hash and string.len(hash) > 10
end

function GenerateSecurityToken(playerId)
    local token = GetPlayerName(playerId) .. "_" .. os.time() .. "_" .. math.random(100000, 999999)
    -- In a real implementation, you'd want to store this somewhere secure
    -- For now, we'll store it in the player metrics
    if PlayerMetrics[playerId] then
        PlayerMetrics[playerId].securityToken = token
    end
    return token
end

function ValidateSecurityToken(playerId, token)
    if not PlayerMetrics[playerId] then return false end
    return PlayerMetrics[playerId].securityToken == token
end

-- Detection related functions
function GetDetectionSeverity(detectionType)
    local severities = {
        godmode = 50,
        speedhack = 30,
        weaponmod = 40,
        teleport = 25,
        noclip = 45,
        resourcehack = 75,
        entityspam = 35,
        explosionspam = 40,
        menudetection = 60
    }
    
    return severities[string.lower(detectionType)] or 20 -- Default severity
end

function IsHighRiskDetection(detectionType, detectionData)
    local highRiskTypes = {
        "godmode",
        "menudetection",
        "resourcehack"
    }
    
    for _, hrt in ipairs(highRiskTypes) do
        if string.lower(detectionType) == hrt then
            return true
        end
    end
    
    -- Check data for high risk indicators
    if detectionData and type(detectionData) == "table" then
        if detectionData.confidence and detectionData.confidence > 0.8 then
            return true
        end
        
        if detectionData.severity and detectionData.severity > 40 then
            return true
        end
    end
    
    return false
end

function IsConfirmedCheat(detectionType, detectionData)
    -- Detections that are always confirmed cheats
    local confirmedTypes = {
        "resourcehack",
        "injectiondetected",
        "menudetected"
    }
    
    for _, ct in ipairs(confirmedTypes) do
        if string.lower(detectionType) == ct then
            return true
        end
    end
    
    -- Check data for confirmation
    if detectionData and type(detectionData) == "table" then
        if detectionData.confirmed == true then
            return true
        end
        
        if detectionData.confidence and detectionData.confidence > 0.9 then
            return true
        end
    end
    
    return false
end

-- AI related functions
function BuildFeatureVector(metrics, detectionType, detectionData)
    -- This would extract relevant features for AI analysis
    local featureVector = {
        warningCount = metrics.warningCount or 0,
        detectionCount = #(metrics.detections or {}),
        playTime = os.time() - (metrics.connectTime or os.time()),
        trustScore = metrics.trustScore or 100,
        detectionType = detectionType,
        -- Add more features based on detection data
    }
    
    return featureVector
end

function CalculateAnomalyScore(featureVector)
    -- In a real implementation, this would use the AI model to calculate an anomaly score
    -- For now, return a simple score based on basic metrics
    local score = 0.3 -- baseline score
    
    if featureVector.warningCount > 2 then
        score = score + 0.2
    end
    
    if featureVector.detectionCount > 3 then
        score = score + 0.3
    end
    
    if featureVector.trustScore < 50 then
        score = score + 0.2
    end
    
    return math.min(score, 1.0) -- Cap at 1.0
end

function AnalyzeBehaviorPattern(featureVector, behaviorProfile)
    -- This would analyze the player's behavior pattern using the AI model
    -- For now, return a simple verdict
    return {
        confidence = 0.5,
        suspicious = featureVector.warningCount > 1,
        reasoning = "Behavior analysis based on " .. featureVector.detectionCount .. " detections"
    }
end

function UpdateAIModels()
    AC.utils.log("Checking for AI model updates...", 2)
    -- In a real implementation, this would update the AI models
    -- For now, just log a message
    AC.utils.log("AI models are up to date", 2)
end

-- Event handling functions
function HandleExplosionEvent(sender, ev)
    -- Check for explosion spam or illegal explosions
    if ev and PlayerMetrics[sender] then
        local explosionType = ev.explosionType
        local position = vector3(ev.posX, ev.posY, ev.posZ)
        
        -- Track explosions in player metrics
        if not PlayerMetrics[sender].explosions then
            PlayerMetrics[sender].explosions = {}
        end
        
        table.insert(PlayerMetrics[sender].explosions, {
            type = explosionType,
            position = position,
            time = os.time()
        })
        
        -- Check for explosion spam (more than 5 in 10 seconds)
        local recentExplosions = 0
        local currentTime = os.time()
        for _, explosion in ipairs(PlayerMetrics[sender].explosions) do
            if currentTime - explosion.time < 10 then
                recentExplosions = recentExplosions + 1
            end
        end
        
        if recentExplosions > 5 then
            ProcessDetection(sender, "explosionspam", { count = recentExplosions, period = "10s" })
        end
    end
end

function HandleEntityCreation(entity)
    if not entity then return end
    
    local entityType = GetEntityType(entity)
    local owner = NetworkGetEntityOwner(entity)
    
    if owner > 0 and PlayerMetrics[owner] then
        -- Track entity creation in player metrics
        if not PlayerMetrics[owner].entities then
            PlayerMetrics[owner].entities = {}
        end
        
        table.insert(PlayerMetrics[owner].entities, {
            type = entityType,
            time = os.time(),
            netId = NetworkGetNetworkIdFromEntity(entity)
        })
        
        -- Check for entity spam (more than 10 in 60 seconds)
        local recentEntities = 0
        local currentTime = os.time()
        for _, entityData in ipairs(PlayerMetrics[owner].entities) do
            if currentTime - entityData.time < 60 then
                recentEntities = recentEntities + 1
            end
        end
        
        if recentEntities > 10 then
            ProcessDetection(owner, "entityspam", { count = recentEntities, period = "60s" })
        end
    end
end

-- Utility functions
function CollectPlayerMetrics()
    for playerId, metrics in pairs(PlayerMetrics) do
        if GetPlayerName(playerId) then
            local ped = GetPlayerPed(playerId)
            if ped and DoesEntityExist(ped) then
                -- Update player position
                metrics.lastPosition = GetEntityCoords(ped)
                
                -- Update health data
                local health = GetEntityHealth(ped)
                table.insert(metrics.healthHistory, { health = health, time = os.time() })
                
                -- Limit history size
                if #metrics.healthHistory > 20 then
                    table.remove(metrics.healthHistory, 1)
                end
                
                -- Other metrics would be collected here
            end
        end
    end
end

function CleanupDetectionHistory()
    local currentTime = os.time()
    local threshold = currentTime - (Config.Database.historyDuration * 86400) -- Convert days to seconds
    
    for id, history in pairs(DetectionHistory) do
        local newHistory = {}
        for _, detection in ipairs(history) do
            if detection.timestamp > threshold then
                table.insert(newHistory, detection)
            end
        end
        DetectionHistory[id] = newHistory
    end
    
    AC.utils.log("Cleaned up detection history", 3)
end

function SavePlayerMetrics(playerId)
    if not Config.Database.enabled or not PlayerMetrics[playerId] then return end
    
    -- In a real implementation, this would save to a database
    -- For now, just log a message
    AC.utils.log("Saving metrics for player " .. playerId, 3)
end

-- Discord related functions
function SendToDiscord(title, message)
    if not Config.EnableDiscordLogs then return end
    
    if Config.DiscordWebhook and Config.DiscordWebhook ~= "" then
        local embed = {
            {
                ["color"] = 16711680, -- Red
                ["title"] = title,
                ["description"] = message,
                ["footer"] = {
                    ["text"] = "NexusGuard Anti-Cheat | " .. os.date("%Y-%m-%d %H:%M:%S")
                }
            }
        }
        
        PerformHttpRequest(Config.DiscordWebhook, function(err, text, headers) end, 'POST', json.encode({ embeds = embed }), { ['Content-Type'] = 'application/json' })
    end
end

-- Export globals for other resources
exports('getAntiCheatConfig', function()
    return AC.config
end)

exports('getAntiCheatUtils', function()
    return AC.utils
end)

exports('getNexusGuardAPI', function()
    return {
        banPlayer = BanPlayer,
        isPlayerBanned = IsPlayerBanned,
        sendToDiscord = SendToDiscord
    }
end)
