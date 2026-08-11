--!strict
--[[
	Enums

	Every value that crosses the network is a small integer, not a string.
	With 100 players the RemoteEvent traffic is the main scaling risk, so
	"Overhead" (8 bytes + string overhead) becomes 3 (1 byte).

	Each enum has a matching `*Name` array for logging/UI. Index it with the
	numeric code: Enums.AttackDirectionName[Enums.AttackDirection.Overhead].
]]

local Enums = {}

-- Which of the four melee attacks a player threw. Chosen client-side from the
-- mouse movement direction at the moment the attack button goes down.
Enums.AttackDirection = {
	Left = 1, -- horizontal swing travelling right-to-left across the screen
	Right = 2, -- horizontal swing travelling left-to-right
	Overhead = 3, -- vertical chop from above
	Stab = 4, -- straight thrust
}
Enums.AttackDirectionName = { "Left", "Right", "Overhead", "Stab" }
Enums.AttackDirectionCount = 4

-- Server-authoritative combat state machine. The server owns this; the client
-- mirrors it optimistically for animation only.
Enums.CombatPhase = {
	Idle = 1,
	Windup = 2, -- attack committed, can still be feinted
	Release = 3, -- blade is live, server is tracing hits this whole window
	Recovery = 4, -- attack finished, cannot act
	Blocking = 5, -- guard raised
	Staggered = 6, -- got parried / blockbroken, cannot act
	Drawing = 7, -- ranged: pulling the bowstring
	Dead = 8,
}
Enums.CombatPhaseName =
	{ "Idle", "Windup", "Release", "Recovery", "Blocking", "Staggered", "Drawing", "Dead" }

Enums.TeamId = {
	Attackers = 1,
	Defenders = 2,
}
Enums.TeamIdName = { "Attackers", "Defenders" }

Enums.RoundState = {
	Waiting = 1, -- not enough players
	Starting = 2, -- countdown, players frozen at spawn
	InProgress = 3,
	Ended = 4, -- score screen
}
Enums.RoundStateName = { "Waiting", "Starting", "InProgress", "Ended" }

-- How a hit resolved. Drives both damage and the effect the client plays.
Enums.HitResult = {
	Hit = 1,
	Blocked = 2, -- defender was guarding within their block cone
	Parried = 3, -- defender raised guard inside the parry window -> attacker staggers
	BlockBroken = 4, -- defender was guarding but had no stamina left
	Ignored = 5, -- friendly fire, already-hit target, dead target, etc.
}
Enums.HitResultName = { "Hit", "Blocked", "Parried", "BlockBroken", "Ignored" }

-- Cosmetic-only events broadcast to nearby clients over an UnreliableRemoteEvent.
-- Dropping one of these costs a visual, never a gameplay outcome.
Enums.EffectKind = {
	SwingStart = 1, -- someone began a windup (kind, character, weaponId, direction)
	SwingRelease = 2, -- windup ended, blade is live
	Feint = 3,
	Impact = 4, -- landed a hit (kind, character, position, hitResult)
	GuardUp = 5,
	GuardDown = 6,
	Stagger = 7,
	Arrow = 8, -- spawn a client-side arrow tracer (kind, origin, velocity)
	Death = 9,
	DrawStart = 10, -- bow being pulled
	DrawEnd = 11, -- bow released or cancelled
}

-- Client -> server ranged actions, sent as RangedRequest(action, aim).
Enums.RangedAction = {
	Draw = 1,
	Release = 2,
	Cancel = 3,
}

Enums.DamageCause = {
	Melee = 1,
	Ranged = 2,
	Environment = 3,
}

-- Objective point ownership.
Enums.PointState = {
	Defender = 1, -- held by defenders, not yet the active front line
	Contested = 2,
	Captured = 3,
	Locked = 4, -- further down the line, cannot be touched yet
}

table.freeze(Enums.AttackDirection)
table.freeze(Enums.CombatPhase)
table.freeze(Enums.TeamId)
table.freeze(Enums.RoundState)
table.freeze(Enums.HitResult)
table.freeze(Enums.EffectKind)
table.freeze(Enums.RangedAction)
table.freeze(Enums.DamageCause)
table.freeze(Enums.PointState)

return table.freeze(Enums)
