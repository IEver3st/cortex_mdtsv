fx_version 'cerulean'
game 'gta5'
lua54 'yes'

dependency 'es_lib'

description 'Cortex MDT - Mobile Data Terminal'
author 'Ever3st'
version '1.0.0'

exports {
    'getOfficerData',
    'isOfficerOnDuty',
    'getFrameworkMode',
}

shared_scripts {
    '@es_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
    'client/cameras.lua',
    'client/dispatch.lua',
}

server_scripts {
    'server/db.lua',
    'server/main.lua',
    'server/core.lua',
    'server/callbackRegistry.lua',
    'server/storage/localStorage.lua',
    'server/storage/sessionStore.lua',
    'server/storage/profilePrefs.lua',
    'server/storage/sqlStore.lua',
    'server/framework/qbox/provider.lua',
    'server/framework/standalone/provider.lua',
    'server/framework/ers/provider.lua',
    'server/framework/common.lua',
    'server/pages/index.lua',
    'server/localStorage.lua',
    'server/citations.lua',
    'server/data.lua',
    'server/ers.lua',
    'server/cameras.lua',
    'server/dispatch.lua',
}

ui_page 'html/index.html'

files {
    'html/**',
    'data/cctv_presets.json',
}
