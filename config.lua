Config = {}

-- General Settings
Config.ServerName = "Your Server Name" -- Your server name
Config.LogLevel = 2 -- 0=Error, 1=Warn, 2=Info, 3=Debug (Affects server console logs)
Config.EnableDiscordLogs = true -- Enable Discord webhook logs (Separate from LogLevel)
Config.DiscordWebhook = "" -- Your Discord webhook URL (General logs if specific webhooks below aren't set)
Config.BanMessage = "You have been banned for cheating. Appeal at: discord.gg/yourserver" -- Ban message
Config.KickMessage = "You have been kicked for suspicious activity." -- Kick message

-- Permissions Framework Configuration
-- Set this to match your server's permission system. Affects the IsPlayerAdmin check in globals.lua.
-- Options:
-- "ace"    : Use built-in FiveM ACE permissions (checks group.<group_name> for groups in Config.AdminGroups).
-- "esx"    : Use ESX framework (checks xPlayer.getGroup() against Config.AdminGroups). Requires ESX to be running.
-- "qbcore" : Use QBCore framework (checks QBCore.Functions.HasPermission(playerId, group) for groups in Config.AdminGroups). Requires QBCore to be running.
-- "custom" : Use this if you want to write your own logic directly into the IsPlayerAdmin function in globals.lua.
Config.PermissionsFramework = "ace" -- Default to ACE permissions

Config.AdminGroups = {"admin", "superadmin", "mod"} -- Groups considered admin by the selected framework check (case-sensitive depending on framework)
-- Example ACE groups (default): {"admin", "superadmin", "mod"}
-- Example ESX groups: {"admin", "superadmin"}
-- Example QBCore groups: {"admin", "god"} -- Or other high-level permission groups defined in your QBCore setup

-- !! CRITICAL !! Change this to a long, unique, random string for your server.
-- This is used by the default secure token implementation (HMAC-SHA256 via ox_lib).
-- **LEAVING THIS AS DEFAULT OR USING A WEAK SECRET WILL MAKE YOUR SERVER VULNERABLE.**
Config.SecuritySecret = "CHANGE_THIS_TO_A_VERY_LONG_RANDOM_SECRET_STRING" -- <<< CHANGE THIS!!!

-- Auto Configuration (Placeholder Features)
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
    aiDecisionConfidenceThreshold = 0.75, -- AI confidence threshold for automated action

    -- Server-Side Validation Thresholds (Used by server checks, independent of client checks)
    serverSideSpeedThreshold = 50.0, -- Max allowed speed in m/s based on server position checks (Approx 180 km/h). Tune carefully!
    serverSideRegenThreshold = 3.0, -- Max allowed passive HP regen rate in HP/sec based on server health checks.
    serverSideArmorThreshold = 105.0 -- Max allowed armor value based on server health checks (Allows slight buffer over 100).
}

-- Server-Side Weapon Base Data (for validation)
-- Add known base values for weapons here. This helps the server validate client reports.
-- Values can vary based on game version/mods. Use natives on a clean client/server to find defaults.
-- Key: Weapon Hash (use GetHashKey("WEAPON_PISTOL") etc.)
Config.WeaponBaseDamage = { -- Base Damage (float)
    [GetHashKey("WEAPON_PISTOL")] = 26.0,
    [GetHashKey("WEAPON_COMBATPISTOL")] = 27.0,
    [GetHashKey("WEAPON_APPISTOL")] = 28.0,
    [GetHashKey("WEAPON_MICROSMG")] = 21.0,
    [GetHashKey("WEAPON_SMG")] = 22.0,
    [GetHashKey("WEAPON_ASSAULTRIFLE")] = 30.0,
    [GetHashKey("WEAPON_CARBINERIFLE")] = 32.0,
    [GetHashKey("WEAPON_SPECIALCARBINE")] = 34.0,
    [GetHashKey("WEAPON_PUMPSHOTGUN")] = 30.0, -- Damage per pellet, often multiple pellets per shot
    [GetHashKey("WEAPON_SNIPERRIFLE")] = 100.0,
    -- Add more weapons as needed...
}
Config.WeaponBaseClipSize = { -- Base Clip Size (integer)
    [GetHashKey("WEAPON_PISTOL")] = 12,
    [GetHashKey("WEAPON_COMBATPISTOL")] = 12,
    [GetHashKey("WEAPON_APPISTOL")] = 18,
    [GetHashKey("WEAPON_MICROSMG")] = 16,
    [GetHashKey("WEAPON_SMG")] = 30,
    [GetHashKey("WEAPON_ASSAULTRIFLE")] = 30,
    [GetHashKey("WEAPON_CARBINERIFLE")] = 30,
    [GetHashKey("WEAPON_SPECIALCARBINE")] = 30,
    [GetHashKey("WEAPON_PUMPSHOTGUN")] = 8,
    [GetHashKey("WEAPON_SNIPERRIFLE")] = 10,
    -- Add more weapons as needed...
}

