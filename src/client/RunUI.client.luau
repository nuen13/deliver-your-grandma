--!strict
-- The Patience bar, room progress, and the screen shown when a run ends.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GrandmaReactions = require(script.Parent.GrandmaReactions)

local FULL_COLOR = Color3.fromRGB(90, 200, 110)
local LOW_COLOR = Color3.fromRGB(225, 60, 50)
local PANEL_COLOR = Color3.fromRGB(35, 30, 40)
local BANNER_DURATION = 2.5

local player = Players.LocalPlayer
local restartRun = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RestartRun") :: RemoteEvent
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

-- Run over screen
local failPanel = Instance.new("Frame")
failPanel.AnchorPoint = Vector2.new(0.5, 0.5)
failPanel.Position = UDim2.fromScale(0.5, 0.5)
failPanel.Size = UDim2.fromOffset(420, 240)
failPanel.BackgroundColor3 = PANEL_COLOR
failPanel.Visible = false
failPanel.Parent = gui
Instance.new("UICorner").Parent = failPanel

local titleLabel = addLabel(failPanel, "", UDim2.new(1, -32, 0, 70), UDim2.fromOffset(16, 16))
local fallsLabel = addLabel(failPanel, "", UDim2.new(1, -32, 0, 36), UDim2.fromOffset(16, 96))

local restartButton = Instance.new("TextButton")
restartButton.AnchorPoint = Vector2.new(0.5, 1)
restartButton.Position = UDim2.new(0.5, 0, 1, -20)
restartButton.Size = UDim2.fromOffset(240, 60)
restartButton.BackgroundColor3 = FULL_COLOR
restartButton.TextColor3 = Color3.new(0, 0, 0)
restartButton.Font = Enum.Font.Cartoon
restartButton.TextScaled = true
restartButton.Text = "Try again (R)"
restartButton.Parent = failPanel
Instance.new("UICorner").Parent = restartButton

restartButton.Activated:Connect(function()
	restartRun:FireServer()
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
	if ended and not failPanel.Visible then
		GrandmaReactions.say(head, if state == "Won" then "Arrived" else "GaveUp", true)
	end
	failPanel.Visible = ended
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
updatePatience()
updateRunState()
updateProgress()

gui.Parent = player:WaitForChild("PlayerGui")
