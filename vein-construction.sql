-- Create construction_data table
CREATE TABLE IF NOT EXISTS `construction_data` (
    `citizenid` varchar(50) NOT NULL,
    `xp` int(11) NOT NULL DEFAULT 0,
    PRIMARY KEY (`citizenid`)
);

-- Create construction_projects table
CREATE TABLE IF NOT EXISTS `construction_projects` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `name` varchar(100) NOT NULL,
    `type` varchar(50) NOT NULL,
    `budget` int(11) NOT NULL DEFAULT 0,
    `progress` int(11) NOT NULL DEFAULT 0,
    `manager` varchar(50) NOT NULL,
    `location_x` float NOT NULL,
    `location_y` float NOT NULL,
    `location_z` float NOT NULL,
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
);

-- Create construction_assignments table
CREATE TABLE IF NOT EXISTS `construction_assignments` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `worker_id` varchar(50) NOT NULL,
    `task_type` varchar(50) NOT NULL,
    `site_index` int(11) NOT NULL,
    `assigner_id` varchar(50) NOT NULL,
    `status` varchar(20) NOT NULL DEFAULT 'assigned',
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
); 