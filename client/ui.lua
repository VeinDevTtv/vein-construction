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

-- Declare local variables for ox_lib support
local hasOxLib = false
local libInitialized = false
-- Use direct reference to the global lib
local lib = nil

-- Check if ox_lib is available
Citizen.CreateThread(function()
    -- Wait a moment to ensure other resources are loaded
    Citizen.Wait(1000)
    
    -- Check if ox_lib is started
    if GetResourceState('ox_lib') == 'started' then
        hasOxLib = true
        
        -- Use proper FiveM exports syntax - this assigns directly to global lib
        if not lib then
            -- Try both methods of getting the export
            lib = exports['ox_lib']
            
            -- Also check if it's been set globally
            if not lib and _G.lib then
                lib = _G.lib
            end
            
            -- Check if lib is fully initialized
            if lib and type(lib.registerContext) == 'function' then
                print('ox_lib fully initialized in UI module')
                libInitialized = true
            else
                print('WARNING: ox_lib export obtained but registerContext not available')
            end
        end
    end
    
    print('ox_lib detection status in UI module:')
    print('  - Resource detected:', hasOxLib)
    print('  - Lib export obtained:', lib ~= nil)
    print('  - Functions available:', libInitialized)
    
    -- Run a test if lib is available
    if hasOxLib and lib and libInitialized then
        -- Schedule a delayed test to ensure everything is loaded
        Citizen.SetTimeout(2000, function()
            local testResult = TestOxLibMenu()
            print('ox_lib menu test result:', testResult)
        end)
    end
end)

local debugMode = false -- Set to true for debugging

-- Debug logging function
local function debugLog(...)
    if debugMode then
        print('[vein-construction UI]', ...)
    end
end

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

