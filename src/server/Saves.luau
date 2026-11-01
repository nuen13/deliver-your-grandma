--!strict
-- Loads and saves each player's progress. If a load fails, nothing is saved for that session,
-- so a brief DataStore outage can't overwrite real progress with an empty profile.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Saves = {}

export type Profile = {
	tickets: number,
	unlocked: { string },
	bestTime: number?,
	wins: number,
}

type Entry = {
	profile: Profile,
	canSave: boolean,
	dirty: boolean,
}

local STORE_NAME = "PlayerProgress_v1"
local LOAD_ATTEMPTS = 3
local RETRY_DELAY = 2

local entries: { [Player]: Entry } = {}
local savesInProgress = 0

local storeOk, store = pcall(function()
	return DataStoreService:GetDataStore(STORE_NAME)
end)

local function keyFor(player: Player): string
	return `player_{player.UserId}`
end

local function cleanProfile(data: any): Profile
	local profile: Profile = { tickets = 0, unlocked = {}, bestTime = nil, wins = 0 }
	if typeof(data) ~= "table" then
		return profile
	end
	if typeof(data.tickets) == "number" then
		profile.tickets = math.max(math.floor(data.tickets), 0)
	end
	if typeof(data.wins) == "number" then
		profile.wins = math.max(math.floor(data.wins), 0)
	end
	if typeof(data.bestTime) == "number" then
		profile.bestTime = data.bestTime
	end
	if typeof(data.unlocked) == "table" then
		for _, id in data.unlocked do
			if typeof(id) == "string" then
				table.insert(profile.unlocked, id)
			end
		end
	end
	return profile
end

-- Yields. Returns the profile, and whether it will be saved.
function Saves.load(player: Player): (Profile, boolean)
	local data: any = nil
	local loaded = false
	if storeOk then
		for attempt = 1, LOAD_ATTEMPTS do
			local ok, result = pcall(function()
				return store:GetAsync(keyFor(player))
			end)
			if ok then
				data = result
				loaded = true
				break
			end
			warn(`Couldn't load progress (attempt {attempt}): {result}`)
			if attempt < LOAD_ATTEMPTS then
				task.wait(RETRY_DELAY)
			end
		end
	end

	local profile = cleanProfile(data)
	if player.Parent then
		entries[player] = { profile = profile, canSave = loaded, dirty = false }
	end
	return profile, loaded
end

function Saves.markDirty(player: Player)
	local entry = entries[player]
	if entry then
		entry.dirty = true
	end
end

local function saveEntry(player: Player, entry: Entry)
	if not entry.canSave or not entry.dirty then
		return
	end
	entry.dirty = false
	savesInProgress += 1
	local ok, result = pcall(function()
		store:SetAsync(keyFor(player), entry.profile)
	end)
	savesInProgress -= 1
	if not ok then
		entry.dirty = true
		warn(`Couldn't save progress: {result}`)
	end
end

-- Call when a player leaves. Yields until the save finishes.
function Saves.release(player: Player)
	local entry = entries[player]
	if entry then
		saveEntry(player, entry)
		entries[player] = nil
	end
end

task.spawn(function()
	while true do
		task.wait(Config.AutosaveInterval)
		for player, entry in entries do
			task.spawn(saveEntry, player, entry)
		end
	end
end)

game:BindToClose(function()
	for player, entry in entries do
		task.spawn(saveEntry, player, entry)
	end
	while savesInProgress > 0 do
		task.wait()
	end
end)

return Saves
