-- Initialize QBCore
local QBCore = exports['qb-core']:GetCoreObject()

-- Player data table to store XP and other job-related info
local PlayerData = {}

-- Active projects
local ActiveProjects = {}

-- Register server callback for inventory shop
if Config.UseOxInventory and GetResourceState('ox_inventory') ~= 'missing' then
    exports.ox_inventory:registerShop('construction', {
        name = 'Construction Shop',
        inventory = {
            -- Tools
            { name = 'hammer', price = 250 },
            { name = 'drill', price = 500 },
            { name = 'welding_torch', price = 1000 },
            { name = 'shovel', price = 350 },
            { name = 'paint_roller', price = 200 },
            
            -- Safety gear
            { name = 'construction_helmet', price = 150 },
            { name = 'safety_vest', price = 100 },
            { name = 'work_gloves', price = 75 },
            { name = 'welding_mask', price = 250 },
            { name = 'work_belt', price = 300 },
            
            -- Materials
            { name = 'nails', price = 20 },
            { name = 'screws', price = 25 },
            { name = 'metal_rods', price = 75 },
            { name = 'asphalt_bucket', price = 100 }
        }
    })
else
    -- Setup for QB-Inventory
    -- Shop items are handled on the client side for QB-Inventory
    -- Nothing extra needed here as the client triggers "inventory:server:OpenInventory"
end

-- Initialize player data when they join
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    InitializePlayerData(src, Player.PlayerData.citizenid)
end)

-- Clean up player data when they leave
RegisterNetEvent('QBCore:Server:OnPlayerUnload', function(src)
    if PlayerData[src] then
        PlayerData[src] = nil
    end
end)

-- Initialize player data
function InitializePlayerData(src, citizenid)
    if not citizenid then return end
    
    local result = MySQL.query.await('SELECT * FROM construction_data WHERE citizenid = ?', {citizenid})
    
    if result and result[1] then
        -- Player exists in DB, load data
        PlayerData[src] = {
            citizenid = citizenid,
            xp = result[1].xp,
            rank = Vein.GetRankByXP(result[1].xp).name
        }
    else
        -- New player, create entry
        PlayerData[src] = {
            citizenid = citizenid,
            xp = 0,
            rank = Config.Ranks[1].name
        }
        
        MySQL.insert('INSERT INTO construction_data (citizenid, xp) VALUES (?, ?)', {
            citizenid,
            0
        })
    end
end

-- Save player data to database
function SavePlayerData(src)
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not PlayerData[src] then return end
    
    MySQL.update('UPDATE construction_data SET xp = ? WHERE citizenid = ?', {
        PlayerData[src].xp,
        PlayerData[src].citizenid
    })
end

-- Add XP to player
function AddXP(src, amount)
    if not PlayerData[src] then return end
    
    local oldRank = PlayerData[src].rank
    PlayerData[src].xp = PlayerData[src].xp + amount
    
    -- Check for rank up
    local newRank = Vein.GetRankByXP(PlayerData[src].xp)
    
    if newRank.name ~= oldRank then
        -- Player ranked up
        PlayerData[src].rank = newRank.name
        
        -- Notify player of rank up
        TriggerClientEvent('vein-construction:client:rankUp', src, newRank)
    end
    
    -- Save to database
    SavePlayerData(src)
    
    return PlayerData[src].xp
end

-- Set job
RegisterNetEvent('vein-construction:server:setJob', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Set job
    Player.Functions.SetJob(Config.JobName, 0)
    
    -- Initialize player data if needed
    if not PlayerData[src] then
        InitializePlayerData(src, Player.PlayerData.citizenid)
    end
    
    TriggerClientEvent('QBCore:Notify', src, 'You now work as a construction worker', 'success')
end)

-- Toggle duty
RegisterNetEvent('vein-construction:server:toggleDuty', function(onDuty)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Set duty state
    Player.Functions.SetJobDuty(onDuty)
    Player.Functions.SetMetaData("duty", onDuty)
    
    if onDuty then
        TriggerClientEvent('QBCore:Notify', src, 'You are now on duty', 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, 'You are now off duty', 'primary')
    end
end)

