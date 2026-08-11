--!strict
--[[
	ClassConfig

	Pure data, same rule as WeaponConfig: adding a class must never require a
	change in combat code. ClassService reads this table and nothing else.

	Balance dials, roughly in order of importance:
	  MaxHealth              - how many hits you eat
	  BlockDamageMultiplier  - damage taken through a *successful* block
	                           (0 = perfect shield, 1 = blocking does nothing)
	  BlockAngleDegrees      - how wide your guard is; shields are forgiving
	  DamageReduction        - flat armour, applied after everything else
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Modules.Types)

type ClassDef = Types.ClassDef

local Classes: { [string]: ClassDef } = {

	Footman = {
		Id = "Footman",
		Name = "Footman",
		Description = "Sword and shield. Balanced, blocks better than anyone.",
		MaxHealth = 100,
		WalkSpeed = 16,
		StaminaMax = 100,
		Weapons = { "Sword" },
		HasShield = true,
		BlockDamageMultiplier = 0,
		BlockAngleDegrees = 130,
		DamageReduction = 0,
		BodyColor = Color3.fromRGB(150, 155, 165),
		AccentColor = Color3.fromRGB(90, 96, 108),
	},

	Vanguard = {
		Id = "Vanguard",
		Name = "Vanguard",
		Description = "Greatsword. Enormous damage and reach, cleaves crowds, blocks badly.",
		MaxHealth = 110,
		WalkSpeed = 16,
		StaminaMax = 110,
		Weapons = { "Greatsword" },
		HasShield = false,
		-- Takes 45% of the hit even when guarding: a Vanguard who turtles loses.
		BlockDamageMultiplier = 0.45,
		BlockAngleDegrees = 95,
		DamageReduction = 0,
		BodyColor = Color3.fromRGB(120, 108, 96),
		AccentColor = Color3.fromRGB(70, 62, 54),
	},

	Archer = {
		Id = "Archer",
		Name = "Archer",
		Description = "Bow and dagger. Kills from range, dies instantly up close.",
		MaxHealth = 80,
		WalkSpeed = 17,
		StaminaMax = 90,
		Weapons = { "Bow", "Dagger" },
		HasShield = false,
		BlockDamageMultiplier = 0.7,
		BlockAngleDegrees = 80,
		DamageReduction = 0,
		BodyColor = Color3.fromRGB(84, 108, 74),
		AccentColor = Color3.fromRGB(52, 68, 46),
	},

	Knight = {
		Id = "Knight",
		Name = "Knight",
		Description = "Heavy plate and a mace. Slow, tanky, shreds shields. No shield of his own.",
		MaxHealth = 150,
		WalkSpeed = 14,
		StaminaMax = 120,
		Weapons = { "Mace" },
		HasShield = false,
		BlockDamageMultiplier = 0.55,
		BlockAngleDegrees = 100,
		-- Plate soaks a flat slice of everything, including arrows.
		DamageReduction = 0.15,
		BodyColor = Color3.fromRGB(196, 200, 208),
		AccentColor = Color3.fromRGB(120, 124, 132),
	},
}

local ClassConfig = {}

ClassConfig.All = Classes

-- Fixed display order for the class select UI. Also the source of truth for
-- "which classes exist" - a class missing here will not be pickable.
ClassConfig.Order = { "Footman", "Vanguard", "Archer", "Knight" }
ClassConfig.Default = "Footman"

function ClassConfig.find(id: string): ClassDef?
	return Classes[id]
end

function ClassConfig.get(id: string): ClassDef
	local def = Classes[id]
	if not def then
		error(`ClassConfig: unknown class id "{id}"`, 2)
	end
	return def
end

function ClassConfig.isValid(id: unknown): boolean
	return typeof(id) == "string" and Classes[id :: string] ~= nil
end

return ClassConfig
