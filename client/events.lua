-- Initialize QBCore
local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = QBCore.Functions.GetPlayerData()
local lib

-- Check if ox_lib is available and define lib
if GetResourceState('ox_lib') ~= 'missing' then
    lib = exports.ox_lib
end

-- Function to handle notifications based on available libraries
function SendNotification(title, message, type, icon)
    if lib then
        lib.notify({
            title = title,
            description = message,
            type = type or 'info',
            position = 'top',
            duration = 5000,
            icon = icon or 'fas fa-info-circle'
        })
    else
        QBCore.Functions.Notify(message, type or 'primary')
    end
end

-- Function to show a menu based on what's available
function ShowMenu(id, title, options, parent)
    if lib then
        -- Use ox_lib context menu
        lib.registerContext({
            id = id,
            title = title,
            menu = parent,
            options = options
        })
        
        lib.showContext(id)
    else
        -- Use QBCore menu as fallback
        local menuItems = {}
        for i, option in ipairs(options) do
            table.insert(menuItems, {
                header = option.title,
                txt = option.description or '',
                icon = option.icon,
                params = {
                    event = option.event,
                    args = option.args,
                    isAction = option.onSelect ~= nil,
                    action = option.onSelect
                }
            })
        end
        
        QBCore.UI.Menu.Open('default', GetCurrentResourceName(), id, {
            title = title,
            align = 'top-left',
            elements = menuItems
        }, function(data, menu)
            local selected = options[data.current.value]
            if selected.onSelect then
                selected.onSelect()
            end
        end, function(data, menu)
            menu.close()
            if parent then
                ShowMenu(parent, '', {}, nil) -- Reopen parent menu
            end
        end)
    end
end

-- Register events for random occurrences and special cases
-- Notification for rank up
RegisterNetEvent('vein-construction:client:rankUp', function(newRank)
    -- Play success sound
    PlaySoundFrontend(-1, "MEDAL_UP", "HUD_MINI_GAME_SOUNDSET", 1)
    
    -- Display notification
    SendNotification('Promotion!', 'You\'ve been promoted to ' .. newRank.label, 'success', 'fas fa-user-tie')
    
    -- Display celebratory effect
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    
    RequestNamedPtfxAsset("scr_indep_fireworks")
    while not HasNamedPtfxAssetLoaded("scr_indep_fireworks") do
        Wait(10)
    end
    
    UseParticleFxAssetNextCall("scr_indep_fireworks")
    StartParticleFxNonLoopedAtCoord("scr_indep_firework_burst_spawn", 
        coords.x, coords.y, coords.z + 5.0, 
        0.0, 0.0, 0.0, 
        0.5, false, false, false)
end)

-- Commission notification
RegisterNetEvent('vein-construction:client:commission', function(amount)
    SendNotification('Commission', 'You earned $' .. amount .. ' in commission from your team\'s work', 'success', 'fas fa-percentage')
end)

-- Payment notification
RegisterNetEvent('vein-construction:client:payment', function(amount)
    SendNotification('Payment', 'You received $' .. amount .. ' for your work', 'success', 'fas fa-dollar-sign')
end)

-- Tool repair notification
RegisterNetEvent('vein-construction:client:toolsRepaired', function()
    SendNotification('Tools Repaired', 'All your tools have been repaired', 'success', 'fas fa-wrench')
end)

-- Fine notification
RegisterNetEvent('vein-construction:client:fine', function(amount)
    SendNotification('OSHA Fine', 'You\'ve been fined $' .. amount .. ' for safety violations', 'error', 'fas fa-exclamation-triangle')
end)

-- Rank check response from server
RegisterNetEvent('vein-construction:client:rankCheckResult', function(canPerform, taskType, requiredRank)
    if canPerform then
        TriggerEvent('vein-construction:client:startTask', taskType)
    else
        QBCore.Functions.Notify('You need to be ' .. requiredRank .. ' or higher for this task', 'error')
    end
end)

-- Contract job notification (for higher ranks who can manage teams)
RegisterNetEvent('vein-construction:client:contractJob', function(jobDetails)
    SendNotification('New Contract', 'A new construction contract is available: ' .. jobDetails.name, 'info', 'fas fa-file-contract')
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
        QBCore.Functions.Notify('No active projects found', 'error')
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
end

-- View details of a specific project
function ViewProjectDetails(project)
    local options = {
        {
            title = 'Project Details',
            description = 'Type: ' .. project.type .. '\nBudget: $' .. project.budget .. '\nProgress: ' .. project.progress .. '%',
            icon = 'fas fa-info-circle'
        },
        {
            title = 'Check on Project',
            description = 'Visit the project site',
            icon = 'fas fa-map-marker-alt',
            onSelect = function()
                -- Set GPS to project location
                SetNewWaypoint(project.location.x, project.location.y)
                QBCore.Functions.Notify('GPS set to project location', 'success')
            end
        }
    }
    
    ShowMenu('project_details', project.name, options, 'active_projects')
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