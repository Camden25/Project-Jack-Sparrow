# Ex Navy Officer

> A former British Navy officer turned pirate. A disciplined marksman whose current kit pairs a musket/flintlock with a dash and smoke.

**Status:** 🟡 Playable scene exists; Volley is not attached to it. Smoke-vision passive is a design/pending task.

---

## Kit Overview

| Slot | Name | Type | Status |
|---|---|---|---|
| Primary weapon | Musket | Hitscan | Present in scene |
| Secondary weapon | Flintlock | Hitscan | Present in scene; fired when not aiming the musket |
| Ability 1 | Dash | Mobility | Present in scene |
| Ability 2 | Smoke Canister | Projectile / vision denial | Present in scene |
| Ultimate | Volley | AOE / bombardment | Script/assets exist, but no Volley node is attached to the current hero scene |

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

### Dash (Ability 1; older notes called it Retreat)
- Dashes based on movement input, or forward if no direction is supplied.
- **File:** `res://heroes/ex_navy_officer/abilities/dash/dash.gd`

### Smoke Canister (Ability 2)
- Thrown projectile; on landing it deploys a FogVolume smoke effect.
- The ADS enemy-outline passive is not implemented.
- **Files:**
  - `res://heroes/ex_navy_officer/abilities/smoke_canister/smoke_canister.gd`
  - `res://heroes/ex_navy_officer/abilities/smoke_canister/scripts/smoke_canister_projectile.gd`
  - `res://heroes/ex_navy_officer/abilities/smoke_canister/scripts/smoke_effect.gd`

### Volley (planned ultimate; not wired into the current scene)
- Design/script concept: fires a flare, then calls down an AOE musket barrage.
- Scene assets and a script exist, but `ex_navy_officer.tscn` does not instantiate/register an ultimate node, so Volley is not currently available in the playable kit.
- **File:** `res://heroes/ex_navy_officer/abilities/volley/volley.gd`

---

## Pending Work

- [ ] Decide/implement whether ADS reveals enemies inside smoke.
- [ ] Attach and test Volley as an ultimate.
- [ ] Character model and rig.
- [ ] Weapon viewmodels.
- [ ] SFX — musket crack, flintlock pop, smoke hiss, dash whoosh, volley impacts.

---

## Story and Design Notes

She was a poor British citizen who joined the military to survive, rose to officer, challenged leadership, was charged with treason, and exiled to an island. The Captain found and brought her aboard, but still distrusts her former Navy ties. She keeps her tattered uniform as a reminder of what not to become.

The ADS dual-weapon system is the intended mechanical identity: the Musket rewards deliberate aim while the Flintlock is used outside ADS. Smoke/ADS synergy remains a design idea, not implemented behavior.

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