-- Quit job
RegisterNetEvent('vein-construction:server:quitJob', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Set player to unemployed
    Player.Functions.SetJob('unemployed', 0)
    
    -- Clean up player data
    if PlayerData[src] then
        -- Save XP before quitting
        SavePlayerData(src)
    end
    
    TriggerClientEvent('QBCore:Notify', src, 'You are no longer working as a construction worker', 'primary')
end)

-- Complete task and give rewards
RegisterNetEvent('vein-construction:server:completeTask', function(taskType, xp)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not PlayerData[src] then return end
    
    -- Add XP
    local newXP = AddXP(src, xp)
    
    -- Calculate payment based on rank
    local rankName = PlayerData[src].rank
    local payment = Vein.GetPaymentForRank(rankName)
    
    -- Give money to player
    Player.Functions.AddMoney('bank', payment, 'construction-job-payment')
    
    -- Trigger payment notification
    TriggerClientEvent('vein-construction:client:payment', src, payment)
    
    -- Calculate commissions for higher ranks
    CalculateCommissions(src, payment)
    
    -- Log task completion
    print(string.format('Player %s completed %s task, earned %d XP and $%d', 
        Player.PlayerData.citizenid, taskType, xp, payment))
end)

-- Calculate and distribute commissions to foremen and site managers
function CalculateCommissions(src, payment)
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not PlayerData[src] then return end
    
    -- Only calculate commissions for apprentices and skilled workers
    local rank = PlayerData[src].rank
    if rank == 'foreman' or rank == 'site_manager' then return end
    
    -- Get all online players with construction job
    local players = QBCore.Functions.GetQBPlayers()
    
    for _, player in pairs(players) do
        if player.PlayerData.job.name == Config.JobName and PlayerData[player.PlayerData.source] then
            local targetRank = PlayerData[player.PlayerData.source].rank
            local commission = 0
            
            -- Calculate commission based on rank
            if targetRank == 'foreman' and rank == 'apprentice' then
                -- Foremen get commission from apprentices
                for _, rankConfig in ipairs(Config.Ranks) do
                    if rankConfig.name == 'foreman' and rankConfig.commission then
                        commission = payment * rankConfig.commission
                        break
                    end
                end
            elseif targetRank == 'site_manager' then
                -- Site managers get commission from anyone lower
                for _, rankConfig in ipairs(Config.Ranks) do
                    if rankConfig.name == 'site_manager' and rankConfig.commission then
                        commission = payment * rankConfig.commission
                        break
                    end
                end
            end
            
            -- Pay commission if applicable
            if commission > 0 then
                player.Functions.AddMoney('bank', commission, 'construction-job-commission')
                TriggerClientEvent('vein-construction:client:commission', player.PlayerData.source, commission)
            end
        end
    end
end

-- Repair tools
RegisterNetEvent('vein-construction:server:repairTools', function(cost)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Check if player can afford repair cost
    if Player.Functions.GetMoney('bank') < cost then
        TriggerClientEvent('QBCore:Notify', src, 'You cannot afford this repair', 'error')
        return
    end
    
    -- Remove money
    Player.Functions.RemoveMoney('bank', cost, 'tool-repair')
    
    -- Notify client
    TriggerClientEvent('vein-construction:client:toolsRepaired', src)
end)

-- Pay fine
RegisterNetEvent('vein-construction:server:payFine', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Remove money
    Player.Functions.RemoveMoney('bank', amount, 'safety-violation-fine')
    
    -- Notify client
    TriggerClientEvent('vein-construction:client:fine', src, amount)
end)

-- Add XP directly (e.g., for passing safety inspection)
RegisterNetEvent('vein-construction:server:addXP', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    AddXP(src, amount)
end)

