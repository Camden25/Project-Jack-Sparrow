# Cannoneer

> Longer-range, tankier cannon specialist who can load an ally into the cannon and steal an enemy for the ultimate.

**Status:** ❌ Design only — no hero scene/resource is registered in the project.

---

## Kit Overview (Concept)

| Slot | Name | Type | Status |
|---|---|---|---|
| Primary fire | Cannonball | Projectile | ❌ Design only |
| Secondary fire | Shoot ally | Team utility / projectile, details TBD | ❌ Design only |
| Ability 1 | Enter ally mode | Transformation / team interaction, details TBD | ❌ Design only |
| Ability 2 | TBD | — | ❌ Undecided |
| Ultimate | Steal an enemy and fire them from the cannon | Displacement / projectile | ❌ Design only |

---

## Design Notes

- This hero is the projectile weapon framework test case
- Longer-range and tankier than the current close-range heroes; exact role stats are not set.
- Cannonball should be physics-based: affected by gravity, travel time, splash damage
- Counterplay is dodging the projectile — skill expression is leading shots
- Slow and heavy — takes up space on the point, hard to move off
- Story and horror angle: TBD.

## Open Design Questions

- Define what “shoot ally” does and whether it requires entering ally mode first.
- Define how entering ally mode changes the ally and how they opt in/out.
- Define the enemy-steal rules, counterplay, and whether the ultimate can be interrupted.
- Design Ability 2 and the character's story.

---

## Implementation Notes

- Primary weapon is the first projectile weapon — will establish the framework for all future projectile weapons
- Needs: server-authoritative projectile spawning, client prediction for feel, splash damage radius on impact
- See [[Weapon System]] — projectile weapon framework is a priority task
- Splash damage needs its own hit detection (sphere overlap at impact point)
