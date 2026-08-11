--!strict
--[[
	CameraController

	Locks the mouse to the centre of the screen and makes the character face
	wherever the camera is looking.

	This is not a cosmetic choice - two systems depend on it:

	  * Directional attacks read the mouse *delta*, and Roblox only reports a
	    meaningful InputObject.Delta while MouseBehavior is LockCenter. With a
	    free cursor there is no swing direction to read.

	  * The server resolves swing arcs and block cones from
	    HumanoidRootPart.CFrame. If the body did not follow the camera, you
	    would block in a direction you are not looking at.

	The client owns its character's physics, so rotating the root here
	replicates to the server for free - the same mechanism Roblox's own shift
	lock uses.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local CameraController = {}

local player = Players.LocalPlayer

local SHOULDER_OFFSET = Vector3.new(1.7, 0.5, 0)
local SHAKE_DECAY = 9

local mouseLocked = true
local shake = Vector3.zero

--[[
	Menus need a cursor. Anything that opens one must call this, and must call
	it again when it closes - the class select screen is the only caller today.
]]
function CameraController.setMouseLocked(locked: boolean)
	mouseLocked = locked
end

function CameraController.isMouseLocked(): boolean
	return mouseLocked
end

--[[
	A short positional kick, used for taking a hit or being staggered. Applied
	through Humanoid.CameraOffset, which is client-local and costs nothing.
]]
function CameraController.addShake(intensity: number)
	shake += Vector3.new((math.random() - 0.5) * intensity, (math.random() - 0.5) * intensity, 0)
end

local function step(dt: number)
	local character = player.Character
	local camera = Workspace.CurrentCamera
	if not character or not camera then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.Health <= 0 then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		return
	end

	UserInputService.MouseBehavior = if mouseLocked
		then Enum.MouseBehavior.LockCenter
		else Enum.MouseBehavior.Default

	-- Decay the shake first so a single hit is a kick, not a wobble.
	shake = shake:Lerp(Vector3.zero, math.clamp(dt * SHAKE_DECAY, 0, 1))
	humanoid.CameraOffset = SHOULDER_OFFSET + shake

	if not mouseLocked then
		humanoid.AutoRotate = true
		return
	end

	-- Body follows the camera's horizontal facing.
	humanoid.AutoRotate = false
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		return
	end

	local position = root.Position
	root.CFrame = CFrame.lookAt(position, position + flat.Unit)
end

function CameraController.init()
	player.CameraMaxZoomDistance = 20
	player.CameraMinZoomDistance = 7

	RunService.RenderStepped:Connect(step)
end

return CameraController
