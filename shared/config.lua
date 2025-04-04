Config = {}

-- General settings
Config.Debug = false -- Set to true for debug prints
Config.UseOxTarget = true -- Set to false to use qb-target instead
Config.UseOxInventory = true -- Set to false to use qb-inventory instead

-- Job settings
Config.JobName = 'construction'

-- Job ranks and their requirements
Config.Ranks = {
    {
        name = 'apprentice',
        label = 'Apprentice',
        xpNeeded = 0, -- Starting rank
        payment = {
            min = 500,
            max = 800
        }
    },
    {
        name = 'skilled_worker',
        label = 'Skilled Worker',
        xpNeeded = 100,
        payment = {
            min = 800,
            max = 1200
        }
    },
    {
        name = 'foreman',
        label = 'Foreman',
        xpNeeded = 300,
        payment = {
            min = 1200,
            max = 1800
        },
        commission = 0.05 -- 5% commission on subordinates' work
    },
    {
        name = 'site_manager',
        label = 'Site Manager',
        xpNeeded = 700,
        payment = {
            min = 1800,
            max = 2500
        },
        commission = 0.1 -- 10% commission on subordinates' work
    }
}

-- XP gained per task
Config.TaskXP = {
    lifting = 5,
    hammering = 8,
    drilling = 10,
    welding = 15,
    roadwork = 12
}

-- Tool durability (uses before breaking)
Config.ToolDurability = {
    hammer = {
        uses = 10,
        repairCost = 50
    },
    drill = {
        uses = 8,
        repairCost = 100
    },
    welding_torch = {
        uses = 5,
        repairCost = 150
    },
    shovel = {
        uses = 12,
        repairCost = 75
    },
    paint_roller = {
        uses = 15,
        repairCost = 40
    }
}

-- Required items for different tasks
Config.RequiredItems = {
    lifting = {
        'work_belt'
    },
    hammering = {
        'hammer',
        'nails'
    },
    drilling = {
        'drill',
        'screws'
    },
    welding = {
        'welding_torch',
        'welding_mask',
        'metal_rods'
    },
    roadwork = {
        'shovel',
        'asphalt_bucket',
        'paint_roller'
    }
}

-- Safety gear requirements
Config.SafetyGear = {
    'construction_helmet',
    'safety_vest',
    'work_gloves'
}

-- HQ location
Config.HQ = {
    coords = vector3(110.1, -365.9, 42.4), -- Replace with actual location
    radius = 20.0,
    blip = {
        sprite = 566,
        color = 47,
        scale = 0.8,
        label = 'Construction HQ'
    }
}

-- Construction sites and their task locations
Config.Sites = {
    {
        name = 'downtown_site',
        label = 'Downtown Construction Site',
        coords = vector3(150.1, -300.3, 43.2), -- Replace with actual location
        blip = {
            sprite = 566,
            color = 47,
            scale = 0.6,
            label = 'Construction Site'
        },
        tasks = {
            lifting = {
                {
                    pickup = vector3(145.3, -302.7, 43.2),
                    dropoff = vector3(156.8, -298.4, 43.2)
                },
                {
                    pickup = vector3(140.1, -305.6, 43.2),
                    dropoff = vector3(152.4, -295.2, 43.2)
                }
            },
            hammering = {
                {coords = vector3(148.7, -290.5, 43.2)},
                {coords = vector3(153.6, -286.2, 43.2)}
            },
            drilling = {
                {coords = vector3(160.3, -293.8, 43.2)},
                {coords = vector3(165.2, -290.6, 43.2)}
            },
            welding = {
                {coords = vector3(155.9, -302.1, 43.2)},
                {coords = vector3(162.7, -304.9, 43.2)}
            },
            roadwork = {
                {coords = vector3(140.8, -315.4, 43.2)},
                {coords = vector3(147.6, -318.2, 43.2)}
            }
        }
    },
    {
        name = 'vinewood_site',
        label = 'Vinewood Construction Site',
        coords = vector3(200.5, 200.1, 105.7), -- Replace with actual location
        blip = {
            sprite = 566,
            color = 47,
            scale = 0.6,
            label = 'Construction Site'
        },
        tasks = {
            lifting = {
                {
                    pickup = vector3(195.3, 197.8, 105.7),
                    dropoff = vector3(205.9, 202.3, 105.7)
                }
            },
            hammering = {
                {coords = vector3(198.7, 206.2, 105.7)}
            },
            drilling = {
                {coords = vector3(204.2, 195.6, 105.7)}
            },
            welding = {
                {coords = vector3(210.5, 201.1, 105.7)}
            },
            roadwork = {
                {coords = vector3(190.8, 210.5, 105.7)}
            }
        }
    }
}

