# Testing in Studio

Everything below is manual Studio testing. There is no automated test harness
yet — Roblox has no headless runner without extra tooling, and for an MVP the
faster loop is two Studio clients and a checklist.

## Setup

```sh
rojo serve          # in MedievalBattle/
```

Connect from the Rojo plugin in Studio, then:

**Test → Clients and Servers → Players: 2 → Start.**

You get a server window plus two client windows. Combat needs two characters, so
solo *Play* mode only tells you whether things load — it cannot tell you whether
they work.

Handy while iterating:

- The two teams spawn at opposite ends of a 500-stud map. To cut the walk, edit
  `MapConfig.SpawnZones` and move both start zones near `x = 0`, or use the
  server window's command bar to teleport a character.
- `RoundConfig.MinPlayersToStart` is 2 so a two-client test actually starts a
  round. `RoundConfig.CountdownSeconds` and `RoundSeconds` are the two numbers
  to shrink when testing round transitions.
- The server window prints `[MedievalBattle] server ready in Nms` on boot. If it
  does not appear, `Main.server` errored — check the Output window before
  debugging anything else.

---

## 1. Spawning and teams

1. Both clients spawn, at opposite ends, with a sword and a team-coloured
   surcoat and plume.
2. The two players are on *different* teams (check the Players list in the
   server window — the balancer alternates).
3. Kill one (`Humanoid.Health = 0` from the command bar, or jump off the map):
   they respawn after ~6s at their own team's spawn pad.
4. A third client joining lands on the smaller team.

## 1b. Weapon racks (the fastest way to try everything)

Each team's home spawn has a rack with one stand per weapon — Sword, Mace,
Spear, Greatsword, Dagger, Bow — labelled with its damage, windup and reach.
Walk up and press **E** to take it, no class change and no dying required.

The rack is generated from `WeaponConfig.Ids`, so a weapon you add to the config
appears there automatically with its real numbers on the label.

This is a testing tool, not a design decision: picking up a greatsword as an
Archer ignores the class system entirely. Turn it off with
`CombatConfig.WeaponRacks = false` when the game gets closer to real.

## 2. Melee: the four attacks

With the mouse locked (it is, by default), flick and click:

| Flick | Expected |
| --- | --- |
| left | horizontal swing travelling right→left |
| right | horizontal swing travelling left→right |
| up | overhead chop |
| down | thrust |
| nothing | right swing |

Look for: a visible wind-up *before* the blade moves (this is what the defender
reads), then a fast arc, then a slower return to rest. If every attack looks the
same, the mouse delta is not being read — check that the cursor is locked
(`CameraController`).

## 3. Hit registration

1. Swing through the other player: their health drops, an impact spark appears.
2. Swing at them through a wall (stand either side of the gatehouse): **no**
   damage. The blade is stopped by geometry.
3. Swing while walking past them at full speed: the hit still registers. This is
   the sub-stepped sweep doing its job — if fast-moving swings whiff, look at
   `CombatConfig.MaxTraceStepsPerTick`.
4. Stand next to a teammate and swing through them: no damage, and the swing
   continues to the enemy behind them.
5. Greatsword (Vanguard) into two enemies standing together: both take damage,
   up to `MaxTargets = 3`.

## 4. Blocking, parrying, block-breaking

1. Hold RMB facing an incoming swing: little or no damage, your stamina drops by
   a chunk.
2. Hold RMB facing *away* from the attacker: full damage. The block cone is
   frontal only.
3. Raise the guard within ~0.28s *before* the hit lands: **parry** — no damage,
   no stamina cost, and the attacker visibly staggers and cannot act for a
   second. This is the timing to tune first if the combat feels wrong.
4. Block repeatedly until stamina hits zero, then block one more hit:
   **block-break** — full damage plus a stagger.
5. Attack, then immediately press RMB during the recovery: the guard goes up
   when the recovery ends, and it cannot parry for the first 0.1s
   (`BlockRaiseDelay`). Chaining attack→instant-parry must not be free.

## 5. Feinting and stamina

1. Start a swing, press Q in the first half of the wind-up: the attack cancels,
   stamina drops, and there is a short recovery.
2. Press Q late in the wind-up: nothing happens. The window is
   `CombatConfig.FeintWindowFraction` (65%).
3. Attack repeatedly until stamina empties: "EXHAUSTED" appears, wind-ups get
   visibly slower, movement slows, and blocks start leaking damage.
4. Stop for a second: stamina refills (`StaminaRegenDelay` then `RegenRate`).
5. Hold Shift and run: stamina drains only while actually moving. Attack
   mid-sprint, then keep holding Shift — the sprint resumes on its own when the
   attack ends.

## 6. The bow (Archer)

1. Press B → Archer → you respawn with a bow.
2. Hold LMB: the bow draws over ~0.85s. Release: an arrow flies with visible
   drop over distance.
3. Release immediately after pressing: nothing is fired (under a third of a
   draw).
4. Press F: swap to the dagger and back.
5. Shoot a Knight and a Footman from the same distance: the Knight takes
   noticeably less (15% flat armour).

## 7. Classes

For each of Footman / Vanguard / Archer / Knight, check the numbers on the class
card match what you feel: health pool, speed, and how much a block leaks. The
card reads the same config combat does, so a mismatch means a genuine bug, not a
stale UI.

## 8. Round loop and objectives

Shrink `RoundConfig.RoundSeconds` to ~60 first, and `CountdownSeconds` to 3.

1. With two players, a round starts: countdown banner, both players frozen at
   their spawns, then "advance!".
2. Walk the attacker into point A's circle: the pip fills, the marker turns
   yellow, the ring colour changes on capture and a banner announces it.
3. Stand the defender in the same circle: progress **stops**.
4. Attacker leaves the circle: progress decays back down.
5. After A falls, the attacker's next respawn is at the forward zone, and point
   B becomes live. B cannot be captured before A.
6. Let the clock run out: defenders win, score screen, then a new round with
   points reset and everyone respawned.
7. Kills appear in the top-right feed with team colours, and the team score
   goes up.

---

## Performance testing

**Test the systems with 2–8 players. Test the *cost* separately, and do not
assume the two are related.** Everything above is correctness; none of it tells
you what happens at 100 players.

When you are ready to look at scale:

1. Studio's `Test → Clients and Servers` supports up to 8 local clients, and
   they share your machine's CPU. Eight local clients is a load test of your
   laptop, not of the server.
2. Real numbers come from a published place with real players. Watch the server
   window's **F9 → Server → Scripts** and the MicroProfiler
   (`Ctrl+Alt+F6`) for `Heartbeat` cost.
3. The three things that will show up first, in order:
   - **Character collisions.** 100 humanoids shoving in a chokepoint is real
     physics work. `CombatConfig.PlayerCollisions = false` is the first lever.
   - **Hit tracing.** Cost is proportional to *players mid-swing*, not players.
     `CombatConfig.BladeSamples` (3 today) and `MaxTraceStepsPerTick` are the
     dials.
   - **Effect fan-out.** Cosmetic events are already distance-filtered;
     `EffectBroadcastRadius` trades visibility for bandwidth.