-- Request rank info
RegisterNetEvent('vein-construction:server:requestRankInfo', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not PlayerData[src] then return end
    
    local currentXP = PlayerData[src].xp
    local currentRank = PlayerData[src].rank
    
    -- Find current rank index and next rank XP requirement
    local nextRankXP = 0
    for i, rank in ipairs(Config.Ranks) do
        if rank.name == currentRank then
            if i < #Config.Ranks then
                nextRankXP = Config.Ranks[i + 1].xpNeeded - currentXP
            end
            break
        end
    end
    
    -- Send info to client
    TriggerClientEvent('vein-construction:client:showRankInfo', src, currentRank, currentXP, nextRankXP)
end)

-- Request rank check for task
RegisterNetEvent('vein-construction:server:requestRankCheck', function(taskType)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not PlayerData[src] then return end
    
    local currentRank = PlayerData[src].rank
    local canPerform = true
    local requiredRank = ''
    
    -- Check rank requirements for different tasks
    if (taskType == 'welding' or taskType == 'roadwork') and currentRank == 'apprentice' then
        canPerform = false
        requiredRank = 'Skilled Worker'
    end
    
    -- Send result to client
    TriggerClientEvent('vein-construction:client:rankCheckResult', src, canPerform, taskType, requiredRank)
end)

-- Check if player is site manager
RegisterNetEvent('vein-construction:server:checkIfSiteManager', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not PlayerData[src] then 
        TriggerClientEvent('vein-construction:client:siteManagerResponse', src, false)
        return 
    end
    
    local isSiteManager = PlayerData[src].rank == 'site_manager'
    TriggerClientEvent('vein-construction:client:siteManagerResponse', src, isSiteManager)
end)

