Config = {}

-- General Settings
Config.ServerName = "Your Server Name" -- Your server name
Config.EnableDiscordLogs = true -- Enable Discord webhook logs
Config.DiscordWebhook = "" -- Your Discord webhook URL
Config.BanMessage = "You have been banned for cheating. Appeal at: discord.gg/yourserver" -- Ban message
Config.KickMessage = "You have been kicked for suspicious activity." -- Kick message
Config.AdminGroups = {"admin", "superadmin", "mod"} -- Groups that can access admin commands

-- Auto Configuration
Config.AutoConfig = {
    enabled = true, -- Enable auto-configuration during installation
    detectFramework = true, -- Auto-detect framework (ESX, QB, etc.)
    importBanList = true, -- Import bans from existing ban systems
    setupDatabase = true -- Attempt to set up database tables automatically
}

-- Detection Thresholds
Config.Thresholds = {
    weaponDamageMultiplier = 1.5, -- Threshold for weapon damage (1.0 = normal)
    speedHackMultiplier = 1.3, -- Speed multiplier threshold (player movement)
    teleportDistance = 100.0, -- Maximum allowed teleport distance (meters)
    noclipTolerance = 3.0, -- NoClip detection tolerance
    vehicleSpawnLimit = 5, -- Vehicles spawned per minute
    entitySpawnLimit = 15, -- Entities spawned per minute
    healthRegenerationRate = 2.0, -- Health regeneration rate threshold
    aiDecisionConfidenceThreshold = 0.75 -- AI confidence threshold for automated action
}

-- Detection Types
Config.Detectors = {
    godMode = true,
    speedHack = true,
    weaponModification = true,
    resourceInjection = true,
    explosionSpamming = true,
    objectSpamming = true,
    entitySpawning = true,
    noclip = true,
    freecam = true,
    teleporting = true,
    menuDetection = true,
    vehicleModification = true,
    aiDetection = true
}

-- Action Settings
Config.Actions = {
    kickOnSuspicion = true, -- Kick player when suspicious activity is detected
    banOnConfirmed = true, -- Ban player when cheating is confirmed
    warningThreshold = 3, -- Number of warnings before taking action
    screenshotOnSuspicion = true, -- Take screenshot on suspicious activity
    reportToAdminsOnSuspicion = true, -- Report suspicious activity to online admins
    notifyPlayer = true, -- Notify player they are being monitored (can deter cheaters)
    progressiveResponse = true -- Gradually increase response severity with repeated offenses
}

-- AI Settings
Config.AI = {
    enabled = true,
    modelUpdateInterval = 7, -- Days between model updates
    playerDataSampleRate = 10, -- Seconds between player data sampling
    adaptiveDetection = true, -- Adjust thresholds based on server-wide patterns
    anomalyDetectionStrength = 0.8, -- Sensitivity for anomaly detection (0.0-1.0)
    clusteringEnabled = true, -- Enable behavioral clustering
    falsePositiveProtection = true, -- Additional checks to prevent false positives
    reportAccuracy = true -- Report detection accuracy to central database to improve model
}

-- Optional Features
Config.Features = {
    adminPanel = true, -- Admin panel to review detections and manage bans
    playerReports = true, -- Allow players to report suspicious activity
    resourceVerification = true, -- Verify integrity of server resources
    performanceOptimization = true, -- Optimize detection methods based on server performance
    autoUpdate = true, -- Check for updates automatically
    compatibilityMode = false -- Enable for older servers with compatibility issues
}

-- Database Settings
Config.Database = {
    enabled = true,
    storeDetectionHistory = true, -- Store all detections in database
    historyDuration = 30, -- Days to keep detection history
    useAsync = true, -- Use async database operations
    tablePrefix = "nexusguard_", -- Prefix for database tables
    backupFrequency = 24 -- Hours between database backups
}

-- Screen Capture Settings
Config.ScreenCapture = {
    enabled = true,
    webhookURL = "", -- Discord webhook for screenshots
    quality = "medium", -- Screenshot quality (low, medium, high)
    includeWithReports = true, -- Include screenshots with admin reports
    automaticCapture = true, -- Take periodic screenshots of suspicious players
    storageLimit = 50 -- Maximum number of screenshots to store per player
}

-- Discord Integration
Config.Discord = {
    enabled = true,
    botToken = "", -- Your Discord bot token (if using the bot feature)
    guildId = "", -- Your Discord server ID
    botCommandPrefix = "!ac", -- Command prefix for Discord bot
    richPresence = {
        enabled = true,
        appId = "1234567890", -- Discord Application ID
        largeImageKey = "logo", -- Large image key
        smallImageKey = "shield" -- Small image key
    },
    moderationChannel = "", -- Channel ID for moderation alerts
    logsChannel = "", -- Channel ID for general logs
    publicReportsChannel = "", -- Channel ID for public player reports
    staffRoles = {"123456789", "987654321"}, -- Role IDs that can use admin commands
    alertPriority = {
        high = "1122334455", -- Role ID to ping for high priority alerts
        medium = "5566778899", -- Role ID to ping for medium priority alerts
        low = "" -- Role ID to ping for low priority alerts
    }
}

-- Whitelist & Exemptions
Config.Whitelist = {
    enabled = false, -- Enable whitelist feature
    adminsBypass = true, -- Admins bypass certain detections
    whitelistedSteamIds = {}, -- Steam IDs exempt from certain checks
    whitelistedDiscordIds = {}, -- Discord IDs exempt from certain checks
    whitelistedResources = {"es_extended", "qb-core"} -- Resources exempt from integrity checks
}

-- Compatibility Settings
Config.Compatibility = {
    framework = "auto", -- auto, esx, qb-core, vrp, custom
    customFrameworkExport = "", -- If using custom framework
    essentialMods = {}, -- Mods that might conflict with anti-cheat
    playerIdentifierType = "auto" -- auto, license, steam, discord
}

-- Performance Settings
Config.Performance = {
    optimizeForPlayerCount = true, -- Automatically adjust scan frequency based on player count
    lowPlayerThreshold = 10, -- Number of players considered "low"
    highPlayerThreshold = 50, -- Number of players considered "high"
    reducedDetectionOnHighLoad = true -- Reduce detection intensity during server stress
}