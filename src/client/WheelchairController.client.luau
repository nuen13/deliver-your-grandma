--!strict
-- Drives the wheelchair and decides when a crash, tilt, or fast turn throws Grandma out.
-- ChairInput handles the driving controls. R or the gamepad's Y restarts the run.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ChairInput = require(script.Parent.ChairInput)
local Config = require(ReplicatedStorage.Shared.Config)
local GrandmaReactions = require(script.Parent.GrandmaReactions)

local TELEPORT_DISTANCE = 20 -- moving this far in one frame means a reset, not a crash
local GROUND_RAY_LENGTH = 1.5
local EJECT_TIMEOUT = 1 -- stop waiting if the server turned the eject down

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

local tipMeter = 0
local previousSpeed = 0
local previousPosition = chassis.Position
local wasSeated = true
local ejectPending = false -- sent to the server, but the attribute hasn't changed yet
local ejectTime = 0
local boostUntil = 0
local lastBoostCount = 0

-- How much upgrades have changed a stat during this run.
local function stat(name: string): number
	return (chassis:GetAttribute(`Stat{name}`) :: number?) or 1
end

chassis:GetAttributeChangedSignal("BoostCount"):Connect(function()
	local count = (chassis:GetAttribute("BoostCount") :: number?) or 0
	if count > lastBoostCount then
		boostUntil = os.clock() + Config.BoostDuration * stat("BoostTime")
		GrandmaReactions.say(head, "Boost", true)
	end
	lastBoostCount = count
end)

chassis:GetAttributeChangedSignal("Surface"):Connect(function()
	local surface = chassis:GetAttribute("Surface") :: string?
	if surface then
		GrandmaReactions.say(head, surface)
	end
end)

ContextActionService:BindAction("RestartRun", function(_, inputState)
	if inputState == Enum.UserInputState.Begin and chassis:GetAttribute("RunState") ~= "Menu" then
		restartRun:FireServer()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.R, Enum.KeyCode.ButtonY)

local function moveToward(value: number, target: number, amount: number): number
	if value < target then
		return math.min(value + amount, target)
	end
	return math.max(value - amount, target)
end

local function findGround(): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { chair, player.Character :: Instance }
	return workspace:Raycast(chassis.Position, chassis.CFrame.UpVector * -GROUND_RAY_LENGTH, params)
end

local function launchGrandma(velocity: Vector3)
	ejectPending = true
	ejectTime = os.clock()
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
	if ejectPending and seated and os.clock() - ejectTime > EJECT_TIMEOUT then
		ejectPending = false
	end
	if not seated then
		ejectPending = false
		wasSeated = false
	elseif not ejectPending and not wasSeated then
		wasSeated = true
		previousSpeed = horizontalSpeed
		GrandmaReactions.say(head, "Reseated", true)
	end
	local running = chassis:GetAttribute("RunState") == "Running"
	local canFall = running and seated and wasSeated and not ejectPending
	ChairInput.setTouchVisible(running)

	local throttle = if running then ChairInput.getThrottle() else 0
	local steer = if running then ChairInput.getSteer() else 0

	local yawRate = 0
	local forwardSpeed = velocity:Dot(frame.LookVector)
	local boosted = running and os.clock() < boostUntil
	-- Only this client reads it, for the camera's speed effect.
	chassis:SetAttribute("Boosted", boosted)

	local surface = chassis:GetAttribute("Surface")
	local ground = findGround()
	if ground then
		local grip = Config.SidewaysGrip * stat("Grip") * (if surface == "Oil" then Config.OilGripFactor else 1)
		local sideSpeed = velocity:Dot(frame.RightVector) * math.exp(-grip * dt)
		local upSpeed = math.min(velocity:Dot(frame.UpVector), Config.MaxStickUpSpeed)
		local speedStat = stat("Speed")
		local boostTopSpeed = Config.BoostTopSpeed * speedStat * stat("BoostSpeed")

		if ChairInput.isBraking() or not running then
			forwardSpeed = moveToward(forwardSpeed, 0, Config.BrakeDeceleration * stat("BrakePower") * dt)
		elseif boosted then
			-- A boost shoves the chair forward whether you're pushing or not.
			if forwardSpeed < boostTopSpeed then
				forwardSpeed = math.min(forwardSpeed + Config.BoostAcceleration * dt, boostTopSpeed)
			end
		elseif throttle > 0 then
			local sprinting = ChairInput.isSprinting()
			local topSpeed = (if sprinting then Config.SprintTopSpeed else Config.TopSpeed) * speedStat
			local acceleration = (if sprinting then Config.SprintAcceleration else Config.Acceleration) * stat("Acceleration")
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
		local maxSpeed = if boosted then boostTopSpeed else Config.MaxRollSpeed * speedStat
		forwardSpeed = math.clamp(forwardSpeed, -maxSpeed, maxSpeed)
		if surface == "Mud" and forwardSpeed > Config.MudTopSpeed then
			forwardSpeed = moveToward(forwardSpeed, Config.MudTopSpeed, Config.MudDrag * dt)
		end

		chassis.AssemblyLinearVelocity = frame.LookVector * forwardSpeed
			+ frame.RightVector * sideSpeed
			+ frame.UpVector * upSpeed

		local turnFactor = math.clamp(math.abs(forwardSpeed) / Config.TurnFullSpeed, Config.MinTurnFactor, 1)
		yawRate = -steer * Config.TurnRate * stat("TurnRate") * turnFactor
		-- Steering sets the turn, and the chair follows the slope instead of wobbling freely.
		local angular = frame.UpVector * yawRate
			+ frame.UpVector:Cross(ground.Normal) * Config.GroundAlignStrength

		-- A fast turn leans the chair over and fills the tip meter.
		local turnForce = math.abs(forwardSpeed * yawRate)
		local safeTurnForce = Config.SafeTurnForce * stat("TurnSafety")
		if canFall and turnForce > safeTurnForce then
			local overflow = turnForce - safeTurnForce
			local before = tipMeter
			tipMeter += overflow / Config.TipBuildup * dt
			local leanDirection = if yawRate * forwardSpeed > 0 then 1 else -1
			angular += frame.LookVector * leanDirection * overflow * Config.TipRollStrength
			if before < 0.3 and tipMeter >= 0.3 then
				GrandmaReactions.say(head, "Tipping")
			end
		else
			tipMeter = math.max(tipMeter - Config.TipDecay * dt, 0)
		end
		chassis.AssemblyAngularVelocity = angular
	else
		-- Level out in the air, so jumps land on the wheels.
		chassis.AssemblyAngularVelocity = frame.UpVector:Cross(Vector3.yAxis) * Config.AirAlignStrength
	end

	if canFall then
		local speedDrop = previousSpeed - horizontalSpeed
		if teleported then
			speedDrop = 0
		end

		if speedDrop >= Config.CrashSpeedDrop * stat("Toughness") or tipMeter >= 1 or frame.UpVector.Y < maxTiltUpY then
			local launchFrom = frame.LookVector * math.max(previousSpeed, horizontalSpeed)
			launchGrandma(launchFrom)
		elseif speedDrop >= Config.BumpSpeedDrop * stat("Toughness") then
			GrandmaReactions.say(head, "Bumped")
			grandmaBumped:FireServer()
		end
	end

	local newVelocity = chassis.AssemblyLinearVelocity
	previousSpeed = Vector3.new(newVelocity.X, 0, newVelocity.Z).Magnitude
end)
