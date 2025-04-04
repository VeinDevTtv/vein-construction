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
local hasOxLib = false

-- Check if ox_lib is available
Citizen.CreateThread(function()
    -- Check if ox_lib is available
    if GetResourceState('ox_lib') == 'started' then
        hasOxLib = true
        lib = exports['ox_lib']
    end
    print('ox_lib detection in main module:', hasOxLib)
end)

-- Initialize the script
Citizen.CreateThread(function()
    print('Vein Construction: Initializing...')
    
    -- Initial player data load
    PlayerData = QBCore.Functions.GetPlayerData()
    
    -- Setup NPCs, blips and map markers
    SetupJobBlips()
    SetupConstructionNPCs()
    
    -- Duty status check
    if PlayerData.job and PlayerData.job.name == 'construction' then
        isOnDuty = PlayerData.job.onduty
    end
    
    print('Vein Construction: Initialized successfully')
end)

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
    -- Check if player is already a construction worker
    local isConstructionWorker = PlayerData.job and PlayerData.job.name == Config.JobName
    
    if isConstructionWorker then
        QBCore.Functions.Notify('You are already a construction worker', 'error')
        return
    end
    
    local sections = {
        {
            title = "Employment Options",
            items = {
                {
                    title = 'Apply for Construction Job',
                    description = 'Start working as a construction worker',
                    icon = 'fas fa-hard-hat',
                    onSelect = function()
                        ApplyForJob()
                    end
                }
            }
        },
        {
            title = "Information",
            items = {
                {
                    title = 'Job Information',
                    description = 'Learn about the construction job',
                    icon = 'fas fa-info-circle',
                    onSelect = function()
                        ShowJobInformation()
                    end
                }
            }
        }
    }
    
    CreateSectionedMenu('construction_job_menu', 'Construction Job', sections)
end

