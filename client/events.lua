-- Initialize QBCore
local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = QBCore.Functions.GetPlayerData()

-- Register an event to expose the ShowMenu function
RegisterNetEvent('vein-construction:internal:showMenu')
AddEventHandler('vein-construction:internal:showMenu', function(id, title, options, parent)
    -- This will be handled by the function in ui.lua
end)

-- Function to handle notifications based on available libraries
function SendNotification(title, message, type, icon)
    -- Determine if we have message + title or just message
    if type(message) == 'string' then
        -- We have both title and message
        QBCore.Functions.Notify({
            text = message,
            caption = title,
            type = type or 'primary',
            duration = 5000
        })
    else
        -- Only have message (in title parameter)
        QBCore.Functions.Notify(title, message or 'primary', 5000)
    end
end

-- Register events for random occurrences and special cases
-- Notification for rank up
RegisterNetEvent('vein-construction:client:rankUp', function(newRank)
    -- Check if newRank is a table or string
    local rankName = type(newRank) == 'table' and (newRank.label or newRank.name) or newRank
    
    -- Make sure we have a valid string for the notification
    if not rankName or type(rankName) ~= 'string' then
        rankName = 'a new rank'
    end
    
    SendNotification('Congratulations! You have been promoted to ' .. rankName, 'success')
    
    -- Play celebration sound
    PlaySoundFrontend(-1, "MEDAL_UP", "HUD_MINI_GAME_SOUNDSET", 1)
    
    -- Trigger visual effect
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    
    RequestNamedPtfxAsset("scr_rcbarry2")
    while not HasNamedPtfxAssetLoaded("scr_rcbarry2") do
        Wait(10)
    end
    
    UseParticleFxAssetNextCall("scr_rcbarry2")
    local particle = StartParticleFxLoopedAtCoord("scr_clown_appears", coords.x, coords.y, coords.z - 0.5, 0.0, 0.0, 0.0, 1.0, false, false, false, false)
    SetParticleFxLoopedColour(particle, 0.0, 1.0, 0.0, 0)
    
    Wait(3000)
    StopParticleFxLooped(particle, 0)
end)

-- Notification for commission earned
RegisterNetEvent('vein-construction:client:commissionEarned', function(amount)
    SendNotification('You earned a commission of $' .. amount, 'success')
end)

-- Notification for payment
RegisterNetEvent('vein-construction:client:payment', function(amount)
    SendNotification('You received a payment of $' .. amount, 'success')
end)

-- Notification for tool repair
RegisterNetEvent('vein-construction:client:toolRepaired', function(toolName, quality)
    SendNotification('Your ' .. toolName .. ' has been repaired. New quality: ' .. quality .. '%', 'success')
end)

-- Notification for fine
RegisterNetEvent('vein-construction:client:fined', function(amount, reason)
    SendNotification('You received a fine of $' .. amount .. ' for ' .. reason, 'error')
    
    -- Play fine sound
    PlaySoundFrontend(-1, "Lose_1st", "GTAO_FM_Events_Soundset", 1)
end)

-- Show assign workers menu
RegisterNetEvent('vein-construction:client:assignWorkersMenu', function(projectId)
    TriggerServerEvent('vein-construction:server:getAvailableWorkers', projectId)
end)

-- Display available workers for assignment
RegisterNetEvent('vein-construction:client:displayAvailableWorkers', function(workers, projectId)
    if #workers == 0 then
        SendNotification('No available workers found', 'error')
        return
    end
    
    local options = {}
    
    for i, worker in ipairs(workers) do
        table.insert(options, {
            title = worker.name,
            description = 'Rank: ' .. worker.rank .. '\nHourly Rate: $' .. worker.hourlyRate,
            icon = 'fas fa-hard-hat',
            onSelect = function()
                TriggerServerEvent('vein-construction:server:assignWorker', worker.id, projectId)
            end
        })
    end
    
    table.insert(options, {
        title = 'Back',
        description = 'Return to project details',
        icon = 'fas fa-arrow-left',
        onSelect = function()
            TriggerServerEvent('vein-construction:server:getProjectDetails', projectId)
        end
    })
    
    ShowMenu('assign_workers_' .. projectId, 'Assign Workers', options, 'project_details_' .. projectId)
end)

