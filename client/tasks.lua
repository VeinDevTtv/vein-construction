-- Task Variables
local isCarryingObject = false
local materialProps = {
    cement_bag = 'prop_cement_bag_01',
    bricks = 'prop_bricks_pile_01',
    wood_planks = 'prop_cons_plank'
}

-- Check if ox_lib is available
local hasOxLib = false
local lib = nil
local libInitialized = false

-- Check for ox_lib on resource start
Citizen.CreateThread(function()
    -- Wait a moment to ensure other resources are loaded
    Citizen.Wait(1000)
    
    -- Check if ox_lib is started
    if GetResourceState('ox_lib') == 'started' then
        hasOxLib = true
        lib = exports['ox_lib']
        
        -- Make sure the lib export is fully initialized
        local maxAttempts = 10
        local attempts = 0
        
        while attempts < maxAttempts do
            attempts = attempts + 1
            
            -- Check if we can access functions in the export
            if lib and type(lib) == 'table' and type(lib.registerContext) == 'function' then
                print('ox_lib fully initialized in Tasks module after', attempts, 'attempts')
                libInitialized = true
                break
            end
            
            print('Waiting for ox_lib to fully initialize in Tasks module... attempt', attempts)
            Citizen.Wait(500)
        end
        
        if not libInitialized then
            print('WARNING: ox_lib did not fully initialize in Tasks module after', maxAttempts, 'attempts')
        end
    end
    
    print('ox_lib detection status in Tasks module:')
    print('  - Resource detected:', hasOxLib)
    print('  - Fully initialized:', libInitialized)
end)

-- Function to safely use ox_lib
function SafelyUseOxLib(action, param)
    if not action then
        print('ERROR: No action provided to SafelyUseOxLib')
        return nil
    end
    
    -- Ensure param is a table if required for certain actions
    if action == 'registerContext' and not param then
        print('ERROR: registerContext requires a parameter table')
        return nil
    elseif action == 'registerContext' and type(param) ~= 'table' then
        print('ERROR: registerContext parameter must be a table, got', type(param))
        return nil
    elseif action == 'registerContext' and type(param.options) ~= 'table' then
        print('ERROR: registerContext options must be a table, got', type(param.options))
        return nil
    end
    
    if hasOxLib and lib and libInitialized then
        if action == 'hideContext' and type(lib.hideContext) == "function" then
            return lib.hideContext()
        elseif action == 'registerContext' and type(lib.registerContext) == "function" then
            -- Final safety check for options table
            if not param.options then param.options = {} end
            return lib.registerContext(param)
        elseif action == 'showContext' and type(lib.showContext) == "function" then
            return lib.showContext(param)
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

-- Helper function to check and add tool usage (durability)
function AddToolUsage(toolName)
    if not toolDurabilities[toolName] then
        toolDurabilities[toolName] = 0
    end
    
    toolDurabilities[toolName] = toolDurabilities[toolName] + 1
    local toolConfig = Config.ToolDurability[toolName]
    
    -- Check if tool should break
    if toolDurabilities[toolName] >= toolConfig.uses then
        -- Roll for tool breakage
        local breakChance = math.random(1, 100)
        if breakChance <= Config.RandomEvents.toolBreakage.chance then
            QBCore.Functions.Notify('Your ' .. toolName:gsub("_", " ") .. ' broke!', 'error')
            
            if Config.UseOxInventory then
                exports.ox_inventory:RemoveItem(toolName, 1)
            else
                TriggerServerEvent('QBCore:Server:RemoveItem', toolName, 1)
            end
            
            toolDurabilities[toolName] = 0
            return false
        end
    end
    
    return true
end

