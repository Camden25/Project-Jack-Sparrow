# Ability System

**Status:** 🟡 Core registration, input routing, and cooldowns are implemented. Finite-use handling is stubbed; the Ultimate base class exists, but neither playable hero scene currently includes an ultimate.

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

### Weapon
- Fire-rate timer, ammo, reload, and viewmodel/world-mesh visibility.
- **File:** `res://hero_base/scripts/weapon.gd`

### HitscanWeaponBase (extends Weapon)
- Server-side shot validation and lag-compensated raycasts.
- **File:** `res://hero_base/scripts/hitscan_weapon.gd`

### UltimateAbility (extends Ability)
- Tracks `current_charge` up to `ultimate_cost` (default 1000; it is not normalized to 0.0–1.0).
- Hooks `damage_dealt` / `healing_done` signals on `HeroBase` to add charge.
- Hitscan weapons and Drop Anchor emit `damage_dealt`; the detached Volley script also emits it. `healing_done` currently has no emitters, and no playable hero scene registers an `UltimateAbility`, so there is no active ultimate charge bar or charge flow in the runtime roster.
- Base class only permits activation when charge is full. A subclass must implement `_activate()` and call `_use_ultimate()` to reset charge.
- **No UltimateAbility node is currently attached to either playable hero scene.**
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
- Ultimate display supports a charge bar, but no Ultimate is currently registered by the playable heroes.
- **File:** `res://ui/scripts/ability_slot_display.gd`

---

## File Paths

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
