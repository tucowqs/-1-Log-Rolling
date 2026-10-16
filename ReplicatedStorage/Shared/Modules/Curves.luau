--[[
	Curves — every Speed / level / Wins formula in one place (numbers: BalanceConfig). Used by RunSim, the
	services and the UI so what the HUD shows is what the server grants.
	  Soft(S)                         0..1 diminishing curve of Speed
	  MaxSpeed(S)                     the constant velocity of a run at Speed S (studs/s)
	  Life(log, world?)               seconds until a log shrinks out on that world's hill: its Durability x Economy.Wear (a log from an
	                                  earlier world wears out faster), whatever your Speed
	  LogById[id] / LogIndex[id] / TreadmillById[id]
	  Treadmills                      every treadmill STATION: BalanceConfig.Training.Treadmills expanded per world (a def with World
	                                  stands in that world; an AllWorlds def (the Robux zones) gets one station per world, Id + world
	                                  number from World 2 on, same Mult). Workspace.Training.<station Id> is its model.
	  XPForLevel(level, rebirths?)    Speed (= XP) needed to leave `level` (Level.Early before the first rebirth, Level.Hard from the 2nd)
	  LevelFor(speed, rebirths?)      (level, XP into that level): the level is derived from Speed
	  WinsFor(distance, finished, world)   (Wins, areaIndex) for a log that stopped at `distance` in that world
	  TrainTick(totalLevels, rebirths?) seconds between treadmill payouts (faster for brand-new players: data.TotalLevels; always Slow once rebirthed)
	  LogMult(logId, owned)           a log's Mult; a Better log (the limited Reaper Relic) = Better x the best other owned log's
	                                  (owned = data.Logs). The server puts it on each run (RunSim params.LogMult)
	  TrainGain(station, mult)        Speed per payout tick: Training.Rate x the belt's Mult x the equipped log's Mult (before multipliers;
	                                  Rate 1: the Jogging Belt pays the log's advertised Speed / hit every tick)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local Economy = require(script.Parent.Economy)
local Track = require(script.Parent.Track)
local Worlds = require(script.Parent.Worlds)

local Curves = { LogById = {}, LogIndex = {}, TreadmillById = {}, Treadmills = {} }

for index, log in Config.Logs do
	Curves.LogById[log.Id], Curves.LogIndex[log.Id] = log, index
end
local function addStation(def, w: number)
	local copy = table.clone(def)
	copy.World, copy.Base = w, def.Id
	if def.AllWorlds then
		copy.Id = if w == 1 then def.Id else def.Id .. w
	end
	table.insert(Curves.Treadmills, copy)
	Curves.TreadmillById[copy.Id] = copy
end

for _, def in Config.Training.Treadmills do
	if def.AllWorlds then
		for w = 1, Worlds.Count do
			addStation(def, w)
		end
	else
		addStation(def, def.World)
	end
end

function Curves.Soft(speed: number): number
	local n = math.log10(1 + math.max(speed, 0))
	return n / (n + Config.Speed.Half)
end

local function lerp(range, t: number): number
	return range[1] + (range[2] - range[1]) * t
end

function Curves.MaxSpeed(speed: number): number
	return lerp(Config.Speed.MaxSpeed, Curves.Soft(speed))
end

function Curves.Life(log, world: number?): number
	return (log.Durability or Config.Shrink.Seconds) * Economy.Wear(log.World or 1, world or 1)
end

-- The XP-cost multiplier on `level`: the Early discount before any rebirth, the plain curve on rebirth 1, then the first
-- Hard.Levels levels get a little harder with each rebirth past the first.
local function levelMult(level: number, rebirths: number): number
	local L = Config.Level
	if rebirths <= 0 then
		return L.Early and L.Early[level] or 1
	end
	local hard = L.Hard
	if hard and rebirths >= 2 and level <= hard.Levels then
		return math.min(1 + hard.PerRebirth * (rebirths - 1), hard.Max)
	end
	return 1
end

function Curves.XPForLevel(level: number, rebirths: number?): number
	return math.floor(Config.Level.BaseXP * Config.Level.Growth ^ (level - 1) * levelMult(level, rebirths or 0))
end

function Curves.LevelFor(speed: number, rebirths: number?): (number, number)
	local level, left = 1, math.max(speed, 0)
	while left >= Curves.XPForLevel(level, rebirths) do
		left -= Curves.XPForLevel(level, rebirths)
		level += 1
	end
	return level, left
end

function Curves.WinsFor(distance: number, finished: boolean, world: number?): (number, number)
	local W = Config.Wins
	local index = Track.AreaIndex(distance)
	local start, stop = Track.AreaStart(index), Track.AreaEnd(index)
	local fraction = math.clamp((distance - start) / (stop - start), 0, 1)
	local wins = W.Base * Worlds.Area(world or 1, index).WinsMult * (1 + W.DistanceBonus * fraction)
	if finished then
		wins *= W.FinishMult
	end
	return math.max(1, math.floor(wins)), index
end

function Curves.LogMult(logId: string, owned): number
	local log = Curves.LogById[logId]
	if not log.Better then
		return log.Mult
	end
	local best = 1
	for id in owned or {} do
		local other = Curves.LogById[id]
		if other and not other.Better then
			best = math.max(best, other.Mult)
		end
	end
	return log.Better * best
end

-- Seconds between treadmill payouts for a player with `totalLevels` lifetime levels (data.TotalLevels): Training.Tick.Fast
-- at 0, easing linearly to Slow at SlowAt. After a rebirth the head start is gone: always Slow.
function Curves.TrainTick(totalLevels: number?, rebirths: number?): number
	local tick = Config.Training.Tick
	if (rebirths or 0) > 0 then
		return tick.Slow
	end
	local t = math.clamp((totalLevels or 0) / math.max(tick.SlowAt, 1), 0, 1)
	return tick.Fast + (tick.Slow - tick.Fast) * t
end

function Curves.TrainGain(station, mult: number?): number
	return Config.Training.Rate * station.Mult * (mult or 1) -- not rounded: the Birch Log's 1.6 pays 1.6
end

return Curves
