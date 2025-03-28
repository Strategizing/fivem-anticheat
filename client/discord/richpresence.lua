local playerName = GetPlayerName(PlayerId())
local serverId = GetPlayerServerId(PlayerId())
local richPresenceLastUpdate = 0

-- Initialize rich presence
function InitializeRichPresence()
    if not Config.Discord.RichPresence.Enabled then return end
    
    SetDiscordAppId(Config.Discord.RichPresence.AppId)
    SetDiscordRichPresenceAsset(Config.Discord.RichPresence.LargeImage)
    SetDiscordRichPresenceAssetText(Config.Discord.RichPresence.LargeImageText)
    SetDiscordRichPresenceAssetSmall(Config.Discord.RichPresence.SmallImage)
    SetDiscordRichPresenceAssetSmallText(Config.Discord.RichPresence.SmallImageText)
end

-- Update rich presence with player and server info
function UpdateRichPresence()
    if not Config.Discord.RichPresence.Enabled then return end
    
    local currentTime = GetGameTimer()
    if currentTime - richPresenceLastUpdate < (Config.Discord.RichPresence.UpdateInterval * 1000) then
        return
    end
    
    richPresenceLastUpdate = currentTime
    
    -- Get player position and convert to zone name
    local playerCoords = GetEntityCoords(PlayerPedId())
    local streetName, crossingRoad = GetStreetNameAtCoord(playerCoords.x, playerCoords.y, playerCoords.z)
    local location = GetStreetNameFromHashKey(streetName)
    
    -- Get player health and armor
    local health = GetEntityHealth(PlayerPedId()) - 100
    if health < 0 then health = 0 end
    local armor = GetPedArmour(PlayerPedId())
    
    -- Set rich presence details
    SetRichPresence(string.format("ID: %s | %s | HP: %s%% | Location: %s", 
        serverId, playerName, health, location))
    
    -- Set rich presence state and party info
    SetDiscordRichPresenceAction(0, "Join Server", "fivem://connect/yourserverip:port")
    SetDiscordRichPresenceAction(1, "Discord", "https://discord.gg/yourdiscordinvite")
end

-- Event handlers
AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    InitializeRichPresence()
end)

-- Main thread
Citizen.CreateThread(function()
    InitializeRichPresence()
    
    while true do
        UpdateRichPresence()
        Citizen.Wait(5000)
    end
end)
