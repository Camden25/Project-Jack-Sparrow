# Game Flow

**Status:** ✅ Working

---

## State Machine

```
WAITING → hero-select overlay → COUNTDOWN → ACTIVE → ROUND_END → MATCH_END → lobby
```

Managed by `GameFlowManager` — a child of the World scene. The server drives flow and syncs state to clients via `_sync_state.rpc`.

The enum also contains `HERO_SELECT`, but the initial `_sync_show_hero_select()` path does not sync that enum state. The overlay is shown separately from the synchronized flow state.

---

## States

| State | What happens |
|---|---|
| `WAITING` | Initial state on world load |
| `HERO_SELECT` | Enum value exists; current overlay display path does not sync this state |
| `COUNTDOWN` | Players spawned, 5 second countdown |
| `ACTIVE` | Round running, game mode active |
| `ROUND_END` | Synced when `GameFlowManager` receives `round_ended`; current ControlPointMode emits this only when the win threshold is reached |
| `MATCH_END` | Match over, 5 second pause, then return to lobby |

---

## Flow Details

### Hero Select
- On World load, the server calls `_begin_hero_select()` → `_sync_show_hero_select.rpc()`
- All clients show `HeroSelectOverlay`
- When all players confirm (or the 20-second selection timer expires) → selections are applied; `start_match()` is called on server
- Overlay passes `GameFlowManager` reference so it can call `start_match()`

### Spawn
- `world.spawn_all_players()` — server iterates `PlayerManager.player_registry`
- Each player gets a spawn position from `RespawnManager`
- Server spawns hero scene, sets authority, confirms position
- Client receives `_set_client_spawn_position` RPC → `player.confirm_spawn()` → movement enabled

### Round End / Match End
- `ControlPointMode` detects win → emits `round_ended(winning_team)`
- `GameFlowManager._on_round_ended` → check if match is over
- If not match over: `GameFlowManager` calls `_begin_hero_select()`; however, the current `ControlPointMode` does not emit `round_ended` for intermediate round wins. It waits 3 seconds and starts the next round itself. With the current `wins_needed = 1` default, a single point capture ends the match, so hero select does not currently repeat between rounds.
- If match over: `_end_match()` → wait 5s → `_return_to_lobby.rpc()`

### Return to Lobby
- `_return_to_lobby` RPC fires on all clients
- Calls `NetworkManager.return_to_lobby()`
- Mouse unlocked, hero selections cleared, scene changes to lobby
- Steam lobby stays alive — same host/connection
- Server re-registers itself, sends `_request_reregistration` to clients
- Lobby UI detects `steam_lobby_id != 0` → `_restore_lobby_state()`

---

## Scene Structure

```
Root (Node) — root.gd
  PersistentUI (CanvasLayer)
    HUD (CanvasLayer)
    HeroSelectOverlay (CanvasLayer)
  SceneContainer (SubViewportContainer)
    SubViewport
      [current scene]

When the current scene is World:
  World (Node3D)
    GameFlowManager
      ControlPointMode
    ProjectileRegistry
    Players
    Projectiles
    Effects
    RespawnManager
    ControlPoint
    Map / SpawnPoints
```

  `Effects` and `ProjectileRegistry` are World-scoped, not persistent Root children or autoloads.

---

## SceneManager

- `goto_scene(path)` — queues the current scene and existing SubViewport children for deletion, instantiates/adds the requested scene, then emits `scene_loaded`
- `_is_transitioning` guard prevents double loads
- `scene_loaded` signal used by HUD to detect world vs non-world

---

## File Paths

```
res://maps/world.gd
res://maps/scripts/game_flow_manager.gd
res://maps/scripts/game_mode.gd
res://maps/scripts/control_point_mode.gd
res://maps/scripts/control_point.gd
res://maps/scripts/respawn_manager.gd
res://autoloads/scene_manager.gd
```
