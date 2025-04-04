-- Initialize QBCore
local QBCore = exports['qb-core']:GetCoreObject()

-- Check if ox_lib is available and define lib
local lib
if GetResourceState('ox_lib') ~= 'missing' then
    lib = exports.ox_lib
end

-- Import the ShowMenu function from client/ui.lua
local ShowMenu = function(id, title, options, parent)
    -- This function will be replaced by the global function in ui.lua
    -- We keep this for backward compatibility
    TriggerEvent('vein-construction:internal:showMenu', id, title, options, parent)
end

-- Create local Vein utility object
Vein = {
    -- Check if player has required items
    HasRequiredItems = function(items)
        if not items then return true end
        
        for _, item in ipairs(items) do
            if not QBCore.Functions.HasItem(item) then
                return false
            end
        end
        
        return true
    end,
    
    -- Check if player has all safety gear
    HasSafetyGear = function()
        for _, item in ipairs(Config.SafetyGear) do
            if not QBCore.Functions.HasItem(item) then
                return false
            end
        end
        
        return true
    end
}

-- Local variables
local PlayerData = {}
local isOnDuty = false
local currentTask = nil
local currentSite = nil
local activeBlips = {}
local safetyCheckTimer = nil
local toolDurabilities = {}

-- Initialize player data and event handlers
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    ResetJobStatus()
    InitBlips()
    InitJobNPC()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    ResetJobStatus()
    RemoveBlips()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
    
    -- If player is no longer a construction worker, reset everything
    if PlayerData.job.name ~= Config.JobName then
        ResetJobStatus()
    end
end)

-- Initialize resource
AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    
    PlayerData = QBCore.Functions.GetPlayerData()
    ResetJobStatus()
    InitBlips()
    InitJobNPC()
end)

-- Reset job status and tasks
function ResetJobStatus()
    isOnDuty = false
    currentTask = nil
    currentSite = nil
    if safetyCheckTimer then
        safetyCheckTimer = nil
    end
    toolDurabilities = {}
end

