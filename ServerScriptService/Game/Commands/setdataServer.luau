-- Writes one top-level field, then re-mirrors attributes and resends the client snapshot.
-- Speed, Level and Wins are the player-facing numbers and are handled properly: Speed IS the level (Level / LevelHits are derived from it by
-- Curves.LevelFor, capped at the player's max level for their rebirths), so setting Level sets Speed to where that level starts.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Curves = require(ReplicatedStorage.Shared.Modules.Curves)
local RebirthMath = require(ReplicatedStorage.Shared.Modules.RebirthMath)
local DataService = require(ServerScriptService.Game.Services.DataService)

local function parse(text: string): any
	if text == "true" or text == "false" then
		return text == "true"
	elseif tonumber(text) then
		return tonumber(text)
	elseif text:match("^%s*[%[{]") then
		return HttpService:JSONDecode(text)
	end
	return text
end

local function setSpeed(data, speed: number)
	local cap = RebirthMath.SpeedAt(RebirthMath.MaxLevel(data.Rebirths), data.Rebirths)
	data.Speed = math.clamp(speed, 0, cap)
	data.Level, data.LevelHits = Curves.LevelFor(data.Speed, data.Rebirths)
end

return function(_, players: { Player }, key: string, text: string)
	local ok, value = pcall(parse, text)
	if not ok then
		return "Bad JSON: " .. tostring(value)
	end
	local field = key:lower()
	if (field == "speed" or field == "level" or field == "wins") and type(value) ~= "number" then
		return key .. " needs a number."
	end
	local done = 0
	for _, player in players do
		local data = DataService.Get(player)
		if data then
			if field == "speed" then
				setSpeed(data, value)
			elseif field == "level" then
				setSpeed(data, RebirthMath.SpeedAt(math.max(1, math.floor(value)), data.Rebirths))
			elseif field == "wins" then
				data.Wins = math.max(0, value)
			else
				data[key] = value
			end
			DataService.Changed(player)
			DataService.Sync(player)
			done += 1
		end
	end
	return ("Set %s for %d player(s)."):format(key, done)
end
