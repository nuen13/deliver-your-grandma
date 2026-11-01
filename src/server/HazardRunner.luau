--!strict
-- Builds hazards and moves them. Hazards are anchored and don't collide: they're checked by position,
-- so they can't knock the chair around in ways the crash detection would misread.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local HazardRunner = {}

export type Hazard = {
	kind: string,
	frame: CFrame,
	random: Random,
	phase: number,
	span: number,
	length: number,
	size: Vector2,
	mover: Model?,
	arm: Part?,
	piano: Part?,
	shadow: Part?,
	cycle: number,
	targetX: number,
	slamming: boolean,
	angle: number,
	catX: number,
}

local MAX_HEIGHT_GAP = 12 -- a hazard can't reach a chair this far above or below it

local CAT_COLOR = Color3.fromRGB(235, 140, 50)
local SWEEPER_COLOR = Color3.fromRGB(225, 60, 50)
local POST_COLOR = Color3.fromRGB(60, 60, 70)
local PIANO_COLOR = Color3.fromRGB(20, 20, 25)
local SHADOW_COLOR = Color3.fromRGB(225, 40, 40)
local OIL_COLOR = Color3.fromRGB(15, 15, 25)
local MUD_COLOR = Color3.fromRGB(95, 60, 30)

local function addPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function buildCat(parent: Instance, frame: CFrame): Model
	local cat = Instance.new("Model")
	cat.Name = "Cat"
	local body = addPart(cat, "Body", Vector3.new(4, 2, 2), frame * CFrame.new(0, 2, 0), CAT_COLOR)
	addPart(cat, "Head", Vector3.new(1.8, 1.8, 1.8), frame * CFrame.new(2.4, 3, 0), CAT_COLOR)
	addPart(cat, "EarLeft", Vector3.new(0.5, 0.8, 0.5), frame * CFrame.new(2.4, 4.2, -0.5), CAT_COLOR)
	addPart(cat, "EarRight", Vector3.new(0.5, 0.8, 0.5), frame * CFrame.new(2.4, 4.2, 0.5), CAT_COLOR)
	addPart(cat, "Tail", Vector3.new(0.4, 2.4, 0.4), frame * CFrame.new(-2, 3.4, 0), CAT_COLOR)
	cat.PrimaryPart = body
	cat.Parent = parent
	return cat
end

function HazardRunner.build(parent: Instance, kind: string, frame: CFrame, options: { [string]: any }, random: Random): Hazard
	local hazard: Hazard = {
		kind = kind,
		frame = frame,
		random = random,
		phase = random:NextNumber(0, math.pi * 2),
		span = options.span or 0,
		length = options.length or 0,
		size = options.size or Vector2.zero,
		mover = nil,
		arm = nil,
		piano = nil,
		shadow = nil,
		cycle = -1,
		targetX = 0,
		slamming = false,
		angle = 0,
		catX = 0,
	}

	if kind == "Cat" then
		hazard.mover = buildCat(parent, frame)
	elseif kind == "Sweeper" then
		addPart(parent, "SweeperPost", Vector3.new(2, 6, 2), frame * CFrame.new(0, 3, 0), POST_COLOR)
		hazard.arm = addPart(parent, "SweeperArm", Vector3.new(hazard.length * 2, 1, 1), frame * CFrame.new(0, 2.5, 0), SWEEPER_COLOR)
	elseif kind == "Piano" then
		hazard.piano = addPart(parent, "Piano", Vector3.new(8, 5, 5), frame * CFrame.new(0, Config.PianoDropHeight, 0), PIANO_COLOR)
		local shadow = addPart(parent, "PianoShadow", Vector3.new(0.2, 12, 12), frame * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.pi / 2), SHADOW_COLOR)
		shadow.Shape = Enum.PartType.Cylinder
		shadow.Material = Enum.Material.Neon
		shadow.Transparency = 1
		hazard.shadow = shadow
	elseif kind == "Oil" or kind == "Mud" then
		local zone = addPart(parent, kind, Vector3.new(hazard.size.X, 0.1, hazard.size.Y), frame * CFrame.new(0, 0.55, 0), if kind == "Oil" then OIL_COLOR else MUD_COLOR)
		zone.Material = if kind == "Oil" then Enum.Material.SmoothPlastic else Enum.Material.Mud
		zone.Reflectance = if kind == "Oil" then 0.3 else 0
	end

	return hazard
end

local function updatePiano(hazard: Hazard, now: number)
	local piano = hazard.piano :: Part
	local shadow = hazard.shadow :: Part
	local clock = now + hazard.phase * Config.PianoPeriod
	local cycle = math.floor(clock / Config.PianoPeriod)
	local time = clock - cycle * Config.PianoPeriod
	if cycle ~= hazard.cycle then
		hazard.cycle = cycle
		hazard.targetX = hazard.random:NextNumber(-hazard.span, hazard.span)
	end

	local target = hazard.frame * CFrame.new(hazard.targetX, 0, 0)
	local warnTime = Config.PianoWarnTime
	local fallStart = warnTime - Config.PianoFallTime
	hazard.slamming = time >= warnTime and time < warnTime + Config.PianoSlamTime

	local height = Config.PianoDropHeight
	if time >= warnTime then
		height = 3
	elseif time >= fallStart then
		local share = (time - fallStart) / Config.PianoFallTime
		height = 3 + (Config.PianoDropHeight - 3) * (1 - share * share)
	end
	piano.CFrame = target * CFrame.new(0, height, 0)
	shadow.CFrame = target * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.pi / 2)
	shadow.Transparency = if time < warnTime then 0.35 else 1
end

function HazardRunner.update(hazard: Hazard, now: number)
	if hazard.kind == "Cat" then
		local position = now * Config.CatSpeed + hazard.phase
		hazard.catX = math.sin(position) * hazard.span
		local facing = if math.cos(position) >= 0 then 0 else math.pi
		local mover = hazard.mover :: Model
		mover:PivotTo(hazard.frame * CFrame.new(hazard.catX, 2, 0) * CFrame.Angles(0, facing, 0))
	elseif hazard.kind == "Sweeper" then
		hazard.angle = now * Config.SweeperSpeed + hazard.phase
		local arm = hazard.arm :: Part
		arm.CFrame = hazard.frame * CFrame.Angles(0, hazard.angle, 0) * CFrame.new(0, 2.5, 0)
	elseif hazard.kind == "Piano" then
		updatePiano(hazard, now)
	end
end

function HazardRunner.isHitting(hazard: Hazard, position: Vector3): boolean
	local localPosition = hazard.frame:PointToObjectSpace(position)
	if math.abs(localPosition.Y) > MAX_HEIGHT_GAP then
		return false
	end

	if hazard.kind == "Cat" then
		local gap = Vector2.new(localPosition.X - hazard.catX, localPosition.Z)
		return gap.Magnitude <= Config.CatHitRadius
	elseif hazard.kind == "Sweeper" then
		local onArm = CFrame.Angles(0, hazard.angle, 0):PointToObjectSpace(localPosition)
		return math.abs(onArm.X) <= hazard.length and math.abs(onArm.Z) <= Config.SweeperHitWidth
	elseif hazard.kind == "Piano" then
		local gap = Vector2.new(localPosition.X - hazard.targetX, localPosition.Z)
		return hazard.slamming and gap.Magnitude <= Config.PianoHitRadius
	elseif hazard.kind == "Oil" or hazard.kind == "Mud" then
		return math.abs(localPosition.X) <= hazard.size.X / 2 and math.abs(localPosition.Z) <= hazard.size.Y / 2
	end
	return false
end

return HazardRunner
