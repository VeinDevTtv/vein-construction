-- Initialize QBCore
local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local isOnDuty = false

-- Initialize player data
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
end)

-- NPC Variables
local jobNPC = nil

-- Create job NPC and add target interactions
function CreateJobNPC()
    -- Check if NPC already exists
    if DoesEntityExist(jobNPC) then
        DeleteEntity(jobNPC)
    end
    
    -- Request the model
    local model = GetHashKey(Config.JobNPC.model)
    RequestModel(model)
    
    while not HasModelLoaded(model) do
        Wait(1)
    end
    
    -- Create the ped
    jobNPC = CreatePed(4, model, Config.JobNPC.coords.x, Config.JobNPC.coords.y, Config.JobNPC.coords.z - 1.0, Config.JobNPC.coords.w, false, true)
    SetEntityHeading(jobNPC, Config.JobNPC.coords.w)
    FreezeEntityPosition(jobNPC, true)
    SetEntityInvincible(jobNPC, true)
    SetBlockingOfNonTemporaryEvents(jobNPC, true)
    
    -- Set the ped into a scenario
    TaskStartScenarioInPlace(jobNPC, Config.JobNPC.scenario, 0, true)
    
    -- Add target interactions
    if Config.UseOxTarget then
        AddOxInteractions()
    else
        AddQBInteractions()
    end
end

-- Add ox_target interactions
function AddOxInteractions()
    exports.ox_target:addLocalEntity(jobNPC, {
        {
            name = 'construction_job_apply',
            icon = 'fas fa-hard-hat',
            label = 'Apply for Construction Job',
            distance = 2.0,
            onSelect = function()
                if PlayerData.job and PlayerData.job.name == Config.JobName then
                    QBCore.Functions.Notify('You already work for this company', 'error')
                    return
                end
                
                OpenJobMenu()
            end
        },
        {
            name = 'construction_job_management',
            icon = 'fas fa-clipboard-list',
            label = 'Construction Job Management',
            distance = 2.0,
            onSelect = function()
                if not PlayerData.job or PlayerData.job.name ~= Config.JobName then
                    QBCore.Functions.Notify('You don\'t work for this company', 'error')
                    return
                end
                
                OpenJobManagementMenu()
            end
        },
        {
            name = 'construction_shop',
            icon = 'fas fa-shopping-cart',
            label = 'Construction Shop',
            distance = 2.0,
            onSelect = function()
                OpenConstructionShop()
            end
        }
    })
    
    -- Add HQ zone for clock in/out
    exports.ox_target:addSphereZone({
        coords = Config.HQ.coords,
        radius = 1.5,
        options = {
            {
                name = 'construction_clock',
                icon = 'fas fa-clock',
                label = function()
                    if isOnDuty then
                        return 'Clock Out'
                    else
                        return 'Clock In'
                    end
                end,
                distance = 2.0,
                onSelect = function()
                    if not PlayerData.job or PlayerData.job.name ~= Config.JobName then
                        QBCore.Functions.Notify('You don\'t work for this company', 'error')
                        return
                    end
                    
                    ToggleDuty()
                end,
                canInteract = function()
                    return PlayerData and PlayerData.job and PlayerData.job.name == Config.JobName
                end
            }
        }
    })
    
    -- Add repair station for tools
    exports.ox_target:addSphereZone({
        coords = vector3(Config.HQ.coords.x + 5.0, Config.HQ.coords.y, Config.HQ.coords.z),
        radius = 1.5,
        options = {
            {
                name = 'construction_repair',
                icon = 'fas fa-tools',
                label = 'Repair Tools',
                distance = 2.0,
                onSelect = function()
                    if not PlayerData.job or PlayerData.job.name ~= Config.JobName then
                        QBCore.Functions.Notify('You don\'t work for this company', 'error')
                        return
                    end
                    
                    RepairTools()
                end,
                canInteract = function()
                    return PlayerData and PlayerData.job and PlayerData.job.name == Config.JobName
                end
            }
        }
    })
end

