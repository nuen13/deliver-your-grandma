--!strict
-- A blocky Grandma. Seated, she's welded to the chair; ejected, she becomes a ragdoll held together by ball sockets.

local Grandma = {}

local DRESS_COLOR = Color3.fromRGB(150, 90, 170)
local SKIN_COLOR = Color3.fromRGB(235, 200, 170)
local HAIR_COLOR = Color3.fromRGB(215, 215, 220)

type BodyPart = {
	name: string,
	size: Vector3,
	offset: CFrame, -- from the chair's Chassis while seated
	joint: Vector3?, -- where it connects to the Torso, from the Chassis
	color: Color3,
}

local BODY: { BodyPart } = {
	{ name = "Torso", size = Vector3.new(1.8, 2, 1), offset = CFrame.new(0, 2.2, 0.5), color = DRESS_COLOR },
	{ name = "Head", size = Vector3.new(1.2, 1.2, 1.2), offset = CFrame.new(0, 3.8, 0.5), joint = Vector3.new(0, 3.2, 0.5), color = SKIN_COLOR },
	{ name = "LeftArm", size = Vector3.new(0.6, 1.8, 0.6), offset = CFrame.new(-1.25, 2.3, 0.4), joint = Vector3.new(-1.1, 3.1, 0.5), color = SKIN_COLOR },
	{ name = "RightArm", size = Vector3.new(0.6, 1.8, 0.6), offset = CFrame.new(1.25, 2.3, 0.4), joint = Vector3.new(1.1, 3.1, 0.5), color = SKIN_COLOR },
	{ name = "LeftLeg", size = Vector3.new(0.7, 0.7, 2), offset = CFrame.new(-0.5, 1.55, -0.9), joint = Vector3.new(-0.5, 1.55, 0.1), color = DRESS_COLOR },
	{ name = "RightLeg", size = Vector3.new(0.7, 0.7, 2), offset = CFrame.new(0.5, 1.55, -0.9), joint = Vector3.new(0.5, 1.55, 0.1), color = DRESS_COLOR },
}

local function getPart(model: Model, name: string): Part
	return model:FindFirstChild(name) :: Part
end

local function addHairBun(model: Model, head: Part)
	local bun = Instance.new("Part")
	bun.Name = "HairBun"
	bun.Shape = Enum.PartType.Ball
	bun.Size = Vector3.new(0.8, 0.8, 0.8)
	bun.CFrame = head.CFrame * CFrame.new(0, 0.7, 0.3)
	bun.Color = HAIR_COLOR
	bun.CanCollide = false
	bun.CanQuery = false
	bun.CanTouch = false
	bun.Massless = true
	bun.CollisionGroup = "Grandma"
	bun.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = bun
	weld.Parent = bun
end

function Grandma.seat(model: Model, chassis: Part)
	local seatWelds = model:FindFirstChild("SeatWelds") :: Folder
	seatWelds:ClearAllChildren()

	for _, body in BODY do
		local part = getPart(model, body.name)
		part.Massless = true
		part.CanCollide = false
		part.CFrame = chassis.CFrame * body.offset
		part.AssemblyLinearVelocity = Vector3.zero
		part.AssemblyAngularVelocity = Vector3.zero

		local socket = part:FindFirstChildOfClass("BallSocketConstraint")
		if socket then
			socket.Enabled = false
		end

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = chassis
		weld.Part1 = part
		weld.Parent = seatWelds
	end
end

function Grandma.eject(model: Model, launch: Vector3)
	local seatWelds = model:FindFirstChild("SeatWelds") :: Folder
	seatWelds:ClearAllChildren()

	for _, body in BODY do
		local part = getPart(model, body.name)
		part.Massless = false
		part.CanCollide = true

		local socket = part:FindFirstChildOfClass("BallSocketConstraint")
		if socket then
			socket.Enabled = true
		end

		part:SetNetworkOwner(nil)
		part.AssemblyLinearVelocity = launch
	end
end

function Grandma.build(parent: Model, chassis: Part): Model
	local model = Instance.new("Model")
	model.Name = "Grandma"

	local seatWelds = Instance.new("Folder")
	seatWelds.Name = "SeatWelds"
	seatWelds.Parent = model

	for _, body in BODY do
		local part = Instance.new("Part")
		part.Name = body.name
		part.Size = body.size
		part.CFrame = chassis.CFrame * body.offset
		part.Color = body.color
		part.CollisionGroup = "Grandma"
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
	end

	local torso = getPart(model, "Torso")
	for _, body in BODY do
		local joint = body.joint
		if joint then
			local part = getPart(model, body.name)
			local jointFrame = chassis.CFrame * CFrame.new(joint)

			local torsoPoint = Instance.new("Attachment")
			torsoPoint.Name = body.name .. "Joint"
			torsoPoint.CFrame = torso.CFrame:ToObjectSpace(jointFrame)
			torsoPoint.Parent = torso

			local partPoint = Instance.new("Attachment")
			partPoint.Name = "Joint"
			partPoint.CFrame = part.CFrame:ToObjectSpace(jointFrame)
			partPoint.Parent = part

			local socket = Instance.new("BallSocketConstraint")
			socket.Attachment0 = torsoPoint
			socket.Attachment1 = partPoint
			socket.Enabled = false
			socket.Parent = part
		end
	end

	addHairBun(model, getPart(model, "Head"))

	model.Parent = parent
	Grandma.seat(model, chassis)
	return model
end

return Grandma
