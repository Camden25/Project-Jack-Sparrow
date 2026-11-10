# Cannoneer

> A stubborn artillery bruiser who turns open sightlines into danger, then turns the cannon into a way to move the crew.

**Status:** 🟡 Graybox scene, cannonball primary, Recoil Hop, and Crew Shot are wired; not registered in the runtime roster. Crew Shot still needs multiplayer playtesting.

## Design Goal

The Cannoneer should make space by threatening predictable routes with slow, weighty explosive shots. They are durable enough to hold a firing lane, but should still need cover and teammates: the cannon is powerful when lined up, not a shield or a constant source of damage.

**Combat loop:** choose a lane → read an enemy's movement → lead a cannonball → use recoil or a team launch to reposition → reload in cover and set up the next shot.

The fun should come from landing a satisfying prediction and making a clever movement/team play, not from unavoidable splash damage or long crowd-control locks.

## Proposed Kit

| Slot      | Name       | Role                                                                         | Status                           |
| --------- | ---------- | ---------------------------------------------------------------------------- | -------------------------------- |
| Primary   | Cannon     | Slow physics projectile; direct hit plus smaller falloff splash damage       | 🟡 Graybox wired                 |
| Ability 1 | Recoil Hop | Recoil launches the Cannoneer backward and upward                             | 🟡 Graybox wired                 |
| Ability 2 | Crew Shot  | An ally opts in, boards the cannon, and gets launched toward a chosen area   | 🟡 Graybox wired; playtesting needed |
| Ultimate  | Press-Gang | A telegraphed harpoon shot captures and launches one enemy, displacing them  | Design; needs playtesting        |

No separate weapon secondary is proposed yet. In the current input routing, secondary fire activates an ability; keep the first prototype on that path rather than inventing a second weapon trigger.

## Primary: Cannonball

- Server-simulated projectile with gravity, visible travel time, direct-hit damage, and a smaller-radius splash.
- A direct hit is the reward for leading a moving target. Splash pressures a position but should not match direct-hit damage.
- Impact can give a modest, readable knockback. Avoid a large blast radius that makes near misses feel like hits.
- One loaded shot and a deliberate reload create clear firing windows. The Cannoneer should not win a sustained damage race by spamming.
- Use a distinct launch sound and visible projectile/trail so opponents can track the shot and learn its travel time.
- **Initial graybox tuning:** 28 m/s launch speed, 9.8 m/s² downward gravity, 60 direct damage, up to 30 splash damage within 3.5 m with distance falloff and world-geometry line of sight, one round, and a 2-second reload. These are starting values, not balance targets.

## Abilities

### Recoil Hop (Ability 1)

Activate to recoil backward from the horizontal aim direction and launch upward. It is a movement tool with no damage.

- The graybox adds 9 m/s of backward velocity and 6 m/s upward velocity, and briefly preserves that launch for 0.12 seconds before returning control.
- Usable in the air as well as on the ground; the upward launch is retained even when aiming nearly straight up.
- The current cooldown is 8 seconds. These values should be tuned in playtests.

### Crew Shot (Ability 2)

Crew Shot has three states:

1. **Pickup Mode:** The Cannoneer activates Ability 2. Any eligible teammate within pickup range receives an accept prompt. The first teammate to accept is picked up; the server must accept only one response if multiple teammates accept nearly simultaneously.
2. **Shoot Mode:** The accepted teammate is held in the cannon and cannot move independently or leave pickup range. They can still cancel after being picked up. The Cannoneer aims and can press primary fire to launch them, or use Ability 2 to drop/release them.
3. **Normal Mode:** After launch, release, cancellation, or interruption, the Cannoneer returns to normal weapon behavior and the teammate regains movement.

