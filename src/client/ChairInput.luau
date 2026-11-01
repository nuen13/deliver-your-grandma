--!strict
-- Combines keyboard, gamepad, and on-screen touch controls into one set of driving inputs.
-- Keyboard: W/S push and pull, A/D steer, Shift sprints, Space brakes.
-- Gamepad: right trigger pushes, left trigger pulls, left stick steers, X sprints, A brakes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)

local ChairInput = {}

local TRIGGER_THRESHOLD = 0.2

local touchHeld: { [string]: boolean } = {}
local touchOwners: { [InputObject]: string } = {}
local sprintToggled = false
local touchGui: ScreenGui? = nil

local function anyKeyDown(keys: { Enum.KeyCode }): boolean
	for _, key in keys do
		if UserInputService:IsKeyDown(key) then
			return true
		end
	end
	return false
end

local function gamepadState(): { [Enum.KeyCode]: InputObject }
	local states = {}
	if UserInputService:GetGamepadConnected(Enum.UserInputType.Gamepad1) then
		for _, state in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
			states[state.KeyCode] = state
		end
	end
	return states
end

local function gamepadButtonDown(button: Enum.KeyCode): boolean
	return UserInputService:GetGamepadConnected(Enum.UserInputType.Gamepad1)
		and UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, button)
end

local function typing(): boolean
	return UserInputService:GetFocusedTextBox() ~= nil
end

function ChairInput.getThrottle(): number
	if typing() then
		return 0
	end
	local value = (if anyKeyDown({ Enum.KeyCode.W, Enum.KeyCode.Up }) or touchHeld.Push then 1 else 0)
		- (if anyKeyDown({ Enum.KeyCode.S, Enum.KeyCode.Down }) or touchHeld.Pull then 1 else 0)
	local pad = gamepadState()
	local push = pad[Enum.KeyCode.ButtonR2]
	local pull = pad[Enum.KeyCode.ButtonL2]
	if push and push.Position.Z > TRIGGER_THRESHOLD then
		value += push.Position.Z
	end
	if pull and pull.Position.Z > TRIGGER_THRESHOLD then
		value -= pull.Position.Z
	end
	return math.clamp(value, -1, 1)
end

function ChairInput.getSteer(): number
	if typing() then
		return 0
	end
	local value = (if anyKeyDown({ Enum.KeyCode.D, Enum.KeyCode.Right }) or touchHeld.Right then 1 else 0)
		- (if anyKeyDown({ Enum.KeyCode.A, Enum.KeyCode.Left }) or touchHeld.Left then 1 else 0)
	local stick = gamepadState()[Enum.KeyCode.Thumbstick1]
	if stick and math.abs(stick.Position.X) > Config.GamepadDeadzone then
		value += stick.Position.X
	end
	return math.clamp(value, -1, 1)
end

function ChairInput.isSprinting(): boolean
	if sprintToggled or anyKeyDown({ Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift }) then
		return true
	end
	return gamepadButtonDown(Enum.KeyCode.ButtonX)
end

function ChairInput.isBraking(): boolean
	if typing() then
		return false
	end
	if touchHeld.Brake or UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		return true
	end
	return gamepadButtonDown(Enum.KeyCode.ButtonA)
end

-- The touch buttons only show while driving.
function ChairInput.setTouchVisible(visible: boolean)
	if touchGui then
		touchGui.Enabled = visible
	end
end

local function addTouchButton(gui: ScreenGui, action: string, text: string, position: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = position
	button.Size = UDim2.fromOffset(84, 84)
	button.BackgroundColor3 = Color3.fromRGB(35, 30, 40)
	button.BackgroundTransparency = 0.35
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.Cartoon
	button.TextScaled = true
	button.Text = text
	button.AutoButtonColor = false
	button.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button

	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			touchOwners[input] = action
			touchHeld[action] = true
		end
	end)
	return button
end

if UserInputService.TouchEnabled then
	-- Lifting a finger anywhere releases its button, even if it slid off first.
	UserInputService.TouchEnded:Connect(function(touch)
		local action = touchOwners[touch]
		if action then
			touchOwners[touch] = nil
			touchHeld[action] = nil
		end
	end)

	local gui = Instance.new("ScreenGui")
	gui.Name = "TouchControls"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	addTouchButton(gui, "Left", "<", UDim2.new(0, 70, 1, -80))
	addTouchButton(gui, "Right", ">", UDim2.new(0, 170, 1, -80))
	addTouchButton(gui, "Push", "GO", UDim2.new(1, -70, 1, -130))
	addTouchButton(gui, "Pull", "BACK", UDim2.new(1, -170, 1, -80))
	addTouchButton(gui, "Brake", "STOP", UDim2.new(1, -70, 1, -230))

	local sprint = addTouchButton(gui, "Sprint", "RUN", UDim2.new(1, -170, 1, -180))
	sprint.Activated:Connect(function()
		sprintToggled = not sprintToggled
		sprint.BackgroundTransparency = if sprintToggled then 0 else 0.35
	end)

	touchGui = gui
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
end

return ChairInput
