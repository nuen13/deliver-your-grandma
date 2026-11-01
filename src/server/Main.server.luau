--!strict
-- Sets up the world, gives each player a wheelchair, and runs Patience, falls, and restarts.
-- The Chassis attributes GrandmaSeated, Patience, Falls, RunState, Room, RoomName, RoomCount, Seed, FinishTime,
-- and BoostCount are the run's state for the client. RunState is Running, Failed, or Won.
-- In Studio, chat commands help with testing: !seed 1234, !room 2, !god

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Grandma = require(script.Parent.Grandma)
local RoomGenerator = require(script.Parent.RoomGenerator)
local Wheelchair = require(script.Parent.Wheelchair)

type Rig = {
	chair: Model,
	chassis: Part,
	grandma: Model,
	seatToken: number, -- cancels a waiting reseat when the chair is reset
	lastRestart: number,
	lastBump: number,
	patience: number,
	falls: number,
	layout: RoomGenerator.Layout?,
	room: number,
	startTime: number,
	godMode: boolean,
	boostCount: number,
}

local RESTART_COOLDOWN = 1
local CHECKPOINT_OFFSET = CFrame.new(0, 3, -4) -- from a room's entrance
local EXIT_HALF_WIDTH = 30
local EXIT_HALF_HEIGHT = 15
local EXIT_DEPTH = 8 -- deep enough that a fast chair can't skip it between updates

local seedPicker = Random.new()

local rigs: { [Player]: Rig } = {}

for _, group in { "Chair", "Grandma", "Pusher" } do
	PhysicsService:RegisterCollisionGroup(group)
end
PhysicsService:CollisionGroupSetCollidable("Chair", "Grandma", false)
PhysicsService:CollisionGroupSetCollidable("Chair", "Pusher", false)
PhysicsService:CollisionGroupSetCollidable("Grandma", "Pusher", false)
PhysicsService:CollisionGroupSetCollidable("Grandma", "Grandma", false)

RoomGenerator.buildStart()

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local grandmaEjected = Instance.new("RemoteEvent")
grandmaEjected.Name = "GrandmaEjected"
grandmaEjected.Parent = remotes
local grandmaBumped = Instance.new("RemoteEvent")
grandmaBumped.Name = "GrandmaBumped"
grandmaBumped.Parent = remotes
local restartRun = Instance.new("RemoteEvent")
restartRun.Name = "RestartRun"
restartRun.Parent = remotes
remotes.Parent = ReplicatedStorage

local function isRunning(rig: Rig): boolean
	return rig.chassis:GetAttribute("RunState") == "Running"
end

local function isSeated(rig: Rig): boolean
	return rig.chassis:GetAttribute("GrandmaSeated") == true
end

local function restoreChair(player: Player, rig: Rig, cframe: CFrame)
	rig.seatToken += 1
	rig.chassis.Anchored = false
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

local function currentRoom(rig: Rig): RoomGenerator.PlacedRoom?
	return rig.layout and rig.layout.rooms[rig.room]
end

local function checkpointFrame(rig: Rig): CFrame
	local room = currentRoom(rig)
	if room and rig.room > 1 then
		return room.entrance * CHECKPOINT_OFFSET
	end
	return RoomGenerator.ChairStart
end

local function returnToCheckpoint(player: Player, rig: Rig)
	restoreChair(player, rig, checkpointFrame(rig))
	placePusher(player, rig)
end

local function setRoom(rig: Rig, roomIndex: number)
	rig.room = roomIndex
	local room = currentRoom(rig)
	rig.chassis:SetAttribute("RoomName", if room then RoomGenerator.displayName(room.name) else "")
	rig.chassis:SetAttribute("Room", roomIndex)
end

