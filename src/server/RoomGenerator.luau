--!strict
-- Turns the room data into parts, and connects a seeded random set of rooms end to end.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boss = require(script.Parent.Boss)
local Config = require(ReplicatedStorage.Shared.Config)
local HazardRunner = require(script.Parent.HazardRunner)
local RoomData = require(ReplicatedStorage.Shared.Data.Rooms) :: any

local RoomGenerator = {}

export type PlacedRoom = {
	name: string,
	entrance: CFrame,
	exit: CFrame,
	isBoss: boolean,
}

export type Letter = {
	letter: string,
	part: Part?, -- nil once collected
}

export type Layout = {
	model: Model,
	rooms: { PlacedRoom },
	boosts: { Part },
	hazards: { HazardRunner.Hazard },
	letters: { Letter },
	gate: Part?,
	boss: Boss.State?,
}

-- What a room adds to the layout as it's built.
type RoomContents = {
	random: Random,
	boosts: { Part },
	hazards: { HazardRunner.Hazard },
	letters: { Letter },
	gate: Part?,
	boss: Boss.State?,
}

local WALL_COLOR = Color3.fromRGB(190, 130, 90)
local START_ROAD_COLOR = Color3.fromRGB(95, 95, 105)
-- One road color per room, so it's obvious when you've reached a new one.
local ROOM_ROAD_COLORS = {
	Color3.fromRGB(70, 110, 170),
	Color3.fromRGB(135, 80, 165),
	Color3.fromRGB(185, 95, 60),
	Color3.fromRGB(60, 140, 120),
	Color3.fromRGB(170, 75, 110),
}
local CRATE_COLOR = Color3.fromRGB(160, 110, 60)
local GATE_COLOR = Color3.fromRGB(255, 210, 70)
local FINISH_COLOR = Color3.fromRGB(90, 220, 120)
local BOOST_COLOR = Color3.fromRGB(255, 240, 60)
local LETTER_COLOR = Color3.fromRGB(255, 120, 200)
local BOSS_GATE_COLOR = Color3.fromRGB(200, 40, 60)

-- Where a player starts, and the chair's start. Heads toward the first room.
RoomGenerator.ChairStart = CFrame.new(0, 3, 12)

