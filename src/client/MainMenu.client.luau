--!strict
-- The title screen, how to play, and the shop where Bingo Tickets unlock upgrade cards.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Sfx = require(script.Parent.Sfx)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)

local BACKGROUND_COLOR = Color3.fromRGB(35, 30, 40)
local ROW_COLOR = Color3.fromRGB(55, 48, 62)
local PLAY_COLOR = Color3.fromRGB(90, 200, 110)
local BUTTON_COLOR = Color3.fromRGB(200, 200, 210)
local LOCKED_COLOR = Color3.fromRGB(110, 105, 115)
local TITLE_COLOR = Color3.fromRGB(255, 210, 70)

local HOW_TO_PLAY = table.concat({
	"Get Grandma to bingo, through every room, then beat Mildred by collecting B-I-N-G-O.",
	"Crash too often and she runs out of Patience. Pick an upgrade after each room.",
	"Keyboard: W/S push and pull, A/D steer, Shift sprint, Space brake, R restart.",
	"Gamepad: triggers push and pull, left stick steers, X sprint, A brake, Y restart.",
}, "\n")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local restartRun = remotes:WaitForChild("RestartRun") :: RemoteEvent
local buyUpgrade = remotes:WaitForChild("BuyUpgrade") :: RemoteEvent
local chair = workspace:WaitForChild(player.Name .. "_Chair") :: Model
local chassis = chair:WaitForChild("Chassis") :: Part

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

