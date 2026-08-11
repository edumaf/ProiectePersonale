--!strict
--[[
	HUD

	Health, stamina, a crosshair and a controls reminder.

	Health comes straight off the Humanoid (Roblox replicates it for us, so
	there is no reason to send it over a remote). Stamina is the only combat
	number the server has to push, and it only goes to its owner, throttled to
	10 Hz and only when it actually changed - see CombatConfig.StatusSend*.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.RemoteEvents.Remotes)

local UIStyle = require(script.Parent.UIStyle)

local HUD = {}

local player = Players.LocalPlayer

local health = { current = 100, max = 100 }
local stamina = { current = 100, max = 100, exhausted = false }

local healthBar: UIStyle.Bar? = nil
local staminaBar: UIStyle.Bar? = nil
local screenGui: ScreenGui? = nil

local function buildCrosshair(parent: Instance)
	local dot = Instance.new("Frame")
	dot.Name = "Crosshair"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(4, 4)
	dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	dot.BackgroundTransparency = 0.35
	dot.BorderSizePixel = 0
	dot.Parent = parent
	UIStyle.corner(dot, 2)
end

local function buildHint(parent: Instance)
	local hint = UIStyle.label("Hint", parent)
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.new(0.5, 0, 0, 14)
	hint.Size = UDim2.fromOffset(760, 20)
	hint.TextSize = 14
	hint.TextColor3 = UIStyle.Colors.TextDim
	hint.Text = "LMB attack (flick the mouse to aim the swing)  ·  RMB block  ·  Q feint  ·  Shift sprint  ·  F swap weapon  ·  B class"

	task.delay(18, function()
		if hint.Parent then
			TweenService:Create(hint, TweenInfo.new(1.5), { TextTransparency = 1 }):Play()
		end
	end)
end

local function build()
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "MedievalHUD"
	gui.ResetOnSpawn = false -- rebuilding the whole HUD every respawn is waste
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	screenGui = gui

	buildCrosshair(gui)
	buildHint(gui)

	local container = UIStyle.frame("Vitals", gui)
	container.AnchorPoint = Vector2.new(0.5, 1)
	container.Position = UDim2.new(0.5, 0, 1, -18)
	container.Size = UDim2.fromOffset(420, 44)
	container.BackgroundTransparency = 1

	local hp = UIStyle.bar("Health", container, UIStyle.Colors.Health)
	hp.root.Position = UDim2.fromOffset(0, 0)
	hp.root.Size = UDim2.fromOffset(420, 22)
	healthBar = hp

	local sp = UIStyle.bar("Stamina", container, UIStyle.Colors.Stamina)
	sp.root.Position = UDim2.fromOffset(0, 26)
	sp.root.Size = UDim2.fromOffset(420, 12)
	sp.label.TextSize = 11
	staminaBar = sp
end

local function bindCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end

	health.max = humanoid.MaxHealth
	health.current = humanoid.Health

	humanoid.HealthChanged:Connect(function(value)
		health.current = value
		health.max = humanoid.MaxHealth
	end)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		health.max = humanoid.MaxHealth
	end)
end

--[[
	Bars are lerped toward their target every frame rather than set directly:
	the chip layer trails the fill, which is what makes a big hit read as a
	chunk of health disappearing instead of a number quietly changing.
]]
local function step(dt: number)
	local hp = healthBar
	local sp = staminaBar
	if not hp or not sp then
		return
	end

	local healthAlpha = if health.max > 0 then math.clamp(health.current / health.max, 0, 1) else 0
	local staminaAlpha = if stamina.max > 0 then math.clamp(stamina.current / stamina.max, 0, 1) else 0

	hp.fill.Size = UDim2.fromScale(healthAlpha, 1)
	hp.fill.BackgroundColor3 = if healthAlpha < 0.3 then UIStyle.Colors.HealthLow else UIStyle.Colors.Health
	hp.chip.Size = hp.chip.Size:Lerp(UDim2.fromScale(healthAlpha, 1), math.clamp(dt * 4, 0, 1))
	hp.label.Text = `{math.ceil(health.current)} / {math.floor(health.max)}`

	sp.fill.Size = sp.fill.Size:Lerp(UDim2.fromScale(staminaAlpha, 1), math.clamp(dt * 14, 0, 1))
	sp.fill.BackgroundColor3 = if stamina.exhausted
		then UIStyle.Colors.StaminaExhausted
		else UIStyle.Colors.Stamina
	sp.chip.Size = sp.fill.Size
	sp.label.Text = if stamina.exhausted then "EXHAUSTED" else ""
end

function HUD.init()
	build()

	Remotes.get("StatusUpdate").OnClientEvent:Connect(function(value: number, max: number, exhausted: boolean)
		stamina.current = value
		stamina.max = max
		stamina.exhausted = exhausted
	end)

	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end
	player.CharacterAdded:Connect(bindCharacter)

	RunService.RenderStepped:Connect(step)
end

function HUD.getScreenGui(): ScreenGui?
	return screenGui
end

return HUD
