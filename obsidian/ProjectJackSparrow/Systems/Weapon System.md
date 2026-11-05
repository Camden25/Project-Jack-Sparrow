# Weapon System

**Status:** ✅ Hitscan weapon base and the lightweight RPC visual path for smoke, Anchor, and Volley effects are implemented. ⚠️ Multiplayer behavior still needs host/remote testing. ❌ No reusable projectile-weapon base or projectile-primary hero is currently implemented.

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

`World/ProjectileEvents` now owns server-side gameplay projectile creation and reliable lifecycle events. Clients create collision-free visual proxies; gameplay collision/damage remains server-side. Smoke canisters, Drop Anchor, and Volley presentation use this event path. The missing piece is a reusable weapon fire/validation path and projectile-primary hero such as a cannonball.

### Lightweight RPC migration — walkthrough

The goal is not to send physics state every frame. Keep collision and damage on the server, and send small lifecycle events so clients create cosmetic-only proxies. The server simulates each gameplay projectile once; clients simulate only its appearance and correct it on impact. This replaces replicated projectile nodes, not the server's physics objects.

#### 1. Inventory and classify

- **Smoke canister:** server-simulated throw; broadcast launch, then broadcast the authoritative landing/deployment event.
- **Drop Anchor:** server-simulated fall and landing/damage; broadcast launch and landing. The player's lift/pull ability flow remains separate from the projectile visual.
- **Volley:** server raycasts and applies damage; broadcast a barrage-start event and per-shot impact positions for flare/impact visuals. The flare and shot VFX do not need physics replication.
- **Future cannonball:** server-simulated projectile with direct-hit/AOE damage; broadcast launch, then impact or expiry.

Keep an inventory table of each call site, authoritative simulation, client visual, and terminal event. Migrate one type at a time; don't remove the old spawn path until every peer sees the replacement correctly.

#### 2. Add a projectile-event service to `World`

Create a node under `World` that owns two responsibilities:

- A server-only factory for gameplay projectiles. It validates a registered type key and instantiates the gameplay scene under `World/Projectiles`; it does not call `MultiplayerSpawner.spawn()`.
- RPC endpoints that create, update, and finish client-only visuals. Clients resolve type keys through a local allow-list of visual scenes; never accept arbitrary scene paths from the network.

Every peer must have the RPC service at the same scene-tree path and with matching RPC declarations. Use the server as its multiplayer authority. Send launch and terminal events reliably on the same channel so an impact cannot arrive before its launch; if you later add frequent snapshots, put those on an unreliable channel.

Use compact, typed RPC arguments rather than sending whole Nodes or arbitrary Resources. The current launch payload is: unique projectile ID, type key, start position, initial velocity, gravity, and visual lifetime. Add a server timestamp only if a clock-synchronization/age-correction strategy is introduced.

#### 3. Establish IDs and authority

- The firing peer sends a request containing an aim direction and monotonically increasing shot/request ID—not damage, team, projectile scene path, muzzle origin, or claimed shooter ID.
- The server identifies the caller with `multiplayer.get_remote_sender_id()`, checks alive/equipped/cooldown/ammo, derives the muzzle transform from the server's player/weapon, and chooses the projectile type and stats from server-owned data.
- The server assigns a unique projectile ID (for example, match-scoped server counter), creates the gameplay projectile, and announces the launch.
- Ignore or reject events for unknown types, duplicate IDs, invalid vectors, implausible aim, and stale fire requests. Rate-limit on the server; a client-side fire timer is presentation, not security.

#### 4. Separate gameplay scenes from visual proxies

Keep the existing `Projectile`/`RigidBody3D` pattern for server gameplay where it is useful. Make a separate lightweight visual scene or a visual-only mode that has no damage, collision authority, RPCs, or gameplay side effects. Add visual proxies under `World/ProjectileVisuals`; map projectile ID to proxy so impact/expiry events find the right visual.

Clients may integrate a cosmetic proxy from the launch state to reduce traffic. Its transform is never used for hit detection. On server impact, send projectile ID, impact position, normal, and result/effect parameters; clients snap or smoothly correct the proxy, play impact VFX, and remove it. On expiry, send a finish event and clean up. Add periodic snapshots only if testing shows drift that impact correction cannot hide.

#### 5. Pick delivery per event

- **Reliable:** low-rate lifecycle events whose loss would leave a stuck visual, such as a smoke deployment or projectile cleanup. Make handlers idempotent by projectile ID.
- **Unreliable:** frequent cosmetic transform snapshots; newest state matters more than retransmitting old state.
- **Damage:** never inferred from a client visual or cosmetic event. Only the server collision/result path applies it.

Start without periodic snapshots. If adding them, batch multiple projectiles into one update and use server timestamps plus client interpolation. Do not send one reliable RPC per physics frame.

#### 6. Migrate and verify incrementally

1. [x] Implement the World event service, server-only factory, and client visual proxies.
2. [x] Convert smoke canister launch, landing, smoke deployment, and cleanup.
3. [x] Convert Drop Anchor launch/landing visuals; keep the existing server-only damage and client pull/cooldown flow.
4. [x] Route Volley flare and impact visuals through RPCs; keep server raycasts/damage unchanged.
5. [ ] Add the cannonball weapon using the same launch/impact contract.
6. [x] Remove the projectile `MultiplayerSpawner` and Anchor's transform synchronizer. Host/remote, disconnect/reconnect, and latency testing remains outstanding.

Late joiners currently do not receive already-active projectile proxies or smoke volumes; the current mid-match join flow is not supported. If late joining is enabled, add a server snapshot of active gameplay projectiles and smoke volumes rather than replaying old launch events.

### Is RPC spawning better than the current approach?

For your stated goal of moving **all projectile visuals** to a lightweight event path, yes: the RPC event service avoids replicating a physics Node to every peer and gives the server a clear gameplay/visual boundary. But it is not automatically lower bandwidth just because it uses RPCs. One RPC per projectile launch still has per-message overhead; the benefit is avoiding ongoing physics-node replication and sending only the lifecycle data clients need. Your existing `MultiplayerSpawner` remains a valid choice for the current small number of slow ability projectiles and is simpler until you need this separation.

For many very short-lived bullets, batch fire/impact effects or render tracers locally from compact fire events rather than creating a networked physics body per bullet. Pool cosmetic proxies only if profiling shows local allocation cost; pooling does not replace server authority or reduce network traffic by itself.

### Existing reference:
- `AnchorProjectile` (extends the `Projectile` RigidBody3D base) is an example of `init_from_data` / `_ready` separation and server-side impact decisions.
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
