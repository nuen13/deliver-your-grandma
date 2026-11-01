--!strict
-- First-person view from behind the wheelchair's handle, looking over Grandma.
-- Uses its own camera so it doesn't depend on Roblox's default camera scripts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local MAX_CHAIR_PITCH = 0.8 -- keep the last direction if the chair flips further than this

local player = Players.LocalPlayer
local chair = workspace:WaitForChild(player.Name .. "_Chair") :: Model
local chassis = chair:WaitForChild("Chassis") :: Part

local viewDirection = chassis.CFrame.LookVector
local fieldOfView = Config.CameraFieldOfView

local function hideCharacter()
	local character = player.Character
	if character then
		for _, descendant in character:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.LocalTransparencyModifier = 1
			end
		end
	end
end

RunService:BindToRenderStep("FirstPersonCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local boostKick = if chassis:GetAttribute("Boosted") == true then Config.BoostFieldOfViewKick else 0
	fieldOfView += (Config.CameraFieldOfView + boostKick - fieldOfView) * (1 - math.exp(-6 * dt))
	camera.FieldOfView = fieldOfView

	local frame = chassis.CFrame
	if math.abs(frame.LookVector.Y) < MAX_CHAIR_PITCH then
		local blend = 1 - math.exp(-Config.CameraTurnSmoothing * dt)
		viewDirection = viewDirection:Lerp(frame.LookVector, blend).Unit
	end

	-- Stays level with the world, so a tipping chair doesn't roll the view.
	local position = frame:PointToWorldSpace(Config.CameraOffset)
	local target = position + viewDirection - Vector3.yAxis * Config.CameraDownTilt
	camera.CFrame = CFrame.lookAt(position, target)

	hideCharacter()
end)