- Pickup requires explicit teammate acceptance; never load or fire an ally without consent.
- Ally practice dummies auto-accept when in range so Crew Shot can be tested without a second player. Launch momentum is preserved, and the held passenger appears as a translucent silhouette to the Cannoneer.
- Show clear state feedback to both players: Pickup Mode and its range to the Cannoneer, an accept prompt to eligible teammates, and the held teammate plus launch/cancel affordances once accepted.
- Once picked up, range no longer applies because the teammate is held in the cannon. The teammate's cancel action must remain available while held.
- A launch is a mobility play, not a damaging projectile. Landing deals no damage or stun, and the ally regains control on landing.
- Release the teammate safely near the Cannoneer if they cancel or the Cannoneer drops them. Death, disconnect, respawn, or ability interruption must also cleanly end the held state.
- The Cannoneer temporarily gives up ordinary cannon firing while in Pickup Mode or Shoot Mode.
- Controls: Ability 2 enters Pickup Mode; G accepts or cancels; H declines; primary fire launches; Ability 2 exits either active mode or releases the passenger.
- Carrying a passenger slows the Cannoneer's movement to 65% speed. The 10-second Crew Shot cooldown starts only after launching a passenger, including a practice dummy; entering Pickup Mode or releasing without launching does not start it.

This is the most distinctive team fantasy and requires multiplayer playtesting for ownership, collision, respawn, and launch behavior.

## Ultimate: Press-Gang

Fire a slow, clearly marked harpoon shell. Hitting an enemy briefly tethers them; after a short, interruptible loading tell, the cannon launches them along a visible arc. The goal is to break an enemy formation or knock a defender off a strong position, not to delete them.

- The target can dodge the projectile, break line of sight during the tether, or be freed if the Cannoneer is interrupted before the launch.
- The launch should deal little or no damage by itself. Avoid chaining the forced movement into a guaranteed kill.
- Keep the tether and launch short enough that the target is not removed from play for an excessive time.
- Test whether the forced movement is fun for both players. If it feels frustrating, replace the capture with an ultimate cannon barrage or a large knockback shot rather than increasing its damage.

## Role, Strengths, and Counterplay

- **Strengths:** threatens open lanes, pressures grouped enemies, punishes predictable movement, and offers unusual team repositioning.
- **Weaknesses:** slow shot travel, reload downtime, vulnerability while setting up, and less value in cramped spaces or against agile targets.
- **Counterplay:** dodge or take cover from the visible projectile; push during reload; flank the firing position; separate before splash lands.
- Make the hero somewhat tougher than a duelist, but do not compensate for missed shots with excessive health, passive damage reduction, or broad splash.
- Do not slow ordinary movement just to sell the weight fantasy. Put the weight in the cannon's firing/reload cadence and projectile feel.

## Graybox Plan

Prototype the primary first, then validate Recoil Hop and Crew Shot as graybox abilities. Defer Press-Gang, final art, and story until the core kit is fun.

Keep the first pass intentionally tunable: projectile speed, gravity, direct/splash damage, blast radius, reload time, and knockback. Validate those values in a multiplayer test, not only against stationary targets.

### Questions the prototype should answer

1. Can players reliably see, understand, and dodge a cannonball?
2. Is leading a moving target satisfying at useful engagement distances?
3. Does splash create pressure without making near misses feel unfair?
4. Does the slower firing rhythm still fit the game's fast movement?
5. Does Recoil Hop provide enough self-repositioning without making the Cannoneer feel like a mobile duelist?

If these answers are poor, change the projectile or role before investing in the ally-launch and capture mechanics.

## Implementation Notes

- The cannon uses `ProjectileWeaponBase` and the server-authoritative projectile lifecycle in [[Weapon System]]; never apply damage from a client visual.
- The cannonball uses server-side collision and splash overlap checks; verify direct/splash tuning and impact readability in playtests.
- Recoil Hop uses the existing movement-override pattern and clears the override on timeout or cancellation.
- Crew Shot uses server-arbitrated invites and mode changes, while the passenger's owning client follows the seat and applies launch velocity. Multiplayer playtesting is still required; Press-Gang needs its own ownership, interruption, and cleanup rules.
- See [[Ability System]] for ability slots, cooldowns, and current input routing.
