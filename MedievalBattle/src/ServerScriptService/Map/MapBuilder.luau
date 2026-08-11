--!strict
--[[
	MapBuilder

	Greyboxes the battlefield from MapConfig.Blocks at run time.

	Why build the map in code instead of committing a .rbxl:
	  * A binary place file cannot be merged. With four people, one person
	    touching the map would block everyone else's map work until it lands.
	  * Level tweaks become reviewable diffs ("moved the gatehouse 10 studs").
	  * Anyone can `rojo build` and get an identical map with no asset uploads.

	When the map gets a real art pass, this module is the only thing that has to
	change: MapConfig keeps the gameplay-relevant numbers (point positions,
	spawn zones) and the rest of the game reads those, not the geometry.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage.Modules.MapConfig)

local MapBuilder = {}

local FOLDER_NAME = "Map"

local function clearDefaults()
	-- Studio templates ship a Baseplate and a SpawnLocation; both would sit in
	-- the middle of the battlefield.
	for _, child in workspace:GetChildren() do
		if child.Name == "Baseplate" or child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end
end

function MapBuilder.build(): Folder
	clearDefaults()

	local existing = workspace:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME

	for _, def in MapConfig.Blocks do
		local part = Instance.new("Part")
		part.Name = def.Name
		part.Size = def.Size
		part.Position = def.Position
		part.Anchored = true
		part.CanCollide = true
		part.Color = def.Color or Color3.fromRGB(140, 140, 140)
		part.Material = def.Material or Enum.Material.Concrete
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if def.Orientation then
			part.Orientation = def.Orientation
		end
		part.Parent = folder
	end

	folder.Parent = workspace

	return folder
end

--[[
	Flat coloured pads under each spawn zone. Purely a readability aid so
	players can see where their side spawns during a playtest.
]]
function MapBuilder.buildSpawnPads(parent: Instance)
	for index, zone in MapConfig.SpawnZones do
		local pad = Instance.new("Part")
		pad.Name = `SpawnPad_{index}`
		pad.Anchored = true
		pad.CanCollide = false
		pad.CanQuery = false -- must never stop a swing trace
		pad.CanTouch = false
		pad.Shape = Enum.PartType.Cylinder
		-- A cylinder's axis runs along its X size, and Y/Z form the circular
		-- face. So thickness goes in X, diameter in Y and Z, and the part is
		-- then rolled 90 degrees to stand the axis upright into a flat disc.
		pad.Size = Vector3.new(0.4, zone.Radius * 2, zone.Radius * 2)
		pad.Position = zone.Position + Vector3.new(0, 0.2, 0)
		pad.Orientation = Vector3.new(0, 0, 90)
		pad.Color = MapConfig.TeamColors[zone.Team]
		pad.Material = Enum.Material.Neon
		pad.Transparency = 0.7
		pad.Parent = parent
	end
end

return MapBuilder
