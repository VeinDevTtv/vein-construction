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
local shopNPC = nil

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

-- Function to release control back to the player if UI fails to appear
function ReleaseUIControl()
    SetNuiFocus(false, false)
    TriggerEvent('qb-menu:client:closeMenu')
end

-- Function to open the construction shop
function OpenConstructionShop()
    print('OpenConstructionShop called')
    
    -- Create menu options
    local options = {
        {
            title = "Safety Equipment",
            description = "Required gear for construction work",
            icon = "fas fa-hard-hat",
            onSelect = function()
                OpenSafetyEquipmentMenu()
            end
        },
        {
            title = "Tools",
            description = "Equipment for construction tasks",
            icon = "fas fa-tools",
            onSelect = function()
                OpenToolsMenu()
            end
        },
        {
            title = "Materials",
            description = "Building materials",
            icon = "fas fa-boxes",
            onSelect = function()
                OpenMaterialsMenu()
            end
        }
    }
    
    -- Show menu directly without pcall
    ShowMenu('construction_shop', 'Construction Shop', options)
end

-- Safety Equipment Menu
function OpenSafetyEquipmentMenu()
    print('OpenSafetyEquipmentMenu called')
    
    local options = {
        {
            title = "Construction Helmet",
            description = "$150 - Standard safety helmet for construction work",
            icon = "fas fa-hard-hat",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', 'construction_helmet', 150)
            end
        },
        {
            title = "Safety Vest",
            description = "$100 - High-visibility safety vest",
            icon = "fas fa-tshirt",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', 'safety_vest', 100)
            end
        },
        {
            title = "Work Gloves",
            description = "$75 - Protective gloves for construction work",
            icon = "fas fa-mitten",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', 'work_gloves', 75)
            end
        },
        {
            title = "Safety Boots",
            description = "$200 - Steel-toed boots for construction work",
            icon = "fas fa-boot",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', 'safety_boots', 200)
            end
        },
        {
            title = "Back",
            description = "Return to main menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                OpenConstructionShop()
            end
        }
    }
    
    -- Show menu directly without pcall
    ShowMenu('safety_menu', 'Safety Equipment', options, 'construction_shop')
end

-- Tools Menu
function OpenToolsMenu()
    print('OpenToolsMenu called')
    
    local options = {
        {
            title = "Hammer",
            description = "$300 - Standard construction hammer",
            icon = "fas fa-hammer",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', 'hammer', 300)
            end
        },
        {
            title = "Screwdriver Set",
            description = "$250 - Set of various screwdrivers",
            icon = "fas fa-screwdriver",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', 'screwdriver_set', 250)
            end
        },
        {
            title = "Power Drill",
            description = "$500 - Electric drill for construction tasks",
            icon = "fas fa-power-off",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', 'power_drill', 500)
            end
        },
        {
            title = "Measuring Tape",
            description = "$100 - For precise measurements",
            icon = "fas fa-ruler",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', 'measuring_tape', 100)
            end
        },
        {
            title = "Wrench Set",
            description = "$350 - Set of various sized wrenches",
            icon = "fas fa-wrench",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', 'wrench_set', 350)
            end
        },
        {
            title = "Back",
            description = "Return to main menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                OpenConstructionShop()
            end
        }
    }
    
    -- Show menu directly without pcall
    ShowMenu('tools_menu', 'Tools', options, 'construction_shop')
end

-- Materials Menu
function OpenMaterialsMenu()
    print('OpenMaterialsMenu called')
    
    local options = {
        {
            title = "Cement Bag",
            description = "$75 - A bag of cement for construction",
            icon = "fas fa-shopping-bag",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', 'cement_bag', 75)
            end
        },
        {
            title = "Lumber",
            description = "$50 - Wood for construction projects",
            icon = "fas fa-tree",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', 'lumber', 50)
            end
        },
        {
            title = "Steel Beam",
            description = "$150 - Heavy steel beam for construction",
            icon = "fas fa-grip-lines",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', 'steel_beam', 150)
            end
        },
        {
            title = "Brick Pack",
            description = "$100 - A pack of construction bricks",
            icon = "fas fa-border-all",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', 'brick_pack', 100)
            end
        },
        {
            title = "Wire Bundle",
            description = "$60 - Bundle of electrical wires",
            icon = "fas fa-plug",
            onSelect = function()
                TriggerServerEvent('vein-construction:server:buyItem', 'wire_bundle', 60)
            end
        },
        {
            title = "Back",
            description = "Return to main menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                OpenConstructionShop()
            end
        }
    }
    
    -- Show menu directly without pcall
    ShowMenu('materials_menu', 'Materials', options, 'construction_shop')
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

