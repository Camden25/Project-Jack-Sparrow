# Captain

> Unnamed, respected veteran captain and mid-range recon specialist. Her parrot is her closest companion.

**Status:** ❌ Design only — not present in the playable roster or hero scenes.

---

## Kit Overview (Proposed)

| Slot | Name | Type | Status |
|---|---|---|---|
| Primary fire | Feather Strike (current direction); pistol was an earlier option | Cone / projectile spread, TBD | ❌ Design only |
| Secondary fire | Focus | Target tracking / mark | ❌ Design only |
| Ability 1 | Coachgun | Burst / mobility, details TBD | ❌ Design only |
| Ability 2 | Recon Parrot | Remote scouting / vision | ❌ Design only |
| Ultimate | TBD | — | ❌ Not designed |

---

## Kit Concepts

### Feather Strike — Primary
- Fires a cone of feathers, compared in the notes to Genji-style shuriken.
- An earlier version listed a pistol as primary fire. Feather Strike is the newer direction; decide whether the pistol is removed or remains an alternate weapon before implementation.
- Range, spread, damage, fire cadence, and ammunition are undecided.

### Focus — Secondary
- Track/keep aim on a target for about 1.5 seconds to mark them.
- Define whether tracking must be uninterrupted, what the mark reveals, its duration, and how targets can break it.

### Coachgun — Ability 1
- Coachgun activation is paired with a visual of the captain summoning parrot wings.
- The parenthetical design note is unfinished. Clarify whether the wings are a dash/evade, whether the coachgun is fired, or both.

### Recon Parrot — Ability 2
- Throw/deploy the parrot, then control it and see through its eyes.
- The captain's body remains in its original place while piloting the parrot. Decide movement limits, duration, recall, vulnerability, and how control returns.

---

## Story and Visual Direction

- The captain is currently unnamed; she became captain after serving as first mate to a close friend in her late teens/early twenties. The British Navy killed her friend.
- She is now older, highly respected, and commands a ship. The design shorthand says “unc”; exact age and characterization remain open.
- She has a parrot she would die for. Its name is still blank.
- Visual reference: the proportions/silhouette of Reaper's cursed captain skin, interpreted freely. She need not be cursed; this is a proportion reference, not a requirement to copy the skin.

---

## Open Decisions

- Settle pistol versus Feather Strike as the primary-fire design.
- Complete Coachgun's unfinished “summons parrot wings” mechanic.
- Specify the mark's gameplay effect and the focus tracking rules.
- Define parrot control, vision sharing, vulnerability, and return behavior.
- Choose the captain's and parrot's names; design the ultimate and story details beyond the known backstory.

---

## Implementation Note

The current `PlayerManager.HEROES` roster contains only Ex Navy Officer and Octopus in a Barrel. No Captain scene, resource, or implementation is currently registered. The `HeroBase` code has a generic ability-node swap hook, but that does not mean Captain's kit or form swapping is implemented.
