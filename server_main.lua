RegisterNetEvent('onResourceStart')

local NexusGuard = {}
local BanList = {}
local DetectionHistory = {}
local PlayerMetrics = {}
local AIModelCache = {}
local ClientsLoaded = {}
local OnlineAdmins = {} -- Table to store server IDs of online admins

-- Add this after loading configs
function ValidateConfig()
    -- Apply schema validation
    if ConfigValidator then
        Config = ConfigValidator.Apply(Config)
    else
        -- Fallback to basic validation
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
        
        print('^2[NexusGuard]^7 Basic configuration validation complete')
    end
end

-- Initialize the anti-cheat
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    print('^2[NexusGuard]^7 Initializing advanced anti-cheat system...')
    
    -- Ensure proper initialization sequence
    LoadBanList()
    ValidateConfig()
    InitializeAIModels()
    SetupScheduledTasks()
    
    -- Register server events
    RegisterServerEvents()
    
    print('^2[NexusGuard]^7 Anti-cheat system initialized successfully!')
end)

-- Player connected handler
AddEventHandler('playerConnecting', function(playerName, setKickReason, deferrals)
    local source = source
    local license = GetPlayerIdentifierByType(source, 'license')
    local ip = GetPlayerEndpoint(source)
    local isAdmin = IsPlayerAdmin(source) -- Check admin status early

    deferrals.defer()
    deferrals.update('Checking your profile against our anti-cheat database...')

    -- Check if player is banned
    Citizen.Wait(200) -- Reduced wait slightly
    if IsPlayerBanned(license, ip) then
        deferrals.done(Config.BanMessage)
        SendToDiscord('Connection Rejected', playerName .. ' attempted to connect but is banned')
        return
    end
    
    -- Initialize player metrics with proper structure
    PlayerMetrics[source] = {
        connectTime = os.time(),
        lastPosition = nil,
        warningCount = 0,
        detections = {},
        healthHistory = {},
        movementSamples = {},
        weaponStats = {},
        behaviorProfile = {},
        trustScore = 100.0,
        securityToken = nil,
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
end)

-- Player disconnected handler
AddEventHandler('playerDropped', function(reason)
    local source = source
    
    -- Save detection data to database if enabled
    if Config.Database and Config.Database.enabled and PlayerMetrics[source] then
        SavePlayerMetrics(source)
    end
    local playerName = GetPlayerName(source) or "Unknown"

    -- Clean up player data
    if PlayerMetrics[source] and PlayerMetrics[source].isAdmin then
        OnlineAdmins[source] = nil -- Remove from admin list
        print("^2[NexusGuard]^7 Admin disconnected: " .. playerName .. " (ID: " .. source .. ")")
    end
    PlayerMetrics[source] = nil
    ClientsLoaded[source] = nil
end)

-- Consolidated client security token handling
RegisterNetEvent('NexusGuard:RequestSecurityToken')
AddEventHandler('NexusGuard:RequestSecurityToken', function(clientHash)
    local source = source
    
    -- Verify client hash to ensure the client is running the correct version
    if ValidateClientHash(clientHash) then
        ClientsLoaded[source] = true
        local token = GenerateSecurityToken(source)
        TriggerClientEvent('NexusGuard:ReceiveSecurityToken', source, token)
        print('^2[NexusGuard]^7 Security token sent to ' .. GetPlayerName(source))
    else
        -- If client hash is invalid, player might be using a modified client
        BanPlayer(source, 'Modified client detected')
    end
end)

-- Consolidated detection event handling
RegisterNetEvent('NexusGuard:ReportCheat')
AddEventHandler('NexusGuard:ReportCheat', function(detectionType, detectionData, securityToken)
    local source = source
    
    -- Validate security token to prevent spoofed events
    if not ValidateSecurityToken(source, securityToken) then
        BanPlayer(source, 'Invalid security token')
        return
    end
    
    -- Process the detection
    ProcessDetection(source, detectionType, detectionData)
end)

-- For backwards compatibility - redirect to the main event handler
RegisterNetEvent('nexusguard:detection')
AddEventHandler('nexusguard:detection', function(detectionType, detectionData, securityToken)
    TriggerEvent('NexusGuard:ReportCheat', detectionType, detectionData, securityToken)
end)

-- Register event for resource verification
RegisterNetEvent('NexusGuard:VerifyResources')
AddEventHandler('NexusGuard:VerifyResources', function(resources)
    local source = source
    
    if not source or source <= 0 then return end
    
    -- Here you would implement resource validation logic
    -- For now, just log that we received the resources list
    print('^3[NexusGuard]^7 Received resource list from ' .. GetPlayerName(source) .. ' with ' .. #resources .. ' resources')
end)

-- Register client error event
RegisterNetEvent('NexusGuard:ClientError')
AddEventHandler('NexusGuard:ClientError', function(detectionName, errorMessage, securityToken)
    local source = source
    
    -- Validate security token to prevent spoofed events
    if not ValidateSecurityToken(source, securityToken) then
        -- Just log the error, don't ban for error reports
        print("^1[NexusGuard]^7 Invalid security token in error report from " .. GetPlayerName(source))
        return
    end
    
    print("^3[NexusGuard]^7 Client error in " .. detectionName .. " from " .. GetPlayerName(source) .. ": " .. errorMessage)
    
    -- Log the error
    if Config.EnableDiscordLogs then
        SendToDiscord('Client Error', 
            "Player: " .. GetPlayerName(source) .. "\n" ..
            "Detection: " .. detectionName .. "\n" ..
            "Error: " .. errorMessage
        )
    end
    
    -- Track client errors in player metrics
    if PlayerMetrics[source] then
        if not PlayerMetrics[source].clientErrors then
            PlayerMetrics[source].clientErrors = {}
        end
        
        table.insert(PlayerMetrics[source].clientErrors, {
            detection = detectionName,
            error = errorMessage,
            time = os.time()
        })
    end
end)

function ProcessDetection(playerId, detectionType, detectionData)
    -- Check for valid input
    if not playerId or not detectionType then return end
    
    local playerName = GetPlayerName(playerId) or "Unknown"
    
    -- Log the detection
    print('^1[NexusGuard]^7 Detection: ' .. playerName .. ' - ' .. detectionType)
    
    -- Record detection in player's history
    if PlayerMetrics[playerId] then
        table.insert(PlayerMetrics[playerId].detections, {
            type = detectionType,
            data = detectionData,
            timestamp = os.time()
        })
        
        -- Update trust score based on detection severity
        local severityImpact = GetDetectionSeverity(detectionType)
        PlayerMetrics[playerId].trustScore = math.max(0, PlayerMetrics[playerId].trustScore - severityImpact)
    end
    
    -- AI-based detection analysis
    if Config.AI and Config.AI.enabled then
        local aiVerdict = ProcessAIVerification(playerId, detectionType, detectionData)
        
        if aiVerdict.confidence > Config.Thresholds.aiDecisionConfidenceThreshold then
            if aiVerdict.action == 'ban' then
                BanPlayer(playerId, 'AI-confirmed cheat: ' .. detectionType)
                return
            elseif aiVerdict.action == 'kick' then
                DropPlayer(playerId, Config.KickMessage)
                return
            end
        end
    end
    
    -- Rule-based detection handling
    if Config.Actions then
        -- Handle detection based on configuration
        if Config.Actions.kickOnSuspicion and IsHighRiskDetection(detectionType, detectionData) then
            DropPlayer(playerId, Config.KickMessage)
        elseif Config.Actions.banOnConfirmed and IsConfirmedCheat(detectionType, detectionData) then
            BanPlayer(playerId, 'Confirmed cheat: ' .. detectionType)
        elseif Config.ScreenCapture and Config.ScreenCapture.enabled and Config.ScreenCapture.includeWithReports then
            TriggerClientEvent('nexusguard:requestScreenshot', playerId)
        end
        
        -- Notify admins
        if Config.Actions.reportToAdminsOnSuspicion then
            NotifyAdmins(playerId, detectionType, detectionData)
        end
    end
    
    -- Log to Discord
    if Config.EnableDiscordLogs then
        SendToDiscord('Detection Alert', playerName .. ' - ' .. detectionType)
    end
end

-- Ban a player
function BanPlayer(playerId, reason)
    if not playerId then return end
    
    local identifiers = GetPlayerIdentifiers(playerId)
    local playerName = GetPlayerName(playerId) or "Unknown"
    
    -- Add to ban list
    local banData = {
        name = playerName,
        reason = reason,
        date = os.date('%Y-%m-%d %H:%M:%S'),
        admin = 'System',
        identifiers = identifiers
    }
    
    table.insert(BanList, banData)
    SaveBanList()
    
    -- Log the ban
    print('^1[NexusGuard]^7 Banned player: ' .. playerName .. ' for: ' .. reason)
    
    -- Kick the player with ban message
    DropPlayer(playerId, Config.BanMessage or "You have been banned.")
    
    -- Log to Discord if enabled
    if Config.EnableDiscordLogs then
        SendToDiscord('Player Banned', playerName .. ' was banned for: ' .. reason)
    end
    
    -- Store in database if enabled
    if Config.Database and Config.Database.enabled then
        StorePlayerBan(banData)
    end
end

-- AI model initialization
function InitializeAIModels()
    print('^2[NexusGuard]^7 Loading AI detection models...')
    
    -- Load behavior analysis model
    local behaviorModelFile = LoadResourceFile(GetCurrentResourceName(), 'ml_models/behavior_model.json')
    if behaviorModelFile then
        AIModelCache.behaviorModel = json.decode(behaviorModelFile)
        print('^2[NexusGuard]^7 Behavior model loaded successfully')
    else
        print('^1[NexusGuard]^7 Failed to load behavior model - running without AI behavior analysis')
    end
    
    -- Load anomaly detection model
    local anomalyModelFile = LoadResourceFile(GetCurrentResourceName(), 'ml_models/anomaly_model.json')
    if anomalyModelFile then
        AIModelCache.anomalyModel = json.decode(anomalyModelFile)
        print('^2[NexusGuard]^7 Anomaly model loaded successfully')
    else
        print('^1[NexusGuard]^7 Failed to load anomaly model - running without anomaly detection')
    end
end

-- Process detection with AI verification
function ProcessAIVerification(playerId, detectionType, detectionData)
    -- Default response if AI processing fails
    local defaultVerdict = {
        confidence = 0.3,
        action = 'monitor',
        reasoning = 'Insufficient data for AI decision'
    }
    
    -- Ensure we have AI models loaded
    if not AIModelCache.behaviorModel or not AIModelCache.anomalyModel then
        return defaultVerdict
    end
    
    -- Get player metrics for analysis
    local metrics = PlayerMetrics[playerId]
    if not metrics then
        return defaultVerdict
    end
    
    -- Construct feature vector for AI analysis
    local featureVector = BuildFeatureVector(metrics, detectionType, detectionData)
    
    -- Run anomaly detection
    local anomalyScore = CalculateAnomalyScore(featureVector)
    
    -- Run behavior analysis
    local behaviorVerdict = AnalyzeBehaviorPattern(featureVector, metrics.behaviorProfile)
    
    -- Determine action based on combined AI analysis
    local finalConfidence = (anomalyScore + behaviorVerdict.confidence) / 2
    local action = 'monitor'
    local reasoning = ''
    
    if finalConfidence > 0.9 then
        action = 'ban'
        reasoning = 'High confidence cheat detection'
    elseif finalConfidence > 0.7 then
        action = 'kick'
        reasoning = 'Moderate confidence suspicious activity'
    elseif finalConfidence > 0.5 then
        action = 'warn'
        reasoning = 'Low confidence unusual behavior'
    end
    
    -- Return AI verdict
    return {
        confidence = finalConfidence,
        action = action,
        reasoning = reasoning,
        anomalyScore = anomalyScore,
        behaviorAnalysis = behaviorVerdict
    }
end

-- Scheduled task to monitor players
function SetupScheduledTasks()
    -- Player metrics collection thread
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(60000) -- Once per minute
            CollectPlayerMetrics()
            CleanupDetectionHistory()
        end
    end)
    
    -- AI model update thread (if enabled)
    if Config.AI and Config.AI.enabled then
        Citizen.CreateThread(function()
            while true do
                Citizen.Wait(86400000) -- Daily updates
                UpdateAIModels()
            end
        end)
    end
end

function RegisterServerEvents()
    -- Various events the server listens for
    AddEventHandler('explosionEvent', function(sender, ev)
        -- Check for explosion spam or illegal explosions
        HandleExplosionEvent(sender, ev)
    end)
    
    AddEventHandler('entityCreated', function(entity)
        -- Check for entity spam or illegal entities
        HandleEntityCreation(entity)
    end)
    
    -- Add event handlers for weapon damage, player movement, etc.
end

-- Fixed potential nil access in HandleExplosionEvent
function HandleExplosionEvent(sender, ev)
    -- Check for valid input
    if not ev or not sender or sender <= 0 then return end
    if not PlayerMetrics[sender] then return end
    
    local explosionType = ev.explosionType
    local position = vector3(ev.posX or 0, ev.posY or 0, ev.posZ or 0)
    
    -- Initialize explosions table if it doesn't exist
    if not PlayerMetrics[sender].explosions then
        PlayerMetrics[sender].explosions = {}
    end
    
    -- Track explosion data
    table.insert(PlayerMetrics[sender].explosions, {
        type = explosionType,
        position = position,
        time = os.time()
    })
    
    -- Check for explosion spam
    local recentCount = 0
    local currentTime = os.time()
    
    for _, exp in ipairs(PlayerMetrics[sender].explosions) do
        if currentTime - exp.time < 10 then -- Last 10 seconds
            recentCount = recentCount + 1
        end
    end
    
    -- Detect explosion spam
    if recentCount > 5 then
        ProcessDetection(sender, "explosionspam", {count = recentCount, timeframe = 10})
    end
end

-- Send notification to online admins
function NotifyAdmins(playerId, detectionType, detectionData)
    local playerName = GetPlayerName(playerId) or "Unknown"
    local message = '^1[NexusGuard]^7 Detection: ' .. playerName .. ' (ID: ' .. playerId .. ') - ' .. detectionType .. ' - Data: ' .. json.encode(detectionData)

    -- Send to all online admins stored in our list
    for adminId, _ in pairs(OnlineAdmins) do
        -- Ensure the admin player still exists before sending
        if GetPlayerName(adminId) then
            TriggerClientEvent('nexusguard:adminNotification', adminId, {
                player = playerName,
                playerId = playerId, -- Send player ID as well
                type = detectionType,
                data = detectionData,
                timestamp = os.time()
            })
        end
    end
end

-- Use the SafeGetPlayers function from globals.lua
function GetPlayers()
    return SafeGetPlayers()
end

-- Export NexusGuard API for other resources
exports('BanPlayer', function(playerId, reason, duration, adminId)
    if not playerId then return false end
    
    BanPlayer(playerId, reason or "No reason specified")
    return true
end)

exports('CreatePlayerReport', function(playerId, reason, source, reporterId)
    -- Implementation of player reporting system
    print("^3[NexusGuard]^7 Player report created for " .. playerId .. ": " .. reason)
    return true
end)

-- Make required globals available
_G.ProcessDetection = ProcessDetection
_G.PlayerMetrics = PlayerMetrics
_G.DetectionHistory = DetectionHistory