-- Initialize map blips
function InitBlips()
    RemoveBlips()
    
    -- Create blip for HQ
    local hqBlip = AddBlipForCoord(Config.HQ.coords.x, Config.HQ.coords.y, Config.HQ.coords.z)
    SetBlipSprite(hqBlip, Config.HQ.blip.sprite)
    SetBlipColour(hqBlip, Config.HQ.blip.color)
    SetBlipScale(hqBlip, Config.HQ.blip.scale)
    SetBlipAsShortRange(hqBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.HQ.blip.label)
    EndTextCommandSetBlipName(hqBlip)
    table.insert(activeBlips, hqBlip)
    
    -- Create blips for construction sites
    for _, site in ipairs(Config.Sites) do
        local siteBlip = AddBlipForCoord(site.coords.x, site.coords.y, site.coords.z)
        SetBlipSprite(siteBlip, site.blip.sprite)
        SetBlipColour(siteBlip, site.blip.color)
        SetBlipScale(siteBlip, site.blip.scale)
        SetBlipAsShortRange(siteBlip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(site.blip.label)
        EndTextCommandSetBlipName(siteBlip)
        table.insert(activeBlips, siteBlip)
    end
end

-- Remove all blips
function RemoveBlips()
    for _, blip in ipairs(activeBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    activeBlips = {}
end

-- Initialize job NPC
function InitJobNPC()
    -- Create NPC and add ox_target interaction
    if Config.UseOxTarget then
        local model = Config.JobNPC.model
        RequestModel(model)
        
        while not HasModelLoaded(model) do
            Wait(1)
        end
        
        local jobNPC = CreatePed(4, model, Config.JobNPC.coords.x, Config.JobNPC.coords.y, Config.JobNPC.coords.z - 1.0, Config.JobNPC.coords.w, false, true)
        SetEntityHeading(jobNPC, Config.JobNPC.coords.w)
        FreezeEntityPosition(jobNPC, true)
        SetEntityInvincible(jobNPC, true)
        SetBlockingOfNonTemporaryEvents(jobNPC, true)
        TaskStartScenarioInPlace(jobNPC, Config.JobNPC.scenario, 0, true)
        
        -- Add ox_target interaction
        exports.ox_target:addLocalEntity(jobNPC, {
            {
                name = 'construction_job_application',
                icon = 'fas fa-hard-hat',
                label = 'Apply for Construction Job',
                distance = 2.0,
                onSelect = function()
                    OpenJobMenu()
                end,
                canInteract = function()
                    return PlayerData.job.name ~= Config.JobName
                end
            },
            {
                name = 'construction_job_management',
                icon = 'fas fa-clipboard-list',
                label = 'Construction Job Management',
                distance = 2.0,
                onSelect = function()
                    OpenJobManagementMenu()
                end,
                canInteract = function()
                    return PlayerData.job.name == Config.JobName
                end
            }
        })
    end
end

-- Open job application menu
function OpenJobMenu()
    local options = {
        {
            title = 'Apply for Construction Job',
            description = 'Start working as a construction worker',
            icon = 'fas fa-hard-hat',
            onSelect = function()
                ApplyForJob()
            end
        },
        {
            title = 'Job Information',
            description = 'Learn about the construction job',
            icon = 'fas fa-info-circle',
            onSelect = function()
                ShowJobInformation()
            end
        }
    }
    
    ShowMenu('construction_job_menu', 'Construction Job', options)
end

-- Show job information menu
function ShowJobInformation()
    local options = {
        {
            title = 'Available Ranks',
            description = 'View job ranks and requirements',
            icon = 'fas fa-user-tie',
            onSelect = function()
                ShowRankInformation()
            end
        },
        {
            title = 'Job Tasks',
            description = 'Learn about available tasks',
            icon = 'fas fa-tasks',
            onSelect = function()
                ShowTaskInformation()
            end
        },
        {
            title = 'Required Equipment',
            description = 'View required tools and safety gear',
            icon = 'fas fa-tools',
            onSelect = function()
                ShowEquipmentInformation()
            end
        }
    }
    
    ShowMenu('job_info', 'Job Information', options, 'construction_job_menu')
end

-- Show task information
function ShowTaskInformation()
    local options = {
        {
            title = 'Lifting Materials',
            description = 'Carry construction materials to designated areas',
            icon = 'fas fa-weight-hanging'
        },
        {
            title = 'Hammering',
            description = 'Use a hammer to secure beams and structures',
            icon = 'fas fa-hammer'
        },
        {
            title = 'Drilling',
            description = 'Drill holes and secure parts with screws',
            icon = 'fas fa-cog'
        },
        {
            title = 'Welding',
            description = 'Weld metal beams and structures together',
            icon = 'fas fa-fire'
        },
        {
            title = 'Roadwork',
            description = 'Fix roads and paint markings',
            icon = 'fas fa-road'
        }
    }
    
    ShowMenu('task_info', 'Available Tasks', options, 'job_info')
end

-- Show equipment information
function ShowEquipmentInformation()
    local options = {
        {
            title = 'Safety Equipment',
            description = 'Required: Hard Hat, Safety Vest, Work Gloves',
            icon = 'fas fa-hard-hat'
        },
        {
            title = 'Basic Tools',
            description = 'Hammer, Work Belt',
            icon = 'fas fa-hammer'
        },
        {
            title = 'Advanced Tools',
            description = 'Power Drill, Welding Torch, Paint Roller',
            icon = 'fas fa-tools'
        }
    }
    
    ShowMenu('equipment_info', 'Required Equipment', options, 'job_info')
end

-- Apply for the job
function ApplyForJob()
    if lib then
        lib.progressBar({
            duration = 5000,
            label = 'Filling out application...',
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true
            },
            anim = {
                dict = 'missheistdockssetup1clipboard@base',
                clip = 'base'
            },
            prop = {
                model = 'prop_notepad_01',
                bone = 18905,
                pos = vec3(0.1, 0.02, 0.05),
                rot = vec3(10.0, 0.0, 0.0)
            }
        })
    else
        -- Fallback to QBCore progress
        QBCore.Functions.Progressbar("fill_application", "Filling out application...", 5000, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = "missheistdockssetup1clipboard@base",
            anim = "base",
            flags = 49,
        }, {
            model = "prop_notepad_01",
            bone = 18905,
            coords = { x = 0.1, y = 0.02, z = 0.05 },
            rotation = { x = 10.0, y = 0.0, z = 0.0 },
        }, {}, function() -- Done
            TriggerServerEvent('vein-construction:server:setJob')
        end, function() -- Cancel
            QBCore.Functions.Notify('Cancelled application', 'error')
        end)
    end
