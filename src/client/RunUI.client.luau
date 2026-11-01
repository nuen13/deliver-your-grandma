--!strict
-- The Patience bar, room progress, and the screen shown when a run ends.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local GrandmaReactions = require(script.Parent.GrandmaReactions)
local Sfx = require(script.Parent.Sfx)

local FULL_COLOR = Color3.fromRGB(90, 200, 110)
local LOW_COLOR = Color3.fromRGB(225, 60, 50)
local PANEL_COLOR = Color3.fromRGB(35, 30, 40)
local BANNER_DURATION = 2.5

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local restartRun = remotes:WaitForChild("RestartRun") :: RemoteEvent
local returnToMenu = remotes:WaitForChild("ReturnToMenu") :: RemoteEvent
local grandmaSay = remotes:WaitForChild("GrandmaSay") :: RemoteEvent
local chair = workspace:WaitForChild(player.Name .. "_Chair") :: Model
local chassis = chair:WaitForChild("Chassis") :: Part
local grandma = chair:WaitForChild("Grandma") :: Model
local head = grandma:WaitForChild("Head") :: Part

local function addLabel(parent: Instance, text: string, size: UDim2, position: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.Cartoon
	label.TextScaled = true
	label.Text = text
	label.Parent = parent
	return label
end

local gui = Instance.new("ScreenGui")
gui.Name = "RunUI"
gui.ResetOnSpawn = false

-- Patience bar
local barBack = Instance.new("Frame")
barBack.AnchorPoint = Vector2.new(1, 0)
barBack.Position = UDim2.new(1, -16, 0, 16)
barBack.Size = UDim2.new(0.3, 0, 0, 28)
barBack.BackgroundColor3 = PANEL_COLOR
barBack.Parent = gui
Instance.new("UICorner").Parent = barBack

local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(1, 1)
barFill.BackgroundColor3 = FULL_COLOR
barFill.Parent = barBack
Instance.new("UICorner").Parent = barFill

local barLabel = addLabel(barBack, "Grandma's Patience", UDim2.fromScale(1, 0.8), UDim2.fromScale(0, 0.1))
barLabel.ZIndex = 2

-- Room progress and seed, under the bar
local roomLabel = addLabel(gui, "", UDim2.new(0.3, 0, 0, 26), UDim2.new(0.7, -16, 0, 50))
roomLabel.TextXAlignment = Enum.TextXAlignment.Right
local seedLabel = addLabel(gui, "", UDim2.new(0.3, 0, 0, 16), UDim2.new(0.7, -16, 0, 78))
seedLabel.TextXAlignment = Enum.TextXAlignment.Right
seedLabel.TextTransparency = 0.4

local bannerLabel = addLabel(gui, "", UDim2.new(0.7, 0, 0, 70), UDim2.fromScale(0.15, 0.2))
bannerLabel.TextStrokeTransparency = 0
bannerLabel.Visible = false
local shownRoom = 0
local bannerToken = 0

-- The boss room's letters, at the top of the screen
local lettersLabel = addLabel(gui, "", UDim2.new(0.5, 0, 0, 56), UDim2.new(0.25, 0, 0, 12))
lettersLabel.TextStrokeTransparency = 0
lettersLabel.TextColor3 = Color3.fromRGB(255, 120, 200)
lettersLabel.Visible = false

-- Run over screen
local failPanel = Instance.new("Frame")
failPanel.AnchorPoint = Vector2.new(0.5, 0.5)
failPanel.Position = UDim2.fromScale(0.5, 0.5)
failPanel.Size = UDim2.fromOffset(420, 340)
failPanel.BackgroundColor3 = PANEL_COLOR
failPanel.Visible = false
failPanel.Parent = gui
Instance.new("UICorner").Parent = failPanel

local titleLabel = addLabel(failPanel, "", UDim2.new(1, -32, 0, 70), UDim2.fromOffset(16, 16))
local fallsLabel = addLabel(failPanel, "", UDim2.new(1, -32, 0, 36), UDim2.fromOffset(16, 96))
local ticketsLabel = addLabel(failPanel, "", UDim2.new(1, -32, 0, 36), UDim2.fromOffset(16, 138))

local function addButton(text: string, color: Color3, position: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = position
	button.Size = UDim2.fromOffset(240, 60)
	button.BackgroundColor3 = color
	button.TextColor3 = Color3.new(0, 0, 0)
	button.Font = Enum.Font.Cartoon
	button.TextScaled = true
	button.Text = text
	button.Parent = failPanel
	Instance.new("UICorner").Parent = button
	return button
end

local restartButton = addButton("Try again (R)", FULL_COLOR, UDim2.new(0.5, 0, 1, -88))
local menuButton = addButton("Menu and shop", Color3.fromRGB(200, 200, 210), UDim2.new(0.5, 0, 1, -16))

restartButton.Activated:Connect(function()
	Sfx.play("Click")
	restartRun:FireServer()
end)
menuButton.Activated:Connect(function()
	Sfx.play("Click")
	returnToMenu:FireServer()
end)

local function updatePatience()
	local patience = (chassis:GetAttribute("Patience") :: number?) or Config.MaxPatience
	local share = math.clamp(patience / Config.MaxPatience, 0, 1)
	barFill.Size = UDim2.fromScale(share, 1)
	barFill.Visible = share > 0
	barFill.BackgroundColor3 = LOW_COLOR:Lerp(FULL_COLOR, share)
end

local function updateRunState()
	local state = chassis:GetAttribute("RunState")
	local ended = state == "Failed" or state == "Won"
	local falls = (chassis:GetAttribute("Falls") :: number?) or 0
	if state == "Won" then
		local seconds = (chassis:GetAttribute("FinishTime") :: number?) or 0
		titleLabel.Text = "Grandma made it to bingo!"
		fallsLabel.Text = `Time: {math.floor(seconds)}s   Dropped her: {falls}`
		restartButton.Text = "Go again (R)"
	else
		titleLabel.Text = "Grandma has had enough."
		fallsLabel.Text = `Times you dropped her: {falls}`
		restartButton.Text = "Try again (R)"
	end
	local tickets = (chassis:GetAttribute("RunTickets") :: number?) or 0
	ticketsLabel.Text = `Bingo Tickets earned: {tickets}`
	if ended and not failPanel.Visible then
		GrandmaReactions.say(head, if state == "Won" then "Arrived" else "GaveUp", true)
		Sfx.play(if state == "Won" then "Win" else "Lose")
		if UserInputService.GamepadEnabled then
			GuiService.SelectedObject = restartButton
		end
	end
	failPanel.Visible = ended
	gui.Enabled = state ~= "Menu"
	if ended or state == "Menu" then
		shownRoom = 0 -- so the next run announces room 1
	end
end

local function updateLetters()
	local letters = chassis:GetAttribute("BossLetters") :: string?
	if letters and lettersLabel.Visible and lettersLabel.Text ~= letters then
		Sfx.play("Letter")
	end
	lettersLabel.Text = letters or ""
	lettersLabel.Visible = letters ~= nil
end

local function updateProgress()
	local room = (chassis:GetAttribute("Room") :: number?) or 1
	local roomCount = (chassis:GetAttribute("RoomCount") :: number?) or 1
	local seed = chassis:GetAttribute("Seed")
	local roomName = (chassis:GetAttribute("RoomName") :: string?) or ""
	roomLabel.Text = `Room {room} of {roomCount}`
	seedLabel.Text = `Seed {seed or "-"}`

	-- A big announcement whenever the room changes.
	if room ~= shownRoom then
		shownRoom = room
		bannerToken += 1
		local token = bannerToken
		bannerLabel.Text = `ROOM {room}: {roomName}`
		bannerLabel.Visible = true
		task.delay(BANNER_DURATION, function()
			if bannerToken == token then
				bannerLabel.Visible = false
			end
		end)
	end
end

chassis:GetAttributeChangedSignal("Patience"):Connect(updatePatience)
chassis:GetAttributeChangedSignal("RunState"):Connect(updateRunState)
chassis:GetAttributeChangedSignal("Falls"):Connect(updateRunState)
chassis:GetAttributeChangedSignal("Room"):Connect(updateProgress)
chassis:GetAttributeChangedSignal("RoomCount"):Connect(updateProgress)
chassis:GetAttributeChangedSignal("Seed"):Connect(updateProgress)
chassis:GetAttributeChangedSignal("RoomName"):Connect(updateProgress)
chassis:GetAttributeChangedSignal("RunTickets"):Connect(updateRunState)
chassis:GetAttributeChangedSignal("BossLetters"):Connect(updateLetters)
chassis:GetAttributeChangedSignal("GrandmaSeated"):Connect(function()
	if chassis:GetAttribute("GrandmaSeated") == false then
		Sfx.play("Crash")
	end
end)
local lastBoostCount = 0
chassis:GetAttributeChangedSignal("BoostCount"):Connect(function()
	local count = (chassis:GetAttribute("BoostCount") :: number?) or 0
	if count > lastBoostCount then
		Sfx.play("Boost")
	end
	lastBoostCount = count
end)
grandmaSay.OnClientEvent:Connect(function(category: string)
	GrandmaReactions.say(head, category, true)
end)
updatePatience()
updateRunState()
updateProgress()
updateLetters()

gui.Parent = player:WaitForChild("PlayerGui")
