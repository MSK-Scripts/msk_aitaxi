if Config.Framework == 'ESX' then
    ESX = exports["es_extended"]:getSharedObject()

    ESX.RegisterServerCallback('msk_aitaxi:getOnlineTaxi', function(source, cb)
        local src = source
        local OnlineTaxi = 0
        local xPlayers = ESX.GetExtendedPlayers()

        local hasTaxiJob = function(playerJob)
            for k, job in pairs(Config.Jobs.jobs) do
                if job == playerJob then
                    return true
                end
            end
            return false
        end
    
        for k, xPlayer in pairs(xPlayers) do
            if hasTaxiJob(xPlayer.job.name) then
                OnlineTaxi = OnlineTaxi + 1
            end
        end
    
       cb(OnlineTaxi)
    end)
elseif Config.Framework == 'QBCore' then
    QBCore = exports['qb-core']:GetCoreObject()

    QBCore.Functions.CreateCallback('msk_aitaxi:getOnlineTaxi', function(source, cb)
        local src = source
        local OnlineTaxi = 0
        local Players = QBCore.Functions.GetQBPlayers()

        local hasTaxiJob = function(playerJob)
            for k, job in pairs(Config.Jobs.jobs) do
                if job == playerJob then
                    return true
                end
            end
            return false
        end

        for k, Player in pairs(Players) do
            if hasTaxiJob(Player.PlayerData.job.name) then
                OnlineTaxi = OnlineTaxi + 1
            end
        end

        cb(OnlineTaxi)
    end)
elseif Config.Framework == 'Standalone' then
    -- Add your own code here
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

RegisterNetEvent('msk_aitaxi:payTaxiPrice', function(payAmount)
    local src = source
    payAmount = round(payAmount)

    if Config.Framework == 'ESX' then
        local xPlayer = ESX.GetPlayerFromId(src)
        local account = 'money'

        if xPlayer.getAccount('money').money < payAmount then account = 'bank' end
        xPlayer.removeAccountMoney(account, payAmount)
    elseif Config.Framework == 'QBCore' then
        local Player = QBCore.Functions.GetPlayer(src)
        local account = 'cash'

        if Player.Functions.GetMoney('cash') < payAmount then account = 'bank' end
        Player.Functions.RemoveMoney(account, payAmount)
    elseif Config.Framework == 'Standalone' then
        -- Add your own code here
    end

    Config.Notification(src, Translation[Config.Locale]['paid']:format(comma(payAmount)))
    
    if Config.Society.enable then
        if Config.Framework == 'ESX' then
            TriggerEvent('esx_addonaccount:getSharedAccount', Config.Society.account, function(account)
                if not account then return print(('^1Society %s not found on Event ^2 msk_aitaxi:payTaxiPrice ^0'):format(Config.Society.account)) end
                
                account.addMoney(payAmount)
            end)
        elseif Config.Framework == 'QBCore' then
            local account = exports['qb-banking']:GetAccount(Config.Society.account)
            if not account then return print(('^1Society %s not found on Event ^2 msk_aitaxi:payTaxiPrice ^0'):format(Config.Society.account)) end
            
            exports['qb-banking']:AddMoney(Config.Society.account, payAmount, 'Taxi')
        elseif Config.Framework == 'Standalone' then
            -- Add your own code here
        end
    end
end)

GithubUpdater = function()
    local GetCurrentVersion = function()
	    return GetResourceMetadata( GetCurrentResourceName(), "version" )
    end
    
    local CurrentVersion = GetCurrentVersion()
    local resourceName = "[^2"..GetCurrentResourceName().."^0]"

    if Config.VersionChecker then
        PerformHttpRequest('https://raw.githubusercontent.com/MSK-Scripts/msk_aitaxi/main/VERSION', function(Error, NewestVersion, Header)
            if not NewestVersion then
                print(resourceName .. '^2 ✓ Resource loaded^0 - ^5Current Version: ^2' .. CurrentVersion .. '^0')
                print(resourceName .. '^1 ✗ Version Check failed. Please Update!^0 - ^6Download here:^9 https://github.com/MSK-Scripts/msk_aitaxi ^0')
                return
            end

            if CurrentVersion == NewestVersion then
                print(resourceName .. '^2 ✓ Resource is Up to Date^0 - ^5Current Version: ^2' .. CurrentVersion .. '^0')
            elseif CurrentVersion ~= NewestVersion then
                print(resourceName .. '^1 ✗ Resource Outdated. Please Update!^0 - ^5Current Version: ^1' .. CurrentVersion .. '^0')
                print('^5Newest Version: ^2' .. NewestVersion .. '^0 - ^6Download here:^9 https://github.com/MSK-Scripts/msk_aitaxi/releases/tag/v'.. NewestVersion .. '^0')
            end
        end)
    else
        print(resourceName .. '^2 ✓ Resource loaded^0 - ^5Current Version: ^2' .. CurrentVersion .. '^0')
    end
end
GithubUpdater()