end

-- Open job management menu
function OpenJobManagementMenu()
    local options = {
        {
            title = 'Toggle Duty',
            description = isOnDuty and 'Clock out from work' or 'Clock in for work',
            icon = isOnDuty and 'fas fa-sign-out-alt' or 'fas fa-sign-in-alt',
            onSelect = function()
                ToggleDuty()
            end
        }
    }
    
    -- Only show task options if on duty
    if isOnDuty then
        table.insert(options, {
            title = 'Select Construction Site',
            description = 'Choose a site to work at',
            icon = 'fas fa-map-marked-alt',
            onSelect = function()
                SelectConstructionSite()
            end
        })
        
        table.insert(options, {
            title = 'View Current Rank',
            description = 'Check your job rank and XP',
            icon = 'fas fa-user-tie',
            onSelect = function()
                ViewCurrentRank()
            end
        })
        
        table.insert(options, {
            title = 'Check Tool Durability',
            description = 'Check the condition of your tools',
            icon = 'fas fa-tools',
            onSelect = function()
                CheckToolDurability()
            end
        })
    end
    
    -- Add quit job option
    table.insert(options, {
        title = 'Quit Job',
        description = 'Resign from construction work',
        icon = 'fas fa-user-times',
        onSelect = function()
            QuitJob()
        end
    })
    
    ShowMenu('job_management', 'Job Management', options)
end

-- Toggle duty status
function ToggleDuty()
    isOnDuty = not isOnDuty
    
    if isOnDuty then
        -- Check for safety gear when going on duty
        if not Vein.HasSafetyGear() then
            QBCore.Functions.Notify('You need safety gear to work! (Helmet, Vest, Gloves)', 'error')
            isOnDuty = false
            return
        end
        
        -- Start safety check timer
        StartSafetyCheckTimer()
        QBCore.Functions.Notify('You are now on duty', 'success')
    else
        -- If going off duty, cancel current task
        if currentTask then
            CancelCurrentTask()
        end
        QBCore.Functions.Notify('You are now off duty', 'primary')
    end
    
    -- Tell server about duty change
    TriggerServerEvent('vein-construction:server:toggleDuty', isOnDuty)
end

-- Start periodic safety checks
function StartSafetyCheckTimer()
    if safetyCheckTimer then return end
    
    -- Schedule safety inspections periodically
    safetyCheckTimer = true
    Citizen.CreateThread(function()
        while safetyCheckTimer and isOnDuty do
            -- Random safety inspection chance every hour
            local randomChance = math.random(1, 100)
            if randomChance <= Config.RandomEvents.safetyInspection.chance then
                TriggerSafetyInspection()
            end
            Citizen.Wait(60 * 60 * 1000) -- Check every hour
        end
    end)
end

-- Trigger a safety inspection
function TriggerSafetyInspection()
    QBCore.Functions.Notify('OSHA inspector approaching!', 'primary')
    Citizen.Wait(10000) -- Give player time to put on safety gear
    
    if not Vein.HasSafetyGear(nil) then
        -- Player failed inspection, apply fine
        QBCore.Functions.Notify('You failed the safety inspection and received a fine!', 'error')
        TriggerServerEvent('vein-construction:server:payFine', Config.RandomEvents.safetyInspection.fine)
    else
        QBCore.Functions.Notify('You passed the safety inspection!', 'success')
        -- Give small XP bonus for passing
        TriggerServerEvent('vein-construction:server:addXP', 5)
    end
end

-- Select a construction site to work at
function SelectConstructionSite()
    local options = {}
    
    for i, site in ipairs(Config.Sites) do
        table.insert(options, {
            title = site.label,
            description = 'Select this construction site',
            icon = 'fas fa-hard-hat',
            onSelect = function()
                currentSite = i
                QBCore.Functions.Notify('You are now working at ' .. site.label, 'success')
                SelectTask()
            end
        })
    end
    
    ShowMenu('select_site', 'Select Construction Site', options, 'job_management')
end

-- View current rank and XP
function ViewCurrentRank()
    TriggerServerEvent('vein-construction:server:requestRankInfo')
