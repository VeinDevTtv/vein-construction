fx_version 'cerulean'
game 'gta5'

author 'Vein'
description 'Construction Job for FiveM using QBCore'
version '1.0.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'shared/config.lua',
    'shared/utils.lua'
}

client_scripts {
    '@PolyZone/client.lua',
    '@PolyZone/BoxZone.lua',
    '@PolyZone/EntityZone.lua',
    '@PolyZone/CircleZone.lua',
    '@PolyZone/ComboZone.lua',
    'client/main.lua',
    'client/tasks.lua',
    'client/events.lua',
    'client/npc.lua',
    'client/ui.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/progression.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js'
}

lua54 'yes'

dependencies {
    'qb-core',
    'PolyZone'
}

escrow_ignore {
    'shared/config.lua',
    'locales/*.lua',
    'README.md'
}

server_export 'GetSharedObject' 