-- XP and progression related functions

-- Check for rank requirements for different tasks
function MeetsRankRequirement(rank, task)
    if task == 'lifting' or task == 'hammering' or task == 'drilling' then
        -- These tasks can be done by anyone
        return true
    elseif task == 'welding' or task == 'roadwork' then
        -- These require at least skilled worker rank
        return rank ~= 'apprentice'
    end
    return true
end

-- Get next rank for player
function GetNextRank(currentRank)
    for i, rank in ipairs(Config.Ranks) do
        if rank.name == currentRank and i < #Config.Ranks then
            return Config.Ranks[i + 1]
        end
    end
    return nil -- Already at highest rank
end

-- Get XP needed for next rank
function GetXpForNextRank(currentXp)
    local nextRank = nil
    
    for i, rank in ipairs(Config.Ranks) do
        if currentXp < rank.xpNeeded then
            nextRank = rank
            break
        end
    end
    
    if not nextRank then
        return 0 -- Already at max rank
    end
    
    return nextRank.xpNeeded - currentXp
end

-- Calculate bonus XP based on streak (completing tasks without breaks)
function CalculateStreakBonus(streak)
    if streak <= 1 then
        return 0
    elseif streak <= 5 then
        return math.floor(streak)
    else
        return 5 + math.floor((streak - 5) / 2)
    end
end

