fx_version 'cerulean'
game 'gta5'

author 'Strategizing'
description 'NexusGuard - Modular Anti-Cheat Framework for FiveM'
version '0.6.9' -- Reflecting framework version

--[[ Dependencies: Ensure these resources are started BEFORE NexusGuard ]]
dependencies {
    'oxmysql', -- Required for database features (bans, detections, sessions) and JSON library
    'screenshot-basic' -- Required for screenshot functionality (Config.ScreenCapture.enabled)
    -- 'chat', -- Optional: Required for default client-side warnings via exports.chat
    -- Add framework dependencies if needed for IsPlayerAdmin checks (e.g., 'es_extended', 'qb-core')
}

shared_scripts {
    '@ox_lib/init.lua', -- Required for lib.crypto used in default secure token implementation
    'config.lua',
    'globals.lua', -- Contains helpers and PLACEHOLDERS requiring user implementation
    'shared/detector_registry.lua',
    'shared/event_registry.lua',
    'shared/version_compat.lua'
    -- NOTE: config_validator.lua, discord_config.lua, constants.lua are not used/present.
    -- NOTE: load.lua is redundant and removed. Initialization happens in client_main/server_main.
}

client_scripts {
    'client_main.lua',
    'client/detectors/*.lua' -- Loads all detector modules
}

server_scripts {
    -- '@oxmysql/lib/MySQL.lua', -- Not needed; dependency ensures MySQL is available globally or via exports['oxmysql']
    'server_main.lua'
    -- NOTE: Discord bot, API, server-side detectors, ML, webhooks, etc., are not implemented in this version.
}

files {
    'sql/schema.sql' -- Database schema file
    -- Removed: ml_models, discord_bot/config.json (missing/unused)
}

lua54 'yes'

provides {
    'anticheat' -- Indicate that this resource provides anticheat functionality
    -- 'discord_richpresence' -- Rich presence is integrated into client_main, not a separate provided export
}

-- Optional: Exclude development/debug tools from being accessible via exports by other resources
-- server_ignore_resource_method 'tools'