-- Show job information menu
function ShowJobInformation()
    local sections = {
        {
            title = "Job Details",
            items = {
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
        },
        {
            title = "Job Benefits",
            items = {
                {
                    title = 'Competitive Pay',
                    description = 'Earn $500-$2500 per hour based on rank',
                    icon = 'fas fa-money-bill-wave',
                    onSelect = false
                },
                {
                    title = 'Career Advancement',
                    description = 'Progress from Apprentice to Site Manager',
                    icon = 'fas fa-chart-line',
                    onSelect = false
                }
            }
        }
    }
    
    CreateSectionedMenu('job_info', 'Job Information', sections, 'construction_job_menu')
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
    -- Show progress bar for filling out application
    ShowProgressBar('Filling out application...', 5000)
    
    -- Set up animation
    RequestAnimDict("missheistdockssetup1clipboard@base")
    while not HasAnimDictLoaded("missheistdockssetup1clipboard@base") do
        Wait(10)
    end
    
    -- Create props
    local playerPed = PlayerPedId()
    local propModel = `prop_notepad_01`
    
    RequestModel(propModel)
    while not HasModelLoaded(propModel) do
        Wait(10)
    end
    
    local prop = CreateObject(propModel, 0.0, 0.0, 0.0, true, true, true)
    local boneIndex = GetPedBoneIndex(playerPed, 18905)
    AttachEntityToEntity(prop, playerPed, boneIndex, 0.1, 0.02, 0.05, 10.0, 0.0, 0.0, true, true, false, true, 1, true)
    
    -- Play animation
    TaskPlayAnim(playerPed, "missheistdockssetup1clipboard@base", "base", 2.0, 2.0, 5000, 49, 0, false, false, false)
    
    -- Wait for animation and progress bar to complete
    Citizen.SetTimeout(5000, function()
        -- Delete prop and stop animation
        DeleteObject(prop)
        StopAnimTask(playerPed, "missheistdockssetup1clipboard@base", "base", 1.0)
        
        -- Trigger server event to set job
        TriggerServerEvent('vein-construction:server:setJob')
    end)
end

-- Function to open the job management menu
function OpenJobManagementMenu()
    -- Determine player options based on job and duty status
    local options = {}
    
    -- Default options available to everyone
    table.insert(options, {
        title = isOnDuty and "Clock Out" or "Clock In",
        description = isOnDuty and "End your shift" or "Start your shift",
        icon = isOnDuty and "fas fa-clock" or "fas fa-hard-hat",
        onSelect = function()
            -- For clocking in, check for safety gear
            if not isOnDuty then
                local hasSafetyGear = CheckSafetyGear()
                if not hasSafetyGear then
                    SendNotification("You need to wear safety equipment to clock in", "error")
                    return
                end
            end
            ToggleDuty()
        end
    })
    
    -- Options for on-duty workers
    if isOnDuty then
        -- Site selection
        table.insert(options, {
            title = "Select Construction Site",
            description = "Choose a site to work at",
            icon = "fas fa-map-marker-alt",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:getConstructionSites')
            end
        })
        
        -- View tasks (depends on current site)
        if currentSite then
            table.insert(options, {
                title = "View Available Tasks",
                description = "See tasks available at " .. currentSite.name,
                icon = "fas fa-tasks",
                onSelect = function()
                    TriggerEvent('vein-construction:client:showTaskMenu', currentSite.id)
                end
            })
        end
        
        -- View current rank and progress
        table.insert(options, {
            title = "View Current Rank",
            description = "Check your rank and progression",
            icon = "fas fa-star",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:getRankInfo')
            end
        })
        
        -- Tool durability check
        table.insert(options, {
            title = "Check Tool Durability",
            description = "Inspect your tools' condition",
            icon = "fas fa-tools",
            onSelect = function()
                TriggerEvent('vein-construction:client:checkToolDurability')
            end
        })
    end
    
    -- Option to quit the job
    table.insert(options, {
        title = "Quit Job",
        description = "Leave the construction job",
        icon = "fas fa-sign-out-alt",
        onSelect = function()
            -- Create confirmation dialog with QBCore if ox_lib is not available
            if hasOxLib and lib then
                local confirm = SafelyUseOxLib('alertDialog', {
                    header = 'Quit Construction Job',
                    content = 'Are you sure you want to quit? You will lose your current rank and experience.',
                    centered = true,
                    cancel = true
                })
                if confirm == 'confirm' then
                    TriggerServerEvent('vein-construction:server:quitJob')
                end
            else
                -- Fallback to QBCore dialog
                QBCore.Functions.TriggerCallback('QBCore:Dialog:CloseDialog', {
                    header = "Quit Construction Job",
                    rows = {
                        {
                            id = 0,
                            txt = "Are you sure you want to quit? You will lose your current rank and experience."
                        }
                    }
                }, function(result)
                    if result then
                        TriggerServerEvent('vein-construction:server:quitJob')
                    end
                end)
            end
        end
    })
    
    -- Try to show the menu with error handling
    local success = pcall(function()
        ShowMenu('job_management', 'Job Management', options)
    end)
    
    -- Function to safely use ox_lib
    function SafelyUseOxLib(action, ...)
        if hasOxLib and lib then
            if action == 'hideContext' then
                return lib.hideContext(...)
            elseif action == 'registerContext' then
                return lib.registerContext(...)
            elseif action == 'showContext' then
                return lib.showContext(...)
            elseif action == 'alertDialog' then
                return lib.alertDialog(...)
            elseif action == 'progressBar' then
                return lib.progressBar(...)
            elseif action == 'notify' then
                return lib.notify(...)
            else
                print('Unknown ox_lib action:', action)
                return nil
            end
        else
            print('ox_lib is not available for action:', action)
            return nil
        end
    end

    -- If ShowMenu fails, release control
    if not success then
        SetNuiFocus(false, false)
        if hasOxLib then
            SafelyUseOxLib('hideContext')
        else
            TriggerEvent('qb-menu:client:closeMenu')
        end
        QBCore.Functions.Notify('There was an error opening the menu. Please try again.', 'error')
    end
end

-- Helper function to get current rank label
function GetJobRankLabel()
    if not PlayerData or not PlayerData.metadata or not PlayerData.metadata.constructionrank then
        return 'Apprentice'
    end
    
    for _, rank in ipairs(Config.Ranks) do
        if rank.name == PlayerData.metadata.constructionrank then
            return rank.label
        end
    end
    
    return 'Apprentice'
end

-- Toggle player duty status
function ToggleDuty()
    local newDutyStatus = not isOnDuty
    
    -- Send to server to update job state
    TriggerServerEvent('QBCore:ToggleDuty')
    
    -- Update local state
    isOnDuty = newDutyStatus
    
    -- Notify player
    if isOnDuty then
        QBCore.Functions.Notify('You clocked in for work', 'success')
    else
        QBCore.Functions.Notify('You clocked out from work', 'primary')
    end
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
    
    if hasOxLib and lib then
        SafelyUseOxLib('notify', {
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
    local sections = {
        {
            title = "Your Tools",
            items = {}
        }
    }
    
    -- Add tools with durability status
    local hasTools = false
    
    for tool, data in pairs(toolDurabilities) do
        hasTools = true
        local toolConfig = Config.ToolDurability[tool]
        if toolConfig then
            local usesLeft = toolConfig.uses - data
            local percentage = math.floor((usesLeft / toolConfig.uses) * 100)
            local condition
            local icon
            
            if percentage > 70 then
                condition = 'Good'
                icon = 'fas fa-check-circle'
            elseif percentage > 30 then
                condition = 'Fair'
                icon = 'fas fa-exclamation-circle'
            else
                condition = 'Poor'
                icon = 'fas fa-times-circle'
            end
            
            table.insert(sections[1].items, {
                title = tool:gsub("^%l", string.upper):gsub("_", " "),
                description = 'Condition: ' .. condition .. ' (' .. percentage .. '%)',
                icon = icon,
                progress = percentage,
                onSelect = false
            })
        end
    end
    
    -- No tools used yet
    if not hasTools then
        table.insert(sections[1].items, {
            title = 'No Tools Used',
            description = 'You haven\'t used any tools yet',
            icon = 'fas fa-info-circle',
            onSelect = false
        })
    else
        -- Add repair option
        table.insert(sections, {
            title = "Maintenance",
            items = {
                {
                    title = 'Repair All Tools',
                    description = 'Pay to repair all your tools',
                    icon = 'fas fa-wrench',
                    onSelect = function()
                        RepairTools()
                    end
                }
            }
        })
    end
    
    CreateSectionedMenu('tool_durability', 'Tool Durability', sections, 'job_management')
    
    -- Update status display with tool info
    if hasTools then
        -- Find the worst condition tool for status display
        local worstCondition = 100
        for tool, data in pairs(toolDurabilities) do
            local toolConfig = Config.ToolDurability[tool]
            if toolConfig then
                local usesLeft = toolConfig.uses - data
                local percentage = math.floor((usesLeft / toolConfig.uses) * 100)
                if percentage < worstCondition then
                    worstCondition = percentage
                end
            end
        end
        
        -- Update job status with tool condition
        UpdateJobStatus({
            toolCondition = worstCondition
        })
    end
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
    
    -- Create sections for the repair menu
    local sections = {
        {
            title = "Repair Details",
            items = {
                {
                    title = 'Total Repair Cost',
                    description = '$' .. totalCost,
                    icon = 'fas fa-dollar-sign',
                    onSelect = false
                }
            }
        },
        {
            title = "Actions",
            items = {
                {
                    title = 'Confirm Repair',
                    description = 'Pay $' .. totalCost .. ' to repair all tools',
                    icon = 'fas fa-check',
                    onSelect = function()
                        -- Start a progress bar for the repair process
                        ShowProgressBar('Repairing tools...', 3000)
                        
                        -- Trigger server event after progress bar is done
                        Citizen.SetTimeout(3000, function()
                            TriggerServerEvent('vein-construction:server:repairTools', totalCost)
                            toolDurabilities = {}
                            
                            -- Update job status after repair
                            UpdateJobStatus({
                                toolCondition = 100
                            })
                        end)
                    end
                },
                {
                    title = 'Cancel',
                    icon = 'fas fa-times',
                    onSelect = function()
                        CheckToolDurability()
                    end
                }
            }
        }
    }
    
    CreateSectionedMenu('repair_tools', 'Repair Tools', sections, 'tool_durability')
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

-- Add event handler for opening job menu
RegisterNetEvent('vein-construction:client:openJobMenu', function()
    OpenJobManagementMenu()
end)

-- Function to check for safety gear
function CheckSafetyGear()
    local playerPed = PlayerPedId()
    local hasHelmet = false
    local hasVest = false
    local hasGloves = false
    local hasBoots = false
    
    -- Check if player has construction helmet
    if HasPedGotAccessory(playerPed, 0) then
        hasHelmet = true
    end
    
    -- Check inventory for safety items
    local items = QBCore.Functions.GetPlayerData().items
    
    for _, item in pairs(items) do
        if item.name == "construction_helmet" then
            hasHelmet = true
        elseif item.name == "safety_vest" then
            hasVest = true
        elseif item.name == "work_gloves" then
            hasGloves = true
        elseif item.name == "safety_boots" then
            hasBoots = true
        end
    end
    
    local gearStatus = {
        helmet = hasHelmet,
        vest = hasVest,
        gloves = hasGloves,
        boots = hasBoots
    }
    
    local hasSafetyGear = hasHelmet and hasVest and hasGloves
    
    if not hasSafetyGear then
        local missingItems = {}
        if not hasHelmet then table.insert(missingItems, "helmet") end
        if not hasVest then table.insert(missingItems, "safety vest") end
        if not hasGloves then table.insert(missingItems, "work gloves") end
        
        SendNotification("Missing safety gear: " .. table.concat(missingItems, ", "), "error")
    end
    
    return hasSafetyGear
end

-- Event when resource starts
RegisterNetEvent('onClientResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then 
        return 
    end
    print('Vein Construction: Resource started')
    Wait(1000) -- Short delay to ensure everything is loaded
    
    -- Initial player data load
    PlayerData = QBCore.Functions.GetPlayerData()
    
    -- Setup NPCs, blips and map markers
    SetupJobBlips()
    SetupConstructionNPCs()
    
    -- Duty status check
    if PlayerData.job and PlayerData.job.name == 'construction' then
        isOnDuty = PlayerData.job.onduty
    end
end)

-- Setup job blips on the map
function SetupJobBlips()
    print('Setting up job blips...')
    
    -- Remove existing blips first
    local existingBlips = GetAllBlips()
    for _, blipId in pairs(existingBlips) do
        if DoesBlipExist(blipId) then
            local blipSprite = GetBlipSprite(blipId)
            -- Only remove our specific blips (construction related)
            if blipSprite == 477 or blipSprite == 566 or blipSprite == 478 then
                RemoveBlip(blipId)
            end
        end
    end
    
    -- Job HQ Blip
    if Config.JobNPC and Config.JobNPC.coords then
        local jobBlip = AddBlipForCoord(Config.JobNPC.coords.x, Config.JobNPC.coords.y, Config.JobNPC.coords.z)
        SetBlipSprite(jobBlip, 477) -- Construction blip sprite
        SetBlipDisplay(jobBlip, 4)
        SetBlipScale(jobBlip, 0.8)
        SetBlipAsShortRange(jobBlip, true)
        SetBlipColour(jobBlip, 47) -- Orange color
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName("Construction HQ")
        EndTextCommandSetBlipName(jobBlip)
    else
        print('Job NPC coordinates not found in config')
    end
    
    -- Shop Blip
    if Config.ShopNPC and Config.ShopNPC.coords then
        local shopBlip = AddBlipForCoord(Config.ShopNPC.coords.x, Config.ShopNPC.coords.y, Config.ShopNPC.coords.z)
        SetBlipSprite(shopBlip, 566) -- Shop blip sprite
        SetBlipDisplay(shopBlip, 4)
        SetBlipScale(shopBlip, 0.7)
        SetBlipAsShortRange(shopBlip, true)
        SetBlipColour(shopBlip, 47) -- Orange color
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName("Construction Shop")
        EndTextCommandSetBlipName(shopBlip)
    else
        print('Shop NPC coordinates not found in config')
    end
    
    -- Setup construction sites blips if on duty
    if isOnDuty and Config.ConstructionSites then
        for _, site in pairs(Config.ConstructionSites) do
            if site.coords then
                local siteBlip = AddBlipForCoord(site.coords.x, site.coords.y, site.coords.z)
                SetBlipSprite(siteBlip, 478) -- Construction site sprite
                SetBlipDisplay(siteBlip, 4)
                SetBlipScale(siteBlip, 0.7)
                SetBlipAsShortRange(siteBlip, true)
                SetBlipColour(siteBlip, 47) -- Orange color
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentSubstringPlayerName(site.name)
                EndTextCommandSetBlipName(siteBlip)
            end
        end
    end
    
    print('Job blips setup complete')
end

-- Helper function to get all blips
function GetAllBlips()
    local blips = {}
    for i = 1, 750 do -- Arbitrary upper limit
        if DoesBlipExist(i) then
            table.insert(blips, i)
        end
    end
    return blips
end

-- Notify player of their current rank
RegisterNetEvent('vein-construction:client:notifyRankUp', function(rankData)
    local currentRank = rankData
    
    local title = 'Construction Job Rank: ' .. currentRank.label
    local description = 'XP: ' .. currentRank.currentXP .. ' / ' .. currentRank.nextXP
    
    if currentRank.hourlyRate then
        description = description .. '\nHourly Rate: $' .. currentRank.hourlyRate
    end
    
    if currentRank.commission then
        description = description .. '\nCommission: ' .. (currentRank.commission * 100) .. '%'
    end
    
    if hasOxLib and lib then
        SafelyUseOxLib('notify', {
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