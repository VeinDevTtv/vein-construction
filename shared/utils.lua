-- Shared utility functions for the construction job
-- Can be required by both client and server files

local Vein = {}

-- Check if player has all required items for a task
Vein.HasRequiredItems = function(player, items)
    if not items then return true end
    
    for _, item in ipairs(items) do
        if not Vein.HasItem(player, item) then
            return false
        end
    end
    
    return true
end

-- Check if player has all safety gear
Vein.HasSafetyGear = function(player)
    for _, item in ipairs(Config.SafetyGear) do
        if not Vein.HasItem(player, item) then
            return false
        end
    end
    
    return true
end

-- Check if player has a specific item
Vein.HasItem = function(player, item)
    if Config.UseOxInventory then
        -- Use ox_inventory to check for item
        if client then
            return exports.ox_inventory:GetItemCount(item) > 0
        else
            return exports.ox_inventory:GetItemCount(player.source, item) > 0
        end
    else
        -- Use QB-Core to check for item
        if client then
            local hasItem = QBCore.Functions.HasItem(item)
            return hasItem
        else
            local hasItem = player.Functions.GetItemByName(item)
            return hasItem ~= nil
        end
    end
end

-- Get formatted rank name from raw rank name
Vein.GetFormattedRankName = function(rankName)
    for _, rank in ipairs(Config.Ranks) do
        if rank.name == rankName then
            return rank.label
        end
    end
    
    return "Unknown Rank"
end

-- Check if a player rank meets minimum requirement for a task
Vein.MeetsRankRequirement = function(playerRank, taskType)
    if taskType == "lifting" or taskType == "hammering" then
        -- All ranks can do basic tasks
        return true
    elseif taskType == "drilling" or taskType == "welding" or taskType == "roadwork" then
        -- Need to be at least Skilled Worker (index 2 or higher)
        for i, rank in ipairs(Config.Ranks) do
            if rank.name == playerRank and i >= 2 then
                return true
            end
        end
    end
    
    return false
end

-- Check if a rank is management (Foreman or Site Manager)
Vein.IsManagementRank = function(rankName)
    return rankName == "foreman" or rankName == "site_manager"
end

-- Calculate payment based on rank and random factor
Vein.CalculatePayment = function(rankName, bonus)
    bonus = bonus or 0
    
    for _, rank in ipairs(Config.Ranks) do
        if rank.name == rankName then
            local basePayment = math.random(rank.payment.min, rank.payment.max)
            return math.floor(basePayment * (1 + bonus))
        end
    end
    
    return 0
end

-- Calculate commission for management ranks
Vein.CalculateCommission = function(rankName, payment)
    for _, rank in ipairs(Config.Ranks) do
        if rank.name == rankName and rank.commission then
            return math.floor(payment * rank.commission)
        end
    end
    
    return 0
end

-- Find nearest construction site
Vein.GetNearestSite = function(coords)
    local nearestDist = -1
    local nearestSite = nil
    
    for _, site in ipairs(Config.Sites) do
        local dist = #(coords - site.coords)
        if nearestDist == -1 or dist < nearestDist then
            nearestDist = dist
            nearestSite = site
        end
    end
    
    return nearestSite, nearestDist
end

-- Register export to be used globally
exports('GetSharedObject', function()
    return Vein
end)

return Vein 