local function startRun(player: Player, rig: Rig, seed: number?)
	rig.lastRestart = os.clock()
	rig.startTime = os.clock()
	rig.patience = Config.MaxPatience
	rig.falls = 0

	if rig.layout then
		rig.layout.model:Destroy()
	end
	local runSeed = seed or seedPicker:NextInteger(1, 999999)
	local layout = RoomGenerator.generate(runSeed, Config.RoomsPerRun)
	rig.layout = layout

	local roomNames = {}
	for _, room in layout.rooms do
		table.insert(roomNames, room.name)
	end
	print(`Run started. Seed {runSeed}: {table.concat(roomNames, ", ")}, {#layout.boosts} boosts`)

	setRoom(rig, 1)
	rig.boostCount = 0
	rig.chassis:SetAttribute("BoostCount", 0)
	rig.chassis:SetAttribute("Patience", rig.patience)
	rig.chassis:SetAttribute("Falls", rig.falls)
	rig.chassis:SetAttribute("RunState", "Running")
	rig.chassis:SetAttribute("RoomCount", #layout.rooms)
	rig.chassis:SetAttribute("Seed", runSeed)
	returnToCheckpoint(player, rig)
end

local function checkExit(rig: Rig)
	local room = currentRoom(rig)
	if not room or not isRunning(rig) or not isSeated(rig) then
		return -- nobody gets credit for arriving without Grandma
	end
	local position = room.exit:PointToObjectSpace(rig.chassis.Position)
	local reached = position.Z <= 0
		and position.Z >= -EXIT_DEPTH
		and math.abs(position.X) <= EXIT_HALF_WIDTH
		and math.abs(position.Y) <= EXIT_HALF_HEIGHT
	if not reached then
		return
	end

	local layout = rig.layout :: RoomGenerator.Layout
	if rig.room >= #layout.rooms then
		rig.chassis:SetAttribute("FinishTime", os.clock() - rig.startTime)
		rig.chassis:SetAttribute("RunState", "Won")
		print("Run won")
	else
		setRoom(rig, rig.room + 1)
		print(`Reached room {rig.room}: {room.name} finished`)
	end
end

local function checkBoosts(rig: Rig)
	local layout = rig.layout
	if not layout or not isRunning(rig) then
		return
	end
	for index = #layout.boosts, 1, -1 do
		local pickup = layout.boosts[index]
		if (pickup.Position - rig.chassis.Position).Magnitude <= Config.BoostPickupRadius then
			pickup:Destroy()
			table.remove(layout.boosts, index)
			rig.boostCount += 1
			rig.chassis:SetAttribute("BoostCount", rig.boostCount)
		end
	end
end

local function losePatience(rig: Rig, amount: number)
	if rig.godMode then
		return
	end
	rig.patience = math.max(rig.patience - amount, 0)
	rig.chassis:SetAttribute("Patience", rig.patience)
	if rig.patience == 0 then
		rig.chassis:SetAttribute("RunState", "Failed")
	end
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

local function throwGrandma(player: Player, rig: Rig, launch: Vector3)
	rig.chassis:SetAttribute("GrandmaSeated", false)
	Grandma.eject(rig.grandma, launch)
	rig.falls += 1
	rig.chassis:SetAttribute("Falls", rig.falls)
	losePatience(rig, Config.FallPatienceCost)

	rig.seatToken += 1
	local token = rig.seatToken
	if isRunning(rig) then
		task.delay(Config.ReseatDelay, function()
			if rigs[player] == rig and rig.seatToken == token then
				restoreChair(player, rig, uprightAt(rig.chassis))
			end
		end)
	end
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

	startRun(player, rig)
end

local function onDebugCommand(player: Player, rig: Rig, message: string)
	local command, argument = message:match("^!(%a+)%s*(%-?%d*)$")
	local number = tonumber(argument)
	if command == "seed" and number then
		startRun(player, rig, number)
	elseif command == "room" and number and rig.layout and rig.layout.rooms[number] then
		setRoom(rig, number)
		rig.chassis:SetAttribute("RunState", "Running")
		returnToCheckpoint(player, rig)
	elseif command == "god" then
		rig.godMode = not rig.godMode
		print(`God mode: {rig.godMode}`)
	end
end

local function onPlayerAdded(player: Player)
	local chair = Wheelchair.build(player.Name .. "_Chair", RoomGenerator.ChairStart)
	local chassis = chair.PrimaryPart :: Part
	local grandma = Grandma.build(chair, chassis)
	chassis:SetAttribute("GrandmaSeated", true)
	chassis:SetAttribute("Patience", Config.MaxPatience)
	chassis:SetAttribute("Falls", 0)
	chassis:SetAttribute("RunState", "Running")

	local rig: Rig = {
		chair = chair,
		chassis = chassis,
		grandma = grandma,
		seatToken = 0,
		lastRestart = 0,
		lastBump = 0,
		patience = Config.MaxPatience,
		falls = 0,
		layout = nil,
		room = 1,
		startTime = os.clock(),
		godMode = false,
		boostCount = 0,
	}
	rigs[player] = rig

	if RunService:IsStudio() then
		player.Chatted:Connect(function(message)
			onDebugCommand(player, rig, message)
		end)
	end

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
		if rig.layout then
			rig.layout.model:Destroy()
		end
		rigs[player] = nil
	end
end)

grandmaEjected.OnServerEvent:Connect(function(player, launch: unknown)
	local rig = rigs[player]
	if not rig or not isSeated(rig) or not isRunning(rig) then
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

	throwGrandma(player, rig, launch)
end)

grandmaBumped.OnServerEvent:Connect(function(player)
	local rig = rigs[player]
	if not rig or not isSeated(rig) or not isRunning(rig) then
		return
	end
	local now = os.clock()
	if now - rig.lastBump < Config.BumpCostCooldown then
		return
	end
	rig.lastBump = now

	-- The last bump she'll tolerate throws her out, so a run never ends with her still seated.
	if rig.patience <= Config.BumpPatienceCost and not rig.godMode then
		throwGrandma(player, rig, Vector3.yAxis * Config.LaunchUpSpeed)
	else
		losePatience(rig, Config.BumpPatienceCost)
	end
end)

restartRun.OnServerEvent:Connect(function(player)
	local rig = rigs[player]
	if rig and os.clock() - rig.lastRestart >= RESTART_COOLDOWN then
		startRun(player, rig)
	end
end)

RunService.Heartbeat:Connect(function()
	for player, rig in rigs do
		local room = currentRoom(rig)
		local entranceHeight = if room then room.entrance.Position.Y else 0
		local fallHeight = entranceHeight - Config.FallResetDepth
		Grandma.freezeBelow(rig.grandma, fallHeight)
		checkExit(rig)
		checkBoosts(rig)

		if rig.chassis.Position.Y < fallHeight and not rig.chassis.Anchored then
			-- Going off the edge with Grandma aboard counts as dropping her.
			if isRunning(rig) and isSeated(rig) then
				throwGrandma(player, rig, Vector3.zero)
			end
			if isRunning(rig) then
				returnToCheckpoint(player, rig)
			else
				rig.chassis.Anchored = true
			end
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
