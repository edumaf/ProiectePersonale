--!strict
--[[
	Types

	Shared type definitions. Kept in one place so the config modules, the server
	services and the client controllers all agree on the same shapes.

	Nothing here has runtime behaviour - it is types plus an empty table so the
	module is requireable.
]]

-- Numeric codes from Enums. Aliased so signatures read as intent, not `number`.
export type AttackDirection = number
export type CombatPhase = number
export type TeamId = number
export type RoundState = number
export type HitResult = number
export type EffectKind = number
export type PointState = number

-- Per-attack phase durations, in seconds.
export type WeaponTiming = {
	Windup: number,
	Release: number,
	Recovery: number,
}

-- A single primitive making up a procedurally built weapon model.
-- Offsets are in weapon-local space where -Z points from the grip to the tip
-- (matching CFrame.LookVector), +Y is the "spine" of the blade.
export type PartSpec = {
	Size: Vector3,
	Offset: Vector3,
	Color: Color3,
	Material: Enum.Material,
	Shape: Enum.PartType?,
}

export type WeaponDef = {
	Id: string,
	Name: string,
	Kind: string, -- "Melee" | "Ranged"
	Description: string,

	-- Arrays indexed by AttackDirection code (1..4). Built by the config module
	-- from readable named tables, so tuning stays human-friendly.
	Damage: { number },
	Timings: { WeaponTiming },
	StaminaCost: { number },

	Range: number, -- studs from grip to tip; also the melee reach
	GripOffset: Vector3, -- where the grip sits relative to the character root
	MaxTargets: number, -- cleave cap per swing

	BlockStaminaDrain: number, -- stamina taken from a defender who blocks this
	BlockPenetration: number, -- 0..1 fraction of damage that leaks through a block
	PoiseDamage: number, -- reserved: stagger pressure, unused in MVP

	Model: { PartSpec },

	-- Ranged only.
	DrawTime: number?,
	ProjectileSpeed: number?,
	ProjectileGravity: number?,
	ProjectileLifetime: number?,
}

export type ClassDef = {
	Id: string,
	Name: string,
	Description: string,
	MaxHealth: number,
	WalkSpeed: number,
	StaminaMax: number,
	Weapons: { string }, -- weapon ids; [1] is equipped on spawn
	HasShield: boolean,
	BlockDamageMultiplier: number, -- damage taken through a successful block
	BlockAngleDegrees: number, -- total width of the frontal block cone
	DamageReduction: number, -- 0..1 flat armour reduction applied last
	BodyColor: Color3,
	AccentColor: Color3,
}

-- A capture point in the sequential push mode.
export type CapturePointDef = {
	Id: string,
	Name: string,
	Position: Vector3,
	Radius: number,
	Height: number,
	CaptureSeconds: number, -- time for a single attacker to take it alone
	-- Spawn position attackers get *after* this point falls.
	AttackerSpawnAfter: Vector3?,
}

export type SpawnZoneDef = {
	Team: TeamId,
	Position: Vector3,
	Radius: number,
	-- Only usable once this many points have been captured (nil = always).
	RequiresCaptures: number?,
}

-- Live per-player combat state owned by the server. This is the authoritative
-- copy of what a player is doing; the client mirrors it for animation only.
export type CombatState = {
	player: Player,
	character: Model?,
	humanoid: Humanoid?,
	root: BasePart?,
	alive: boolean,
	spawnedAt: number,

	classId: string,
	weaponId: string,

	phase: CombatPhase,
	phaseStart: number, -- os.clock() when the current phase began
	phaseEnd: number, -- os.clock() when it will end (Idle/Blocking: math.huge)
	direction: AttackDirection,
	-- Timings of the attack currently in flight, already scaled by exhaustion.
	-- Snapshotted at the start of the windup so the numbers cannot change
	-- underneath a swing that is already committed.
	timing: WeaponTiming?,

	-- Release-window hit tracing bookkeeping.
	traceAlpha: number, -- how far through the release window the last trace got
	traceRootCF: CFrame?, -- root CFrame at the previous trace, for swept casts
	hitsThisSwing: { [Model]: boolean },
	hitCount: number,

	blocking: boolean, -- guard is actually up right now
	blockHeld: boolean, -- player is holding the block input (may be mid-attack)
	blockStart: number,
	sprinting: boolean, -- actually sprinting this instant (moving, has stamina)
	sprintHeld: boolean, -- sprint key is down; re-applied whenever you go idle

	stamina: number,
	staminaMax: number,
	lastStaminaSpend: number,
	exhaustedUntil: number,

	drawStart: number, -- ranged: when the draw began (0 = not drawing)

	lastAttacker: Player?, -- for kill attribution
	lastAttackerAt: number,

	lastSentStamina: number,
	lastStatusSend: number,
}

return {}
