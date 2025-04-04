# Vein Construction Job

A comprehensive construction job for FiveM QBCore servers. This resource provides a fully-featured construction job with rank progression, tool management, project assignments, and more.

## Features

- **Job Management**: Apply for the job, clock in/out, and manage your career
- **Rank Progression**: Advance through multiple ranks (Apprentice, Skilled Worker, Foreman, Site Manager)
- **Tool System**: Purchase, use, and repair tools with durability system
- **Safety Requirements**: OSHA-compliant safety gear requirements
- **Project Management**: Assign workers, track progress, and complete projects
- **Modern UI**: Clean and intuitive UI for all interactions
- **Dynamic Tasks**: Different tasks based on rank and location
- **Random Events**: OSHA inspections, tool breakage, safety violations

## Dependencies

- QBCore Framework
- oxmysql
- ox_lib (optional but recommended)

## Installation

1. **Copy the Resource**: 
   - Place the `vein-construction` folder in your server's resources directory

2. **Import Database Tables**:
   - Import the `vein-construction.sql` file into your database

3. **Add Items to QBCore Shared**:
   - Copy items from `shared/construction_items.lua` to your `qb-core/shared/items.lua` file

4. **Ensure the Resource**:
   - Add `ensure vein-construction` to your server.cfg

5. **Configure the Resource** (Optional):
   - Edit settings in `shared/config.lua` to match your server's economy and preferences

## Usage

### For Players

1. **Apply for the Job**:
   - Visit the Construction HQ (location configurable in config.lua)
   - Use the job menu to apply

2. **Clock In/Out**:
   - You'll need to purchase and wear safety equipment (helmet, vest, gloves)
   - Use the job menu at the HQ to clock in/out

3. **Purchase Equipment**:
   - Visit the construction shop to buy tools and safety gear
   - Different ranks require different tools

4. **Complete Tasks**:
   - Tasks are assigned based on your rank
   - Higher ranks get more complex and better-paying tasks

5. **Advance Ranks**:
   - Gain XP by completing tasks
   - Automatic promotion when you reach XP thresholds

### For Admins

Admin commands for testing and management:

- `/addconstructionxp [amount]` - Add XP to a player
- `/setconstructionrank [rank]` - Set a player's rank
- `/refreshconstructionsites` - Refresh construction site locations
- `/addconstructionproject [name] [type] [budget]` - Create a new project

## Configuration

The main configuration file is located at `shared/config.lua` and includes options for:

- Job locations and blips
- Rank requirements and benefits
- Task rewards and XP
- Tool durability settings
- Safety gear requirements
- Shop item prices

## Adding Custom Tasks

1. Open `client/tasks.lua`
2. Add a new task function following the existing pattern
3. Register the task in the tasks table with rank requirements

## License

This resource is licensed under MIT License. See the LICENSE file for details.

## Credits

Created by Vein Development
Contact: support@veindevelopment.com 