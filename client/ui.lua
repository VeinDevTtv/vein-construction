-- Initialize QBCore
local QBCore = exports['qb-core']:GetCoreObject()

-- Menu state management
local menuOpen = false
local menuData = {}
local menuCallbacks = {}

-- Job status tracking
local jobStatus = {
    onDuty = false,
    rank = "Apprentice",
    xp = 0,
    nextRankXP = 100,
    site = "None",
    task = "None",
    taskProgress = 0,
    tools = {},
    safetyGear = {
        hasHelmet = false,
        hasVest = false,
        hasGloves = false
    }
}

-- Function to send data to the NUI
function SendUIMessage(data)
    SendNUIMessage(data)
end

-- Function to show a menu
function ShowUIMenu(id, title, options, parent, footerInfo)
    -- Store callbacks separately because they can't be passed to NUI
    local processOptions = function(opts)
        if opts then
            for i, option in ipairs(opts) do
                if option.onSelect then
                    menuCallbacks[id .. '_' .. i] = option.onSelect
                    option.onSelect = true -- Just set to true so UI knows it's clickable
                end
            end
        end
        return opts
    end
    
    -- Process sections if they exist
    if options and options.sections then
        for i, section in ipairs(options.sections) do
            if section.items then
                section.items = processOptions(section.items)
            end
        end
    else
        options = processOptions(options)
    end
    
    -- Store menu data for callbacks
    menuData = {
        id = id,
        options = options,
        parent = parent
    }

    -- Send message to UI
    SendUIMessage({
        action = 'showMenu',
        id = id,
        title = title,
        options = options,
        parent = parent,
        footerInfo = footerInfo
    })

    -- Set menu state
    menuOpen = true
    
    -- Display cursor
    SetNuiFocus(true, true)
end

-- Function to close the menu
function CloseUIMenu()
    if not menuOpen then return end
    
    -- Send message to UI
    SendUIMessage({
        action = 'closeMenu'
    })

    -- Reset menu state
    menuOpen = false
    menuData = {}
    menuCallbacks = {}
    
    -- Hide cursor
    SetNuiFocus(false, false)
end

-- Function to show a notification
function ShowUINotification(title, message, type, icon)
    SendUIMessage({
        action = 'showNotification',
        title = title,
        message = message,
        type = type or 'info',
        icon = icon
    })
end

-- Function to update job status display
function UpdateJobStatus(status)
    -- Update local tracking
    if status then
        for k, v in pairs(status) do
            jobStatus[k] = v
        end
    end
    
    -- Send to UI
    SendUIMessage({
        action = 'updateJobStatus',
        status = status or jobStatus
    })
end

-- Function to toggle the status display
function ToggleStatusDisplay(show)
    SendUIMessage({
        action = 'toggleStatusDisplay',
        show = show
    })
end

-- Function to show the progress bar
function ShowProgressBar(label, duration)
    SendUIMessage({
        action = 'showProgress',
        label = label,
        duration = duration
    })
end

-- Function to update progress bar value
function UpdateProgressBar(progress)
    SendUIMessage({
        action = 'updateProgress',
        progress = progress
    })
end

-- Function to hide the progress bar
function HideProgressBar()
    SendUIMessage({
        action = 'hideProgress'
    })
end

-- Function to check if player has all safety gear
function HasAllSafetyGear()
    local hasHelmet = QBCore.Functions.HasItem('construction_helmet')
    local hasVest = QBCore.Functions.HasItem('safety_vest')
    local hasGloves = QBCore.Functions.HasItem('work_gloves')
    
    -- Update job status
    jobStatus.safetyGear = {
        hasHelmet = hasHelmet,
        hasVest = hasVest,
        hasGloves = hasGloves
    }
    
    return hasHelmet and hasVest and hasGloves
end

-- Function to update tool durability in UI
function UpdateToolDurability(toolName, durability, maxDurability)
    if not jobStatus.tools[toolName] then
        jobStatus.tools[toolName] = {}
    end
    
    jobStatus.tools[toolName].durability = durability
    jobStatus.tools[toolName].maxDurability = maxDurability
    
    -- Update job status display
    UpdateJobStatus()
end

-- NUI Callbacks
RegisterNUICallback('closeMenu', function(data, cb)
    CloseUIMenu()
    cb('ok')
end)

RegisterNUICallback('menuSelect', function(data, cb)
    local menuId = data.menuId
    local optionIndex = data.optionIndex
    
    -- Call the stored callback
    local callbackId = menuId .. '_' .. optionIndex
    if menuCallbacks[callbackId] then
        menuCallbacks[callbackId]()
    end
    
    cb('ok')
end)

