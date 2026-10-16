--[[
	AssetGroups — the order the Blender models are built in (server) and announced as ready (client), most urgent first:
	the core set (default log, bumps, ramps, start area), then every log, then each area's props in hill order.
	  AssetGroups() -> { { Name, List = { assetName } } }
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local LimitedConfig = require(ReplicatedStorage.Shared.Config.LimitedConfig)
local Worlds = require(ReplicatedStorage.Shared.Modules.Worlds)
local PetsConfig = require(ReplicatedStorage.Shared.Config.PetsConfig)
local LeaderboardConfig = require(ReplicatedStorage.Shared.Config.LeaderboardConfig)

return function()
	local groups = { { Name = "Core", List = { "Wood", "Bump", "Ramp", "SuperRamp", "HyperRamp", "RollSign", "Conveyor" } } }
	local treads, seen = {}, {}
	for _, def in Config.Training.Treadmills do
		if not seen[def.Model] then
			seen[def.Model] = true
			table.insert(treads, def.Model)
		end
	end
	table.insert(groups, { Name = "Treadmills", List = treads })
	local pets = {}
	for _, pet in PetsConfig.Pets do
		table.insert(pets, pet.Id)
	end
	for _, egg in PetsConfig.Eggs do
		table.insert(pets, egg.Model)
	end
	table.insert(pets, PetsConfig.World.Podium.Model)
	table.insert(groups, { Name = "Pets", List = pets })
	table.insert(groups, { Name = "Boards", List = { LeaderboardConfig.Podium.Model } })
	local logs = {}
	for _, log in Config.Logs do
		table.insert(logs, log.Id)
	end
	table.insert(groups, { Name = "Logs", List = logs })
	local limited = {}
	for _, item in LimitedConfig.Items do
		table.insert(limited, item.Model)
	end
	table.insert(groups, { Name = "Limited", List = limited })
	table.insert(groups, { Name = "Lobby", List = { "FreeChest", "WorldPortal", "LimitedPedestal", "RollSign" } }) -- the lobby's own props come before the hill's
	for w = 1, Worlds.Count do -- each zone's scenery, landmark and wall props, world by world
		for index in Config.Areas do
			local area, list, added = Worlds.Area(w, index), {}, {}
			local function add(name: string)
				if not added[name] then
					added[name] = true
					table.insert(list, name)
				end
			end
			for _, prop in area.Props do
				add(prop[1])
			end
			add(area.Landmark[1])
			for _, name in area.WallProps do
				add(name)
			end
			table.insert(groups, { Name = "World" .. w .. "Area" .. index, List = list })
		end
	end
	return groups
end
