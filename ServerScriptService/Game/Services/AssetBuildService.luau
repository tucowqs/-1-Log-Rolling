--[[
	AssetBuildService — builds the Blender models once per server (AssetLibrary: MeshData -> EditableMesh -> session content
	-> Models in ReplicatedStorage.Assets) in AssetGroups order, so the first things a player needs (their log, bumps and
	ramps, the start area) exist within moments of the server starting and the rest of the hill follows. Clients only
	clone the replicated templates.
	The groups the join loading screen waits for (LoadingConfig.Groups) are built first as one batch, LoadingConfig.BuildWidth
	assets at a time, so a fresh server's first players get in fast; the rest of the hill follows RestWidth at a time.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetGroups = require(ReplicatedStorage.Shared.Modules.AssetGroups)
local AssetLibrary = require(ReplicatedStorage.Shared.Modules.AssetLibrary)
local LoadingConfig = require(ReplicatedStorage.Shared.Config.LoadingConfig)

local AssetBuildService = {}

function AssetBuildService.Start()
	task.spawn(function()
		local lobby = {}
		for _, name in LoadingConfig.Groups do
			lobby[name] = true
		end
		local first, rest = {}, {}
		for _, group in AssetGroups() do
			local list = if lobby[group.Name] then first else rest
			table.move(group.List, 1, #group.List, #list + 1, list)
		end
		local ok, err = pcall(AssetLibrary.Preload, first, LoadingConfig.BuildWidth)
		if not ok then
			warn("[AssetBuildService] lobby: " .. tostring(err))
		end
		ReplicatedStorage:SetAttribute("LobbyAssetsBuilt", true)
		ok, err = pcall(AssetLibrary.Preload, rest, LoadingConfig.RestWidth)
		if not ok then
			warn("[AssetBuildService] hill: " .. tostring(err))
		end
		ReplicatedStorage:SetAttribute("AssetsBuilt", true)
	end)
end

return AssetBuildService
