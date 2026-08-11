--!strict
--[[
	CombatService

	The authoritative combat state machine. One instance of the machine per
	player, all advanced from a single Heartbeat loop.

	=========================== THE SECURITY MODEL ===========================
	The client never tells the server that it hit someone. It sends four things
	and nothing else:

	    "I pressed attack, in this direction"
	    "I want to feint"
	    "my guard is up / down"
	    "I am sprinting / not"

	The server starts its own copy of the attack, times the windup with its own
	clock, and during the release window traces the blade itself against the
	world. Damage is decided entirely from server-side geometry.

	The consequence is that the worst a modified client can do is *ask* for
	actions - and the rate limiters cap how often it may ask. There is no
	"I hit Bob for 400" message to forge, because no such message exists.

	The cost of this design is honest and worth stating: the server starts the
	windup when the request arrives, so a player with 120ms ping sees their own
	swing start ~120ms before the server does. It feels fine because the client
	animates immediately and the whole exchange (windup + release) is
	400-900ms, but it does mean high-ping players' swings land slightly later
	than they look. The fix later is a client timestamp clamped to a sane
	window - deliberately not in the MVP, because that is exactly the kind of
	thing that becomes an exploit if it is rushed.
	==========================================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ClassConfig = require(ReplicatedStorage.Modules.ClassConfig)
local CombatConfig = require(ReplicatedStorage.Modules.CombatConfig)
local Enums = require(ReplicatedStorage.Modules.Enums)
local Remotes = require(ReplicatedStorage.RemoteEvents.Remotes)
local SwingMath = require(ReplicatedStorage.Modules.SwingMath)
local Types = require(ReplicatedStorage.Modules.Types)
local WeaponConfig = require(ReplicatedStorage.Modules.WeaponConfig)

local DamageService = require(script.Parent.DamageService)
local EffectBroadcaster = require(script.Parent.EffectBroadcaster)
local RateLimiter = require(script.Parent.RateLimiter)
local StaminaService = require(script.Parent.StaminaService)

type CombatState = Types.CombatState
type WeaponDef = Types.WeaponDef

local CombatService = {}

local states: { [Player]: CombatState } = {}
local combatEnabled = true

local limiters = {
	attack = RateLimiter.new(CombatConfig.RateLimits.Attack.tokens, CombatConfig.RateLimits.Attack.perSecond),
	block = RateLimiter.new(CombatConfig.RateLimits.Block.tokens, CombatConfig.RateLimits.Block.perSecond),
	feint = RateLimiter.new(CombatConfig.RateLimits.Feint.tokens, CombatConfig.RateLimits.Feint.perSecond),
	sprint = RateLimiter.new(CombatConfig.RateLimits.Sprint.tokens, CombatConfig.RateLimits.Sprint.perSecond),
}

-- Reused between traces. Allocating a RaycastParams per cast would mean tens of
-- thousands of short-lived tables a minute in a 50v50 fight.
local traceParams = RaycastParams.new()
traceParams.FilterType = Enum.RaycastFilterType.Exclude
traceParams.IgnoreWater = true

-- ============================================================== helpers ====

local function newState(player: Player): CombatState
	return {
		player = player,
		character = nil,
		humanoid = nil,
		root = nil,
		alive = false,
		spawnedAt = 0,

		classId = ClassConfig.Default,
		weaponId = ClassConfig.get(ClassConfig.Default).Weapons[1],

		phase = Enums.CombatPhase.Idle,
		phaseStart = 0,
		phaseEnd = math.huge,
		direction = Enums.AttackDirection.Right,
		timing = nil,

		traceAlpha = 0,
		traceRootCF = nil,
		hitsThisSwing = {},
		hitCount = 0,

		blocking = false,
		blockHeld = false,
		blockStart = 0,
		sprinting = false,
		sprintHeld = false,

		stamina = CombatConfig.StaminaMax,
		staminaMax = CombatConfig.StaminaMax,
		lastStaminaSpend = 0,
		exhaustedUntil = 0,

		drawStart = 0,

		lastAttacker = nil,
		lastAttackerAt = 0,

		lastSentStamina = -1,
		lastStatusSend = 0,
	}
end

function CombatService.getState(player: Player): CombatState?
	return states[player]
end

function CombatService.getStates(): { [Player]: CombatState }
	return states
end

--[[
	Round control. While combat is disabled (countdown, score screen) every
	request is dropped at the door - no half-finished swings can survive a
	round transition.
]]
function CombatService.setCombatEnabled(enabled: boolean)
	combatEnabled = enabled
	if enabled then
		return
	end
	for _, state in states do
		CombatService.setPhase(state, Enums.CombatPhase.Idle, math.huge)
		state.blocking = false
		state.blockHeld = false
		state.sprinting = false
		state.sprintHeld = false
	end
end

function CombatService.setPhase(state: CombatState, phase: number, duration: number)
	local now = os.clock()
	state.phase = phase
	state.phaseStart = now
	state.phaseEnd = if duration == math.huge then math.huge else now + duration
end

local function canAct(state: CombatState): boolean
	if not combatEnabled or not state.alive then
		return false
	end
	local humanoid = state.humanoid
	return humanoid ~= nil and humanoid.Health > 0
end

--[[
	Resolves the character model a hit part belongs to. Returns nil for map
	geometry, which is the signal that the blade was stopped by the world.
]]
local function getCharacterModel(part: BasePart): Model?
	local model = part:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end
	-- Attribute check rather than FindFirstChildOfClass("Humanoid"): it is a
	-- single attribute read on the hot path, and an untagged character is one
	-- that is mid-spawn and must not be hittable anyway.
	if model:GetAttribute("TeamId") == nil then
		return nil
	end
	return model
end

-- ============================================================ hit tracing ==

--[[
	Sweeps one blade sample from `p0` to `p1` and resolves whatever it finds.

	Returns false if the swing was interrupted (the attacker got parried), in
	which case the caller must stop tracing this swing entirely.
]]
local function sweepSegment(state: CombatState, weapon: WeaponDef, p0: Vector3, p1: Vector3): boolean
	local delta = p1 - p0
	if delta.Magnitude < 1e-3 then
		return true
	end

	local attackerCharacter = state.character
	if not attackerCharacter then
		return true
	end

	-- Rebuilt per segment: characters we have already tested get excluded so
	-- the next cast can reach the enemy standing behind them (cleave), while a
	-- wall simply ends the sweep.
	local filter: { Instance } = { attackerCharacter }

	for _ = 1, weapon.MaxTargets + 2 do
		if state.hitCount >= weapon.MaxTargets then
			return true
		end

		traceParams.FilterDescendantsInstances = filter
		local result = workspace:Spherecast(p0, CombatConfig.TraceRadius, delta, traceParams)
		if not result then
			return true
		end

		local model = getCharacterModel(result.Instance)
		if not model then
			-- Map geometry: the blade physically cannot reach anything further
			-- along this segment. Swinging through walls is not a feature.
			return true
		end

		table.insert(filter, model)

		local victimPlayer = Players:GetPlayerFromCharacter(model)
		local victimState = if victimPlayer then states[victimPlayer] else nil
		if not victimState or state.hitsThisSwing[model] then
			continue
		end

		local hitResult = DamageService.resolveMelee(state, victimState, weapon, state.direction, result.Instance)
		if hitResult == Enums.HitResult.Ignored then
			-- Allies and invulnerable players do not stop or consume a swing.
			continue
		end

		state.hitsThisSwing[model] = true
		state.hitCount += 1

		EffectBroadcaster.broadcastIncluding(
			result.Position,
			{ state.player, victimState.player },
			Enums.EffectKind.Impact,
			hitResult,
			result.Position,
			state.weaponId,
			victimState.character
		)

		if hitResult == Enums.HitResult.Parried then
			-- The defender beat the swing: attacker eats a stagger and the
			-- blade stops dead.
			CombatService.setPhase(state, Enums.CombatPhase.Staggered, CombatConfig.ParryStaggerDuration)
			state.blocking = false
			EffectBroadcaster.broadcast(
				result.Position,
				Enums.EffectKind.Stagger,
				attackerCharacter,
				CombatConfig.ParryStaggerDuration
			)
			return false
		elseif hitResult == Enums.HitResult.BlockBroken then
			CombatService.setPhase(victimState, Enums.CombatPhase.Staggered, CombatConfig.BlockBreakStaggerDuration)
			victimState.blocking = false
			victimState.blockHeld = false
			EffectBroadcaster.broadcast(
				result.Position,
				Enums.EffectKind.Stagger,
				model,
				CombatConfig.BlockBreakStaggerDuration
			)
		end
	end

	return true
end

--[[
	Advances the blade from where the last tick left it to where it is now, and
	traces every blade sample along the way.

	Sub-stepping matters: a greatsword tip covers ~14 studs in a 0.28s release,
	and at 30 server FPS that is ~2.3 studs per tick. Without sweeping between
	the previous and current positions a thin target could sit between two
	samples and never be touched.
]]
local function traceSwing(state: CombatState, weapon: WeaponDef, fromAlpha: number, toAlpha: number)
	local root = state.root
	if not root then
		return
	end

	local previousRootCF = state.traceRootCF or root.CFrame
	local currentRootCF = root.CFrame
	local steps = math.clamp(math.ceil((toAlpha - fromAlpha) / 0.25), 1, CombatConfig.MaxTraceStepsPerTick)

	for step = 1, steps do
		local t0 = (step - 1) / steps
		local t1 = step / steps
		local alpha0 = fromAlpha + (toAlpha - fromAlpha) * t0
		local alpha1 = fromAlpha + (toAlpha - fromAlpha) * t1

		-- Interpolate the root too: a player who is running or turning drags
		-- their blade with them, and the trace has to follow.
		local rootCF0 = previousRootCF:Lerp(currentRootCF, t0)
		local rootCF1 = previousRootCF:Lerp(currentRootCF, t1)

		local swingCF0 = SwingMath.getSwingCFrame(rootCF0, weapon, state.direction, alpha0)
		local swingCF1 = SwingMath.getSwingCFrame(rootCF1, weapon, state.direction, alpha1)

		for _, fraction in CombatConfig.BladeSamples do
			local p0 = SwingMath.getBladePoint(swingCF0, weapon, fraction)
			local p1 = SwingMath.getBladePoint(swingCF1, weapon, fraction)
			if not sweepSegment(state, weapon, p0, p1) then
				return -- parried, swing is over
			end
		end
	end

	state.traceRootCF = currentRootCF
end

-- ======================================================== state machine ====

local function beginRelease(state: CombatState)
	local timing = state.timing
	if not timing then
		CombatService.setPhase(state, Enums.CombatPhase.Idle, math.huge)
		return
	end

	CombatService.setPhase(state, Enums.CombatPhase.Release, timing.Release)
	state.traceAlpha = 0
	state.traceRootCF = if state.root then state.root.CFrame else nil
	table.clear(state.hitsThisSwing)
	state.hitCount = 0

	local root = state.root
	if root then
		EffectBroadcaster.broadcast(
			root.Position,
			Enums.EffectKind.SwingRelease,
			state.character,
			state.direction,
			timing.Release
		)
	end
end

local function beginRecovery(state: CombatState)
	local timing = state.timing
	local recovery = if timing then timing.Recovery else 0.3
	CombatService.setPhase(state, Enums.CombatPhase.Recovery, recovery)
end

local function finishAction(state: CombatState)
	-- Guard goes back up automatically if the player is still holding block.
	if state.blockHeld and canAct(state) then
		CombatService.setPhase(state, Enums.CombatPhase.Blocking, math.huge)
		state.blocking = true
		-- Delayed activation: you cannot chain an attack straight into a parry.
		-- DamageService treats a block whose start time is in the future as
		-- "guard not up yet".
		state.blockStart = os.clock() + CombatConfig.BlockRaiseDelay
	else
		CombatService.setPhase(state, Enums.CombatPhase.Idle, math.huge)
		state.blocking = false
	end
end

-- =========================================================== requests ======

local function onAttackRequest(player: Player, rawDirection: unknown)
	if not limiters.attack:consume(player) then
		return
	end
	if typeof(rawDirection) ~= "number" then
		return
	end

	local direction = math.floor(rawDirection)
	if direction < 1 or direction > Enums.AttackDirectionCount then
		return
	end

	local state = states[player]
	if not state or not canAct(state) then
		return
	end
	-- Only Idle and Blocking may start an attack. Windup/Release/Recovery/
	-- Staggered all mean "you are busy", and that is the whole commitment
	-- system: once you swing, you are committed until recovery ends.
	if state.phase ~= Enums.CombatPhase.Idle and state.phase ~= Enums.CombatPhase.Blocking then
		return
	end

	local weapon = WeaponConfig.get(state.weaponId)
	if weapon.Kind ~= "Melee" then
		return -- bows go through RangedService
	end
	if not StaminaService.canAfford(state, WeaponConfig.getStaminaCost(weapon, direction)) then
		return
	end

	StaminaService.spend(state, WeaponConfig.getStaminaCost(weapon, direction))

	local timing = WeaponConfig.getTiming(weapon, direction, StaminaService.getTimeScale(state))
	state.timing = timing
	state.direction = direction
	state.blocking = false
	CombatService.setPhase(state, Enums.CombatPhase.Windup, timing.Windup)

	local root = state.root
	if root then
		EffectBroadcaster.broadcast(
			root.Position,
			Enums.EffectKind.SwingStart,
			state.character,
			direction,
			timing.Windup,
			state.weaponId
		)
	end
end

local function onFeintRequest(player: Player)
	if not limiters.feint:consume(player) then
		return
	end

	local state = states[player]
	if not state or not canAct(state) then
		return
	end
	if state.phase ~= Enums.CombatPhase.Windup then
		return
	end

	local timing = state.timing
	if not timing then
		return
	end

	-- Only the first part of a windup may be cancelled. A feint that works up
	-- to the last frame is not a mind game, it is an unpunishable cancel.
	local elapsed = os.clock() - state.phaseStart
	if elapsed > timing.Windup * CombatConfig.FeintWindowFraction then
		return
	end
	if not StaminaService.canAfford(state, CombatConfig.FeintStaminaCost) then
		return
	end

	StaminaService.spend(state, CombatConfig.FeintStaminaCost)
	state.timing = { Windup = 0, Release = 0, Recovery = CombatConfig.FeintRecovery }
	CombatService.setPhase(state, Enums.CombatPhase.Recovery, CombatConfig.FeintRecovery)

	local root = state.root
	if root then
		EffectBroadcaster.broadcast(root.Position, Enums.EffectKind.Feint, state.character)
	end
end

local function onBlockRequest(player: Player, down: unknown)
	if not limiters.block:consume(player) then
		return
	end
	if typeof(down) ~= "boolean" then
		return
	end

	local state = states[player]
	if not state or not canAct(state) then
		return
	end

	state.blockHeld = down

	if down then
		-- A guard can only be raised from a neutral stance. Mid-attack the
		-- input is remembered and applied when the recovery ends.
		if state.phase == Enums.CombatPhase.Idle then
			CombatService.setPhase(state, Enums.CombatPhase.Blocking, math.huge)
			state.blocking = true
			state.blockStart = os.clock()
			local root = state.root
			if root then
				EffectBroadcaster.broadcast(root.Position, Enums.EffectKind.GuardUp, state.character)
			end
		end
	else
		if state.phase == Enums.CombatPhase.Blocking then
			CombatService.setPhase(state, Enums.CombatPhase.Idle, math.huge)
			state.blocking = false
			local root = state.root
			if root then
				EffectBroadcaster.broadcast(root.Position, Enums.EffectKind.GuardDown, state.character)
			end
		end
		state.blocking = false
	end
end

local function onSprintRequest(player: Player, on: unknown)
	if not limiters.sprint:consume(player) then
		return
	end
	if typeof(on) ~= "boolean" then
		return
	end

	local state = states[player]
	if not state or not canAct(state) then
		return
	end

	-- Only the *intent* is stored. Whether it turns into actual sprinting is
	-- re-evaluated every tick, so holding shift through an attack resumes the
	-- sprint automatically instead of needing another key press.
	state.sprintHeld = on
	if not on then
		state.sprinting = false
	end
end

-- ============================================================== update =====

--[[
	Movement speed is a *replicated* property, so it is only written when the
	value actually changes. Setting Humanoid.WalkSpeed every frame for 100
	players is a replication storm for no gameplay benefit.
]]
local function updateWalkSpeed(state: CombatState)
	local humanoid = state.humanoid
	if not humanoid then
		return
	end

	local classDef = ClassConfig.find(state.classId) or ClassConfig.get(ClassConfig.Default)
	local speed = classDef.WalkSpeed

	if not combatEnabled then
		-- Round countdown and score screen: everyone is planted where they
		-- stand. Doing it here rather than with a separate "frozen" flag means
		-- there is exactly one place that owns WalkSpeed.
		speed = 0
	elseif state.phase == Enums.CombatPhase.Staggered then
		speed *= 0.45
	elseif state.blocking then
		speed *= 0.7
	elseif state.phase == Enums.CombatPhase.Windup or state.phase == Enums.CombatPhase.Release then
		speed *= 0.85
	elseif state.sprinting then
		speed += CombatConfig.SprintSpeedBonus
	end

	if StaminaService.isExhausted(state) then
		speed *= 0.85
	end

	if math.abs(humanoid.WalkSpeed - speed) > 0.05 then
		humanoid.WalkSpeed = speed
	end
end

local function sendStatus(state: CombatState, now: number)
	if now - state.lastStatusSend < CombatConfig.StatusSendInterval then
		return
	end
	if math.abs(state.stamina - state.lastSentStamina) < CombatConfig.StatusSendMinDelta then
		return
	end

	state.lastStatusSend = now
	state.lastSentStamina = state.stamina

	Remotes.get("StatusUpdate"):FireClient(
		state.player,
		state.stamina,
		state.staminaMax,
		StaminaService.isExhausted(state),
		state.phase
	)
end

local function updateState(state: CombatState, dt: number, now: number)
	if not state.alive then
		return
	end

	local humanoid = state.humanoid
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	-- Sprinting is a derived state, not a latched one: you sprint while you are
	-- holding the key, standing in neutral, actually moving, and not gassed.
	-- Recomputing it here means it can never get stuck on (draining stamina
	-- while stationary) or stuck off (after an attack interrupts it).
	state.sprinting = state.sprintHeld
		and state.phase == Enums.CombatPhase.Idle
		and humanoid.MoveDirection.Magnitude > 0.1
		and StaminaService.canSprint(state)

	StaminaService.update(state, dt)

	local phase = state.phase
	if phase == Enums.CombatPhase.Windup then
		if now >= state.phaseEnd then
			beginRelease(state)
		end
	elseif phase == Enums.CombatPhase.Release then
		local timing = state.timing
		local duration = if timing then math.max(timing.Release, 1e-3) else 0.2
		local alpha = math.clamp((now - state.phaseStart) / duration, 0, 1)

		traceSwing(state, WeaponConfig.get(state.weaponId), state.traceAlpha, alpha)
		state.traceAlpha = alpha

		-- traceSwing can knock us out of Release (parry), so re-check.
		if state.phase == Enums.CombatPhase.Release and alpha >= 1 then
			beginRecovery(state)
		end
	elseif phase == Enums.CombatPhase.Recovery or phase == Enums.CombatPhase.Staggered then
		if now >= state.phaseEnd then
			finishAction(state)
		end
	end

	updateWalkSpeed(state)
	sendStatus(state, now)
end

-- ========================================================= lifecycle ======

--[[
	Called by SpawnService once the character exists and has been tagged with a
	team and a loadout. Everything about the previous life is reset here.
]]
function CombatService.bindCharacter(player: Player, character: Model)
	local state = states[player]
	if not state then
		state = newState(player)
		states[player] = state
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?

	state.character = character
	state.humanoid = humanoid
	state.root = root
	state.alive = humanoid ~= nil and humanoid.Health > 0
	state.spawnedAt = os.clock()

	CombatService.setPhase(state, Enums.CombatPhase.Idle, math.huge)
	state.blocking = false
	state.blockHeld = false
	state.sprinting = false
	state.sprintHeld = false
	state.traceAlpha = 0
	state.traceRootCF = nil
	state.hitCount = 0
	state.timing = nil
	table.clear(state.hitsThisSwing)
	StaminaService.reset(state)

	state.lastSentStamina = -1
	sendStatus(state, os.clock())
end

function CombatService.unbindCharacter(player: Player)
	local state = states[player]
	if not state then
		return
	end
	state.alive = false
	state.character = nil
	state.humanoid = nil
	state.root = nil
	state.blocking = false
	state.blockHeld = false
	state.sprinting = false
	state.sprintHeld = false
	CombatService.setPhase(state, Enums.CombatPhase.Dead, math.huge)
end

--[[
	Called by ClassService when a loadout is applied. CombatService does not
	know what a "class" is beyond these three numbers.
]]
function CombatService.setLoadout(player: Player, classId: string, weaponId: string, staminaMax: number)
	local state = states[player]
	if not state then
		state = newState(player)
		states[player] = state
	end

	state.classId = classId
	state.weaponId = weaponId
	state.staminaMax = staminaMax
	state.stamina = math.min(state.stamina, staminaMax)

	Remotes.get("LoadoutUpdate"):FireClient(player, classId, weaponId)
end

function CombatService.setWeapon(player: Player, weaponId: string)
	local state = states[player]
	if not state then
		return
	end
	state.weaponId = weaponId
	-- Switching weapons cancels whatever you were doing, so it cannot be used
	-- to cancel a recovery for free.
	CombatService.setPhase(state, Enums.CombatPhase.Recovery, 0.35)
	Remotes.get("LoadoutUpdate"):FireClient(player, state.classId, weaponId)
end

local function onPlayerAdded(player: Player)
	states[player] = newState(player)
end

local function onPlayerRemoving(player: Player)
	DamageService.forgetPlayer(player, states)
	states[player] = nil
	limiters.attack:forget(player)
	limiters.block:forget(player)
	limiters.feint:forget(player)
	limiters.sprint:forget(player)
end

function CombatService.init()
	Remotes.get("AttackRequest").OnServerEvent:Connect(onAttackRequest)
	Remotes.get("FeintRequest").OnServerEvent:Connect(onFeintRequest)
	Remotes.get("BlockRequest").OnServerEvent:Connect(onBlockRequest)
	Remotes.get("SprintRequest").OnServerEvent:Connect(onSprintRequest)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- One loop for all combat. Adding a second Heartbeat connection per player
	-- would cost 100 scheduler entries a frame instead of one.
	RunService.Heartbeat:Connect(function(dt: number)
		local now = os.clock()
		for _, state in states do
			updateState(state, dt, now)
		end
	end)
end

return CombatService
