--!strict
--[[
	RoundHUD

	Top of the screen: the round clock, both team scores, the capture point
	track, and the centre banner for announcements.

	The clock is derived locally from a single synchronised timestamp
	(Workspace:GetServerTimeNow) rather than the server pushing a countdown.
	One number sent at each state change replaces one message per second per
	player - at 100 players that difference is the whole point.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Enums = require(ReplicatedStorage.Modules.Enums)
local MapConfig = require(ReplicatedStorage.Modules.MapConfig)
local Remotes = require(ReplicatedStorage.RemoteEvents.Remotes)

local UIStyle = require(script.Parent.UIStyle)

local RoundHUD = {}

local player = Players.LocalPlayer

type PointPayload = {
	index: number,
	id: string,
	name: string,
	state: number,
	progress: number,
	attackers: number,
	defenders: number,
}

local round = {
	state = Enums.RoundState.Waiting,
	endsAt = 0,
	headline = "",
	scores = { [Enums.TeamId.Attackers] = 0, [Enums.TeamId.Defenders] = 0 },
}

local timerLabel: TextLabel? = nil
local headlineLabel: TextLabel? = nil
local scoreLabels: { [number]: TextLabel } = {}
local banner: TextLabel? = nil
local pips: { [number]: { root: Frame, fill: Frame, label: TextLabel } } = {}

local function formatClock(seconds: number): string
	local clamped = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", clamped // 60, clamped % 60)
end

local function buildPips(parent: Instance)
	local total = #MapConfig.CapturePoints
	for index, def in MapConfig.CapturePoints do
		local root = UIStyle.frame(`Pip_{def.Id}`, parent)
		root.Size = UDim2.new(1 / total, -8, 1, 0)
		root.Position = UDim2.new((index - 1) / total, 4, 0, 0)
		root.BackgroundColor3 = UIStyle.Colors.Background
		root.BackgroundTransparency = 0.3
		UIStyle.corner(root, 3)
		UIStyle.stroke(root, 1)

		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.BackgroundColor3 = MapConfig.TeamColors[Enums.TeamId.Attackers]
		fill.BackgroundTransparency = 0.35
		fill.BorderSizePixel = 0
		fill.Size = UDim2.fromScale(0, 1)
		fill.Parent = root

		local label = UIStyle.label("Id", root)
		label.Size = UDim2.fromScale(1, 1)
		label.Font = UIStyle.FontBold
		label.TextSize = 16
		label.ZIndex = 3
		label.Text = def.Id

		pips[index] = { root = root, fill = fill, label = label }
	end
end

local function build()
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "RoundHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local top = UIStyle.frame("Top", gui)
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, 40)
	top.Size = UDim2.fromOffset(520, 74)
	top.BackgroundTransparency = 1

	local clock = UIStyle.label("Clock", top)
	clock.Font = UIStyle.FontBold
	clock.TextSize = 26
	clock.AnchorPoint = Vector2.new(0.5, 0)
	clock.Position = UDim2.new(0.5, 0, 0, 0)
	clock.Size = UDim2.fromOffset(140, 28)
	clock.Text = "--:--"
	timerLabel = clock

	for offset, teamId in { Enums.TeamId.Attackers, Enums.TeamId.Defenders } do
		local label = UIStyle.label(`Score_{teamId}`, top)
		label.Font = UIStyle.FontBold
		label.TextSize = 18
		label.TextColor3 = MapConfig.TeamColors[teamId]
		label.Size = UDim2.fromOffset(180, 26)
		label.Position = if offset == 1 then UDim2.fromOffset(0, 1) else UDim2.new(1, -180, 0, 1)
		label.TextXAlignment = if offset == 1 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
		label.Text = `{MapConfig.TeamNames[teamId]}  0`
		scoreLabels[teamId] = label
	end

	local track = UIStyle.frame("Points", top)
	track.BackgroundTransparency = 1
	track.Position = UDim2.fromOffset(0, 34)
	track.Size = UDim2.new(1, 0, 0, 22)
	buildPips(track)

	local head = UIStyle.label("Headline", top)
	head.TextSize = 14
	head.TextColor3 = UIStyle.Colors.TextDim
	head.Position = UDim2.fromOffset(0, 58)
	head.Size = UDim2.new(1, 0, 0, 18)
	headlineLabel = head

	local announce = UIStyle.label("Banner", gui)
	announce.Font = UIStyle.FontBold
	announce.TextSize = 34
	announce.TextColor3 = UIStyle.Colors.Accent
	announce.TextStrokeTransparency = 0.55
	announce.AnchorPoint = Vector2.new(0.5, 0.5)
	announce.Position = UDim2.fromScale(0.5, 0.26)
	announce.Size = UDim2.fromOffset(900, 46)
	announce.TextTransparency = 1
	banner = announce
end

--[[
	Announcements fade in, hold, and fade out. Each new message restarts the
	sequence, so a burst of captures does not queue up a backlog of banners.
]]
local bannerToken = 0
local function showBanner(text: string, seconds: number?)
	local label = banner
	if not label then
		return
	end

	bannerToken += 1
	local token = bannerToken

	label.Text = text
	TweenService:Create(label, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()

	task.delay(seconds or 3.5, function()
		if token == bannerToken and label.Parent then
			TweenService:Create(label, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		end
	end)
end

local function applyRound()
	if headlineLabel then
		headlineLabel.Text = round.headline
	end
	for teamId, label in scoreLabels do
		label.Text = `{MapConfig.TeamNames[teamId]}  {math.floor(round.scores[teamId] or 0)}`
	end
end

local function applyObjectives(payload: { PointPayload })
	for _, entry in payload do
		local pip = pips[entry.index]
		if not pip then
			continue
		end

		pip.fill.Size = UDim2.fromScale(math.clamp(entry.progress, 0, 1), 1)

		if entry.state == Enums.PointState.Captured then
			pip.fill.BackgroundColor3 = MapConfig.TeamColors[Enums.TeamId.Attackers]
			pip.label.TextColor3 = UIStyle.Colors.Text
		elseif entry.state == Enums.PointState.Contested then
			pip.fill.BackgroundColor3 = Color3.fromRGB(226, 196, 92)
			pip.label.TextColor3 = UIStyle.Colors.Text
		elseif entry.state == Enums.PointState.Locked then
			pip.label.TextColor3 = UIStyle.Colors.TextDim
		else
			pip.label.TextColor3 = UIStyle.Colors.Text
		end
	end
end

local function step()
	local label = timerLabel
	if not label then
		return
	end

	if round.endsAt <= 0 then
		label.Text = "--:--"
		return
	end

	local remaining = round.endsAt - Workspace:GetServerTimeNow()
	label.Text = formatClock(remaining)
	label.TextColor3 = if remaining <= 30 then UIStyle.Colors.Bad else UIStyle.Colors.Text
end

function RoundHUD.init()
	build()

	Remotes.get("RoundUpdate").OnClientEvent:Connect(
		function(state: number, endsAt: number, scores: { [number]: number }, headline: string)
			local changed = state ~= round.state
			round.state = state
			round.endsAt = endsAt
			round.scores = scores
			round.headline = headline
			applyRound()

			if changed then
				showBanner(headline, 4)
			end
		end
	)

	Remotes.get("ObjectiveUpdate").OnClientEvent:Connect(applyObjectives)

	Remotes.get("Notify").OnClientEvent:Connect(function(text: string, seconds: number?)
		showBanner(text, seconds)
	end)

	RunService.RenderStepped:Connect(step)
end

return RoundHUD
