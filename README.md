# Vein Construction Job for FiveM

A comprehensive construction job script for FiveM servers using QBCore, with ox_inventory and ox_target integration.

![Construction Job Banner](https://i.imgur.com/placeholder.png)

## Features

### Job System & Progression
- Apply for the job at a construction site HQ
- Four ranks with progression based on XP:
  - **Apprentice**: Basic lifting & hammering jobs
  - **Skilled Worker**: Unlocks welding & roadwork tasks
  - **Foreman**: Assigns jobs to other workers, earns commissions
  - **Site Manager**: Can start large projects & hire/fire workers
- Players earn XP per completed task, leading to promotions

### Construction Tasks
- **Lifting Materials**: Pick up cement bags, bricks, or wood planks and carry them to a marked area
- **Hammering & Drilling**: Use a hammer or drill to secure beams or construct walls
- **Welding Metal Beams**: Use a welding torch to fuse metal beams together (with heat effects and sparks)
- **Roadwork**: Fix potholes and mark road lanes

### Random Events & Realism Features
- **Tool Durability**: Tools break after 5-10 uses, requiring repairs
- **Safety Inspections**: OSHA-style random checks with fines if not wearing proper gear
- **Explosions**: Risk of explosions when welding near gas lines
- **Eye Damage**: Blurred vision effect if welding without a mask

### Payment & XP System
- Payment varies based on rank ($500-$2,500)
- XP system for rank progression:
  - Apprentice: 0-100 XP
  - Skilled Worker: 100-300 XP
  - Foreman: 300-700 XP
  - Site Manager: 700+ XP
- Foremen and Site Managers earn commissions from subordinates' work

### Integration with ox_inventory & ox_target
- Job interactions use ox_target for a smooth experience
- Tools & safety gear stored in ox_inventory
- Job start/quit NPC uses ox_target
- Players can't start work without proper gear (helmet, gloves, vest)

## Dependencies
- [qb-core](https://github.com/qbcore-framework/qb-core)
- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_inventory](https://github.com/overextended/ox_inventory)
- [ox_target](https://github.com/overextended/ox_target)

## Installation

1. **Download the Resource**
   - Download the latest release or clone the repository

2. **Install Dependencies**
   - Ensure you have all dependencies installed and configured properly

3. **Database Setup**
   - Run the included `vein-construction.sql` script in your database

4. **Resource Installation**
   - Place the `vein-construction` folder in your server's resources directory
   - Add `ensure vein-construction` to your server.cfg

5. **Item Setup**
   - Add the items to your ox_inventory items.lua file or to your qb-core/shared/items.lua file
   - The items needed are listed in the config.lua file

6. **Configuration**
   - Configure the locations and other settings in the config.lua file
   - Adjust payment rates and XP values if needed

## Configuration

You can modify various aspects of the resource in the `config.lua` file:

- Construction site locations and task points
- XP requirements for different ranks
- Payment rates for different ranks
- Tool durability settings
- Required items for different tasks
- Safety gear requirements
- Random event chances and effects

## Commands

- `/constructiondata [id]` - Check construction job data (Admin only)
- `/addconstructionxp [id] [amount]` - Add XP to a player (Admin only)
- `/setconstructionrank [id] [rank]` - Set player's rank (Admin only)

## Development

This resource was developed by Vein. Feel free to submit issues or pull requests on our GitHub repository.

## License

This resource is released under the [MIT License](LICENSE).

## Credits

- Vein - For development and design
- QBCore - For the framework
- Overextended - For ox_inventory and ox_target
- The FiveM community - For support and inspiration 