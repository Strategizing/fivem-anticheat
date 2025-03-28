local command = {
    name = 'ban',
    description = 'Ban a player from the server',
    usage = '!ban [playerID] [duration] [reason]',
    permission = 'moderator'
}

-- Adding FiveM native function declarations for static analysis tools
---@diagnostic disable: undefined-global
-- These functions are provided by the FiveM runtime environment

command.execute = function(user, args)
    if #args < 3 then
        return "Usage: " .. command.usage
    end
    
    local targetId = tonumber(args[1])
    local duration = args[2]
    
    -- Combine remaining arguments for reason
    local reason = ""
    for i = 3, #args do
        reason = reason .. args[i] .. " "
    end
    
    -- Convert duration string to hours
    local durationHours = 0
    if duration:lower() == "permanent" or duration:lower() == "perm" then
        durationHours = 0  -- 0 means permanent
    else
        local timeValue = tonumber(string.match(duration, "%d+"))
        local timeUnit = string.match(duration, "%a+")
        
        if timeValue and timeUnit then
            if timeUnit:lower() == "h" or timeUnit:lower() == "hour" or timeUnit:lower() == "hours" then
                durationHours = timeValue
            elseif timeUnit:lower() == "d" or timeUnit:lower() == "day" or timeUnit:lower() == "days" then
                durationHours = timeValue * 24
            elseif timeUnit:lower() == "w" or timeUnit:lower() == "week" or timeUnit:lower() == "weeks" then
                durationHours = timeValue * 24 * 7
            end
        end
    end
    
    -- Get player name from ID
    local playerName = "Unknown"
    -- GetPlayers is a FiveM native function
    local players = GetPlayers()
    for _, playerId in ipairs(players) do
        if tonumber(playerId) == targetId then
            -- GetPlayerName is a FiveM native function
            playerName = GetPlayerName(playerId)
            break
        end
    end
    
    -- Ban the player
    -- exports is a FiveM global to access exports from other resources
    local success = exports.nexusguard:BanPlayer(targetId, reason, durationHours, user.id)
    
    if success then
        -- Create Discord embed for ban notification
        local embed = {
            title = "Player Banned",
            color = 16711680, -- Red
            fields = {
                {name = "Player", value = playerName .. " (ID: " .. targetId .. ")", inline = true},
                {name = "Banned by", value = user.username, inline = true},
                {name = "Duration", value = duration == "0" and "Permanent" or duration, inline = true},
                {name = "Reason", value = reason, inline = false}
            },
            footer = {
                text = "NexusGuard Anti-Cheat"
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }
        
        -- Log to Discord channel
        exports['discord_bot']:SendEmbed(Config.Discord.Channels.BanLogs, embed)
        
        return "Player " .. playerName .. " (ID: " .. targetId .. ") has been banned."
    else
        return "Failed to ban player. Check if the player ID is valid."
    end
end
---@diagnostic enable: undefined-global

return command
