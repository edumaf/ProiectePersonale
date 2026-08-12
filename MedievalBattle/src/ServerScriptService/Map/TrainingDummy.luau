--!strict
--[[
	TrainingDummy

	Static targets beside each home spawn, with a health number above them that
	resets a few seconds after the dummy falls.

	They exist so hit registration can be tested by one person. Without them,
	answering "did that swing actually land, and at what range" needs two
	clients connected and cooperating, which makes tuning reach and timing far
	slower than it should be.

	A dummy is deliberately *not* a character rig: no Humanoid, no joints, no
	physics. It is two anchored blocks carrying the same `TeamId` attribute a
	real character has, which is all the hit tracer looks for, plus a `Health`
	attribute that replicates to every client on its own. TeamId 0 means
	"hostile to everybody", so both teams can train on the same target.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Modules.CombatConfig)
local Enums = require(ReplicatedStorage.Modules.Enums)
local MapConfig = require(ReplicatedStorage.Modules.MapConfig)

local TrainingDummy = {}

local MAX_HEALTH = 250
local RESET_DELAY = 3
local DUMMIES_PER_SPAWN = 3
local SPACING = 7

local function label(anchor: BasePart)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Health"
	billboard.Size = UDim2.fromOffset(150, 44)
	billboard.StudsOffset = Vector3.new(0, 3.4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120
	billboard.Parent = anchor

	local text = Instance.new("TextLabel")
	text.Name = "Value"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 0.6)
	text.Font = Enum.Font.Antique
	text.TextSize = 22
	text.TextColor3 = Color3.fromRGB(240, 236, 228)
	text.TextStrokeTransparency = 0.4
	text.Text = `{MAX_HEALTH} / {MAX_HEALTH}`
	text.Parent = billboard

	local hitBy = Instance.new("TextLabel")
	hitBy.Name = "LastHit"
	hitBy.BackgroundTransparency = 1
	hitBy.Position = UDim2.fromScale(0, 0.6)
	hitBy.Size = UDim2.fromScale(1, 0.4)
	hitBy.Font = Enum.Font.Garamond
	hitBy.TextSize = 14
	hitBy.TextColor3 = Color3.fromRGB(198, 192, 180)
	hitBy.TextStrokeTransparency = 0.6
	hitBy.Text = ""
	hitBy.Parent = billboard

	return text, hitBy
end

local function buildDummy(parent: Instance, position: Vector3, facing: number): Model
	local model = Instance.new("Model")
	model.Name = "TrainingDummy"

	local post = Instance.new("Part")
	post.Name = "Post"
	post.Anchored = true
	post.Size = Vector3.new(0.6, 3, 0.6)
	post.Position = position + Vector3.new(0, 1.5, 0)
	post.Color = Color3.fromRGB(96, 70, 46)
	post.Material = Enum.Material.Wood
	post.Parent = model

	-- Named to match a real character's torso so the limb-multiplier extension
	-- point in CombatConfig applies to dummies too once it is filled in.
	local body = Instance.new("Part")
	body.Name = "UpperTorso"
	body.Anchored = true
	body.Size = Vector3.new(2.2, 2.6, 1.2)
	body.Position = position + Vector3.new(0, 4.3, 0)
	body.Orientation = Vector3.new(0, facing, 0)
	body.Color = Color3.fromRGB(150, 122, 90)
	body.Material = Enum.Material.Fabric
	body.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Anchored = true
	head.Size = Vector3.new(1.2, 1.2, 1.2)
	head.Position = position + Vector3.new(0, 6.2, 0)
	head.Orientation = Vector3.new(0, facing, 0)
	head.Color = Color3.fromRGB(178, 150, 112)
	head.Material = Enum.Material.Fabric
	head.Parent = model

	model.PrimaryPart = body

	-- The two attributes that make this a valid target: TeamId is what the hit
	-- tracer looks for, Health is what DamageService decrements.
	model:SetAttribute("TeamId", 0)
	model:SetAttribute("Health", MAX_HEALTH)
	model:SetAttribute("MaxHealth", MAX_HEALTH)

	local text, hitBy = label(body)
	local resetting = false

	model:GetAttributeChangedSignal("Health"):Connect(function()
		local health = model:GetAttribute("Health")
		if typeof(health) ~= "number" then
			return
		end

		text.Text = `{math.ceil(health)} / {MAX_HEALTH}`
		text.TextColor3 = if health <= MAX_HEALTH * 0.3
			then Color3.fromRGB(226, 110, 92)
			else Color3.fromRGB(240, 236, 228)

		local last = model:GetAttribute("LastHitBy")
		hitBy.Text = if typeof(last) == "string" then `last hit by {last}` else ""

		if health > 0 or resetting then
			return
		end

		resetting = true
		text.Text = "DOWN"
		body.Transparency = 0.6
		head.Transparency = 0.6

		task.delay(RESET_DELAY, function()
			if not model.Parent then
				return
			end
			body.Transparency = 0
			head.Transparency = 0
			resetting = false
			model:SetAttribute("Health", MAX_HEALTH)
		end)
	end)

	model.Parent = parent
	return model
end

function TrainingDummy.build(parent: Instance)
	if not CombatConfig.TrainingDummies then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "TrainingDummies"
	folder.Parent = parent

	for _, teamId in { Enums.TeamId.Attackers, Enums.TeamId.Defenders } do
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

		-- Opposite side of the spawn from the weapon racks, so you can grab a
		-- weapon and turn straight around into a target.
		local forward = if teamId == Enums.TeamId.Attackers then -1 else 1
		local facing = if teamId == Enums.TeamId.Attackers then 90 else -90
		local width = (DUMMIES_PER_SPAWN - 1) * SPACING

		for index = 1, DUMMIES_PER_SPAWN do
			local offset = Vector3.new(forward * 16, 0, -width / 2 + (index - 1) * SPACING)
			buildDummy(folder, (home :: Vector3) + offset, facing)
		end
	end
end

return TrainingDummy
