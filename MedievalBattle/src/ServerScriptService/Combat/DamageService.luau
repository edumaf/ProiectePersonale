--!strict
--[[
	DamageService

	Turns "the server's trace says A's blade touched B" into a health change.
	It is the only place in the codebase that calls Humanoid:TakeDamage.

	It takes CombatStates as arguments rather than requiring CombatService, so
	the dependency graph stays acyclic (CombatService -> DamageService, never
	back). Anything the caller has to react to - staggering the attacker on a
	parry, playing effects - is returned as a HitResult instead of being done
	here.

	Resolution order, and why:
	  1. Liveness / friendly fire / spawn protection    (cheapest rejects first)
	  2. Block cone test                                 (is the defender facing it)
	  3. Parry window                                    (a block that beats the swing)
	  4. Block-break                                     (blocking on empty stamina)
	  5. Block leak                                      (class + weapon penetration)
	  6. Flat armour
	  7. Limb multiplier                                 (extension point, 1.0 today)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassConfig = require(ReplicatedStorage.Modules.ClassConfig)
local CombatConfig = require(ReplicatedStorage.Modules.CombatConfig)
local Enums = require(ReplicatedStorage.Modules.Enums)
local Remotes = require(ReplicatedStorage.RemoteEvents.Remotes)
local Types = require(ReplicatedStorage.Modules.Types)
local WeaponConfig = require(ReplicatedStorage.Modules.WeaponConfig)

local StaminaService = require(script.Parent.StaminaService)
local TeamService = require(script.Parent.Parent.Rounds.TeamService)

type CombatState = Types.CombatState
type WeaponDef = Types.WeaponDef

local DamageService = {}

type KillCallback = (killer: Player?, victim: Player, weaponId: string) -> ()
local killCallbacks: { KillCallback } = {}

function DamageService.onKill(callback: KillCallback)
	table.insert(killCallbacks, callback)
end

local function isInvulnerable(character: Model): boolean
	local until_ = character:GetAttribute("InvulnerableUntil")
	return typeof(until_) == "number" and os.clock() < until_
end

--[[
	Is the attacker inside the defender's frontal guard cone?

	Measured on the horizontal plane only: looking up or down should not open
	or close your guard, and flattening the vectors keeps a defender on a ramp
	from being unblockable.
]]
local function isInsideBlockCone(victimRoot: BasePart, attackerPosition: Vector3, coneDegrees: number): boolean
	local toAttacker = attackerPosition - victimRoot.Position
	local flat = Vector3.new(toAttacker.X, 0, toAttacker.Z)
	if flat.Magnitude < 1e-3 then
		return true -- standing inside each other; treat as blocked, favours the defender
	end

	local look = victimRoot.CFrame.LookVector
	local lookFlat = Vector3.new(look.X, 0, look.Z)
	if lookFlat.Magnitude < 1e-3 then
		return false
	end

	local cosAngle = lookFlat.Unit:Dot(flat.Unit)
	-- coneDegrees is the *total* width, so the half-angle is what we compare.
	return cosAngle >= math.cos(math.rad(coneDegrees / 2))
end

local function getClassDef(state: CombatState)
	return ClassConfig.find(state.classId) or ClassConfig.get(ClassConfig.Default)
end

local function fireKill(killer: Player?, victim: Player, weaponId: string)
	local killerTeam = if killer then TeamService.getTeamId(killer) else nil
	local victimTeam = TeamService.getTeamId(victim)

	Remotes.get("KillFeed"):FireAllClients(
		if killer then killer.DisplayName else "",
		victim.DisplayName,
		weaponId,
		killerTeam,
		victimTeam
	)

	for _, callback in killCallbacks do
		task.spawn(callback, killer, victim, weaponId)
	end
end

--[[
	Applies a final, already-modified damage number and handles the kill.
	`weaponId` is only used for the kill feed.
]]
function DamageService.applyDamage(
	victimState: CombatState,
	amount: number,
	attacker: Player?,
	weaponId: string
): boolean
	local humanoid = victimState.humanoid
	if not humanoid or humanoid.Health <= 0 or not victimState.alive then
		return false
	end

	if attacker then
		victimState.lastAttacker = attacker
		victimState.lastAttackerAt = os.clock()
	end

	humanoid:TakeDamage(amount)

	if humanoid.Health <= 0 then
		-- Guard against a cleave landing two hits in the same frame and firing
		-- two kill feed entries. Humanoid.Died is handled elsewhere (respawn);
		-- this flag is purely for attribution.
		victimState.alive = false
		fireKill(attacker, victimState.player, weaponId)
		return true
	end

	return false
end

--[[
	Full melee resolution. Returns the HitResult so CombatService can stagger the
	attacker on a parry and broadcast the right effect.

	`hitPosition` is where the blade sample landed, used only for effects.
]]
function DamageService.resolveMelee(
	attackerState: CombatState,
	victimState: CombatState,
	weapon: WeaponDef,
	direction: number,
	hitPart: BasePart
): number
	local attackerCharacter = attackerState.character
	local victimCharacter = victimState.character
	local attackerRoot = attackerState.root
	local victimRoot = victimState.root
	local victimHumanoid = victimState.humanoid

	if not attackerCharacter or not victimCharacter or not attackerRoot or not victimRoot or not victimHumanoid then
		return Enums.HitResult.Ignored
	end
	if not victimState.alive or victimHumanoid.Health <= 0 then
		return Enums.HitResult.Ignored
	end
	if isInvulnerable(victimCharacter) then
		return Enums.HitResult.Ignored
	end
	if not CombatConfig.FriendlyFire and not TeamService.areEnemies(attackerCharacter, victimCharacter) then
		return Enums.HitResult.Ignored
	end

	local victimClass = getClassDef(victimState)
	local damage = WeaponConfig.getDamage(weapon, direction)

	-- ---------------------------------------------------------------- block --
	local now = os.clock()

	-- `blockStart` can be in the future: raising a guard straight out of an
	-- attack recovery costs CombatConfig.BlockRaiseDelay before it counts, so
	-- "swing, get read, instantly parry" is not a free option.
	local guardIsUp = victimState.blocking
		and victimState.phase == Enums.CombatPhase.Blocking
		and now >= victimState.blockStart

	local blocked = guardIsUp
		and isInsideBlockCone(victimRoot, attackerRoot.Position, victimClass.BlockAngleDegrees)

	if blocked then
		-- Parry: guard raised inside the window right before impact. Costs the
		-- defender nothing and puts the attacker on the floor. This is the
		-- highest-skill defensive option in the game, so it is strictly timed.
		if now - victimState.blockStart <= CombatConfig.ParryWindow then
			return Enums.HitResult.Parried
		end

		-- Block-break: guard up but nothing left in the tank. Full damage plus
		-- a stagger; this is how heavy weapons beat turtles.
		if victimState.stamina <= 0 then
			local broken = damage * (1 - victimClass.DamageReduction)
			DamageService.applyDamage(victimState, broken, attackerState.player, weapon.Id)
			return Enums.HitResult.BlockBroken
		end

		StaminaService.spend(victimState, weapon.BlockStaminaDrain)
		StaminaService.spend(attackerState, CombatConfig.BlockedAttackerStaminaCost)

		-- Leak: the class's block quality, with the weapon's penetration as a
		-- floor (a greatsword gets through a shield a little regardless).
		local leak = math.max(victimClass.BlockDamageMultiplier, weapon.BlockPenetration)
		if StaminaService.isExhausted(victimState) then
			leak *= CombatConfig.ExhaustBlockMultiplier
		end

		local throughBlock = damage * math.clamp(leak, 0, 1) * (1 - victimClass.DamageReduction)
		if throughBlock > 0 then
			DamageService.applyDamage(victimState, throughBlock, attackerState.player, weapon.Id)
		end
		return Enums.HitResult.Blocked
	end

	-- ------------------------------------------------------------ clean hit --
	local limbMultiplier = CombatConfig.LimbMultipliers[hitPart.Name] or CombatConfig.DefaultLimbMultiplier
	local final = damage * limbMultiplier * (1 - victimClass.DamageReduction)

	DamageService.applyDamage(victimState, final, attackerState.player, weapon.Id)
	return Enums.HitResult.Hit
end

--[[
	Arrows. No block interaction (BlockPenetration on the bow is 1) but armour
	and limb multipliers still apply, so a Knight is genuinely arrow-resistant.
]]
function DamageService.resolveRanged(
	attacker: Player?,
	victimState: CombatState,
	weapon: WeaponDef,
	hitPart: BasePart
): number
	local victimCharacter = victimState.character
	if not victimCharacter or not victimState.alive then
		return Enums.HitResult.Ignored
	end
	if isInvulnerable(victimCharacter) then
		return Enums.HitResult.Ignored
	end

	if attacker and not CombatConfig.FriendlyFire then
		local attackerCharacter = attacker.Character
		if attackerCharacter and not TeamService.areEnemies(attackerCharacter, victimCharacter) then
			return Enums.HitResult.Ignored
		end
	end

	local victimClass = getClassDef(victimState)
	local limbMultiplier = CombatConfig.LimbMultipliers[hitPart.Name] or CombatConfig.DefaultLimbMultiplier
	local damage = WeaponConfig.getDamage(weapon, Enums.AttackDirection.Stab)
		* limbMultiplier
		* (1 - victimClass.DamageReduction)

	DamageService.applyDamage(victimState, damage, attacker, weapon.Id)
	return Enums.HitResult.Hit
end

--[[
	Non-player targets: training dummies.

	They carry a TeamId attribute like a real character (so the hit tracer finds
	them) but no CombatState, so there is no guard to check and no stamina to
	drain - a dummy simply takes the flat number. Health lives in an attribute,
	which replicates to every client for free and is all the dummy needs.

	TeamId 0 means "hostile to everyone", so both teams can train on the same
	target. A dummy tagged with a real team id respects friendly fire instead.
]]
function DamageService.resolveDummy(
	attackerState: CombatState,
	model: Model,
	weapon: WeaponDef,
	direction: number,
	hitPart: BasePart
): number
	local health = model:GetAttribute("Health")
	if typeof(health) ~= "number" or health <= 0 then
		return Enums.HitResult.Ignored
	end

	local teamId = model:GetAttribute("TeamId")
	if typeof(teamId) == "number" and teamId ~= 0 and not CombatConfig.FriendlyFire then
		local attackerCharacter = attackerState.character
		if attackerCharacter and not TeamService.areEnemies(attackerCharacter, model) then
			return Enums.HitResult.Ignored
		end
	end

	local limbMultiplier = CombatConfig.LimbMultipliers[hitPart.Name] or CombatConfig.DefaultLimbMultiplier
	local damage = WeaponConfig.getDamage(weapon, direction) * limbMultiplier

	model:SetAttribute("Health", math.max(0, health - damage))
	model:SetAttribute("LastHitBy", attackerState.player.Name)
	return Enums.HitResult.Hit
end

--[[
	Kills a player outright (fell out of the map, round reset, ...). Kept here so
	every path to a death goes through the same attribution and kill feed.
]]
function DamageService.kill(victimState: CombatState, reason: string)
	local humanoid = victimState.humanoid
	if not humanoid or not victimState.alive then
		return
	end
	victimState.alive = false
	humanoid.Health = 0
	fireKill(nil, victimState.player, reason)
end

--[[
	Player left mid-fight: drop any attribution pointing at them so we never
	hold a reference to a departed player.
]]
function DamageService.forgetPlayer(player: Player, states: { [Player]: CombatState })
	for _, state in states do
		if state.lastAttacker == player then
			state.lastAttacker = nil
		end
	end
end

return DamageService
