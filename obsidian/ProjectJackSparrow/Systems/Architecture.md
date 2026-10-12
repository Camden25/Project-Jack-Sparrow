# Architecture

**Status:** ✅ Established

---

## Scene Tree

```
Root (Node) — root.gd
  PersistentUI (CanvasLayer)
    HUD (CanvasLayer) — hud.gd
    HeroSelectOverlay (CanvasLayer) — hero_select_overlay.gd
  SceneContainer (SubViewportContainer)
    SubViewport
      [current scene — lobby/world/etc]
```

World scene contains:
```
World (Node3D) — world.gd
  GameFlowManager (Node) — game_flow_manager.gd
    ControlPointMode (GameMode) — control_point_mode.gd
  ControlPoint (Area3D) — control_point.gd
  RespawnManager (Node) — respawn_manager.gd
  Effects (Node3D) — effects_manager.gd
  ProjectileRegistry (Node) — projectile_registry.gd
  Players (Node3D) — player instances added here
  Projectiles (Node3D) + MultiplayerSpawner
```

---

## Autoloads

| Name | File | Purpose |
|---|---|---|
| `NetworkManager` | `res://autoloads/network_manager.gd` | Steam P2P, lobby, peer registration, ping measurement |
| `PlayerManager` | `res://autoloads/player_manager.gd` | Player registry, teams, hero selections |
| `MatchEvents` | `res://autoloads/match_events.gd` | `hit_confirmed`, `player_killed` RPCs |
| `GameModeEvents` | `res://autoloads/game_mode_events.gd` | `objective_progress_updated`, `round_started/ended`, `wins_updated` |
| `SceneManager` | `res://autoloads/scene_manager.gd` | `goto_scene()`, node getters |

`ProjectileRegistry` is **not** an autoload: it is a child of the World scene, at `World/ProjectileRegistry`. `EffectsManager` is also a World child (`World/Effects`), not an autoload or Root child. `SceneManager` accesses both through the current World.

## Project Configuration

- Godot `4.7`, Forward+ renderer, Jolt Physics.
- Main scene: `res://core/scenes/root.tscn`.
- Input actions include movement, jump, crouch, reload, primary/secondary fire, ability1–3, ultimate, and pause. Default keyboard movement is WASD; fire uses mouse buttons.
- The target design is 4v4, but `NetworkManager.MAX_PLAYERS` is currently 6, so runtime lobby capacity is not yet 8.

---

## Key File Paths

### Core
```
res://core/scenes/root.tscn
res://core/scripts/root.gd
```

### Maps
```
res://maps/world.gd
res://maps/scripts/game_flow_manager.gd
res://maps/scripts/game_mode.gd
res://maps/scripts/control_point_mode.gd
res://maps/scripts/control_point.gd
res://maps/scripts/respawn_manager.gd
```

### Player
```
res://player/scripts/player.gd
res://player/scripts/player_health.gd
res://player/scripts/interpolation_controller.gd
res://player/scripts/lag_compensation_buffer.gd
```

### Heroes
```
res://hero_base/scripts/hero_base.gd
res://hero_base/scripts/ability.gd
res://hero_base/scripts/weapon.gd
res://hero_base/scripts/hitscan_weapon.gd
res://hero_base/scripts/ultimate_ability.gd
res://hero_base/resources/hero_data.gd
res://hero_base/resources/ability_data.gd
res://hero_base/resources/weapon_data.gd
```

### UI
```
res://ui/scripts/hud.gd
res://ui/scripts/ability_slot_display.gd
res://ui/scripts/world_health_bar.gd
res://ui/scripts/hero_select_overlay.gd
res://menus/scripts/lobby_ui.gd
```

### Weapons / Effects
```
res://weapons/scenes/tracer.tscn
res://weapons/scripts/tracer.gd
```

---

## Player Authority Model

- Each player scene is named after their peer ID: `"1"`, `"1560726720"`, etc.
- `set_multiplayer_authority(int(name))` in `_enter_tree()`
- All ability nodes inherit this authority
- `MultiplayerSynchronizer` authority also set explicitly
- Server (peer 1) has authority over world, projectiles, game mode nodes

---

## Projectile Pattern

All projectiles follow this contract:
1. `init_from_data(data: Dictionary)` — store values, NO engine API calls
2. `_ready()` — all engine setup here (set position, connect signals, set velocity)
3. Server owns gameplay-authoritative impact/damage logic; local lifetime or visual code may still run on clients
4. Must be registered in the World child `ProjectileRegistry` and spawned through `World/Projectiles/MultiplayerSpawner`

---

## GitHub

https://github.com/Camden25/Project-Jack-Sparrow
