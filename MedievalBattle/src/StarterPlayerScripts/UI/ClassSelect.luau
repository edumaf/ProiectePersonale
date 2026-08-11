--!strict
--[[
	ClassSelect

	The class picker. Opens automatically on death and on the first spawn, and
	on demand with B.

	The card list is generated from ClassConfig.Order - adding a fifth class to
	the config puts it on this screen with no UI work at all.

	While it is open, combat input is disabled and the cursor is unlocked. Both
	have to be undone on close, or the player ends up unable to swing or unable
	to look around; every early exit path in here goes through `close`.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ClassConfig = require(ReplicatedStorage.Modules.ClassConfig)
local Remotes = require(ReplicatedStorage.RemoteEvents.Remotes)
local WeaponConfig = require(ReplicatedStorage.Modules.WeaponConfig)

local CameraController = require(script.Parent.Parent.Combat.CameraController)
local InputController = require(script.Parent.Parent.Combat.InputController)
local UIStyle = require(script.Parent.UIStyle)

local ClassSelect = {}

local player = Players.LocalPlayer

local gui: ScreenGui? = nil
local isOpen = false
local selectedId = ClassConfig.Default

local cards: { [string]: Frame } = {}

local function refreshHighlight()
	for id, card in cards do
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if id == selectedId then UIStyle.Colors.Accent else UIStyle.Colors.Border
			stroke.Thickness = if id == selectedId then 2 else 1
		end
		card.BackgroundTransparency = if id == selectedId then 0.05 else 0.25
	end
end

local function buildCard(parent: Instance, classId: string, index: number, total: number)
	local def = ClassConfig.get(classId)

	local card = UIStyle.frame(classId, parent)
	card.Size = UDim2.new(1 / total, -12, 1, 0)
	card.Position = UDim2.new((index - 1) / total, 6, 0, 0)
	UIStyle.stroke(card, 1)
	UIStyle.corner(card, 4)

	local name = UIStyle.label("Name", card)
	name.Font = UIStyle.FontBold
	name.TextSize = 22
	name.TextColor3 = UIStyle.Colors.Accent
	name.Position = UDim2.fromOffset(0, 14)
	name.Size = UDim2.new(1, 0, 0, 26)
	name.Text = def.Name

	local description = UIStyle.label("Description", card)
	description.TextSize = 14
	description.TextColor3 = UIStyle.Colors.TextDim
	description.TextWrapped = true
	description.Position = UDim2.new(0, 12, 0, 46)
	description.Size = UDim2.new(1, -24, 0, 60)
	description.Text = def.Description

	-- Stats, read straight from the configs so they can never drift from the
	-- numbers combat actually uses.
	local weaponNames = {}
	for _, weaponId in def.Weapons do
		local weapon = WeaponConfig.find(weaponId)
		table.insert(weaponNames, if weapon then weapon.Name else weaponId)
	end

	local blockQuality = math.floor((1 - def.BlockDamageMultiplier) * 100 + 0.5)
	local stats = UIStyle.label("Stats", card)
	stats.TextSize = 13
	stats.TextXAlignment = Enum.TextXAlignment.Left
	stats.TextYAlignment = Enum.TextYAlignment.Top
	stats.Position = UDim2.new(0, 14, 0, 112)
	stats.Size = UDim2.new(1, -28, 1, -160)
	stats.Text = `Health   {def.MaxHealth}\nSpeed    {def.WalkSpeed}\nStamina  {def.StaminaMax}\n`
		.. `Block    {blockQuality}%\nArmour   {math.floor(def.DamageReduction * 100 + 0.5)}%\n`
		.. `\n{table.concat(weaponNames, " + ")}`

	local button = Instance.new("TextButton")
	button.Name = "Select"
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -14)
	button.Size = UDim2.new(1, -28, 0, 32)
	button.BackgroundColor3 = UIStyle.Colors.Background
	button.BorderSizePixel = 0
	button.Font = UIStyle.FontBold
	button.TextSize = 15
	button.TextColor3 = UIStyle.Colors.Text
	button.Text = "Select"
	button.Parent = card
	UIStyle.corner(button, 3)
	UIStyle.stroke(button, 1)

	button.Activated:Connect(function()
		ClassSelect.choose(classId)
	end)

	cards[classId] = card
end

local function build()
	local playerGui = player:WaitForChild("PlayerGui")

	local screen = Instance.new("ScreenGui")
	screen.Name = "ClassSelect"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 10
	screen.Enabled = false
	screen.Parent = playerGui
	gui = screen

	local backdrop = UIStyle.frame("Backdrop", screen)
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = UIStyle.Colors.Background
	backdrop.BackgroundTransparency = 0.35

	local title = UIStyle.label("Title", backdrop)
	title.Font = UIStyle.FontBold
	title.TextSize = 28
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0.12, 0)
	title.Size = UDim2.fromOffset(600, 34)
	title.Text = "Choose your class"

	local hint = UIStyle.label("Hint", backdrop)
	hint.TextSize = 14
	hint.TextColor3 = UIStyle.Colors.TextDim
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.new(0.5, 0, 0.12, 34)
	hint.Size = UDim2.fromOffset(760, 20)
	hint.Text = "Picking while alive takes effect on your next respawn.  ·  B or Esc to close"

	local row = UIStyle.frame("Cards", backdrop)
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.fromScale(0.5, 0.55)
	row.Size = UDim2.new(0.86, 0, 0, 340)

	local order = ClassConfig.Order
	for index, classId in order do
		buildCard(row, classId, index, #order)
	end

	refreshHighlight()
end

function ClassSelect.open()
	if isOpen then
		return
	end
	local screen = gui
	if not screen then
		return
	end

	isOpen = true
	screen.Enabled = true
	InputController.setInputEnabled(false)
	CameraController.setMouseLocked(false)
end

function ClassSelect.close()
	if not isOpen then
		return
	end
	local screen = gui
	if screen then
		screen.Enabled = false
	end

	isOpen = false
	InputController.setInputEnabled(true)
	CameraController.setMouseLocked(true)
end

function ClassSelect.toggle()
	if isOpen then
		ClassSelect.close()
	else
		ClassSelect.open()
	end
end

function ClassSelect.choose(classId: string)
	selectedId = classId
	refreshHighlight()
	Remotes.get("SelectClass"):FireServer(classId)
	ClassSelect.close()
end

local function onCharacterAdded(character: Model)
	-- Closing on spawn covers the "picked a class while dead" path: the server
	-- respawns you immediately, and the menu should not be in the way.
	ClassSelect.close()

	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.Died:Connect(function()
		-- Dead players have nothing else to do, and this doubles as the
		-- respawn screen.
		task.wait(0.6)
		if not player.Character or player.Character == character then
			ClassSelect.open()
		end
	end)
end

function ClassSelect.init()
	build()

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.B then
			ClassSelect.toggle()
		elseif input.KeyCode == Enum.KeyCode.Escape and isOpen then
			ClassSelect.close()
		end
	end)

	Remotes.get("ClassMenu").OnClientEvent:Connect(function(open: boolean)
		if open then
			ClassSelect.open()
		else
			ClassSelect.close()
		end
	end)

	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)

	-- First join: let them pick before they walk into a fight.
	task.delay(1.5, function()
		if not isOpen then
			ClassSelect.open()
		end
	end)
end

return ClassSelect