-- Add QB-Target interactions (fallback if ox_target is not used)
function AddQBInteractions()
    exports['qb-target']:AddTargetEntity(jobNPC, {
        options = {
            {
                type = "client",
                event = "vein-construction:client:openJobMenu",
                icon = "fas fa-hard-hat",
                label = "Apply for Construction Job",
                canInteract = function()
                    return not PlayerData or not PlayerData.job or PlayerData.job.name ~= Config.JobName
                end
            },
            {
                type = "client",
                event = "vein-construction:client:openJobManagement",
                icon = "fas fa-clipboard-list",
                label = "Construction Job Management",
                canInteract = function()
                    return PlayerData and PlayerData.job and PlayerData.job.name == Config.JobName
                end
            },
            {
                type = "client",
                event = "vein-construction:client:openShop",
                icon = "fas fa-shopping-cart",
                label = "Construction Shop",
                job = "all"
            },
        },
        distance = 2.0
    })
    
    -- Add HQ zone for clock in/out
    exports['qb-target']:AddCircleZone("construction_clock", Config.HQ.coords, 1.5, {
        name = "construction_clock",
        debugPoly = false
    }, {
        options = {
            {
                type = "client",
                event = "vein-construction:client:toggleDuty",
                icon = "fas fa-clock",
                label = function()
                    if isOnDuty then
                        return "Clock Out"
                    else
                        return "Clock In"
                    end
                end,
                canInteract = function()
                    return PlayerData and PlayerData.job and PlayerData.job.name == Config.JobName
                end
            },
        },
        distance = 2.0
    })
    
    -- Add repair station for tools
    exports['qb-target']:AddCircleZone("construction_repair", vector3(Config.HQ.coords.x + 5.0, Config.HQ.coords.y, Config.HQ.coords.z), 1.5, {
        name = "construction_repair",
        debugPoly = false
    }, {
        options = {
            {
                type = "client",
                event = "vein-construction:client:repairTools",
                icon = "fas fa-tools",
                label = "Repair Tools",
                canInteract = function()
                    return PlayerData and PlayerData.job and PlayerData.job.name == Config.JobName
                end
            },
        },
        distance = 2.0
    })
end

-- Construction shop function
function OpenConstructionShop()
    if Config.UseOxInventory then
        exports.ox_inventory:openInventory('shop', { type = 'construction', id = 1 })
    else
        local shopItems = {
            label = "Construction Shop",
            slots = 30,
            items = {}
        }
        
        -- Add tools to shop
        table.insert(shopItems.items, {
            name = "hammer",
            price = 250,
            amount = 10,
            info = {},
            type = "item",
            slot = 1,
        })
        
        table.insert(shopItems.items, {
            name = "drill",
            price = 500,
            amount = 10,
            info = {},
            type = "item",
            slot = 2,
        })
        
        table.insert(shopItems.items, {
            name = "welding_torch",
            price = 1000,
            amount = 10,
            info = {},
            type = "item",
            slot = 3,
        })
        
        table.insert(shopItems.items, {
            name = "shovel",
            price = 350,
            amount = 10,
            info = {},
            type = "item",
            slot = 4,
        })
        
        table.insert(shopItems.items, {
            name = "paint_roller",
            price = 200,
            amount = 10,
            info = {},
            type = "item",
            slot = 5,
        })
        
        -- Add safety gear to shop
        table.insert(shopItems.items, {
            name = "construction_helmet",
            price = 150,
            amount = 10,
            info = {},
            type = "item",
            slot = 6,
        })
        
        table.insert(shopItems.items, {
            name = "safety_vest",
            price = 100,
            amount = 10,
            info = {},
            type = "item",
            slot = 7,
        })
        
        table.insert(shopItems.items, {
            name = "work_gloves",
            price = 75,
            amount = 10,
            info = {},
            type = "item",
            slot = 8,
        })
        
        table.insert(shopItems.items, {
            name = "welding_mask",
            price = 250,
            amount = 10,
            info = {},
            type = "item",
            slot = 9,
        })
        
        table.insert(shopItems.items, {
            name = "work_belt",
            price = 300,
            amount = 10,
            info = {},
            type = "item",
            slot = 10,
        })
        
        -- Add materials to shop
        table.insert(shopItems.items, {
            name = "nails",
            price = 20,
            amount = 50,
            info = {},
            type = "item",
            slot = 11,
        })
        
        table.insert(shopItems.items, {
            name = "screws",
            price = 25,
            amount = 50,
            info = {},
            type = "item",
            slot = 12,
        })
        
        table.insert(shopItems.items, {
            name = "metal_rods",
            price = 75,
            amount = 50,
            info = {},
            type = "item",
            slot = 13,
        })
        
        table.insert(shopItems.items, {
            name = "asphalt_bucket",
            price = 100,
            amount = 50,
            info = {},
            type = "item",
            slot = 14,
        })
        
        TriggerServerEvent("inventory:server:OpenInventory", "shop", "construction", shopItems)
    end
end

-- QB Target Event Handlers (if not using ox_target)
RegisterNetEvent('vein-construction:client:openJobMenu', function()
    OpenJobMenu()
end)

RegisterNetEvent('vein-construction:client:openJobManagement', function()
    OpenJobManagementMenu()
end)

RegisterNetEvent('vein-construction:client:openShop', function()
    OpenConstructionShop()
end)

RegisterNetEvent('vein-construction:client:toggleDuty', function()
    ToggleDuty()
end)

RegisterNetEvent('vein-construction:client:repairTools', function()
    RepairTools()
end)

-- Create NPC when resource starts
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    Wait(1000) -- Wait a second to make sure everything is loaded
    CreateJobNPC()
end)

-- Create NPC when player loads
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    CreateJobNPC()
end)

-- Delete NPC when resource stops
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    if DoesEntityExist(jobNPC) then
        DeleteEntity(jobNPC)
    end
end) 