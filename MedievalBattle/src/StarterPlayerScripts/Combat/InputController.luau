--!strict
--[[
	InputController

	Turns mouse and keyboard into *requests*, and runs a local mirror of the
	combat state machine so the game feels instant.

	Directional attacks
	-------------------
	The swing direction comes from how the mouse was moving in the ~150ms
	before the click, exactly like Chivalry/Mordhau:

	    flick left   -> Left swing        flick up    -> Overhead
	    flick right  -> Right swing       flick down  -> Stab
	    no movement  -> Right swing (the neutral default)

	This needs a locked cursor to work at all - see CameraController.

	Prediction
	----------
	The local machine runs the same timings the server does (WeaponConfig is
	shared) and starts animating on the click. The server is still the only
	thing that decides whether the swing happened; if it never confirms within
	CONFIRM_TIMEOUT the prediction is rolled back and the weapon snaps to rest.
	That is the visible symptom of a rejected request - out of stamina, still in
	recovery, or rate limited.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ClassConfig = require(ReplicatedStorage.Modules.ClassConfig)
local CombatConfig = require(ReplicatedStorage.Modules.CombatConfig)
local Enums = require(ReplicatedStorage.Modules.Enums)
local Remotes = require(ReplicatedStorage.RemoteEvents.Remotes)
local WeaponConfig = require(ReplicatedStorage.Modules.WeaponConfig)

local SwingAnimator = require(script.Parent.SwingAnimator)

local InputController = {}

local player = Players.LocalPlayer

-- How far back to look for the swing direction, and how much movement counts.
local DIRECTION_WINDOW = 0.15
local DIRECTION_DEADZONE = 5
-- If the server has not echoed our swing by now, assume it was rejected.
local CONFIRM_TIMEOUT = 0.4

local local_ = {
	phase = Enums.CombatPhase.Idle,
	phaseEnd = math.huge,
	direction = Enums.AttackDirection.Right,
	timing = nil :: any,

	weaponId = ClassConfig.get(ClassConfig.Default).Weapons[1],
	classId = ClassConfig.Default,
	exhausted = false,

	blockHeld = false,
	sprinting = false,

	predicting = false,
	awaitingConfirm = false,
	requestSentAt = 0,
}

type MouseSample = { t: number, x: number, y: number }
local mouseSamples: { MouseSample } = {}

-- Combat input is switched off while a full-screen menu is open, so clicking
-- "Archer" does not also throw a swing.
local inputEnabled = true

-- Installed by RangedController. Keeping it a hook rather than a require means
-- InputController has no idea ranged combat exists, and the two modules can be
-- owned by different people.
type RangedHandlers = { press: () -> (), release: () -> () }
local rangedHandlers: RangedHandlers? = nil

function InputController.setInputEnabled(enabled: boolean)
	inputEnabled = enabled
end

function InputController.setRangedHandlers(handlers: RangedHandlers)
	rangedHandlers = handlers
end

function InputController.isPredicting(): boolean
	return local_.predicting
end

function InputController.getWeaponId(): string
	return local_.weaponId
end

function InputController.getClassId(): string
	return local_.classId
end

--[[
	Called by EffectController when the server echoes our own swing back. That
	is the confirmation the prediction was accepted.
]]
function InputController.onServerConfirm()
	local_.awaitingConfirm = false
end

--[[
	The server staggered us (parried, or block broken). Prediction is wrong by
	definition here, so the server's word is taken directly.
]]
function InputController.onServerStagger(duration: number)
	local_.phase = Enums.CombatPhase.Staggered
	local_.phaseEnd = os.clock() + duration
	local_.predicting = false
	local_.awaitingConfirm = false
end

local function character(): Model?
	return player.Character
end

local function canStartAction(): boolean
	local char = character()
	if not char then
		return false
	end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	return local_.phase == Enums.CombatPhase.Idle or local_.phase == Enums.CombatPhase.Blocking
end

--[[
	Sums the recent mouse movement and turns it into an attack direction.
]]
local function readDirection(): number
	local now = os.clock()
	local x, y = 0, 0

	for index = #mouseSamples, 1, -1 do
		local sample = mouseSamples[index]
		if now - sample.t > DIRECTION_WINDOW then
			break
		end
		x += sample.x
		y += sample.y
	end

	if math.abs(x) < DIRECTION_DEADZONE and math.abs(y) < DIRECTION_DEADZONE then
		return Enums.AttackDirection.Right
	end

	if math.abs(x) >= math.abs(y) then
		return if x > 0 then Enums.AttackDirection.Right else Enums.AttackDirection.Left
	end
	-- Screen Y grows downward, so a negative delta is an upward flick.
	return if y < 0 then Enums.AttackDirection.Overhead else Enums.AttackDirection.Stab
end

local function setLocalPhase(phase: number, duration: number)
	local_.phase = phase
	local_.phaseEnd = if duration == math.huge then math.huge else os.clock() + duration
end

local function startAttack()
	if not canStartAction() then
		return
	end

	local weapon = WeaponConfig.get(local_.weaponId)
	if weapon.Kind ~= "Melee" then
		-- Bows draw on hold and loose on release, so they need the raw
		-- press/release pair rather than this one-shot path.
		if rangedHandlers then
			rangedHandlers.press()
		end
		return
	end

	local direction = readDirection()
	local scale = if local_.exhausted then CombatConfig.ExhaustTimeScale else 1
	local timing = WeaponConfig.getTiming(weapon, direction, scale)

	local_.direction = direction
	local_.timing = timing
	local_.predicting = true
	local_.awaitingConfirm = true
	local_.requestSentAt = os.clock()
	setLocalPhase(Enums.CombatPhase.Windup, timing.Windup)

	local char = character()
	if char then
		SwingAnimator.predictSwing(char, direction, timing.Windup)
	end

	Remotes.get("AttackRequest"):FireServer(direction)
end

local function startFeint()
	if local_.phase ~= Enums.CombatPhase.Windup then
		return
	end
	local timing = local_.timing
	if not timing then
		return
	end

	-- Mirror the server's window so the client does not send a request that is
	-- certain to be rejected.
	local elapsed = timing.Windup - math.max(local_.phaseEnd - os.clock(), 0)
	if elapsed > timing.Windup * CombatConfig.FeintWindowFraction then
		return
	end

	setLocalPhase(Enums.CombatPhase.Recovery, CombatConfig.FeintRecovery)
	local_.predicting = false

	local char = character()
	if char then
		SwingAnimator.onFeint(char)
	end

	Remotes.get("FeintRequest"):FireServer()
end

local function setBlock(down: boolean)
	local_.blockHeld = down
	Remotes.get("BlockRequest"):FireServer(down)

	local char = character()
	if down then
		if local_.phase == Enums.CombatPhase.Idle then
			setLocalPhase(Enums.CombatPhase.Blocking, math.huge)
			if char then
				SwingAnimator.onGuard(char, true)
			end
		end
	else
		if local_.phase == Enums.CombatPhase.Blocking then
			setLocalPhase(Enums.CombatPhase.Idle, math.huge)
			if char then
				SwingAnimator.onGuard(char, false)
			end
		end
	end
end

local function setSprint(on: boolean)
	if local_.sprinting == on then
		return
	end
	local_.sprinting = on
	Remotes.get("SprintRequest"):FireServer(on)
end

-- ============================================================== stepping ===

local function step()
	local now = os.clock()

	-- Roll back an unconfirmed swing.
	if local_.awaitingConfirm and now - local_.requestSentAt > CONFIRM_TIMEOUT then
		local_.awaitingConfirm = false
		local_.predicting = false
		setLocalPhase(if local_.blockHeld then Enums.CombatPhase.Blocking else Enums.CombatPhase.Idle, math.huge)
		local char = character()
		if char then
			SwingAnimator.cancelPrediction(char)
		end
		return
	end

	if now < local_.phaseEnd then
		return
	end

	local char = character()
	local timing = local_.timing

	if local_.phase == Enums.CombatPhase.Windup then
		local release = if timing then timing.Release else 0.2
		setLocalPhase(Enums.CombatPhase.Release, release)
		if char then
			SwingAnimator.onSwingRelease(char, local_.direction, release)
		end
	elseif local_.phase == Enums.CombatPhase.Release then
		local recovery = if timing then timing.Recovery else 0.3
		setLocalPhase(Enums.CombatPhase.Recovery, recovery)
		if char then
			SwingAnimator.onRecovery(char, local_.direction, recovery)
		end
	elseif local_.phase == Enums.CombatPhase.Recovery or local_.phase == Enums.CombatPhase.Staggered then
		local_.predicting = false
		if local_.blockHeld then
			setLocalPhase(Enums.CombatPhase.Blocking, math.huge)
			if char then
				SwingAnimator.onGuard(char, true)
			end
		else
			setLocalPhase(Enums.CombatPhase.Idle, math.huge)
		end
	end
end

-- =============================================================== wiring ====

local function onInputBegan(input: InputObject, processed: boolean)
	if processed or not inputEnabled then
		return -- the click went to a UI button, or a menu is open
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		startAttack()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		setBlock(true)
	elseif input.KeyCode == Enum.KeyCode.Q then
		startFeint()
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		setSprint(true)
	elseif input.KeyCode == Enum.KeyCode.F then
		Remotes.get("SwapWeapon"):FireServer()
	end
end

local function onInputEnded(input: InputObject)
	-- Note: releases are handled even while input is disabled. Otherwise
	-- opening a menu mid-block would leave the guard stuck up forever.
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if rangedHandlers then
			rangedHandlers.release()
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		setBlock(false)
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		setSprint(false)
	end
end

local function onInputChanged(input: InputObject)
	if input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end

	local now = os.clock()
	table.insert(mouseSamples, { t = now, x = input.Delta.X, y = input.Delta.Y })

	-- Keep the buffer to just the window we read from.
	while #mouseSamples > 0 and now - mouseSamples[1].t > DIRECTION_WINDOW * 2 do
		table.remove(mouseSamples, 1)
	end
end

local function onCharacterAdded(char: Model)
	local_.phase = Enums.CombatPhase.Idle
	local_.phaseEnd = math.huge
	local_.predicting = false
	local_.awaitingConfirm = false
	local_.blockHeld = false
	local_.sprinting = false
	SwingAnimator.clear(char)

	local humanoid = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid.Died:Connect(function()
			local_.phase = Enums.CombatPhase.Dead
			local_.phaseEnd = math.huge
			local_.predicting = false
		end)
	end
end

function InputController.init()
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(function(input)
		onInputEnded(input)
	end)
	UserInputService.InputChanged:Connect(onInputChanged)

	Remotes.get("LoadoutUpdate").OnClientEvent:Connect(function(classId: string, weaponId: string)
		local_.classId = classId
		local_.weaponId = weaponId
	end)

	Remotes.get("StatusUpdate").OnClientEvent:Connect(function(_stamina, _max, exhausted: boolean, phase: number)
		local_.exhausted = exhausted
		-- The server's phase is the truth. Only correct on a disagreement that
		-- prediction cannot explain: it says we are free and we think we are
		-- mid-swing with no pending confirmation.
		if phase == Enums.CombatPhase.Idle and not local_.awaitingConfirm then
			if local_.phase == Enums.CombatPhase.Windup or local_.phase == Enums.CombatPhase.Release then
				local_.phase = Enums.CombatPhase.Idle
				local_.phaseEnd = math.huge
				local_.predicting = false
			end
		end
	end)

	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)

	RunService.RenderStepped:Connect(step)
end

return InputController
