-- Server events for Construction Job

local QBCore = exports['qb-core']:GetCoreObject()

-- Server events

RegisterNetEvent('vein-construction:server:buyItem', function(item, price)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Check if player has enough money
    if Player.Functions.GetMoney('cash') < price then
        TriggerClientEvent('QBCore:Notify', src, 'You don\'t have enough money', 'error')
        return
    end

    -- Remove money and add item
    if Player.Functions.RemoveMoney('cash', price) then
        Player.Functions.AddItem(item, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'add')
        TriggerClientEvent('QBCore:Notify', src, 'You purchased ' .. QBCore.Shared.Items[item].label, 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Failed to purchase item', 'error')
    end
end)

RegisterNetEvent('vein-construction:server:getAvailableWorkers', function(projectId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- This would normally query the database for available workers
    -- For now, return some example data
    local workers = {
        {
            id = 1,
            name = "John Smith",
            rank = "Journeyman",
            hourlyRate = 25
        },
        {
            id = 2,
            name = "Mike Johnson",
            rank = "Apprentice",
            hourlyRate = 15
        },
        {
            id = 3,
            name = "Sarah Williams",
            rank = "Craftsman",
            hourlyRate = 35
        }
    }
    
    TriggerClientEvent('vein-construction:client:displayAvailableWorkers', src, workers, projectId)
end)

RegisterNetEvent('vein-construction:server:assignWorker', function(workerId, projectId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- This would normally update the database
    -- For now, just send a confirmation
    TriggerClientEvent('vein-construction:client:workerAssigned', src, "Worker #" .. workerId, "Project #" .. projectId)
end)

RegisterNetEvent('vein-construction:server:getProjectDetails', function(projectId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- This would normally query the database for project details
    -- For now, return some example data
    local project = {
        id = projectId,
        name = "Construction Project #" .. projectId,
        type = "Building",
        budget = 50000,
        progress = 35,
        location = vector3(100.0, 100.0, 30.0)
    }
    
    -- This function doesn't exist yet, you would need to create it on the client side
    TriggerClientEvent('vein-construction:client:displayProjectDetails', src, project)
end)

RegisterNetEvent('vein-construction:server:startProject', function(projectType, budget)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- This would normally create a new project in the database
    -- For now, just send a confirmation
    TriggerClientEvent('QBCore:Notify', src, 'Started new ' .. projectType .. ' project with budget $' .. budget, 'success')
end)

RegisterNetEvent('vein-construction:server:getActiveProjects', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- This would normally query the database for active projects
    -- For now, return some example data
    local projects = {
        {
            id = 1,
            name = "Downtown Office",
            type = "Commercial",
            budget = 100000,
            progress = 60,
            location = vector3(125, 215, 30)
        },
        {
            id = 2,
            name = "Vinewood Heights",
            type = "Residential",
            budget = 75000,
            progress = 25,
            location = vector3(300, 400, 35)
        }
    }
    
    TriggerClientEvent('vein-construction:client:displayActiveProjects', src, projects)
end)

RegisterNetEvent('vein-construction:server:checkIfSiteManager', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- This would normally check if the player is a site manager
    -- For now, assume they are if they're a construction worker
    local isSiteManager = Player.PlayerData.job.name == 'construction' and Player.PlayerData.job.grade >= 3
    
    TriggerClientEvent('vein-construction:client:siteManagerResponse', src, isSiteManager)
end)

print('Construction Job: Server events initialized') 