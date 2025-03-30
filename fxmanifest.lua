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
    'globals.lua',
    'shared/utils.lua',
    'shared/constants.lua',
    'shared/discord_config.lua',
    'shared/detector_registry.lua',
    'shared/config_validator.lua',
    'shared/event_registry.lua',
    'shared/version_compat.lua'
}

client_scripts {
    'client_main.lua',
    'client/detectors/*.lua',
    'client/networks/*.lua',
    'client/ml/*.lua',
    'client/hooks/*.lua',
    'client/discord/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server_main.lua',
    'server/api/*.lua',
    'server/detectors/*.lua',
    'server/ml/*.lua',
    'server/webhooks/*.lua',
    'server/discord/*.lua',
    'server/discord/commands/*.lua',
    'server/discord/events/*.lua',
    'server/db/*.lua',
    'server/handlers/*.lua'
}

files {
    -- 'ui/index.html', -- Removed as file doesn't exist
    -- 'ui/css/*.css', -- Removed as file doesn't exist
    -- 'ui/js/*.js', -- Removed as file doesn't exist
    -- 'ui/img/*.png', -- Removed as file doesn't exist
    -- 'ui/img/discord/*.png', -- Removed as file doesn't exist
    'ml_models/*.json',
    'discord_bot/config.json'
}

lua54 'yes'

provides {
    'anticheat',
    'discord_anticheat',
    'discord_richpresence'
}

-- Exclude development/debug tools from server resources
server_ignore_resource_method 'tools'
