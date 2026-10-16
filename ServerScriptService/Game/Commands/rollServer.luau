local ServerScriptService = game:GetService("ServerScriptService")

local RollService = require(ServerScriptService.Game.Services.RollService)

return function(_, players: { Player })
	for _, player in players do
		RollService.Launch(player)
	end
	return ("Launched %d run(s)."):format(#players)
end
