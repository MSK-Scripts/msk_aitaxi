local canCallTaxi = true
local taskVehicle, taskNPC, taskBlip, taskStartPosition, taskEndPosition = nil, nil, nil, nil, nil
local taskDriverName, taskDriverVoice = 'Alex', 'A_M_M_EASTSA_02_LATINO_FULL_01'
local taxiOnRoad, taxiInDriveMode, taxiDriveFinished, taxiDriveCancelled = false, false, false, false
local taskStartTime = GetGameTimer()

if Config.Command.enable then
    RegisterCommand(Config.Command.command, function(source, args, raw)
        callTaxi()
    end)
end

if Config.AbortTaxiDrive.enable then
    RegisterCommand(Config.AbortTaxiDrive.command, function(source, args, raw)
        abortTaxiDrive(true)
    end)
    RegisterKeyMapping(Config.AbortTaxiDrive.command, 'Abort Taxi Drive', 'keyboard', Config.AbortTaxiDrive.hotkey)
end

toggleCanCallTaxi = function(toggle)
    canCallTaxi = toggle
end
exports('toggleCanCallTaxi', toggleCanCallTaxi)
RegisterNetEvent('msk_aitaxi:canCallTaxi', toggleCanCallTaxi)

getStoppingLocation = function(coords)
    local _, nCoords = GetClosestVehicleNode(coords.x, coords.y, coords.z, 1, 3.0, 0)
    return nCoords
end

getVehNodeType = function(coords)
    local _, _, flags = GetVehicleNodeProperties(coords.x, coords.y, coords.z)
    return flags
end