-- TASK 1: LIFTING MATERIALS
function StartLiftingTask()
    if not currentSite or not currentTask then return end
    
    local site = Config.Sites[currentSite]
    if not site.tasks.lifting or #site.tasks.lifting == 0 then return end
    
    -- Randomly select a lifting task location
    local taskIdx = math.random(1, #site.tasks.lifting)
    local task = site.tasks.lifting[taskIdx]
    
    -- Create task markers and blips
    local pickupBlip = AddBlipForCoord(task.pickup.x, task.pickup.y, task.pickup.z)
    SetBlipSprite(pickupBlip, 1)
    SetBlipColour(pickupBlip, 5)
    SetBlipRoute(pickupBlip, true)
    SetBlipRouteColour(pickupBlip, 5)
    
    -- Store blip in task object for cleanup
    currentTask.blip = pickupBlip
    currentTask.pickup = nil
    currentTask.pickupCoords = task.pickup
    currentTask.dropoffCoords = task.dropoff
    currentTask.completed = false
    
    -- Add target to pickup location
    if Config.UseOxTarget then
        local targetOptions = {
            {
                name = 'construction_pickup_material',
                icon = 'fas fa-weight-hanging',
                label = 'Pickup Material',
                distance = 3.0,
                onSelect = function()
                    PickupMaterial()
                end,
                canInteract = function()
                    return currentTask and currentTask.type == 'lifting' and not isCarryingObject
                end
            }
        }
        
        exports.ox_target:addSphereZone({
            coords = task.pickup,
            radius = 2.0,
            options = targetOptions
        })
    end
    
    QBCore.Functions.Notify('Go to the marked location and pick up materials', 'primary')
end

-- Pickup material
function PickupMaterial()
    if not currentTask or isCarryingObject then return end
    
    -- Check if player has required items
    if not Vein.HasRequiredItems(Config.RequiredItems.lifting) then
        QBCore.Functions.Notify('You need a work belt to lift heavy materials', 'error')
        return
    end
    
    -- Randomly select a material type
    local materials = {'cement_bag', 'bricks', 'wood_planks'}
    local materialType = materials[math.random(1, #materials)]
    
    -- Start carrying animation
    isCarryingObject = true
    
    if hasOxLib and lib and libInitialized then
        SafelyUseOxLib('progressBar', {
            duration = 3000,
            label = 'Picking up ' .. materialType:gsub("_", " ") .. '...',
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
            },
            anim = {
                dict = 'anim@heists@box_carry@',
                clip = 'idle'
            }
        })
    else
        -- Fallback to QBCore progress bar
        QBCore.Functions.Progressbar("pickup_material", 'Picking up ' .. materialType:gsub("_", " ") .. '...', 3000, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = 'anim@heists@box_carry@',
            anim = 'idle',
            flags = 49,
        }, {}, {}, function() -- Done
            -- Completed
        end, function() -- Cancel
            isCarryingObject = false
            ClearPedTasks(PlayerPedId())
        end)
    end
    
    -- Create prop and attach to player
    local playerPed = PlayerPedId()
    local modelHash = GetHashKey(materialProps[materialType])
    
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(1)
    end
    
    local prop = CreateObject(modelHash, 0, 0, 0, true, true, true)
    AttachEntityToEntity(prop, playerPed, GetPedBoneIndex(playerPed, 60309), 0.025, 0.08, 0.255, -145.0, 290.0, 0.0, true, true, false, true, 1, true)
    currentTask.pickup = prop
    
    -- Remove pickup blip and create dropoff blip
    if currentTask.blip and DoesBlipExist(currentTask.blip) then
        RemoveBlip(currentTask.blip)
    end
    
    local dropoffBlip = AddBlipForCoord(currentTask.dropoffCoords.x, currentTask.dropoffCoords.y, currentTask.dropoffCoords.z)
    SetBlipSprite(dropoffBlip, 1)
    SetBlipColour(dropoffBlip, 3)
    SetBlipRoute(dropoffBlip, true)
    SetBlipRouteColour(dropoffBlip, 3)
    currentTask.blip = dropoffBlip
    
    -- Add target to dropoff location
    if Config.UseOxTarget then
        local targetOptions = {
            {
                name = 'construction_dropoff_material',
                icon = 'fas fa-truck-loading',
                label = 'Drop Material',
                distance = 3.0,
                onSelect = function()
                    DropoffMaterial()
                end,
                canInteract = function()
                    return currentTask and currentTask.type == 'lifting' and isCarryingObject
                end
            }
        }
        
        exports.ox_target:addSphereZone({
            coords = currentTask.dropoffCoords,
            radius = 2.0,
            options = targetOptions
        })
    end
    
    QBCore.Functions.Notify('Carry the materials to the marked location', 'primary')
    
    -- Disable sprint and jumping while carrying
    Citizen.CreateThread(function()
        while isCarryingObject do
            DisableControlAction(0, 21, true) -- disable sprint
            DisableControlAction(0, 22, true) -- disable jump
            Wait(0)
        end
    end)
end

-- Dropoff material
function DropoffMaterial()
    if not currentTask or not isCarryingObject then return end
    
    -- Stop carrying animation
    isCarryingObject = false
    ClearPedTasks(PlayerPedId())
    
    -- Delete the prop
    if currentTask.pickup and DoesEntityExist(currentTask.pickup) then
        DeleteEntity(currentTask.pickup)
        currentTask.pickup = nil
    end
    
    -- Complete task
    if hasOxLib and lib and libInitialized then
        SafelyUseOxLib('progressBar', {
            duration = 2000,
            label = 'Placing materials...',
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true
            },
            anim = {
                dict = 'random@domestic',
                clip = 'pickup_low'
            }
        })
    else
        -- Fallback to QBCore progress bar
        QBCore.Functions.Progressbar("dropoff_material", 'Placing materials...', 2000, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = 'random@domestic',
            anim = 'pickup_low',
            flags = 49,
        }, {}, {}, function() -- Done
            -- Completed
        end, function() -- Cancel
            isCarryingObject = false
            ClearPedTasks(PlayerPedId())
        end)
    end
    
    -- Complete task and reward player
    CompleteTask()
