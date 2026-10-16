--[[
	PlaytimeService — total time played (data.TimePlayed, seconds), mirrored to the attribute "TimePlayed" every Step seconds
	for the Top Time Played board (LeaderboardConfig).
]]
local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)

local PlaytimeService = {}

local STEP = 30

function PlaytimeService.Start()
	DataService.OnPrepare(function(player, data)
		data.TimePlayed = data.TimePlayed or 0
		player:SetAttribute("TimePlayed", data.TimePlayed)
	end)
	task.spawn(function()
		while true do
			task.wait(STEP)
			for _, player in Players:GetPlayers() do
				local data = DataService.Get(player)
				if data then
					data.TimePlayed += STEP
					player:SetAttribute("TimePlayed", data.TimePlayed)
				end
			end
		end
	end)
end

return PlaytimeService
