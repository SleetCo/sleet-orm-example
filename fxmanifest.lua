fx_version 'cerulean'
game 'gta5'

name        'sleet_orm_example'
description 'Sleet ORM — full-featured example resource'
version     '1.0.0'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@sleet/sleet.lua',     -- 加载 Sleet ORM，同时安装 package/require shim

    'server/players.lua',
    'server/gangs.lua',
    'server/items.lua',
    'server/main.lua',
}
