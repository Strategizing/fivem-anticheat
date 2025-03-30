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
    -- 'shared/constants.lua', -- File missing
    'shared/discord_config.lua',
    'shared/detector_registry.lua',
    'shared/config_validator.lua',
    'shared/event_registry.lua',
    'shared/version_compat.lua'
}

client_scripts {
    'client_main.lua',
    'client/detectors/*.lua',
    -- 'client/networks/*.lua', -- Directory missing
    -- 'client/ml/*.lua', -- Directory missing
    -- 'client/hooks/*.lua', -- Directory missing
    'client/discord/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server_main.lua',
    -- 'server/api/*.lua', -- Directory missing
    -- 'server/detectors/*.lua', -- Directory missing
    -- 'server/ml/*.lua', -- Directory missing
    -- 'server/webhooks/*.lua', -- Directory missing
    'server/discord/bot.lua', -- Explicitly list existing file instead of wildcard
    'server/discord/commands/*.lua',
    -- 'server/discord/events/*.lua', -- Directory missing
    -- 'server/db/*.lua', -- Directory missing
    -- 'server/handlers/*.lua' -- Directory missing
}

files {
    -- 'ml_models/*.json', -- Directory missing
    -- 'discord_bot/config.json' -- Directory missing
}

lua54 'yes'

provides {
    'anticheat',
    'discord_anticheat',
    'discord_richpresence'
}

-- Exclude development/debug tools from server resources
server_ignore_resource_method 'tools'
