# Networking

**Status:** ✅ Core working — rough edges remain

---

## Stack

- **Godot 4** with `MultiplayerAPI`
- **GodotSteam** GDExtension — Steam P2P transport
- **SteamMultiplayerPeer** for host/client connections
- The active lobby flow is Steam P2P through Steam relay. `NetworkManager` also contains basic ENet `start_dedicated_server()` / `join_dedicated_server()` helpers, but they are not integrated with lobby, matchmaking, or game-flow selection.
- `NetworkManager.MAX_PLAYERS` currently caps a Steam lobby at 6; this does not yet match the 4v4 design target of 8 players.

---

## Connection Flow

1. Host creates Steam lobby → `SteamMultiplayerPeer.create_host(0)`
2. Client joins → `create_client(host_steam_id, 0)`
3. Both register in `PlayerManager` via `_sync_existing_player` RPC
4. `start_game` RPC → `SceneManager.goto_scene("res://maps/world.tscn")`
5. World loads → `GameFlowManager._ready()` → hero select shown
6. All confirm hero → `world.spawn_all_players()` → countdown → round starts

---

## Spawn System

- Server calls `_spawn_player(peer_id)` — instantiates hero scene
- **Host:** `player.confirm_spawn(spawn_pos)` directly
- **Client:** 4-frame delay → `_set_client_spawn_position.rpc_id(peer_id, spawn_pos)`
- Client receives RPC → `player.confirm_spawn(spawn_pos)` → sets `spawn_confirmed = true` → movement enabled
- Respawn uses same path via `RespawnManager`

---

## Player Sync

- `MultiplayerSynchronizer` on each hero scene
- Synced vars: `net_position`, `net_rotation`, `net_head_rotation` (all `@export var`)
- Authority set in `_enter_tree()`: `set_multiplayer_authority(int(name))`
- Remote players use `InterpolationController` with 100ms delay buffer
- `LagCompensationBuffer` records position history server-side every physics frame

---

## Lag Compensation (Hitscan)

1. Client fires → `_server_validate_shot.rpc_id(1, origin, direction, shooter_id)`
2. Server: `rewind_time = now - ping` → rewind all non-shooter players via `PhysicsServer3D.body_set_state`
3. Raycast → restore positions → apply damage if hit
4. `NetworkManager.get_peer_ping()` returns measured one-way latency from ping-pong loop

---

## Tracers

- Go through `EffectsManager` (NOT MultiplayerSpawner — avoids ownership issues)
- Client fires → `_request_tracer.rpc_id(1)` → server calls `EffectsManager.spawn_tracer.rpc()` → all clients spawn locally
- `EffectsManager` is `World/Effects`, not an autoload; it is recreated with the World scene.

---

## Projectiles

- Generic spawner: `world.spawn_projectile(key, data)`
- `World/ProjectileRegistry` maps string keys to PackedScenes (it is a World child, not an autoload)
- Each projectile implements `init_from_data(data: Dictionary)` — store values only, no engine API calls
- Engine API calls go in `_ready()` after node is in tree
- Server owns gameplay-authoritative impact/damage behavior; projectiles may still run local lifetime or visual behavior on clients
- Projectile scenes must be in `World/Projectiles/MultiplayerSpawner`'s auto-spawn list

---

## RPC Authority Rules

| Node owner | RPC mode needed |
|---|---|
| Server calling server-owned node | `"authority"` |
| Server calling client-owned node | `"any_peer"` |
| Client calling server | `rpc_id(1, ...)` with `"any_peer"` |
| Server broadcasting to all on client-owned node | `"any_peer", "call_local"` |

Ability nodes are children of player → inherit player authority (client-owned). Server calling RPCs on them needs `"any_peer"`.

---

## Autoloads

| Autoload | Purpose |
|---|---|
| `NetworkManager` | Steam P2P, lobby, peer registration, ping |
| `PlayerManager` | Player registry, teams, hero selections |
| `MatchEvents` | `hit_confirmed`, `player_killed` RPCs |
| `GameModeEvents` | `objective_progress_updated`, `round_started/ended`, `wins_updated` |
| `SceneManager` | `goto_scene()`, world/player/projectile node getters |

These are the five autoloads declared in `project.godot`. `EffectsManager` and `ProjectileRegistry` are World-scene children.

---

## Known Issues / Roughness

- Player sync and interpolation could use more testing
- Mid-game joining not fully implemented (spectator mode needed)
- Lobby player list names sometimes wrong on join (debounce applied)