end

-- Show Rank Information (called from server)
RegisterNetEvent('vein-construction:client:showRankInfo', function(rankName, xp, nextRankXP)
    local currentRank
    local nextRank
    
    for i, rank in ipairs(Config.Ranks) do
        if rank.name == rankName then
            currentRank = rank
            if i < #Config.Ranks then
                nextRank = Config.Ranks[i + 1]
            end
            break
        end
    end
    
    if not currentRank then return end
    
    local title = 'Current Rank: ' .. currentRank.label
    local description = 'XP: ' .. xp
    
    if nextRank then
        description = description .. '\nNext Rank: ' .. nextRank.label .. ' (Need ' .. nextRankXP .. ' more XP)'
    else
        description = description .. '\nYou have reached the highest rank!'
    end
    
    if currentRank.commission then
        description = description .. '\nCommission: ' .. (currentRank.commission * 100) .. '%'
    end
    
    if lib then
        lib.notify({
            title = title,
            description = description,
            type = 'info',
            position = 'top',
            duration = 5000
        })
    else
        QBCore.Functions.Notify(title .. '\n' .. description, 'primary', 5000)
    end
end)

-- Check tool durability
function CheckToolDurability()
    local toolList = {}
    
    for tool, durability in pairs(toolDurabilities) do
        local toolConfig = Config.ToolDurability[tool]
        if toolConfig then
            local usesLeft = toolConfig.uses - durability
            local percentage = math.floor((usesLeft / toolConfig.uses) * 100)
            local condition
            
            if percentage > 70 then
                condition = 'Good'
            elseif percentage > 30 then
                condition = 'Fair'
            else
                condition = 'Poor'
            end
            
            table.insert(toolList, {
                title = tool:gsub("^%l", string.upper):gsub("_", " "),
                description = 'Condition: ' .. condition .. ' (' .. percentage .. '%)',
                icon = 'fas fa-tools'
            })
        end
    end
    
    if #toolList == 0 then
        table.insert(toolList, {
            title = 'No Tools Used',
            description = 'You haven\'t used any tools yet',
            icon = 'fas fa-tools'
        })
    end
    
    -- Add repair option
    table.insert(toolList, {
        title = 'Repair Tools',
        description = 'Pay to repair all your tools',
        icon = 'fas fa-wrench',
        onSelect = function()
            RepairTools()
        end
    })
    
    ShowMenu('tool_durability', 'Tool Durability', toolList, 'job_management')
end

-- Repair all tools
function RepairTools()
    if next(toolDurabilities) == nil then
        QBCore.Functions.Notify('You have no tools that need repair', 'error')
        return
    end
    
    local totalCost = 0
    for tool, _ in pairs(toolDurabilities) do
        local toolConfig = Config.ToolDurability[tool]
        if toolConfig then
            totalCost = totalCost + toolConfig.repairCost
        end
    end
    
    local options = {
        {
            title = 'Confirm Repair',
            description = 'Cost: $' .. totalCost,
            icon = 'fas fa-check',
            onSelect = function()
                TriggerServerEvent('vein-construction:server:repairTools', totalCost)
                toolDurabilities = {}
            end
        },
        {
            title = 'Cancel',
            icon = 'fas fa-times',
            onSelect = function()
                ShowMenu('tool_durability', 'Tool Durability', {}, 'job_management')
            end
        }
    }
    
    ShowMenu('repair_tools', 'Repair Tools', options, 'tool_durability')
end

-- Quit job
function QuitJob()
    local options = {
        {
            title = 'Confirm Resignation',
            description = 'Are you sure you want to quit?',
            icon = 'fas fa-check',
            onSelect = function()
                TriggerServerEvent('vein-construction:server:quitJob')
                ResetJobStatus()
            end
        },
        {
            title = 'Cancel',
            icon = 'fas fa-times',
            onSelect = function()
                ShowMenu('job_management', 'Job Management', {}, nil)
            end
        }
    }
    
    ShowMenu('quit_job', 'Quit Job', options, 'job_management')
end

