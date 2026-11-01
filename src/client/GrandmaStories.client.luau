--!strict
-- Every so often, Grandma starts a story while she's riding.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GrandmaReactions = require(script.Parent.GrandmaReactions)

local player = Players.LocalPlayer
local chair = workspace:WaitForChild(player.Name .. "_Chair") :: Model
local chassis = chair:WaitForChild("Chassis") :: Part
local grandma = chair:WaitForChild("Grandma") :: Model
local head = grandma:WaitForChild("Head") :: Part

local random = Random.new()

while true do
	task.wait(random:NextNumber(Config.StoryMinGap, Config.StoryMaxGap))
	if chassis:GetAttribute("RunState") == "Running" and chassis:GetAttribute("GrandmaSeated") == true then
		GrandmaReactions.tellStory(head)
	end
end
