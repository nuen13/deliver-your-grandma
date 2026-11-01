--!strict
-- Rooms as data. Each room starts at (0, 0, 0) heading toward -Z, with the road's center at y = 0.
-- `exit` is where the next room connects, and which way it heads.
-- Keep the drop within a room under Config.FallResetDepth.
-- Part kinds: block, ramp (high and low are road centers), crate, boost (a spot that may hold a pickup).

local function block(size: Vector3, at: Vector3, color: string)
	return { kind = "block", size = size, at = at, color = color }
end

local function ramp(high: Vector3, low: Vector3, width: number)
	return { kind = "ramp", high = high, low = low, width = width }
end

local function crate(at: Vector3)
	return { kind = "crate", at = at }
end

local function boost(at: Vector3)
	return { kind = "boost", at = at }
end

local TURN_RIGHT = CFrame.Angles(0, -math.pi / 2, 0)
local TURN_LEFT = CFrame.Angles(0, math.pi / 2, 0)

local Rooms = {}

-- Always first and last. The rest are picked at random.
Rooms.Start = {
	-- The player's start is at z = 12, so the road continues behind the entrance.
	parts = {
		block(Vector3.new(40, 1, 40), Vector3.new(0, 0, 20), "Road"),
	},
	exit = CFrame.new(0, 0, 0),
}

Rooms.Finish = {
	parts = {
		block(Vector3.new(40, 1, 60), Vector3.new(0, 0, -30), "Road"),
		block(Vector3.new(44, 10, 2), Vector3.new(0, 5, -61), "Wall"),
		block(Vector3.new(2, 10, 60), Vector3.new(-21, 5, -30), "Wall"),
		block(Vector3.new(2, 10, 60), Vector3.new(21, 5, -30), "Wall"),
	},
	exit = CFrame.new(0, 0, -60),
}

Rooms.Pool = {
	Hill = {
		parts = {
			ramp(Vector3.new(0, 0, 0), Vector3.new(0, -12, -95), 20),
			block(Vector3.new(30, 1, 30), Vector3.new(0, -12, -110), "Road"),
			block(Vector3.new(4, 8, 4), Vector3.new(8, -8, -112), "Wall"),
			boost(Vector3.new(0, -3.3, -50)),
			boost(Vector3.new(-6, -9, -105)),
		},
		exit = CFrame.new(0, -12, -125),
	},

	SharpTurn = {
		parts = {
			block(Vector3.new(60, 1, 100), Vector3.new(0, 0, -50), "Road"),
			block(Vector3.new(90, 1, 50), Vector3.new(75, 0, -75), "Road"),
			block(Vector3.new(2, 8, 100), Vector3.new(-31, 4, -50), "Wall"),
			block(Vector3.new(2, 8, 50), Vector3.new(31, 4, -25), "Wall"),
			block(Vector3.new(90, 8, 2), Vector3.new(75, 4, -49), "Wall"),
			block(Vector3.new(152, 8, 2), Vector3.new(44, 4, -101), "Wall"),
			crate(Vector3.new(-7, 2, -40)),
			crate(Vector3.new(0, 2, -40)),
			crate(Vector3.new(7, 2, -40)),
			crate(Vector3.new(-7, 2, -48)),
			crate(Vector3.new(0, 2, -48)),
			crate(Vector3.new(7, 2, -48)),
			boost(Vector3.new(0, 3, -20)),
			boost(Vector3.new(70, 3, -75)),
		},
		exit = CFrame.new(120, 0, -75) * TURN_RIGHT,
	},

	Slalom = {
		parts = {
			block(Vector3.new(40, 1, 180), Vector3.new(0, 0, -90), "Road"),
			block(Vector3.new(2, 8, 180), Vector3.new(-21, 4, -90), "Wall"),
			block(Vector3.new(2, 8, 180), Vector3.new(21, 4, -90), "Wall"),
			block(Vector3.new(4, 8, 4), Vector3.new(-10, 4, -30), "Wall"),
			block(Vector3.new(4, 8, 4), Vector3.new(10, 4, -70), "Wall"),
			block(Vector3.new(4, 8, 4), Vector3.new(-10, 4, -110), "Wall"),
			block(Vector3.new(4, 8, 4), Vector3.new(10, 4, -150), "Wall"),
			boost(Vector3.new(10, 3, -30)),
			boost(Vector3.new(-10, 3, -70)),
			boost(Vector3.new(10, 3, -110)),
		},
		exit = CFrame.new(0, 0, -180),
	},

	Bridge = {
		parts = {
			block(Vector3.new(40, 1, 20), Vector3.new(0, 0, -10), "Road"),
			block(Vector3.new(12, 1, 80), Vector3.new(0, 0, -60), "Ramp"),
			block(Vector3.new(40, 1, 20), Vector3.new(0, 0, -110), "Road"),
			boost(Vector3.new(0, 3, -60)),
		},
		exit = CFrame.new(0, 0, -120),
	},

	SpeedBumps = {
		parts = {
			ramp(Vector3.new(0, 0, 0), Vector3.new(0, -12, -100), 20),
			block(Vector3.new(30, 1, 100), Vector3.new(0, -12, -150), "Road"),
			block(Vector3.new(30, 0.6, 3), Vector3.new(0, -11.6, -125), "Wall"),
			block(Vector3.new(30, 0.6, 3), Vector3.new(0, -11.6, -145), "Wall"),
			block(Vector3.new(30, 0.6, 3), Vector3.new(0, -11.6, -165), "Wall"),
			boost(Vector3.new(0, -1.8, -40)),
			boost(Vector3.new(8, -9, -135)),
		},
		exit = CFrame.new(0, -12, -200),
	},

	Jump = {
		parts = {
			block(Vector3.new(30, 1, 60), Vector3.new(0, 0, -30), "Road"),
			ramp(Vector3.new(0, 4, -80), Vector3.new(0, 0, -60), 20),
			block(Vector3.new(40, 1, 60), Vector3.new(0, -8, -120), "Road"),
			boost(Vector3.new(0, 3, -40)),
			boost(Vector3.new(8, -5, -125)),
		},
		exit = CFrame.new(0, -8, -150),
	},

	CrateCorner = {
		parts = {
			block(Vector3.new(60, 1, 60), Vector3.new(0, 0, -30), "Road"),
			block(Vector3.new(2, 8, 60), Vector3.new(31, 4, -30), "Wall"),
			block(Vector3.new(62, 8, 2), Vector3.new(0, 4, -61), "Wall"),
			crate(Vector3.new(-8, 2, -22)),
			crate(Vector3.new(-16, 2, -30)),
			crate(Vector3.new(-8, 2, -38)),
			crate(Vector3.new(-16, 2, -46)),
			boost(Vector3.new(0, 3, -10)),
			boost(Vector3.new(-16, 3, -12)),
		},
		exit = CFrame.new(-30, 0, -30) * TURN_LEFT,
	},
}

return Rooms
