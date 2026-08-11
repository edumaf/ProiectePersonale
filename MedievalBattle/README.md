# Medieval Battle — 50v50 Roblox melee combat

Large-scale team melee combat in the spirit of Chivalry 2: directional swings,
blocks, parries, feints, stamina, and a sequential capture-point siege for up to
100 players.

This is the MVP. The goal is a fun, playable core loop — not monetisation, not
progression, not an art pass.

---

## Getting set up (5 minutes)

Roblox Studio is not a filesystem project, so the source lives here and syncs
into Studio with [Rojo](https://rojo.space).

1. **Install the tools.** With [Aftman](https://github.com/LPGhatguy/aftman):

   ```sh
   cd MedievalBattle
   aftman install          # installs the pinned rojo + stylua from aftman.toml
   ```

   (Or install Rojo 7.4.x by hand — but pinning keeps all four of us on one
   version, which matters because project-file format changes between majors.)

2. **Install the Rojo plugin in Studio** — `rojo plugin install`, or get it from
   the Studio plugin marketplace.

3. **Start the server and connect:**

   ```sh
   rojo serve
   ```

   In Studio, open a new baseplate, click the Rojo plugin, and press *Connect*.
   The whole `src/` tree appears in the correct services. Save the place as
   `MedievalBattle.rbxl` (it is gitignored — the place file is build output,
   never source).

   To produce a place without Studio open: `rojo build -o MedievalBattle.rbxl`.

4. **Set max players — this one is manual and easy to forget.**

   `Players.MaxPlayers` is a place setting and *cannot* be changed from a
   script. In Studio: **Home → Game Settings → Basic Info → Max Players → 100**.
   Studio allows up to 200 without approval; beyond that you need Roblox's
   large-server programme. The server prints a warning on boot if it is still
   below 100, because otherwise you will "test 50v50" with the default 12-player
   cap and never notice.

---

## Playing it

| Input | Action |
| --- | --- |
| **LMB** | Attack. The direction comes from how you flick the mouse: left/right = horizontal swings, up = overhead, down = stab. No movement = right swing. |
| **RMB** (hold) | Block. Raise it just before an impact for a **parry**, which staggers the attacker. |
| **Q** | Feint — cancel a windup in its first 65%, at a stamina cost. |
| **Shift** (hold) | Sprint. Costs stamina while you are actually moving. |
| **F** | Swap weapon (classes with two, e.g. Archer bow ↔ dagger). |
| **B** | Class select. |

The mouse is locked to the centre of the screen and your body follows the
camera. Both are load-bearing: swing direction is read from the mouse *delta*
(which Roblox only reports while the cursor is locked), and the server resolves
swing arcs and block cones from your character's facing.

---

## Layout

```
src/
  ReplicatedStorage/
    Modules/            shared, pure data + maths (server and client both read these)
      Enums             every value that crosses the network, as small integers
      Types             shared type definitions
      CombatConfig      global combat tuning (stamina, parry window, rate limits…)
      WeaponConfig      per-weapon data
      ClassConfig       per-class data
      MapConfig         capture points, spawn zones, greybox geometry
      RoundConfig       round pacing and objective rules
      SwingMath         swing arc geometry — used by BOTH hit tracing and animation
    RemoteEvents/
      Remotes           the entire network surface, in one file

  ServerScriptService/
    Main.server         boot order, in one place
    Combat/             hit tracing, damage, stamina, rate limiting, effect fan-out
    Classes/            loadouts and procedurally built weapon models
    Rounds/             teams (round state machine + objectives land here)
    Spawning/           spawn pipeline, respawn timers, collision groups
    Map/                greybox builder

  StarterPlayerScripts/
    Client.client       boot order, in one place
    Combat/             input, prediction, weapon animation, camera, effects
    UI/                 HUD
```

### Who owns what

The four systems are deliberately separated so we are not editing the same files:

| System | Files | Talks to the rest via |
| --- | --- | --- |
| Combat | `Combat/*`, `SwingMath`, `WeaponConfig`, `CombatConfig` | `CombatService.getState`, `DamageService.onKill` |
| Classes | `Classes/*`, `ClassConfig` | `CombatService.setLoadout` |
| Rounds & objectives | `Rounds/*`, `RoundConfig`, `MapConfig` | `CombatService.setCombatEnabled`, `SpawnService.*` |
| UI & client feel | `StarterPlayerScripts/*` | `Remotes` only |

Adding a weapon or a class is a table entry in a config module. If you find
yourself adding a class-specific branch to combat code, that is the signal the
config table is missing a field — add the field instead.

---

## Design decisions worth knowing before you edit

**The client never reports hits.** It sends "I pressed attack, direction 2" and
nothing else. The server runs its own copy of your windup, and during the release
window it sweeps the blade against the world itself. There is no "I hit Bob for
400 damage" message to forge, because no such message exists. Every remote
handler is behind a token-bucket rate limiter (`CombatConfig.RateLimits`).

**One shared source of swing geometry.** `SwingMath` computes the weapon's pose
for a given attack and progress. The server traces hits with it; every client
animates the weapon with it. The blade you see is the blade that was tested.

**Weapon animation costs no bandwidth.** Weapons hang off a `Motor6D` and the
client drives `C0` locally — client property writes never replicate. The server
sends roughly ten bytes per swing ("X began a left swing, 0.36s windup") and each
client derives the whole motion.

**Cosmetic traffic is unreliable and distance-filtered.** Swings, impacts and
guards go out on an `UnreliableRemoteEvent`, only to players within
`CombatConfig.EffectBroadcastRadius`. Dropping one costs a spark, never an
outcome, and it never delays the reliable channel behind it.

**Replicated properties are only written when they change.** `Humanoid.WalkSpeed`
replicates to everyone; setting it every frame for 100 players is a replication
storm for no gameplay benefit.

---

## Testing in Studio

Combat needs two characters, so use **Test → Clients and Servers → 2 players →
Start**. You get a server window plus two client windows.

Both players spawn on opposite teams (the balancer alternates), at opposite ends
of the map. Fly/walk them together, or drop `MapConfig.SpawnZones` closer while
iterating.

What to check on the barebones slice:

1. Two players spawn, on different teams, with a sword and a team-coloured
   surcoat.
2. Flicking the mouse and clicking produces four visibly different swings.
3. A swing that connects takes health off; a swing into a wall does not reach
   through it.
4. Holding RMB in front of an incoming swing eats it and drains stamina.
5. Raising the guard *just before* the hit parries it — the attacker staggers.
6. Q during the first part of a windup cancels the attack.
7. Stamina drains on attacks, blocks and sprinting, and refills after ~1s idle.
   At zero you are visibly slower for a moment.
8. Dying respawns you at your team's zone after ~6 seconds.

**Test performance with a small number of players first.** Two to eight clients
tells you whether the systems work; it tells you nothing about 100-player
replication cost. `CombatConfig.PlayerCollisions` is the first lever to pull if a
large test drops the server frame rate — 100 colliding humanoids in one blob is
real physics work.

---

## Status

Built and playable (the barebones slice):

- Rojo project scaffold, strict-Luau modules, shared config
- Greybox siege map, two teams with auto-balance, spawn/respawn
- Directional melee (left/right/overhead/stab), windup → release → recovery,
  server-authoritative swept hit tracing, cleave
- Blocking, parries, block-breaks, feints, stamina and exhaustion
- Class loadouts (four classes, five melee weapons), HUD with health and stamina

Next up: class select UI, the bow, and the capture-point round loop.

Out of scope for the MVP entirely: monetisation, progression, matchmaking,
mobile/console input, voice, art pass, sound (no audio assets are referenced
anywhere yet).