-- Worker assigned confirmation
RegisterNetEvent('vein-construction:client:workerAssigned', function(workerName, projectName)
    SendNotification(workerName .. ' has been assigned to ' .. projectName, 'success')
end)

-- Show hire NPC worker menu
RegisterNetEvent('vein-construction:client:showHireMenu', function(availableNPCs)
    if #availableNPCs == 0 then
        SendNotification('No workers available for hire at this time', 'error')
        return
    end
    
    local options = {}
    
    for i, npc in ipairs(availableNPCs) do
        table.insert(options, {
            title = npc.name,
            description = 'Experience: ' .. npc.experience .. ' years\nSkills: ' .. npc.skills .. '\nHourly Rate: $' .. npc.rate,
            icon = 'fas fa-user-hard-hat',
            onSelect = function()
                TriggerServerEvent('vein-construction:server:hireNPCWorker', npc.id)
            end
        })
    end
    
    ShowMenu('hire_npc_workers', 'Available Workers for Hire', options)
end)

-- NPC worker hired confirmation
RegisterNetEvent('vein-construction:client:npcHired', function(npcName)
    SendNotification('You have hired ' .. npcName, 'success')
end)

-- Notification for OSHA inspection
RegisterNetEvent('vein-construction:client:oshaInspection', function(inspectorName)
    SendNotification('OSHA Inspector ' .. inspectorName .. ' is conducting a surprise inspection!', 'warning', 10000)
    
    -- Play alarm sound
    PlaySoundFrontend(-1, "Beep_Red", "DLC_HEIST_HACKING_SNAKE_SOUNDS", 1)
end)

-- Show tool durability notification
RegisterNetEvent('vein-construction:client:toolDurabilityWarning', function(toolName, durability)
    if durability <= 25 then
        SendNotification('Your ' .. toolName .. ' is in poor condition (' .. durability .. '%)', 'error')
    elseif durability <= 50 then
        SendNotification('Your ' .. toolName .. ' is wearing down (' .. durability .. '%)', 'warning')
    end
end)

-- Tool broken notification
RegisterNetEvent('vein-construction:client:toolBroken', function(toolName)
    SendNotification('Your ' .. toolName .. ' has broken! You need to replace it.', 'error')
    
    -- Play break sound
    PlaySoundFrontend(-1, "WOODEN_BREAK", "JEWEL_HEIST_SOUNDS", 1)
end)

-- For site managers to start new construction projects
RegisterNetEvent('vein-construction:client:showProjectMenu', function()
    if not PlayerData.job or PlayerData.job.name ~= Config.JobName then return end
    
    -- Get current rank from server
    TriggerServerEvent('vein-construction:server:checkIfSiteManager')
end)

-- Callback for site manager check
RegisterNetEvent('vein-construction:client:siteManagerResponse', function(isSiteManager)
    if not isSiteManager then
        QBCore.Functions.Notify('Only Site Managers can start new projects', 'error')
        return
    end
    
    OpenProjectMenu()
end)

-- Project management menu for Site Managers
function OpenProjectMenu()
    local options = {
        {
            title = 'Start New Project',
            description = 'Create a new construction project',
            icon = 'fas fa-plus',
            onSelect = function()
                StartNewProject()
            end
        },
        {
            title = 'View Active Projects',
            description = 'Check status of ongoing projects',
            icon = 'fas fa-tasks',
            onSelect = function()
                ViewActiveProjects()
            end
        },
        {
            title = 'Hire Workers',
            description = 'Recruit new construction workers',
            icon = 'fas fa-users',
            onSelect = function()
                HireWorkers()
            end
        }
    }
    
    ShowMenu('project_menu', 'Project Management', options)
end

