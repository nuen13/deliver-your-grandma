--!strict
-- Shows Grandma's lines in a speech bubble above her head.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GrandmaLines = require(ReplicatedStorage.Shared.Data.GrandmaLines)

local GrandmaReactions = {}

local random = Random.new()
local lastLineTime = -math.huge
local currentBubble: BillboardGui? = nil

function GrandmaReactions.say(head: BasePart, category: string, ignoreCooldown: boolean?)
	local now = os.clock()
	if not ignoreCooldown and now - lastLineTime < Config.LineCooldown then
		return
	end
	lastLineTime = now

	local lines = (GrandmaLines :: any)[category] :: { string }
	local line = lines[random:NextInteger(1, #lines)]

	if currentBubble then
		currentBubble:Destroy()
	end

	local bubble = Instance.new("BillboardGui")
	bubble.Size = UDim2.fromOffset(280, 70)
	bubble.StudsOffset = Vector3.new(0, 3, 0)
	bubble.AlwaysOnTop = true
	bubble.Adornee = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.new(1, 1, 1)
	label.TextColor3 = Color3.new(0, 0, 0)
	label.Font = Enum.Font.Cartoon
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = line
	label.Parent = bubble

	local corner = Instance.new("UICorner")
	corner.Parent = label

	bubble.Parent = head
	currentBubble = bubble

	task.delay(Config.LineDuration, function()
		if currentBubble == bubble then
			bubble:Destroy()
			currentBubble = nil
		end
	end)
end

return GrandmaReactions