-- Select a task at the current site
function SelectTask()
    if not currentSite or not Config.Sites[currentSite] then
        QBCore.Functions.Notify('You need to select a construction site first', 'error')
        return
    end
    
    local site = Config.Sites[currentSite]
    local options = {}
    
    -- Task 1: Lifting Materials
    if site.tasks.lifting and #site.tasks.lifting > 0 then
        table.insert(options, {
            title = 'Lifting Materials',
            description = 'Carry materials to designated areas',
            icon = 'fas fa-weight-hanging',
            onSelect = function()
                TriggerServerEvent('vein-construction:server:requestRankCheck', 'lifting')
            end
        })
    end
    
    -- Task 2: Hammering
    if site.tasks.hammering and #site.tasks.hammering > 0 then
        table.insert(options, {
            title = 'Hammering',
            description = 'Hammer nails into structures',
            icon = 'fas fa-hammer',
            onSelect = function()
                TriggerServerEvent('vein-construction:server:requestRankCheck', 'hammering')
            end
        })
    end
    
    -- Task 3: Drilling
    if site.tasks.drilling and #site.tasks.drilling > 0 then
        table.insert(options, {
            title = 'Drilling',
            description = 'Drill holes and secure parts',
            icon = 'fas fa-cog',
            onSelect = function()
                TriggerServerEvent('vein-construction:server:requestRankCheck', 'drilling')
            end
        })
    end
    
    -- Task 4: Welding (requires Skilled Worker rank or higher)
    if site.tasks.welding and #site.tasks.welding > 0 then
        table.insert(options, {
            title = 'Welding',
            description = 'Weld metal beams together',
            icon = 'fas fa-fire',
            onSelect = function()
                TriggerServerEvent('vein-construction:server:requestRankCheck', 'welding')
            end
        })
    end
    
    -- Task 5: Roadwork (requires Skilled Worker rank or higher)
    if site.tasks.roadwork and #site.tasks.roadwork > 0 then
        table.insert(options, {
            title = 'Roadwork',
            description = 'Fix potholes and mark road lanes',
            icon = 'fas fa-road',
            onSelect = function()
                TriggerServerEvent('vein-construction:server:requestRankCheck', 'roadwork')
            end
        })
    end
    
    ShowMenu('select_task', 'Select Task', options)
end

-- Start task (after rank check from server)
RegisterNetEvent('vein-construction:client:startTask', function(taskType)
    if not currentSite or not Config.Sites[currentSite] then
        QBCore.Functions.Notify('You need to select a construction site first', 'error')
        return
    end
    
    -- Check if player has required items
    local requiredItems = Config.RequiredItems[taskType]
    if not Vein.HasRequiredItems(nil, requiredItems) then
        local requiredItemsText = table.concat(requiredItems, ', ')
        requiredItemsText = requiredItemsText:gsub('_', ' ')
        QBCore.Functions.Notify('You need: ' .. requiredItemsText, 'error')
        return
    end
    
    -- Set current task
    currentTask = {
        type = taskType,
        site = currentSite,
        completed = false
    }
    
    -- Start the task based on its type
    if taskType == 'lifting' then
        StartLiftingTask()
    elseif taskType == 'hammering' then
        StartHammeringTask()
    elseif taskType == 'drilling' then
        StartDrillingTask()
    elseif taskType == 'welding' then
        StartWeldingTask()
    elseif taskType == 'roadwork' then
        StartRoadworkTask()
    end
end)

-- Cancel current task
function CancelCurrentTask()
    if currentTask then
        -- Remove any task-specific elements
        if currentTask.blip and DoesBlipExist(currentTask.blip) then
            RemoveBlip(currentTask.blip)
        end
        
        if currentTask.pickup and DoesEntityExist(currentTask.pickup) then
            DeleteEntity(currentTask.pickup)
        end
        
        QBCore.Functions.Notify('Task cancelled', 'error')
        currentTask = nil
    end
end

-- These will be implemented in tasks.lua
function StartLiftingTask() end
function StartHammeringTask() end
function StartDrillingTask() end
function StartWeldingTask() end
function StartRoadworkTask() end

-- Exports for other resources to use
exports('IsPlayerOnDuty', function()
    return isOnDuty
end)

exports('GetCurrentSite', function()
    if currentSite and Config.Sites[currentSite] then
        return Config.Sites[currentSite]
    end
    return nil
end)

exports('GetCurrentTask', function()
    return currentTask
end) 