 Control Point

> One team captures a single point to win the round. First to X round wins takes the match.

**Status:** ✅ Functional in the tested build, including capture/recapture, contest behavior, zone presence, and client progress sync.

---

## Rules

- Single control point in the center of the map
- The controlling team gains **round progress** (0.0–1.0) over time even when nobody is in the zone. This is intentional and matches Overwatch's objective scoring.
- **Control** is determined by `capture_progress` (0.0 = Team A, 1.0 = Team B)
- A team captures by standing on the point long enough to move `capture_progress` to its side.
- Players in the zone affect capture/recapture and contesting; an empty zone does not stop the current owner's round score.
- First team to reach 100% progress wins the round
- First team to reach `wins_needed` round wins takes the match; the current World scene uses the script default of 1

---

## Behavior Details

| Situation | Effect |
|---|---|
| Only Team A on a neutral point | Capture progress moves toward Team A |
| Only Team B on a neutral point | Capture progress moves toward Team B |
| Both teams present | Capture progress is contested; the current owner can still score, capped at 99% while an opponent is present |
| Nobody on point | The controlling team's round progress continues; capture progress stays unchanged |
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

## Balance Notes

- `PROGRESS_RATE = 0.01` per second — about 100 seconds to fill from 0% while controlling the point; this continues while the zone is empty.
- `CAPTURE_RATE = 0.2` per second — a neutral point starts at 50%, so an uncontested initial capture takes about 2.5 seconds.
- Overtime threshold at 99% means matches can extend if teams trade control at the end
