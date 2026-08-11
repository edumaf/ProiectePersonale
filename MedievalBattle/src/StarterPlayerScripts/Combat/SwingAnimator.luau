--!strict
--[[
	SwingAnimator

	Drives every visible weapon, including your own.

	Three things worth knowing before editing this:

	1. It animates Motor6D.C0 on the *client*. Property writes on a client never
	   replicate, so a full 100-player battle of swinging weapons costs exactly
	   zero bandwidth. The server only ever sends "X started a left swing, 0.36s
	   windup" - about ten bytes - and every client derives the motion.

	2. The poses come from the shared SwingMath module, the same one the server
	   traces hits with. The blade you see really is the blade that was tested.

	3. Only characters that are *doing something* and are close enough to see
	   are in the working set. At 50v50 most players are idle or far away, and
	   an idle weapon needs no per-frame work at all - its Motor6D already holds
	   the idle pose.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Enums = require(ReplicatedStorage.Modules.Enums)
local SwingMath = require(ReplicatedStorage.Modules.SwingMath)
local Types = require(ReplicatedStorage.Modules.Types)
local WeaponConfig = require(ReplicatedStorage.Modules.WeaponConfig)

type WeaponDef = Types.WeaponDef

local SwingAnimator = {}

-- Beyond this a swing is a few pixels tall; skipping it is free performance.
local ANIMATE_DISTANCE = 220
local ANIMATE_DISTANCE_SQ = ANIMATE_DISTANCE * ANIMATE_DISTANCE

type Track = {
	character: Model,
	phase: number,
	startTime: number,
	duration: number,
	direction: number,
	motor: Motor6D?,
	weapon: WeaponDef?,
	-- Set for locally predicted swings so a late server echo does not restart
	-- the animation we are already playing.
	predicted: boolean,
}

local tracks: { [Model]: Track } = {}

local function findMotor(character: Model): (Motor6D?, WeaponDef?)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil, nil
	end
	local motor = root:FindFirstChild("WeaponMotor") :: Motor6D?
	if not motor or not motor.Part1 then
		return nil, nil
	end

	local weaponModel = motor.Part1.Parent
	local weaponId = if weaponModel then weaponModel:GetAttribute("WeaponId") else nil
	if typeof(weaponId) ~= "string" then
		return motor, nil
	end
	return motor, WeaponConfig.find(weaponId)
end

local function setTrack(character: Model, phase: number, duration: number, direction: number, predicted: boolean)
	local motor, weapon = findMotor(character)
	if not motor or not weapon then
		return
	end

	tracks[character] = {
		character = character,
		phase = phase,
		startTime = os.clock(),
		duration = math.max(duration, 1e-3),
		direction = direction,
		motor = motor,
		weapon = weapon,
		predicted = predicted,
	}
end

--[[
	Started locally the instant the player clicks, before the server has seen
	anything. This is the whole responsiveness story: input feels instant, the
	server still decides what actually happens.
]]
function SwingAnimator.predictSwing(character: Model, direction: number, windup: number)
	setTrack(character, Enums.CombatPhase.Windup, windup, direction, true)
end

function SwingAnimator.isPredicting(character: Model): boolean
	local track = tracks[character]
	return track ~= nil and track.predicted
end

function SwingAnimator.onSwingStart(character: Model, direction: number, windup: number)
	-- Our own swing is already playing from the prediction; re-starting it on
	-- the server echo would visibly stutter at any real ping.
	if SwingAnimator.isPredicting(character) then
		local track = tracks[character]
		if track then
			track.predicted = false -- confirmed by the server
		end
		return
	end
	setTrack(character, Enums.CombatPhase.Windup, windup, direction, false)
end

function SwingAnimator.onSwingRelease(character: Model, direction: number, release: number)
	local track = tracks[character]
	if track and track.predicted then
		track.predicted = false
	end
	setTrack(character, Enums.CombatPhase.Release, release, direction, false)
end

function SwingAnimator.onRecovery(character: Model, direction: number, recovery: number)
	setTrack(character, Enums.CombatPhase.Recovery, recovery, direction, false)
end

function SwingAnimator.onGuard(character: Model, up: boolean)
	if up then
		setTrack(character, Enums.CombatPhase.Blocking, math.huge, Enums.AttackDirection.Right, false)
	else
		local track = tracks[character]
		local direction = if track then track.direction else Enums.AttackDirection.Right
		setTrack(character, Enums.CombatPhase.Recovery, 0.2, direction, false)
	end
end

function SwingAnimator.onDraw(character: Model, drawTime: number)
	setTrack(character, Enums.CombatPhase.Drawing, drawTime, Enums.AttackDirection.Stab, false)
end

function SwingAnimator.onDrawEnd(character: Model)
	setTrack(character, Enums.CombatPhase.Recovery, 0.3, Enums.AttackDirection.Stab, false)
end

function SwingAnimator.onFeint(character: Model)
	local track = tracks[character]
	local direction = if track then track.direction else Enums.AttackDirection.Right
	setTrack(character, Enums.CombatPhase.Recovery, 0.22, direction, false)
end

function SwingAnimator.onStagger(character: Model)
	local track = tracks[character]
	local direction = if track then track.direction else Enums.AttackDirection.Right
	setTrack(character, Enums.CombatPhase.Recovery, 0.6, direction, false)
end

--[[
	Cancels a locally predicted swing the server never confirmed - a rejected
	request (out of stamina, mid-recovery, rate limited) or a dropped packet.
]]
function SwingAnimator.cancelPrediction(character: Model)
	local track = tracks[character]
	if track and track.predicted then
		tracks[character] = nil
		local motor = track.motor
		local weapon = track.weapon
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if motor and weapon and root then
			motor.C0 = root.CFrame:ToObjectSpace(SwingMath.getIdleCFrame(root.CFrame, weapon))
		end
	end
end

function SwingAnimator.clear(character: Model)
	tracks[character] = nil
end

local function poseFor(track: Track, rootCF: CFrame, weapon: WeaponDef, alpha: number): CFrame
	if track.phase == Enums.CombatPhase.Windup then
		return SwingMath.getWindupCFrame(rootCF, weapon, track.direction, alpha)
	elseif track.phase == Enums.CombatPhase.Release then
		return SwingMath.getSwingCFrame(rootCF, weapon, track.direction, alpha)
	elseif track.phase == Enums.CombatPhase.Blocking then
		return SwingMath.getBlockCFrame(rootCF, weapon)
	elseif track.phase == Enums.CombatPhase.Drawing then
		return SwingMath.getDrawCFrame(rootCF, weapon, alpha)
	end
	-- Recovery and everything else: ease back to rest.
	return SwingMath.getRecoveryCFrame(rootCF, weapon, track.direction, alpha)
end

local function step()
	local camera = Workspace.CurrentCamera
	local viewPosition = if camera then camera.CFrame.Position else Vector3.zero
	local now = os.clock()

	for character, track in tracks do
		if not character.Parent then
			tracks[character] = nil
			continue
		end

		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local motor = track.motor
		local weapon = track.weapon
		if not root or not motor or not weapon or not motor.Parent then
			tracks[character] = nil
			continue
		end

		local offset = root.Position - viewPosition
		if offset:Dot(offset) > ANIMATE_DISTANCE_SQ then
			-- Too far to matter. Leave the weapon where it is; when the player
			-- gets closer the next event re-registers a track.
			continue
		end

		local alpha = if track.duration == math.huge then 1 else math.clamp((now - track.startTime) / track.duration, 0, 1)
		local rootCF = root.CFrame
		local target = poseFor(track, rootCF, weapon, alpha)
		motor.C0 = rootCF:ToObjectSpace(target)

		if alpha < 1 or track.phase == Enums.CombatPhase.Blocking then
			continue
		end

		if track.phase == Enums.CombatPhase.Drawing then
			continue -- hold the drawn pose until the shot is loosed
		elseif track.phase == Enums.CombatPhase.Release then
			-- Chain into recovery locally instead of waiting for a "recovery"
			-- packet that is never sent. Without this, a remote player's weapon
			-- would freeze at the end of its arc until their next action.
			track.phase = Enums.CombatPhase.Recovery
			track.startTime = now
			track.duration = weapon.Timings[track.direction].Recovery
		elseif track.phase == Enums.CombatPhase.Recovery then
			-- Back at rest: drop it out of the working set so idle players cost
			-- nothing at all.
			tracks[character] = nil
		end
		-- A finished Windup holds its pose: the release event decides when the
		-- blade actually starts moving.
	end
end

function SwingAnimator.init()
	RunService.RenderStepped:Connect(step)

	Players.PlayerRemoving:Connect(function(player)
		local character = player.Character
		if character then
			tracks[character] = nil
		end
	end)
end

return SwingAnimator