local function addPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function addDecoration(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = addPart(parent, name, size, cframe, color)
	part.Material = Enum.Material.Neon
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

local function addFloatingText(part: Part, text: string, sizeInStuds: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(sizeInStuds, sizeInStuds)
	billboard.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.Cartoon
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard
	billboard.Parent = part
end

local function buildRoom(parent: Instance, name: string, data: any, origin: CFrame, roadColor: Color3, contents: RoomContents?)
	local room = Instance.new("Model")
	room.Name = name

	for _, piece in data.parts do
		if piece.kind == "block" then
			local color = if piece.color == "Wall" then WALL_COLOR else roadColor
			addPart(room, "Block", piece.size, origin * CFrame.new(piece.at), color)
		elseif piece.kind == "ramp" then
			-- Sits just below the high end and only overlaps at the low end, so there's no lip to catch on.
			local size = Vector3.new(piece.width, 1, (piece.low - piece.high).Magnitude + 1)
			local frame = CFrame.lookAt((piece.high + piece.low) / 2, piece.low) * CFrame.new(0, -0.01, -0.5)
			addPart(room, "Ramp", size, origin * frame, roadColor)
		elseif piece.kind == "crate" then
			local crate = addPart(room, "Crate", Vector3.new(3, 3, 3), origin * CFrame.new(piece.at), CRATE_COLOR)
			crate.Anchored = false
			crate.CustomPhysicalProperties = PhysicalProperties.new(0.15, 0.4, 0.3)
		elseif contents and piece.kind == "boost" then
			if contents.random:NextNumber() < Config.BoostChance then
				local pickup = addDecoration(room, "Boost", Vector3.new(3, 3, 3), origin * CFrame.new(piece.at), BOOST_COLOR)
				pickup.Shape = Enum.PartType.Ball
				table.insert(contents.boosts, pickup)
			end
		elseif contents and piece.kind == "hazard" then
			local hazard = HazardRunner.build(room, piece.hazard, origin * CFrame.new(piece.at), piece.options, contents.random)
			table.insert(contents.hazards, hazard)
		elseif contents and piece.kind == "letter" then
			local pickup = addDecoration(room, "Letter", Vector3.new(5, 5, 5), origin * CFrame.new(piece.at), LETTER_COLOR)
			pickup.Shape = Enum.PartType.Ball
			addFloatingText(pickup, piece.letter, 6)
			table.insert(contents.letters, { letter = piece.letter, part = pickup })
		elseif contents and piece.kind == "gate" then
			contents.gate = addPart(room, "BossGate", piece.size, origin * CFrame.new(piece.at), BOSS_GATE_COLOR)
		elseif contents and piece.kind == "mildred" then
			contents.boss = Boss.build(room, origin * CFrame.new(piece.at), contents.random)
		end
	end

	room.Parent = parent
end

local function addGate(parent: Instance, exit: CFrame, color: Color3, signText: string)
	addDecoration(parent, "GatePost", Vector3.new(1, 12, 1), exit * CFrame.new(-15, 6, 0), color)
	addDecoration(parent, "GatePost", Vector3.new(1, 12, 1), exit * CFrame.new(15, 6, 0), color)
	local sign = addDecoration(parent, "GateSign", Vector3.new(31, 5, 1), exit * CFrame.new(0, 14, 0), color)

	-- The chair heads toward -Z, so it approaches the sign's Back face.
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Back
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 20
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(0, 0, 0)
	label.Font = Enum.Font.Cartoon
	label.TextScaled = true
	label.Text = signText
	label.Parent = surface
	surface.Parent = sign
end

-- "SharpTurn" becomes "Sharp Turn".
function RoomGenerator.displayName(name: string): string
	return (name:gsub("(%l)(%u)", "%1 %2"))
end

-- The start area stays between runs, because players spawn there.
function RoomGenerator.buildStart()
	local holder = Instance.new("Model")
	holder.Name = "StartArea"
	buildRoom(holder, "Start", RoomData.Start, CFrame.identity, START_ROAD_COLOR)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(0, 0.6, 28)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = holder

	holder.Parent = workspace
end

function RoomGenerator.generate(seed: number, roomCount: number): Layout
	local random = Random.new(seed)

	-- Sorted first, because Luau doesn't promise an order for named keys and a seed must always give the same run.
	local names = {}
	for name in RoomData.Pool do
		table.insert(names, name)
	end
	table.sort(names)
	random:Shuffle(names)

	local model = Instance.new("Model")
	model.Name = "RunRooms"

	local count = math.min(roomCount, #names)
	-- The boss room always comes last.
	names[count + 1] = RoomData.Boss.name

	local rooms: { PlacedRoom } = {}
	local contents: RoomContents = {
		random = random,
		boosts = {},
		hazards = {},
		letters = {},
		gate = nil,
		boss = nil,
	}
	local cursor = RoomData.Start.exit
	for index = 1, count + 1 do
		local name = names[index]
		local isBoss = index == count + 1
		local data = if isBoss then RoomData.Boss else RoomData.Pool[name]
		local exit = cursor * data.exit
		local roadColor = ROOM_ROAD_COLORS[(index - 1) % #ROOM_ROAD_COLORS + 1]
		buildRoom(model, name, data, cursor, roadColor, contents)
		if isBoss then
			addGate(model, exit, FINISH_COLOR, "BINGO HALL")
		else
			addGate(model, exit, GATE_COLOR, `ROOM {index + 1}: {RoomGenerator.displayName(names[index + 1])}`)
		end
		table.insert(rooms, { name = name, entrance = cursor, exit = exit, isBoss = isBoss })
		cursor = exit
	end
	buildRoom(model, "Finish", RoomData.Finish, cursor, FINISH_COLOR)

	model.Parent = workspace
	return {
		model = model,
		rooms = rooms,
		boosts = contents.boosts,
		hazards = contents.hazards,
		letters = contents.letters,
		gate = contents.gate,
		boss = contents.boss,
	}
end

return RoomGenerator
