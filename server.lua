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
    local xPlayer = ESX.GetPlayerFromId(src)
    local account = 'money'
    payAmount = round(payAmount)

    if xPlayer.getAccount('money').money < payAmount then account = 'bank' end
    xPlayer.removeAccountMoney(account, payAmount)
    Config.Notification(src, Translation[Config.Locale]['paid']:format(comma(payAmount)))
    
    if Config.Society.enable then
        TriggerEvent('esx_addonaccount:getSharedAccount', Config.Society.account, function(account)
            if not account then return print(('^1Society %s not found on Event ^2 msk_aitaxi:payTaxiPrice ^0'):format(Config.Society.account)) end
            account.addMoney(payAmount)
        end)
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