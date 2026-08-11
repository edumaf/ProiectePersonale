--!strict
--[[
	StaminaService

	Pure functions over a CombatState. No remotes, no instances, no state of its
	own - which makes the stamina rules trivial to reason about and to unit test
	later.

	The model:
	  * Spending sets a cooldown; regen only starts once you have stopped
	    spending for StaminaRegenDelay.
	  * Hitting zero puts you in "exhausted" for a fixed duration, which slows
	    your windups/recoveries and makes blocks leak damage. That is the
	    punishment for spamming - not an inability to act.
	  * Blocking drains passively, and blocked hits drain a chunk, so turtling
	    against a heavy weapon loses on its own.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Modules.CombatConfig)
local Types = require(ReplicatedStorage.Modules.Types)

type CombatState = Types.CombatState

local StaminaService = {}

function StaminaService.isExhausted(state: CombatState): boolean
	return os.clock() < state.exhaustedUntil
end

--[[
	Multiplier applied to windup/recovery durations. Exhausted players are
	slower, which is what actually loses them the fight.
]]
function StaminaService.getTimeScale(state: CombatState): number
	return if StaminaService.isExhausted(state) then CombatConfig.ExhaustTimeScale else 1
end

function StaminaService.canAfford(state: CombatState, amount: number): boolean
	-- Deliberately `> 0` rather than `>= amount`: you can always start an
	-- action with a sliver of stamina, you just end up exhausted afterwards.
	-- Blocking a full action out feels far worse than paying for it.
	return state.stamina > 0
end

function StaminaService.spend(state: CombatState, amount: number)
	if amount <= 0 then
		return
	end
	state.stamina = math.max(0, state.stamina - amount)
	state.lastStaminaSpend = os.clock()
	if state.stamina <= 0 then
		state.exhaustedUntil = os.clock() + CombatConfig.ExhaustDuration
	end
end

function StaminaService.restore(state: CombatState, amount: number)
	state.stamina = math.clamp(state.stamina + amount, 0, state.staminaMax)
end

--[[
	Per-tick regen and sprint drain. Called from the CombatService heartbeat so
	there is exactly one update loop over players in the whole combat system.
]]
function StaminaService.update(state: CombatState, dt: number)
	local now = os.clock()

	if state.sprinting then
		StaminaService.spend(state, CombatConfig.SprintStaminaDrain * dt)
		return
	end

	if state.blocking then
		StaminaService.spend(state, CombatConfig.BlockStaminaDrainPerSecond * dt)
		return
	end

	if now - state.lastStaminaSpend < CombatConfig.StaminaRegenDelay then
		return
	end

	if state.stamina < state.staminaMax then
		state.stamina = math.min(state.staminaMax, state.stamina + CombatConfig.StaminaRegenRate * dt)
	end
end

function StaminaService.reset(state: CombatState)
	state.stamina = state.staminaMax
	state.lastStaminaSpend = 0
	state.exhaustedUntil = 0
end

--[[
	Can this player start a sprint? Prevents chain-sprinting on fumes, which
	otherwise lets an exhausted player kite forever.
]]
function StaminaService.canSprint(state: CombatState): boolean
	return state.stamina >= CombatConfig.SprintMinStamina and not StaminaService.isExhausted(state)
end

return StaminaService
