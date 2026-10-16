--[[
	MonetizeService — this game's Robux grant kinds for ShopService (ShopConfig documents each Kind):
	  "Speed"   { Levels }   the Speed for that many more levels (Progress.AddRaw: no multipliers, capped at the rebirth max level)
	  "Bundle"  { Bundle }   MonetizeService.Bundle: pets, Speed, Wins, potions, rebirths, pet slots in one go
	  "Egg"     { Egg, Count } hatches a Robux egg (PetService.Grant) and plays the hatch animation
	  "Limited" { Limited }  one limited-stock item (LimitedService.Grant)
	Every grant only writes saved data (no yields) and returns the toast text.
	  MonetizeService.Bundle(player, data, bundle) -> text   also used by codes, chests and gifts
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoostConfig = require(ReplicatedStorage.Shared.Config.BoostConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)
local PetMath = require(ReplicatedStorage.Shared.Modules.PetMath)
local RebirthMath = require(ReplicatedStorage.Shared.Modules.RebirthMath)
local Progress = require(script.Parent.Parent.Modules.Progress)
local BoostService = require(script.Parent.BoostService)
local DataService = require(script.Parent.DataService)
local LimitedService = require(script.Parent.LimitedService)
local PetService = require(script.Parent.PetService)
local ShopService = require(script.Parent.ShopService)

local MonetizeService = {}

local function speed(player: Player, data, levels: number): string
	local before = data.Level
	Progress.AddRaw(data, RebirthMath.SpeedAt(data.Level + levels, data.Rebirths) - data.Speed)
	player:SetAttribute("Speed", data.Speed)
	player:SetAttribute("Level", data.Level)
	return "+" .. (data.Level - before) .. " Levels"
end

function MonetizeService.Bundle(player: Player, data, bundle): string
	local parts = {}
	for _, id in bundle.Pets or {} do
		PetService.Give(player, data, { id })
		table.insert(parts, PetMath.Pet(id).Name)
	end
	if bundle.Speed then
		table.insert(parts, speed(player, data, bundle.Speed))
	end
	if bundle.Wins then
		DataService.AddCash(player, bundle.Wins)
		table.insert(parts, "+" .. NumberFormat.Abbreviate(bundle.Wins) .. " Wins")
	end
	for kind, count in bundle.Potions or {} do
		BoostService.Give(player, data, kind, count)
		table.insert(parts, count .. "x " .. BoostConfig.Potions[kind].Name)
	end
	if bundle.Rebirths then
		data.Rebirths += bundle.Rebirths
		player:SetAttribute("Rebirths", data.Rebirths)
		table.insert(parts, "+" .. bundle.Rebirths .. " Rebirths")
	end
	if bundle.Slots then
		data.ExtraSlots += bundle.Slots
		PetService.Refresh(player, data)
		table.insert(parts, "+" .. bundle.Slots .. " Pet Slot")
	end
	DataService.Changed(player)
	DataService.Sync(player)
	return table.concat(parts, ", ")
end

function MonetizeService.Start()
	ShopService.RegisterGrant("Speed", function(player, data, item)
		return speed(player, data, item.Def.Levels)
	end)
	ShopService.RegisterGrant("Bundle", function(player, data, item)
		return MonetizeService.Bundle(player, data, item.Def.Bundle)
	end)
	ShopService.RegisterGrant("Egg", function(player, data, item)
		local ids = PetService.Grant(player, data, item.Def.Egg, item.Def.Count)
		Net.Get("PetHatched"):Fire(player, { Egg = item.Def.Egg, Pets = ids })
		return item.Def.Name
	end)
	ShopService.RegisterGrant("Limited", function(player, data, item)
		return LimitedService.Grant(player, data, item.Def.Limited)
	end)
end

return MonetizeService
