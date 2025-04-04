-- Register events for random occurrences and special cases
-- Notification for rank up
RegisterNetEvent('vein-construction:client:rankUp', function(newRank)
    -- Play success sound
    PlaySoundFrontend(-1, "MEDAL_UP", "HUD_MINI_GAME_SOUNDSET", 1)
    
    -- Display notification
    lib.notify({
        title = 'Promotion!',
        description = 'You\'ve been promoted to ' .. newRank.label,
        type = 'success',
        position = 'top',
        duration = 5000,
        icon = 'fas fa-user-tie'
    })
    
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
    lib.notify({
        title = 'Commission',
        description = 'You earned $' .. amount .. ' in commission from your team\'s work',
        type = 'success',
        position = 'top',
        duration = 5000,
        icon = 'fas fa-percentage'
    })
end)

-- Payment notification
RegisterNetEvent('vein-construction:client:payment', function(amount)
    lib.notify({
        title = 'Payment',
        description = 'You received $' .. amount .. ' for your work',
        type = 'success',
        position = 'top',
        duration = 5000,
        icon = 'fas fa-dollar-sign'
    })
end)

-- Tool repair notification
RegisterNetEvent('vein-construction:client:toolsRepaired', function()
    lib.notify({
        title = 'Tools Repaired',
        description = 'All your tools have been repaired',
        type = 'success',
        position = 'top',
        duration = 5000,
        icon = 'fas fa-wrench'
    })
end)

-- Fine notification
RegisterNetEvent('vein-construction:client:fine', function(amount)
    lib.notify({
        title = 'OSHA Fine',
        description = 'You\'ve been fined $' .. amount .. ' for safety violations',
        type = 'error',
        position = 'top',
        duration = 5000,
        icon = 'fas fa-exclamation-triangle'
    })
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
    lib.notify({
        title = 'New Contract',
        description = 'A new construction contract is available: ' .. jobDetails.name,
        type = 'info',
        position = 'top',
        duration = 5000,
        icon = 'fas fa-file-contract'
    })
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
    lib.registerContext({
        id = 'project_menu',
        title = 'Project Management',
        options = {
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
    })
    
    lib.showContext('project_menu')
end

-- For Site Managers to start new projects
function StartNewProject()
    lib.registerContext({
        id = 'new_project',
        title = 'Start New Project',
        menu = 'project_menu',
        options = {
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
    })
    
    lib.showContext('new_project')
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
    
    lib.registerContext({
        id = 'active_projects',
        title = 'Active Projects',
        menu = 'project_menu',
        options = options
    })
    
    lib.showContext('active_projects')
end

-- View details of a specific project
function ViewProjectDetails(project)
    lib.registerContext({
        id = 'project_details',
        title = project.name,
        menu = 'active_projects',
        options = {
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
    })
    
    lib.showContext('project_details')
end

-- For Foremen and Site Managers to hire workers
function HireWorkers()
    QBCore.Functions.Notify('This feature is not yet implemented', 'error')
end 