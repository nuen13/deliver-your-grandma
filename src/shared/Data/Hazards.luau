--!strict
-- What each hazard does when it catches the chair. Timings are in Config, placement is in Rooms.
-- effect: "bump" costs some Patience, "throw" throws Grandma out. `surface` changes how the chair drives.
-- line: the GrandmaLines category she shouts.

export type Hazard = {
	effect: string?,
	surface: string?,
	line: string?,
}

local Hazards: { [string]: Hazard } = {
	Cat = { effect = "bump", line = "Cat" },
	Sweeper = { effect = "throw", line = "Sweeper" },
	Piano = { effect = "throw", line = "Piano" },
	Oil = { surface = "Oil" },
	Mud = { surface = "Mud" },
}

return Hazards
