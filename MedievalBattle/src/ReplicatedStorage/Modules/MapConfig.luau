--!strict
--[[
	MapConfig

	Layout data for the MVP battlefield. MapBuilder greyboxes the geometry from
	these numbers, ObjectiveService reads the capture points, SpawnService reads
	the spawn zones - one source of truth, so moving a point moves everything.

	The battlefield runs along the X axis:

	   -240 .......... -70 .......... 40 .......... 150 ....... 250
	   Attacker       [A] Village   [B] Gatehouse  [C] Keep    Defender
	    spawn                                                    spawn

	Attackers push left-to-right and must take A, then B, then C, in order.
	Their spawn moves forward each time a point falls, so the walk to the fight
	stays short and the front line keeps moving.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = require(ReplicatedStorage.Modules.Enums)
local Types = require(ReplicatedStorage.Modules.Types)

type CapturePointDef = Types.CapturePointDef
type SpawnZoneDef = Types.SpawnZoneDef

local MapConfig = {}

MapConfig.GroundY = 0
MapConfig.FieldMinX = -260
MapConfig.FieldMaxX = 280
MapConfig.FieldHalfWidth = 130 -- along Z

MapConfig.TeamColors = {
	[Enums.TeamId.Attackers] = Color3.fromRGB(178, 54, 54),
	[Enums.TeamId.Defenders] = Color3.fromRGB(54, 96, 178),
}
MapConfig.TeamNames = {
	[Enums.TeamId.Attackers] = "Crimson Host",
	[Enums.TeamId.Defenders] = "Azure Watch",
}

-- Ordered: attackers must capture index 1, then 2, then 3.
MapConfig.CapturePoints = {
	{
		Id = "A",
		Name = "The Village",
		Position = Vector3.new(-70, 0, 0),
		Radius = 26,
		Height = 34,
		CaptureSeconds = 26,
	},
	{
		Id = "B",
		Name = "The Gatehouse",
		Position = Vector3.new(40, 0, 0),
		Radius = 22,
		Height = 40,
		CaptureSeconds = 30,
	},
	{
		Id = "C",
		Name = "The Keep",
		Position = Vector3.new(152, 0, -6),
		Radius = 24,
		Height = 44,
		CaptureSeconds = 34,
	},
} :: { CapturePointDef }

--[[
	Spawn zones. `RequiresCaptures` gates a zone behind progress: the attacker
	zone requiring 1 capture only opens once point A has fallen, and
	SpawnService always picks the furthest-forward zone a team has unlocked.
]]
MapConfig.SpawnZones = {
	{ Team = Enums.TeamId.Attackers, Position = Vector3.new(-215, 0, 0), Radius = 26 },
	{ Team = Enums.TeamId.Attackers, Position = Vector3.new(-24, 0, 34), Radius = 20, RequiresCaptures = 1 },
	{ Team = Enums.TeamId.Attackers, Position = Vector3.new(88, 0, 30), Radius = 18, RequiresCaptures = 2 },

	{ Team = Enums.TeamId.Defenders, Position = Vector3.new(238, 0, 0), Radius = 26 },
	{ Team = Enums.TeamId.Defenders, Position = Vector3.new(196, 0, -28), Radius = 18 },
} :: { SpawnZoneDef }

--[[
	Greybox pieces. Kept as plain data so the blockout can be tweaked without
	touching MapBuilder, and so a real art pass can later replace MapBuilder
	alone. Position is the centre, Size is full size.
]]
export type BlockDef = {
	Name: string,
	Position: Vector3,
	Size: Vector3,
	Color: Color3?,
	Material: Enum.Material?,
	Orientation: Vector3?,
}

local STONE = Color3.fromRGB(132, 130, 124)
local DARK_STONE = Color3.fromRGB(98, 96, 92)
local TIMBER = Color3.fromRGB(104, 74, 48)
local PLASTER = Color3.fromRGB(196, 186, 166)
local ROOF = Color3.fromRGB(122, 62, 48)

local function block(
	name: string,
	pos: Vector3,
	size: Vector3,
	color: Color3?,
	material: Enum.Material?,
	orientation: Vector3?
): BlockDef
	return { Name = name, Position = pos, Size = size, Color = color, Material = material, Orientation = orientation }
end

-- Small helper for the village huts: 4 walls + a roof, built as solid blocks
-- (greybox - nobody goes inside them yet, they exist to break line of sight).
local function hut(name: string, pos: Vector3, w: number, d: number, h: number): { BlockDef }
	return {
		block(name .. "_Body", pos + Vector3.new(0, h / 2, 0), Vector3.new(w, h, d), PLASTER, Enum.Material.Concrete),
		block(name .. "_Roof", pos + Vector3.new(0, h + 1, 0), Vector3.new(w + 2.5, 2, d + 2.5), ROOF, Enum.Material.Slate),
		block(name .. "_Beam", pos + Vector3.new(0, h / 2, d / 2), Vector3.new(w, h, 0.6), TIMBER, Enum.Material.Wood),
	}
end

local blocks: { BlockDef } = {}

local function add(list: { BlockDef })
	for _, b in list do
		table.insert(blocks, b)
	end
end

-- Ground + out-of-bounds walls -------------------------------------------------
add({
	block(
		"Ground",
		Vector3.new((MapConfig.FieldMinX + MapConfig.FieldMaxX) / 2, -2, 0),
		Vector3.new(MapConfig.FieldMaxX - MapConfig.FieldMinX, 4, MapConfig.FieldHalfWidth * 2),
		Color3.fromRGB(94, 112, 68),
		Enum.Material.Grass
	),
	block("Bound_North", Vector3.new(10, 40, -MapConfig.FieldHalfWidth), Vector3.new(560, 80, 6), DARK_STONE, Enum.Material.Rock),
	block("Bound_South", Vector3.new(10, 40, MapConfig.FieldHalfWidth), Vector3.new(560, 80, 6), DARK_STONE, Enum.Material.Rock),
	block("Bound_West", Vector3.new(MapConfig.FieldMinX, 40, 0), Vector3.new(6, 80, 266), DARK_STONE, Enum.Material.Rock),
	block("Bound_East", Vector3.new(MapConfig.FieldMaxX, 40, 0), Vector3.new(6, 80, 266), DARK_STONE, Enum.Material.Rock),
})

-- Attacker staging camp --------------------------------------------------------
add({
	block("Camp_Palisade_N", Vector3.new(-190, 6, -46), Vector3.new(70, 12, 3), TIMBER, Enum.Material.Wood),
	block("Camp_Palisade_S", Vector3.new(-190, 6, 46), Vector3.new(70, 12, 3), TIMBER, Enum.Material.Wood),
	block("Camp_Platform", Vector3.new(-215, 1, 0), Vector3.new(46, 2, 46), TIMBER, Enum.Material.WoodPlanks),
})

-- Point A: open village, several huts making a loose maze of chokes -----------
add(hut("Hut1", Vector3.new(-96, 0, -26), 16, 14, 12))
add(hut("Hut2", Vector3.new(-52, 0, -34), 14, 16, 11))
add(hut("Hut3", Vector3.new(-88, 0, 30), 18, 14, 13))
add(hut("Hut4", Vector3.new(-44, 0, 26), 14, 14, 11))
add({
	block("Village_Well", Vector3.new(-70, 2, 0), Vector3.new(9, 4, 9), STONE, Enum.Material.Cobblestone),
	block("Village_Cart", Vector3.new(-62, 2, -8), Vector3.new(10, 4, 5), TIMBER, Enum.Material.Wood),
	-- Low walls: cover you can fight over, not hide behind.
	block("Village_Wall_N", Vector3.new(-70, 2.5, -50), Vector3.new(64, 5, 3), STONE, Enum.Material.Cobblestone),
	block("Village_Wall_S", Vector3.new(-70, 2.5, 50), Vector3.new(64, 5, 3), STONE, Enum.Material.Cobblestone),
})

-- Point B: the gatehouse. The main choke of the map, with a flanking side gap.
add({
	block("Curtain_Wall_N", Vector3.new(40, 14, -62), Vector3.new(10, 28, 132), STONE, Enum.Material.Brick),
	block("Curtain_Wall_S", Vector3.new(40, 14, 74), Vector3.new(10, 28, 110), STONE, Enum.Material.Brick),
	block("Gate_Tower_L", Vector3.new(40, 18, -18), Vector3.new(14, 36, 14), DARK_STONE, Enum.Material.Brick),
	block("Gate_Tower_R", Vector3.new(40, 18, 14), Vector3.new(14, 36, 14), DARK_STONE, Enum.Material.Brick),
	block("Gate_Lintel", Vector3.new(40, 26, -2), Vector3.new(12, 8, 20), DARK_STONE, Enum.Material.Brick),
	-- Wall walk the defenders can hold, reachable from two ramps.
	block("Wall_Walk", Vector3.new(40, 28.5, 26), Vector3.new(12, 1, 96), STONE, Enum.Material.Brick),
	block("Ramp_Defender", Vector3.new(58, 14, 60), Vector3.new(30, 1, 14), STONE, Enum.Material.Brick, Vector3.new(0, 0, -28)),
	-- Breach: the "flank" route, deliberately narrow so it costs time.
	block("Breach_Rubble", Vector3.new(40, 3, -104), Vector3.new(12, 6, 22), DARK_STONE, Enum.Material.Rock),
})

-- Between B and C: open ground with scattered cover, so cavalry-less infantry
-- still have something to fight around.
add({
	block("Field_Rock1", Vector3.new(92, 3, -40), Vector3.new(14, 6, 12), DARK_STONE, Enum.Material.Rock),
	block("Field_Rock2", Vector3.new(104, 4, 44), Vector3.new(16, 8, 14), DARK_STONE, Enum.Material.Rock),
	block("Field_Fence", Vector3.new(118, 2.5, -8), Vector3.new(3, 5, 54), TIMBER, Enum.Material.Wood),
})

-- Point C: the keep courtyard, raised, reached by two ramps.
add({
	block("Keep_Base", Vector3.new(152, 3, -6), Vector3.new(86, 6, 92), STONE, Enum.Material.Cobblestone),
	block("Keep_Wall_N", Vector3.new(152, 12, -54), Vector3.new(86, 24, 6), DARK_STONE, Enum.Material.Brick),
	block("Keep_Wall_E", Vector3.new(196, 12, -6), Vector3.new(6, 24, 92), DARK_STONE, Enum.Material.Brick),
	block("Keep_Tower", Vector3.new(178, 20, -34), Vector3.new(20, 40, 20), DARK_STONE, Enum.Material.Brick),
	block("Keep_Ramp_W", Vector3.new(100, 3, -30), Vector3.new(30, 1, 18), STONE, Enum.Material.Cobblestone, Vector3.new(0, 0, 11)),
	block("Keep_Ramp_S", Vector3.new(140, 3, 56), Vector3.new(18, 1, 30), STONE, Enum.Material.Cobblestone, Vector3.new(-11, 0, 0)),
	block("Keep_Pillar1", Vector3.new(136, 10, -20), Vector3.new(8, 14, 8), STONE, Enum.Material.Brick),
	block("Keep_Pillar2", Vector3.new(168, 10, 12), Vector3.new(8, 14, 8), STONE, Enum.Material.Brick),
})

-- Defender camp ----------------------------------------------------------------
add({
	block("Def_Platform", Vector3.new(238, 1, 0), Vector3.new(40, 2, 46), STONE, Enum.Material.Cobblestone),
	block("Def_Banner_Wall", Vector3.new(252, 8, 0), Vector3.new(4, 16, 44), DARK_STONE, Enum.Material.Brick),
})

MapConfig.Blocks = blocks

return MapConfig
