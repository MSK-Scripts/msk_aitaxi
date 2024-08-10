Config = {}
----------------------------------------------------------------
Config.Locale = 'de'
Config.VersionChecker = true
----------------------------------------------------------------
-- !!! This function is clientside AND serverside !!!
Config.Notification = function(source, message, typ)
    if IsDuplicityVersion() then -- serverside
        exports.msk_core:Notification(source, 'AI Taxi', message, typ)
    else -- clientside
        exports.msk_core:Notification('AI Taxi', message, typ)
    end
end
----------------------------------------------------------------
-- You'll need esx_addonaccount for that!
Config.Society = {
    enable = false, -- Set false if you don't want that the Price will be added to a society account
    account = 'society_taxi'
}
----------------------------------------------------------------
-- If you deactivate the command, you can still use the export: exports.msk_aitaxi:callTaxi()
Config.Command = {
    enable = true,
    command = 'callTaxi'
}

Config.AbortTaxiDrive = {
    enable = true,
    command = 'abortTaxi',
    hotkey = 'X'
}

-- You can set multiple spawn points
Config.SpawnCoords = {
    vector4(902.85, -143.56, 76.6, 322.2),
}

Config.DrivingStyle = 786731 -- default: 786731 // https://vespura.com/fivem/drivingstyle/
Config.SpeedType = 3.6 -- kmh = 3.6 // mph = 2.236936
Config.SpeedZones = {
    -- Speed of the Taxi in specific zones
    [2] = 100, -- City / main roads
    [10] = 60, -- Slow roads
    [64] = 60, -- Off road
    [66] = 150, -- Freeway
    [82] = 150, -- Freeway tunnels
}

Config.Price = {
    base = 20, -- Price for driving to your position
    tick = 0.15, -- Price per tick
    tickTime = 50, 

    color = {r = 255, g = 255, b = 255, a = 255},
    position = {height = 0.90, width = 0.50}
}
----------------------------------------------------------------
-- It will use a random vehicle and random pedmodel from the list below
Config.Taxi = {
    vehicles = {
        -- You can set different models
        'taxi',
        'taxi',
    },
    pedmodels = {
        -- You can set different models
        {name = 'Michael Reynold', model = 'a_m_y_stlat_01', voice = 'A_M_M_EASTSA_02_LATINO_FULL_01'},
        {name = 'John Smith', model = 'a_m_y_smartcaspat_01', voice = 'A_M_M_EASTSA_02_LATINO_FULL_01'},
    },
}