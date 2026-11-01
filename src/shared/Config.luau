--!strict
-- Every value you might tune while playtesting. Speeds are in studs per second.

return {
	-- Pushing
	TopSpeed = 26,
	SprintTopSpeed = 40, -- while holding Shift
	SprintAcceleration = 30,
	ReverseSpeed = 10,
	MaxRollSpeed = 45, -- hills can push the chair past TopSpeed, up to this
	Acceleration = 18,
	BrakeDeceleration = 40,
	RollingDrag = 4, -- how quickly the chair slows with no input
	TurnRate = 2.2, -- radians per second at full steering
	MinTurnFactor = 0.35, -- share of TurnRate kept when almost stopped
	TurnFullSpeed = 10, -- speed at which steering reaches full strength
	SidewaysGrip = 5, -- higher means less drifting

	-- Stability
	GroundAlignStrength = 8, -- how firmly the chair follows the slope under it
	AirAlignStrength = 2.5, -- how firmly it levels out during a jump
	MaxStickUpSpeed = 2, -- limits bouncing away from the ground

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

	-- Patience: Grandma's health for the run
	MaxPatience = 100,
	FallPatienceCost = 25,
	BumpPatienceCost = 5,
	BumpCostCooldown = 1, -- bumps closer together than this cost nothing extra

	-- Grandma's babbling voice: one short sound per syllable
	VoiceSoundId = "rbxasset://sounds/oof.ogg",
	VoiceVolume = 0.8,
	VoiceShoutVolume = 1.2,
	VoiceMinPitch = 2.3,
	VoiceMaxPitch = 3.3,
	VoiceSyllableWobble = 0.35, -- how much pitch jumps within a word
	VoiceSyllableGap = 0.07, -- seconds between sounds
	VoiceWordPause = 0.1, -- extra pause between words
	VoiceLettersPerSyllable = 3,

	-- Stories she tells at random while riding
	StoryMinGap = 20, -- seconds between stories
	StoryMaxGap = 45,
	StoryLineDuration = 3,

	-- Boost pickups
	BoostChance = 0.7, -- chance that each boost spot in a room is filled
	BoostPickupRadius = 6,
	BoostDuration = 3,
	BoostTopSpeed = 55,
	BoostAcceleration = 60,
	BoostFieldOfViewKick = 15,

	-- Upgrade cards
	UpgradeCardsOffered = 3, -- cards to pick from after each room

	-- Bingo Tickets: the saved currency
	TicketsPerRoom = 5,
	TicketsWinBonus = 30,
	TicketsCleanBonus = 15, -- for winning without dropping her
	AutosaveInterval = 30,

	-- Hazards
	HazardHitCooldown = 1.5,
	CatSpeed = 1.6, -- radians per second along its path
	CatHitRadius = 4.5,
	SweeperSpeed = 1.1, -- radians per second
	SweeperHitWidth = 2.5,
	PianoPeriod = 4, -- seconds per drop, including the warning
	PianoWarnTime = 1.6,
	PianoFallTime = 0.4, -- the last part of the warning
	PianoSlamTime = 0.2, -- how long the landing can hit
	PianoHitRadius = 6,
	PianoDropHeight = 45,
	OilGripFactor = 0.08, -- share of SidewaysGrip kept on oil
	MudTopSpeed = 14,
	MudDrag = 60,

	-- Mildred, the boss
	BossThrowInterval = 1.6,
	BossThrowIntervalPerLetter = 0.2, -- she panics as you collect letters
	BossBallSpeed = 55,
	BossBallLifetime = 6,
	BossBallHitRadius = 4.5,
	BossBallPatienceCost = 10,
	BossAimLead = 0.7, -- how far ahead of the chair she aims, as a share of its movement
	BossAimSpread = 10,
	BossLetterRadius = 7,

	-- Sound effects, using sounds built into Roblox
	Sfx = {
		Click = "rbxasset://sounds/clickfast.wav",
		Boost = "rbxasset://sounds/electronicpingshort.wav",
		Letter = "rbxasset://sounds/electronicpingshort.wav",
		Crash = "rbxasset://sounds/collide.wav",
		Win = "rbxasset://sounds/victory.wav",
		Lose = "rbxasset://sounds/bass.wav",
	},
	SfxVolume = 0.7,

	-- Gamepad
	GamepadDeadzone = 0.2,

	-- First-person camera
	CameraOffset = Vector3.new(0, 5.2, 4), -- from the Chassis: up, and behind the handle
	CameraDownTilt = 0.22, -- higher looks further down at Grandma
	CameraTurnSmoothing = 10, -- higher follows the chair's turns more tightly
	CameraFieldOfView = 80,

	-- Other
	LineDuration = 2.5,
	LineCooldown = 2,
	MaxPusherDistance = 14, -- the pusher teleports back beyond this
	FallResetDepth = 40, -- how far below the current room's entrance counts as falling off
	RoomsPerRun = 5, -- random rooms before the boss
}
