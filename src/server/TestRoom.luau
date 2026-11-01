--!strict
-- The test course: a top platform, a long ramp, a flat run, and a sharp right turn.

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

function TestRoom.build(): Model
	local room = Instance.new("Model")
	room.Name = "TestRoom"

	-- Top platform
	addPart(room, "TopPlatform", Vector3.new(40, 1, 40), CFrame.new(0, 12, 0), ROAD_COLOR)

	-- Ramp from the top platform down to the flat run
	local rampTop = Vector3.new(0, 12, -20)
	local rampBottom = Vector3.new(0, 0, -115)
	local rampLength = (rampBottom - rampTop).Magnitude
	addPart(
		room,
		"Ramp",
		Vector3.new(20, 1, rampLength + 1),
		-- Sits just below the platform and only overlaps at the bottom, so there's no lip to catch on.
		CFrame.lookAt((rampTop + rampBottom) / 2, rampBottom) * CFrame.new(0, -0.01, -0.5),
		RAMP_COLOR
	)

	-- Flat run and the turn
	addPart(room, "FlatRun", Vector3.new(60, 1, 100), CFrame.new(0, 0, -165), ROAD_COLOR)
	addPart(room, "TurnRun", Vector3.new(90, 1, 50), CFrame.new(75, 0, -190), ROAD_COLOR)

	-- Walls with a gap to the right for the turn. The far end of TurnRun is open.
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
