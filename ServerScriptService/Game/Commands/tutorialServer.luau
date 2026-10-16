-- Restarts the tutorial (TutorialService.Restart) for each player: testing / helping someone stuck.
local ServerScriptService = game:GetService("ServerScriptService")

local TutorialService = require(ServerScriptService.Game.Services.TutorialService)

return function(_, players: { Player }, step: string?)
	for _, player in players do
		if not TutorialService.Restart(player, step) then
			return "No tutorial step called " .. tostring(step)
		end
	end
	return ("Restarted the tutorial for %d player(s)."):format(#players)
end
