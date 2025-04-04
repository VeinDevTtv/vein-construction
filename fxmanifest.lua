fx_version 'cerulean'
game 'gta5'

author 'Your Name'
description 'Advanced Construction Job for FiveM using QBCore'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/main.lua',
    'locales/en.lua'
}

client_scripts {
    'client/main.lua',
    'client/tasks.lua',
    'client/events.lua',
    'client/npc.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/progression.lua'
}

dependencies {
    'qb-core',
    'ox_lib',
    'ox_inventory',
    'ox_target'
}

lua54 'yes' 