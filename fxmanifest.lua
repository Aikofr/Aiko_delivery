fx_version 'cerulean'
game 'gta5'

author 'Panem - Aiko'
description 'A delivery script for Panem'
version '0.1'

shared_scripts {
    'config.lua'
}

client_scripts {
    '@PolyZone/client.lua',
    '@PolyZone/BoxZone.lua',
    '@PolyZone/CircleZone.lua', --A commenter si pas utilisé.
    'client/cl_main.lua'
}
server_script {
    'server/sv_main.lua'
}

lua54 'yes'
