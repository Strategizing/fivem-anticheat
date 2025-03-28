Config = {}

-- General Settings
Config.ServerName = "Your Server Name" -- Your server name
Config.EnableDiscordLogs = true -- Enable Discord webhook logs
Config.DiscordWebhook = "" -- Your Discord webhook URL
Config.BanMessage = "You have been banned for cheating. Appeal at: discord.gg/yourserver" -- Ban message
Config.KickMessage = "You have been kicked for suspicious activity." -- Kick message
Config.AdminGroups = {"admin", "superadmin", "mod"} -- Groups that can access admin commands

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
    reportToAdminsOnSuspicion = true -- Report suspicious activity to online admins
}

-- AI Settings
Config.AI = {
    enabled = true,
    modelUpdateInterval = 7, -- Days between model updates
    playerDataSampleRate = 10, -- Seconds between player data sampling
    adaptiveDetection = true, -- Adjust thresholds based on server-wide patterns
    anomalyDetectionStrength = 0.8, -- Sensitivity for anomaly detection (0.0-1.0)
    clusteringEnabled = true, -- Enable behavioral clustering
    falsePositiveProtection = true -- Additional checks to prevent false positives
}

-- Optional Features
Config.Features = {
    adminPanel = true, -- Admin panel to review detections and manage bans
    playerReports = true, -- Allow players to report suspicious activity
    resourceVerification = true, -- Verify integrity of server resources
    performanceOptimization = true -- Optimize detection methods based on server performance
}

-- Database Settings
Config.Database = {
    enabled = true,
    storeDetectionHistory = true, -- Store all detections in database
    historyDuration = 30, -- Days to keep detection history
    useAsync = true -- Use async database operations
}

-- Screen Capture Settings
Config.ScreenCapture = {
    enabled = true,
    webhookURL = "", -- Discord webhook for screenshots
    quality = "medium", -- Screenshot quality (low, medium, high)
    includeWithReports = true -- Include screenshots with admin reports
}