-- For Site Managers to start new projects
function StartNewProject()
    local options = {
        {
            title = 'Small Building Project',
            description = 'Budget: $15,000\nTime: 3 days',
            icon = 'fas fa-home',
            onSelect = function()
                TriggerServerEvent('vein-construction:server:startProject', 'small', 15000)
            end
        },
        {
            title = 'Medium Building Project',
            description = 'Budget: $40,000\nTime: 7 days',
            icon = 'fas fa-building',
            onSelect = function()
                TriggerServerEvent('vein-construction:server:startProject', 'medium', 40000)
            end
        },
        {
            title = 'Large Building Project',
            description = 'Budget: $100,000\nTime: 14 days',
            icon = 'fas fa-city',
            onSelect = function()
                TriggerServerEvent('vein-construction:server:startProject', 'large', 100000)
            end
        }
    }
    
    ShowMenu('new_project', 'Start New Project', options, 'project_menu')
end

-- For Site Managers to view active projects
function ViewActiveProjects()
    TriggerServerEvent('vein-construction:server:getActiveProjects')
end

-- Display active projects
RegisterNetEvent('vein-construction:client:displayActiveProjects', function(projects)
    if #projects == 0 then
        SendNotification('No active projects found', 'error')
        return
    end
    
    local options = {}
    
    for i, project in ipairs(projects) do
        table.insert(options, {
            title = project.name,
            description = 'Budget: $' .. project.budget .. '\nProgress: ' .. project.progress .. '%',
            icon = 'fas fa-building',
            onSelect = function()
                ViewProjectDetails(project)
            end
        })
    end
    
    ShowMenu('active_projects', 'Active Projects', options, 'project_menu')
end)

-- View details of a specific project
function ViewProjectDetails(project)
    local options = {
        {
            title = 'Project Details',
            description = 'Type: ' .. project.type .. '\nBudget: $' .. project.budget .. '\nProgress: ' .. project.progress .. '%',
            icon = 'fas fa-info-circle',
            onSelect = function() end
        },
        {
            title = 'Check on Project',
            description = 'Visit the project site',
            icon = 'fas fa-map-marker-alt',
            onSelect = function()
                -- Set GPS to project
                SetNewWaypoint(project.location.x, project.location.y)
                SendNotification('GPS set to project location', 'success')
            end
        },
        {
            title = 'Assign Workers',
            description = 'Assign workers to this project',
            icon = 'fas fa-users',
            onSelect = function()
                TriggerEvent('vein-construction:client:assignWorkersMenu', project.id)
            end
        },
        {
            title = 'Back to Projects',
            description = 'Return to project list',
            icon = 'fas fa-arrow-left',
            onSelect = function()
                TriggerServerEvent('vein-construction:server:getActiveProjects')
            end
        }
    }
    
    ShowMenu('project_details_' .. project.id, 'Project: ' .. project.name, options, 'active_projects')
end

-- For Foremen and Site Managers to hire workers
function HireWorkers()
    QBCore.Functions.Notify('This feature is not yet implemented', 'error')
end

-- Update player data when it changes
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
end)

-- Show rank information
function ShowRankInformation()
    local options = {}
    
    for _, rank in ipairs(Config.Ranks) do
        local description = 'XP Needed: ' .. rank.xpNeeded .. '\nPay Range: $' .. rank.payment.min .. ' - $' .. rank.payment.max
        if rank.commission then
            description = description .. '\nCommission: ' .. (rank.commission * 100) .. '%'
        end
        
        table.insert(options, {
            title = rank.label,
            description = description,
            icon = 'fas fa-user-tie'
        })
    end
    
    ShowMenu('rank_information', 'Job Ranks', options, 'construction_job_info')
end

-- View active construction projects
RegisterNetEvent('vein-construction:client:viewActiveProjects')
AddEventHandler('vein-construction:client:viewActiveProjects', function(projects)
    if not projects or #projects == 0 then
        SendNotification('No active projects', 'error')
        return
    end
    
    local options = {}
    
    for i, project in ipairs(projects) do
        table.insert(options, {
            title = project.name,
            description = 'Location: ' .. project.location .. '\nProgress: ' .. project.progress .. '%',
            icon = 'fas fa-building',
            onSelect = function()
                TriggerServerEvent('vein-construction:server:getProjectDetails', project.id)
            end
        })
    end
    
    table.insert(options, {
        title = 'Back',
        description = 'Return to project menu',
        icon = 'fas fa-arrow-left',
        onSelect = function()
            OpenProjectMenu()
        end
    })
    
    ShowMenu('active_projects', 'Active Projects', options, 'project_menu')
end)