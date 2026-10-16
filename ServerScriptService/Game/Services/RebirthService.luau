--[[
	RebirthService — the authoritative REBIRTH. The client only asks ("Rebirth"); the server checks the player is at the
	max level for their rebirths (RebirthMath.MaxLevel) and not mid-run, then resets Speed / Level (Progress.Rebirth) and
	adds one rebirth: a permanent, stacking Speed-gain multiplier (RebirthMath.Mult, applied in Progress.AddSpeed).
	Replies "RebirthDone" to the owner. Numbers: RebirthConfig.
	  RebirthService.Rebirth(player, keepTraining?) -> boolean
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local RebirthMath = require(ReplicatedStorage.Shared.Modules.RebirthMath)
local Progress = require(script.Parent.Parent.Modules.Progress)
local DataService = require(script.Parent.DataService)
local TrainingService = require(script.Parent.TrainingService)

local RebirthService = {}

local function rebirth(player: Player, keepTraining: boolean?): boolean
	local data = DataService.Get(player)
	if not data or player:GetAttribute("Running") or data.Level < RebirthMath.MaxLevel(data.Rebirths) then
		return false
	end
	if keepTraining ~= true then
		TrainingService.Stop(player)
	end
	Progress.Rebirth(data)
	DataService.Changed(player)
	DataService.Sync(player)
	Net.Get("RebirthDone"):Fire(player, { Rebirths = data.Rebirths, Level = data.Level, LevelHits = data.LevelHits, Speed = data.Speed })
	return true
end

RebirthService.Rebirth = rebirth

function RebirthService.Start()
	Net.Get("Rebirth"):Connect(function(player)
		rebirth(player)
	end)
end

return RebirthService
