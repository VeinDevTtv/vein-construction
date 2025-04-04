-- UI Management for Construction Job
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

-- Declare local variables but disable ox_lib usage
local hasOxLib = false -- Set to false to disable ox_lib
local lib = nil
local libInitialized = false

-- Define a simple active tasks tracking system
local ActiveTasks = {}

-- Register active task
function RegisterActiveTask(id, options)
    ActiveTasks[id] = options
end

-- Function to handle menu selection events
RegisterNetEvent('vein-construction:client:menuSelect')
AddEventHandler('vein-construction:client:menuSelect', function(data)
    if not data or not data.id or not data.option then return end
    
    local menuId = data.id
    local optionTitle = data.option
    
    -- Find the matching option and execute its onSelect function
    if ActiveTasks[menuId] then
        for _, option in ipairs(ActiveTasks[menuId]) do
            if option.title == optionTitle and option.onSelect then
                option.onSelect()
                break
            end
        end
    end
end)

-- Function to show a menu with options
function ShowMenu(id, title, options, parent)
    -- Initialize options as empty table if nil
    options = options or {}
    
    print('ShowMenu called:', id, title, 'options count:', #options)
    
    -- Make sure we release any existing UI control first
    SetNuiFocus(false, false)
    
    -- Create QBCore menu
    local qbMenu = {}
    
    -- Add header
    table.insert(qbMenu, {
        header = title,
        isMenuHeader = true
    })
    
    -- Add back button if parent is provided
    if parent then
        table.insert(qbMenu, {
            header = "← Go Back",
            txt = "Return to previous menu",
            params = {
                event = "vein-construction:client:menuSelect",
                args = {
                    id = parent,
                    option = "back",
                    action = "back"
                }
            }
        })
    end
    
    -- Add menu options
    for _, option in ipairs(options) do
        local menuOption = {
            header = option.title or "Option",
            txt = option.description or "",
            icon = option.icon,
            params = {}
        }
        
        -- Add select function if provided
        if option.onSelect then
            menuOption.params = {
                event = "vein-construction:client:menuSelect",
                args = {
                    id = id,
                    option = option.title,
                    action = "select"
                }
            }
        end
        
        table.insert(qbMenu, menuOption)
    end
    
    -- Show QBCore menu
    exports['qb-menu']:openMenu(qbMenu)
    
    -- Store active menu options for selection callback
    RegisterActiveTask(id, options)
    
    return true
end

-- Function to close menu
function CloseMenu()
    exports['qb-menu']:closeMenu()
end

-- Function to show a notification
function SendNotification(title, message, type, duration)
    if type(title) == 'string' and type(message) == 'string' then
        -- Title and message provided
        QBCore.Functions.Notify({
            text = message,
            caption = title,
            type = type or 'primary',
            duration = duration or 5000
        })
    else
        -- Only message provided as first parameter
        QBCore.Functions.Notify(title, message or 'primary', duration or 5000)
    end
end

-- Function to show an alert
function ShowAlert(title, message, type)
    QBCore.Functions.Notify(message, type or 'primary', 7500)
end

-- Function to show a progress bar
function ShowProgressBar(label, duration, animation, canCancel, onComplete, onCancel)
    animation = animation or {}
    
    -- Start animation if provided
    if animation.dict and animation.clip then
        -- Request animation dictionary
        RequestAnimDict(animation.dict)
        while not HasAnimDictLoaded(animation.dict) do
            Wait(10)
        end
        
        -- Play animation
        TaskPlayAnim(PlayerPedId(), animation.dict, animation.clip, 8.0, -8.0, -1, 49, 0, false, false, false)
    end
    
    -- Show progress bar
    QBCore.Functions.Progressbar("construction_task", label, duration, false, canCancel, {
        disableMovement = animation.disableMovement or false,
        disableCarMovement = animation.disableCarMovement or false,
        disableMouse = animation.disableMouse or false,
        disableCombat = animation.disableCombat or false,
    }, {}, {}, function() -- Complete
        if animation.dict and animation.clip then
            StopAnimTask(PlayerPedId(), animation.dict, animation.clip, 1.0)
        end
        if onComplete then
            onComplete()
        end
        return true
    end, function() -- Cancel
        if animation.dict and animation.clip then
            StopAnimTask(PlayerPedId(), animation.dict, animation.clip, 1.0)
        end
        if onCancel then
            onCancel()
        end
        return false
    end)
    
    -- This is not ideal, but QBCore progressbar is not synchronous
    Wait(duration + 500)
    return true
end

-- Register a command to test the UI
RegisterCommand('testconstructionui', function()
    -- Create a test menu
    local testOptions = {
        {
            title = "Test Option 1",
            description = "This is a test option",
            icon = "fas fa-check",
            onSelect = function()
                SendNotification("Test", "You selected option 1", "success")
            end
        },
        {
            title = "Test Option 2",
            description = "Another test option",
            icon = "fas fa-times",
            onSelect = function()
                SendNotification("Test", "You selected option 2", "error")
            end
        },
        {
            title = "Test Progress",
            description = "Test progress bar",
            icon = "fas fa-spinner",
            onSelect = function()
                ShowProgressBar("Testing Progress", 5000, {
                    dict = "amb@world_human_hammering@male@base",
                    clip = "base"
                }, true, function()
                    SendNotification("Test", "Progress completed", "success")
                end)
            end
        }
    }
    
    ShowMenu("test_menu", "Test Construction UI", testOptions)
    
    print("QBCore menu test started")
end, false)

-- Print a message when the UI is loaded
Citizen.CreateThread(function()
    Citizen.Wait(2000)
    print("Vein Construction UI loaded successfully. Use /testconstructionui to test it.")
end)

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

-- Function to show a menu with options
function ShowMenu(id, title, options, parent)
    -- Initialize options as empty table if nil
    options = options or {}
    
    print('ShowMenu called:', id, title, 'options count:', #options)
    
    -- Make sure we release any existing UI control first
    SetNuiFocus(false, false)
    
    -- Create QBCore menu
    local qbMenu = {}
    
    -- Add header
    table.insert(qbMenu, {
        header = title,
        isMenuHeader = true
    })
    
    -- Add back button if parent is provided
    if parent then
        table.insert(qbMenu, {
            header = "← Go Back",
            txt = "Return to previous menu",
            params = {
                event = "vein-construction:client:menuSelect",
                args = {
                    id = parent,
                    option = "back",
                    action = "back"
                }
            }
        })
    end
    
    -- Add menu options
    for _, option in ipairs(options) do
        local menuOption = {
            header = option.title or "Option",
            txt = option.description or "",
            icon = option.icon,
            params = {}
        }
        
        -- Add select function if provided
        if option.onSelect then
            menuOption.params = {
                event = "vein-construction:client:menuSelect",
                args = {
                    id = id,
                    option = option.title,
                    action = "select"
                }
            }
        end
        
        table.insert(qbMenu, menuOption)
    end
    
    -- Show QBCore menu
    exports['qb-menu']:openMenu(qbMenu)
    
    -- Store active menu options for selection callback
    RegisterActiveTask(id, options)
    
    return true
end

-- Function to handle menu selection for QBCore fallback
RegisterNetEvent('vein-construction:client:menuSelect', function(data)
    debugLog('menuSelect event received', data.id, data.option)
    if not data or not data.id or not data.option then return end
    
    -- Find the selected option in the original menu
    local menuId = data.id
    local optionTitle = data.option
    
    for _, menu in pairs(GetActiveTasks()) do
        if menu.id == menuId then
            for _, option in ipairs(menu.options) do
                if option.title == optionTitle and option.onSelect then
                    debugLog('Executing onSelect function for', optionTitle)
                    option.onSelect()
                    return
                end
            end
        end
    end
    
    debugLog('No matching option found for', menuId, optionTitle)
end)

-- Function to send notification to player
function SendNotification(message, type, duration)
    type = type or 'primary'
    duration = duration or 5000
    
    debugLog('SendNotification:', message, type, duration)
    
    if hasOxLib and lib and libInitialized then
        SafelyUseOxLib('notify', {
            title = 'Construction Job',
            description = message,
            type = type,
            duration = duration
        })
    else
        QBCore.Functions.Notify(message, type, duration)
    end
end

-- Function to show alert message
function ShowAlert(message, type, icon)
    type = type or 'info'
    icon = icon or 'fas fa-info-circle'
    
    debugLog('ShowAlert:', message, type)
    
    if hasOxLib and lib and libInitialized then
        SafelyUseOxLib('showTextUI', {
            position = "right-center",
            icon = icon,
            text = message,
            style = {
                borderRadius = 0,
                backgroundColor = type == 'error' and '#AA0000' or '#2D3A4A',
                color = 'white'
            }
        })
        Wait(3000)
        SafelyUseOxLib('hideTextUI')
    else
        QBCore.Functions.Notify(message, type, 3000)
    end
end

-- Function to display progress bar
function ShowProgressBar(label, duration, canCancel, animation)
    debugLog('ShowProgressBar:', label, duration)
    
    if hasOxLib and lib and libInitialized then
        return SafelyUseOxLib('progressBar', {
            duration = duration,
            label = label,
            useWhileDead = false,
            canCancel = canCancel or false,
            disable = {
                car = true,
                move = true,
                combat = true
            },
            anim = animation or {
                dict = "mini@repair",
                clip = "fixing_a_ped"
            }
        })
    else
        if animation then
            loadAnimDict(animation.dict)
            TaskPlayAnim(PlayerPedId(), animation.dict, animation.clip, 8.0, -8.0, -1, 0, 0, false, false, false)
        end
        
        QBCore.Functions.Progressbar("construction_task", label, duration, canCancel, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {}, {}, {}, function() -- Done
            if animation then
                StopAnimTask(PlayerPedId(), animation.dict, animation.clip, 1.0)
            end
            return true
        end, function() -- Cancel
            if animation then
                StopAnimTask(PlayerPedId(), animation.clip, animation.clip, 1.0)
            end
            return false
        end)
        
        -- This is not ideal, but QBCore progressbar is not synchronous
        Wait(duration + 500)
        return true
    end
end

-- Helper function to load animation dictionary
function loadAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        RequestAnimDict(dict)
        Wait(5)
    end
end

-- Active tasks storage for menu handling
local activeTasks = {}

function RegisterActiveTask(id, options)
    debugLog('RegisterActiveTask:', id, #options)
    activeTasks[id] = {
        id = id,
        options = options
    }
end

function RemoveActiveTask(id)
    debugLog('RemoveActiveTask:', id)
    activeTasks[id] = nil
end

function GetActiveTasks()
    return activeTasks
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
exports('CloseMenu', CloseMenu)
exports('ShowProgressBar', ShowProgressBar)
exports('UpdateProgressBar', UpdateProgressBar)
exports('HideProgressBar', HideProgressBar)
exports('ToggleStatusDisplay', ToggleStatusDisplay)
exports('UpdateJobStatus', UpdateJobStatus)
exports('CreateSectionedMenu', CreateSectionedMenu)
exports('CheckSafetyGear', CheckSafetyGear)
exports('ShowAlert', ShowAlert)

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
                        title = "Section 1",
                        items = {
                            {
                                title = "Item 1",
                                description = "This is item 1",
                                icon = "fas fa-star",
                                onSelect = function()
                                    ShowUINotification("Section 1", "You selected Item 1", "success")
                                end
                            },
                            {
                                title = "Item 2",
                                description = "This is item 2",
                                icon = "fas fa-star",
                                onSelect = function()
                                    ShowUINotification("Section 1", "You selected Item 2", "success")
                                end
                            }
                        }
                    },
                    {
                        title = "Section 2",
                        items = {
                            {
                                title = "Item 3",
                                description = "This is item 3",
                                icon = "fas fa-circle",
                                onSelect = function()
                                    ShowUINotification("Section 2", "You selected Item 3", "info")
                                end
                            }
                        }
                    }
                }, 'test_menu')
            end
        }
    })