end

-- TASK 2: HAMMERING
function StartHammeringTask()
    if not currentSite or not currentTask then return end
    
    local site = Config.Sites[currentSite]
    if not site.tasks.hammering or #site.tasks.hammering == 0 then return end
    
    -- Randomly select a hammering task location
    local taskIdx = math.random(1, #site.tasks.hammering)
    local task = site.tasks.hammering[taskIdx]
    
    -- Create task markers and blips
    local hammerBlip = AddBlipForCoord(task.coords.x, task.coords.y, task.coords.z)
    SetBlipSprite(hammerBlip, 1)
    SetBlipColour(hammerBlip, 5)
    SetBlipRoute(hammerBlip, true)
    SetBlipRouteColour(hammerBlip, 5)
    
    -- Store blip in task object for cleanup
    currentTask.blip = hammerBlip
    currentTask.coords = task.coords
    currentTask.completed = false
    
    -- Add target to hammering location
    if Config.UseOxTarget then
        local targetOptions = {
            {
                name = 'construction_hammer_task',
                icon = 'fas fa-hammer',
                label = 'Start Hammering',
                distance = 3.0,
                onSelect = function()
                    PerformHammeringTask()
                end,
                canInteract = function()
                    return currentTask and currentTask.type == 'hammering'
                end
            }
        }
        
        exports.ox_target:addSphereZone({
            coords = task.coords,
            radius = 2.0,
            options = targetOptions
        })
    end
    
    QBCore.Functions.Notify('Go to the marked location to start hammering', 'primary')
end

-- Perform hammering task
function PerformHammeringTask()
    if not currentTask then return end
    
    -- Check if player has required items
    if not Vein.HasRequiredItems(Config.RequiredItems.hammering) then
        QBCore.Functions.Notify('You need a hammer and nails', 'error')
        return
    end
    
    -- Check tool durability
    if not AddToolUsage('hammer') then
        CancelCurrentTask()
        return
    end
    
    -- Start hammering animation and progressbar
    if hasOxLib and lib and libInitialized then
        SafelyUseOxLib('progressBar', {
            duration = 10000,
            label = 'Hammering...',
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true
            },
            anim = {
                dict = 'amb@world_human_hammering@male@base',
                clip = 'base'
            },
            prop = {
                model = 'prop_tool_hammer',
                bone = 28422,
                pos = vec3(0.0, 0.0, 0.0),
                rot = vec3(0.0, 0.0, 0.0)
            }
        })
    else
        -- Fallback to QBCore progress bar
        QBCore.Functions.Progressbar("hammering", 'Hammering...', 10000, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = 'amb@world_human_hammering@male@base',
            anim = 'base',
            flags = 49,
        }, {
            model = 'prop_tool_hammer',
            bone = 28422
        }, {}, function() -- Done
            -- Completed
        end, function() -- Cancel
            ClearPedTasks(PlayerPedId())
        end)
    end
    
    -- Play hammer sound
    PlaySoundFrontend(-1, "Drill_Pin_Break", "DLC_HEIST_FLEECA_SOUNDSET", 1)
    
    -- Complete task and reward player
    CompleteTask()
