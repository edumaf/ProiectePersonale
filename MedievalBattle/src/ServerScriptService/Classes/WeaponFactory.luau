--!strict
--[[
	WeaponFactory

	Builds weapon models out of primitives from WeaponConfig.Model, so there are
	no binary .rbxm assets in the repo. Four people can diff and merge a weapon
	change; nobody can merge a mesh.

	Two Roblox details that matter more than they look:

	  * Every part is CanQuery = false / CanTouch = false / CanCollide = false /
	    Massless = true. If weapons stayed query-able, the server's swing
	    raycasts would hit the attacker's own blade (and every ally's blade in a
	    50v50 crowd) instead of the enemy behind it, and unmassed weapons would
	    wreck character physics.

	  * The weapon hangs off the HumanoidRootPart through a Motor6D rather than
	    a rigid weld. Motor6D.C0 is what the client animator drives every frame,
	    and property writes on the client never replicate - so a full swing
	    animation costs exactly zero bandwidth. The server keeps its copy at the
	    idle pose and never animates it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SwingMath = require(ReplicatedStorage.Modules.SwingMath)
local Types = require(ReplicatedStorage.Modules.Types)
local WeaponConfig = require(ReplicatedStorage.Modules.WeaponConfig)

type WeaponDef = Types.WeaponDef

local WeaponFactory = {}

local GRIP_NAME = "Grip"

local function configurePart(part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

--[[
	Builds an unparented weapon model. The grip sits at the model's origin with
	-Z pointing at the tip, matching SwingMath's convention.
]]
function WeaponFactory.build(weaponId: string): Model
	local def = WeaponConfig.get(weaponId)

	local model = Instance.new("Model")
	model.Name = weaponId

	local grip = Instance.new("Part")
	grip.Name = GRIP_NAME
	grip.Size = Vector3.new(0.2, 0.2, 0.2)
	grip.Transparency = 1
	grip.CFrame = CFrame.new()
	configurePart(grip)
	grip.Parent = model
	model.PrimaryPart = grip

	for index, spec in def.Model do
		local part = Instance.new("Part")
		part.Name = `{weaponId}_{index}`
		part.Size = spec.Size
		part.Color = spec.Color
		part.Material = spec.Material
		if spec.Shape then
			-- Ball/Cylinder need a Part with a Shape, which is the default
			-- Instance.new("Part") class, so this is just a property set.
			part.Shape = spec.Shape
		end
		configurePart(part)
		part.CFrame = grip.CFrame * CFrame.new(spec.Offset)
		part.Parent = model

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = grip
		weld.Part1 = part
		weld.Parent = part
	end

	model:SetAttribute("WeaponId", weaponId)
	return model
end

--[[
	Attaches a built weapon to a character and returns the Motor6D the client
	animator will drive. Safe to call on a character that already has a weapon -
	the old one is destroyed first.
]]
function WeaponFactory.attach(character: Model, model: Model): Motor6D?
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local grip = model.PrimaryPart
	if not root or not grip then
		warn("WeaponFactory.attach: character has no HumanoidRootPart, or weapon has no Grip")
		return nil
	end

	local def = WeaponConfig.find(model.Name)
	if not def then
		warn(`WeaponFactory.attach: no config for weapon "{model.Name}"`)
		return nil
	end

	-- Place the weapon at the idle pose first so it is never seen at the world
	-- origin for a frame while the Motor6D is being created.
	local idleCF = SwingMath.getIdleCFrame(root.CFrame, def)
	model:PivotTo(idleCF)
	model.Parent = character

	local motor = Instance.new("Motor6D")
	motor.Name = "WeaponMotor"
	motor.Part0 = root
	motor.Part1 = grip
	motor.C0 = root.CFrame:ToObjectSpace(idleCF)
	motor.C1 = CFrame.new()
	motor.Parent = root

	return motor
end

--[[
	A shield is a static prop on the left arm - it does not animate, and it does
	not affect hit resolution. Blocking quality is a class stat
	(ClassDef.BlockDamageMultiplier), not a physical object, because resolving
	blocks against a real shield part would mean trusting client-side geometry.
]]
function WeaponFactory.buildShield(): Model
	local model = Instance.new("Model")
	model.Name = "Shield"

	local board = Instance.new("Part")
	board.Name = "Board"
	board.Size = Vector3.new(0.4, 4.2, 3.2)
	board.Color = Color3.fromRGB(96, 72, 48)
	board.Material = Enum.Material.Wood
	configurePart(board)
	board.CFrame = CFrame.new()
	board.Parent = model
	model.PrimaryPart = board

	local boss = Instance.new("Part")
	boss.Name = "Boss"
	boss.Shape = Enum.PartType.Ball
	boss.Size = Vector3.new(0.9, 0.9, 0.9)
	boss.Color = Color3.fromRGB(178, 185, 196)
	boss.Material = Enum.Material.Metal
	configurePart(boss)
	boss.CFrame = board.CFrame * CFrame.new(-0.3, 0, 0)
	boss.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = board
	weld.Part1 = boss
	weld.Parent = boss

	return model
end

function WeaponFactory.attachShield(character: Model, model: Model): Motor6D?
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local board = model.PrimaryPart
	if not root or not board then
		return nil
	end

	local offset = CFrame.new(-1.4, 0.2, -0.7) * CFrame.Angles(0, math.rad(-20), 0)
	model:PivotTo(root.CFrame * offset)
	model.Parent = character

	local motor = Instance.new("Motor6D")
	motor.Name = "ShieldMotor"
	motor.Part0 = root
	motor.Part1 = board
	motor.C0 = offset
	motor.C1 = CFrame.new()
	motor.Parent = root

	return motor
end

--[[
	Removes any weapon/shield previously attached by this factory.
]]
function WeaponFactory.clear(character: Model)
	for _, child in character:GetChildren() do
		if child:IsA("Model") and (child:GetAttribute("WeaponId") ~= nil or child.Name == "Shield") then
			child:Destroy()
		end
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		for _, child in root:GetChildren() do
			if child:IsA("Motor6D") and (child.Name == "WeaponMotor" or child.Name == "ShieldMotor") then
				child:Destroy()
			end
		end
	end
end

return WeaponFactory
