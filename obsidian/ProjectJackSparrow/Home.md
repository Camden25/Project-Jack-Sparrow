# Project Jack Sparrow

> Pirate horror themed 4v4 hero shooter. Woodblock print visual style. Fast movement. Built in Godot 4 with GodotSteam.

---

## Quick Links

### 📋 Planning
- [[Todo]]
- [[Ideas & Backlog]]
- [[Architecture]]

### 🦸 Heroes
- **In the current runtime roster:** [[Ex Navy Officer]], [[Octopus in a Barrel]]
- **Design only / not registered:** [[Captain]], [[Scout Sword Dude]], [[Cannoneer]], [[Hook]], [[Surgeon]]

### 🎮 Gamemodes
- [[Control Point]]
- [[Claim]] *(planned)*

### 🔧 Systems
- [[Networking]]
- [[Ability System]]
- [[Weapon System]]
- [[Game Flow]]
- [[Matchmaking & Servers]]

---

## Project Status

| Area | Status |
|---|---|
| Core networking | ✅ Working |
| Hero select | ✅ Working |
| Control point gamemode | ✅ Functional; ownership, contest, zone presence, and progress sync verified |
| Return to lobby | ✅ Working |
| Runtime hero roster | 🟡 2 heroes registered (Ex Navy Officer, Octopus in a Barrel) |
| Ex Navy Officer | 🟡 Musket, flintlock, dash, smoke, and charge-based Volley ultimate attached |
| Octopus in a Barrel | ✅ Shotgun, grapple, and Drop Anchor working |
| Map | 🟡 World scene is a blockout built from prototype geometry |
| Character models | ❌ Capsule placeholders in playable hero scenes |
| Audio | ❌ Not started |
| Woodblock shader | ❌ Not started |
| Dedicated servers | 🟡 Basic ENet helpers only; no integrated/deployed flow |
| Matchmaking | ❌ Not started |

---

## Design Pillars

- **4v4 target** — small team, every player matters. Current lobby code caps a session at 6 players, not 8.
- **Pirate horror** — not cartoony pirates, not gore horror. Woodblock print aesthetic. Dread and atmosphere.
- **Fast movement** — grapple, dash, anchor. Vertical maps. Never feels slow.
- **Disruption ultimates** — ultimates are strong but not solo carry. Best with coordination.
- **Round-based target** — Arenas-inspired tight structure with hero select each round. Current code selects before the match; ControlPointMode restarts intermediate rounds itself, and its default win target is one capture.
