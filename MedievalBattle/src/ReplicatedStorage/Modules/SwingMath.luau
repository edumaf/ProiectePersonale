--!strict
--[[
	SwingMath

	The geometry of a swing, shared by the server and the client *on purpose*.

	The server traces hits with these functions and every client animates the
	weapon with the same functions, so the blade you see is the blade the server
	tested. If you change an arc here, the visual and the hitbox move together -
	there is no second copy to keep in sync.

	Conventions
	  * All poses are relative to the character's HumanoidRootPart CFrame.
	  * The returned weapon CFrame sits at the grip, with LookVector pointing at
	    the tip. Blade points are therefore grip + LookVector * distance.
	  * yaw   (deg) +  = toward the character's left
	    pitch (deg) +  = tip raised
	    roll  (deg)    = blade twist, purely cosmetic
	  * alpha is 0..1 across a single phase.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = require(ReplicatedStorage.Modules.Enums)
local Types = require(ReplicatedStorage.Modules.Types)

type WeaponDef = Types.WeaponDef

local SwingMath = {}

export type Pose = {
	yaw: number,
	pitch: number,
	roll: number,
	push: number, -- studs the grip travels forward from the resting offset
}

type PoseTrack = { from: Pose, to: Pose }

local function pose(yaw: number, pitch: number, roll: number, push: number): Pose
	return { yaw = yaw, pitch = pitch, roll = roll, push = push }
end

--[[
	Start and end poses of each attack's release window.

	Left/Right are wide horizontal arcs that start behind the opposite shoulder,
	which is what makes them readable to the defender (you can see the wind-up
	side before it lands) and what makes turning into a swing - "drag" - work
	naturally: the arc is defined relative to the root, so rotating the root
	mid-swing genuinely moves the blade.
]]
local TRACKS: { [number]: PoseTrack } = {
	[Enums.AttackDirection.Left] = {
		from = pose(-82, 26, -30, 0.1),
		to = pose(78, -16, 34, 0.7),
	},
	[Enums.AttackDirection.Right] = {
		from = pose(82, 26, 30, 0.1),
		to = pose(-78, -16, -34, 0.7),
	},
	[Enums.AttackDirection.Overhead] = {
		from = pose(-6, 78, 0, 0.0),
		to = pose(4, -40, 0, 0.9),
	},
	[Enums.AttackDirection.Stab] = {
		-- A thrust barely rotates; the reach comes from `push`.
		from = pose(14, 8, 0, -0.4),
		to = pose(-2, -2, 0, 2.1),
	},
}

-- Where the weapon rests when you are doing nothing, and where it sits when the
-- guard is up (blade across the body, which is also roughly the block cone).
local IDLE_POSE = pose(-16, 58, 12, 0)
local BLOCK_POSE = pose(38, 12, 74, 0.5)
-- Bow held up and across, roughly along the aim line.
local DRAW_POSE = pose(-4, 2, 88, 0.9)

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function lerpPose(a: Pose, b: Pose, t: number): Pose
	return pose(lerp(a.yaw, b.yaw, t), lerp(a.pitch, b.pitch, t), lerp(a.roll, b.roll, t), lerp(a.push, b.push, t))
end

function SwingMath.getTrack(direction: number): PoseTrack
	return TRACKS[direction] or TRACKS[Enums.AttackDirection.Right]
end

function SwingMath.getIdlePose(): Pose
	return IDLE_POSE
end

function SwingMath.getBlockPose(): Pose
	return BLOCK_POSE
end

--[[
	Builds the world CFrame of the weapon for an arbitrary pose.
	`rootCF` is the character's HumanoidRootPart CFrame this instant - passing
	the *live* CFrame each tick is what makes swing-dragging work.
]]
function SwingMath.poseToCFrame(rootCF: CFrame, weapon: WeaponDef, p: Pose): CFrame
	local grip = weapon.GripOffset - Vector3.new(0, 0, p.push)
	return rootCF
		* CFrame.new(grip)
		* CFrame.Angles(0, math.rad(p.yaw), 0)
		* CFrame.Angles(math.rad(p.pitch), 0, 0)
		* CFrame.Angles(0, 0, math.rad(p.roll))
end

--[[
	Weapon CFrame at `alpha` (0..1) through the release window of `direction`.
	This is the function the hit tracer walks.
]]
function SwingMath.getSwingCFrame(rootCF: CFrame, weapon: WeaponDef, direction: number, alpha: number): CFrame
	local track = SwingMath.getTrack(direction)
	local clamped = math.clamp(alpha, 0, 1)
	-- Ease-out: the blade is fastest at the start of the release and decelerates,
	-- which both looks right and concentrates the trace samples where the hit
	-- normally happens.
	local eased = 1 - (1 - clamped) * (1 - clamped)
	return SwingMath.poseToCFrame(rootCF, weapon, lerpPose(track.from, track.to, eased))
end

--[[
	Windup: the weapon travels from rest to the start of the arc, so a defender
	can read which side the swing is coming from.
]]
function SwingMath.getWindupCFrame(rootCF: CFrame, weapon: WeaponDef, direction: number, alpha: number): CFrame
	local track = SwingMath.getTrack(direction)
	local clamped = math.clamp(alpha, 0, 1)
	local eased = clamped * clamped * (3 - 2 * clamped) -- smoothstep
	return SwingMath.poseToCFrame(rootCF, weapon, lerpPose(IDLE_POSE, track.from, eased))
end

function SwingMath.getRecoveryCFrame(rootCF: CFrame, weapon: WeaponDef, direction: number, alpha: number): CFrame
	local track = SwingMath.getTrack(direction)
	local clamped = math.clamp(alpha, 0, 1)
	return SwingMath.poseToCFrame(rootCF, weapon, lerpPose(track.to, IDLE_POSE, clamped))
end

function SwingMath.getIdleCFrame(rootCF: CFrame, weapon: WeaponDef): CFrame
	return SwingMath.poseToCFrame(rootCF, weapon, IDLE_POSE)
end

function SwingMath.getBlockCFrame(rootCF: CFrame, weapon: WeaponDef): CFrame
	return SwingMath.poseToCFrame(rootCF, weapon, BLOCK_POSE)
end

--[[
	Bow draw: rest -> drawn, over the weapon's DrawTime.
]]
function SwingMath.getDrawCFrame(rootCF: CFrame, weapon: WeaponDef, alpha: number): CFrame
	local clamped = math.clamp(alpha, 0, 1)
	local eased = clamped * clamped * (3 - 2 * clamped)
	return SwingMath.poseToCFrame(rootCF, weapon, lerpPose(IDLE_POSE, DRAW_POSE, eased))
end

--[[
	A point on the blade: 0 = grip, 1 = tip.
]]
function SwingMath.getBladePoint(weaponCF: CFrame, weapon: WeaponDef, fraction: number): Vector3
	return weaponCF.Position + weaponCF.LookVector * (weapon.Range * fraction)
end

--[[
	Furthest the weapon can possibly reach from the character root during an
	attack. Used as a cheap broad-phase radius before any raycasting.
]]
function SwingMath.getMaxReach(weapon: WeaponDef): number
	local maxPush = 0
	for _, track in TRACKS do
		maxPush = math.max(maxPush, track.from.push, track.to.push)
	end
	return weapon.GripOffset.Magnitude + maxPush + weapon.Range
end

return SwingMath
