--!strict
--[[
	EffectController

	Receives the server's cosmetic combat broadcasts and turns them into
	animation, camera kick and impact sparks.

	Everything here is allowed to be dropped, arrive late or arrive out of
	order - it comes in on an UnreliableRemoteEvent. Never put anything the
	player's outcome depends on in this file.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Enums = require(ReplicatedStorage.Modules.Enums)
local Remotes = require(ReplicatedStorage.RemoteEvents.Remotes)

local CameraController = require(script.Parent.CameraController)
local InputController = require(script.Parent.InputController)
local SwingAnimator = require(script.Parent.SwingAnimator)

local EffectController = {}

local player = Players.LocalPlayer

-- Hard cap on simultaneous impact sparks. In a 50-on-50 melee the server can
-- legitimately report dozens of impacts a second; without a cap the client
-- spends its frame budget creating and destroying parts.
local MAX_SPARKS = 24
local activeSparks = 0

local IMPACT_COLORS = {
	[Enums.HitResult.Hit] = Color3.fromRGB(220, 70, 60),
	[Enums.HitResult.Blocked] = Color3.fromRGB(230, 220, 180),
	[Enums.HitResult.Parried] = Color3.fromRGB(255, 240, 160),
	[Enums.HitResult.BlockBroken] = Color3.fromRGB(255, 170, 80),
}

local function isLocalCharacter(character: Instance?): boolean
	return character ~= nil and character == player.Character
end

local function spark(position: Vector3, color: Color3, size: number)
	if activeSparks >= MAX_SPARKS then
		return
	end
	activeSparks += 1

	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(size, size, size)
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = workspace

	local tween = TweenService:Create(
		part,
		TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Transparency = 1, Size = Vector3.new(size * 2.4, size * 2.4, size * 2.4) }
	)
	tween.Completed:Connect(function()
		activeSparks -= 1
	end)
	tween:Play()

	Debris:AddItem(part, 0.4)
end

local function onEffect(kind: number, a: any, b: any, c: any, d: any)
	if kind == Enums.EffectKind.SwingStart then
		local character, direction, windup = a :: Model, b :: number, c :: number
		if isLocalCharacter(character) then
			-- Our own swing is already playing locally; this is just the
			-- server telling us it accepted the request.
			InputController.onServerConfirm()
			if InputController.isPredicting() then
				return
			end
		end
		SwingAnimator.onSwingStart(character, direction, windup)
	elseif kind == Enums.EffectKind.SwingRelease then
		local character, direction, release = a :: Model, b :: number, c :: number
		if isLocalCharacter(character) and InputController.isPredicting() then
			return
		end
		SwingAnimator.onSwingRelease(character, direction, release)
	elseif kind == Enums.EffectKind.Feint then
		local character = a :: Model
		if isLocalCharacter(character) then
			return
		end
		SwingAnimator.onFeint(character)
	elseif kind == Enums.EffectKind.GuardUp then
		local character = a :: Model
		if not isLocalCharacter(character) then
			SwingAnimator.onGuard(character, true)
		end
	elseif kind == Enums.EffectKind.GuardDown then
		local character = a :: Model
		if not isLocalCharacter(character) then
			SwingAnimator.onGuard(character, false)
		end
	elseif kind == Enums.EffectKind.Stagger then
		local character, duration = a :: Model, (b :: number) or 1
		SwingAnimator.onStagger(character)
		if isLocalCharacter(character) then
			InputController.onServerStagger(duration)
			CameraController.addShake(2.2)
		end
	elseif kind == Enums.EffectKind.Impact then
		local hitResult, position, victim = a :: number, b :: Vector3, d :: Model?
		local color = IMPACT_COLORS[hitResult] or IMPACT_COLORS[Enums.HitResult.Hit]
		spark(position, color, if hitResult == Enums.HitResult.Hit then 0.6 else 0.45)

		if isLocalCharacter(victim) then
			CameraController.addShake(if hitResult == Enums.HitResult.Hit then 1.8 else 0.8)
		end
	elseif kind == Enums.EffectKind.Arrow then
		EffectController.onArrow(a, b, c)
	end
end

--[[
	Overridden by RangedController when it loads. Kept as a stub so the effect
	router does not have to know whether ranged combat exists yet.
]]
function EffectController.onArrow(_origin: Vector3, _velocity: Vector3, _lifetime: number) end

function EffectController.init()
	Remotes.get("CombatEffect").OnClientEvent:Connect(onEffect)
end

return EffectController
