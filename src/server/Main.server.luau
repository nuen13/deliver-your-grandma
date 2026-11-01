--!strict
-- Sets up the world, gives each player a wheelchair, and runs Patience, falls, rooms, rewards, and restarts.
-- The Chassis attributes GrandmaSeated, Patience, Falls, RunState, Room, RoomName, RoomCount, Seed, FinishTime,
-- BoostCount, UpgradeOffer, RunTickets, Surface, BossLetters, and Stat<Name> are the run's state for the client.
-- RunState is Menu, Running, Choosing (picking an upgrade card), Failed, or Won.
-- The Player attributes ProfileReady, SaveWarning, Tickets, Unlocked, BestTime, and Wins are their saved progress.
-- In Studio, chat commands help with testing: !seed 1234, !room 2, !god, !tickets 100

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Boss = require(script.Parent.Boss)
local Config = require(ReplicatedStorage.Shared.Config)
local Grandma = require(script.Parent.Grandma)
local HazardData = require(ReplicatedStorage.Shared.Data.Hazards)
local HazardRunner = require(script.Parent.HazardRunner)
local RoomGenerator = require(script.Parent.RoomGenerator)
local Saves = require(script.Parent.Saves)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)
local Wheelchair = require(script.Parent.Wheelchair)

type Rig = {
	chair: Model,
	chassis: Part,
	grandma: Model,
	seatToken: number, -- cancels a waiting reseat when the chair is reset
	lastRestart: number,
	lastBump: number,
	lastHazardHit: number,
	patience: number,
	falls: number,
	layout: RoomGenerator.Layout?,
	room: number,
	startTime: number,
	godMode: boolean,
	boostCount: number,
	stats: { [string]: number }, -- only stats an upgrade has changed
	upgradeRandom: Random,
	offer: { Upgrades.Upgrade }?,
	offerTime: number,
	runTickets: number,
	profile: Saves.Profile?, -- nil until loaded, and no run can start before then
}

local RESTART_COOLDOWN = 1
local CHECKPOINT_OFFSET = CFrame.new(0, 3, -4) -- from a room's entrance
local EXIT_HALF_WIDTH = 30
local EXIT_HALF_HEIGHT = 15
local EXIT_DEPTH = 8 -- deep enough that a fast chair can't skip it between updates

local seedPicker = Random.new()

local rigs: { [Player]: Rig } = {}

local upgradesById: { [string]: Upgrades.Upgrade } = {}
for _, upgrade in Upgrades do
	upgradesById[upgrade.id] = upgrade
end

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
local function addRemote(name: string): RemoteEvent
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	return remote
end
local grandmaEjected = addRemote("GrandmaEjected")
local grandmaBumped = addRemote("GrandmaBumped")
local restartRun = addRemote("RestartRun")
local returnToMenu = addRemote("ReturnToMenu")
local chooseUpgrade = addRemote("ChooseUpgrade")
local buyUpgrade = addRemote("BuyUpgrade")
local grandmaSay = addRemote("GrandmaSay")
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

-- "B _ N _ _" while in the boss room, otherwise nothing.
local function updateBossLetters(rig: Rig)
	local room = currentRoom(rig)
	local layout = rig.layout
	if not room or not room.isBoss or not layout then
		rig.chassis:SetAttribute("BossLetters", nil)
		return
	end
	local shown = {}
	for _, entry in layout.letters do
		table.insert(shown, if entry.part then "_" else entry.letter)
	end
	rig.chassis:SetAttribute("BossLetters", table.concat(shown, " "))
end

local function setRoom(rig: Rig, roomIndex: number)
	rig.room = roomIndex
	local room = currentRoom(rig)
	rig.chassis:SetAttribute("RoomName", if room then RoomGenerator.displayName(room.name) else "")
	rig.chassis:SetAttribute("Room", roomIndex)
	updateBossLetters(rig)
end

local function clearRun(rig: Rig)
	rig.offer = nil
	for name in rig.stats do
		rig.chassis:SetAttribute(`Stat{name}`, nil)
	end
	rig.stats = {}
	rig.chassis:SetAttribute("Surface", nil)
	if rig.layout then
		rig.layout.model:Destroy()
		rig.layout = nil
	end
end

