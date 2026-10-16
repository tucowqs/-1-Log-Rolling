local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ServerScriptService.Game.Services.DataService)

return function(_, players: { Player }, amount: number)
	local done = 0
	for _, player in players do
		if DataService.Get(player) then
			DataService.AddCash(player, amount)
			done += 1
		end
	end
	return ("Gave %s to %d player(s)."):format(tostring(amount), done)
end
