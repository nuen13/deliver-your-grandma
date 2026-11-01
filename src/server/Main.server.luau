--!strict
-- Sets up the world, gives each player a wheelchair, and handles Grandma falling out and resets.

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Grandma = require(script.Parent.Grandma)
local TestRoom = require(script.Parent.TestRoom)
local Wheelchair = require(script.Parent.Wheelchair)

type Rig = {
	chair: Model,
	chassis: Part,
	grandma: Model,
	seatToken: number, -- cancels a waiting reseat when the chair is reset
	lastReset: number,
}

local RESET_COOLDOWN = 1

local rigs: { [Player]: Rig } = {}

for _, group in { "Chair", "Grandma", "Pusher" } do
	PhysicsService:RegisterCollisionGroup(group)
end
PhysicsService:CollisionGroupSetCollidable("Chair", "Grandma", false)
PhysicsService:CollisionGroupSetCollidable("Chair", "Pusher", false)
PhysicsService:CollisionGroupSetCollidable("Grandma", "Pusher", false)
PhysicsService:CollisionGroupSetCollidable("Grandma", "Grandma", false)

TestRoom.build()

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local grandmaEjected = Instance.new("RemoteEvent")
grandmaEjected.Name = "GrandmaEjected"
grandmaEjected.Parent = remotes
local resetChair = Instance.new("RemoteEvent")
resetChair.Name = "ResetChair"
resetChair.Parent = remotes
remotes.Parent = ReplicatedStorage

local function restoreChair(player: Player, rig: Rig, cframe: CFrame)
	rig.seatToken += 1
	rig.chassis:SetNetworkOwner(nil)
	rig.chair:PivotTo(cframe)
	rig.chassis.AssemblyLinearVelocity = Vector3.zero
	rig.chassis.AssemblyAngularVelocity = Vector3.zero
	Grandma.seat(rig.grandma, rig.chassis)
	rig.chassis:SetAttribute("GrandmaSeated", true)
	rig.chassis:SetNetworkOwner(player)
end

local function placePusher(player: Player, rig: Rig)
	local character = player.Character
	if character then
		character:PivotTo(rig.chassis.CFrame * CFrame.new(0, 2, 4.5))
	end
end

local function resetToStart(player: Player, rig: Rig)
	rig.lastReset = os.clock()
	restoreChair(player, rig, TestRoom.ChairStart)
	placePusher(player, rig)
end

local function uprightAt(chassis: Part): CFrame
	local look = chassis.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.1 then
		flatLook = Vector3.new(0, 0, -1)
	end
	local position = chassis.Position + Vector3.new(0, 3, 0)
	return CFrame.lookAt(position, position + flatLook)
end

local function attachPusher(player: Player, rig: Rig, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local rootPart = character:WaitForChild("HumanoidRootPart") :: Part

	local function setGroup(descendant: Instance)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = "Pusher"
		end
	end
	for _, descendant in character:GetDescendants() do
		setGroup(descendant)
	end
	character.DescendantAdded:Connect(setGroup)

	-- The client drives the chair, so the pusher shouldn't walk by themselves.
	humanoid.WalkSpeed = 0
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.AutoRotate = false

	local pusherPoint = rig.chassis:FindFirstChild("PusherPoint") :: Attachment

	local rootPoint = Instance.new("Attachment")
	rootPoint.Name = "PushPoint"
	rootPoint.Parent = rootPart

	-- Horizontal only, so the pusher still stands on the ground and follows slopes.
	local follow = Instance.new("AlignPosition")
	follow.Mode = Enum.PositionAlignmentMode.TwoAttachment
	follow.Attachment0 = rootPoint
	follow.Attachment1 = pusherPoint
	follow.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	follow.MaxAxesForce = Vector3.new(60000, 0, 60000)
	follow.Responsiveness = 100
	follow.ApplyAtCenterOfMass = true
	follow.Parent = rootPart

	local face = Instance.new("AlignOrientation")
	face.Mode = Enum.OrientationAlignmentMode.TwoAttachment
	face.Attachment0 = rootPoint
	face.Attachment1 = pusherPoint
	face.MaxTorque = 1000000
	face.Responsiveness = 100
	face.Parent = rootPart

	resetToStart(player, rig)
end

local function onPlayerAdded(player: Player)
	local chair = Wheelchair.build(player.Name .. "_Chair", TestRoom.ChairStart)
	local chassis = chair.PrimaryPart :: Part
	local grandma = Grandma.build(chair, chassis)
	chassis:SetAttribute("GrandmaSeated", true)

	local rig: Rig = {
		chair = chair,
		chassis = chassis,
		grandma = grandma,
		seatToken = 0,
		lastReset = 0,
	}
	rigs[player] = rig

	player.CharacterAdded:Connect(function(character)
		attachPusher(player, rig, character)
	end)
	if player.Character then
		attachPusher(player, rig, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	local rig = rigs[player]
	if rig then
		rig.chair:Destroy()
		rigs[player] = nil
	end
end)

grandmaEjected.OnServerEvent:Connect(function(player, launch: unknown)
	local rig = rigs[player]
	if not rig or rig.chassis:GetAttribute("GrandmaSeated") ~= true then
		return
	end
	if typeof(launch) ~= "Vector3" then
		return
	end
	local speed = launch.Magnitude
	if speed ~= speed or speed == math.huge then
		return
	end
	if speed > Config.MaxLaunchSpeed then
		launch = launch.Unit * Config.MaxLaunchSpeed
	end

	rig.chassis:SetAttribute("GrandmaSeated", false)
	Grandma.eject(rig.grandma, launch)

	rig.seatToken += 1
	local token = rig.seatToken
	task.delay(Config.ReseatDelay, function()
		if rigs[player] == rig and rig.seatToken == token then
			restoreChair(player, rig, uprightAt(rig.chassis))
		end
	end)
end)

resetChair.OnServerEvent:Connect(function(player)
	local rig = rigs[player]
	if rig and os.clock() - rig.lastReset >= RESET_COOLDOWN then
		resetToStart(player, rig)
	end
end)

RunService.Heartbeat:Connect(function()
	for player, rig in rigs do
		if rig.chassis.Position.Y < Config.FallResetHeight then
			resetToStart(player, rig)
		else
			local character = player.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: Part?
			if rootPart then
				local pusherPoint = rig.chassis.CFrame * CFrame.new(0, 2, 4.5)
				if (rootPart.Position - pusherPoint.Position).Magnitude > Config.MaxPusherDistance then
					placePusher(player, rig)
				end
			end
		end
	end
end)
