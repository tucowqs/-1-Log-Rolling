--[[
	RebirthMath — the one source of truth for rebirth numbers, used by the server (Progress, RebirthService) and the
	client (rebirth window, level bar, Mult label). All knobs: RebirthConfig.
	  MaxLevel(rebirths)   the level cap with that many rebirths
	  Mult(rebirths)       the permanent Speed-gain multiplier
	  SpeedAt(level, rebirths?)  the Speed (= XP) at which `level` is reached (the curve depends on rebirths)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.RebirthConfig)
local Curves = require(ReplicatedStorage.Shared.Modules.Curves)

local RebirthMath = {}

function RebirthMath.MaxLevel(rebirths: number): number
	return Config.BaseMaxLevel + Config.LevelsPerRebirth * rebirths
end

function RebirthMath.Mult(rebirths: number): number
	return 1 + Config.MultPerRebirth * rebirths
end

function RebirthMath.SpeedAt(level: number, rebirths: number?): number
	local speed = 0
	for l = 1, level - 1 do
		speed += Curves.XPForLevel(l, rebirths)
	end
	return speed
end

return RebirthMath
