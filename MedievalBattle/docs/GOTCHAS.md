# Roblox gotchas and performance traps

Things this codebase already works around, and why. Read this before "fixing"
something here that looks unnecessary — most of it is load-bearing.

---

## Networking

### The client cannot be trusted with hits, so it is never asked

The client sends `AttackRequest(direction)` and nothing else. The server runs
its own wind-up timer and traces the blade itself. There is no
"I hit Bob" message anywhere in the protocol, so there is nothing to forge.

The honest cost: the server starts the wind-up when the request *arrives*, so a
player on 120ms ping is ~120ms behind their own animation. The whole exchange is
400–900ms, so it plays fine, but it is a real trade. The eventual fix is a
client timestamp clamped to a sane window — deliberately not in the MVP, because
a rushed timestamp is exactly how you get "my swing landed 900ms ago" exploits.

### Every remote handler is rate limited

A RemoteEvent can be fired as fast as a modified client likes. Every handler
takes a token from a per-player bucket first (`CombatConfig.RateLimits`). The
limits are loose enough that mashing is never throttled, and dropped requests
are silent — kicking on a false positive from a laggy client is worse than
ignoring a packet.

### Cosmetic traffic is unreliable and distance-filtered

Swings, impacts, guards and arrows go out on an `UnreliableRemoteEvent`, only to
players within `EffectBroadcastRadius`. Two reasons: an unfiltered
`FireAllClients` per swing is O(players) packets in a fight that produces dozens
of swings a second, and unreliable traffic cannot head-of-line block the
reliable channel carrying actual gameplay.

Rule: if losing a message would change an outcome, it does not belong on that
channel.

### Replicated properties are only written when they change

`Humanoid.WalkSpeed` replicates to every client. Setting it every frame for 100
players is a replication storm for nothing, so `updateWalkSpeed` compares before
assigning. The same reasoning applies to any property on a replicated instance —
check before you write.

### Attributes replicate to *everyone*

`Instance:SetAttribute` is convenient and replicates automatically, which makes
it a trap for anything high-frequency: there is no interest management, so a
value that changes 20 times a second reaches all 100 clients 20 times a second.

Attributes here are used only for values that change rarely and that everyone
needs: `TeamId` on characters (per spawn), `ClassId`, `InvulnerableUntil`.
Stamina — which changes constantly and only matters to its owner — goes over a
throttled, owner-only remote instead.

### Clocks

`os.clock()` is a local monotonic clock: fine for server-side durations, useless
across the network. Anything a client has to render a countdown from uses
`Workspace:GetServerTimeNow()`, which is synchronised. Sending one end-timestamp
per state change beats sending "seconds remaining" once a second to 100 people.

---

## Physics and queries

### Weapons must be invisible to raycasts

Every weapon part is `CanQuery = false`, `CanTouch = false`, `CanCollide =
false`, `Massless = true`. Miss any of these and:

- **CanQuery** — the server's swing sweep hits the attacker's own blade, or a
  bystander's, instead of the enemy behind it. In a 50v50 crowd there are
  hundreds of weapon parts in the air.
- **Massless** — an unmassed sword welded to a character changes how the
  humanoid moves.

The same applies to the surcoat, the plume, spawn pads and capture-point
markers. Anything decorative near a fight gets `CanQuery = false`.

### Swept casts, not point checks

A greatsword tip covers ~14 studs during a 0.28s release. At 30 server FPS that
is over 2 studs per tick, and a point check would sail straight past a target
between two frames. `traceSwing` sweeps from the previous blade position to the
current one and sub-steps if that gap is large.

The same reasoning applies to arrows: `RangedService` raycasts from where the
arrow was to where it now is, every step.

### Character collisions are the biggest single lever

100 colliding humanoids in one chokepoint is genuine physics work every step.
`CombatConfig.PlayerCollisions` flips the whole thing through one collision
group. It defaults to **on** because shield walls and chokepoints are the point
of the mode — but it is the first thing to try when a large test drops the
server frame rate.

### One Heartbeat, not one per player

Combat runs a single `RunService.Heartbeat` connection that walks the player
state table. A connection per player would mean 100 scheduler entries a frame
doing the same work. Objectives use their own accumulator at 4 Hz because
nothing about a capture bar needs 60 Hz.

---

## Characters and spawning

### `Players.MaxPlayers` cannot be set from a script

It is a place setting: **Game Settings → Basic Info → Max Players**. Studio
allows up to 200; above that needs Roblox's large-server programme.
`Main.server` warns on boot if it is under 100, because the failure mode is
silent — you cap at 12 and "test 50v50" without noticing.

### `CharacterAutoLoads = false` and a fixed spawn order

Roblox's automatic spawn would drop a character into the world before it has a
team, a loadout, or a position. `SpawnService` turns it off and does the steps in
a fixed order: team → `LoadCharacter` → tag → loadout → combat state → place +
spawn protection. A character in the world with no `TeamId` attribute is
unhittable by design, which is the safety net if that order is ever broken.

### Mouse delta needs a locked cursor

`InputObject.Delta` for mouse movement is only meaningful while
`MouseBehavior = LockCenter`. Directional attacks read that delta, so the lock is
a gameplay requirement, not a camera preference. Any UI that unlocks the cursor
must restore it — `ClassSelect` routes every close path through one function for
exactly this reason.

### The body must follow the camera

The server resolves swing arcs and block cones from `HumanoidRootPart.CFrame`.
If the character did not turn with the camera, you would block in a direction you
are not looking. `CameraController` rotates the root every frame (the client owns
its character's physics, so it replicates for free) — the same mechanism
Roblox's own shift lock uses.

---

## Animation

### Motor6D.C0 on the client is free

Weapons hang off a `Motor6D` from the HumanoidRootPart, and each client drives
`C0` locally. Client property writes never replicate, so a hundred players
swinging costs zero bandwidth. The server sends roughly ten bytes per swing and
every client derives the motion from `SwingMath`.

This is also why there are no animation assets: nothing has to be uploaded, and
a change to a swing arc is a diff, not an asset re-upload.

### One source of swing geometry

`SwingMath` is shared. The server traces hits with it; clients animate with it.
If you change an arc, the visual and the hitbox move together — there is no
second copy to forget. Do not "optimise" by inlining a copy of the pose maths
into either side.

### Only animate what is doing something

`SwingAnimator` tracks only characters mid-action and within 220 studs. An idle
weapon needs no per-frame work at all — its Motor6D already holds the idle pose —
and a track removes itself the moment its recovery ends.

---

## Source control

### Never commit a `.rbxl`

Binary place files cannot be merged, and one person touching the map would block
everyone. `.gitignore` covers them. Everything that would otherwise be binary is
generated from code: the map from `MapConfig`, weapons from `WeaponConfig` part
specs, UI from `UIStyle`.

### Adding a remote is one line

Four people editing `default.project.json` to add RemoteEvent instances would
conflict constantly. `Remotes.luau` holds one array; adding a name to it is a
one-line diff that merges cleanly.
