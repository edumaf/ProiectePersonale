# Medieval Battle — 50v50 Roblox melee combat

Large-scale team melee combat in the spirit of Chivalry 2: directional swings,
blocks, parries, feints, stamina, and a sequential capture-point siege for up to
100 players.

This is the MVP. The goal is a fun, playable core loop — not monetisation, not
progression, not an art pass.

---

## Getting set up

Roblox Studio is not a filesystem project, so the source lives here and syncs
into Studio with [Rojo](https://rojo.space). **Rojo is the only tool you need** —
a single binary, no toolchain manager, no package install.

### Just want to open the game and play it?

```sh
rojo build -o MedievalBattle.rbxlx
```

Double-click the file — Studio opens with the whole game in it. Nothing else to
install, no plugin. Edits to `src/` will not appear until you build again, so
this is for looking, not developing. (The file is gitignored: a place file is
build output, never source.)

### Setting up properly

1. **Install Rojo.** Grab the binary for your OS from the
   [releases page](https://github.com/rojo-rbx/rojo/releases) (use 7.4.x), unzip
   it, and put it somewhere on your `PATH`. Check it worked:

   ```sh
   rojo --version        # should print: Rojo 7.4.4
   ```

   *Optional, for the team:* [Rokit](https://github.com/rojo-rbx/rokit) reads
   `rokit.toml` in this folder and gives everyone the identical Rojo and StyLua
   versions (`rokit install`). Worth doing once we are all working on this
   daily, since project-file format changes between Rojo majors. It is genuinely
   optional — nothing in the project requires it.

   (If you find older instructions mentioning **Aftman**: that was Rokit's
   predecessor and is no longer maintained. Do not install it.)

2. **Install the Rojo plugin in Studio** — run `rojo plugin install`, or search
   the Studio toolbox for "Rojo". The plugin is what lets Studio talk to the
   sync server; it cannot read your files on its own.

3. **Start the server and connect:**

   ```sh
   cd MedievalBattle
   rojo serve
   ```

   In Studio, open a new baseplate, click the Rojo plugin button, and press
   *Connect*. The whole `src/` tree appears in the correct services and stays in
   sync as you edit. Save the place locally so you do not repeat this each time.

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

The quick smoke test — two players spawn on opposite teams; flicking the mouse
and clicking produces four visibly different swings; a swing that connects takes
health off and one into a wall does not reach through it; holding RMB eats a hit
and drains stamina; raising the guard *just before* impact parries and staggers
the attacker.

**`docs/TESTING.md` has the full per-system checklist** — hit registration,
blocking and parry timing, feints, the bow, and the round loop, with the config
values to shrink while iterating.

**Test performance with a small number of players first.** Two to eight clients
tells you whether the systems work; it tells you nothing about 100-player
replication cost. `CombatConfig.PlayerCollisions` is the first lever to pull if a
large test drops the server frame rate — 100 colliding humanoids in one blob is
real physics work.

---

## Status

Built and playable:

- Rojo project scaffold, strict-Luau modules, shared config
- Greybox siege map, two teams with auto-balance, spawn/respawn with forward
  spawn zones that unlock as the line moves
- Directional melee (left/right/overhead/stab), windup → release → recovery,
  server-authoritative swept hit tracing, cleave
- Blocking, parries, block-breaks, feints, stamina and exhaustion
- Four classes, six weapons including a bow with drop and draw-scaled power
- Sequential capture points, full round loop with scoring
- HUD: health, stamina, round clock, objective track, kill feed, class select

Deliberately not built: monetisation, progression, matchmaking, mobile/console
input, voice, art pass. **No sound at all yet** — no audio assets are referenced
anywhere, and it is probably the single biggest feel upgrade available for the
effort.

Known rough edges worth knowing about before you playtest:

- Character *body* animation is untouched — only the weapon animates, so a
  swing reads from the blade, not the arms. Procedural arm posing or real
  animation assets are the next visual step.
- Swing timing is server-start-on-receipt, so high-ping players' swings land
  slightly later than they look (see `docs/GOTCHAS.md`).
- The greybox ramps are eyeballed; expect to nudge `MapConfig.Blocks` once you
  walk the map.

## Further reading

- `docs/TESTING.md` — a per-system Studio checklist, and how to test
  performance without fooling yourself
- `docs/GOTCHAS.md` — the Roblox-specific traps this codebase works around, and
  why the workarounds are load-bearing