-- Function to safely use ox_lib
function SafelyUseOxLib(action, param)
    if not action then
        print('ERROR: No action provided to SafelyUseOxLib')
        return nil
    end
    
    -- Ensure param is a table if required
    if action == 'registerContext' then
        if not param then
            print('ERROR: registerContext requires a parameter table')
            return nil
        elseif type(param) ~= 'table' then
            print('ERROR: registerContext parameter must be a table, got', type(param))
            return nil
        elseif type(param.options) ~= 'table' then
            print('ERROR: registerContext options must be a table, got', type(param.options))
            return nil
        elseif #param.options == 0 then
            print('WARNING: registerContext called with empty options array')
            -- Don't return nil here, allow empty menus
        end
        
        -- Ensure options are properly formatted for ox_lib
        for i, option in ipairs(param.options) do
            -- Always ensure these fields exist
            option.title = option.title or 'Option ' .. i
            option.description = option.description or ''
            
            -- If onSelect is a function, wrap it properly for ox_lib
            if type(option.onSelect) == 'function' then
                local originalOnSelect = option.onSelect
                option.onSelect = function(args)
                    -- Execute the original function
                    originalOnSelect()
                end
            end
        end
    end
    
    if hasOxLib and lib and libInitialized then
        if action == 'hideContext' and type(lib.hideContext) == "function" then
            return lib.hideContext()
        elseif action == 'registerContext' and type(lib.registerContext) == "function" then
            -- Dump the full context for debugging
            print('REGISTERING CONTEXT:')
            for k, v in pairs(param) do
                if k ~= 'options' then
                    print(k, '=', v)
                else
                    print('options = [' .. #v .. ' items]')
                    -- Print first few options
                    for i = 1, math.min(3, #v) do
                        print('  Option ' .. i .. ':', v[i].title)
                    end
                end
            end
            
            -- Try to register context
            local success, result = pcall(function()
                return lib.registerContext(param)
            end)
            
            if not success then
                print('ERROR in registerContext:', result)
                return false
            end
            
            return result
        elseif action == 'showContext' and type(lib.showContext) == "function" then
            print('SHOWING CONTEXT:', param)
            
            -- Try to show context
            local success, result = pcall(function()
                return lib.showContext(param)
            end)
            
            if not success then
                print('ERROR in showContext:', result)
                return false
            end
            
            return result
        elseif action == 'alertDialog' and type(lib.alertDialog) == "function" then
            return lib.alertDialog(param)
        elseif action == 'progressBar' and type(lib.progressBar) == "function" then
            return lib.progressBar(param)
        elseif action == 'notify' and type(lib.notify) == "function" then
            return lib.notify(param)
        elseif action == 'showTextUI' and type(lib.showTextUI) == "function" then
            return lib.showTextUI(param)
        elseif action == 'hideTextUI' and type(lib.hideTextUI) == "function" then
            return lib.hideTextUI()
        else
            print('Unknown action or method not available:', action)
            return nil
        end
    else
        print('ox_lib not available for action:', action)
        print('hasOxLib:', hasOxLib)
        print('lib exists:', lib ~= nil)
        print('libInitialized:', libInitialized)
        return nil
    end
end

-- Function to close any open menus
function CloseMenu()
    menuOpen = false
    SetNuiFocus(false, false)
    
    debugLog('CloseMenu called')
    
    if hasOxLib and lib and libInitialized then
        SafelyUseOxLib('hideContext')
    else
        TriggerEvent('qb-menu:client:closeMenu')
    end
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
    CloseMenu()
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

-- Function to validate and normalize a menu option structure
function ValidateMenuOption(option)
    if type(option) ~= 'table' then
        print('WARNING: Invalid menu option (not a table):', type(option))
        return {
            title = 'Invalid Option',
            description = 'Option format error'
        }
    end
    
    -- Create a normalized option
    local validOption = {
        title = option.title or 'No Title',
    }
    
    -- Optional fields
    if option.description then validOption.description = option.description end
    if option.icon then validOption.icon = option.icon end
    
    -- Only add onSelect if it's a function
    if type(option.onSelect) == 'function' then
        validOption.onSelect = option.onSelect
    end
    
    return validOption
end

-- Safely register a context menu with better error handling
function SafeRegisterContext(menuData)
    if not hasOxLib or not lib or not libInitialized then
        print('ERROR: Cannot register context - ox_lib not available')
        return false
    end
    
    if type(menuData) ~= 'table' then
        print('ERROR: menuData must be a table, got', type(menuData))
        return false
    end
    
    if not menuData.id then
        print('ERROR: menuData.id is required')
        return false
    end
    
    if not menuData.title then
        print('ERROR: menuData.title is required')
        return false
    end
    
    if type(menuData.options) ~= 'table' then
        print('ERROR: menuData.options must be a table')
        menuData.options = {}
    end
    
    -- Validate each option to ensure it's properly structured
    for i, option in ipairs(menuData.options) do
        if type(option) ~= 'table' then
            print('WARNING: Option at index', i, 'is not a table, replacing with default option')
            menuData.options[i] = {title = 'Invalid Option'}
        elseif not option.title then
            print('WARNING: Option at index', i, 'has no title, adding default title')
            option.title = 'Option ' .. i
        end
        
        -- Ensure onSelect is a function if present
        if option.onSelect ~= nil and type(option.onSelect) ~= 'function' then
            print('WARNING: Option "' .. option.title .. '" has invalid onSelect (not a function), removing')
            option.onSelect = nil
        end
    end
    
    -- Print menu data for debugging
    print('Registering menu:', menuData.id)
    print('Title:', menuData.title)
    print('Options count:', #menuData.options)
    if menuData.menu then
        print('Parent menu:', menuData.menu)
    end
    
    -- Try to register the context
    local success, result = pcall(function()
        return lib.registerContext(menuData)
    end)
    
    if not success then
        print('ERROR: Failed to register context menu:', result)
        -- Debug output the menu structure for troubleshooting
        print('Menu structure that failed:')
        for key, value in pairs(menuData) do
            if key ~= 'options' then
                print('  ' .. key .. ':', value)
            else
                print('  options: [table with ' .. #value .. ' items]')
                -- Print first option as example
                if #value > 0 then
                    print('    First option:')
                    for k, v in pairs(value[1]) do
                        if type(v) ~= 'function' then
                            print('      ' .. k .. ':', v)
                        else
                            print('      ' .. k .. ': [function]')
                        end
                    end
                end
            end
        end
        return false
    end
    
    if result == false then
        print('WARNING: lib.registerContext returned false')
        return false
    end
    
    return true
end

-- Safely show a context menu with better error handling
function SafeShowContext(id)
    if not hasOxLib or not lib or not libInitialized then
        print('ERROR: Cannot show context - ox_lib not available')
        return false
    end
    
    if not id then
        print('ERROR: Menu ID is required')
        return false
    end
    
    print('Showing menu:', id)
    
    -- Try to show the context
    local success, result = pcall(function()
        return lib.showContext(id)
    end)
    
    if not success then
        print('ERROR: Failed to show context menu:', result)
        return false
    end
    
    if result == false then
        print('WARNING: lib.showContext returned false')
        return false
    end
    
    return true
end

-- Function to show a menu with options
function ShowMenu(id, title, options, parent)
    -- Initialize options as empty table if nil
    options = options or {}
    
    print('ShowMenu called:', id, title, 'options count:', #options)
    
    -- Make sure we release any existing UI control first
    SetNuiFocus(false, false)
    
    -- If ox_lib is available, use it
    if hasOxLib and lib and libInitialized then
        print('Using ox_lib for menu')
        
        -- Create a simplified menu structure compatible with ox_lib
        local menuData = {
            id = id,
            title = title,
            options = {},
        }
        
        -- Add parent menu if provided
        if parent then
            menuData.menu = parent
        end
        
        -- Process options to ensure format compatibility
        if type(options) == 'table' then
            for i, option in ipairs(options) do
                -- Validate and normalize the option
                local cleanOption = ValidateMenuOption(option)
                table.insert(menuData.options, cleanOption)
            end
        end
        
        print('Menu data prepared with ' .. #menuData.options .. ' options')
        
        -- Use our safer registration and display functions
        if SafeRegisterContext(menuData) then
            if SafeShowContext(id) then
                return true
            else
                SetNuiFocus(false, false)
                QBCore.Functions.Notify('Failed to show menu', 'error')
                return false
            end
        else
            SetNuiFocus(false, false)
            QBCore.Functions.Notify('Failed to register menu', 'error')
            return false
        end
    else
        print('Using QBCore menu')
        -- QBCore menu code remains unchanged
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
                    event = "qb-menu:client:openMenu",
                    args = {
                        menuType = parent
                    }
                }
            })
        end
        
        -- Add menu options
        for _, option in ipairs(options) do
            local menuOption = {
                header = option.title,
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
    end
    
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
                StopAnimTask(PlayerPedId(), animation.dict, animation.clip, 1.0)
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
    
    if not libInitialized then
        print('lib not fully initialized')
        return false
    end
    
    -- Try to create a simple test menu
    local testMenu = {
        id = 'test_menu',
        title = 'Test Menu',
        options = {
            {
                title = 'Test Option',
                description = 'This is a test',
                onSelect = function()
                    print('Test option selected')
                end
            }
        }
    }
    
    print('Attempting to register test menu...')
    
    -- Use pcall to catch any errors
    local success, result = pcall(function()
        return lib.registerContext(testMenu)
    end)
    
    if not success then
        print('Failed to register test menu with error:', result)
        return false
    end
    
    print('Test menu registered successfully')
    print('Attempting to show test menu...')
    
    -- Use pcall to catch any errors when showing the menu
    local showSuccess, showResult = pcall(function()
        return lib.showContext('test_menu')
    end)
    
    if not showSuccess then
        print('Failed to show test menu with error:', showResult)
        return false
    end
    
    print('Test menu shown successfully')
    print('ox_lib context menus are working properly')
    return true
end

-- Add a debug command to test the ox_lib menu
RegisterCommand('testmenu', function()
    TestOxLibMenu()
end, false) 