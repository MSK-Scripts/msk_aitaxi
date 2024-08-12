local canCallTaxi = true
local task, taxi = {}, {}

if Config.Framework == 'ESX' then
    ESX = exports["es_extended"]:getSharedObject()
elseif Config.Framework == 'QBCore' then
    QBCore = exports['qb-core']:GetCoreObject()
elseif Config.Framework == 'Standalone' then
    -- Add your own code here
end

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

getCanCallTaxi = function()
    if not canCallTaxi then return false end
    if not Config.Jobs.enable then return canCallTaxi end
    local p = promise.new()

    if Config.Framework == 'ESX' then
        ESX.TriggerServerCallback('msk_aitaxi:getOnlineTaxi', function(OnlineTaxi)
            p:resolve(OnlineTaxi)
        end)
    elseif Config.Framework == 'QBCore' then
        QBCore.Functions.TriggerCallback('msk_aitaxi:getOnlineTaxi', function(OnlineTaxi)
            p:resolve(OnlineTaxi)
        end)
    elseif Config.Framework == 'Standalone' then
        -- Add your own code here
    end

    local result = Citizen.Await(p)
    return result <= Config.Jobs.amount
end
exports('getCanCallTaxi', getCanCallTaxi)

getStartingLocation = function(coords)
    local found, spawnPos, spawnHeading = GetClosestVehicleNodeWithHeading(coords.x + math.random(-Config.SpawnRadius, Config.SpawnRadius), coords.y + math.random(-Config.SpawnRadius, Config.SpawnRadius), coords.z, 0, 3.0, 0)
    return found, spawnPos, spawnHeading
end

getStoppingLocation = function(coords)
    local _, nCoords = GetClosestVehicleNode(coords.x, coords.y, coords.z, 1, 3.0, 0)
    return nCoords
end

getVehNodeType = function(coords)
    local _, _, flags = GetVehicleNodeProperties(coords.x, coords.y, coords.z)
    return flags
end

