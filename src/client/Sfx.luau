--!strict
-- Plays the short sound effects named in Config.Sfx.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)

local Sfx = {}

local sounds: { [string]: Sound } = {}

function Sfx.play(name: string)
	local sound = sounds[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = (Config.Sfx :: any)[name]
		sound.Volume = Config.SfxVolume
		sound.Parent = SoundService
		sounds[name] = sound
	end
	sound.TimePosition = 0
	sound:Play()
end

return Sfx