callTaxi = function()
    if not canCallTaxi then return end
    local npcId, vehId = math.random(#Config.Taxi.pedmodels), math.random(#Config.Taxi.vehicles)
    local npc, veh = Config.Taxi.pedmodels[npcId], Config.Taxi.vehicles[vehId]
    taskDriverName = npc.name or 'Alex'
    taskDriverVoice = npc.voice or 'A_M_M_EASTSA_02_LATINO_FULL_01'

    local driverHash = GetHashKey(npc.model)
    local vehHash = GetHashKey(veh)

    loadModel(driverHash)
    loadModel(vehHash)

    local playerCoords = GetEntityCoords(PlayerPedId())
    local vehicleSpawned = spawnVehicle(driverHash, vehHash)

    if not vehicleSpawned then 
        AdvancedNotification(Translation[Config.Locale]['not_available'], 'Downtown Cab Co.', 'Taxi', 'CHAR_TAXI')
        return 
    end

    local toCoords = getStoppingLocation(playerCoords)
    local speed = (Config.SpeedZones[getVehNodeType(toCoords)] or 60) / Config.SpeedType
    TaskVehicleDriveToCoordLongrange(taskNPC, taskVehicle, toCoords.x, toCoords.y, toCoords.z, speed, Config.DrivingStyle, 5.0)
    SetPedKeepTask(taskNPC, true)
    AdvancedNotification(Translation[Config.Locale]['on_the_way'], 'Downtown Cab Co.', 'Taxi', 'CHAR_TAXI')
    taxiOnRoad = true
end
exports('callTaxi', callTaxi)

spawnVehicle = function(driverHash, vehHash)
    local found, coords = GetAvailableParkingSpots()
    if not found then return false end

    taskVehicle = CreateVehicle(vehHash, vector3(coords.x, coords.y, coords.z), coords.w, true, false)
    SetVehicleOnGroundProperly(taskVehicle)
    SetVehicleUndriveable(taskVehicle, true)
    SetVehicleIndividualDoorsLocked(taskVehicle, 0, 2)
    SetVehicleDoorCanBreak(taskVehicle, 0, false)
    SetVehicleFuelLevel(taskVehicle, 100.0)

    taskNPC = CreatePedInsideVehicle(taskVehicle, 26, driverHash, -1, true, false)
    SetBlockingOfNonTemporaryEvents(taskNPC, true)
    SetAmbientVoiceName(taskNPC, taskDriverVoice)
    SetDriverAbility(taskNPC, 1.0)
    SetPedIntoVehicle(taskNPC, taskVehicle, -1)

    taskBlip = AddBlipForEntity(taskVehicle)
    SetBlipSprite(taskBlip, 198)
    SetBlipFlashes(taskBlip, true)
    SetBlipColour(taskBlip, 5)

    return true
end

startDriveToCoords = function(waypoint)
    taskStartTime = GetGameTimer()
    taskStartPosition = GetEntityCoords(PlayerPedId())
    PlayPedAmbientSpeechNative(taskNPC, "TAXID_BEGIN_JOURNEY", "SPEECH_PARAMS_FORCE_NORMAL")

    local toCoords = getStoppingLocation(waypoint)
    taskEndPosition = toCoords
    local speed = (Config.SpeedZones[getVehNodeType(toCoords)] or 60) / Config.SpeedType
    TaskVehicleDriveToCoordLongrange(taskNPC, taskVehicle, toCoords.x, toCoords.y, toCoords.z, speed, Config.DrivingStyle, 5.0)
    SetPedKeepTask(taskNPC, true)
    taxiInDriveMode = true

    while taxiOnRoad and taxiInDriveMode and not taxiDriveFinished do
        Wait(500)
        local vehicleCoords = GetEntityCoords(taskVehicle)
        local distance = #(toCoords - vehicleCoords)

        if distance < 10.0 then
            PlayPedAmbientSpeechNative(taskNPC, "TAXID_CLOSE_AS_POSS", "SPEECH_PARAMS_FORCE_NORMAL")
            AdvancedNotification(Translation[Config.Locale]['end'], 'Downtown Cab Co.', taskDriverName, 'CHAR_TAXI')
            TriggerServerEvent('msk_aitaxi:payTaxiPrice', math.ceil(Config.Price.base + (Config.Price.tick * ((GetGameTimer() - taskStartTime) / Config.Price.tickTime))))
            taxiDriveFinished = true
            break
        end
    end

    if taxiDriveCancelled then return end

    while taxiOnRoad and not IsWaypointActive() do
        Wait(1000)
    end
    Wait(2500)
    if not taxiOnRoad then return end
    if not IsWaypointActive() then return end

    startDriveToCoords(GetBlipCoords(GetFirstBlipInfoId(8)))
end

abortTaxiDrive = function(keyPressed)
    if not taxiOnRoad then return end
    if taxiDriveCancelled then return end
    if taxiDriveFinished then return end
    taxiDriveCancelled = true

    if not taxiInDriveMode then
        AdvancedNotification(Translation[Config.Locale]['abort'], 'Downtown Cab Co.', taskDriverName, 'CHAR_TAXI')
        leaveTarget()
        return
    end

    if not taxiDriveFinished and not keyPressed then
        AdvancedNotification(Translation[Config.Locale]['abort'], 'Downtown Cab Co.', taskDriverName, 'CHAR_TAXI')
        leaveTarget()
        return
    end

    if not taxiDriveFinished and keyPressed then
        AdvancedNotification(Translation[Config.Locale]['abort'], 'Downtown Cab Co.', taskDriverName, 'CHAR_TAXI')
        TaskVehicleTempAction(taskNPC, taskVehicle, 27, 1000)
    end

    TriggerServerEvent('msk_aitaxi:payTaxiPrice', math.ceil(Config.Price.base + (Config.Price.tick * ((GetGameTimer() - taskStartTime) / Config.Price.tickTime))))
    taxiDriveFinished = true
end

leaveTarget = function()
    taxiOnRoad = false
    taxiInDriveMode = false
    taxiDriveFinished = false
    taxiDriveCancelled = false
    taskStartPosition = nil
    taskEndPosition = nil

    local blip, vehicle, npc = taskBlip, taskVehicle, taskNPC
    taskBlip = nil
    taskVehicle = nil
    taskNPC = nil

    if blip then RemoveBlip(blip) end
    if vehicle and npc then
        TaskVehicleDriveWander(npc, vehicle, 17.0, Config.DrivingStyle)
        SetVehicleDoorsShut(vehicle, true)
        SetVehicleDoorsLocked(vehicle, 2)

        for i = 0, 5 do
            SetVehicleDoorCanBreak(vehicle, i, false)
        end

        Wait(10000)

        SetPedAsNoLongerNeeded(npc)
        SetEntityAsNoLongerNeeded(vehicle)
        DeleteEntity(npc)
        DeleteEntity(vehicle)
    end
end

enteringVehicle = function(vehicle, plate, seat)
    if not taxiOnRoad then return end
    if vehicle ~= taskVehicle then return end
    if seat ~= 0 and seat ~= -1 then return end

    while true and vehicle == taskVehicle do
        if IsPedInVehicle(PlayerPedId(), vehicle, false) then
            SetPedIntoVehicle(PlayerPedId(), vehicle, 0)
            break
        end
        Wait(0)
    end
end
AddEventHandler('msk_enginetoggle:enteringVehicle', enteringVehicle)

enteredVehicle = function(vehicle, plate, seat)
    if not taxiOnRoad then return end
    
    if vehicle ~= taskVehicle then 
        abortTaxiDrive() 
        return
    end

    if taskBlip then 
        RemoveBlip(taskBlip) 
        taskBlip = nil
    end

    SetVehicleDoorsShut(vehicle, false)
    SetPedIntoVehicle(PlayerPedId(), taskVehicle, seat)
    PlayPedAmbientSpeechNative(taskNPC, "TAXID_WHERE_TO", "SPEECH_PARAMS_FORCE_NORMAL")
    AdvancedNotification(Translation[Config.Locale]['welcome']:format(taskDriverName), 'Downtown Cab Co.', taskDriverName, 'CHAR_TAXI')

    while taxiOnRoad and not IsWaypointActive() do
        Wait(1000)
    end
    Wait(2500)
    if not taxiOnRoad then return end
    if not IsWaypointActive() then return end

    startDriveToCoords(GetBlipCoords(GetFirstBlipInfoId(8)))
end
AddEventHandler('msk_enginetoggle:enteredVehicle', enteredVehicle)

exitedVehicle = function(vehicle, plate, seat)
    if not taxiOnRoad then return end
    if not taxiInDriveMode then return end
    if vehicle ~= taskVehicle then return end

    if not taxiDriveCancelled and not taxiDriveFinished then
        abortTaxiDrive()
    end

    leaveTarget()
end
AddEventHandler('msk_enginetoggle:exitedVehicle', exitedVehicle)

enteringVehicleAborted = function()
    -- Nothing to add here...
end
AddEventHandler('msk_enginetoggle:enteringVehicleAborted', enteringVehicleAborted)

if GetResourceState("msk_enginetoggle") == "missing" or GetResourceState("msk_enginetoggle") == "stopped" then
    -- Credits to ESX Legacy (https://github.com/esx-framework/esx_core/blob/main/%5Bcore%5D/es_extended/client/modules/actions.lua)
    local isEnteringVehicle, isInVehicle = false, false
    local currentVehicle = {}
    CreateThread(function()
        while true do
            local sleep = 200
            local playerPed = PlayerPedId()

            if not isInVehicle and not IsPlayerDead(PlayerId()) then
                if DoesEntityExist(GetVehiclePedIsTryingToEnter(playerPed)) and not isEnteringVehicle then
                    local vehicle = GetVehiclePedIsTryingToEnter(playerPed)
                    local plate = GetVehicleNumberPlateText(vehicle)
                    local seat = GetSeatPedIsTryingToEnter(playerPed)
                    isEnteringVehicle = true
                    enteringVehicle(vehicle, plate, seat)
                elseif not DoesEntityExist(GetVehiclePedIsTryingToEnter(playerPed)) and not IsPedInAnyVehicle(playerPed, true) and isEnteringVehicle then
                    enteringVehicleAborted()
                    isEnteringVehicle = false
                elseif IsPedInAnyVehicle(playerPed, false) then
                    isEnteringVehicle = false
                    isInVehicle = true
                    currentVehicle.vehicle = GetVehiclePedIsIn(playerPed)
                    currentVehicle.plate = GetVehicleNumberPlateText(currentVehicle.vehicle)
                    currentVehicle.seat = GetPedVehicleSeat(playerPed, currentVehicle.vehicle)
                    enteredVehicle(currentVehicle.vehicle, currentVehicle.plate, currentVehicle.seat)
                end
            elseif isInVehicle then
                if not IsPedInAnyVehicle(playerPed, false) or IsPlayerDead(PlayerId()) then
                    isInVehicle = false
                    exitedVehicle(currentVehicle.vehicle, currentVehicle.plate, currentVehicle.seat)
                    currentVehicle = {}
                end
            end

            Wait(sleep)
        end
    end)
end

CreateThread(function()
    while true do
        local sleep = 500

        if taxiOnRoad and taskVehicle then
            SetVehicleIndividualDoorsLocked(taskVehicle, 0, 2)
            SetVehicleDoorCanBreak(taskVehicle, 0, false)

            if taskEndPosition and not taxiDriveCancelled and not taxiDriveFinished then
                local speed = (Config.SpeedZones[getVehNodeType(GetEntityCoords(taskVehicle))] or Config.SpeedZones[2]) / Config.SpeedType
                TaskVehicleDriveToCoordLongrange(taskNPC, taskVehicle, taskEndPosition.x, taskEndPosition.y, taskEndPosition.z, speed, Config.DrivingStyle, 5.0)
                SetPedKeepTask(taskNPC, true)
            end
        end

        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        local sleep = 500

        if taxiOnRoad and taskVehicle and taxiInDriveMode and taskStartPosition and not taxiDriveCancelled and not taxiDriveFinished then
            sleep = 1
            HelpNotification(Translation[Config.Locale]['input']:format(Config.AbortTaxiDrive.hotkey))
            DrawGenericText(Translation[Config.Locale]['price']:format(comma(math.ceil(Config.Price.base + (Config.Price.tick * ((GetGameTimer() - taskStartTime) / Config.Price.tickTime))))))
        end

        Wait(sleep)
    end
end)

loadModel = function(modelHash)
    if not HasModelLoaded(modelHash) then
        RequestModel(modelHash)
    
        while not HasModelLoaded(modelHash) do
            Wait(1)
        end
    end
end

GetAvailableParkingSpots = function()
    local found, coords = false, {}

    for k, v in pairs(Config.SpawnCoords) do
		if ESX.Game.IsSpawnPointClear(vector3(v.x, v.y, v.z), 3.0) then
			found = true 
            coords = v
			break
		end
	end

    if found then
        return true, coords
    else
        return false
    end
end

GetPedVehicleSeat = function(ped, vehicle)
    for i = -1, 16 do
        if (GetPedInVehicleSeat(vehicle, i) == ped) then return i end
    end
    return -1
end

round = function(num, decimal)
    return tonumber(string.format("%." .. (decimal or 0) .. "f", num))
end

comma = function(int, tag)
    if not tag then tag = '.' end
    local newInt = int

    while true do  
        newInt, k = string.gsub(newInt, "^(-?%d+)(%d%d%d)", '%1'..tag..'%2')

        if (k == 0) then
            break
        end
    end

    return newInt
end

HelpNotification = function(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

DrawGenericText = function(text)
	SetTextColour(Config.Price.color.r, Config.Price.color.g, Config.Price.color.b, Config.Price.color.a)
	SetTextFont(0)
	SetTextScale(0.30, 0.30)
	SetTextWrap(0.0, 1.0)
	SetTextCentre(true)
	SetTextDropshadow(0, 0, 0, 0, 255)
	SetTextEdge(1, 0, 0, 0, 205)
    SetTextOutline()
	BeginTextCommandDisplayText("STRING")
	AddTextComponentSubstringPlayerName(text)
	EndTextCommandDisplayText(Config.Price.position.width, Config.Price.position.height)
end

AdvancedNotification = function(text, title, subtitle, icon, flash, icontype)
    if not flash then flash = true end
    if not icontype then icontype = 1 end
    if not icon then icon = 'CHAR_TAXI' end

    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandThefeedPostMessagetext(icon, icon, flash, icontype, title, subtitle)
	EndTextCommandThefeedPostTicker(false, true)
end