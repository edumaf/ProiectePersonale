# Medieval Battle — 50v50 Roblox melee combat

Large-scale team melee combat in the spirit of Chivalry 2: directional swings,
blocks, parries, feints, stamina, and a sequential capture-point siege for up to
100 players.

This is the MVP. The goal is a fun, playable core loop — not monetisation, not
progression, not an art pass.

---

## Getting set up

Roblox Studio is not a filesystem project, so the source lives here and syncs
into Studio with [Rojo](https://rojo.space). **Rojo is the only thing you need to
install** — a single binary, no installer, no toolchain manager, no package
manager. You need Windows or macOS, because Studio does not run on Linux.

Every block below is copy-paste-able. Run them from inside the `MedievalBattle`
folder.

### Step 1 — get the code

The game lives on `main`, so there is no branch to switch to.

```sh
git clone https://github.com/edumaf/ProiectePersonale.git
cd ProiectePersonale/MedievalBattle
```

Already cloned? Just pull:

```sh
git checkout main
git pull origin main
cd MedievalBattle
```

In GitHub Desktop: make sure the branch dropdown says **main**, click **Fetch
origin** / **Pull origin**, then *Repository → Open in Command Prompt* (or
*Open in Terminal*) and `cd MedievalBattle`.

### Step 2 — install Rojo

The binary is downloaded straight into this folder, so there is no `PATH` to
configure and nothing installed system-wide. `.gitignore` already excludes it,
so it will never be committed.

> **Open your terminal *inside* `MedievalBattle` first.** These commands
> download into whatever folder you are currently in, and Rojo has to sit next
> to `default.project.json` to find the project. A terminal opens in your home
> folder (`C:\Users\<you>`) by default, which is the wrong place.
>
> - **Windows:** open the `MedievalBattle` folder in File Explorer, click the
>   address bar, type `powershell`, press Enter. (Or Shift + right-click on
>   empty space in the folder → *Open PowerShell window here*.)
> - **macOS:** right-click the folder → *Services → New Terminal at Folder*.
> - **Or by hand** — with a GitHub Desktop clone this is usually:
>   ```powershell
>   cd "$HOME\Documents\GitHub\ProiectePersonale\MedievalBattle"
>   ```
>
> Confirm before pasting anything: `ls` must list `default.project.json`, `src`,
> `docs` and `README.md`. If it does not, you are in the wrong folder — and if
> you already downloaded Rojo there, just delete the stray `rojo.exe` and start
> again from the right one.

**Windows** — paste into **PowerShell** (not cmd):

```powershell
# Must print True - if it prints False you are in the wrong folder, stop here
Test-Path .\default.project.json

# Windows PowerShell 5.1 defaults to a TLS version GitHub refuses. Without this
# the download fails, often without an obvious error, and you end up with no
# rojo.exe and a confusing "not recognized" message later.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Invoke-WebRequest -Uri "https://github.com/rojo-rbx/rojo/releases/download/v7.7.0/rojo-7.7.0-windows-x86_64.zip" -OutFile "rojo.zip"
Expand-Archive -Path ".\rojo.zip" -DestinationPath "." -Force
Remove-Item .\rojo.zip

Get-ChildItem .\rojo.exe      # must list the file
.\rojo.exe --version          # must print Rojo 7.7.0
```

If the download will not work at all, fetch
[the zip](https://github.com/rojo-rbx/rojo/releases/download/v7.7.0/rojo-7.7.0-windows-x86_64.zip)
in a browser, extract it, and drag `rojo.exe` into this folder by hand. Exactly
the same result.

**macOS, Apple Silicon** (M1/M2/M3/M4) — paste into **Terminal**:

```sh
curl -L -o rojo.zip https://github.com/rojo-rbx/rojo/releases/download/v7.7.0/rojo-7.7.0-macos-aarch64.zip
unzip -o rojo.zip && rm rojo.zip
chmod +x rojo
xattr -d com.apple.quarantine rojo 2>/dev/null
./rojo --version
```

**macOS, Intel** — identical, but with `macos-x86_64` in the URL:

```sh
curl -L -o rojo.zip https://github.com/rojo-rbx/rojo/releases/download/v7.7.0/rojo-7.7.0-macos-x86_64.zip
unzip -o rojo.zip && rm rojo.zip
chmod +x rojo
xattr -d com.apple.quarantine rojo 2>/dev/null
./rojo --version
```

The last line must print `Rojo 7.7.0`. If it does, you are done installing.

Two notes on the above: the Windows asset really is named `windows-x86_64` (not
`win64`, which is what most guides guess), and the `xattr` line clears macOS
Gatekeeper's quarantine flag, which otherwise blocks the first run with a
"cannot be opened" dialog.

> **Always type `.\rojo.exe`, never plain `rojo`.**
> PowerShell does not run programs from the current folder unless you prefix
> `.\` — that is a deliberate safety behaviour, and it is why plain `rojo` gives
> you:
>
> ```
> rojo : The term 'rojo' is not recognized as the name of a cmdlet...
> ```
>
> That message does **not** mean the download failed. Check with `ls rojo.exe`:
> if the file is listed, just re-run the command with `.\` in front. (Plain
> `rojo` only works once you have moved the binary onto your `PATH`, which is
> worth doing later but is not needed for any of this.)

### Updating Rojo later

There is no `rojo update` command — it is a standalone binary, so updating means
downloading the new one over the old one. Re-run the Step 2 block for your OS
with the new version number in the URL, then check `.\rojo.exe --version`.

Two things to know:

- **Stop `rojo serve` first.** Windows will not overwrite a running executable,
  and `Expand-Archive` fails with a file-in-use error that does not obviously say
  so.
- **Tell the others.** The project file format can change between Rojo majors, so
  everyone should move together. If you are using Rokit, bump the version in
  `rokit.toml`, commit it, and `rokit install` gives the whole team the same
  build.

7.7.0 and 7.4.4 produce a byte-identical place file from this project, so
upgrading between them is a non-event.

### Step 3a — just play it

```powershell
.\rojo.exe build -o MedievalBattle.rbxlx     # Windows
./rojo build -o MedievalBattle.rbxlx         # macOS
```

Double-click the resulting file: Studio opens with the whole game in it. No
plugin, no sync server. Edits to `src/` will not show up until you build again,
so this is for playing, not developing. (The place file is gitignored — it is
build output, never source. The name is arbitrary; `.rbxlx` just keeps it a text
format.)

### Step 3b — develop with live sync

```powershell
.\rojo.exe plugin install     # once: installs the Rojo plugin into Studio
.\rojo.exe serve              # leave this running
```

On macOS: `./rojo plugin install` and `./rojo serve`.

In Studio: **File → New**, then open the **Rojo** plugin from the Plugins tab
and press **Connect**. The whole `src/` tree appears in the right services and
stays in sync as you edit files. Save the place locally so you do not redo this
each session.

Daily loop from then on: `.\rojo.exe serve` → Connect → edit files in your
editor → press Play in Studio.

### Step 4 — set max players (manual, easy to forget)

`Players.MaxPlayers` is a place setting and *cannot* be changed from a script.
In Studio: **Home → Game Settings → Basic Info → Max Players → 100**.

Studio allows up to 200 without approval; beyond that you need Roblox's
large-server programme. The server prints a warning on boot if it is still below
100, because otherwise you will "test 50v50" against the default 12-player cap
and never notice.

### Step 5 — run it with two players

**Test tab → Clients and Servers → Players: 2 → Start.**

You get a server window and two client windows. Combat needs two characters, so
solo *Play* only tells you things load, never that they work. The server window
should print `[MedievalBattle] server ready in Nms` — if that line is missing,
something failed at boot and the Output window says what.

### Working in VS Code (recommended)

Every command above works in VS Code's integrated terminal, and this is the
easiest way to run them: **File → Open Folder →** select `MedievalBattle`
(the folder, not the repo root), then **Ctrl + `** opens a terminal already in
the right place. No `cd`, and the wrong-folder mistake becomes impossible.

The terminal is PowerShell on Windows, so the `.\rojo.exe` prefix still applies.
`rojo serve` runs until you stop it, so give it its own tab
(**Ctrl + Shift + `**) and keep working in the first one.

Two extensions worth having, both configured by files already in this repo:

| Extension | Why |
| --- | --- |
| `JohnnyMorganz.luau-lsp` | Luau autocomplete, inline type errors, go-to-definition. Reads the `.luaurc` here, so strict mode is on automatically. |
| `JohnnyMorganz.stylua` | Formats on save from `stylua.toml`, so four people produce identical formatting and reviews never fill up with whitespace diffs. |

There is also a Rojo extension in the marketplace that can start and stop the
sync server from the VS Code UI, if you would rather not keep a terminal tab
open for it.

VS Code's Source Control panel covers commits, pulls and branches, so you do not
need GitHub Desktop as well.

### Command reference

Windows form shown; on macOS use `./rojo` in place of `.\rojo.exe`.

| Command | What it does |
| --- | --- |
| `.\rojo.exe build -o MedievalBattle.rbxlx` | Build a place file you can double-click |
| `.\rojo.exe serve` | Start the sync server for live editing |
| `.\rojo.exe plugin install` | Install the Studio plugin (once) |
| `.\rojo.exe --version` | Check the install worked |

### If something goes wrong

| Symptom | Cause |
| --- | --- |
| `The term 'rojo' is not recognized...` | Missing `.\` prefix — PowerShell does not run programs from the current folder. Use `.\rojo.exe`. |
| `.\rojo.exe` also "not recognized" | The file really is missing — the download failed. Usually the TLS default: run the `SecurityProtocol` line, then Step 2 again. `Get-ChildItem .\rojo.exe` tells you whether it is there. |
| `Invoke-WebRequest` fails or hangs | Same TLS cause, or a proxy. Download the zip in a browser and drag `rojo.exe` into this folder instead. |
| `Rojo: found no project file` | You are in the wrong folder. `ls` should show `default.project.json`. |
| macOS: *"rojo cannot be opened"* | Gatekeeper quarantine — run the `xattr -d com.apple.quarantine rojo` line. |
| Studio opens but the map is empty | You opened a blank baseplate instead of the built `.rbxlx`, or the Rojo plugin is not *Connect*ed. |

<sub>*Optional:* [Rokit](https://github.com/rojo-rbx/rokit) reads `rokit.toml`
here and pins identical Rojo/StyLua versions for the whole team (`rokit
install`). Worth it once we are all on this daily, since the project-file format
changes between Rojo majors — but nothing in the project requires it. If you
find older instructions mentioning **Aftman**, that was Rokit's predecessor and
is no longer maintained; do not install it.</sub>

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
    Combat/             hit tracing, damage, stamina, arrows, rate limiting, effects
    Classes/            loadouts and procedurally built weapon models
    Rounds/             team balance, round state machine, capture points
    Spawning/           spawn pipeline, respawn timers, collision groups
    Map/                greybox builder

  StarterPlayerScripts/
    Client.client       boot order, in one place
    Combat/             input, prediction, weapon animation, camera, bow, effects
    UI/                 health/stamina HUD, round + objective HUD, kill feed,
                        class select, shared style
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

Launch two players as in step 5 above. They spawn on opposite teams (the
balancer alternates), at opposite ends of the map — to cut the walk while
iterating, move both start zones in `MapConfig.SpawnZones` near `x = 0`.

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