end, false)

-- Emergency command to close menus if stuck
RegisterCommand('fixmenu', function()
    debugLog('fixmenu command executed')
    CloseMenu()
    SetNuiFocus(false, false)
    QBCore.Functions.Notify('UI has been reset', 'success')
end, false)

TriggerEvent('chat:addSuggestion', '/fixmenu', 'Reset the UI if you get stuck in a menu')

print('Vein Construction UI loaded successfully. Use /testconstructionui to test it.')

-- Function to check if specific UI functions are available
function CheckLibFunctions()
    if not hasOxLib or not lib then return false end
    
    local requiredFunctions = {
        'hideContext', 
        'registerContext', 
        'showContext',
        'notify',
        'progressBar',
        'alertDialog'
    }
    
    for _, funcName in ipairs(requiredFunctions) do
        if type(lib[funcName]) ~= 'function' then
            print('WARNING: ox_lib.' .. funcName .. ' is not a function or is missing')
            return false
        end
    end
    
    print('All required ox_lib UI functions are available')
    return true
end

-- Test function to check if ox_lib is working properly
function TestOxLibMenu()
    print('=== TESTING OX_LIB MENU FUNCTIONALITY ===')
    
    -- Check if library is available
    if not hasOxLib then
        print('ox_lib not detected')
        return false
    end
    
    if not lib then
        print('lib export is nil')
        return false
    end
    
    -- Create an extremely simple menu just to test the core functionality
    local testMenu = {
        id = 'test_menu_basic',
        title = 'Test Menu',
        options = {
            {
                title = 'Test Option',
                onSelect = function() 
                    print('Test option selected')
                end
            }
        }
    }
    
    print('Attempting to register most basic test menu...')
    
    -- Use pcall to catch any errors
    local success, result = pcall(function()
        return lib.registerContext(testMenu)
    end)
    
    if not success then
        print('Failed to register test menu with error:', result)
        
        -- Try an even more basic test without onSelect
        local basicMenu = {
            id = 'super_basic_menu',
            title = 'Basic Test',
            options = {
                { title = 'Option' }
            }
        }
        
        print('Trying with even more basic menu...')
        success, result = pcall(function()
            return lib.registerContext(basicMenu)
        end)
        
        if not success then
            print('Second attempt also failed with error:', result)
            return false
        end
    end
    
    print('Test menu registered successfully')
    
    return true