local function startRun(player: Player, rig: Rig, seed: number?)
	rig.lastRestart = os.clock()
	rig.startTime = os.clock()
	rig.patience = Config.MaxPatience
	rig.falls = 0
	rig.runTickets = 0
	clearRun(rig)

	local runSeed = seed or seedPicker:NextInteger(1, 999999)
	local layout = RoomGenerator.generate(runSeed, Config.RoomsPerRun)
	rig.layout = layout
	rig.upgradeRandom = Random.new(runSeed)

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
	rig.chassis:SetAttribute("RunTickets", 0)
	rig.chassis:SetAttribute("RoomCount", #layout.rooms)
	rig.chassis:SetAttribute("Seed", runSeed)
	returnToCheckpoint(player, rig)
	rig.chassis:SetAttribute("RunState", "Running")
end

local function publishProfile(player: Player, rig: Rig)
	local profile = rig.profile
	if profile then
		player:SetAttribute("Tickets", profile.tickets)
		player:SetAttribute("Unlocked", table.concat(profile.unlocked, ","))
		player:SetAttribute("BestTime", profile.bestTime)
		player:SetAttribute("Wins", profile.wins)
	end
end

local function awardTickets(player: Player, rig: Rig, amount: number)
	local profile = rig.profile
	if not profile then
		return
	end
	local earned = math.ceil(amount * (rig.stats.TicketBonus or 1))
	profile.tickets += earned
	rig.runTickets += earned
	rig.chassis:SetAttribute("RunTickets", rig.runTickets)
	publishProfile(player, rig)
	Saves.markDirty(player)
end

local function offerUpgrades(player: Player, rig: Rig)
	local profile = rig.profile
	local pool = {}
	for _, upgrade in Upgrades do
		if not upgrade.cost or (profile and table.find(profile.unlocked, upgrade.id)) then
			table.insert(pool, upgrade)
		end
	end
	rig.upgradeRandom:Shuffle(pool)

	local offer = {}
	local ids = {}
	for index = 1, math.min(Config.UpgradeCardsOffered, #pool) do
		table.insert(offer, pool[index])
		table.insert(ids, pool[index].id)
	end
	rig.offer = offer
	rig.offerTime = os.clock()
	rig.chassis:SetAttribute("UpgradeOffer", table.concat(ids, ","))
	rig.chassis:SetAttribute("RunState", "Choosing")
end

local function applyUpgrade(rig: Rig, upgrade: Upgrades.Upgrade)
	if upgrade.multiply then
		for name, factor in upgrade.multiply do
			local value = (rig.stats[name] or 1) * factor
			rig.stats[name] = value
			rig.chassis:SetAttribute(`Stat{name}`, value)
		end
	end
	if upgrade.heal then
		rig.patience = math.min(rig.patience + upgrade.heal, Config.MaxPatience)
		rig.chassis:SetAttribute("Patience", rig.patience)
	end
	print(`Upgrade picked: {upgrade.id}`)
end

local function winRun(player: Player, rig: Rig)
	local seconds = os.clock() - rig.startTime
	local profile = rig.profile
	if profile then
		profile.wins += 1
		if not profile.bestTime or seconds < profile.bestTime then
			profile.bestTime = seconds
		end
	end
	awardTickets(player, rig, Config.TicketsWinBonus + (if rig.falls == 0 then Config.TicketsCleanBonus else 0))
	rig.chassis:SetAttribute("FinishTime", seconds)
	rig.chassis:SetAttribute("RunState", "Won")
	print("Run won")
end

local function checkExit(player: Player, rig: Rig)
	local room = currentRoom(rig)
	if not room or not isRunning(rig) or not isSeated(rig) then
		return -- nobody gets credit for arriving without Grandma
	end
	local layout = rig.layout :: RoomGenerator.Layout
	if room.isBoss and layout.gate then
		return -- the gate is still closed
	end
	local position = room.exit:PointToObjectSpace(rig.chassis.Position)
	local reached = position.Z <= 0
		and position.Z >= -EXIT_DEPTH
		and math.abs(position.X) <= EXIT_HALF_WIDTH
		and math.abs(position.Y) <= EXIT_HALF_HEIGHT
	if not reached then
		return
	end

	awardTickets(player, rig, Config.TicketsPerRoom)
	if rig.room >= #layout.rooms then
		winRun(player, rig)
	else
		setRoom(rig, rig.room + 1)
		print(`Reached room {rig.room}: {room.name} finished`)
		offerUpgrades(player, rig)
	end
end

local function checkBoosts(rig: Rig)
	local layout = rig.layout
	if not layout or not isRunning(rig) then
		return
	end
	local radius = Config.BoostPickupRadius * (rig.stats.BoostRadius or 1)
	for index = #layout.boosts, 1, -1 do
		local pickup = layout.boosts[index]
		if (pickup.Position - rig.chassis.Position).Magnitude <= radius then
			pickup:Destroy()
			table.remove(layout.boosts, index)
			rig.boostCount += 1
			rig.chassis:SetAttribute("BoostCount", rig.boostCount)
		end
	end
end

local function patienceCost(rig: Rig, amount: number, stats: { string }): number
	local cost = amount * (rig.stats.Damage or 1)
	for _, name in stats do
		cost *= rig.stats[name] or 1
	end
	return cost
end

local function losePatience(rig: Rig, cost: number)
	if rig.godMode then
		return
	end
	rig.patience = math.max(rig.patience - cost, 0)
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

local function throwGrandma(player: Player, rig: Rig, launch: Vector3, damageStats: { string })
	rig.chassis:SetAttribute("GrandmaSeated", false)
	Grandma.eject(rig.grandma, launch)
	rig.falls += 1
	rig.chassis:SetAttribute("Falls", rig.falls)
	losePatience(rig, patienceCost(rig, Config.FallPatienceCost, damageStats))

	rig.seatToken += 1
	local token = rig.seatToken
	if isRunning(rig) then
		task.delay(Config.ReseatDelay * (rig.stats.ReseatTime or 1), function()
			if rigs[player] == rig and rig.seatToken == token then
				restoreChair(player, rig, uprightAt(rig.chassis))
			end
		end)
	end
end

-- The last bump she'll tolerate throws her out, so a run never ends with her still seated.
local function bumpGrandma(player: Player, rig: Rig, amount: number, damageStats: { string })
	local cost = patienceCost(rig, amount, damageStats)
	if rig.patience <= cost and not rig.godMode then
		throwGrandma(player, rig, Vector3.yAxis * Config.LaunchUpSpeed, { "FallDamage" })
	else
		losePatience(rig, cost)
	end
end

local function updateHazards(player: Player, rig: Rig, now: number)
	local layout = rig.layout
	if not layout then
		return
	end
	local active = isRunning(rig)
	local position = rig.chassis.Position
	local surface: string? = nil

	for _, hazard in layout.hazards do
		HazardRunner.update(hazard, now)
		if active and HazardRunner.isHitting(hazard, position) then
			local data = HazardData[hazard.kind]
			surface = data.surface or surface
			if data.effect and isSeated(rig) and now - rig.lastHazardHit >= Config.HazardHitCooldown then
				rig.lastHazardHit = now
				if data.line then
					grandmaSay:FireClient(player, data.line)
				end
				if data.effect == "throw" then
					local launch = rig.chassis.AssemblyLinearVelocity + Vector3.yAxis * Config.LaunchUpSpeed
					if launch.Magnitude > Config.MaxLaunchSpeed then
						launch = launch.Unit * Config.MaxLaunchSpeed
					end
					throwGrandma(player, rig, launch, { "FallDamage", "HazardDamage" })
				else
					bumpGrandma(player, rig, Config.BumpPatienceCost, { "BumpDamage", "HazardDamage" })
				end
			end
		end
	end

	if rig.chassis:GetAttribute("Surface") ~= surface then
		rig.chassis:SetAttribute("Surface", surface)
	end
end

local function updateBoss(player: Player, rig: Rig, dt: number, now: number)
	local layout = rig.layout
	local room = currentRoom(rig)
	if not layout or not layout.boss then
		return
	end
	local inBossRoom = room ~= nil and room.isBoss and isRunning(rig)

	local collected = 0
	for _, entry in layout.letters do
		local part = entry.part
		if not part then
			collected += 1
		elseif inBossRoom and (part.Position - rig.chassis.Position).Magnitude <= Config.BossLetterRadius then
			part:Destroy()
			entry.part = nil
			collected += 1
			updateBossLetters(rig)
			if collected < #layout.letters then
				grandmaSay:FireClient(player, "BossLetter")
			end
		end
	end

	if layout.gate and collected >= #layout.letters then
		layout.gate:Destroy()
		layout.gate = nil
		Boss.defeat(layout.boss)
		grandmaSay:FireClient(player, "BossDefeated")
		print("Mildred defeated")
		return
	end

	local active = inBossRoom and isSeated(rig)
	local hit = Boss.update(layout.boss, dt, now, rig.chassis.Position, rig.chassis.AssemblyLinearVelocity, active, collected)
	if hit and now - rig.lastHazardHit >= Config.HazardHitCooldown then
		rig.lastHazardHit = now
		grandmaSay:FireClient(player, "BossHit")
		bumpGrandma(player, rig, Config.BossBallPatienceCost, { "BumpDamage", "HazardDamage" })
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

	-- A respawn mid-run picks up from the checkpoint and keeps the run's progress.
	local state = rig.chassis:GetAttribute("RunState")
	if state == "Running" or state == "Choosing" then
		returnToCheckpoint(player, rig)
	else
		placePusher(player, rig)
	end
end

local function onDebugCommand(player: Player, rig: Rig, message: string)
	local command, argument = message:match("^!(%a+)%s*(%-?%d*)$")
	local number = tonumber(argument)
	if command == "seed" and number and rig.profile then
		startRun(player, rig, number)
	elseif command == "room" and number and rig.layout and rig.layout.rooms[number] then
		rig.offer = nil
		setRoom(rig, number)
		returnToCheckpoint(player, rig)
		rig.chassis:SetAttribute("RunState", "Running")
	elseif command == "god" then
		rig.godMode = not rig.godMode
		print(`God mode: {rig.godMode}`)
	elseif command == "tickets" and number and rig.profile then
		rig.profile.tickets += number
		publishProfile(player, rig)
		Saves.markDirty(player)
	end
end

local function loadProfile(player: Player, rig: Rig)
	local profile, willSave = Saves.load(player)
	if rigs[player] ~= rig then
		return
	end
	rig.profile = profile
	publishProfile(player, rig)
	player:SetAttribute("SaveWarning", not willSave)
	player:SetAttribute("ProfileReady", true)
end

local function onPlayerAdded(player: Player)
	local chair = Wheelchair.build(player.Name .. "_Chair", RoomGenerator.ChairStart)
	local chassis = chair.PrimaryPart :: Part
	local grandma = Grandma.build(chair, chassis)
	chassis:SetAttribute("GrandmaSeated", true)
	chassis:SetAttribute("Patience", Config.MaxPatience)
	chassis:SetAttribute("Falls", 0)
	chassis:SetAttribute("RunState", "Menu")

	local rig: Rig = {
		chair = chair,
		chassis = chassis,
		grandma = grandma,
		seatToken = 0,
		lastRestart = 0,
		lastBump = 0,
		lastHazardHit = 0,
		patience = Config.MaxPatience,
		falls = 0,
		layout = nil,
		room = 1,
		startTime = os.clock(),
		godMode = false,
		boostCount = 0,
		stats = {},
		upgradeRandom = Random.new(),
		offer = nil,
		offerTime = 0,
		runTickets = 0,
		profile = nil,
	}
	rigs[player] = rig
	chassis:SetNetworkOwner(player)
	task.spawn(loadProfile, player, rig)

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
	Saves.release(player)
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

	throwGrandma(player, rig, launch, { "FallDamage" })
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
	bumpGrandma(player, rig, Config.BumpPatienceCost, { "BumpDamage" })
end)

restartRun.OnServerEvent:Connect(function(player)
	local rig = rigs[player]
	if rig and rig.profile and os.clock() - rig.lastRestart >= RESTART_COOLDOWN then
		startRun(player, rig)
	end
end)

returnToMenu.OnServerEvent:Connect(function(player)
	local rig = rigs[player]
	if not rig then
		return
	end
	local state = rig.chassis:GetAttribute("RunState")
	if state ~= "Failed" and state ~= "Won" then
		return
	end
	clearRun(rig)
	rig.room = 1
	restoreChair(player, rig, RoomGenerator.ChairStart)
	placePusher(player, rig)
	rig.chassis:SetAttribute("BossLetters", nil)
	rig.chassis:SetAttribute("RunState", "Menu")
end)

chooseUpgrade.OnServerEvent:Connect(function(player, index: unknown)
	local rig = rigs[player]
	if not rig or typeof(index) ~= "number" or rig.chassis:GetAttribute("RunState") ~= "Choosing" then
		return
	end
	local upgrade = rig.offer and rig.offer[index]
	if not upgrade then
		return
	end

	rig.offer = nil
	applyUpgrade(rig, upgrade)
	rig.startTime += os.clock() - rig.offerTime -- choosing doesn't count toward the finish time
	rig.chassis:SetAttribute("RunState", "Running")

	local room = currentRoom(rig)
	if room and room.isBoss then
		grandmaSay:FireClient(player, "BossStart")
	end
end)

buyUpgrade.OnServerEvent:Connect(function(player, id: unknown)
	local rig = rigs[player]
	if not rig or typeof(id) ~= "string" then
		return
	end
	local profile = rig.profile
	local upgrade = upgradesById[id]
	if not profile or not upgrade or not upgrade.cost then
		return
	end
	if table.find(profile.unlocked, id) or profile.tickets < upgrade.cost then
		return
	end
	profile.tickets -= upgrade.cost
	table.insert(profile.unlocked, id)
	publishProfile(player, rig)
	Saves.markDirty(player)
end)

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	for player, rig in rigs do
		local room = currentRoom(rig)
		local entranceHeight = if room then room.entrance.Position.Y else 0
		local fallHeight = entranceHeight - Config.FallResetDepth
		Grandma.freezeBelow(rig.grandma, fallHeight)
		checkExit(player, rig)
		checkBoosts(rig)
		updateHazards(player, rig, now)
		updateBoss(player, rig, dt, now)

		if rig.chassis.Position.Y < fallHeight and not rig.chassis.Anchored then
			-- Going off the edge with Grandma aboard counts as dropping her.
			if isRunning(rig) and isSeated(rig) then
				throwGrandma(player, rig, Vector3.zero, { "FallDamage" })
			end
			local state = rig.chassis:GetAttribute("RunState")
			if state == "Failed" or state == "Won" then
				rig.chassis.Anchored = true
			else
				returnToCheckpoint(player, rig)
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
