--!strict
-- The test course: a long ramp, a sharp turn, a slalom, a narrow bridge, a second hill,
-- speed bumps, and a jump that needs a sprint.

local TestRoom = {}

local ROAD_COLOR = Color3.fromRGB(95, 95, 105)
local WALL_COLOR = Color3.fromRGB(190, 130, 90)
local RAMP_COLOR = Color3.fromRGB(120, 110, 130)

TestRoom.ChairStart = CFrame.new(0, 15, 8)

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

local function addCrate(parent: Instance, position: Vector3)
	local crate = addPart(parent, "Crate", Vector3.new(3, 3, 3), CFrame.new(position), Color3.fromRGB(160, 110, 60))
	crate.Anchored = false
	crate.CustomPhysicalProperties = PhysicalProperties.new(0.15, 0.4, 0.3)
end

-- Sits just below the high end and only overlaps at the low end, so there's no lip to catch on.
local function addRamp(parent: Instance, name: string, high: Vector3, low: Vector3, width: number)
	addPart(
		parent,
		name,
		Vector3.new(width, 1, (low - high).Magnitude + 1),
		CFrame.lookAt((high + low) / 2, low) * CFrame.new(0, -0.01, -0.5),
		RAMP_COLOR
	)
end

local function addLaterSections(room: Model)
	-- Slalom
	addPart(room, "SlalomRun", Vector3.new(180, 1, 40), CFrame.new(210, 0, -190), ROAD_COLOR)
	addPart(room, "SlalomWallA", Vector3.new(180, 8, 2), CFrame.new(210, 4, -211), WALL_COLOR)
	addPart(room, "SlalomWallB", Vector3.new(180, 8, 2), CFrame.new(210, 4, -169), WALL_COLOR)
	for index, x in { 150, 190, 230, 270 } do
		local z = if index % 2 == 0 then -180 else -200
		addPart(room, "SlalomPillar", Vector3.new(4, 8, 4), CFrame.new(x, 4, z), WALL_COLOR)
	end

	-- Narrow bridge with no walls
	addPart(room, "Bridge", Vector3.new(80, 1, 12), CFrame.new(340, 0, -190), RAMP_COLOR)

	-- Corner platform with more crates, turning left onto the second hill
	addPart(room, "CornerPlatform", Vector3.new(60, 1, 60), CFrame.new(410, 0, -190), ROAD_COLOR)
	addPart(room, "CornerWallA", Vector3.new(2, 8, 60), CFrame.new(441, 4, -190), WALL_COLOR)
	addPart(room, "CornerWallB", Vector3.new(60, 8, 2), CFrame.new(410, 4, -159), WALL_COLOR)
	for column = -1, 1 do
		addCrate(room, Vector3.new(410 + column * 7, 2, -205))
	end

	-- Second hill and speed bumps
	addRamp(room, "SecondHill", Vector3.new(410, 0, -220), Vector3.new(410, -12, -320), 20)
	addPart(room, "BumpRun", Vector3.new(30, 1, 100), CFrame.new(410, -12, -370), ROAD_COLOR)
	for _, z in { -345, -365, -385 } do
		addPart(room, "SpeedBump", Vector3.new(30, 0.6, 3), CFrame.new(410, -11.6, z), WALL_COLOR)
	end

	-- A jump that needs a sprint to clear the gap, with a finish area to land on
	addRamp(room, "JumpRamp", Vector3.new(410, -8, -440), Vector3.new(410, -12, -420), 20)
	addPart(room, "Landing", Vector3.new(40, 1, 60), CFrame.new(410, -20, -480), ROAD_COLOR)
	addPart(room, "FinishWall", Vector3.new(40, 10, 2), CFrame.new(410, -15, -511), WALL_COLOR)
	local finish = addPart(room, "FinishPad", Vector3.new(16, 0.2, 8), CFrame.new(410, -19.4, -500), Color3.fromRGB(90, 220, 120))
	finish.Material = Enum.Material.Neon
	finish.CanCollide = false
end

function TestRoom.build(): Model
	local room = Instance.new("Model")
	room.Name = "TestRoom"

	-- Top platform
	addPart(room, "TopPlatform", Vector3.new(40, 1, 40), CFrame.new(0, 12, 0), ROAD_COLOR)

	-- Ramp from the top platform down to the flat run
	local rampTop = Vector3.new(0, 12, -20)
	local rampBottom = Vector3.new(0, 0, -115)
	addRamp(room, "Ramp", rampTop, rampBottom, 20)

	-- Flat run and the turn
	addPart(room, "FlatRun", Vector3.new(60, 1, 100), CFrame.new(0, 0, -165), ROAD_COLOR)
	addPart(room, "TurnRun", Vector3.new(90, 1, 50), CFrame.new(75, 0, -190), ROAD_COLOR)

	addLaterSections(room)

	-- Walls with a gap to the right for the turn.
	addPart(room, "BackWall", Vector3.new(152, 8, 2), CFrame.new(44, 4, -216), WALL_COLOR)
	addPart(room, "LeftWall", Vector3.new(2, 8, 100), CFrame.new(-31, 4, -165), WALL_COLOR)
	addPart(room, "RightWall", Vector3.new(2, 8, 50), CFrame.new(31, 4, -140), WALL_COLOR)
	addPart(room, "TurnWall", Vector3.new(90, 8, 2), CFrame.new(75, 4, -164), WALL_COLOR)

	-- Crates to smash through
	for row = 0, 2 do
		for column = -1, 1 do
			addCrate(room, Vector3.new(column * 7, 2, -150 - row * 8))
		end
	end

	-- A solid pillar for testing crashes
	addPart(room, "Pillar", Vector3.new(4, 8, 4), CFrame.new(15, 4, -130), WALL_COLOR)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(0, 12.6, 16)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawn.Parent = room

	room.Parent = workspace
	return room
end

return TestRoom