-- Generate a random task for player based on rank and location
function GenerateRandomTask(rank, siteIndex)
    local site = Config.Sites[siteIndex]
    if not site then return nil end
    
    local availableTasks = {}
    
    -- Add tasks based on rank
    if site.tasks.lifting and #site.tasks.lifting > 0 then
        table.insert(availableTasks, 'lifting')
    end
    
    if site.tasks.hammering and #site.tasks.hammering > 0 then
        table.insert(availableTasks, 'hammering')
    end
    
    if site.tasks.drilling and #site.tasks.drilling > 0 then
        table.insert(availableTasks, 'drilling')
    end
    
    if rank ~= 'apprentice' then
        if site.tasks.welding and #site.tasks.welding > 0 then
            table.insert(availableTasks, 'welding')
        end
        
        if site.tasks.roadwork and #site.tasks.roadwork > 0 then
            table.insert(availableTasks, 'roadwork')
        end
    end
    
    if #availableTasks == 0 then return nil end
    
    return availableTasks[math.random(1, #availableTasks)]
end

-- For Foremen and Site Managers: Generate work orders for subordinates
function GenerateWorkOrders(src, siteIndex)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not PlayerData[src] then return end
    
    -- Only Foremen and Site Managers can generate work orders
    if PlayerData[src].rank ~= 'foreman' and PlayerData[src].rank ~= 'site_manager' then
        TriggerClientEvent('QBCore:Notify', src, 'Only Foremen and Site Managers can assign work', 'error')
        return
    end
    
    local site = Config.Sites[siteIndex]
    if not site then return end
    
    -- Get all online construction workers
    local players = QBCore.Functions.GetQBPlayers()
    local workOrders = {}
    
    for _, player in pairs(players) do
        if player.PlayerData.job.name == Config.JobName and player.PlayerData.source ~= src then
            -- Check if player is subordinate
            if PlayerData[player.PlayerData.source] then
                local subordinateRank = PlayerData[player.PlayerData.source].rank
                
                -- Foremen can only assign to apprentices, Site Managers to everyone except other Site Managers
                if (PlayerData[src].rank == 'foreman' and subordinateRank == 'apprentice') or
                   (PlayerData[src].rank == 'site_manager' and subordinateRank ~= 'site_manager') then
                    
                    -- Generate random task for player
                    local task = GenerateRandomTask(subordinateRank, siteIndex)
                    
                    if task then
                        table.insert(workOrders, {
                            playerName = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname,
                            playerId = player.PlayerData.source,
                            rank = subordinateRank,
                            task = task
                        })
                    end
                end
            end
        end
    end
    
    -- Send work orders to client
    TriggerClientEvent('vein-construction:client:showWorkOrders', src, workOrders, site.name)
end

-- For Foremen and Site Managers: Assign work to a subordinate
RegisterNetEvent('vein-construction:server:assignWork', function(targetId, task, siteIndex)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local TargetPlayer = QBCore.Functions.GetPlayer(targetId)
    
    if not Player or not TargetPlayer or not PlayerData[src] or not PlayerData[targetId] then return end
    
    -- Only Foremen and Site Managers can assign work
    if PlayerData[src].rank ~= 'foreman' and PlayerData[src].rank ~= 'site_manager' then
        TriggerClientEvent('QBCore:Notify', src, 'Only Foremen and Site Managers can assign work', 'error')
        return
    end
    
    -- Check if target is subordinate
    local subordinateRank = PlayerData[targetId].rank
    if (PlayerData[src].rank == 'foreman' and subordinateRank ~= 'apprentice') or
       (PlayerData[src].rank == 'site_manager' and subordinateRank == 'site_manager') then
        TriggerClientEvent('QBCore:Notify', src, 'You cannot assign work to this employee', 'error')
        return
    end
    
    -- Check if task is valid for rank
    if not MeetsRankRequirement(subordinateRank, task) then
        TriggerClientEvent('QBCore:Notify', src, 'This worker cannot perform this task', 'error')
        return
    end
    
    -- Notify target player about assigned work
    TriggerClientEvent('vein-construction:client:workAssigned', targetId, {
        task = task,
        siteIndex = siteIndex,
        assignedBy = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    })
    
    TriggerClientEvent('QBCore:Notify', src, 'Work assigned to ' .. TargetPlayer.PlayerData.charinfo.firstname, 'success')
end)

-- Complete assigned work
RegisterNetEvent('vein-construction:server:completeAssignedWork', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not PlayerData[src] then return end
    
    -- Add bonus XP for completing assigned work
    local taskXP = Config.TaskXP[data.task] or 5
    local bonusXP = math.floor(taskXP * 0.25) -- 25% bonus for assigned work
    
    -- Add XP
    local totalXP = taskXP + bonusXP
    AddXP(src, totalXP)
    
    -- Calculate payment based on rank with bonus
    local rankName = PlayerData[src].rank
    local payment = Vein.GetPaymentForRank(rankName)
    local bonusPayment = math.floor(payment * 0.15) -- 15% bonus for assigned work
    local totalPayment = payment + bonusPayment
    
    -- Give money to player
    Player.Functions.AddMoney('bank', totalPayment, 'construction-assigned-work-payment')
    
    -- Trigger payment notification
    TriggerClientEvent('vein-construction:client:payment', src, totalPayment)
    
    -- Calculate commissions for the assigner
    local assignerId = data.assignerId
    if QBCore.Functions.GetPlayer(assignerId) then
        local assigner = QBCore.Functions.GetPlayer(assignerId)
        local commission = math.floor(totalPayment * 0.1) -- 10% commission for assigning work
        
        assigner.Functions.AddMoney('bank', commission, 'construction-assignment-commission')
        TriggerClientEvent('vein-construction:client:commission', assignerId, commission)
    end
    
    -- Notify player
    TriggerClientEvent('QBCore:Notify', src, 'Assigned work completed! Bonus: +' .. bonusXP .. ' XP and +$' .. bonusPayment, 'success')
end)

-- Get work orders for management view
RegisterNetEvent('vein-construction:server:requestWorkOrders', function(siteIndex)
    local src = source
    GenerateWorkOrders(src, siteIndex)
end)

-- Add XP command for admins
QBCore.Commands.Add('addconstructionxp', 'Add XP to construction worker (Admin only)', {{name = 'id', help = 'Player ID'}, {name = 'amount', help = 'Amount of XP'}}, true, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Check if player is admin
    if Player.PlayerData.job.name ~= 'admin' and Player.PlayerData.job.name ~= 'police' then
        TriggerClientEvent('QBCore:Notify', src, 'You are not authorized to use this command', 'error')
        return
    end
    
    local targetId = tonumber(args[1])
    local amount = tonumber(args[2])
    
    if not targetId or not amount then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid arguments', 'error')
        return
    end
    
    local target = QBCore.Functions.GetPlayer(targetId)
    
    if not target then
        TriggerClientEvent('QBCore:Notify', src, 'Player not found', 'error')
        return
    end
    
    if not PlayerData[targetId] then
        TriggerClientEvent('QBCore:Notify', src, 'Player does not have construction data', 'error')
        return
    end
    
    -- Add XP
    AddXP(targetId, amount)
    
    TriggerClientEvent('QBCore:Notify', src, 'Added ' .. amount .. ' XP to ' .. target.PlayerData.charinfo.firstname, 'success')
    TriggerClientEvent('QBCore:Notify', targetId, 'You received ' .. amount .. ' construction XP from an admin', 'success')
end, 'admin')

-- Set rank command for admins
QBCore.Commands.Add('setconstructionrank', 'Set construction rank (Admin only)', {{name = 'id', help = 'Player ID'}, {name = 'rank', help = 'Rank name (apprentice, skilled_worker, foreman, site_manager)'}}, true, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Check if player is admin
    if Player.PlayerData.job.name ~= 'admin' and Player.PlayerData.job.name ~= 'police' then
        TriggerClientEvent('QBCore:Notify', src, 'You are not authorized to use this command', 'error')
        return
    end
    
    local targetId = tonumber(args[1])
    local rankName = args[2]
    
    if not targetId or not rankName then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid arguments', 'error')
        return
    end
    
    local target = QBCore.Functions.GetPlayer(targetId)
    
    if not target then
        TriggerClientEvent('QBCore:Notify', src, 'Player not found', 'error')
        return
    end
    
    if not PlayerData[targetId] then
        TriggerClientEvent('QBCore:Notify', src, 'Player does not have construction data', 'error')
        return
    end
    
    -- Check if rank is valid
    local rankFound = false
    local requiredXP = 0
    
    for _, rank in ipairs(Config.Ranks) do
        if rank.name == rankName then
            rankFound = true
            requiredXP = rank.xpNeeded
            break
        end
    end
    
    if not rankFound then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid rank name', 'error')
        return
    end
    
    -- Set rank and XP
    PlayerData[targetId].rank = rankName
    PlayerData[targetId].xp = requiredXP
    
    -- Save to database
    SavePlayerData(targetId)
    
    TriggerClientEvent('QBCore:Notify', src, 'Set ' .. target.PlayerData.charinfo.firstname .. '\'s rank to ' .. rankName, 'success')
    TriggerClientEvent('QBCore:Notify', targetId, 'Your construction rank was set to ' .. rankName, 'success')
    
    -- Trigger rank up notification on client
    for _, rank in ipairs(Config.Ranks) do
        if rank.name == rankName then
            TriggerClientEvent('vein-construction:client:rankUp', targetId, rank)
            break
        end
    end
end, 'admin') 