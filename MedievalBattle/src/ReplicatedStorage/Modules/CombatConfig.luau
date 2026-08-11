--!strict
--[[
	CombatConfig

	Global combat tuning. Weapon- and class-specific numbers live in
	WeaponConfig / ClassConfig; anything that applies to *everyone* lives here.

	This module is shared: the server uses it to resolve combat, the client uses
	the same numbers to predict animations, so both sides agree on timing.
	Change a number here and both sides move together.
]]

local CombatConfig = {}

-- ---------------------------------------------------------------- stamina --

CombatConfig.StaminaMax = 100
CombatConfig.StaminaRegenRate = 16 -- per second
CombatConfig.StaminaRegenDelay = 0.9 -- seconds of not spending before regen starts
CombatConfig.ExhaustDuration = 1.4 -- how long "exhausted" lasts after hitting 0
CombatConfig.ExhaustTimeScale = 1.35 -- windup/recovery multiplier while exhausted
CombatConfig.ExhaustBlockMultiplier = 1.6 -- extra damage taken through a block while exhausted

CombatConfig.SprintStaminaDrain = 9 -- per second
CombatConfig.SprintMinStamina = 8 -- cannot start a sprint below this
CombatConfig.SprintSpeedBonus = 7 -- studs/s added to the class walk speed
CombatConfig.BlockStaminaDrainPerSecond = 2.5 -- passive cost of holding a guard up

-- ------------------------------------------------------------- blocking ----

-- A block only counts if the incoming attacker is inside this cone, measured
-- from the defender's look vector. Class defs can widen it (shields).
CombatConfig.DefaultBlockAngleDegrees = 110

-- Raising your guard this recently before an impact turns the block into a
-- parry: no damage, no stamina loss, and the attacker staggers.
CombatConfig.ParryWindow = 0.28
CombatConfig.ParryStaggerDuration = 1.0
CombatConfig.BlockBreakStaggerDuration = 1.2 -- when a block lands with no stamina
CombatConfig.BlockedAttackerStaminaCost = 8 -- attacker pays for hitting a guard

-- Guard cannot be raised instantly out of an attack - this is the delay after
-- a recovery ends. Keeps "attack, insta-block" from being strictly optimal.
CombatConfig.BlockRaiseDelay = 0.1

-- ------------------------------------------------------------- feinting ----

-- You may cancel a windup during the first N% of it. Late feints are impossible,
-- which keeps feints a read rather than a reaction-proof cancel.
CombatConfig.FeintWindowFraction = 0.65
CombatConfig.FeintStaminaCost = 14
CombatConfig.FeintRecovery = 0.22 -- forced recovery after a feint

-- ---------------------------------------------------------- hit tracing ----

-- The server samples the blade at these fractions of the weapon length each
-- tick and sweeps a small sphere from the previous position to the new one.
-- Sampling several points along the blade means a swing connects with the
-- middle of the sword, not only the tip.
CombatConfig.BladeSamples = { 0.45, 0.72, 1.0 }
CombatConfig.TraceRadius = 0.55 -- studs; sphere swept along the blade path
CombatConfig.MaxTraceStepsPerTick = 3 -- sub-steps for very fast swings (anti-tunnelling)

-- Bodies are ignored beyond this; a cheap sanity check before any raycasting.
CombatConfig.MaxMeleeRange = 18

-- Extension point: multiply damage by the limb that was hit. Flat 1.0 for MVP
-- so tuning stays simple - fill these in to get Chivalry-style limb damage.
CombatConfig.LimbMultipliers = {
	Head = 1.0,
	UpperTorso = 1.0,
	LowerTorso = 1.0,
	LeftUpperArm = 1.0,
	RightUpperArm = 1.0,
	LeftLowerLeg = 1.0,
	RightLowerLeg = 1.0,
}
CombatConfig.DefaultLimbMultiplier = 1.0

-- --------------------------------------------------------- replication -----

-- Cosmetic combat events are only sent to clients within this radius of the
-- action. At 100 players an unfiltered broadcast is 100x the traffic of a
-- filtered one, and nobody can see a swing 300 studs away anyway.
CombatConfig.EffectBroadcastRadius = 180
CombatConfig.EffectBroadcastRadiusSq = 180 * 180

-- Own-stamina updates are only pushed to the owning client, and only when the
-- value actually moved. 10 Hz is smooth enough for a bar.
CombatConfig.StatusSendInterval = 0.1
CombatConfig.StatusSendMinDelta = 0.5

-- ------------------------------------------------------ anti-exploit -------

-- The client can only ever *request* an action. Everything below caps how often
-- it may ask; a client over the limit is ignored (and logged), never trusted.
-- These are deliberately generous - a legit player mashing hard must not trip
-- them, but a script firing 500 attacks/second gets nothing.
CombatConfig.RateLimits = {
	Attack = { tokens = 6, perSecond = 5 },
	Block = { tokens = 10, perSecond = 8 },
	Feint = { tokens = 5, perSecond = 4 },
	Sprint = { tokens = 10, perSecond = 8 },
	Ranged = { tokens = 6, perSecond = 5 },
	ClassSelect = { tokens = 4, perSecond = 1 },
}

-- --------------------------------------------------------------- misc ------

CombatConfig.RespawnDelay = 6
CombatConfig.SpawnProtection = 2 -- seconds of immunity after spawning
CombatConfig.FriendlyFire = false

--[[
	Player-vs-player physical collision.

	true  - bodies block each other. Formations, shield walls and chokepoints
	        all work, which is the point of a 50v50 medieval game.
	false - players pass through each other. Much cheaper: 100 colliding
	        humanoids in one blob is a genuine physics-solver cost, and it is
	        the first thing to try if a 100-player test tanks the server frame
	        rate.

	Flip this and re-test before doing anything more exotic.
]]
CombatConfig.PlayerCollisions = true

return table.freeze(CombatConfig)
