-- Initialize QBCore
QBCore = exports['qb-core']:GetCoreObject()

-- Utility functions that will be used by both client and server
Vein = {}

-- Helper function to check if player has all required items
Vein.HasRequiredItems = function(items)
    if Config.UseOxInventory then
        for _, item in ipairs(items) do
            if exports.ox_inventory:GetItemCount(item) <= 0 then
                return false
            end
        end
        return true
    else
        local hasItems = true
        for _, item in ipairs(items) do
            local qbItem = QBCore.Functions.HasItem(item)
            if not qbItem then
                hasItems = false
                break
            end
        end
        return hasItems
    end
end

-- Helper function to check if player has all required safety gear
Vein.HasSafetyGear = function()
    return Vein.HasRequiredItems(Config.SafetyGear)
end

-- Get job rank by XP value
Vein.GetRankByXP = function(xp)
    local highestRankIndex = 1
    for i, rank in ipairs(Config.Ranks) do
        if xp >= rank.xpNeeded then
            highestRankIndex = i
        else
            break
        end
    end
    return Config.Ranks[highestRankIndex]
end

-- Debug print function
Vein.Debug = function(message)
    if Config.Debug then
        if type(message) == "table" then
            print(json.encode(message, {indent = true}))
        else
            print("[VEIN-CONSTRUCTION] " .. tostring(message))
        end
    end
end

-- Format currency
Vein.FormatMoney = function(amount)
    local formatted = math.floor(amount)
    return "$" .. formatted
end

-- Calculate random amount between min and max
Vein.RandomAmount = function(min, max)
    return math.random(min, max)
end

-- Get job payment based on rank
Vein.GetPaymentForRank = function(rankName)
    for _, rank in ipairs(Config.Ranks) do
        if rank.name == rankName then
            return Vein.RandomAmount(rank.payment.min, rank.payment.max)
        end
    end
    return Config.Ranks[1].payment.min -- Default to apprentice pay if rank not found
end 