# Ex Navy Officer

> A former British Navy officer turned pirate. A disciplined marksman whose current kit pairs a musket/flintlock with a dash and smoke.

**Status:** 🟡 Playable scene exists; ADS reveals enemies inside smoke. Volley is attached as a charge-based ultimate.

---

## Kit Overview

| Slot | Name | Type | Status |
|---|---|---|---|
| Primary weapon | Musket | Hitscan | Present in scene |
| Secondary weapon | Flintlock | Hitscan | Present in scene; fired when not aiming the musket |
| Ability 1 | Dash | Mobility | Present in scene |
| Ability 2 | Smoke Canister | Projectile / vision denial | Present in scene |
| Ultimate | Volley | AOE / bombardment | Attached to the current hero scene; charged by damage and activated with Q |

---

## Weapons

### Musket
- Slow, high damage.
- Requires ADS to fire; no hipfire.
- One-shot magazine with a slow reload.
- **File:** `res://heroes/ex_navy_officer/weapons/musket.gd`

### Flintlock
- Fast, lower-damage hipfire weapon; selected while not aiming the Musket.
- Ex Navy Officer routes both weapons through its primary-fire handler. Secondary-fire input is not the Flintlock trigger.
- **File:** `res://heroes/ex_navy_officer/weapons/flintlock.gd`

---

## Abilities

### Dash (Ability 1)
- Dashes based on movement input, or forward if no direction is supplied.
- **File:** `res://heroes/ex_navy_officer/abilities/dash/dash.gd`

### Smoke Canister (Ability 2)
- Thrown projectile; on landing it deploys a smoke shell made from opaque CSG spheres.
- While aiming the Musket, the officer sees outlines of enemy players inside active smoke.
- Outlines are local to the officer, disappear when she stops aiming, and do not reveal allies or players outside smoke.
- Outlines use a silhouette mask in a transparent SubViewport on render layer 19; the main camera excludes that layer. The SubViewport camera tracks the player camera and renders only the mask, while the smoke shell remains fully opaque and writes to depth on layer 18.
- Since the outline viewport is composited over the main view, outlines can appear over walls.
- **Files:**
  - `res://heroes/ex_navy_officer/abilities/smoke_canister/smoke_canister.gd`
  - `res://heroes/ex_navy_officer/abilities/smoke_canister/scripts/smoke_canister_projectile.gd`
  - `res://heroes/ex_navy_officer/abilities/smoke_canister/scripts/smoke_effect.gd`

### Volley (Ultimate)
- Builds charge from damage dealt. Once full, press Q to place a flare at the aim point and call down a server-authoritative barrage.
- The server checks teams and applies damage; the flare and impact markers are shown to all players.
- **File:** `res://heroes/ex_navy_officer/abilities/volley/volley.gd`

---

## Pending Work

- [x] ADS reveals enemies inside smoke.
- [x] Attach Volley as a charge-based ultimate.
- [ ] Character model and rig.
- [ ] Weapon viewmodels.
- [ ] SFX: musket crack, flintlock pop, smoke hiss, dash whoosh, volley impacts.

---

## Story and Design Notes

She was a poor British citizen who joined the military to survive, rose to officer, challenged leadership, was charged with treason, and exiled to an island. The Captain found and brought her aboard, but still distrusts her former Navy ties. She keeps her tattered uniform as a reminder of what not to become.

The ADS dual-weapon system is the intended mechanical identity: the Musket rewards deliberate aim while the Flintlock is used outside ADS. Smoke/ADS synergy is implemented: while aiming, the Officer sees enemy outlines inside active smoke.

---

## File Paths

```
res://heroes/ex_navy_officer/scripts/ex_navy_officer.gd
res://heroes/ex_navy_officer/weapons/musket.gd
res://heroes/ex_navy_officer/weapons/flintlock.gd
res://heroes/ex_navy_officer/abilities/dash/dash.gd
res://heroes/ex_navy_officer/abilities/smoke_canister/smoke_canister.gd
res://heroes/ex_navy_officer/abilities/smoke_canister/scripts/smoke_canister_projectile.gd
res://heroes/ex_navy_officer/abilities/volley/volley.gd
```
