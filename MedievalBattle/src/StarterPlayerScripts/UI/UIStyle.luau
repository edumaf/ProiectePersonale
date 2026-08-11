--!strict
--[[
	UIStyle

	Shared look-and-feel plus the handful of constructors every HUD panel uses.
	Built in code rather than as committed GuiObjects for the same reason the
	map is: four people cannot merge a .rbxmx, but they can merge this.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = require(ReplicatedStorage.Modules.Enums)
local MapConfig = require(ReplicatedStorage.Modules.MapConfig)

local UIStyle = {}

UIStyle.Colors = {
	Background = Color3.fromRGB(18, 18, 20),
	Panel = Color3.fromRGB(28, 28, 32),
	Border = Color3.fromRGB(58, 56, 52),
	Text = Color3.fromRGB(234, 230, 222),
	TextDim = Color3.fromRGB(160, 156, 148),
	Health = Color3.fromRGB(178, 54, 54),
	HealthLow = Color3.fromRGB(230, 92, 60),
	Stamina = Color3.fromRGB(214, 178, 92),
	StaminaExhausted = Color3.fromRGB(120, 96, 60),
	Accent = Color3.fromRGB(198, 168, 106),
	Good = Color3.fromRGB(120, 190, 110),
	Bad = Color3.fromRGB(214, 88, 88),
}

UIStyle.Font = Enum.Font.Merriweather
UIStyle.FontBold = Enum.Font.MerriweatherBold

function UIStyle.teamColor(teamId: number?): Color3
	if teamId == Enums.TeamId.Attackers or teamId == Enums.TeamId.Defenders then
		return MapConfig.TeamColors[teamId :: number]
	end
	return UIStyle.Colors.TextDim
end

function UIStyle.frame(name: string, parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = UIStyle.Colors.Panel
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

function UIStyle.label(name: string, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = UIStyle.Font
	label.TextColor3 = UIStyle.Colors.Text
	label.TextScaled = false
	label.TextSize = 16
	label.Text = ""
	label.Parent = parent
	return label
end

function UIStyle.stroke(parent: Instance, thickness: number?, color: Color3?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness or 1
	stroke.Color = color or UIStyle.Colors.Border
	stroke.Parent = parent
	return stroke
end

function UIStyle.corner(parent: Instance, radius: number?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 3)
	corner.Parent = parent
	return corner
end

--[[
	A bar with a background, a fill and a slower "chip" layer behind the fill so
	damage reads as a visible chunk instead of an instant jump.
]]
export type Bar = {
	root: Frame,
	fill: Frame,
	chip: Frame,
	label: TextLabel,
}

function UIStyle.bar(name: string, parent: Instance, color: Color3): Bar
	local root = UIStyle.frame(name, parent)
	root.BackgroundColor3 = UIStyle.Colors.Background
	root.BackgroundTransparency = 0.35
	UIStyle.stroke(root, 1)
	UIStyle.corner(root, 2)

	local chip = Instance.new("Frame")
	chip.Name = "Chip"
	chip.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	chip.BackgroundTransparency = 0.6
	chip.BorderSizePixel = 0
	chip.Size = UDim2.fromScale(1, 1)
	chip.Parent = root

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = root

	local label = UIStyle.label("Value", root)
	label.Size = UDim2.fromScale(1, 1)
	label.TextSize = 13
	label.TextColor3 = UIStyle.Colors.Text
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.ZIndex = 3

	return { root = root, fill = fill, chip = chip, label = label }
end

return UIStyle
