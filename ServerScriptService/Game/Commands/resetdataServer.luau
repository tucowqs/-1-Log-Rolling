local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ServerScriptService.Game.Services.DataService)

return function(_, players: { Player })
	local done = 0
	for _, player in players do
		if DataService.Reset(player) then
			done += 1
		end
	end
	return ("Reset %d player(s)."):format(done)
end