-- Make sure we add an emergency close menu command
RegisterCommand('closeconstructionmenu', function()
    ReleaseUIControl()
    QBCore.Functions.Notify('Menu closed via command', 'primary')
end, false)

TriggerEvent('chat:addSuggestion', '/closeconstructionmenu', 'Close the construction menu if you get stuck')

-- Add an event handler for NPC interactions
RegisterNetEvent('vein-construction:client:interactNPC', function(interactionType)
    -- Close any existing menus first
    ReleaseUIControl()
    
    Wait(100) -- Short wait to ensure previous menus are closed
    
    -- Handle different interaction types
    if interactionType == 'shop' then
        OpenConstructionShop()
    elseif interactionType == 'job' then
        TriggerEvent('vein-construction:client:openJobMenu')
    elseif interactionType == 'projects' then
        TriggerServerEvent('vein-construction:server:getActiveProjects')
    end
end)

-- Setup Construction NPCs
function SetupConstructionNPCs()
    print('Setting up construction NPCs...')
    TriggerEvent('vein-construction:client:setupNPCs')
    print('Construction NPCs setup complete')
end

-- Add event to re-create NPCs if they get deleted
RegisterNetEvent('vein-construction:client:respawnNPCs', function()
    print('Respawning construction NPCs...')
    
    -- Delete existing NPCs if they exist
    if DoesEntityExist(jobNPC) then
        DeleteEntity(jobNPC)
    end
    
    if DoesEntityExist(shopNPC) then
        DeleteEntity(shopNPC)
    end
    
    -- Create new NPCs
    Wait(500)
    TriggerEvent('vein-construction:client:setupNPCs')
end)

-- Process the NPC setup
RegisterNetEvent('vein-construction:client:setupNPCs', function()
    -- Create the job NPC if it doesn't exist yet
    if not DoesEntityExist(jobNPC) then
        CreateJobNPC()
    end
    
    -- Create shop NPC if it's not already created
    if Config.ShopNPC and not DoesEntityExist(shopNPC) then
        CreateShopNPC()
    end
end)

-- Function to draw 3D text
function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0+0.0125, 0.017+ factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

-- Create shop NPC
function CreateShopNPC()
    -- Check if NPC already exists
    if DoesEntityExist(shopNPC) then
        DeleteEntity(shopNPC)
    end
    
    -- Request the model
    local model = GetHashKey(Config.ShopNPC.model)
    RequestModel(model)
    
    while not HasModelLoaded(model) do
        Wait(1)
    end
    
    -- Create the ped
    shopNPC = CreatePed(4, model, Config.ShopNPC.coords.x, Config.ShopNPC.coords.y, Config.ShopNPC.coords.z - 1.0, Config.ShopNPC.heading, false, true)
    FreezeEntityPosition(shopNPC, true)
    SetEntityInvincible(shopNPC, true)
    SetBlockingOfNonTemporaryEvents(shopNPC, true)
    
    -- Set the ped into a scenario
    TaskStartScenarioInPlace(shopNPC, "WORLD_HUMAN_STAND_IMPATIENT", 0, true)
    
    -- Add target interactions
    if GetResourceState('ox_target') == 'started' then
        -- Use ox_target
        exports.ox_target:addLocalEntity(shopNPC, {
            {
                name = 'construction_shop',
                icon = 'fas fa-shopping-cart',
                label = 'Construction Shop',
                distance = 2.0,
                onSelect = function()
                    TriggerEvent('vein-construction:client:interactNPC', 'shop')
                end
            }
        })
    else
        -- Use qb-target
        exports['qb-target']:AddTargetEntity(shopNPC, {
            options = {
                {
                    type = "client",
                    event = "vein-construction:client:interactNPC",
                    icon = "fas fa-shopping-cart",
                    label = "Construction Shop",
                    job = "all",
                    action = 'shop'
                }
            },
            distance = 2.0
        })
    end
    
    print('Shop NPC created')
end 