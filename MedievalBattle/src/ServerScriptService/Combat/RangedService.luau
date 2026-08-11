--!strict
--[[
	RangedService

	The bow. Same rule as melee: the client asks, the server decides and
	simulates.

	    client: "I am drawing"            -> server starts its own draw timer
	    client: "loose, aiming this way"  -> server checks the draw time it
	                                         measured, validates the aim, and
	                                         simulates the arrow itself

	The aim vector is the one piece of client-supplied *geometry* in the whole
	game, because the server genuinely cannot know where a player's camera is
	pointing vertically (the character root only carries yaw). It is validated
	rather than trusted: it must be a unit-ish vector, and its horizontal
	component must be within MAX_AIM_DEVIATION of the direction the character is
	actually facing. That kills the classic "fire backwards without turning"
	exploit while leaving legitimate vertical aim alone.

	Arrows are raycast step-by-step on the server rather than being physical
	parts. A hundred players' worth of physically simulated arrows would be a
	meaningful chunk of the physics budget; a stepped raycast is a handful of
	microseconds and cannot be shoved around by a player standing on it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatConfig = require(ReplicatedStorage.Modules.CombatConfig)
local Enums = require(ReplicatedStorage.Modules.Enums)
local Remotes = require(ReplicatedStorage.RemoteEvents.Remotes)
local Types = require(ReplicatedStorage.Modules.Types)
local WeaponConfig = require(ReplicatedStorage.Modules.WeaponConfig)

local CombatService = require(script.Parent.CombatService)
local DamageService = require(script.Parent.DamageService)
local EffectBroadcaster = require(script.Parent.EffectBroadcaster)
local RateLimiter = require(script.Parent.RateLimiter)
local StaminaService = require(script.Parent.StaminaService)

type CombatState = Types.CombatState
type WeaponDef = Types.WeaponDef

local RangedService = {}

-- A shot below this fraction of a full draw is refused outright; between there
-- and 1.0 the arrow simply flies slower (and therefore drops more).
local MIN_DRAW_FRACTION = 0.35
-- Horizontal aim may differ from the body's facing by this much. Generous
-- enough that turning while loosing feels fine, tight enough to stop no-turn
-- backshots.
local MAX_AIM_DEVIATION = math.rad(55)

local limiter = RateLimiter.new(CombatConfig.RateLimits.Ranged.tokens, CombatConfig.RateLimits.Ranged.perSecond)

type Projectile = {
	shooter: Player?,
	weapon: WeaponDef,
	position: Vector3,
	velocity: Vector3,
	gravity: number,
	expiresAt: number,
	params: RaycastParams,
}

local projectiles: { Projectile } = {}

local function isRanged(state: CombatState): WeaponDef?
	local weapon = WeaponConfig.find(state.weaponId)
	if weapon and weapon.Kind == "Ranged" then
		return weapon
	end
	return nil
end

--[[
	Validates the client's aim vector and returns a usable direction, or nil.
]]
local function validateAim(root: BasePart, rawAim: unknown): Vector3?
	if typeof(rawAim) ~= "Vector3" then
		return nil
	end

	local aim = rawAim :: Vector3
	local magnitude = aim.Magnitude
	-- Reject NaN, zero and absurd vectors before doing any maths with them.
	if magnitude ~= magnitude or magnitude < 0.5 or magnitude > 2 then
		return nil
	end

	local unit = aim.Unit
	local flatAim = Vector3.new(unit.X, 0, unit.Z)
	local look = root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatAim.Magnitude < 1e-3 then
		-- Straight up or straight down: no horizontal component to check.
		return unit
	end
	if flatLook.Magnitude < 1e-3 then
		return unit
	end

	local angle = math.acos(math.clamp(flatAim.Unit:Dot(flatLook.Unit), -1, 1))
	if angle > MAX_AIM_DEVIATION then
		return nil
	end

	return unit
end

local function onDraw(state: CombatState, weapon: WeaponDef)
	if state.phase ~= Enums.CombatPhase.Idle then
		return
	end
	if not StaminaService.canAfford(state, WeaponConfig.getStaminaCost(weapon, Enums.AttackDirection.Stab)) then
		return
	end

	state.drawStart = os.clock()
	CombatService.setPhase(state, Enums.CombatPhase.Drawing, math.huge)

	local root = state.root
	if root then
		EffectBroadcaster.broadcast(
			root.Position,
			Enums.EffectKind.DrawStart,
			state.character,
			weapon.DrawTime or 0.85
		)
	end
end

local function fireArrow(state: CombatState, weapon: WeaponDef, origin: Vector3, direction: Vector3, power: number)
	local speed = (weapon.ProjectileSpeed or 240) * power
	local lifetime = weapon.ProjectileLifetime or 6

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	-- An arrow must never hit the person who fired it, and must never be
	-- stopped by anyone's weapon model (those are CanQuery = false anyway).
	params.FilterDescendantsInstances = { state.character :: Instance }

	table.insert(projectiles, {
		shooter = state.player,
		weapon = weapon,
		position = origin,
		velocity = direction * speed,
		gravity = weapon.ProjectileGravity or 70,
		expiresAt = os.clock() + lifetime,
		params = params,
	})

	EffectBroadcaster.broadcast(origin, Enums.EffectKind.Arrow, origin, direction * speed, lifetime)
end

local function onRelease(state: CombatState, weapon: WeaponDef, rawAim: unknown)
	if state.phase ~= Enums.CombatPhase.Drawing then
		return
	end

	local root = state.root
	local character = state.character
	if not root or not character then
		return
	end

	local drawTime = weapon.DrawTime or 0.85
	local held = os.clock() - state.drawStart
	local power = math.clamp(held / drawTime, 0, 1)

	CombatService.setPhase(state, Enums.CombatPhase.Recovery, 0.4)
	state.drawStart = 0

	EffectBroadcaster.broadcast(root.Position, Enums.EffectKind.DrawEnd, character)

	if power < MIN_DRAW_FRACTION then
		return -- released too early: the shot is simply lost
	end

	local aim = validateAim(root, rawAim)
	if not aim then
		return
	end

	StaminaService.spend(state, WeaponConfig.getStaminaCost(weapon, Enums.AttackDirection.Stab))

	-- Launch from around eye height, slightly forward, so the arrow does not
	-- start inside the shooter's own torso.
	local head = character:FindFirstChild("Head") :: BasePart?
	local origin = (if head then head.Position else root.Position + Vector3.new(0, 1.5, 0)) + aim * 1.5

	fireArrow(state, weapon, origin, aim, math.max(power, MIN_DRAW_FRACTION))
end

local function onCancel(state: CombatState)
	if state.phase ~= Enums.CombatPhase.Drawing then
		return
	end
	state.drawStart = 0
	CombatService.setPhase(state, Enums.CombatPhase.Idle, math.huge)

	local root = state.root
	if root then
		EffectBroadcaster.broadcast(root.Position, Enums.EffectKind.DrawEnd, state.character)
	end
end

local function onRangedRequest(player: Player, action: unknown, aim: unknown)
	if not limiter:consume(player) then
		return
	end
	if typeof(action) ~= "number" then
		return
	end

	local state = CombatService.getState(player)
	if not state or not state.alive then
		return
	end

	local weapon = isRanged(state)
	if not weapon then
		return
	end

	if action == Enums.RangedAction.Draw then
		onDraw(state, weapon)
	elseif action == Enums.RangedAction.Release then
		onRelease(state, weapon, aim)
	elseif action == Enums.RangedAction.Cancel then
		onCancel(state)
	end
end

--[[
	Steps every arrow once per frame, raycasting from where it was to where it
	now is. Stepping-and-casting (rather than checking a point) means an arrow
	moving 4 studs a frame cannot pass through a 2-stud-thick player.
]]
local function stepProjectiles(dt: number)
	local now = os.clock()

	for index = #projectiles, 1, -1 do
		local arrow = projectiles[index]

		if now >= arrow.expiresAt then
			table.remove(projectiles, index)
			continue
		end

		arrow.velocity -= Vector3.new(0, arrow.gravity * dt, 0)
		local step = arrow.velocity * dt
		local result = workspace:Raycast(arrow.position, step, arrow.params)

		if not result then
			arrow.position += step
			continue
		end

		local hitPart = result.Instance
		local model = hitPart:FindFirstAncestorOfClass("Model")
		local victimPlayer = if model then Players:GetPlayerFromCharacter(model) else nil
		local victimState = if victimPlayer then CombatService.getState(victimPlayer) else nil

		if victimState then
			local hitResult = DamageService.resolveRanged(arrow.shooter, victimState, arrow.weapon, hitPart)
			if hitResult == Enums.HitResult.Ignored then
				-- Passed through an ally or a spawn-protected player: keep flying.
				local existing = arrow.params.FilterDescendantsInstances
				table.insert(existing, model :: Instance)
				arrow.params.FilterDescendantsInstances = existing
				arrow.position = result.Position
				continue
			end

			EffectBroadcaster.broadcastIncluding(
				result.Position,
				{ victimState.player },
				Enums.EffectKind.Impact,
				hitResult,
				result.Position,
				arrow.weapon.Id,
				victimState.character
			)
		else
			EffectBroadcaster.broadcast(
				result.Position,
				Enums.EffectKind.Impact,
				Enums.HitResult.Ignored,
				result.Position,
				arrow.weapon.Id
			)
		end

		table.remove(projectiles, index)
	end
end

function RangedService.init()
	Remotes.get("RangedRequest").OnServerEvent:Connect(onRangedRequest)
	RunService.Heartbeat:Connect(stepProjectiles)

	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player)
		for index = #projectiles, 1, -1 do
			if projectiles[index].shooter == player then
				-- Keep the arrow in flight but drop the reference, so a player
				-- who leaves mid-shot is not held alive by a projectile.
				projectiles[index].shooter = nil
			end
		end
	end)
end

return RangedService
