--[[
	Progress — Speed and XP are ONE value. Every Speed gain (a bump / ramp hit, a treadmill tick) goes through AddSpeed,
	which multiplies the gain by the player's rebirth multiplier x (1 + equipped pets' bonus, PetMath.Total), raises data.Speed (capped at the max level for their
	rebirths, RebirthMath) and re-derives the level from it (Curves.LevelFor); data.Level / data.LevelHits (XP into the
	current level) are just the saved view of that. Levels pay nothing: Wins come ONLY from a roll (RollService pays when the log breaks).
	  Progress.AddSpeed(data, gain, player) -> levels gained, Speed actually added (x BoostMath.Speed(player): passes, potion,
	                                friends, trail)
	  Progress.AddRaw(data, amount)  adds bought Speed as is (no multipliers), still capped
	  Progress.Rebirth(data)        reset Speed / Level to the start and count the rebirth (TotalLevels is kept)
	data.TotalLevels: hidden, every level ever gained across all rebirths (Curves.TrainTick reads it).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoostMath = require(ReplicatedStorage.Shared.Modules.BoostMath)
local Curves = require(ReplicatedStorage.Shared.Modules.Curves)
local PetMath = require(ReplicatedStorage.Shared.Modules.PetMath)
local RebirthMath = require(ReplicatedStorage.Shared.Modules.RebirthMath)

local Progress = {}

function Progress.AddRaw(data, amount: number): (number, number)
	local before = data.Speed
	local cap = RebirthMath.SpeedAt(RebirthMath.MaxLevel(data.Rebirths), data.Rebirths)
	data.Speed = math.min(before + amount, cap)
	local level, into = Curves.LevelFor(data.Speed, data.Rebirths)
	local gained = level - data.Level
	data.Level, data.LevelHits = level, into
	data.TotalLevels = (data.TotalLevels or 0) + math.max(gained, 0) -- hidden lifetime count (a rebirth never lowers it)
	return math.max(gained, 0), data.Speed - before
end

function Progress.AddSpeed(data, gain: number, player: Player): (number, number)
	return Progress.AddRaw(data, gain * PetMath.Total(data.Rebirths, PetMath.Sum(data.Pets, data.PetsEquipped)) * BoostMath.Speed(player))
end

function Progress.Rebirth(data)
	data.Rebirths += 1
	data.Speed = 0
	data.Level, data.LevelHits = Curves.LevelFor(0, data.Rebirths)
end

return Progress