local function addButton(parent: Instance, text: string, color: Color3, size: UDim2, position: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = color
	button.TextColor3 = Color3.new(0, 0, 0)
	button.Font = Enum.Font.Cartoon
	button.TextScaled = true
	button.Text = text
	button.Parent = parent
	Instance.new("UICorner").Parent = button
	return button
end

local gui = Instance.new("ScreenGui")
gui.Name = "MainMenu"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = BACKGROUND_COLOR
background.BackgroundTransparency = 0.2
background.Parent = gui

-- Title screen
local titlePage = Instance.new("Frame")
titlePage.Size = UDim2.fromScale(1, 1)
titlePage.BackgroundTransparency = 1
titlePage.Parent = background

local title = addLabel(titlePage, "GRANDMA'S WILD DELIVERY", UDim2.fromScale(0.8, 0.16), UDim2.fromScale(0.1, 0.06))
title.TextColor3 = TITLE_COLOR
title.TextStrokeTransparency = 0

local statsLabel = addLabel(titlePage, "", UDim2.fromScale(0.7, 0.06), UDim2.fromScale(0.15, 0.24))
local playButton = addButton(titlePage, "Loading...", PLAY_COLOR, UDim2.fromScale(0.3, 0.12), UDim2.fromScale(0.35, 0.33))
local shopButton = addButton(titlePage, "Shop", BUTTON_COLOR, UDim2.fromScale(0.3, 0.09), UDim2.fromScale(0.35, 0.47))
addLabel(titlePage, HOW_TO_PLAY, UDim2.fromScale(0.8, 0.28), UDim2.fromScale(0.1, 0.6))
local warningLabel = addLabel(titlePage, "Your progress can't be saved right now.", UDim2.fromScale(0.7, 0.05), UDim2.fromScale(0.15, 0.91))
warningLabel.TextColor3 = Color3.fromRGB(255, 130, 110)
warningLabel.Visible = false

-- Shop
local shopPage = Instance.new("Frame")
shopPage.Size = UDim2.fromScale(1, 1)
shopPage.BackgroundTransparency = 1
shopPage.Visible = false
shopPage.Parent = background

local shopTitle = addLabel(shopPage, "", UDim2.fromScale(0.8, 0.1), UDim2.fromScale(0.1, 0.04))
shopTitle.TextColor3 = TITLE_COLOR
local backButton = addButton(shopPage, "Back", BUTTON_COLOR, UDim2.fromScale(0.2, 0.08), UDim2.fromScale(0.4, 0.89))

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.fromScale(0.8, 0.72)
list.Position = UDim2.fromScale(0.1, 0.15)
list.BackgroundTransparency = 1
list.CanvasSize = UDim2.fromScale(0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ScrollBarThickness = 8
list.Parent = shopPage

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

type ShopRow = {
	upgrade: Upgrades.Upgrade,
	cost: number,
	button: TextButton,
}
local rows: { ShopRow } = {}

for _, upgrade in Upgrades do
	local cost = upgrade.cost
	if cost then
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -12, 0, 76)
		row.LayoutOrder = cost
		row.BackgroundColor3 = ROW_COLOR
		row.Parent = list
		Instance.new("UICorner").Parent = row

		local name = addLabel(row, upgrade.name, UDim2.new(0.65, -16, 0, 30), UDim2.fromOffset(12, 6))
		name.TextXAlignment = Enum.TextXAlignment.Left
		local description = addLabel(row, upgrade.description, UDim2.new(0.65, -16, 0, 34), UDim2.fromOffset(12, 38))
		description.TextXAlignment = Enum.TextXAlignment.Left

		local button = addButton(row, "", PLAY_COLOR, UDim2.new(0.3, 0, 0, 56), UDim2.new(0.68, 0, 0, 10))
		button.Activated:Connect(function()
			Sfx.play("Click")
			buyUpgrade:FireServer(upgrade.id)
		end)
		table.insert(rows, { upgrade = upgrade, cost = cost, button = button })
	end
end

local function updateProfile()
	local ready = player:GetAttribute("ProfileReady") == true
	local tickets = (player:GetAttribute("Tickets") :: number?) or 0
	local wins = (player:GetAttribute("Wins") :: number?) or 0
	local bestTime = player:GetAttribute("BestTime") :: number?
	local unlocked = ((player:GetAttribute("Unlocked") :: string?) or ""):split(",")

	playButton.Text = if ready then "Play" else "Loading..."
	playButton.Active = ready
	warningLabel.Visible = player:GetAttribute("SaveWarning") == true
	local best = if bestTime then `   Best time: {math.floor(bestTime)}s` else ""
	statsLabel.Text = `Bingo Tickets: {tickets}   Wins: {wins}{best}`
	shopTitle.Text = `Shop: {tickets} Bingo Tickets`

	for _, row in rows do
		if table.find(unlocked, row.upgrade.id) then
			row.button.Text = "Unlocked"
			row.button.BackgroundColor3 = LOCKED_COLOR
			row.button.Active = false
		else
			row.button.Text = `Buy: {row.cost}`
			row.button.BackgroundColor3 = if tickets >= row.cost then PLAY_COLOR else LOCKED_COLOR
			row.button.Active = tickets >= row.cost
		end
	end
end

local function showPage(shop: boolean)
	shopPage.Visible = shop
	titlePage.Visible = not shop
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = if shop then backButton else playButton
	end
end

local function updateVisibility()
	local inMenu = chassis:GetAttribute("RunState") == "Menu"
	gui.Enabled = inMenu
	if inMenu then
		showPage(false)
	end
end

playButton.Activated:Connect(function()
	if player:GetAttribute("ProfileReady") == true then
		Sfx.play("Click")
		restartRun:FireServer()
	end
end)
shopButton.Activated:Connect(function()
	Sfx.play("Click")
	showPage(true)
end)
backButton.Activated:Connect(function()
	Sfx.play("Click")
	showPage(false)
end)

for _, attribute in { "ProfileReady", "SaveWarning", "Tickets", "Wins", "BestTime", "Unlocked" } do
	player:GetAttributeChangedSignal(attribute):Connect(updateProfile)
end
chassis:GetAttributeChangedSignal("RunState"):Connect(updateVisibility)
updateProfile()
updateVisibility()

gui.Parent = player:WaitForChild("PlayerGui")
