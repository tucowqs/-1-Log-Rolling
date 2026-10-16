--[[
	IconPick — the image for an IconPicksConfig name: the uploaded pack icon once its Id is filled in, until
	then the UIConfig.Icons[Fallback] image. Configs use it too (ShopUiConfig, RewardsUiConfig).
	  IconPick.Image("Gem") -> "rbxassetid://..."
]]
local Picks = require(script.Parent.Parent.Config.IconPicksConfig)
local UIConfig = require(script.Parent.Parent.Config.UIConfig)

local IconPick = {}

function IconPick.Image(name: string): string
	local pick = Picks[name]
	assert(pick, "no IconPicksConfig entry " .. name)
	return if pick.Id ~= 0 then "rbxassetid://" .. pick.Id else UIConfig.Icons[pick.Fallback]
end

return IconPick
