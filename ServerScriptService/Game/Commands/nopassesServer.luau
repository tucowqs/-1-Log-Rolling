-- Mocks "owns no gamepasses" for this session (ShopService.MockNoPasses): every pass attribute is cleared, so boosts, slots,
-- zones, autos and multi-hatch all act as on a fresh save. false switches them back on (ownership is re-checked).
local ServerScriptService = game:GetService("ServerScriptService")

local ShopService = require(ServerScriptService.Game.Services.ShopService)

return function(_, players: { Player }, off: boolean?)
	local on = off ~= false
	local lines = {}
	for _, player in players do
		local count = ShopService.MockNoPasses(player, on)
		table.insert(lines, if on then ("%s: %d pass(es) switched off"):format(player.Name, count) else ("%s: %d pass(es) active again"):format(player.Name, count))
	end
	return table.concat(lines, "\n")
end
