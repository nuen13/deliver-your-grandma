--!strict
-- Shows the upgrade cards after each room. Click a card or press its number.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local GrandmaReactions = require(script.Parent.GrandmaReactions)
local Sfx = require(script.Parent.Sfx)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)

local CARD_COLOR = Color3.fromRGB(35, 30, 40)
local NUMBER_KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five }

local player = Players.LocalPlayer
local chooseUpgrade = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ChooseUpgrade") :: RemoteEvent
local chair = workspace:WaitForChild(player.Name .. "_Chair") :: Model
local chassis = chair:WaitForChild("Chassis") :: Part
local grandma = chair:WaitForChild("Grandma") :: Model
local head = grandma:WaitForChild("Head") :: Part

local upgradesById: { [string]: Upgrades.Upgrade } = {}
for _, upgrade in Upgrades do
	upgradesById[upgrade.id] = upgrade
end

local function addLabel(parent: Instance, text: string, size: UDim2, position: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.Cartoon
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = text
	label.Parent = parent
	return label
end

local gui = Instance.new("ScreenGui")
gui.Name = "UpgradeCards"
gui.ResetOnSpawn = false
gui.Enabled = false

local title = addLabel(gui, "Grandma demands a present!", UDim2.fromScale(0.7, 0.08), UDim2.fromScale(0.15, 0.3))
title.TextStrokeTransparency = 0

local row = Instance.new("Frame")
row.AnchorPoint = Vector2.new(0.5, 0)
row.Position = UDim2.fromScale(0.5, 0.4)
row.Size = UDim2.fromScale(0.8, 0.4)
row.BackgroundTransparency = 1
row.Parent = gui

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0.02, 0)
layout.Parent = row

local cardCount = 0

local function clearCards()
	for _, child in row:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	cardCount = 0
end

local function pick(index: number)
	gui.Enabled = false -- so a double click can't pick twice
	Sfx.play("Click")
	GrandmaReactions.say(head, "Upgraded", true)
	chooseUpgrade:FireServer(index)
end

local function addCard(index: number, upgrade: Upgrades.Upgrade, total: number)
	local card = Instance.new("TextButton")
	card.Size = UDim2.fromScale(0.96 / total, 1)
	card.LayoutOrder = index
	card.BackgroundColor3 = CARD_COLOR
	card.Text = ""
	card.Parent = row
	Instance.new("UICorner").Parent = card

	addLabel(card, upgrade.name, UDim2.fromScale(0.9, 0.25), UDim2.fromScale(0.05, 0.05))
	addLabel(card, upgrade.description, UDim2.fromScale(0.9, 0.45), UDim2.fromScale(0.05, 0.33))
	local key = addLabel(card, `Press {index}`, UDim2.fromScale(0.9, 0.12), UDim2.fromScale(0.05, 0.84))
	key.TextTransparency = 0.4

	card.Activated:Connect(function()
		pick(index)
	end)
end

local function refresh()
	clearCards()
	local choosing = chassis:GetAttribute("RunState") == "Choosing"
	if choosing then
		local offer = (chassis:GetAttribute("UpgradeOffer") :: string?) or ""
		local ids = offer:split(",")
		for index, id in ids do
			local upgrade = upgradesById[id]
			if upgrade then
				addCard(index, upgrade, #ids)
				cardCount += 1
			end
		end
	end
	gui.Enabled = choosing
	if choosing and UserInputService.GamepadEnabled then
		GuiService.SelectedObject = row:FindFirstChildWhichIsA("TextButton")
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not gui.Enabled then
		return
	end
	local index = table.find(NUMBER_KEYS, input.KeyCode)
	if index and index <= cardCount then
		pick(index)
	end
end)

chassis:GetAttributeChangedSignal("RunState"):Connect(refresh)
chassis:GetAttributeChangedSignal("UpgradeOffer"):Connect(refresh)
refresh()

gui.Parent = player:WaitForChild("PlayerGui")
