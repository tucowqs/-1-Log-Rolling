--[[
	AssetController — tells the rest of the client when the server's Blender models have replicated: for each group in
	AssetGroups order it waits until every model of the group exists in ReplicatedStorage.Assets, then announces
	ClientState "AssetsReady" (group name) so UIs can build previews. Nothing waits on it: scenery and logs bind to their
	models the moment a template exists (AssetLibrary.Get returns nil until then).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetGroups = require(ReplicatedStorage.Shared.Modules.AssetGroups)
local AssetLibrary = require(ReplicatedStorage.Shared.Modules.AssetLibrary)
local ClientState = require(script.Parent.Parent.State.ClientState)

local AssetController = {}

function AssetController.Start()
	task.spawn(function()
		for _, group in AssetGroups() do
			for _, name in group.List do
				AssetLibrary.Build(name) -- on a client this waits for the server's template to replicate
			end
			ClientState.Emit("AssetsReady", group.Name)
		end
	end)
end

return AssetController