-- Detection Types
-- These flags enable/disable the *client-side* detector modules.
-- Server-side checks (like speed, health, weapon validation) run based on received events, not these flags.
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

-- Optional Features
Config.Features = {
    -- adminPanel = true, -- Placeholder: Requires a UI and server-side logic implementation
    -- playerReports = true, -- Placeholder: Requires UI/command and server-side logic implementation
    resourceVerification = {
        enabled = false, -- Verify integrity of client resources (EXPERIMENTAL - can cause false positives if not configured correctly)
        mode = "whitelist", -- "whitelist" or "blacklist"
        -- Whitelist Mode: ONLY resources listed here are allowed. Add ALL essential FiveM, framework (ESX, QBCore), and core server resources.
        whitelist = {
            "chat",
            "spawnmanager",
            "mapmanager",
            "basic-gamemode", -- Example core resource
            "fivem",          -- Core resource
            "hardcap",        -- Core resource
            "rconlog",        -- Core resource
            "sessionmanager", -- Core resource
            GetCurrentResourceName(), -- Always allow the anti-cheat resource itself
            -- !! VERY IMPORTANT !! If using whitelist mode, you MUST add ALL essential resources
            -- for your server here. This includes your framework (e.g., 'es_extended', 'qb-core'),
            -- maps, MLOs, core scripts (chat, spawnmanager, etc.), UI scripts, and any other
            -- resource required for your server to function.
            -- Failure to whitelist essential resources WILL cause players to be kicked/banned incorrectly.
            -- Example: 'es_extended', 'qb-core', 'qb-inventory', 'ox_lib', 'ox_inventory', 'cd_drawtextui'
        },
        -- Blacklist Mode: Resources listed here are DISALLOWED. Useful for blocking known cheat menus.
        blacklist = {
            -- Add known cheat menu resource names here (case-sensitive)
            "LambdaMenu",     -- Example
            "SimpleTrainer",  -- Example
            "menyoo"
        },
        kickOnMismatch = true, -- Kick player if unauthorized resources are detected
        banOnMismatch = false -- Ban player if unauthorized resources are detected (Use with caution)
    },
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
    webhookURL = "", -- !! REQUIRED if enabled !! Discord webhook for screenshots
    quality = "medium", -- Screenshot quality (low, medium, high)
    includeWithReports = true, -- Include screenshots with admin reports
    automaticCapture = true, -- Take periodic screenshots of suspicious players
    storageLimit = 50 -- Maximum number of screenshots to store per player
}

-- Discord Integration
Config.Discord = {
    enabled = true,
    botToken = "", -- !! REQUIRED for bot features (commands, etc.) - Requires separate bot implementation !! Your Discord bot token
    guildId = "", -- !! REQUIRED for bot features !! Your Discord server ID
    botCommandPrefix = "!ac", -- Command prefix for Discord bot
    inviteLink = "discord.gg/yourserver", -- Discord invite link for players

    richPresence = {
        enabled = true,
        appId = "1234567890", -- !! REQUIRED if enabled !! Discord Application ID (Create one at discord.com/developers/applications)
        largeImageKey = "logo", -- Large image key (Must be uploaded to Discord App Assets)
        smallImageKey = "shield", -- Small image key (Must be uploaded to Discord App Assets)
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
            commandChannels = {"123456789"}, -- !! REQUIRED if restrictToChannels = true !! Channel IDs where commands are allowed
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
        } -- Closing brace for Config.Discord.bot.notifications
        }, -- Closing brace for Config.Discord.bot

        webhooks = {
            general = "", -- General anti-cheat logs (Can be the same as Config.DiscordWebhook)
            bans = "", -- Ban notifications (Can be the same as Config.DiscordWebhook)
            kicks = "", -- Kick notifications
            warnings = "" -- Warning notifications
        } -- Closing brace for Config.Discord.webhooks
    } -- Closing brace for Config.Discord