end

-- Add a debug command to test the ox_lib menu
RegisterCommand('testmenu', function()
    TestOxLibMenu()
end, false)

-- Add a command to directly test ox_lib with minimal code
RegisterCommand('testoxlib', function()
    print('===== DIRECT OX_LIB TEST =====')
    
    if not lib then
        print('ERROR: lib is nil')
        return
    end
    
    -- Try to access registerContext - this is the most basic test
    if type(lib.registerContext) ~= 'function' then
        print('ERROR: lib.registerContext is not a function')
        print('lib type:', type(lib))
        if type(lib) == 'table' then
            print('Available lib functions:')
            for k, v in pairs(lib) do
                print(' -', k, type(v))
            end
        end
        return
    end
    
    print('lib.registerContext is available, attempting to use it')
    
    -- Create the simplest possible menu
    local simpleMenu = {
        id = 'minimal_test',
        title = 'Test',
        options = {
            { title = 'Option' }
        }
    }
    
    -- Directly call the function with pcall for error capture
    local success, result = pcall(function()
        lib.registerContext(simpleMenu)
    end)
    
    if success then
        print('Menu registered successfully!')
        
        -- Try to show the menu
        if type(lib.showContext) == 'function' then
            print('Attempting to show the menu...')
            pcall(function() lib.showContext('minimal_test') end)
        else
            print('WARNING: lib.showContext is not a function')
        end
    else
        print('Failed to register menu with error:', result)
    end
end, false)

-- Function to fall back to QB menu when ox_lib fails
function CreateQBMenu(id, title, options, parent)
    print('Falling back to QB menu')
    
    local qbMenu = {}
    
    -- Add header
    table.insert(qbMenu, {
        header = title,
        isMenuHeader = true
    })
    
    -- Add back button if parent is provided
    if parent then
        table.insert(qbMenu, {
            header = "← Go Back",
            txt = "Return to previous menu",
            params = {
                event = "vein-construction:client:menuSelect",
                args = {
                    id = parent,
                    option = "back",
                    action = "back"
                }
            }
        })
    end
    
    -- Add menu options
    for _, option in ipairs(options) do
        local menuOption = {
            header = option.title or "Option",
            txt = option.description or "",
            icon = option.icon,
            params = {}
        }
        
        -- Add select function if provided
        if option.onSelect then
            menuOption.params = {
                event = "vein-construction:client:menuSelect",
                args = {
                    id = id,
                    option = option.title,
                    action = "select"
                }
            }
        end
        
        table.insert(qbMenu, menuOption)
    end
    
    -- Show QBCore menu
    exports['qb-menu']:openMenu(qbMenu)
    
    -- Store active menu options for selection callback
    RegisterActiveTask(id, options)
    
    return true
end 