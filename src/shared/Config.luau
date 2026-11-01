--!strict
-- Every value you might tune while playtesting. Speeds are in studs per second.

return {
	-- Pushing
	TopSpeed = 26,
	ReverseSpeed = 10,
	MaxRollSpeed = 45, -- hills can push the chair past TopSpeed, up to this
	Acceleration = 18,
	BrakeDeceleration = 40,
	RollingDrag = 4, -- how quickly the chair slows with no input
	TurnRate = 2.2, -- radians per second at full steering
	MinTurnFactor = 0.35, -- share of TurnRate kept when almost stopped
	TurnFullSpeed = 10, -- speed at which steering reaches full strength
	SidewaysGrip = 5, -- higher means less drifting

	-- Tipping on turns
	SafeTurnForce = 34, -- speed x turn rate that's safe indefinitely
	TipBuildup = 20, -- higher means it takes longer to tip
	TipDecay = 1.5, -- how quickly the tip meter recovers per second
	TipRollStrength = 0.12, -- how much the chair visibly leans

	-- What throws Grandma out
	CrashSpeedDrop = 16, -- speed lost in one frame
	BumpSpeedDrop = 7, -- enough for a complaint, not a fall
	MaxTiltDegrees = 55,

	-- After she falls
	LaunchUpSpeed = 35,
	LaunchSpeedMultiplier = 1.1,
	MaxLaunchSpeed = 120,
	ReseatDelay = 4,

	-- First-person camera
	CameraOffset = Vector3.new(0, 5.2, 4), -- from the Chassis: up, and behind the handle
	CameraDownTilt = 0.22, -- higher looks further down at Grandma
	CameraTurnSmoothing = 10, -- higher follows the chair's turns more tightly
	CameraFieldOfView = 80,

	-- Other
	LineDuration = 2.5,
	LineCooldown = 2,
	MaxPusherDistance = 14, -- the pusher teleports back beyond this
	FallResetHeight = -30,
}
