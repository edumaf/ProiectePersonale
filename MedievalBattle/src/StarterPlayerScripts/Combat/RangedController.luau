--!strict
--[[
	RangedController

	Bow input and arrow visuals.

	Hold LMB to draw, release to loose. The aim vector sent to the server is the
	camera's look direction - the one piece of geometry the server cannot derive
	on its own, because the character root only carries yaw. The server validates
	it against the body's facing before using it (see RangedService).

	Arrows are drawn client-side from the launch parameters the server
	broadcasts. Each client re-simulates the same trajectory locally instead of
	the server streaming a position 30 times a second per arrow, which at
	50 archers would be a genuinely large amount of traffic for a decoration.
	The visual arrow does not collide - the server's impact effect is what marks
	the real hit.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Enums = require(ReplicatedStorage.Modules.Enums)
local Remotes = require(ReplicatedStorage.RemoteEvents.Remotes)
local WeaponConfig = require(ReplicatedStorage.Modules.WeaponConfig)

local EffectController = require(script.Parent.EffectController)
local InputController = require(script.Parent.InputController)
local SwingAnimator = require(script.Parent.SwingAnimator)

local RangedController = {}

local player = Players.LocalPlayer

-- More arrows than this on screen at once is visual noise anyway, and it caps
-- the per-frame cost during a mass volley.
local MAX_VISUAL_ARROWS = 40

type VisualArrow = {
	part: BasePart,
	position: Vector3,
	velocity: Vector3,
	gravity: number,
	expiresAt: number,
}

local visuals: { VisualArrow } = {}
local drawing = false

local function isHoldingBow(): boolean
	local weapon = WeaponConfig.find(InputController.getWeaponId())
	return weapon ~= nil and weapon.Kind == "Ranged"
end

local function onPress()
	if drawing or not isHoldingBow() then
		return
	end
	drawing = true
	Remotes.get("RangedRequest"):FireServer(Enums.RangedAction.Draw)

	local character = player.Character
	local weapon = WeaponConfig.find(InputController.getWeaponId())
	if character and weapon then
		SwingAnimator.onDraw(character, weapon.DrawTime or 0.85)
	end
end

local function onRelease()
	if not drawing then
		return
	end
	drawing = false

	local camera = Workspace.CurrentCamera
	local aim = if camera then camera.CFrame.LookVector else Vector3.new(0, 0, -1)
	Remotes.get("RangedRequest"):FireServer(Enums.RangedAction.Release, aim)

	local character = player.Character
	if character then
		SwingAnimator.onDrawEnd(character)
	end
end

local function spawnVisual(origin: Vector3, velocity: Vector3, lifetime: number)
	if #visuals >= MAX_VISUAL_ARROWS then
		return
	end

	local part = Instance.new("Part")
	part.Name = "ArrowVisual"
	part.Size = Vector3.new(0.12, 0.12, 2.2)
	part.Color = Color3.fromRGB(120, 92, 60)
	part.Material = Enum.Material.Wood
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = CFrame.lookAt(origin, origin + velocity)
	part.Parent = Workspace

	table.insert(visuals, {
		part = part,
		position = origin,
		velocity = velocity,
		gravity = 70,
		expiresAt = os.clock() + lifetime,
	})

	Debris:AddItem(part, lifetime + 0.2)
end

local function step(dt: number)
	local now = os.clock()

	for index = #visuals, 1, -1 do
		local arrow = visuals[index]
		if now >= arrow.expiresAt or not arrow.part.Parent then
			arrow.part:Destroy()
			table.remove(visuals, index)
			continue
		end

		arrow.velocity -= Vector3.new(0, arrow.gravity * dt, 0)
		arrow.position += arrow.velocity * dt
		arrow.part.CFrame = CFrame.lookAt(arrow.position, arrow.position + arrow.velocity)
	end
end

function RangedController.init()
	InputController.setRangedHandlers({ press = onPress, release = onRelease })

	-- The effect router owns the CombatEffect connection; we just supply the
	-- arrow handler so both modules stay independent.
	EffectController.onArrow = function(origin: Vector3, velocity: Vector3, lifetime: number)
		spawnVisual(origin, velocity, lifetime)
	end

	player.CharacterAdded:Connect(function()
		drawing = false
	end)

	RunService.RenderStepped:Connect(step)
end

return RangedController
