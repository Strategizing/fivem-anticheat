local NexusGuard = {}
local BanList = {}
local DetectionHistory = {}
local PlayerMetrics = {}
local AIModelCache = {}
local ClientsLoaded = {}

-- Initialize the anti-cheat
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    print('^2[NexusGuard]^7 Initializing advanced anti-cheat system...')
    LoadBanList()
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
    
    deferrals.defer()
    deferrals.update('Checking your profile against our anti-cheat database...')
    
    -- Check if player is banned
    Citizen.Wait(500)
    if IsPlayerBanned(license, ip) then
        deferrals.done(Config.BanMessage)
        SendToDiscord('Connection Rejected', playerName .. ' attempted to connect but is banned')
        return
    end
    
    -- Initialize player metrics
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
        securityToken = nil, -- Added to store security token
        explosions = {}, -- Added for tracking explosions
        entities = {}  -- Added for tracking entities
    }
    
    deferrals.done()
end)

-- Player disconnected handler
AddEventHandler('playerDropped', function(reason)
    local source = source
    
    -- Save detection data to database if enabled
    if Config.Database and Config.Database.enabled and PlayerMetrics[source] then
        SavePlayerMetrics(source)
    end
    
    -- Clean up player data
    PlayerMetrics[source] = nil
    ClientsLoaded[source] = nil
end)

-- Client-server handshake to ensure anti-cheat is loaded
RegisterNetEvent('nexusguard:clientLoaded')
AddEventHandler('nexusguard:clientLoaded', function(clientHash)
    local source = source
    
    -- Verify client hash to ensure the client is running the correct version
    if ValidateClientHash(clientHash) then
        ClientsLoaded[source] = true
        local token = GenerateSecurityToken(source)
        TriggerClientEvent('nexusguard:initializeClient', source, token)
        print('^2[NexusGuard]^7 Client initialized for ' .. GetPlayerName(source))
    else
        -- If client hash is invalid, player might be using a modified client
        BanPlayer(source, 'Modified client detected')
    end
end)

-- Register the event that client actually uses based on client_main.lua
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

-- Register the event that client actually triggers based on client_main.lua
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

-- Process detection from client (original event registration)
RegisterNetEvent('nexusguard:detection')
AddEventHandler('nexusguard:detection', function(detectionType, detectionData, securityToken)
    local source = source
    
    -- Validate security token to prevent spoofed events
    if not ValidateSecurityToken(source, securityToken) then
        BanPlayer(source, 'Invalid security token')
        return
    end
    
    -- Process the detection
    ProcessDetection(source, detectionType, detectionData)
end)

-- Register event for resource verification
RegisterNetEvent('NexusGuard:VerifyResources')
AddEventHandler('NexusGuard:VerifyResources', function(resources)
    local source = source
    -- Here you would implement resource validation logic
    -- For now, just log that we received the resources list
    print('^3[NexusGuard]^7 Received resource list from ' .. GetPlayerName(source) .. ' with ' .. #resources .. ' resources')
end)

function ProcessDetection(playerId, detectionType, detectionData)
    -- Log the detection
    print('^1[NexusGuard]^7 Detection: ' .. GetPlayerName(playerId) .. ' - ' .. detectionType)
    
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
    
    -- Make sure we've defined Config.AI first before checking
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
    
    -- Make sure Config.Actions is defined
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
        SendToDiscord('Detection Alert', GetPlayerName(playerId) .. ' - ' .. detectionType)
    end
end

-- Ban a player
function BanPlayer(playerId, reason)
    if not playerId then return end
    
    local identifiers = GetPlayerIdentifiers(playerId)
    local playerName = GetPlayerName(playerId)
    
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
    DropPlayer(playerId, Config.BanMessage)
    
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
    -- Collect player metrics every minute
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(60000)
            CollectPlayerMetrics()
        end
    end)
    
    -- Update AI models periodically if enabled
    if Config.AI and Config.AI.enabled then
        Citizen.CreateThread(function()
            while true do
                Citizen.Wait(86400000) -- Daily check
                UpdateAIModels()
            end
        end)
    end
    
    -- Clean up old detection history
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(3600000) -- Hourly cleanup
            CleanupDetectionHistory()
        end
    end)
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

-- Send notification to online admins
function NotifyAdmins(playerId, detectionType, detectionData)
    local playerName = GetPlayerName(playerId)
    local message = '^1[NexusGuard]^7 Detection: ' .. playerName .. ' - ' .. detectionType
    
    -- Send to all admins
    for _, adminId in ipairs(GetPlayers()) do
        if IsPlayerAdmin(adminId) then
            TriggerClientEvent('nexusguard:adminNotification', adminId, {
                player = playerName,
                id = playerId,
                type = detectionType,
                data = detectionData,
                timestamp = os.time()
            })
        end
    end
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