-- Initialize QBCore
local QBCore = exports['qb-core']:GetCoreObject()

-- Menu state management
local menuOpen = false
local menuData = {}
local menuCallbacks = {}

-- Function to send data to the NUI
function SendUIMessage(data)
    SendNUIMessage(data)
end

-- Function to show a menu
function ShowUIMenu(id, title, options, parent)
    -- Store callbacks separately because they can't be passed to NUI
    if options then
        for i, option in ipairs(options) do
            if option.onSelect then
                menuCallbacks[id .. '_' .. i] = option.onSelect
                option.onSelect = true -- Just set to true so UI knows it's clickable
            end
        end
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
        parent = parent
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
    end
end)

-- Override existing function calls to use our UI system
-- This is the function that will be used instead of the ox_lib menus
function ShowMenu(id, title, options, parent)
    ShowUIMenu(id, title, options, parent)
end

-- Override notification functions
function SendNotification(title, message, type, icon)
    ShowUINotification(title, message, type, icon)
end

-- Export the functions
exports('ShowMenu', ShowMenu)
exports('SendNotification', SendNotification)
exports('CloseMenu', CloseUIMenu)

-- Add debug command to test the UI
RegisterCommand('testconstructionui', function()
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
        }
    })
end, false)

print('Vein Construction UI loaded successfully. Use /testconstructionui to test it.') 