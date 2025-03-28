local DiscordBot = {
    ready = false,
    commands = {},
    events = {}
}

-- Load the Discord bot
function DiscordBot.Initialize()
    if Config.Discord.BotToken == '' then
        print('^1[NexusGuard] Discord bot token not set. Discord integration disabled.^7')
        return
    end
    
    print('^2[NexusGuard] Initializing Discord bot integration...^7')
    
    -- Register bot with Discord API (this is a conceptual implementation)
    -- In a real implementation, you would use a library or API to connect to Discord
    exports['discord_bot']:Configure({
        token = Config.Discord.BotToken,
        guild = Config.Discord.GuildId,
        status = 'Protecting the server | ' .. GetConvar('sv_hostname', 'FiveM Server'),
        debug = true
    })
    
    -- Register command handlers
    DiscordBot.RegisterCommands()
    
    -- Register event handlers
    DiscordBot.RegisterEventHandlers()
    
    DiscordBot.ready = true
    print('^2[NexusGuard] Discord bot integration initialized successfully.^7')
end

-- Register Discord bot commands
function DiscordBot.RegisterCommands()
    -- Load all command modules from the commands directory
    local commandFiles = LoadResourceFile(GetCurrentResourceName(), 'server/discord/commands')
    for _, file in ipairs(commandFiles) do
        local commandModule = LoadResourceFile(GetCurrentResourceName(), 'server/discord/commands/' .. file)
        if commandModule and commandModule.name then
            DiscordBot.commands[commandModule.name] = commandModule
            print('^3[NexusGuard] Registered Discord command: ' .. commandModule.name .. '^7')
        end
    end
    
    -- Register command handler
    exports['discord_bot']:RegisterCommandHandler(function(user, command, args)
        -- Check if command exists and is enabled
        local cmdName = string.lower(command)
        if not Config.Discord.Commands[cmdName] then return end
        
        if DiscordBot.commands[cmdName] then
            -- Check if user has required permission
            if DiscordBot.HasPermission(user, DiscordBot.commands[cmdName].permission) then
                DiscordBot.commands[cmdName].execute(user, args)
            else
                return "You don't have permission to use this command."
            end
        end
    end)
end

-- Check if a user has a specific permission
function DiscordBot.HasPermission(user, requiredPermission)
    if not requiredPermission then return true end
    
    -- Check user roles against the required permission
    local userRoles = exports['discord_bot']:GetUserRoles(user.id)
    
    if requiredPermission == 'admin' and userRoles[Config.Discord.Roles.Admin] then
        return true
    elseif requiredPermission == 'moderator' and (userRoles[Config.Discord.Roles.Admin] or userRoles[Config.Discord.Roles.Moderator]) then
        return true
    elseif requiredPermission == 'staff' and (userRoles[Config.Discord.Roles.Admin] or userRoles[Config.Discord.Roles.Moderator] or userRoles[Config.Discord.Roles.Staff]) then
        return true
    end
    
    return false
end

-- Register event handlers for Discord events
function DiscordBot.RegisterEventHandlers()
    -- Register event handlers for various Discord events
    exports['discord_bot']:RegisterEventHandler('ready', function()
        print('^2[NexusGuard] Discord bot is ready and connected to Discord API.^7')
        DiscordBot.SendMessage(Config.Discord.Channels.GeneralLogs, 'NexusGuard Anti-Cheat system is now online and monitoring the server.')
    end)
    
    -- Handle incoming reports via Discord
    exports['discord_bot']:RegisterEventHandler('messageCreate', function(message)
        if message.channel_id == Config.Discord.Channels.Reports and not message.author.bot then
            -- Process report message
            DiscordBot.ProcessReport(message)
        end
    end)
end

-- Send a message to a Discord channel
function DiscordBot.SendMessage(channelId, message, embed)
    if not DiscordBot.ready then return end
    
    if embed then
        exports['discord_bot']:SendEmbed(channelId, embed)
    else
        exports['discord_bot']:SendMessage(channelId, message)
    end
end

-- Send a detection notification to Discord
function DiscordBot.SendDetection(playerName, playerId, reason, evidence)
    if not DiscordBot.ready then return end
    
    local embed = {
        title = "🚨 Cheat Detection",
        color = 16711680, -- Red color
        fields = {
            {name = "Player", value = playerName .. " (ID: " .. playerId .. ")", inline = true},
            {name = "Detected", value = os.date("%Y-%m-%d %H:%M:%S"), inline = true},
            {name = "Reason", value = reason, inline = false}
        },
        footer = {
            text = "NexusGuard Anti-Cheat"
        }
    }
    
    if evidence then
        embed.description = "Evidence: " .. evidence
    end
    
    DiscordBot.SendMessage(Config.Discord.Channels.DetectionLogs, nil, embed)
end

-- Process a player report from Discord
function DiscordBot.ProcessReport(message)
    -- Simple report format: !report [playerID] [reason]
    local content = message.content
    
    -- Skip if not a report
    if not string.find(content, "^" .. Config.Discord.CommandPrefix .. "report") then
        return
    end
    
    local args = {}
    for arg in string.gmatch(content, "%S+") do
        table.insert(args, arg)
    end
    
    if #args < 3 then
        DiscordBot.SendMessage(message.channel_id, "Usage: " .. Config.Discord.CommandPrefix .. "report [playerID] [reason]")
        return
    end
    
    local reporterId = message.author.id
    local reporterName = message.author.username
    local targetId = args[2]
    
    -- Combine all remaining words as the reason
    local reason = ""
    for i = 3, #args do
        reason = reason .. args[i] .. " "
    end
    
    -- Create report in the system
    local success = exports.nexusguard:CreatePlayerReport(targetId, reason, "discord", reporterId)
    
    if success then
        DiscordBot.SendMessage(message.channel_id, "Report submitted successfully. Staff will review it as soon as possible.")
    else
        DiscordBot.SendMessage(message.channel_id, "Failed to submit report. Please check the player ID and try again.")
    end
end

-- Initialize the Discord bot when resource starts
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    -- Give a slight delay to allow other resources to load first
    Citizen.Wait(2000)
    DiscordBot.Initialize()
end)

-- Export the DiscordBot object so other resources can use it
exports('GetDiscordBot', function()
    return DiscordBot
end)
