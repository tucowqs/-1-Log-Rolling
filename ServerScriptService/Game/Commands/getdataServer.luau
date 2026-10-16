local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ServerScriptService.Game.Services.DataService)

return function(_, player: Player, key: string?)
	local data = DataService.Get(player)
	if not data then
		return player.Name .. "'s data isn't loaded."
	end
	local ok, json = pcall(HttpService.JSONEncode, HttpService, if key then data[key] else data)
	return ok and json or "Can't encode that field."
end