RegisterNUICallback('goBack', function(data, cb)
    -- If there's a parent menu specified, reopen it
    if data.menuId then
        TriggerEvent('vein-construction:client:reopenMenu', data.menuId)
    end
    
    cb('ok')
end)

RegisterNUICallback('buyItem', function(data, cb)
    -- Trigger server event to buy the item
    TriggerServerEvent('vein-construction:server:buyItem', data.item, data.type)
    cb('ok')
end)

RegisterNUICallback('startTask', function(data, cb)
    -- Trigger task start event
    TriggerEvent('vein-construction:client:startTask', data.taskId)
    cb('ok')
end)

-- Event to reopen a parent menu
RegisterNetEvent('vein-construction:client:reopenMenu', function(menuId)
    -- Look for this menu in the menu history and reopen it
    if menuId == 'construction_job_menu' then
        OpenJobMenu()
    elseif menuId == 'job_management' then
        OpenJobManagementMenu()
    elseif menuId == 'job_info' then
        ShowJobInformation()
    elseif menuId == 'task_info' then
        ShowTaskInformation()
    elseif menuId == 'equipment_info' then
        ShowEquipmentInformation()
    elseif menuId == 'project_menu' then
        OpenProjectMenu()
    elseif menuId == 'active_projects' then
        ViewActiveProjects()
    elseif menuId == 'safety_equipment' then
        OpenSafetyEquipmentMenu()
    elseif menuId == 'tools_menu' then
        OpenToolsMenu()
    elseif menuId == 'materials_menu' then
        OpenMaterialsMenu()
    end
end)

-- Override existing function calls to use our UI system
function ShowMenu(id, title, options, parent)
    ShowUIMenu(id, title, options, parent)
end

-- Override notification functions
function SendNotification(title, message, type, icon)
    ShowUINotification(title, message, type, icon)
end

-- Helper function to create sectioned menus
function CreateSectionedMenu(id, title, sectionsData, parent, footerInfo)
    local options = {
        sections = {}
    }
    
    for _, sectionData in ipairs(sectionsData) do
        table.insert(options.sections, {
            title = sectionData.title,
            items = sectionData.items
        })
    end
    
    ShowUIMenu(id, title, options, parent, footerInfo)
end

-- Function to create job level display
function ShowJobLevelInfo(rankData)
    -- Fetch rank data from server if not provided
    if not rankData then
        TriggerServerEvent('vein-construction:server:requestRankInfo')
        return
    end
    
    -- Update job status with rank info
    jobStatus.rank = rankData.rank
    jobStatus.xp = rankData.xp
    jobStatus.nextRankXP = rankData.nextRankXP
    
    -- Show a menu with the job level card
    local options = {
        {
            title = 'Current Rank: ' .. rankData.rank,
            description = 'XP: ' .. rankData.xp .. ' / ' .. rankData.nextRankXP,
            icon = 'fas fa-user-tie',
            progress = math.min(100, (rankData.xp / rankData.nextRankXP) * 100),
            onSelect = false
        },
        {
            title = 'View Available Tasks',
            description = 'See what tasks you can perform at your rank',
            icon = 'fas fa-tasks',
            onSelect = function()
                ShowTasksForRank(rankData.rank)
            end
        },
        {
            title = 'View Rank Benefits',
            description = 'See the benefits of your current rank',
            icon = 'fas fa-money-bill-wave',
            onSelect = function()
                ShowRankBenefits(rankData.rank)
            end
        }
    }
    
    ShowUIMenu('job_level', 'Job Level Information', options, 'job_management')
    
    -- Update job status display
    UpdateJobStatus()
end

-- Functions to create task lists
function ShowTasksForRank(rank)
    local tasks = {}
    local rankIndex = 1
    
    -- Find the rank index
    for i, r in ipairs(Config.Ranks) do
        if r.name == rank then
            rankIndex = i
            break
        end
    end
    
    -- Get tasks available for this rank
    for _, taskType in ipairs(Config.TaskTypes) do
        local taskRankRequired = Config.TaskRanks[taskType] or 1
        
        if rankIndex >= taskRankRequired then
            local taskData = {
                title = taskType:gsub("^%l", string.upper),
                description = Config.TaskDescriptions[taskType] or "No description available",
                icon = Config.TaskIcons[taskType] or "fas fa-tasks",
                onSelect = function()
                    TriggerEvent('vein-construction:client:previewTask', taskType)
                end
            }
            
            if rankIndex == taskRankRequired then
                taskData.badge = {
                    type = "new",
                    text = "NEW"
                }
            end
            
            table.insert(tasks, taskData)
        end
    end
    
    ShowUIMenu('rank_tasks', 'Tasks Available at Your Rank', tasks, 'job_level')