-- Random events
Config.RandomEvents = {
    safetyInspection = {
        chance = 15, -- 15% chance per hour
        fine = 500  -- Fine for not wearing proper safety gear
    },
    weldingExplosion = {
        chance = 10, -- 10% chance when welding in risky areas
        damage = 20  -- Health damage caused by explosion
    },
    toolBreakage = {
        chance = 20  -- 20% chance of tool breaking during use
    }
}

-- NPC job giver
Config.JobNPC = {
    model = 's_m_y_construct_01',
    coords = vector4(111.2, -366.3, 41.4, 75.2), -- Replace with actual location
    scenario = 'WORLD_HUMAN_CLIPBOARD'
}

-- Items to add to qb-core/shared/items.lua
Config.Items = {
    -- Tools
    hammer = {
        name = 'hammer',
        label = 'Hammer',
        weight = 1500,
        type = 'item',
        image = 'hammer.png',
        unique = true,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'A hammer for construction work'
    },
    drill = {
        name = 'drill',
        label = 'Power Drill',
        weight = 2000,
        type = 'item',
        image = 'drill.png',
        unique = true,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'A power drill for construction work'
    },
    welding_torch = {
        name = 'welding_torch',
        label = 'Welding Torch',
        weight = 3000,
        type = 'item',
        image = 'welding_torch.png',
        unique = true,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'A welding torch for metal work'
    },
    shovel = {
        name = 'shovel',
        label = 'Shovel',
        weight = 2500,
        type = 'item',
        image = 'shovel.png',
        unique = true,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'A shovel for digging'
    },
    paint_roller = {
        name = 'paint_roller',
        label = 'Paint Roller',
        weight = 1000,
        type = 'item',
        image = 'paint_roller.png',
        unique = true,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'A paint roller for road markings'
    },
    
    -- Materials
    nails = {
        name = 'nails',
        label = 'Box of Nails',
        weight = 500,
        type = 'item',
        image = 'nails.png',
        unique = false,
        useable = false,
        shouldClose = false,
        combinable = nil,
        description = 'A box full of nails'
    },
    screws = {
        name = 'screws',
        label = 'Box of Screws',
        weight = 500,
        type = 'item',
        image = 'screws.png',
        unique = false,
        useable = false,
        shouldClose = false,
        combinable = nil,
        description = 'A box full of screws'
    },
    metal_rods = {
        name = 'metal_rods',
        label = 'Metal Rods',
        weight = 2000,
        type = 'item',
        image = 'metal_rods.png',
        unique = false,
        useable = false,
        shouldClose = false,
        combinable = nil,
        description = 'Metal rods for welding'
    },
    asphalt_bucket = {
        name = 'asphalt_bucket',
        label = 'Asphalt Bucket',
        weight = 3000,
        type = 'item',
        image = 'asphalt_bucket.png',
        unique = false,
        useable = false,
        shouldClose = false,
        combinable = nil,
        description = 'A bucket of asphalt for road repairs'
    },
    
    -- Safety gear
    construction_helmet = {
        name = 'construction_helmet',
        label = 'Construction Helmet',
        weight = 1000,
        type = 'item',
        image = 'construction_helmet.png',
        unique = true,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'A hard hat for protection'
    },
    safety_vest = {
        name = 'safety_vest',
        label = 'Safety Vest',
        weight = 500,
        type = 'item',
        image = 'safety_vest.png',
        unique = true,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'A high-visibility vest'
    },
    work_gloves = {
        name = 'work_gloves',
        label = 'Work Gloves',
        weight = 300,
        type = 'item',
        image = 'work_gloves.png',
        unique = true,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'Gloves for hand protection'
    },
    welding_mask = {
        name = 'welding_mask',
        label = 'Welding Mask',
        weight = 1000,
        type = 'item',
        image = 'welding_mask.png',
        unique = true,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'A mask to protect your eyes while welding'
    },
    work_belt = {
        name = 'work_belt',
        label = 'Work Belt',
        weight = 1000,
        type = 'item',
        image = 'work_belt.png',
        unique = true,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'A belt for carrying heavy materials'
    }
} 