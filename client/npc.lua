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

-- Function to open construction shop
function OpenConstructionShop()
    local options = {
        {
            title = 'Safety Equipment',
            description = 'Required safety gear for construction work',
            icon = 'fas fa-hard-hat',
            onSelect = function()
                OpenSafetyEquipmentMenu()
            end
        },
        {
            title = 'Tools',
            description = 'Construction tools and equipment',
            icon = 'fas fa-tools',
            onSelect = function()
                OpenToolsMenu()
            end
        },
        {
            title = 'Materials',
            description = 'Construction materials',
            icon = 'fas fa-boxes',
            onSelect = function()
                OpenMaterialsMenu()
            end
        }
    }
    
    ShowMenu('construction_shop', 'Construction Shop', options)
end

-- Function to open safety equipment menu
function OpenSafetyEquipmentMenu()
    local options = {
        {
            title = 'Construction Helmet',
            description = 'Price: $50\nRequired for all construction work',
            icon = 'fas fa-hard-hat',
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', 'construction_helmet', 50)
            end
        },
        {
            title = 'Safety Vest',
            description = 'Price: $30\nRequired for all construction work',
            icon = 'fas fa-vest',
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', 'safety_vest', 30)
            end
        },
        {
            title = 'Work Gloves',
            description = 'Price: $20\nRequired for all construction work',
            icon = 'fas fa-mitten',
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', 'work_gloves', 20)
            end
        }
    }
    
    ShowMenu('safety_equipment', 'Safety Equipment', options, 'construction_shop')
end

-- Function to open tools menu
function OpenToolsMenu()
    local options = {
        {
            title = 'Hammer',
            description = 'Price: $100\nRequired for hammering tasks',
            icon = 'fas fa-hammer',
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', 'hammer', 100)
            end
        },
        {
            title = 'Power Drill',
            description = 'Price: $200\nRequired for drilling tasks',
            icon = 'fas fa-screwdriver',
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', 'drill', 200)
            end
        },
        {
            title = 'Welding Torch',
            description = 'Price: $300\nRequired for welding tasks',
            icon = 'fas fa-fire',
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', 'welding_torch', 300)
            end
        },
        {
            title = 'Shovel',
            description = 'Price: $150\nRequired for roadwork tasks',
            icon = 'fas fa-shovel',
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', 'shovel', 150)
            end
        },
        {
            title = 'Paint Roller',
            description = 'Price: $80\nRequired for roadwork tasks',
            icon = 'fas fa-paint-roller',
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', 'paint_roller', 80)
            end
        }
    }
    
    ShowMenu('tools', 'Tools', options, 'construction_shop')
end

-- Function to open materials menu
function OpenMaterialsMenu()
    local options = {
        {
            title = 'Nails (Box)',
            description = 'Price: $20\nRequired for hammering tasks',
            icon = 'fas fa-thumbtack',
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', 'nails', 20)
            end
        },
        {
            title = 'Screws (Box)',
            description = 'Price: $25\nRequired for drilling tasks',
            icon = 'fas fa-screwdriver',
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', 'screws', 25)
            end
        },
        {
            title = 'Metal Rods (Bundle)',
            description = 'Price: $50\nRequired for welding tasks',
            icon = 'fas fa-grip-lines',
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', 'metal_rods', 50)
            end
        },
        {
            title = 'Asphalt Bucket',
            description = 'Price: $40\nRequired for roadwork tasks',
            icon = 'fas fa-fill-drip',
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', 'asphalt_bucket', 40)
            end
        }
    }
    
    ShowMenu('materials', 'Materials', options, 'construction_shop')
end

-- Register server callback for buying items
RegisterNetEvent('vein-construction:client:itemPurchased', function(success, message)
    if success then
        QBCore.Functions.Notify(message, 'success')
    else
        QBCore.Functions.Notify(message, 'error')
    end
end)

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