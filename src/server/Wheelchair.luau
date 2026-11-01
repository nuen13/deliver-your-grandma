--!strict
-- Builds the wheelchair. Only the Chassis collides and has mass; everything else is welded decoration.

local Wheelchair = {}

local FRAME_COLOR = Color3.fromRGB(60, 60, 70)
local SEAT_COLOR = Color3.fromRGB(170, 40, 50)
local WHEEL_COLOR = Color3.fromRGB(25, 25, 25)

local function addDetail(model: Model, chassis: Part, name: string, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.CFrame = chassis.CFrame * offset
	part.Color = color
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CollisionGroup = "Chair"
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = chassis
	weld.Part1 = part
	weld.Parent = part
end

function Wheelchair.build(name: string, cframe: CFrame): Model
	local model = Instance.new("Model")
	model.Name = name

	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(3, 1, 4)
	chassis.CFrame = cframe
	chassis.Color = FRAME_COLOR
	chassis.CollisionGroup = "Chair"
	-- Heavy and slippery: it stays low, and rolls downhill by itself.
	chassis.CustomPhysicalProperties = PhysicalProperties.new(3, 0.03, 0.1, 100, 1)
	chassis.TopSurface = Enum.SurfaceType.Smooth
	chassis.BottomSurface = Enum.SurfaceType.Smooth
	chassis.Parent = model
	model.PrimaryPart = chassis

	addDetail(model, chassis, "Seat", Vector3.new(2.6, 0.4, 2.6), CFrame.new(0, 1, 0), SEAT_COLOR)
	addDetail(model, chassis, "Back", Vector3.new(2.6, 2.6, 0.4), CFrame.new(0, 2.2, 1.3), SEAT_COLOR)
	addDetail(model, chassis, "Handle", Vector3.new(2.6, 0.25, 0.25), CFrame.new(0, 3.5, 1.9), FRAME_COLOR)

	addDetail(model, chassis, "WheelLeft", Vector3.new(0.4, 3, 3), CFrame.new(-1.8, 0.5, 0.6), WHEEL_COLOR, Enum.PartType.Cylinder)
	addDetail(model, chassis, "WheelRight", Vector3.new(0.4, 3, 3), CFrame.new(1.8, 0.5, 0.6), WHEEL_COLOR, Enum.PartType.Cylinder)
	addDetail(model, chassis, "CasterLeft", Vector3.new(0.3, 1.2, 1.2), CFrame.new(-1.2, -0.3, -1.7), WHEEL_COLOR, Enum.PartType.Cylinder)
	addDetail(model, chassis, "CasterRight", Vector3.new(0.3, 1.2, 1.2), CFrame.new(1.2, -0.3, -1.7), WHEEL_COLOR, Enum.PartType.Cylinder)

	-- Invisible rollers, slightly deeper than the Chassis, lift it over small seams and lips.
	for _, rollerZ in { -1.9, 1.9 } do
		local roller = Instance.new("Part")
		roller.Name = "Roller"
		roller.Shape = Enum.PartType.Cylinder
		roller.Size = Vector3.new(3, 1.3, 1.3)
		roller.CFrame = chassis.CFrame * CFrame.new(0, 0, rollerZ)
		roller.Transparency = 1
		roller.Massless = true
		roller.CanQuery = false
		roller.CanTouch = false
		roller.CollisionGroup = "Chair"
		roller.CustomPhysicalProperties = PhysicalProperties.new(0.1, 0.03, 0.1, 100, 1)
		roller.Parent = model

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = chassis
		weld.Part1 = roller
		weld.Parent = roller
	end

	-- Where the pusher stands
	local pusherPoint = Instance.new("Attachment")
	pusherPoint.Name = "PusherPoint"
	pusherPoint.Position = Vector3.new(0, 0, 4.5)
	pusherPoint.Parent = chassis

	model.Parent = workspace
	return model
end

return Wheelchair
