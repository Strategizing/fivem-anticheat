fx_version 'cerulean'
game 'gta5'

author 'Strategizing'
description 'NexusGuard - Modular Anti-Cheat Framework for FiveM'
version '0.6.9' -- Reflecting framework version

--[[ Dependencies: Ensure these resources are started BEFORE NexusGuard ]]
dependencies {
    'oxmysql', -- Required for database features (bans, detections, sessions) and JSON library
    'screenshot-basic-master' -- Required for screenshot functionality (Config.ScreenCapture.enabled) -- Corrected resource name
}

shared_scripts {
    '@ox_lib/init.lua', -- Required for lib.crypto used in default secure token implementation
    'config.lua',
    'globals.lua', -- Contains helpers and PLACEHOLDERS requiring user implementation
    'shared/detector_registry.lua', -- Ensure this is included
    'shared/event_registry.lua',
    'shared/version_compat.lua'
    -- NOTE: config_validator.lua, discord_config.lua, constants.lua are not used/present.
}

client_scripts {
    'client_main.lua',
    'client/detectors/*.lua' -- Loads all detector modules
}

server_scripts {
    'server_main.lua'
    -- NOTE: Discord bot, API, server-side detectors, ML, webhooks, etc., are not implemented in this version.
}

files {
    'client_main.lua',
    'server_main.lua',
    'config.lua',
    'sql/schema.sql' -- Database schema file
}

lua54 'yes'

provides {
    'anticheat' -- Indicate that this resource provides anticheat functionality
    -- 'discord_richpresence' -- Rich presence is integrated into client_main, not a separate provided export
}