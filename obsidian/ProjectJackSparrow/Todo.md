# Todo

## 🔴 Bugs

- [ ] **Drop Anchor** — fix the cooldown that is never started by the current scene-bound script; regression-test older ceiling/floor/contact reports.
- [ ] **Lobby player list** — names not always correct on join. Debounce applied, may need more work.
- [ ] **Death UI** — respawn timer doesn't always clear properly.
- [ ] **Control point** — fix ownership recapture, neutral-point contested logic, progress accruing with no players in-zone, and client progress sync.
- [ ] **Client netcode** — player sync and interpolation roughness, needs more multiplayer testing.

---

## 🟠 Priority — Do These First

- [ ] **Projectile weapon framework** — generic server-authoritative ability projectiles already exist; add reusable weapon firing/validation for a physics-based projectile primary. See [[Weapon System]].
- [ ] **Map** — develop the current prototype-geometry World blockout into a proper 4v4 map with spawn rooms, control point language, cover, sightlines, and verticality for grapple/anchor.
- [ ] **Character models and rigs** — all heroes need models. Placeholder capsules are fine for testing but needed before any playtest.
- [ ] **Captain hero** — resolve the open kit/story choices, then implement. See [[Captain]].
- [ ] **Ex Navy Officer — smoke vision** — decide/implement enemy outlines visible through smoke while ADS. Also attach and test the existing Volley script/assets as an ultimate. See [[Ex Navy Officer]].
- [ ] **Win/loss screen** — currently just a print statement. Needs actual UI.
- [ ] **Audio** — basic audio manager, weapon SFX, ability SFX, hit confirm, death/respawn, ambient.

---

## 🟡 Gameplay Systems

- [ ] **Spectator mode** — mid-game joiners become spectators instead of getting spawned or hero-selecting into a live round.
- [ ] **Ultimate charge** — hitscan and Drop Anchor emit damage, but there is no active `UltimateAbility` in the roster and no `healing_done` emitter; complete support/healing charge wiring and register/test an ultimate.
- [ ] **Round flow** — if the design requires hero select every round, update `ControlPointMode`/`GameFlowManager`; intermediate point wins currently restart the round without reopening selection.
- [ ] **Multi-use abilities** — `uses_remaining` is stubbed out in `ability.gd`, not implemented.
- [ ] **Match history / score summary** — show before returning to lobby.
- [ ] **Claim gamemode** — multiple rotating control points. See [[Claim]].
- [ ] **Escape menu** — quit, disconnect, settings.
- [ ] **Settings menu** — sensitivity, audio, graphics.
- [ ] **Round win/loss announcement** — visual/audio moment when a round ends.
- [ ] **Countdown timer** — visible to players before round starts.
- [ ] **Hero select polish** — currently very bare.
- [ ] **Roster capacity** — reconcile the 4v4 target with `NetworkManager.MAX_PLAYERS = 6` (8 players needed for 4v4).

---

## 🟡 Heroes

- [ ] **Captain** — finalize/implement recon-focused kit. See [[Captain]].
- [ ] **Octopus in a Barrel** — test/fix Drop Anchor. No Hide in Barrel is in the latest design brief. See [[Octopus in a Barrel]].
- [ ] **Ex Navy Officer** — enemy outlines through smoke while ADS. See [[Ex Navy Officer]].
- [ ] **Scout Sword Dude** — resolve Ability 2, ultimate, and story, then implement. See [[Scout Sword Dude]].
- [ ] **Cannoneer** — resolve ally/ultimate rules, Ability 2, and story, then implement. See [[Cannoneer]].
- [ ] **Hook** — define full kit and hook behavior, then implement. See [[Hook]].
- [ ] **Surgeon** — develop the healing-primary seed into a complete kit. See [[Surgeon]].

---

## 🟡 Visuals

- [ ] **Woodblock outline + hatching shader** — core visual identity. Low priority until gameplay is solid.
- [ ] **Bullet tracer stylization** — fit woodblock aesthetic.
- [ ] **Smoke effect visual** — currently just a FogVolume placeholder.
- [ ] **Weapon viewmodels** — all heroes.
- [ ] **Hit marker polish**.
- [ ] **Anchor chain visual**.
- [ ] **Grapple rope for non-local players** — current net variables are not in the scene replication config and remote rope rendering is not wired.

---

## 🟡 Technical / Infrastructure

- [ ] **Debug flag system** — replace all print statements with debug flags.
- [ ] **Dedicated server setup** — Hetzner VPS or AWS GameLift with Spot Instances. See [[Matchmaking & Servers]].
- [ ] **Steam App ID** — do NOT buy yet. Wait until close to public playtest. See [[Matchmaking & Servers]].
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
- [x] Dash (Ex Navy Officer)
- [x] Smoke canister (Ex Navy Officer)
- [x] Rope visual on grapple
