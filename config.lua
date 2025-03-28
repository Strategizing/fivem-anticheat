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
    botToken = "", -- Your Discord bot token
    guildId = "", -- Your Discord server ID
    botCommandPrefix = "!ac", -- Command prefix for Discord bot
    inviteLink = "discord.gg/yourserver", -- Discord invite link for players
    
    richPresence = {
        enabled = true,
        appId = "1234567890", -- Discord Application ID
        largeImageKey = "logo", -- Large image key
        smallImageKey = "shield", -- Small image key
        updateInterval = 60, -- How often to update presence (seconds)
        showPlayerCount = true, -- Show current player count in status
        showServerName = true, -- Show server name in status
        showPlayTime = true, -- Show player's time spent on server
        customMessages = { -- Random messages to display in rich presence
            "Secured by NexusGuard",
            "Protected Server",
            "Anti-Cheat Active"
        },
        buttons = { -- Up to 2 buttons that appear on rich presence
            {
                label = "Join Discord",
                url = "discord.gg/yourserver"
            },
            {
                label = "Server Website",
                url = "https://yourserver.com"
            }
        }
    },
    
    bot = {
        status = "Monitoring FiveM server", -- Bot status message
        avatarURL = "", -- URL to bot's avatar image
        embedColor = "#FF0000", -- Default color for embeds
        activityType = "WATCHING", -- PLAYING, WATCHING, LISTENING, STREAMING
        commands = {
            enabled = true,
            restrictToChannels = true, -- Restrict bot commands to specific channels
            commandChannels = {"123456789"}, -- Channel IDs where commands are allowed
            available = {
                "status", -- Get server status
                "players", -- List online players
                "ban", -- Ban player
                "unban", -- Unban player
                "kick", -- Kick player
                "warn", -- Warn player
                "history", -- View player history
                "screenshot", -- Request player screenshot
                "restart", -- Restart anti-cheat
                "help" -- Show command help
            }
        },
        playerReports = {
            enabled = true,
            requireProof = true, -- Require screenshot/video evidence
            notifyAdmins = true, -- Send notification to admins
            createThreads = true, -- Create thread for each report
            reportCooldown = 300, -- Seconds between player reports
            autoArchiveThreads = 24 -- Hours before auto-archiving threads (0 to disable)
        },
        notifications = {
            playerJoin = true, -- Notify when player joins
            playerLeave = true, -- Notify when player leaves
            suspiciousActivity = true, -- Notify on suspicious activity
            serverStatus = true, -- Server status updates
            anticheatUpdates = true -- Anti-cheat update notifications
        }
        },
        
        webhooks = {
            general = "", -- General anti-cheat logs
            bans = "", -- Ban notifications
            kicks = "", -- Kick notifications
            warnings = "" -- Warning notifications
        } -- Closing brace for Config.Discord.webhooks
    } -- Closing brace for Config.Discord