-- Start new construction project
RegisterNetEvent('vein-construction:server:startProject', function(projectType, budget)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not PlayerData[src] then return end
    
    -- Check if player is site manager
    if PlayerData[src].rank ~= 'site_manager' then
        TriggerClientEvent('QBCore:Notify', src, 'Only Site Managers can start new projects', 'error')
        return
    end
    
    -- Create new project
    local projectId = #ActiveProjects + 1
    local projectName = projectType .. ' Building Project #' .. projectId
    
    -- Random coords near a construction site
    local randomSite = Config.Sites[math.random(1, #Config.Sites)]
    local location = vector3(
        randomSite.coords.x + math.random(-50, 50), 
        randomSite.coords.y + math.random(-50, 50), 
        randomSite.coords.z
    )
    
    local newProject = {
        id = projectId,
        name = projectName,
        type = projectType,
        budget = budget,
        progress = 0,
        manager = Player.PlayerData.citizenid,
        location = location
    }
    
    table.insert(ActiveProjects, newProject)
    
    -- Notify player
    TriggerClientEvent('QBCore:Notify', src, 'New project started: ' .. projectName, 'success')
    
    -- Notify all construction workers
    local players = QBCore.Functions.GetQBPlayers()
    for _, player in pairs(players) do
        if player.PlayerData.job.name == Config.JobName and player.PlayerData.source ~= src then
            TriggerClientEvent('vein-construction:client:contractJob', player.PlayerData.source, {
                name = projectName,
                manager = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
            })
        end
    end
end)

-- Get active projects
RegisterNetEvent('vein-construction:server:getActiveProjects', function()
    local src = source
    TriggerClientEvent('vein-construction:client:displayActiveProjects', src, ActiveProjects)
end)

-- Command to check construction job data
QBCore.Commands.Add('constructiondata', 'Check construction job data (Admin only)', {}, false, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Check if player is admin
    if not Player.PlayerData.job.name == 'admin' and not Player.PlayerData.job.name == 'police' then
        TriggerClientEvent('QBCore:Notify', src, 'You are not authorized to use this command', 'error')
        return
    end
    
    if not args[1] then
        -- Show data for self
        if not PlayerData[src] then
            TriggerClientEvent('QBCore:Notify', src, 'No construction data found for you', 'error')
            return
        end
        
        TriggerClientEvent('QBCore:Notify', src, 'XP: ' .. PlayerData[src].xp .. ', Rank: ' .. PlayerData[src].rank, 'primary')
    else
        -- Show data for other player
        local targetId = tonumber(args[1])
        local target = QBCore.Functions.GetPlayer(targetId)
        
        if not target then
            TriggerClientEvent('QBCore:Notify', src, 'Player not found', 'error')
            return
        end
        
        if not PlayerData[targetId] then
            TriggerClientEvent('QBCore:Notify', src, 'No construction data found for this player', 'error')
            return
        end
        
        TriggerClientEvent('QBCore:Notify', src, 'XP: ' .. PlayerData[targetId].xp .. ', Rank: ' .. PlayerData[targetId].rank, 'primary')
    end
end, 'admin')

-- Setup when resource starts
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    -- Check if construction_data table exists, if not create it
    local result = MySQL.query.await("SHOW TABLES LIKE 'construction_data'")
    
    if not result or #result == 0 then
        MySQL.update([[
            CREATE TABLE `construction_data` (
                `citizenid` varchar(50) NOT NULL,
                `xp` int(11) NOT NULL DEFAULT 0,
                PRIMARY KEY (`citizenid`)
            )
        ]])
        print('Created construction_data table')
    end
end)

-- Shared functions for the server
Vein = {}

-- Get rank based on XP
Vein.GetRankByXP = function(xp)
    local highestRankIndex = 1
    for i, rank in ipairs(Config.Ranks) do
        if xp >= rank.xpNeeded then
            highestRankIndex = i
        else
            break
        end
    end
    return Config.Ranks[highestRankIndex]
end

-- Buy item event handler
RegisterNetEvent('vein-construction:server:buyItem')
AddEventHandler('vein-construction:server:buyItem', function(itemName, itemType)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local prices = {
        -- Safety equipment
        construction_helmet = 75,
        safety_vest = 50,
        work_gloves = 35,
        safety_kit = 150,
        
        -- Tools
        hammer = 100,
        power_drill = 250,
        measuring_tape = 40,
        shovel = 120,
        welding_torch = 350,
        
        -- Materials
        concrete_mix = 45,
        lumber = 60,
        steel_beams = 120,
        bricks = 85,
        paint = 30
    }
    
    local price = prices[itemName]
    if not price then
        TriggerClientEvent('QBCore:Notify', src, 'Item not found in shop', 'error')
        return
    end
    
    -- Check if player has enough money
    if Player.PlayerData.money.cash < price then
        TriggerClientEvent('QBCore:Notify', src, 'Not enough cash', 'error')
        return
    end
    
    -- Special handling for safety kit (adds multiple items)
    if itemName == 'safety_kit' then
        -- Remove money first
        Player.Functions.RemoveMoney('cash', price, 'construction-shop-purchase')
        
        -- Add each safety item
        local success = true
        success = success and Player.Functions.AddItem('construction_helmet', 1)
        success = success and Player.Functions.AddItem('safety_vest', 1)
        success = success and Player.Functions.AddItem('work_gloves', 1)
        
        if success then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['construction_helmet'], 'add')
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['safety_vest'], 'add')
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['work_gloves'], 'add')
            TriggerClientEvent('QBCore:Notify', src, 'Safety kit purchased for $' .. price, 'success')
        else
            -- If failed, give money back
            Player.Functions.AddMoney('cash', price, 'construction-shop-refund')
            TriggerClientEvent('QBCore:Notify', src, 'Cannot carry safety kit items', 'error')
        end
        return
    end
    
    -- For regular items
    -- Remove money first
    Player.Functions.RemoveMoney('cash', price, 'construction-shop-purchase')
    
    -- Add the item
    local success = Player.Functions.AddItem(itemName, 1)
    if success then
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'add')
        TriggerClientEvent('QBCore:Notify', src, itemName:gsub("_", " "):gsub("^%l", string.upper) .. ' purchased for $' .. price, 'success')
    else
        -- If failed, give money back
        Player.Functions.AddMoney('cash', price, 'construction-shop-refund')
        TriggerClientEvent('QBCore:Notify', src, 'Cannot carry this item', 'error')
    end
end)