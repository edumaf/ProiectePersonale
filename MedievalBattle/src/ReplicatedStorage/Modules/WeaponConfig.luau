--!strict
--[[
	WeaponConfig

	Pure data. Adding or retuning a weapon must never require touching combat
	code - if you find yourself wanting to, add a field here instead.

	Reading the numbers:
	  * Damage/Timings/StaminaCost are authored with named directions and
	    converted to arrays indexed by Enums.AttackDirection for fast lookup.
	  * Range is both the visual blade length and the hit-trace reach, measured
	    from the grip. Keep them equal - a weapon whose Range exceeds its model
	    hits people who can see they were never touched.
	  * BlockPenetration is the fraction of damage that still lands on a
	    successful block (0 = a clean block eats everything).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = require(ReplicatedStorage.Modules.Enums)
local Types = require(ReplicatedStorage.Modules.Types)

type WeaponDef = Types.WeaponDef
type WeaponTiming = Types.WeaponTiming

-- Guard against someone renumbering Enums.AttackDirection without updating the
-- authoring order below.
assert(
	Enums.AttackDirection.Left == 1
		and Enums.AttackDirection.Right == 2
		and Enums.AttackDirection.Overhead == 3
		and Enums.AttackDirection.Stab == 4,
	"WeaponConfig authoring order is tied to Enums.AttackDirection"
)

type Named<T> = { Left: T, Right: T, Overhead: T, Stab: T }

local function byDirection<T>(t: Named<T>): { T }
	return { t.Left, t.Right, t.Overhead, t.Stab }
end

local function allDirections<T>(v: T): { T }
	return { v, v, v, v }
end

local function timing(windup: number, release: number, recovery: number): WeaponTiming
	return { Windup = windup, Release = release, Recovery = recovery }
end

local STEEL = Color3.fromRGB(178, 185, 196)
local DARK_STEEL = Color3.fromRGB(122, 128, 138)
local WOOD = Color3.fromRGB(102, 72, 48)
local LEATHER = Color3.fromRGB(58, 44, 36)
local BRASS = Color3.fromRGB(168, 137, 74)

local WeaponConfig = {}

--[[
	Model part specs. Weapon-local space: -Z runs from the grip out to the tip
	(so it lines up with CFrame.LookVector), +X is the flat of the blade.
	Offsets are the part centre relative to the grip.
]]
local Weapons: { [string]: WeaponDef } = {

	Sword = {
		Id = "Sword",
		Name = "Arming Sword",
		Kind = "Melee",
		Description = "Fast and honest. Good damage, good recovery, nothing special.",

		Damage = byDirection({ Left = 32, Right = 32, Overhead = 36, Stab = 27 }),
		Timings = byDirection({
			Left = timing(0.36, 0.20, 0.36),
			Right = timing(0.36, 0.20, 0.36),
			Overhead = timing(0.42, 0.20, 0.40),
			Stab = timing(0.30, 0.16, 0.32),
		}),
		StaminaCost = byDirection({ Left = 10, Right = 10, Overhead = 11, Stab = 8 }),

		Range = 5.2,
		GripOffset = Vector3.new(1.35, -0.8, -0.5),
		MaxTargets = 1,

		BlockStaminaDrain = 16,
		BlockPenetration = 0,
		PoiseDamage = 10,

		Model = {
			{ Size = Vector3.new(0.26, 0.26, 1.1), Offset = Vector3.new(0, 0, 0.35), Color = LEATHER, Material = Enum.Material.Leather },
			{ Size = Vector3.new(0.34, 0.34, 0.34), Offset = Vector3.new(0, 0, 0.95), Color = BRASS, Material = Enum.Material.Metal, Shape = Enum.PartType.Ball },
			{ Size = Vector3.new(1.3, 0.22, 0.26), Offset = Vector3.new(0, 0, -0.3), Color = BRASS, Material = Enum.Material.Metal },
			{ Size = Vector3.new(0.3, 0.1, 4.5), Offset = Vector3.new(0, 0, -2.65), Color = STEEL, Material = Enum.Material.Metal },
		},
	},

	Mace = {
		Id = "Mace",
		Name = "Flanged Mace",
		Kind = "Melee",
		Description = "Slow, brutal, and punishing to block. Poor thrusts.",

		Damage = byDirection({ Left = 40, Right = 40, Overhead = 46, Stab = 24 }),
		Timings = byDirection({
			Left = timing(0.48, 0.22, 0.48),
			Right = timing(0.48, 0.22, 0.48),
			Overhead = timing(0.55, 0.22, 0.52),
			Stab = timing(0.40, 0.18, 0.44),
		}),
		StaminaCost = byDirection({ Left = 15, Right = 15, Overhead = 17, Stab = 11 }),

		Range = 4.6,
		GripOffset = Vector3.new(1.35, -0.8, -0.5),
		MaxTargets = 1,

		-- Blocking a mace hurts: this is what makes the Knight a shield-breaker.
		BlockStaminaDrain = 28,
		BlockPenetration = 0.15,
		PoiseDamage = 22,

		Model = {
			{ Size = Vector3.new(0.28, 0.28, 3.0), Offset = Vector3.new(0, 0, -1.0), Color = WOOD, Material = Enum.Material.Wood },
			{ Size = Vector3.new(0.85, 0.85, 0.9), Offset = Vector3.new(0, 0, -2.9), Color = DARK_STEEL, Material = Enum.Material.Metal },
			{ Size = Vector3.new(1.05, 0.2, 0.7), Offset = Vector3.new(0, 0, -2.9), Color = DARK_STEEL, Material = Enum.Material.Metal },
			{ Size = Vector3.new(0.2, 1.05, 0.7), Offset = Vector3.new(0, 0, -2.9), Color = DARK_STEEL, Material = Enum.Material.Metal },
		},
	},

	Spear = {
		Id = "Spear",
		Name = "Spear",
		Kind = "Melee",
		Description = "Longest reach in the game. Thrusts hurt, swings do not.",

		Damage = byDirection({ Left = 22, Right = 22, Overhead = 26, Stab = 44 }),
		Timings = byDirection({
			Left = timing(0.42, 0.20, 0.42),
			Right = timing(0.42, 0.20, 0.42),
			Overhead = timing(0.46, 0.20, 0.46),
			Stab = timing(0.38, 0.22, 0.40),
		}),
		StaminaCost = byDirection({ Left = 11, Right = 11, Overhead = 12, Stab = 12 }),

		Range = 9.5,
		GripOffset = Vector3.new(1.2, -0.7, -0.4),
		MaxTargets = 1,

		BlockStaminaDrain = 14,
		BlockPenetration = 0,
		PoiseDamage = 8,

		Model = {
			{ Size = Vector3.new(0.22, 0.22, 8.4), Offset = Vector3.new(0, 0, -3.9), Color = WOOD, Material = Enum.Material.Wood },
			{ Size = Vector3.new(0.34, 0.12, 1.5), Offset = Vector3.new(0, 0, -8.7), Color = STEEL, Material = Enum.Material.Metal },
		},
	},

	Greatsword = {
		Id = "Greatsword",
		Name = "Greatsword",
		Kind = "Melee",
		Description = "Huge arcs that cleave through several enemies. Slow to recover.",

		Damage = byDirection({ Left = 45, Right = 45, Overhead = 52, Stab = 38 }),
		Timings = byDirection({
			Left = timing(0.58, 0.28, 0.52),
			Right = timing(0.58, 0.28, 0.52),
			Overhead = timing(0.66, 0.28, 0.58),
			Stab = timing(0.48, 0.22, 0.48),
		}),
		StaminaCost = byDirection({ Left = 19, Right = 19, Overhead = 21, Stab = 16 }),

		Range = 7.2,
		GripOffset = Vector3.new(1.25, -0.7, -0.5),
		-- The one weapon that cleaves. This is the whole reason the Vanguard
		-- exists in a 50v50 blob fight.
		MaxTargets = 3,

		BlockStaminaDrain = 34,
		BlockPenetration = 0.2,
		PoiseDamage = 26,

		Model = {
			{ Size = Vector3.new(0.3, 0.3, 1.9), Offset = Vector3.new(0, 0, 0.6), Color = LEATHER, Material = Enum.Material.Leather },
			{ Size = Vector3.new(0.4, 0.4, 0.4), Offset = Vector3.new(0, 0, 1.6), Color = DARK_STEEL, Material = Enum.Material.Metal, Shape = Enum.PartType.Ball },
			{ Size = Vector3.new(1.9, 0.25, 0.3), Offset = Vector3.new(0, 0, -0.45), Color = DARK_STEEL, Material = Enum.Material.Metal },
			{ Size = Vector3.new(0.42, 0.14, 6.3), Offset = Vector3.new(0, 0, -3.7), Color = STEEL, Material = Enum.Material.Metal },
		},
	},

	Dagger = {
		Id = "Dagger",
		Name = "Dagger",
		Kind = "Melee",
		Description = "Archer sidearm. Very fast, very short, very weak.",

		Damage = byDirection({ Left = 20, Right = 20, Overhead = 22, Stab = 26 }),
		Timings = allDirections(timing(0.22, 0.14, 0.26)),
		StaminaCost = allDirections(6),

		Range = 2.8,
		GripOffset = Vector3.new(1.35, -0.8, -0.5),
		MaxTargets = 1,

		BlockStaminaDrain = 8,
		BlockPenetration = 0,
		PoiseDamage = 4,

		Model = {
			{ Size = Vector3.new(0.22, 0.22, 0.8), Offset = Vector3.new(0, 0, 0.3), Color = LEATHER, Material = Enum.Material.Leather },
			{ Size = Vector3.new(0.6, 0.16, 0.2), Offset = Vector3.new(0, 0, -0.2), Color = BRASS, Material = Enum.Material.Metal },
			{ Size = Vector3.new(0.22, 0.09, 2.3), Offset = Vector3.new(0, 0, -1.5), Color = STEEL, Material = Enum.Material.Metal },
		},
	},

	Bow = {
		Id = "Bow",
		Name = "Hunting Bow",
		Kind = "Ranged",
		Description = "Hold to draw, release to loose. Arrows drop over distance.",

		-- Ranged ignores direction; the array is filled uniformly so every
		-- weapon has the same shape and callers never branch on Kind for stats.
		Damage = allDirections(46),
		Timings = allDirections(timing(0.85, 0.05, 0.45)),
		StaminaCost = allDirections(12),

		Range = 3.5,
		GripOffset = Vector3.new(1.2, -0.6, -0.6),
		MaxTargets = 1,

		BlockStaminaDrain = 0,
		BlockPenetration = 1, -- arrows are not stopped by a raised weapon
		PoiseDamage = 6,

		DrawTime = 0.85,
		ProjectileSpeed = 260,
		ProjectileGravity = 70,
		ProjectileLifetime = 6,

		Model = {
			{ Size = Vector3.new(0.18, 3.4, 0.3), Offset = Vector3.new(0, 0, -0.2), Color = WOOD, Material = Enum.Material.Wood },
			{ Size = Vector3.new(0.06, 3.2, 0.06), Offset = Vector3.new(0, 0, 0.05), Color = Color3.fromRGB(220, 214, 200), Material = Enum.Material.Fabric },
		},
	},
}

WeaponConfig.All = Weapons

WeaponConfig.Ids = (function(): { string }
	local ids = {}
	for id in Weapons do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end)()

function WeaponConfig.find(id: string): WeaponDef?
	return Weapons[id]
end

function WeaponConfig.get(id: string): WeaponDef
	local def = Weapons[id]
	if not def then
		error(`WeaponConfig: unknown weapon id "{id}"`, 2)
	end
	return def
end

--[[
	Returns the phase durations for one attack, scaled by `timeScale`
	(the exhausted penalty, class modifiers, ...). Always returns a fresh table
	so callers can't mutate the config.
]]
function WeaponConfig.getTiming(def: WeaponDef, direction: number, timeScale: number?): WeaponTiming
	local base = def.Timings[direction] or def.Timings[1]
	local scale = timeScale or 1
	return {
		Windup = base.Windup * scale,
		-- The release window is the "blade is live" time. Scaling it with the
		-- exhaust penalty would make tired players hit for *longer*, so only
		-- windup and recovery are penalised.
		Release = base.Release,
		Recovery = base.Recovery * scale,
	}
end

function WeaponConfig.getDamage(def: WeaponDef, direction: number): number
	return def.Damage[direction] or def.Damage[1]
end

function WeaponConfig.getStaminaCost(def: WeaponDef, direction: number): number
	return def.StaminaCost[direction] or def.StaminaCost[1]
end

return WeaponConfig
