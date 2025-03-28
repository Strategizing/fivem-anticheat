fx_version 'cerulean'
game 'gta5'

author 'Strategizing'
description 'NexusGuard - Advanced AI-powered Anti-Cheat for FiveM'
version '1.0.0'

shared_scripts {
    'config.lua',
    'shared/utils.lua',
    'shared/constants.lua'
}

client_scripts {
    'client/main.lua',
    'client/detectors/*.lua',
    'client/networks/*.lua',
    'client/ml/*.lua',
    'client/hooks/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/api/*.lua',
    'server/detectors/*.lua',
    'server/ml/*.lua',
    'server/webhooks/*.lua',
    'server/db/*.lua',
    'server/handlers/*.lua'
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/css/*.css',
    'ui/js/*.js',
    'ui/img/*.png',
    'ml_models/*.json'
}

lua54 'yes'