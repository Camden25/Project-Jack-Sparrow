# Ideas & Backlog

Unstructured ideas, half-baked concepts, and things to revisit later.

---

## Hero Ideas

### [[Surgeon]]
- Current seed: primary fire may heal; all details beyond that are undecided.

### Unnamed — Ghost Ship Crew Member
- Stealth mechanics — disappear, reappear elsewhere
- Horror angle: you hear them before you see them

---

## Gamemode Ideas

### Escort
- One team escorts a ship/cart across the map
- Other team defends
- Classic Overwatch payload but on a dock or cliff path

### King of the Hill (Rotating)
- Single point but it moves to a new location each round
- Forces teams to reposition constantly
- Could use existing ControlPoint code with a teleport on round win

### Artifact Recovery
- An item spawns on the map
- Teams fight to carry it to their base
- Carrying player has limited abilities
- Horror artifact — cursed chest, haunted compass, etc.

---

## Map Ideas

### The Dock
- Elevated dock structure over water
- Multiple levels — dock level, ship deck, crow's nest
- Water below is a kill zone (fall damage / instant death)
- Great for grapple play

### The Wreck
- Sunken ship half-buried in an island
- Interior and exterior areas
- Dark, claustrophobic inside / open outside
- Control point inside the wreck — must enter to cap

### The Lighthouse
- Vertical map centered on a lighthouse tower
- Control point at the top, spawn rooms at the bottom
- Grapple shines here — climbing the outside of the tower
- Anchor drops from the top are devastating

---

## Visual / Shader Ideas

### Woodblock Outline Shader
- Hard dark outlines on all geometry and characters
- Hatching patterns on shadows instead of smooth gradients
- Limited color palette — 3-4 tones per object
- Woodblock print / linocut aesthetic
- Reference: Arranger (game), old Japanese woodblock prints, ukiyo-e

### Weather Effects
- Heavy rain that affects visibility
- Fog that rolls in and out
- Could interact with smoke canister — hard to tell real fog from smoke

### Death Effect
- Character crumbles into ink/woodblock print fragments
- Not blood — ink splatters

---

## Audio Ideas

### Music
- No constant music during match — ambient sound only
- Music swells at round win/loss
- Horror-themed: creaking wood, distant waves, something wrong

### Hit Confirm
- Satisfying clunk/thud for melee
- Sharp crack for musket
- Wet sound for shotgun at close range

### Ability SFX
- Grapple: rope whoosh + hook clang on attach
- Anchor: deep metallic crash on landing
- Smoke: hiss of canister, soft pop of smoke deploying
- Retreat dash: quick air burst
- Volley: distant cannon fire, then multiple impacts

---

## Technical Ideas

### Debug Flag System
```gdscript
# Global debug flags
const DEBUG_NETWORKING = false
const DEBUG_LAG_COMP = false
const DEBUG_ABILITIES = false

# Usage
if DEBUG_NETWORKING:
    print("player registered: ", peer_id)
```
Replace all bare `print()` calls. Can be toggled per system.

### Spectator Mode
- Mid-game joiners become spectators
- Free-fly camera or follow-cam attached to a living player
- No HUD except spectator UI showing who you're watching
- Can join next round when hero select opens

### Replay System (long-term)
- Record all inputs and positions server-side
- Play back for highlight clips or bug reports
- Complex but valuable for marketing

---

## Business / Launch Ideas

- **Demo** before paid launch — steam next fest
- **Community server browser** — players host their own servers, browser in lobby UI
- **Seasonal cosmetics** — skins that don't affect gameplay, fund server costs
- **Streamer mode** — hide Steam names for privacy while streaming
