# Ability System

**Status:** 🟡 Core registration, input routing, and cooldowns are implemented. Ex Navy Officer has a charge-based Volley ultimate attached. Drop Anchor and Grapple are working in the tested build. Finite-use handling remains stubbed.

---

## Class Hierarchy

```
CharacterBody3D
  Player (player.gd)             — movement, synchronization, health
    HeroBase (hero_base.gd)      — ability/weapon registration and input routing
      ExNavyOfficer
      OctopusInABarrel
```

Only Ex Navy Officer and Octopus in a Barrel are currently in the runtime roster.

---

## Resource Types

### AbilityData
- `ability_name: String`
- `icon: Texture2D`
- `slot: AbilitySlot` (enum)
- `cooldown: float`
- `max_uses: int` (-1 = unlimited)
- `custom_stats: Dictionary` — hero-specific values

### WeaponData
- `weapon_name: String`
- `icon: Texture2D`
- `slot: WeaponSlot` (enum)
- `damage: int`
- `max_ammo: int`
- `fire_rate: float`
- `reload_time: float`
- `max_range: float`
- `custom_stats: Dictionary`

---

## Slot Enums

```gdscript
enum AbilitySlot { PRIMARY, SECONDARY, ABILITY_1, ABILITY_2, ABILITY_3, ULTIMATE }
enum WeaponSlot { PRIMARY, SECONDARY }
```

---

## Base Classes

### Ability
- Cooldown timer, `try_activate()`, `_activate()` override hook, and `physics_update()` hook.
- `_can_activate()` checks cooldown and uses; cooldown helpers include `_start_cooldown()`, `reset_cooldown()`, and `reduce_cooldown()`.
- `cooldown_changed` signal drives HUD display.
- `max_uses` is represented in data, but decrementing finite uses is currently commented out/stubbed in `try_activate()`.
- **File:** `res://hero_base/scripts/ability.gd`

### Drop Anchor
- Uses bounded `LIFTING`, `DROPPING`, `WAITING_FOR_LANDING`, and `PULLING` phases.
- Lift height is limited by an upward raycast; pull ends on arrival, collision, timeout, or respawn.
- Deals full damage within 1 m of impact, with linear falloff to zero at 4 m.
- The server remains authoritative for anchor landing and damage. Cooldown starts once the landing notification is confirmed, not on activation.
- **File:** `res://heroes/octopus_in_a_barrel/abilities/drop_anchor/drop_anchor.gd`

### Weapon
- Fire-rate timer, ammo, reload, and viewmodel/world-mesh visibility.
- **File:** `res://hero_base/scripts/weapon.gd`

### HitscanWeaponBase (extends Weapon)
- Server-side shot validation and lag-compensated raycasts.
- The server records every player's transform history on physics ticks and interpolates between snapshots when rewinding targets.
- **File:** `res://hero_base/scripts/hitscan_weapon.gd`

### ProjectileWeaponBase (extends Weapon)
- Sends only the aim direction from the owning client. The server validates the shooter, aim, fire rate, ammo, and reload, derives the muzzle origin, then spawns a registered projectile through `World.spawn_projectile()`.
- Projectile key, speed, gravity, lifetime, damage, and additional projectile data are configured on the weapon node.
- The projectile scene handles its own server-side movement, collision, damage, and lifecycle visual events.
- **File:** `res://hero_base/scripts/projectile_weapon.gd`

### Recoil Hop (Cannoneer Ability 1)
- Adds backward horizontal and upward velocity from the player's aim, preserving the launch against ordinary movement input for a short window.
- Does not deal damage; activation is blocked while another ability has movement control. Cancellation restores `movement_override`.
- **Files:** `res://heroes/cannoneer/abilities/recoil_hop/recoil_hop.gd`, `res://heroes/cannoneer/resources/recoil_hop.tres`

### UltimateAbility (extends Ability)
- Tracks `current_charge` up to `ultimate_cost` (default 1000; it is not normalized to 0.0–1.0).
- Hooks server-side `damage_dealt` / `healing_done` signals on `HeroBase` to add charge, then synchronizes the charge to the owning player.
- Hitscan weapons and Drop Anchor emit `damage_dealt`; `healing_done` currently has no emitters.
- Base class only permits activation when charge is full. A subclass must implement `_activate()` and call `_use_ultimate()` to reset charge.
- Volley is registered in Ex Navy Officer's `ULTIMATE` slot and shows charge in the HUD.
- **File:** `res://hero_base/scripts/ultimate_ability.gd`

---

## Registration and Input

`HeroBase._ready()` iterates direct children of the `Abilities` node and registers weapons/abilities using their resource slots. `HeroBase.swap_abilities()` can re-register a different node, but no current hero uses a form swap.

`HeroBase._unhandled_input()` routes primary fire through `_handle_primary_fire()` (overridable), secondary fire to an ability in the `SECONDARY` ability slot, and the remaining actions to ability slots. Ex Navy Officer chooses its Musket or Flintlock from its primary-fire handler; its secondary weapon is not fired by the generic secondary-fire route. Reload is also hero-overridable.

`physics_update(delta)` is called for registered abilities from `HeroBase._physics_process()`.

---

## Movement Override

`movement_override: bool` on `Player` suppresses normal movement while an ability takes control. Ex Navy Officer's Dash sets and clears it. The current Grapple and Drop Anchor scripts change velocity without setting this flag. Any ability that does use the override must restore it when movement control ends.

---

## Cooldown Display

- `AbilitySlotDisplay` is spawned dynamically per registered ability in the HUD.
- Cooldown overlay shrinks the `anchor_top` of a `ColorRect`.
- Ultimate display supports a charge bar; Ex Navy Officer's Volley is registered and displays charge.
- **File:** `res://ui/scripts/ability_slot_display.gd`

## Health Packs

- `res://maps/scenes/health_pack.tscn` is a reusable world pickup. Configure its healing amount and respawn delay in the Inspector, then instance it in a map.
- The server handles pickup collisions and healing; the pack disappears and respawns consistently for all peers.
- Packs do not heal players at full health or revive defeated players. Actual health restored emits `HeroBase.healing_done`.

---

## File Paths

```
res://hero_base/scripts/hero_base.gd
res://hero_base/scripts/ability.gd
res://hero_base/scripts/weapon.gd
res://hero_base/scripts/hitscan_weapon.gd
res://hero_base/scripts/projectile_weapon.gd
res://hero_base/scripts/ultimate_ability.gd
res://hero_base/resources/hero_data.gd
res://hero_base/resources/ability_data.gd
res://hero_base/resources/weapon_data.gd
```
