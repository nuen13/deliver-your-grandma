--!strict
-- Shows Grandma's lines in a speech bubble above her head, with a squeaky gibberish voice.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GrandmaLines = require(ReplicatedStorage.Shared.Data.GrandmaLines)
local GrandmaStories = require(ReplicatedStorage.Shared.Data.GrandmaStories)

local GrandmaReactions = {}

local random = Random.new()
local lastLineTime = -math.huge
local currentBubble: BillboardGui? = nil
local babbleToken = 0 -- a new line cuts off the one before it
local storyToken = 0 -- any other line cuts off a story
local storyActive = false

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

local function babble(head: BasePart, line: string, duration: number)
	babbleToken += 1
	local token = babbleToken
	local voice = getVoice(head)
	voice.Volume = if line == line:upper() then Config.VoiceShoutVolume else Config.VoiceVolume

	task.spawn(function()
		local stopTime = os.clock() + duration
		for word in line:gmatch("%S+") do
			local wordPitch = random:NextNumber(Config.VoiceMinPitch, Config.VoiceMaxPitch)
			for _ = 1, math.ceil(#word / Config.VoiceLettersPerSyllable) do
				if babbleToken ~= token or os.clock() > stopTime then
					return
				end
				local wobble = random:NextNumber(-Config.VoiceSyllableWobble, Config.VoiceSyllableWobble)
				voice.PlaybackSpeed = wordPitch + wobble
				voice.TimePosition = 0
				voice:Play()
				task.wait(Config.VoiceSyllableGap)
			end
			task.wait(Config.VoiceWordPause)
		end
	end)
end

local function showLine(head: BasePart, line: string, duration: number)
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
	babble(head, line, duration)

	task.delay(duration, function()
		if currentBubble == bubble then
			bubble:Destroy()
			currentBubble = nil
		end
	end)
end

function GrandmaReactions.say(head: BasePart, category: string, ignoreCooldown: boolean?)
	local now = os.clock()
	if not ignoreCooldown and now - lastLineTime < Config.LineCooldown then
		return
	end
	lastLineTime = now
	storyToken += 1
	storyActive = false

	local lines = (GrandmaLines :: any)[category] :: { string }
	showLine(head, lines[random:NextInteger(1, #lines)], Config.LineDuration)
end

function GrandmaReactions.tellStory(head: BasePart)
	if storyActive then
		return
	end
	storyToken += 1
	local token = storyToken
	storyActive = true

	local story = GrandmaStories[random:NextInteger(1, #GrandmaStories)]
	task.spawn(function()
		for _, line in story do
			if storyToken ~= token then
				return
			end
			showLine(head, line, Config.StoryLineDuration)
			task.wait(Config.StoryLineDuration)
		end
		if storyToken == token then
			storyActive = false
		end
	end)
end

return GrandmaReactions