end

-- Event handler for previewing tasks
RegisterNetEvent('vein-construction:client:previewTask', function(taskType)
    local taskDescription = Config.TaskDescriptions[taskType] or "No description available"
    local taskRequirements = Config.RequiredItems[taskType] or {}
    local formattedRequirements = {}
    
    for _, item in ipairs(taskRequirements) do
        local hasItem = QBCore.Functions.HasItem(item)
        table.insert(formattedRequirements, {
            name = item:gsub("^%l", string.upper):gsub("_", " "),
            hasItem = hasItem
        })
    end
    
    local options = {
        {
            title = taskType:gsub("^%l", string.upper),
            description = taskDescription,
            icon = Config.TaskIcons[taskType] or "fas fa-tasks",
            onSelect = false
        }
    }
    
    if #formattedRequirements > 0 then
        local requirementsSection = {
            title = "Requirements",
            items = {}
        }
        
        for _, req in ipairs(formattedRequirements) do
            table.insert(requirementsSection.items, {
                title = req.name,
                description = req.hasItem and "You have this item" or "You need this item",
                icon = req.hasItem and "fas fa-check" or "fas fa-times",
                disabled = not req.hasItem,
                onSelect = false
            })
        end
        
        CreateSectionedMenu('task_preview', 'Task Preview', {requirementsSection}, 'rank_tasks')
    else
        ShowUIMenu('task_preview', 'Task Preview', options, 'rank_tasks')
    end
end)

-- Function to show rank benefits
function ShowRankBenefits(rank)
    local rankData = nil
    
    -- Find the rank data
    for _, r in ipairs(Config.Ranks) do
        if r.name == rank then
            rankData = r
            break
        end
    end
    
    if not rankData then
        ShowUINotification('Error', 'Could not find rank data', 'error')
        return
    end
    
    local options = {
        {
            title = 'Pay Range',
            description = '$' .. rankData.payment.min .. ' - $' .. rankData.payment.max,
            icon = 'fas fa-money-bill-wave',
            onSelect = false
        }
    }
    
    if rankData.commission then
        table.insert(options, {
            title = 'Commission Rate',
            description = math.floor(rankData.commission * 100) .. '% of team earnings',
            icon = 'fas fa-percentage',
            onSelect = false
        })
    end
    
    table.insert(options, {
        title = 'Next Rank',
        description = 'XP Needed: ' .. rankData.xpNeeded,
        icon = 'fas fa-arrow-up',
        onSelect = false
    })
    
    ShowUIMenu('rank_benefits', 'Rank Benefits: ' .. rankData.label, options, 'job_level')
end

-- Enhanced version of the safety check function
function CheckSafetyGear()
    local hasHelmet = QBCore.Functions.HasItem('construction_helmet')
    local hasVest = QBCore.Functions.HasItem('safety_vest')
    local hasGloves = QBCore.Functions.HasItem('work_gloves')
    
    -- Update job status
    jobStatus.safetyGear = {
        hasHelmet = hasHelmet,
        hasVest = hasVest,
        hasGloves = hasGloves
    }
    
    -- Create sectioned menu for safety gear
    local sections = {
        {
            title = "Required Safety Gear",
            items = {
                {
                    title = "Construction Helmet",
                    description = hasHelmet and "Equipped" or "Not Equipped - Required for work",
                    icon = "fas fa-hard-hat",
                    onSelect = false,
                    disabled = hasHelmet
                },
                {
                    title = "Safety Vest",
                    description = hasVest and "Equipped" or "Not Equipped - Required for work",
                    icon = "fas fa-vest",
                    onSelect = false,
                    disabled = hasVest
                },
                {
                    title = "Work Gloves",
                    description = hasGloves and "Equipped" or "Not Equipped - Required for work",
                    icon = "fas fa-mitten",
                    onSelect = false,
                    disabled = hasGloves
                }
            }
        }
    }
    
    if hasHelmet and hasVest and hasGloves then
        table.insert(sections, {
            title = "Status",
            items = {
                {
                    title = "All Safety Gear Equipped",
                    description = "You are ready to work safely",
                    icon = "fas fa-check-circle",
                    onSelect = false
                }
            }
        })
    else
        table.insert(sections, {
            title = "Actions",
            items = {
                {
                    title = "Buy Missing Safety Gear",
                    description = "Visit the construction shop to purchase required gear",
                    icon = "fas fa-shopping-cart",
                    onSelect = function()
                        TriggerEvent('vein-construction:client:openConstructionShop')
                    end
                }
            }
        })
    end
    
    CreateSectionedMenu('safety_check', 'Safety Gear Check', sections, 'job_management')
    
    return hasHelmet and hasVest and hasGloves