end

-- TASK 3: DRILLING
function StartDrillingTask()
    if not currentSite or not currentTask then return end
    
    local site = Config.Sites[currentSite]
    if not site.tasks.drilling or #site.tasks.drilling == 0 then return end
    
    -- Randomly select a drilling task location
    local taskIdx = math.random(1, #site.tasks.drilling)
    local task = site.tasks.drilling[taskIdx]
    
    -- Create task markers and blips
    local drillBlip = AddBlipForCoord(task.coords.x, task.coords.y, task.coords.z)
    SetBlipSprite(drillBlip, 1)
    SetBlipColour(drillBlip, 5)
    SetBlipRoute(drillBlip, true)
    SetBlipRouteColour(drillBlip, 5)
    
    -- Store blip in task object for cleanup
    currentTask.blip = drillBlip
    currentTask.coords = task.coords
    currentTask.completed = false
    
    -- Add target to drilling location
    if Config.UseOxTarget then
        local targetOptions = {
            {
                name = 'construction_drill_task',
                icon = 'fas fa-cog',
                label = 'Start Drilling',
                distance = 3.0,
                onSelect = function()
                    PerformDrillingTask()
                end,
                canInteract = function()
                    return currentTask and currentTask.type == 'drilling'
                end
            }
        }
        
        exports.ox_target:addSphereZone({
            coords = task.coords,
            radius = 2.0,
            options = targetOptions
        })
    end
    
    QBCore.Functions.Notify('Go to the marked location to start drilling', 'primary')
end

-- Perform drilling task
function PerformDrillingTask()
    if not currentTask then return end
    
    -- Check if player has required items
    if not Vein.HasRequiredItems(Config.RequiredItems.drilling) then
        QBCore.Functions.Notify('You need a drill and screws', 'error')
        return
    end
    
    -- Check tool durability
    if not AddToolUsage('drill') then
        CancelCurrentTask()
        return
    end
    
    -- Start drilling animation and progressbar
    if hasOxLib and lib and libInitialized then
        SafelyUseOxLib('progressBar', {
            duration = 8000,
            label = 'Drilling...',
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true
            },
            anim = {
                dict = 'anim@heists@fleeca_bank@drilling',
                clip = 'drill_straight_idle'
            },
            prop = {
                model = 'prop_tool_drill',
                bone = 57005,
                pos = vec3(0.14, 0.0, -0.01),
                rot = vec3(90.0, -90.0, 180.0)
            }
        })
    else
        -- Fallback to QBCore progress bar
        QBCore.Functions.Progressbar("drilling", 'Drilling...', 8000, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = 'anim@heists@fleeca_bank@drilling',
            anim = 'drill_straight_idle',
            flags = 49,
        }, {
            model = 'prop_tool_drill',
            bone = 57005
        }, {}, function() -- Done
            -- Completed
        end, function() -- Cancel
            ClearPedTasks(PlayerPedId())
        end)
    end
    
    -- Play drill sound
    PlaySoundFrontend(-1, "Drill_Pin_Break", "DLC_HEIST_FLEECA_SOUNDSET", 1)
    
    -- Complete task and reward player
    CompleteTask()
end

