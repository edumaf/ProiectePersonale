--!strict
--[[
	WeaponRack

	A stand at each team's home spawn holding one of every weapon in
	WeaponConfig. Walk up, press E, and you are carrying it.

	This exists because the weapons are otherwise invisible to a tester: they are
	built procedurally at spawn from your class, so there is nothing in the
	Explorer that looks like a weapon and no way to try a greatsword without
	switching class and dying first. The rack makes all six reachable in about
	ten seconds.

	It is generated from WeaponConfig.Ids, so a weapon added to the config shows
	up here automatically with its real stats on the label - there is no second
	list to keep in sync.

	This is a testing affordance, not a design decision. Turn it off with
	CombatConfig.WeaponRacks when the game gets closer to real, since picking a
	greatsword up as an Archer bypasses the whole class system.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Modules.CombatConfig)
local Enums = require(ReplicatedStorage.Modules.Enums)
local MapConfig = require(ReplicatedStorage.Modules.MapConfig)
local WeaponConfig = require(ReplicatedStorage.Modules.WeaponConfig)

local ClassService = require(script.Parent.ClassService)
local WeaponFactory = require(script.Parent.WeaponFactory)

local WeaponRack = {}

local PEDESTAL_SIZE = Vector3.new(2.4, 4, 2.4)
local SPACING = 4.5

--[[
	A short human summary of what the weapon actually does, straight from the
	config. Damage is shown for the direction the weapon is best at, so the
	spear reads as a thrusting weapon rather than a bad sword.
]]
local function describe(def: typeof(WeaponConfig.get("Sword"))): string
	local best = Enums.AttackDirection.Right
	local bestDamage = 0
	for direction = 1, Enums.AttackDirectionCount do
		local damage = WeaponConfig.getDamage(def, direction)
		if damage > bestDamage then
			bestDamage = damage
			best = direction
		end
	end

	local timing = def.Timings[best]
	return `{math.floor(bestDamage)} dmg ({Enums.AttackDirectionName[best]})  ·  `
		.. `{string.format("%.2f", timing.Windup)}s windup  ·  {math.floor(def.Range)} reach`
end

local function buildPedestal(parent: Instance, position: Vector3, weaponId: string, teamColor: Color3)
	local def = WeaponConfig.get(weaponId)

	local pedestal = Instance.new("Part")
	pedestal.Name = `Rack_{weaponId}`
	pedestal.Anchored = true
	pedestal.Size = PEDESTAL_SIZE
	pedestal.Position = position + Vector3.new(0, PEDESTAL_SIZE.Y / 2, 0)
	pedestal.Color = Color3.fromRGB(96, 92, 86)
	pedestal.Material = Enum.Material.Cobblestone
	pedestal.TopSurface = Enum.SurfaceType.Smooth
	pedestal.Parent = parent

	local trim = Instance.new("Part")
	trim.Name = "Trim"
	trim.Anchored = true
	trim.CanCollide = false
	trim.CanQuery = false
	trim.Size = Vector3.new(PEDESTAL_SIZE.X + 0.4, 0.3, PEDESTAL_SIZE.Z + 0.4)
	trim.Position = pedestal.Position + Vector3.new(0, PEDESTAL_SIZE.Y / 2, 0)
	trim.Color = teamColor
	trim.Material = Enum.Material.Metal
	trim.Parent = parent

	-- The display copy is the real weapon model, anchored and stood upright so
	-- you can see what you are about to pick up.
	local display = WeaponFactory.build(weaponId)
	display.Name = `Display_{weaponId}`
	for _, part in display:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	display:PivotTo(
		CFrame.new(pedestal.Position + Vector3.new(0, PEDESTAL_SIZE.Y / 2 + def.Range / 2 + 0.6, 0))
			* CFrame.Angles(math.rad(90), 0, 0)
	)
	display.Parent = parent

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(260, 52)
	billboard.StudsOffset = Vector3.new(0, def.Range + 2.6, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 90
	billboard.Parent = pedestal

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0.55, 0)
	name.Font = Enum.Font.Antique
	name.TextSize = 22
	name.TextColor3 = Color3.fromRGB(240, 236, 228)
	name.TextStrokeTransparency = 0.4
	name.Text = def.Name
	name.Parent = billboard

	local stats = Instance.new("TextLabel")
	stats.BackgroundTransparency = 1
	stats.Position = UDim2.new(0, 0, 0.55, 0)
	stats.Size = UDim2.new(1, 0, 0.45, 0)
	stats.Font = Enum.Font.Garamond
	stats.TextSize = 14
	stats.TextColor3 = Color3.fromRGB(198, 192, 180)
	stats.TextStrokeTransparency = 0.6
	stats.Text = describe(def)
	stats.Parent = billboard

	-- ProximityPrompt rather than a Touched event: no input plumbing, no
	-- accidental pickups from walking past, and it shows its own key hint.
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take"
	prompt.ObjectText = def.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = pedestal

	prompt.Triggered:Connect(function(player: Player)
		ClassService.equipWeapon(player, weaponId)
	end)
end

--[[
	One rack per team, placed just off the home spawn zone so it is the first
	thing you see and never in the way of the fight.
]]
function WeaponRack.build(parent: Instance)
	if not CombatConfig.WeaponRacks then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "WeaponRacks"
	folder.Parent = parent

	for _, teamId in { Enums.TeamId.Attackers, Enums.TeamId.Defenders } do
		-- The home zone is the one with no capture requirement.
		local home: Vector3? = nil
		for _, zone in MapConfig.SpawnZones do
			if zone.Team == teamId and zone.RequiresCaptures == nil then
				home = zone.Position
				break
			end
		end
		if not home then
			continue
		end

		local ids = WeaponConfig.Ids
		local width = (#ids - 1) * SPACING
		-- Attackers face up the map, defenders face back down it, so each rack
		-- sits in front of the players spawning at that zone.
		local forward = if teamId == Enums.TeamId.Attackers then 1 else -1

		for index, weaponId in ids do
			local offset = Vector3.new(forward * 14, 0, -width / 2 + (index - 1) * SPACING)
			buildPedestal(folder, (home :: Vector3) + offset, weaponId, MapConfig.TeamColors[teamId])
		end
	end
end

return WeaponRack
