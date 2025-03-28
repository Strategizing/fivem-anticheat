local AC = AC

-- Add proper declarations for FiveM natives
local GetPlayers = GetPlayers or function() return {} end  -- Fallback if GetPlayers is nil
local GetPlayerName = GetPlayerName or function() return "Unknown" end  -- Fallback
local exports = exports

AC.Commands.RegisterCommand('ban', {
    name = 'ban',
    description = 'Ban a player from the server',
    usage = '!ban [playerID] [duration] [reason]',
    permission = 'moderator'
}, function(interaction)
    if not interaction or type(interaction) ~= "table" or not interaction.data then
        return "Invalid interaction data."
    end

    local args = interaction.data.options or {}
    local playerID = tonumber(args[1] and args[1].value)
    
    if not playerID then
        return "Invalid player ID."
    end
    
    local duration = args[2] and args[2].value or "permanent"

    -- Combine remaining arguments for reason
    local reason = ""
    for i = 3, #args do
        reason = reason .. (args[i] and args[i].value or "") .. " "
    end
    reason = reason:len() > 0 and reason or "No reason specified"

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

    -- Check if player is online
    local players = nil
    if GetPlayers then
        players = GetPlayers()
    end
    if type(players) ~= "table" then
        players = {}
    end

    local playerName = "Unknown"
    local found = false
    for _, playerId in ipairs(players) do
        if tonumber(playerId) == playerID then
            playerName = GetPlayerName(playerId) or playerName
            found = true
            break
        end
    end

    if not found then
        return "Player not found."
    end

    -- Ban the player - ensure we're using valid function call
    local success = false
    local banExport = exports["fivem-anticheat"]
    if banExport and type(banExport.BanPlayer) == "function" then
        success = banExport:BanPlayer(playerID, {
            reason = reason,
            duration = durationHours,
            bannedBy = interaction.user and interaction.user.id or "Console"
        })
    else
        print("^1[NexusGuard] Error: BanPlayer export not found^7")
    end

    if success then
        -- Create Discord embed for ban notification
        local embed = {
            title = "Player Banned",
            color = 16711680, -- Red
            fields = {
                {name = "Player", value = playerName .. " (ID: " .. playerID .. ")", inline = true},
                {name = "Banned by", value = (interaction.user and interaction.user.username) or "Console", inline = true},
                {name = "Duration", value = (durationHours == 0) and "Permanent" or duration, inline = true},
                {name = "Reason", value = reason, inline = false}
            },
            footer = {
                text = "NexusGuard Anti-Cheat"
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }

        -- Log to Discord channel safely
        local channelId = Config and Config.Discord and Config.Discord.Channels and Config.Discord.Channels.BanLogs or nil
        local logExport = exports["fivem-anticheat"]
        if logExport and type(logExport.AddSystemLog) == "function" then
            logExport:AddSystemLog({
                embed = embed,
                channel = channelId
            })
        end

        return "Player " .. playerName .. " (ID: " .. playerID .. ") has been banned."
    else
        return "Failed to ban player. Check if the player ID is valid."
    end
end)
