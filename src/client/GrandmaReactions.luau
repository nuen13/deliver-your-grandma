--!strict
-- Shows Grandma's lines in a speech bubble above her head, with a babbling voice.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GrandmaLines = require(ReplicatedStorage.Shared.Data.GrandmaLines)

local GrandmaReactions = {}

local random = Random.new()
local lastLineTime = -math.huge
local currentBubble: BillboardGui? = nil
local babbleToken = 0 -- a new line cuts off the one before it

local function getVoice(head: BasePart): Sound
	local voice = head:FindFirstChild("Voice") :: Sound?
	if voice then
		return voice
	end
	local newVoice = Instance.new("Sound")
	newVoice.Name = "Voice"
	newVoice.SoundId = Config.VoiceSoundId
	newVoice.Parent = head
	return newVoice
end

local function babble(head: BasePart, line: string)
	babbleToken += 1
	local token = babbleToken
	local voice = getVoice(head)
	voice.Volume = if line == line:upper() then Config.VoiceShoutVolume else Config.VoiceVolume

	local syllables = math.max(math.ceil(#line / Config.VoiceLettersPerSyllable), 1)
	syllables = math.min(syllables, math.floor(Config.LineDuration / Config.VoiceSyllableGap))

	task.spawn(function()
		for _ = 1, syllables do
			if babbleToken ~= token then
				return
			end
			voice.PlaybackSpeed = random:NextNumber(Config.VoiceMinPitch, Config.VoiceMaxPitch)
			voice.TimePosition = 0
			voice:Play()
			task.wait(Config.VoiceSyllableGap)
		end
	end)
end

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
	babble(head, line)

	task.delay(Config.LineDuration, function()
		if currentBubble == bubble then
			bubble:Destroy()
			currentBubble = nil
		end
	end)
end

return GrandmaReactions