end

-- Export the functions
exports('ShowMenu', ShowMenu)
exports('SendNotification', SendNotification)
exports('CloseMenu', CloseUIMenu)
exports('ShowProgressBar', ShowProgressBar)
exports('UpdateProgressBar', UpdateProgressBar)
exports('HideProgressBar', HideProgressBar)
exports('ToggleStatusDisplay', ToggleStatusDisplay)
exports('UpdateJobStatus', UpdateJobStatus)
exports('CreateSectionedMenu', CreateSectionedMenu)
exports('CheckSafetyGear', CheckSafetyGear)

-- Add debug command to test the UI
RegisterCommand('testconstructionui', function()
    -- First test basic menus and notifications
    ShowUIMenu('test_menu', 'Construction UI Test', {
        {
            title = 'Test Option 1',
            description = 'This is a test option',
            icon = 'fas fa-wrench',
            onSelect = function()
                ShowUINotification('Test', 'You selected option 1', 'success')
            end
        },
        {
            title = 'Test Option 2',
            description = 'This is another test option',
            icon = 'fas fa-hammer',
            onSelect = function()
                ShowUINotification('Test', 'You selected option 2', 'info')
            end
        },
        {
            title = 'Test Submenu',
            description = 'Open a submenu',
            icon = 'fas fa-list',
            onSelect = function()
                ShowUIMenu('submenu', 'Submenu', {
                    {
                        title = 'Submenu Option',
                        description = 'This is a submenu option',
                        icon = 'fas fa-tools',
                        onSelect = function()
                            ShowUINotification('Submenu', 'You selected a submenu option', 'warning')
                        end
                    },
                    {
                        title = 'Error Notification',
                        description = 'Show an error notification',
                        icon = 'fas fa-exclamation-circle',
                        onSelect = function()
                            ShowUINotification('Error', 'This is an error notification', 'error')
                        end
                    }
                }, 'test_menu')
            end
        },
        {
            title = 'Test Progress Bar',
            description = 'Show a progress bar',
            icon = 'fas fa-spinner',
            onSelect = function()
                ShowProgressBar('Testing Progress...', 5000)
            end
        },
        {
            title = 'Test Status Display',
            description = 'Toggle the status display',
            icon = 'fas fa-info-circle',
            onSelect = function()
                ToggleStatusDisplay(true)
                UpdateJobStatus({
                    onDuty = true,
                    rank = "Foreman",
                    xp = 250,
                    nextRankXP = 500,
                    site = "Downtown Construction",
                    task = "Hammering",
                    taskProgress = 45
                })
                ShowUINotification('Status', 'Status display toggled on', 'info')
            end
        },
        {
            title = 'Test Sectioned Menu',
            description = 'Show a menu with sections',
            icon = 'fas fa-th-large',
            onSelect = function()
                CreateSectionedMenu('test_sectioned', 'Sectioned Menu', {
                    {
                        title: "Section 1",
                        items: [
                            {
                                title: "Item 1",
                                description: "This is item 1",
                                icon: "fas fa-star",
                                onSelect: function() {
                                    ShowUINotification("Section 1", "You selected Item 1", "success");
                                }
                            },
                            {
                                title: "Item 2",
                                description: "This is item 2",
                                icon: "fas fa-star",
                                onSelect: function() {
                                    ShowUINotification("Section 1", "You selected Item 2", "success");
                                }
                            }
                        ]
                    },
                    {
                        title: "Section 2",
                        items: [
                            {
                                title: "Item 3",
                                description: "This is item 3",
                                icon: "fas fa-circle",
                                onSelect: function() {
                                    ShowUINotification("Section 2", "You selected Item 3", "info");
                                }
                            }
                        ]
                    }
                }, 'test_menu')
            end
        }
    })
end, false)

print('Vein Construction UI loaded successfully. Use /testconstructionui to test it.') 