callTaxi = function()
    if not getCanCallTaxi() then return end
    local npcId, vehId = math.random(#Config.Taxi.pedmodels), math.random(#Config.Taxi.vehicles)
    local npc, veh = Config.Taxi.pedmodels[npcId], Config.Taxi.vehicles[vehId]
    taxi.driverName = npc.name or 'Alex'
    taxi.driverVoice = npc.voice or 'A_M_M_EASTSA_02_LATINO_FULL_01'

    local driverHash = GetHashKey(npc.model)
    local vehHash = GetHashKey(veh)

    loadModel(driverHash)
    loadModel(vehHash)

    local playerCoords = GetEntityCoords(PlayerPedId())
    local vehicleSpawned = spawnVehicle(playerCoords, driverHash, vehHash)

    if not vehicleSpawned then 
        AdvancedNotification(Translation[Config.Locale]['not_available'], 'Downtown Cab Co.', 'Taxi', 'CHAR_TAXI')
        return 
    end

    startDriveToPlayer(playerCoords)
end
exports('callTaxi', callTaxi)

spawnVehicle = function(playerCoords, driverHash, vehHash)
    local found, coords, heading = getStartingLocation(playerCoords)
    if not found then return false end

    task.vehicle = CreateVehicle(vehHash, vector3(coords.x, coords.y, coords.z), heading, true, true)
    SetVehicleOnGroundProperly(task.vehicle)
    SetVehicleEngineOn(task.vehicle, true, true, false)
    SetVehicleUndriveable(task.vehicle, true)
    SetVehicleIndividualDoorsLocked(task.vehicle, 0, 2)
    SetVehicleDoorCanBreak(task.vehicle, 0, false)
    SetVehicleFuelLevel(task.vehicle, 100.0)
    DecorSetFloat(task.vehicle, '_FUEL_LEVEL', 100.0)
    SetEntityAsMissionEntity(task.vehicle, true, true)

    task.npc = CreatePedInsideVehicle(task.vehicle, 26, driverHash, -1, true, true)
    SetAmbientVoiceName(task.npc, taxi.driverVoice)
    SetBlockingOfNonTemporaryEvents(task.npc, true)
    SetDriverAbility(task.npc, 1.0)
    SetEntityAsMissionEntity(task.npc, true, true)

    task.blip = AddBlipForEntity(task.vehicle)
    SetBlipSprite(task.blip, 198)
    SetBlipFlashes(task.blip, true)
    SetBlipColour(task.blip, 5)

    return true
end

startDriveToPlayer = function(playerCoords)
    local toCoords = getStoppingLocation(playerCoords)
    local speed = (Config.SpeedZones[getVehNodeType(toCoords)] or Config.SpeedZones[2]) / Config.SpeedType

    TaskVehicleDriveToCoordLongrange(task.npc, task.vehicle, toCoords.x, toCoords.y, toCoords.z, speed, Config.DrivingStyle, 5.0)
    SetPedKeepTask(task.npc, true)
    AdvancedNotification(Translation[Config.Locale]['on_the_way'], 'Downtown Cab Co.', 'Taxi', 'CHAR_TAXI')
    taxi.onRoad = true

    while taxi.onRoad and not taxi.inDriveMode do
        Wait(500)
        local vehicleCoords = GetEntityCoords(task.vehicle)
        local distance = #(toCoords - vehicleCoords)

        if distance > 20.0 then
            local speed = (Config.SpeedZones[getVehNodeType(vehicleCoords)] or Config.SpeedZones[2]) / Config.SpeedType
            TaskVehicleDriveToCoordLongrange(task.npc, task.vehicle, toCoords.x, toCoords.y, toCoords.z, speed, Config.DrivingStyle, 5.0)
            SetPedKeepTask(task.npc, true)
        end
        
        if distance <= 20.0 then
            local speed = (Config.SpeedZones[getVehNodeType(toCoords)] or Config.SpeedZones[2]) / Config.SpeedType
            TaskVehicleDriveToCoordLongrange(task.npc, task.vehicle, toCoords.x, toCoords.y, toCoords.z, speed / 2, Config.DrivingStyle, 5.0)
            SetPedKeepTask(task.npc, true)
            break
        end
    end
end

checkWaypoint = function()
    while taxi.onRoad and not IsWaypointActive() do
        Wait(1000)
    end
    Wait(2500)
    if not taxi.onRoad then return end
    if not IsWaypointActive() then return end

    taxi.finished = false
    startDriveToCoords(GetBlipCoords(GetFirstBlipInfoId(8)))
end

startDriveToCoords = function(waypoint)
    task.startTime = GetGameTimer()
    PlayPedAmbientSpeechNative(task.npc, "TAXID_BEGIN_JOURNEY", "SPEECH_PARAMS_FORCE_NORMAL")

    local toCoords = getStoppingLocation(waypoint)
    local speed = (Config.SpeedZones[getVehNodeType(toCoords)] or Config.SpeedZones[2]) / Config.SpeedType
    TaskVehicleDriveToCoordLongrange(task.npc, task.vehicle, toCoords.x, toCoords.y, toCoords.z, speed, Config.DrivingStyle, 5.0)
    SetPedKeepTask(task.npc, true)
    taxi.inDriveMode = true
    CreateThread(drawPrice)

    while taxi.onRoad and taxi.inDriveMode and not taxi.canceled and not taxi.finished do
        Wait(500)
        if taxi.canceled then return end
        local vehicleCoords = GetEntityCoords(task.vehicle)
        local distance = #(toCoords - vehicleCoords)

        if distance > 20.0 then
            local speed = (Config.SpeedZones[getVehNodeType(vehicleCoords)] or Config.SpeedZones[2]) / Config.SpeedType
            TaskVehicleDriveToCoordLongrange(task.npc, task.vehicle, toCoords.x, toCoords.y, toCoords.z, speed, Config.DrivingStyle, 5.0)
            SetPedKeepTask(task.npc, true)
        end

        if distance <= 20.0 then
            local speed = (Config.SpeedZones[getVehNodeType(vehicleCoords)] or Config.SpeedZones[2]) / Config.SpeedType
            TaskVehicleDriveToCoordLongrange(task.npc, task.vehicle, toCoords.x, toCoords.y, toCoords.z, speed / 2, Config.DrivingStyle, 5.0)
            SetPedKeepTask(task.npc, true)
        end

        if distance < 10.0 then
            PlayPedAmbientSpeechNative(task.npc, "TAXID_CLOSE_AS_POSS", "SPEECH_PARAMS_FORCE_NORMAL")
            AdvancedNotification(Translation[Config.Locale]['end'], 'Downtown Cab Co.', taxi.driverName, 'CHAR_TAXI')
            TriggerServerEvent('msk_aitaxi:payTaxiPrice', math.ceil(Config.Price.base + (Config.Price.tick * ((GetGameTimer() - task.startTime) / Config.Price.tickTime))))
            taxi.finished = true
            break
        end
    end

    if taxi.canceled then return end
    checkWaypoint()
end

abortTaxiDrive = function(keyPressed)
    if not taxi.onRoad then return end
    if taxi.canceled then return end
    if taxi.finished then return end
    taxi.canceled = true

    if not taxi.inDriveMode then
        AdvancedNotification(Translation[Config.Locale]['abort'], 'Downtown Cab Co.', taxi.driverName, 'CHAR_TAXI')
        leaveTarget()
        return
    end

    if not taxi.finished and not keyPressed then
        AdvancedNotification(Translation[Config.Locale]['abort'], 'Downtown Cab Co.', taxi.driverName, 'CHAR_TAXI')
        leaveTarget()
        return
    end

    if not taxi.finished and keyPressed then
        AdvancedNotification(Translation[Config.Locale]['abort'], 'Downtown Cab Co.', taxi.driverName, 'CHAR_TAXI')
        TaskVehicleTempAction(task.npc, task.vehicle, 27, 1000)
    end

    TriggerServerEvent('msk_aitaxi:payTaxiPrice', math.ceil(Config.Price.base + (Config.Price.tick * ((GetGameTimer() - task.startTime) / Config.Price.tickTime))))
    taxi.finished = true
end

leaveTarget = function()
    local blip, vehicle, npc = task.blip, task.vehicle, task.npc
    taxi = {}
    task = {}

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
    if not taxi.onRoad then return end
    if vehicle ~= task.vehicle then return end
    if seat ~= 0 and seat ~= -1 then return end

    while true and vehicle == task.vehicle do
        if IsPedInVehicle(PlayerPedId(), vehicle, false) then
            SetPedIntoVehicle(PlayerPedId(), vehicle, 0)
            break
        end
        Wait(0)
    end
end
AddEventHandler('msk_enginetoggle:enteringVehicle', enteringVehicle)

enteredVehicle = function(vehicle, plate, seat)
    if not taxi.onRoad then return end
    
    if vehicle ~= task.vehicle then 
        abortTaxiDrive() 
        return
    end

    if task.blip then 
        RemoveBlip(task.blip) 
        task.blip = nil
    end

    SetVehicleDoorsShut(vehicle, false)
    SetPedIntoVehicle(PlayerPedId(), task.vehicle, seat)
    PlayPedAmbientSpeechNative(task.npc, "TAXID_WHERE_TO", "SPEECH_PARAMS_FORCE_NORMAL")
    AdvancedNotification(Translation[Config.Locale]['welcome']:format(taxi.driverName), 'Downtown Cab Co.', taxi.driverName, 'CHAR_TAXI')

    if taxi.entered then return end
    taxi.entered = true
    checkWaypoint()
end
AddEventHandler('msk_enginetoggle:enteredVehicle', enteredVehicle)

exitedVehicle = function(vehicle, plate, seat)
    if not taxi.onRoad then return end
    if not taxi.inDriveMode then return end
    if vehicle ~= task.vehicle then return end

    if not taxi.canceled and not taxi.finished then
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

        if taxi.onRoad and task.vehicle then
            SetVehicleIndividualDoorsLocked(task.vehicle, 0, 2)
            SetVehicleDoorCanBreak(task.vehicle, 0, false)
        end

        Wait(sleep)
    end
end)

drawPrice = function()
    while taxi.onRoad and taxi.inDriveMode and not taxi.canceled and not taxi.finished do
        local sleep = 1

        HelpNotification(Translation[Config.Locale]['input']:format(Config.AbortTaxiDrive.hotkey))
        DrawGenericText(Translation[Config.Locale]['price']:format(comma(math.ceil(Config.Price.base + (Config.Price.tick * ((GetGameTimer() - task.startTime) / Config.Price.tickTime))))))

        Wait(sleep)
    end
end

loadModel = function(modelHash)
    if not HasModelLoaded(modelHash) then
        RequestModel(modelHash)
    
        while not HasModelLoaded(modelHash) do
            Wait(1)
        end
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

AdvancedNotification = function(text, title, subtitle, icon, flash, icontype)
    if not flash then flash = true end
    if not icontype then icontype = 1 end
    if not icon then icon = 'CHAR_HUMANDEFAULT' end

    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandThefeedPostMessagetext(icon, icon, flash, icontype, title, subtitle)
	EndTextCommandThefeedPostTicker(false, true)
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