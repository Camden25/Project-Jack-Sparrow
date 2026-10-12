# Claim

> Multiple control points rotate or are contested simultaneously. More chaotic than single Control Point.

**Status:** ❌ Not started — design phase

---

## Concept

- Multiple control points on the map
- Teams claim points by capturing them (same mechanism as [[Control Point]])
- Points may activate sequentially, simultaneously, or rotate on a timer
- Scoring based on points held over time, or first to claim X points

---

## Design Variants

### Sequential
- One point active at a time
- When captured, next point activates at a new location
- Teams fight through the map point by point

### Simultaneous  
- All points active at once
- Teams split or focus — strategic choice
- Score accumulates based on points held

### Rotating
- Points activate and deactivate on a timer
- Creates dynamic map control that shifts around

---

## Implementation Notes

- Extends `GameMode` like `ControlPointMode`
- Multiple `ControlPoint` nodes in the scene
- `ClaimMode` manages which points are active and tracks scoring
- Scoring UI needs updating to show multi-point state
- Map design matters more here — point placement determines flow

---

## Design Questions

- How many points? 3 is standard (A/B/C in CS, 3-point King of the Hill)
- Does each point have equal value or are some worth more?
- Time limit or score limit?
- Does this mode work with 4v4 or does it need bigger teams?
