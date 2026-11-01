--!strict
-- Drives the wheelchair and decides when a crash, tilt, or fast turn throws Grandma out.
-- W/S push and pull, A/D steer, Shift speeds up, Space brakes, R restarts the run.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local GrandmaReactions = require(script.Parent.GrandmaReactions)

local TELEPORT_DISTANCE = 20 -- moving this far in one frame means a reset, not a crash
local GROUND_RAY_LENGTH = 1.5

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local grandmaEjected = remotes:WaitForChild("GrandmaEjected") :: RemoteEvent
local grandmaBumped = remotes:WaitForChild("GrandmaBumped") :: RemoteEvent
local restartRun = remotes:WaitForChild("RestartRun") :: RemoteEvent

local chair = workspace:WaitForChild(player.Name .. "_Chair") :: Model
local chassis = chair:WaitForChild("Chassis") :: Part
local grandma = chair:WaitForChild("Grandma") :: Model
local head = grandma:WaitForChild("Head") :: Part

local maxTiltUpY = math.cos(math.rad(Config.MaxTiltDegrees))

local braking = false
local tipMeter = 0
local previousSpeed = 0
local previousPosition = chassis.Position
local wasSeated = true
local ejectPending = false -- sent to the server, but the attribute hasn't changed yet

ContextActionService:BindAction("Brake", function(_, inputState)
	braking = inputState == Enum.UserInputState.Begin
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.Space)
ContextActionService:SetTitle("Brake", "Brake")

ContextActionService:BindAction("RestartRun", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		restartRun:FireServer()
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.R)
ContextActionService:SetTitle("RestartRun", "Restart")

local function keyAxis(positive: { Enum.KeyCode }, negative: { Enum.KeyCode }): number
	local function anyDown(keys: { Enum.KeyCode }): boolean
		for _, key in keys do
			if UserInputService:IsKeyDown(key) then
				return true
			end
		end
		return false
	end
	return (if anyDown(positive) then 1 else 0) - (if anyDown(negative) then 1 else 0)
end

local function moveToward(value: number, target: number, amount: number): number
	if value < target then
		return math.min(value + amount, target)
	end
	return math.max(value - amount, target)
end

local function isGrounded(): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { chair, player.Character :: Instance }
	return workspace:Raycast(chassis.Position, chassis.CFrame.UpVector * -GROUND_RAY_LENGTH, params) ~= nil
end

local function launchGrandma(velocity: Vector3)
	ejectPending = true
	tipMeter = 0
	GrandmaReactions.say(head, "Launched", true)
	local launch = velocity * Config.LaunchSpeedMultiplier + Vector3.yAxis * Config.LaunchUpSpeed
	grandmaEjected:FireServer(launch)
end

RunService.Heartbeat:Connect(function(dt)
	local frame = chassis.CFrame
	local velocity = chassis.AssemblyLinearVelocity
	local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local teleported = (chassis.Position - previousPosition).Magnitude > TELEPORT_DISTANCE
	previousPosition = chassis.Position

	local seated = chassis:GetAttribute("GrandmaSeated") == true
	if ejectPending then
		if not seated then
			ejectPending = false
			wasSeated = false
		end
	elseif seated and not wasSeated then
		wasSeated = true
		previousSpeed = horizontalSpeed
		GrandmaReactions.say(head, "Reseated", true)
	end
	local running = chassis:GetAttribute("RunState") == "Running"
	local canFall = running and seated and wasSeated and not ejectPending

	-- Ignore keys while typing in chat or another text box, and after the run ends.
	local typing = UserInputService:GetFocusedTextBox() ~= nil or not running
	local throttle = if typing then 0 else keyAxis({ Enum.KeyCode.W, Enum.KeyCode.Up }, { Enum.KeyCode.S, Enum.KeyCode.Down })
	local steer = if typing then 0 else keyAxis({ Enum.KeyCode.D, Enum.KeyCode.Right }, { Enum.KeyCode.A, Enum.KeyCode.Left })

	local yawRate = 0
	local forwardSpeed = velocity:Dot(frame.LookVector)

	if isGrounded() then
		local sideSpeed = velocity:Dot(frame.RightVector) * math.exp(-Config.SidewaysGrip * dt)
		local upSpeed = velocity:Dot(frame.UpVector)

		if braking then
			forwardSpeed = moveToward(forwardSpeed, 0, Config.BrakeDeceleration * dt)
		elseif throttle > 0 then
			local sprinting = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
				or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
			local topSpeed = if sprinting then Config.SprintTopSpeed else Config.TopSpeed
			local acceleration = if sprinting then Config.SprintAcceleration else Config.Acceleration
			if forwardSpeed < topSpeed then
				forwardSpeed = math.min(forwardSpeed + acceleration * throttle * dt, topSpeed)
			end
		elseif throttle < 0 then
			if forwardSpeed > -Config.ReverseSpeed then
				forwardSpeed = math.max(forwardSpeed + Config.Acceleration * throttle * dt, -Config.ReverseSpeed)
			end
		else
			forwardSpeed = moveToward(forwardSpeed, 0, Config.RollingDrag * dt)
		end
		forwardSpeed = math.clamp(forwardSpeed, -Config.MaxRollSpeed, Config.MaxRollSpeed)

		chassis.AssemblyLinearVelocity = frame.LookVector * forwardSpeed
			+ frame.RightVector * sideSpeed
			+ frame.UpVector * upSpeed

		local turnFactor = math.clamp(math.abs(forwardSpeed) / Config.TurnFullSpeed, Config.MinTurnFactor, 1)
		yawRate = -steer * Config.TurnRate * turnFactor
		local angular = chassis.AssemblyAngularVelocity
		angular += frame.UpVector * (yawRate - angular:Dot(frame.UpVector))

		-- A fast turn leans the chair over and fills the tip meter.
		local turnForce = math.abs(forwardSpeed * yawRate)
		if canFall and turnForce > Config.SafeTurnForce then
			local overflow = turnForce - Config.SafeTurnForce
			local before = tipMeter
			tipMeter += overflow / Config.TipBuildup * dt
			local leanDirection = if yawRate * forwardSpeed > 0 then 1 else -1
			angular += frame.LookVector * leanDirection * overflow * Config.TipRollStrength * dt
			if before < 0.3 and tipMeter >= 0.3 then
				GrandmaReactions.say(head, "Tipping")
			end
		else
			tipMeter = math.max(tipMeter - Config.TipDecay * dt, 0)
		end
		chassis.AssemblyAngularVelocity = angular
	end

	if canFall then
		local speedDrop = previousSpeed - horizontalSpeed
		if teleported then
			speedDrop = 0
		end

		if speedDrop >= Config.CrashSpeedDrop or tipMeter >= 1 or frame.UpVector.Y < maxTiltUpY then
			local launchFrom = frame.LookVector * math.max(previousSpeed, horizontalSpeed)
			launchGrandma(launchFrom)
		elseif speedDrop >= Config.BumpSpeedDrop then
			GrandmaReactions.say(head, "Bumped")
			grandmaBumped:FireServer()
		end
	end

	local newVelocity = chassis.AssemblyLinearVelocity
	previousSpeed = Vector3.new(newVelocity.X, 0, newVelocity.Z).Magnitude
end)
