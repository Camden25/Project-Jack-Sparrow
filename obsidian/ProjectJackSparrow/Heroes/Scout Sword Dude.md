# Scout Sword Dude

> High-mobility sword flanker. Wall-jumps, creates an explosive spark, then dashes through targets.

**Status:** ❌ Design only — no hero scene/resource is registered in the project.

---

## Kit Overview (Concept)

| Slot | Name | Type | Status |
|---|---|---|---|
| Unique movement | Wall jump | Mobility | ❌ Design only |
| Primary fire | Sword | Melee | ❌ Design only |
| Secondary fire | Flint-strike sword spark | Explosion / setup | ❌ Design only |
| Ability 1 | Dash | Mobility | ❌ Design only |
| Ability 2 | TBD | — | ❌ Undecided |
| Ultimate | TBD | — | ❌ Undecided |

---

## Kit Concepts

- Unique movement: wall jump.
- Primary: sword.
- Secondary: strike the sword with flint to create a spark/explosion.
- Ability 1: dash. Hitting a target that has been blasted by an explosion resets the dash cooldown.
- Ability 2, ultimate, damage values, and story are not decided yet.

## Implementation Questions

- Specify melee hit detection and lag compensation for multiplayer.
- Define the spark's range/effect and what counts as a target “blasted with an explosion.”
- Define dash distance, duration, cooldown, and the exact reset conditions.

---

## Design Notes

- Should feel genuinely threatening to encounter in close quarters
- Melee in a shooter needs to feel fair — hitbox and lag comp need care
- Story and horror angle are currently undecided.

---

## Implementation Notes

- Melee weapon will need its own base class extending `Weapon` or another server-validated hit system.
- Short raycast on swing for hit detection, or capsule overlap
- Lag comp for melee is trickier than hitscan — may need position rewind same as hitscan but with a shape cast