-- TASK 4: WELDING
function StartWeldingTask()
    if not currentSite or not currentTask then return end
    
    local site = Config.Sites[currentSite]
    if not site.tasks.welding or #site.tasks.welding == 0 then return end
    
    -- Randomly select a welding task location
    local taskIdx = math.random(1, #site.tasks.welding)
    local task = site.tasks.welding[taskIdx]
    
    -- Create task markers and blips
    local weldBlip = AddBlipForCoord(task.coords.x, task.coords.y, task.coords.z)
    SetBlipSprite(weldBlip, 1)
    SetBlipColour(weldBlip, 5)
    SetBlipRoute(weldBlip, true)
    SetBlipRouteColour(weldBlip, 5)
    
    -- Store blip in task object for cleanup
    currentTask.blip = weldBlip
    currentTask.coords = task.coords
    currentTask.completed = false
    
    -- Add target to welding location
    if Config.UseOxTarget then
        local targetOptions = {
            {
                name = 'construction_weld_task',
                icon = 'fas fa-fire',
                label = 'Start Welding',
                distance = 3.0,
                onSelect = function()
                    PerformWeldingTask()
                end,
                canInteract = function()
                    return currentTask and currentTask.type == 'welding'
                end
            }
        }
        
        exports.ox_target:addSphereZone({
            coords = task.coords,
            radius = 2.0,
            options = targetOptions
        })
    end
    
    QBCore.Functions.Notify('Go to the marked location to start welding', 'primary')
end

-- Perform welding task
function PerformWeldingTask()
    if not currentTask then return end
    
    -- Check if player has required items
    if not Vein.HasRequiredItems(Config.RequiredItems.welding) then
        QBCore.Functions.Notify('You need a welding torch, welding mask, and metal rods', 'error')
        return
    end
    
    -- Check tool durability
    if not AddToolUsage('welding_torch') then
        CancelCurrentTask()
        return
    end
    
    -- Check if player is wearing welding mask
    local hasWeldingMask = false
    if Config.UseOxInventory then
        hasWeldingMask = exports.ox_inventory:GetItemCount('welding_mask') > 0
    else
        hasWeldingMask = QBCore.Functions.HasItem('welding_mask')
    end
    
    -- Start welding animation and progressbar
    if hasOxLib and lib and libInitialized then
        SafelyUseOxLib('progressBar', {
            duration = 12000,
            label = 'Welding...',
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true
            },
            anim = {
                dict = 'amb@world_human_welding@male@base',
                clip = 'base'
            },
            prop = {
                model = 'prop_weld_torch',
                bone = 28422,
                pos = vec3(0.0, 0.0, 0.0),
                rot = vec3(0.0, 0.0, 0.0)
            }
        })
    else
        -- Fallback to QBCore progress bar
        QBCore.Functions.Progressbar("welding", 'Welding...', 12000, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = 'amb@world_human_welding@male@base',
            anim = 'base',
            flags = 49,
        }, {
            model = 'prop_weld_torch',
            bone = 28422
        }, {}, function() -- Done
            -- Completed
        end, function() -- Cancel
            ClearPedTasks(PlayerPedId())
        end)
    end
    
    -- Add particle effects for welding
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    
    RequestNamedPtfxAsset("core")
    while not HasNamedPtfxAssetLoaded("core") do
        Wait(0)
    end
    
    UseParticleFxAssetNextCall("core")
    local particleEffect = StartParticleFxLoopedAtCoord("ent_amb_welding", 
        coords.x, coords.y, coords.z, 
        0.0, 0.0, 0.0, 
        1.0, false, false, false, false)
    
    -- Wait for welding to finish
    Wait(12000)
    
    -- Stop particle effect
    StopParticleFxLooped(particleEffect, 0)
    
    -- Risk eye damage if not wearing welding mask
    if not hasWeldingMask then
        QBCore.Functions.Notify('Your eyes hurt from welding without a mask!', 'error')
        -- Add blurred vision effect
        SetTimecycleModifier("damage")
        SetTimecycleModifierStrength(0.8)
        
        -- Clear effect after 30 seconds
        Citizen.SetTimeout(30000, function()
            ClearTimecycleModifier()
        end)
    end
    
    -- Random chance for explosion when welding
    local explosionChance = math.random(1, 100)
    if explosionChance <= Config.RandomEvents.weldingExplosion.chance then
        -- Create small explosion
        AddExplosion(coords.x, coords.y, coords.z, 'EXPLOSION_TANKER', 0.5, true, false, 1.0)
        
        -- Apply damage to player
        local health = GetEntityHealth(playerPed)
        SetEntityHealth(playerPed, health - Config.RandomEvents.weldingExplosion.damage)
        
        QBCore.Functions.Notify('The welding caused a gas line to explode!', 'error')
    end
    
    -- Complete task and reward player
    CompleteTask()
end

