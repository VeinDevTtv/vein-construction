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

-- Function to open the construction shop
function OpenConstructionShop()
    local sections = {
        {
            title = "Shop Categories",
            items = {
                {
                    title = "Safety Equipment",
                    description = "Required safety gear for construction work",
                    icon = "fas fa-hard-hat",
                    onSelect = function()
                        OpenSafetyEquipmentMenu()
                    end
                },
                {
                    title = "Tools",
                    description = "Construction tools and equipment",
                    icon = "fas fa-tools",
                    onSelect = function()
                        OpenToolsMenu()
                    end
                },
                {
                    title = "Materials",
                    description = "Construction materials",
                    icon = "fas fa-cubes",
                    onSelect = function()
                        OpenMaterialsMenu()
                    end
                }
            }
        }
    }
    
    CreateSectionedMenu('construction_shop', 'Construction Shop', sections)
end

-- Function to open the safety equipment menu
function OpenSafetyEquipmentMenu()
    local safetyItems = {
        {
            title = "Construction Helmet",
            description = "Protects your head from falling objects",
            icon = "fas fa-hard-hat",
            price = 75,
            id = "construction_helmet",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', "construction_helmet", "safety")
            end
        },
        {
            title = "Safety Vest",
            description = "High visibility vest for safety on site",
            icon = "fas fa-vest",
            price = 50,
            id = "safety_vest",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', "safety_vest", "safety")
            end
        },
        {
            title = "Work Gloves",
            description = "Protects hands from injuries",
            icon = "fas fa-mitten",
            price = 35,
            id = "work_gloves",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', "work_gloves", "safety")
            end
        },
        {
            title = "Full Safety Kit",
            description = "All required safety equipment (helmet, vest, gloves)",
            icon = "fas fa-shield-alt",
            price = 150,
            id = "safety_kit",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', "safety_kit", "safety")
            end
        }
    }
    
    -- Format options with prices in description
    local options = {}
    for _, item in ipairs(safetyItems) do
        table.insert(options, {
            title = item.title,
            description = item.description .. " - $" .. item.price,
            icon = item.icon,
            price = item.price,
            id = item.id,
            onSelect = item.onSelect
        })
    end
    
    ShowMenu('safety_equipment', 'Safety Equipment', options, 'construction_shop')
end

-- Function to open the tools menu
function OpenToolsMenu()
    local toolItems = {
        {
            title = "Hammer",
            description = "Basic construction hammer",
            icon = "fas fa-hammer",
            price = 100,
            id = "hammer",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', "hammer", "tool")
            end
        },
        {
            title = "Power Drill",
            description = "Electric drill for construction work",
            icon = "fas fa-screwdriver",
            price = 250,
            id = "power_drill",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', "power_drill", "tool")
            end
        },
        {
            title = "Measuring Tape",
            description = "For precise measurements",
            icon = "fas fa-ruler",
            price = 40,
            id = "measuring_tape",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', "measuring_tape", "tool")
            end
        },
        {
            title = "Shovel",
            description = "For digging and moving materials",
            icon = "fas fa-snowplow",
            price = 120,
            id = "shovel",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', "shovel", "tool")
            end
        },
        {
            title = "Welding Torch",
            description = "For metal construction work",
            icon = "fas fa-fire",
            price = 350,
            id = "welding_torch",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', "welding_torch", "tool")
            end
        }
    }
    
    -- Format options with prices in description
    local options = {}
    for _, item in ipairs(toolItems) do
        table.insert(options, {
            title = item.title,
            description = item.description .. " - $" .. item.price,
            icon = item.icon,
            price = item.price,
            id = item.id,
            onSelect = item.onSelect
        })
    end
    
    ShowMenu('tools_menu', 'Construction Tools', options, 'construction_shop')
end

-- Function to open the materials menu
function OpenMaterialsMenu()
    local materialItems = {
        {
            title = "Concrete Mix",
            description = "50lb bag of concrete mix",
            icon = "fas fa-cubes",
            price = 45,
            id = "concrete_mix",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', "concrete_mix", "material")
            end
        },
        {
            title = "Lumber",
            description = "Wood for construction",
            icon = "fas fa-grip-lines",
            price = 60,
            id = "lumber",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', "lumber", "material")
            end
        },
        {
            title = "Steel Beams",
            description = "Metal structural support",
            icon = "fas fa-stream",
            price = 120,
            id = "steel_beams",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', "steel_beams", "material")
            end
        },
        {
            title = "Bricks",
            description = "Stack of 50 bricks",
            icon = "fas fa-border-all",
            price = 85,
            id = "bricks",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', "bricks", "material")
            end
        },
        {
            title = "Paint",
            description = "1 gallon of paint",
            icon = "fas fa-fill-drip",
            price = 30,
            id = "paint",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', "paint", "material")
            end
        }
    }
    
    -- Format options with prices in description
    local options = {}
    for _, item in ipairs(materialItems) do
        table.insert(options, {
            title = item.title,
            description = item.description .. " - $" .. item.price,
            icon = item.icon,
            price = item.price,
            id = item.id,
            onSelect = item.onSelect
        })
    end
    
    ShowMenu('materials_menu', 'Construction Materials', options, 'construction_shop')
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

-- Register event handler for opening construction shop
RegisterNetEvent('vein-construction:client:openConstructionShop')
AddEventHandler('vein-construction:client:openConstructionShop', function()
    OpenConstructionShop()
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