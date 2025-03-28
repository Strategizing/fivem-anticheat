fx_version 'cerulean'
game 'gta5'

author 'Strategizing'
description 'NexusGuard - Advanced AI-powered Anti-Cheat for FiveM'
version '1.1.0'

dependency {
    'oxmysql',
    'discord_perms'  -- Optional discord permissions integration
}

shared_scripts {
    'config.lua',
    'shared/utils.lua',
    'shared/constants.lua',
    'shared/discord_config.lua'  -- Discord configuration settings
}

client_scripts {
    'client/main.lua',
    'client/detectors/*.lua',
    'client/networks/*.lua',
    'client/ml/*.lua',
    'client/hooks/*.lua',
    'client/discord/*.lua'  -- Discord rich-presence files
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/api/*.lua',
    'server/detectors/*.lua',
    'server/ml/*.lua',
    'server/webhooks/*.lua',
    'server/discord/*.lua',  -- Discord bot integration
    'server/discord/commands/*.lua',  -- Discord bot commands
    'server/discord/events/*.lua',  -- Discord event handlers
    'server/db/*.lua',
    'server/handlers/*.lua'
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/css/*.css',
    'ui/js/*.js',
    'ui/img/*.png',
    'ui/img/discord/*.png',  -- Discord-related images
    'ml_models/*.json',
    'discord_bot/config.json'  -- Discord bot configuration
}

lua54 'yes'

provides {
    'anticheat',
    'discord_anticheat',
    'discord_richpresence'
}