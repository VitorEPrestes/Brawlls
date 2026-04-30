# Brawlls Simulator

A 2D physical battle simulator built in **Godot 4.x** with GDScript.

## Features (MVP)
- **Arena**: 2D closed arena with physics boundaries.
- **Balls**: Physics-based entities that move and attack automatically.
- **Weapons**: Modular strategy-pattern based weapons:
  - Shield: Blocks or reduces incoming damage before HP is applied.
  - Pa: Dash combo attacker with a life-steal projectile special.
  - Cacto: Splitting projectile shooter with a slowing thorn zone.
  - Laque: Persistent smoke clouds plus an aura special.
  - Adolescente: Fast punch combo fighter with an invulnerable dash special.
  - Colt: Dual revolvers, slow-tracking burst fire, and a longer charged super burst.
  - Shelly: Shotgun pellets and slowing special pellets.
  - Frank: Heavy cone attacks and a stunning super.
- **Auto-Battles**: AI automatically seeks nearest targets and battles.
- **UI**: Presets for teams, duels, Free-For-All, stress tests, and a 9:16 short-video view.

## How to Run
1. Open Godot 4.x.
2. Import the `Brawlls` project using the `project.godot` file.
3. Open `Main.tscn` as the main scene (or just press F5, as it should be set or will prompt you to select the main scene, you can select `Main.tscn`).
4. Select a preset in the top right corner.
5. Click **Start Battle** to watch the simulation.
6. The battle ends when only one entity (or none) remains.
7. Click **Reset** to clear the arena and start over.

## Architecture
- `main.gd` / `Main.tscn`: UI and battle orchestration.
- `preset_catalog.gd`: Battle preset definitions.
- `arena.gd` / `Arena.tscn`: Dynamic generation of boundary walls.
- `ball.gd` / `Ball.tscn`: Core entity, handles health, physics movement, and delegates weapon behavior.
- `projectile.gd` / `Projectile.tscn`: Area2D used for ranged attacks.
- `weapon_registry.gd`: Weapon aliases, scripts, and final stat modifiers.
- `weapon_base.gd`: Base class for all weapons, including shared target, damage, heal, and status helpers.
- `weapons/`: Subclasses of weapons implementing specific behaviors (`modify_incoming_damage`, `on_hit`, `process_weapon`, `on_owner_damaged`).
