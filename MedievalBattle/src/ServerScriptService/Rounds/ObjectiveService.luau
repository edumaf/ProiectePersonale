--!strict
--[[
	ObjectiveService

	Sequential capture points: attackers must take A, then B, then C. Only one
	point is ever live, which is what paces a 100-player fight - the whole
	server converges on one contested area instead of dissolving into a single
	shapeless blob in the middle of the map.

	Capture rate rules (RoundConfig):
	  * Each attacker inside the zone adds a share of the rate, capped at
	    MaxCaptureContributors. Without the cap, 50 attackers take a point
	    instantly and the mode is just "who zerged first".
	  * Each defender inside cancels one attacker. Equal numbers = frozen.
	  * With no attackers present, progress decays back toward zero.

	Only the live point is evaluated, and only four times a second - this runs
	off its own timer rather than Heartbeat because nothing about a capture bar
	needs 60 Hz.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Enums = require(ReplicatedStorage.Modules.Enums)
local MapConfig = require(ReplicatedStorage.Modules.MapConfig)
local Remotes = require(ReplicatedStorage.RemoteEvents.Remotes)
local RoundConfig = require(ReplicatedStorage.Modules.RoundConfig)
local Types = require(ReplicatedStorage.Modules.Types)

type CapturePointDef = Types.CapturePointDef

local ObjectiveService = {}

type PointState = {
	def: CapturePointDef,
	state: number,
	progress: number,
	attackers: number,
	defenders: number,
	marker: BasePart?,
	banner: BasePart?,
}

local points: { PointState } = {}
local activeIndex = 1
local capturedCount = 0
local running = false

local accumulator = 0
local broadcastAccumulator = 0
local dirty = true

type CaptureCallback = (index: number, def: CapturePointDef) -> ()
local captureCallbacks: { CaptureCallback } = {}

function ObjectiveService.onCaptured(callback: CaptureCallback)
	table.insert(captureCallbacks, callback)
end

-- ============================================================== visuals ====

local function buildVisuals(parent: Instance)
	for _, point in points do
		local def = point.def

		local marker = Instance.new("Part")
		marker.Name = `Point_{def.Id}`
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanQuery = false -- must never stop a swing trace
		marker.CanTouch = false
		marker.Shape = Enum.PartType.Cylinder
		marker.Size = Vector3.new(1, def.Radius * 2, def.Radius * 2)
		marker.CFrame = CFrame.new(def.Position + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
		marker.Material = Enum.Material.Neon
		marker.Transparency = 0.82
		marker.Color = MapConfig.TeamColors[Enums.TeamId.Defenders]
		marker.Parent = parent
		point.marker = marker

		local banner = Instance.new("Part")
		banner.Name = `Banner_{def.Id}`
		banner.Anchored = true
		banner.CanCollide = true
		banner.Size = Vector3.new(1.2, def.Height * 0.5, 1.2)
		banner.Position = def.Position + Vector3.new(0, def.Height * 0.25, 0)
		banner.Color = MapConfig.TeamColors[Enums.TeamId.Defenders]
		banner.Material = Enum.Material.WoodPlanks
		banner.Parent = parent
		point.banner = banner

		local label = Instance.new("BillboardGui")
		label.Name = "Label"
		label.Size = UDim2.fromOffset(160, 40)
		label.StudsOffset = Vector3.new(0, def.Height * 0.3, 0)
		label.AlwaysOnTop = true
		label.MaxDistance = 400
		label.Parent = banner

		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.MerriweatherBold
		text.TextSize = 26
		text.TextColor3 = Color3.fromRGB(240, 236, 228)
		text.TextStrokeTransparency = 0.4
		text.Text = def.Id
		text.Parent = label
	end
end

local function refreshVisual(point: PointState)
	local color = if point.state == Enums.PointState.Captured
		then MapConfig.TeamColors[Enums.TeamId.Attackers]
		elseif point.state == Enums.PointState.Contested then Color3.fromRGB(226, 196, 92)
		else MapConfig.TeamColors[Enums.TeamId.Defenders]

	if point.marker then
		point.marker.Color = color
		point.marker.Transparency = if point.state == Enums.PointState.Locked then 0.94 else 0.82
	end
	if point.banner then
		point.banner.Color = color
	end
end

-- ============================================================= counting ====

--[[
	Is this position inside the capture cylinder? Vertical tolerance is
	deliberately generous upward (you can hold a point from the wall above it)
	and tight downward.
]]
local function isInside(position: Vector3, def: CapturePointDef): boolean
	local dx = position.X - def.Position.X
	local dz = position.Z - def.Position.Z
	if dx * dx + dz * dz > def.Radius * def.Radius then
		return false
	end
	local dy = position.Y - def.Position.Y
	return dy > -8 and dy < def.Height
end

local function countOccupants(point: PointState)
	local attackers, defenders = 0, 0

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character.PrimaryPart
		if not root or not character then
			continue
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			continue
		end
		if not isInside(root.Position, point.def) then
			continue
		end

		if character:GetAttribute("TeamId") == Enums.TeamId.Attackers then
			attackers += 1
		else
			defenders += 1
		end
	end

	point.attackers = attackers
	point.defenders = defenders
end

-- =============================================================== update ====

local function capture(index: number, point: PointState)
	point.state = Enums.PointState.Captured
	point.progress = 1
	capturedCount += 1
	activeIndex = index + 1
	refreshVisual(point)

	if points[activeIndex] then
		points[activeIndex].state = Enums.PointState.Defender
		refreshVisual(points[activeIndex])
	end

	dirty = true

	Remotes.get("Notify"):FireAllClients(`{point.def.Name} captured!`, 4)

	for _, callback in captureCallbacks do
		task.spawn(callback, index, point.def)
	end
end

local function tick(dt: number)
	local point = points[activeIndex]
	if not point then
		return
	end

	countOccupants(point)

	local effectiveAttackers = math.min(point.attackers, RoundConfig.MaxCaptureContributors)
	local effectiveDefenders = if RoundConfig.DefenderCancelsAttacker
		then math.min(point.defenders, RoundConfig.MaxCaptureContributors)
		else 0
	local net = effectiveAttackers - effectiveDefenders

	local ratePerSecond = 1 / point.def.CaptureSeconds
	local previousProgress = point.progress
	local previousState = point.state

	if net > 0 then
		point.progress = math.min(1, point.progress + net * ratePerSecond * dt)
		point.state = Enums.PointState.Contested
	elseif point.attackers == 0 then
		point.progress = math.max(0, point.progress - ratePerSecond * RoundConfig.CaptureDecayRate * dt)
		point.state = if point.progress > 0 then Enums.PointState.Contested else Enums.PointState.Defender
	else
		-- Attackers present but held off: the bar simply stops.
		point.state = Enums.PointState.Contested
	end

	if point.state ~= previousState then
		refreshVisual(point)
	end
	if math.abs(point.progress - previousProgress) > 1e-4 or point.state ~= previousState then
		dirty = true
	end

	if point.progress >= 1 then
		capture(activeIndex, point)
	end
end

--[[
	One compact snapshot of every point. Small enough (three entries) that a
	delta encoding would cost more in complexity than it saves in bytes.
]]
local function buildPayload()
	local payload = {}
	for index, point in points do
		table.insert(payload, {
			index = index,
			id = point.def.Id,
			name = point.def.Name,
			state = point.state,
			progress = point.progress,
			attackers = point.attackers,
			defenders = point.defenders,
		})
	end
	return payload
end

local function broadcast()
	Remotes.get("ObjectiveUpdate"):FireAllClients(buildPayload())
end

-- ================================================================ API ======

function ObjectiveService.getCaptureCount(): number
	return capturedCount
end

function ObjectiveService.getActiveIndex(): number
	return activeIndex
end

function ObjectiveService.getPointCount(): number
	return #points
end

function ObjectiveService.allCaptured(): boolean
	return capturedCount >= #points
end

function ObjectiveService.setRunning(value: boolean)
	running = value
end

function ObjectiveService.reset()
	capturedCount = 0
	activeIndex = 1

	for index, point in points do
		point.progress = 0
		point.attackers = 0
		point.defenders = 0
		point.state = if index == 1 then Enums.PointState.Defender else Enums.PointState.Locked
		refreshVisual(point)
	end

	dirty = true
	broadcast()
end

function ObjectiveService.init(parent: Instance)
	for _, def in MapConfig.CapturePoints do
		table.insert(points, {
			def = def,
			state = Enums.PointState.Locked,
			progress = 0,
			attackers = 0,
			defenders = 0,
		})
	end

	buildVisuals(parent)
	ObjectiveService.reset()

	RunService.Heartbeat:Connect(function(dt: number)
		if not running then
			return
		end

		accumulator += dt
		if accumulator >= RoundConfig.ObjectiveTickRate then
			tick(accumulator)
			accumulator = 0
		end

		broadcastAccumulator += dt
		if broadcastAccumulator >= RoundConfig.ObjectiveBroadcastRate then
			broadcastAccumulator = 0
			-- Only send when something actually moved. A stalemate on a point
			-- with nobody in it is silent.
			if dirty then
				dirty = false
				broadcast()
			end
		end
	end)

	-- New arrivals need the current objective state immediately, not on the
	-- next change.
	Players.PlayerAdded:Connect(function(player)
		task.wait(1)
		if player.Parent == Players then
			Remotes.get("ObjectiveUpdate"):FireClient(player, buildPayload())
		end
	end)
end

return ObjectiveService
