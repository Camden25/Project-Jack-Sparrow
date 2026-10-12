# Matchmaking & Servers

**Status:** ❌ Not started — design and planning phase

---

## Current State

Current multiplayer uses Steam lobbies with Steam P2P; no skill-based matchmaking or queue service is implemented. `NetworkManager` has basic ENet server/client helper methods, but no integrated lobby-to-server flow or deployed dedicated-server setup. `NetworkManager.MAX_PLAYERS` is 6 today, while the design target is 4v4 (8 players).

---

## Dedicated Servers

### Options

| Provider | Cost | Notes |
|---|---|---|
| **Hetzner** | ~$4-6/mo (CX22) | Cheapest reputable option. 2 vCPU, 4GB RAM. EU-primary, US available. Can run 4-8 simultaneous matches. Start here. |
| **Linode/Akamai** | ~$6-12/mo | Comparable specs, US/international. Slightly more reliable. |
| **AWS GameLift** | ~$0.03-0.05/hr per instance | Purpose-built for games. Auto-scaling, scales to zero. Built-in matchmaking API. ~$20-35/mo for dedicated, but only pay for actual playtime with Spot. |

### Recommendation
- **Start on Hetzner** for playtesting — cheap, simple, no infrastructure overhead
- **Move to AWS GameLift with Spot Instances** when you have real player volume — scales automatically, only pay for actual sessions

### Cost Reality (small playerbase)
- 50-200 concurrent players → ~10-25 simultaneous servers at peak
- Hetzner: $40-150/mo at that scale
- AWS GameLift Spot: $20-80/mo depending on actual playtime (60-80% discount vs on-demand)

---

## Ways to Reduce Costs

- **Hybrid hosting** — run official servers for matchmade games, allow community-hosted dedicated servers for custom lobbies. Most matches get hosted for free.
- **Region lock at launch** — US East + EU only. Covers most players, half the server count.
- **AWS GameLift Spot Instances** — 60-80% cheaper. Matches end gracefully on interruption, players requeue.
- **One-time purchase price** — $5-10 at 1000 sales = $5-10k, covers servers for years.

---

## How Dedicated Servers Work with Godot

This section is a target plan, not a verified launch procedure. `NetworkManager` defines ENet server/client methods, but the project has no call sites for them; `root.gd` always opens the lobby UI and does not parse `--dedicated-server`.

Godot exports a **headless Linux binary** — no display needed. Run it on any VPS.

```bash
./ProjectJackSparrow.x86_64 --headless --dedicated-server
```

The intended server would use the same gameplay code with `multiplayer.is_server()` true. The current helper method uses ENet on port 7777; a GameLift connection path is not implemented.

On Hetzner: small script SSH's into instance, launches the binary with match parameters (map, mode, player list).

On GameLift: fleet management handles spin-up automatically, game session callbacks hook into your code.

---

## Steam App ID

> ⚠️ **Do NOT purchase yet.**

- Costs $100 (one-time)
- Once purchased, game is visible in Valve's system and 30-day review clock starts
- Current dev uses App ID 480 (Spacewar) — works fine for P2P and lobbies
- Buy when: close to public playtest, dedicated server needs real App ID, or store page needs to go live
- The $100 is not the issue — premature visibility and review timing is

---

## Matchmaking Architecture

### Phase 1 — Steam Lobby Queue (build this first)
```
Player clicks "Play"
→ Client creates or joins a matchmaking Steam lobby
→ Lobby owner watches member count
→ When 8 players present, lobby owner contacts queue server
→ Queue server assigns a game server
→ Game server receives player list
→ All clients connect to game server
→ Match begins
```

### Queue Server (simple)
- Lightweight Python Flask or Node.js app on a $5/mo VPS
- Receives lobby-full events, assigns available servers, returns connection info
- ~100 lines of code to start
- No Steam auth needed here — trust lobby owner's report

### Phase 2 — Skill-Based Matchmaking (post-launch)
- Add Elo rating stored in database (Supabase free tier, PostgreSQL)
- Win = rating up, loss = down, amount based on opponent rating difference
- Filter lobby search by skill range:
```gdscript
Steam.addRequestLobbyListNumericalFilter("skill", local_skill - 200, Steam.LOBBY_COMPARISON_GREATER_OR_EQUAL)
Steam.addRequestLobbyListNumericalFilter("skill", local_skill + 200, Steam.LOBBY_COMPARISON_LESS_OR_EQUAL)
```
- Launch with random matchmaking, add Elo after first few hundred matches

---

## Steam Integration Notes

Steam's `ISteamMatchmaking` API (via GodotSteam) handles:
- Lobby creation and search
- Lobby metadata (game name filter, skill filter, mode)
- Member count and join events
- P2P relay while no dedicated servers

GodotSteam methods used:
- `Steam.createLobby()`
- `Steam.addRequestLobbyListStringFilter()`
- `Steam.addRequestLobbyListNumericalFilter()`
- `Steam.requestLobbyList()`
- `Steam.joinLobby()`
- `Steam.activateGameOverlayInviteDialog()`
