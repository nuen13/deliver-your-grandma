--!strict
-- Upgrade cards as data. Adding a card here is enough for it to appear in runs and in the shop.
-- `multiply` scales a stat for the rest of the run, and picking a card twice stacks. `heal` restores Patience once.
-- `cost` is the Bingo Tickets needed to unlock the card. Without one, it's available from the start.
-- Stats used by the wheelchair: Speed, Acceleration, BoostSpeed, BoostTime, BrakePower, TurnRate, TurnSafety, Grip, Toughness.
-- Stats used by the server: Damage, FallDamage, BumpDamage, HazardDamage, TicketBonus, ReseatTime, BoostRadius.

export type Upgrade = {
	id: string,
	name: string,
	description: string,
	multiply: { [string]: number }?,
	heal: number?,
	cost: number?,
}

local Upgrades: { Upgrade } = {
	{
		id = "BiggerWheels",
		name = "Bigger Wheels",
		description = "Top speed +15%. Stolen from a shopping cart.",
		multiply = { Speed = 1.15 },
	},
	{
		id = "Seatbelt",
		name = "Seatbelt",
		description = "Takes a 40% harder crash to throw her out. It's a bathrobe cord.",
		multiply = { Toughness = 1.4 },
	},
	{
		id = "ThickCushion",
		name = "Thick Cushion",
		description = "She loses 30% less Patience. Mostly old cat fur.",
		multiply = { Damage = 0.7 },
	},
	{
		id = "HardCandy",
		name = "Hard Candy",
		description = "Restores 40 Patience. Older than you are.",
		heal = 40,
	},
	{
		id = "PruneJuice",
		name = "Prune Juice",
		description = "Boosts last 50% longer. Don't ask how it works.",
		multiply = { BoostTime = 1.5 },
	},
	{
		id = "TrainingWheels",
		name = "Training Wheels",
		description = "Take turns 35% harder before tipping. Very embarrassing.",
		multiply = { TurnSafety = 1.35 },
	},
	{
		id = "OrthopedicSneakers",
		name = "Orthopedic Sneakers",
		description = "You push 25% harder. They squeak with confidence.",
		multiply = { Acceleration = 1.25 },
	},
	{
		id = "PowerSteering",
		name = "Power Steering",
		description = "Steer 20% faster. A wooden spoon taped to the wheel.",
		multiply = { TurnRate = 1.2 },
	},
	{
		id = "CementBrakes",
		name = "Cement Brakes",
		description = "Brake 50% harder. Grandma's own recipe.",
		multiply = { BrakePower = 1.5 },
		cost = 20,
	},
	{
		id = "StickyTires",
		name = "Sticky Tires",
		description = "50% less sliding. Covered in butterscotch.",
		multiply = { Grip = 1.5 },
		cost = 25,
	},
	{
		id = "FridgeMagnet",
		name = "Fridge Magnet",
		description = "Grab boosts from 75% further away. Souvenir from Branson.",
		multiply = { BoostRadius = 1.75 },
		cost = 30,
	},
	{
		id = "SmellingSalts",
		name = "Smelling Salts",
		description = "She climbs back in twice as fast, and twice as angry.",
		multiply = { ReseatTime = 0.5 },
		cost = 35,
	},
	{
		id = "KnittedHelmet",
		name = "Knitted Helmet",
		description = "Falling out costs 40% less Patience. Offers no real protection.",
		multiply = { FallDamage = 0.6 },
		cost = 40,
	},
	{
		id = "PersonalInjuryLawyer",
		name = "Injury Lawyer",
		description = "Bumps cost 50% less Patience. He's riding in the basket.",
		multiply = { BumpDamage = 0.5 },
		cost = 45,
	},
	{
		id = "HazardPay",
		name = "Hazard Pay",
		description = "Cats, pianos, and bingo balls cost 40% less Patience.",
		multiply = { HazardDamage = 0.6 },
		cost = 50,
	},
	{
		id = "SecondBreakfast",
		name = "Second Breakfast",
		description = "Restores 75 Patience. She's in a great mood. For now.",
		heal = 75,
		cost = 55,
	},
	{
		id = "RocketSlippers",
		name = "Rocket Slippers",
		description = "Boosts go 20% faster. The warranty is void.",
		multiply = { BoostSpeed = 1.2 },
		cost = 60,
	},
	{
		id = "HipReplacement",
		name = "Hip Replacement",
		description = "10% faster, and 20% harder to throw out. Titanium, baby.",
		multiply = { Speed = 1.1, Toughness = 1.2 },
		cost = 70,
	},
	{
		id = "LuckyDentures",
		name = "Lucky Dentures",
		description = "Earn 50% more Bingo Tickets. They bite if you check.",
		multiply = { TicketBonus = 1.5 },
		cost = 80,
	},
	{
		id = "VitaminGummies",
		name = "Vitamin Gummies",
		description = "Restores 25 Patience, and she loses 15% less. Sold by a man in a van.",
		multiply = { Damage = 0.85 },
		heal = 25,
		cost = 100,
	},
}

return Upgrades
