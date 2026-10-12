# Control Point

> One team captures a single point to win the round. First to X round wins takes the match.

**Status:** 🟡 Implemented; client sync, neutral capture behavior, and ownership recapture need fixes/testing.

---

## Rules

- Single control point in the center of the map
- Teams gain **progress** (0.0–1.0) while `controlling_team` is set to them. Current code does not require players to remain on the point for this progress to accrue.
- **Control** is determined by `capture_progress` (0.0 = Team A, 1.0 = Team B)
- A team captures by standing on the point long enough to move `capture_progress` to its side.
- In code, the point is considered contested when a team other than the current controlling team is present, even if the controlling team has no players on the point; the controlling team's round progress then caps at 99%.
- Ownership/recapture issue: when a team controls the point, any opponent presence sets `contested` and returns before capture progress can move toward the other team. The current logic therefore stalls ownership changes until the round resets.
- Neutral-point edge case: with no controlling team and both teams present, the current `contested` expression is false; Team A's capture-progress branch wins the `if`/`elif` check.
- First team to reach 100% progress wins the round
- First team to reach `wins_needed` round wins takes the match; the current World scene uses the script default of 1

---

## Behavior Details

| Situation | Effect |
|---|---|
| Only Team A on a neutral point | Capture progress moves toward Team A |
| Only Team B on a neutral point | Capture progress moves toward Team B |
| Any opponent present while a team owns the point | Treated as contested, even if the owner is absent; round progress caps at 99% and capture/recapture returns early |
| Both teams present while no team controls the point | Current code is not considered contested; Team A capture-progress branch wins the `if`/`elif` check |
| Nobody on point after ownership is set | Owning team's round progress still increases; capture progress is unchanged |
| Team controls point | That team's round progress increases |

---

## Implementation

- **ControlPoint (Area3D)** — detects players, tracks capture_progress, emits signals
- **ControlPointMode (GameMode)** — tracks round wins, listens to `captured` signal, calls `end_round` at the win threshold; otherwise it waits 3 seconds and starts the next round itself
- **GameFlowManager** — listens to `round_ended`, manages state machine, calls back to `ControlPointMode`

### Key Files
```
res://maps/scripts/control_point.gd
res://maps/scripts/control_point_mode.gd
res://maps/scripts/game_mode.gd
res://maps/scripts/game_flow_manager.gd
```

### Signals
- `captured(team)` — a team has fully captured the point
- `control_changed(team)` — the controlling team changed
- `progress_changed(data)` — progress values updated (sent to HUD via GameModeEvents)

---

## HUD Display

- Text label shows current round progress for both teams
- Win counter shows rounds won per team

---

## Known Issues

- Progress not always updating on client in all scenarios — needs testing
- Neutral point with both teams present is not treated as contested; Team A's capture-progress branch wins.
- An opponent entering an owned point freezes capture progress; the current logic does not allow ordinary recapture until reset.
- Round progress continues for the controlling team even when no players remain in the zone.

---

## Balance Notes

- `PROGRESS_RATE = 0.1` per second — about 10 seconds to fill from 0% while continuously controlling the point
- `CAPTURE_RATE = 0.2` per second — a neutral point starts at 50%, so an uncontested initial capture takes about 2.5 seconds; ordinary recapture is currently blocked by the contested logic
- Overtime threshold at 99% means matches can extend if teams trade control at the end