-- TASK 5: ROADWORK
function StartRoadworkTask()
    if not currentSite or not currentTask then return end
    
    local site = Config.Sites[currentSite]
    if not site.tasks.roadwork or #site.tasks.roadwork == 0 then return end
    
    -- Randomly select a roadwork task location
    local taskIdx = math.random(1, #site.tasks.roadwork)
    local task = site.tasks.roadwork[taskIdx]
    
    -- Create task markers and blips
    local roadworkBlip = AddBlipForCoord(task.coords.x, task.coords.y, task.coords.z)
    SetBlipSprite(roadworkBlip, 1)
    SetBlipColour(roadworkBlip, 5)
    SetBlipRoute(roadworkBlip, true)
    SetBlipRouteColour(roadworkBlip, 5)
    
    -- Store blip in task object for cleanup
    currentTask.blip = roadworkBlip
    currentTask.coords = task.coords
    currentTask.completed = false
    currentTask.roadworkStage = 1 -- 1: Digging, 2: Filling, 3: Painting
    
    -- Add target to roadwork location
    if Config.UseOxTarget then
        local targetOptions = {
            {
                name = 'construction_roadwork_task',
                icon = 'fas fa-road',
                label = 'Start Roadwork',
                distance = 3.0,
                onSelect = function()
                    PerformRoadworkTask()
                end,
                canInteract = function()
                    return currentTask and currentTask.type == 'roadwork'
                end
            }
        }
        
        exports.ox_target:addSphereZone({
            coords = task.coords,
            radius = 2.0,
            options = targetOptions
        })
    end
    
    QBCore.Functions.Notify('Go to the marked location to start roadwork', 'primary')
end

-- Perform roadwork task
function PerformRoadworkTask()
    if not currentTask then return end
    
    -- Check if player has required items
    if not Vein.HasRequiredItems(Config.RequiredItems.roadwork) then
        QBCore.Functions.Notify('You need a shovel, asphalt bucket, and paint roller', 'error')
        return
    end
    
    -- Different stages of roadwork
    if currentTask.roadworkStage == 1 then
        -- Stage 1: Digging with shovel
        
        -- Check tool durability
        if not AddToolUsage('shovel') then
            CancelCurrentTask()
            return
        end
        
        lib.progressBar({
            duration = 8000,
            label = 'Digging road...',
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true
            },
            anim = {
                dict = 'amb@world_human_gardener_plant@male@base',
                clip = 'base'
            },
            prop = {
                model = 'prop_tool_shovel',
                bone = 28422,
                pos = vec3(0.0, 0.0, 0.0),
                rot = vec3(0.0, 0.0, 0.0)
            }
        })
        
        currentTask.roadworkStage = 2
        QBCore.Functions.Notify('Now fill the hole with asphalt', 'primary')
        
    elseif currentTask.roadworkStage == 2 then
        -- Stage 2: Filling with asphalt
        
        lib.progressBar({
            duration = 6000,
            label = 'Filling with asphalt...',
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true
            },
            anim = {
                dict = 'amb@world_human_bum_wash@male@low@idle_a',
                clip = 'idle_a'
            }
        })
        
        currentTask.roadworkStage = 3
        QBCore.Functions.Notify('Now paint the road markings', 'primary')
        
    elseif currentTask.roadworkStage == 3 then
        -- Stage 3: Painting road markings
        
        -- Check tool durability
        if not AddToolUsage('paint_roller') then
            CancelCurrentTask()
            return
        end
        
        lib.progressBar({
            duration = 5000,
            label = 'Painting road markings...',
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true
            },
            anim = {
                dict = 'missfbi4prepp1',
                clip = '_bag_throw_garbage_man'
            },
            prop = {
                model = 'prop_paint_roller',
                bone = 28422,
                pos = vec3(0.0, 0.0, 0.0),
                rot = vec3(0.0, 0.0, 0.0)
            }
        })
        
        -- Complete the roadwork task
        CompleteTask()
    end
end

-- Complete any task and give rewards
function CompleteTask()
    if not currentTask then return end
    
    -- Remove task blip
    if currentTask.blip and DoesBlipExist(currentTask.blip) then
        RemoveBlip(currentTask.blip)
        currentTask.blip = nil
    end
    
    -- Get task XP
    local taskXP = Config.TaskXP[currentTask.type] or 5
    
    -- Trigger server event for rewards
    TriggerServerEvent('vein-construction:server:completeTask', currentTask.type, taskXP)
    
    -- Reset current task
    currentTask = nil
    
    -- Notify player
    QBCore.Functions.Notify('Task completed! You earned XP and payment', 'success')
end