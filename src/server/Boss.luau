--!strict
-- Mildred sits at the far end of the boss room and throws bingo balls at the chair until every letter is collected.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Boss = {}

type Ball = {
	part: Part,
	velocity: Vector3,
	dieAt: number,
}

export type State = {
	model: Model?,
	frame: CFrame,
	parent: Instance,
	random: Random,
	balls: { Ball },
	nextThrow: number,
}

local BODY_COLOR = Color3.fromRGB(60, 150, 120)
local SKIN_COLOR = Color3.fromRGB(235, 200, 170)
local HAIR_COLOR = Color3.fromRGB(240, 120, 190)
local SCOOTER_COLOR = Color3.fromRGB(200, 40, 60)
local BALL_COLOR = Color3.fromRGB(255, 240, 240)
local SWAY_DISTANCE = 18
local SWAY_SPEED = 0.8
local HAND_HEIGHT = 5

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

function Boss.build(parent: Instance, frame: CFrame, random: Random): State
	local model = Instance.new("Model")
	model.Name = "Mildred"
	local base = addPart(model, "Scooter", Vector3.new(4, 1.5, 6), frame * CFrame.new(0, 1.5, 0), SCOOTER_COLOR)
	addPart(model, "Body", Vector3.new(2.4, 3, 1.6), frame * CFrame.new(0, 3.75, 0), BODY_COLOR)
	addPart(model, "Head", Vector3.new(1.8, 1.8, 1.8), frame * CFrame.new(0, 6.15, 0), SKIN_COLOR)
	addPart(model, "Hair", Vector3.new(2.2, 1, 2.2), frame * CFrame.new(0, 7.3, 0), HAIR_COLOR)
	model.PrimaryPart = base
	model.Parent = parent

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(180, 40)
	billboard.StudsOffset = Vector3.new(0, 8, 0)
	billboard.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = HAIR_COLOR
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.Cartoon
	label.TextScaled = true
	label.Text = "MILDRED"
	label.Parent = billboard
	billboard.Parent = base

	return { model = model, frame = frame, parent = parent, random = random, balls = {}, nextThrow = 0 }
end

local function throwBall(state: State, from: Vector3, position: Vector3, velocity: Vector3, now: number)
	local distance = (position - from).Magnitude
	local flightTime = distance / Config.BossBallSpeed
	local spread = Vector3.new(
		state.random:NextNumber(-Config.BossAimSpread, Config.BossAimSpread),
		0,
		state.random:NextNumber(-Config.BossAimSpread, Config.BossAimSpread)
	)
	local target = position + velocity * flightTime * Config.BossAimLead + spread
	local direction = target - from
	if direction.Magnitude < 1 then
		return
	end

	local part = addPart(state.parent, "BingoBall", Vector3.new(3, 3, 3), CFrame.new(from), BALL_COLOR)
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.Neon
	table.insert(state.balls, {
		part = part,
		velocity = direction.Unit * Config.BossBallSpeed,
		dieAt = now + Config.BossBallLifetime,
	})
end

-- Returns true if a ball hit the chair this frame. Balls only get thrown while `active`.
function Boss.update(state: State, dt: number, now: number, position: Vector3, velocity: Vector3, active: boolean, lettersCollected: number): boolean
	local model = state.model
	if not model then
		return false
	end

	local sway = math.sin(now * SWAY_SPEED) * SWAY_DISTANCE
	local mildredFrame = state.frame * CFrame.new(sway, 1.5, 0)
	model:PivotTo(mildredFrame)

	if active and now >= state.nextThrow then
		local interval = Config.BossThrowInterval - lettersCollected * Config.BossThrowIntervalPerLetter
		state.nextThrow = now + interval
		throwBall(state, mildredFrame.Position + Vector3.yAxis * HAND_HEIGHT, position, velocity, now)
	end

	local hit = false
	for index = #state.balls, 1, -1 do
		local ball = state.balls[index]
		local newPosition = ball.part.Position + ball.velocity * dt
		ball.part.CFrame = CFrame.new(newPosition)
		if active and (newPosition - position).Magnitude <= Config.BossBallHitRadius then
			hit = true
			ball.dieAt = 0
		end
		if now >= ball.dieAt then
			ball.part:Destroy()
			table.remove(state.balls, index)
		end
	end
	return hit
end

function Boss.defeat(state: State)
	if state.model then
		state.model:Destroy()
		state.model = nil
	end
	for _, ball in state.balls do
		ball.part:Destroy()
	end
	table.clear(state.balls)
end

return Boss
