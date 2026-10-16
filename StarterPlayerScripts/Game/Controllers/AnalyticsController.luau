--[[
	AnalyticsController — what only the client sees, reported to FunnelWatchService over "Analytics"
	(AnalyticsService is server-only): every menu opened (ClientState "Menu") and the funnel steps the UI
	reports with AnalyticsController.Step (Robux prompts, pickers). Names: FunnelConfig; the server
	ignores anything not allowlisted there.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local ClientState = require(script.Parent.Parent.State.ClientState)

local AnalyticsController = {}

function AnalyticsController.Step(funnel: string, step: string)
	Net.Get("Analytics"):Fire({ Funnel = funnel, Step = step })
end

function AnalyticsController.Start()
	ClientState.On("Menu", function(name)
		if name then
			Net.Get("Analytics"):Fire({ Menu = name })
		end
	end)
end

return AnalyticsController
