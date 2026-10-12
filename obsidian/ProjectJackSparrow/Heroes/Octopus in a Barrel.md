# Octopus in a Barrel

> Literally an octopus in a barrel: a close-range shotgun fighter with a grapple and an anchor trick.

**Status:** 🟡 In the runtime roster. Shotgun, Grapple, and Drop Anchor are attached to the scene. Drop Anchor's current behavior differs from older design notes; regression-test it.

---

## Current Scene Kit

| Slot | Name | Type | Scene status |
|---|---|---|---|
| Primary weapon | Shotgun | Spread hitscan | Present; scene sets 12 pellets |
| Secondary fire | Grapple | Mobility | Present; AbilityData slot is `SECONDARY` |
| Ability 1 | Drop Anchor | AOE | Present; AbilityData defaults to `ABILITY_1` |
| Ability 2 / Ultimate | None | — | No nodes/design in the supplied brief |

---

## Shotgun

- Fires 12 spread hitscan rays per trigger in the current scene (the script default is 10).
- Extends `HitscanWeaponBase`, so server shot validation and hitscan lag compensation are used.
- **File:** `res://heroes/octopus_in_a_barrel/weapons/shotgun.gd`

## Grapple (Secondary)

- Press secondary fire to raycast up to 30 m. A successful hit attaches the grapple point and adds a small launch impulse.
- Hold secondary fire to remain attached; release to detach and start the 5-second cooldown. Hold jump to reel in. Movement input accelerates the swing.
- The local player draws a cylinder rope. Although `net_grapple_point` and `net_is_grappling` variables exist, the scene replication config does not include them and the rope visual uses local grapple state; remote rope rendering is not currently wired up.
- **File:** `res://heroes/octopus_in_a_barrel/abilities/grapple/grapple.gd`

## Drop Anchor (Ability 1)

- The scene uses `drop_anchor.gd`. It can activate only while the player is airborne, zeroes velocity, waits 0.3 seconds, then asks the server to spawn an anchor about 1 m below the player's position.
- The anchor falls under server authority. At landing, the server selects enemy players within 3 m and calculates damage as `min(30 + 3 × drop height in metres, 80)`.
- **The current scene-bound script does not lift the player or yank them to the anchor.** Older notes describing a rise/yank phase refer to behavior not present in this script.
- The resource specifies a 12-second cooldown, but this script overrides `try_activate()` and does not start the base cooldown. Verify/fix cooldown behavior.
- Previously reported ceiling/floor/contact and client movement issues should be retested against this current implementation before planning a full rework.
- **Files:**
  - `res://heroes/octopus_in_a_barrel/abilities/drop_anchor/drop_anchor.gd`
  - `res://heroes/octopus_in_a_barrel/abilities/drop_anchor/scripts/anchor_projectile.gd`

---

## Story and Design Notes

The octopus washed up on the Captain's ship, stole a deck barrel, and used a tentacle to grapple up to the crow's nest. The Captain's parrot sat on its head; they became friends, and the octopus now hangs around aboard the ship. It is missing one tentacle, and nobody knows why. It can produce an anchor from apparent hammerspace, which everyone questions.

The supplied design does not include Hide in Barrel or an ultimate. No such abilities are present in the current scene.

---

## Pending Work

- [ ] Regression-test Drop Anchor and fix confirmed issues, especially the unstarted cooldown.
- [ ] Decide whether anchor yank is still desired; it is absent from the current implementation.
- [ ] Wire remote-player grapple rope rendering if needed.
- [ ] Character model/rig, weapon viewmodel, and SFX.
