# Todo

## 🔴 Bugs

- [ ] **Lobby player list** — names not always correct on join

---

## 🟠 Priority — Do These First

- [ ] **Character models and rigs** — all heroes need models. Placeholder capsules are fine for testing but needed before any playtest.
- [ ] **Captain hero** — resolve the open kit/story choices, then implement. See [[Captain]].
- [x] **Ex Navy Officer Volley** — the charge-based Volley ultimate is attached to the hero scene. See [[Ex Navy Officer]].
- [ ] **Win/loss screen** — currently just a print statement. Needs actual UI.
- [ ] **Audio** — basic audio manager, weapon SFX, ability SFX, hit confirm, death/respawn, ambient.

---

## 🟡 Gameplay Systems

- [ ] **Spectator mode** — mid-game joiners become spectators instead of getting spawned or hero-selecting into a live round.
- [x] **Healing charge wiring** — add a `healing_done` emitter and verify ultimate charge when a healing hero becomes playable; damage-based charge and Ex Navy Officer's Volley are already active.
- [ ] **Round flow** — if the design requires hero select every round, update `ControlPointMode`/`GameFlowManager`; intermediate point wins currently restart the round without reopening selection.
- [ ] **Multi-use abilities** — `uses_remaining` is stubbed out in `ability.gd`, not implemented.
- [ ] **Match history / score summary** — show before returning to lobby.
- [ ] **Claim gamemode** — multiple rotating control points. See [[Claim]].
- [ ] **Settings menu** — sensitivity, audio, graphics.
- [ ] **Round win/loss announcement** — visual/audio moment when a round ends.
- [ ] **Countdown timer** — visible to players before round starts.
- [ ] **Hero select polish** — currently very bare.

---

## 🟡 Heroes

- [ ] **Captain** — implement recon-focused kit. See [[Captain]].
- [ ] **Octopus in a Barrel** — design and implement ultimate. See [[Octopus in a Barrel]].
- [x] **Ex Navy Officer**
- [ ] **Scout Sword Dude** — resolve Ability 2, ultimate, and story, then implement. See [[Scout Sword Dude]].
- [x] **Prototype Cannoneer** — ally-cannon, ultimate, story, and final art. See [[Cannoneer]].
- [ ] **Cannoneer** — implement ultimate
- [ ] **Hook** — define full kit and hook behavior, then implement. See [[Hook]].
- [x] **Prototype Surgeon** — graybox a ranged Burst Rifle plus Quick Dose and Field Wrap healing abilities; test whether supporting allies is engaging and legible. Defer a complete kit, story, and final art. See [[Surgeon]].
- [ ] **Surgeon** — design and implement ultimate

Prototype these two before expanding the full roster. Keep both prototypes intentionally small, run playtests, then decide whether to iterate, redesign, or cut before investing in full kits and polish.

---

## 🟡 Visuals

- [ ] **Woodblock outline + hatching shader** — core visual identity. Low priority until gameplay is solid.
- [ ] **Bullet tracer stylization** — fit woodblock aesthetic.
- [ ] **Smoke effect visual** — currently just a placeholder.
- [ ] **Weapon viewmodels** — all heroes.
- [ ] **Hit marker polish**.
- [ ] **Anchor chain visual**.
- [ ] **Grapple rope for non-local players** — current net variables are not in the scene replication config and remote rope rendering is not wired.

---

## 🟡 Technical / Infrastructure

- [ ] **Debug flag system** — replace all print statements with debug flags.
- [ ] **Dedicated server setup** — Hetzner VPS or AWS GameLift with Spot Instances. See [[Matchmaking & Servers]].
- [x] **Steam App ID**
- [ ] **Steam achievements and stats**.
- [ ] **Mid-game joining** — spectator mode first, then proper late-join flow.
- [ ] **Queue server** — simple Python/Node.js service for matchmaking. See [[Matchmaking & Servers]].
- [ ] **Elo skill rating** — post-launch after match data exists. See [[Matchmaking & Servers]].

---

## ✅ Done

- [x] Steam P2P networking (GodotSteam)
- [x] Lobby create/join
- [x] Player registration and sync
- [x] Hero select overlay
- [x] Spawn system (server authoritative, client confirm)
- [x] Player movement with movement override for abilities
- [x] Hitscan weapon with lag compensation
- [x] Tracer system via EffectsManager
- [x] Generic projectile spawner (ProjectileRegistry)
- [x] Control point gamemode
- [x] Round/match flow with GameFlowManager
- [x] Return to lobby (same Steam connection)
- [x] HUD with ability slots and cooldowns
- [x] Kill feed
- [x] Respawn manager
- [x] Grapple ability (Octopus)
- [x] Drop Anchor ability (Octopus)
- [x] Dash (Ex Navy Officer)
- [x] Smoke canister (Ex Navy Officer)
- [x] Rope visual on grapple
- [x] Control-point ownership, contest, zone-presence, and progress sync
