fx_version 'cerulean'
games { 'gta5' }

author 'Musiker15 - MSK Scripts'
name 'msk_aitaxi'
description 'AI Taxi NPC'
version '1.0.0'

lua54 'yes'

shared_scripts {
	'@es_extended/imports.lua',
	'config.lua',
	'translation.lua'
}

client_scripts {
	'client.lua'
}

server_scripts {
	'server.lua'
}