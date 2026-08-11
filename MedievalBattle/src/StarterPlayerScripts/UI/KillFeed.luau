--!strict
--[[
	KillFeed

	Top-right rolling list of recent kills, coloured by team so you can read the
	state of a fight at a glance without counting bodies.

	Entries are recycled rather than created and destroyed: in a 50v50 fight the
	feed can turn over several times a second, and churning Instances is the
	kind of thing that shows up as frame stutter on weaker clients.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.RemoteEvents.Remotes)
local WeaponConfig = require(ReplicatedStorage.Modules.WeaponConfig)

local UIStyle = require(script.Parent.UIStyle)

local KillFeed = {}

local player = Players.LocalPlayer

local MAX_ENTRIES = 6
local ENTRY_LIFETIME = 7
local ENTRY_HEIGHT = 22

type Entry = {
	frame: Frame,
	killer: TextLabel,
	detail: TextLabel,
	victim: TextLabel,
	expiresAt: number,
}

local container: Frame? = nil
local entries: { Entry } = {}

local function buildEntry(parent: Instance): Entry
	local frame = UIStyle.frame("Entry", parent)
	frame.Size = UDim2.new(1, 0, 0, ENTRY_HEIGHT - 3)
	frame.BackgroundTransparency = 0.4
	frame.Visible = false
	UIStyle.corner(frame, 2)

	local killer = UIStyle.label("Killer", frame)
	killer.TextSize = 14
	killer.TextXAlignment = Enum.TextXAlignment.Right
	killer.Position = UDim2.new(0, 0, 0, 0)
	killer.Size = UDim2.new(0.42, -4, 1, 0)

	local detail = UIStyle.label("Detail", frame)
	detail.TextSize = 13
	detail.TextColor3 = UIStyle.Colors.TextDim
	detail.Position = UDim2.new(0.42, 0, 0, 0)
	detail.Size = UDim2.new(0.16, 0, 1, 0)

	local victim = UIStyle.label("Victim", frame)
	victim.TextSize = 14
	victim.TextXAlignment = Enum.TextXAlignment.Left
	victim.Position = UDim2.new(0.58, 4, 0, 0)
	victim.Size = UDim2.new(0.42, -4, 1, 0)

	return { frame = frame, killer = killer, detail = detail, victim = victim, expiresAt = 0 }
end

local function layout()
	for index, entry in entries do
		entry.frame.Position = UDim2.fromOffset(0, (index - 1) * ENTRY_HEIGHT)
	end
end

local function push(killerName: string, victimName: string, weaponId: string, killerTeam: number?, victimTeam: number?)
	local parent = container
	if not parent then
		return
	end

	local entry: Entry
	if #entries >= MAX_ENTRIES then
		-- Recycle the oldest instead of allocating a new frame.
		entry = table.remove(entries, 1) :: Entry
	else
		entry = buildEntry(parent)
	end

	local weapon = WeaponConfig.find(weaponId)
	local isLocal = killerName == player.DisplayName or victimName == player.DisplayName

	entry.killer.Text = if killerName ~= "" then killerName else "—"
	entry.killer.TextColor3 = UIStyle.teamColor(killerTeam)
	entry.victim.Text = victimName
	entry.victim.TextColor3 = UIStyle.teamColor(victimTeam)
	entry.detail.Text = if weapon then weapon.Name else weaponId
	entry.frame.BackgroundTransparency = if isLocal then 0.15 else 0.45
	entry.frame.Visible = true
	entry.frame.BackgroundColor3 = if isLocal then UIStyle.Colors.Panel else UIStyle.Colors.Background
	entry.expiresAt = os.clock() + ENTRY_LIFETIME

	table.insert(entries, entry)
	layout()

	task.delay(ENTRY_LIFETIME, function()
		if os.clock() < entry.expiresAt - 0.05 then
			return -- it was recycled for a newer kill
		end
		if not entry.frame.Parent then
			return
		end
		TweenService:Create(entry.frame, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		task.wait(0.4)
		entry.frame.Visible = false
		local index = table.find(entries, entry)
		if index then
			table.remove(entries, index)
			layout()
		end
	end)
end

function KillFeed.init()
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "KillFeed"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local frame = UIStyle.frame("Entries", gui)
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.new(1, -18, 0, 130)
	frame.Size = UDim2.fromOffset(320, MAX_ENTRIES * ENTRY_HEIGHT)
	frame.BackgroundTransparency = 1
	container = frame

	Remotes.get("KillFeed").OnClientEvent:Connect(push)
end

return KillFeed
