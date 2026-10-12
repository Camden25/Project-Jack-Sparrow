# Weapon System

**Status:** ✅ Hitscan weapon base and generic ability-projectile spawning exist. ❌ No reusable projectile-weapon base or projectile-primary hero is currently implemented.

---

## Existing Weapons

| Weapon | Type | Hero | Status |
|---|---|---|---|
| Musket | Hitscan, ADS only | Ex Navy Officer | ✅ Done |
| Flintlock | Hitscan, hipfire | Ex Navy Officer | ✅ Done |
| Shotgun | Hitscan spread | Octopus | ✅ Done |

---

## Hitscan Framework

All hitscan weapons extend `HitscanWeaponBase`:

1. Client fires → `_server_validate_shot.rpc_id(1, origin, direction, shooter_id)`
2. Server rewinds player positions by `ping` amount using `LagCompensationBuffer`
3. Raycast in rewound state
4. Restore positions
5. Apply damage if hit via `PlayerHealth.apply_damage`
6. `hit_confirmed` signal → `MatchEvents`

**Lag compensation** uses `PhysicsServer3D.body_set_state` to physically move colliders, raycast, then restore. This means even high-ping players can hit what they're aiming at.

---

## Projectile Weapon Framework — ❌ TODO (distinct from generic ability projectiles)

The project already has a server-authoritative `world.spawn_projectile(key, data)` path, `Projectile` base class, `ProjectileRegistry`, and two registered ability projectiles (smoke canister and anchor). What is still missing is the weapon-side fire/validation framework that would make a cannonball primary weapon.

This is a **priority task**. Needed for [[Cannoneer]] and potentially other heroes.

### What's needed:

**ProjectileWeaponBase** (new class, extends `Weapon`):
- Client fires → request sent to server
- Server spawns projectile via `world.spawn_projectile(key, data)`
- Projectile travels, detects hit, applies damage server-side
- Client gets visual feedback immediately (predicted local projectile? or just tracer?)

**ProjectileBase**: use/extend the existing `Projectile` class rather than assuming a new base is required:
- `init_from_data(data: Dictionary)` — store values only
- All engine API calls in `_ready()`
- Affected by gravity (configurable)
- Splash damage on impact: sphere overlap at hit position
- `_integrate_forces` for physics control if needed

### Key design decisions:
- **Client prediction?** — spawn a dummy visual projectile on the client immediately, then reconcile with the server-spawned one. Avoids the visual delay of waiting for server round-trip.
- **Splash damage** — sphere overlap at impact point, damage falls off with distance. Same team check needed.
- **Direct hit vs splash** — direct hit deals more damage than splash edge.

### Existing reference:
- `AnchorProjectile` (extends the `Projectile` RigidBody3D base) is an example of `init_from_data` / `_ready` separation. Older notes report anchor issues; verify them against the current build before treating them as active bugs.
- `smoke_canister_projectile.gd` is another reference — a rigid-body projectile launched with an impulse that deploys a FogVolume on landing.

---

## Tracer System

- Goes through `EffectsManager`, a child of the World scene (not an autoload)
- Client fires → `_request_tracer.rpc_id(1)` → server calls `EffectsManager.spawn_tracer.rpc()` → all clients spawn locally
- Tracer scene: `res://weapons/scenes/tracer.tscn`
- `EffectsManager` is `World/Effects`; it does not persist across scene changes

---

## Reload

- `Weapon` base class has `max_ammo`, `current_ammo`, `reload_time`
- Reload triggered when ammo hits 0 or player presses reload
- Reload timer is local — no network sync needed (cosmetic)
- Ammo display on HUD driven by weapon signals

---

## File Paths

```
res://hero_base/scripts/weapon.gd
res://hero_base/scripts/hitscan_weapon.gd
res://hero_base/scripts/projectile.gd
res://player/scripts/lag_compensation_buffer.gd
res://maps/scripts/projectile_registry.gd
res://weapons/scenes/tracer.tscn
res://weapons/scripts/tracer.gd
```
