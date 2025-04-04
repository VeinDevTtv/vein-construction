fx_version 'cerulean'
game 'gta5'

author 'Vein Development'
description 'QBCore Construction Job System'
version '1.0.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'config.lua'
}

client_scripts {
    '@PolyZone/client.lua',
    '@PolyZone/BoxZone.lua',
    '@PolyZone/EntityZone.lua',
    '@PolyZone/CircleZone.lua',
    '@PolyZone/ComboZone.lua',
    'client/main.lua',
    'client/ui.lua',
    'client/npc.lua',
    'client/tasks.lua',
    'client/events.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/events.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
    'html/img/*.png'
}

dependency {
    'qb-core',
    'oxmysql'
}

-- List ox_lib as an optional dependency to help with loading order
lua54 'yes'

escrow_ignore {
    'shared/config.lua',
    'locales/*.lua',
    'README.md'
}

server_export 'GetSharedObject' 