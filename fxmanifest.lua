fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'Cortex MDT - Mobile Data Terminal'
author 'Cortex'
version '1.0.0'

shared_scripts {
    '@es_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/**',
}
