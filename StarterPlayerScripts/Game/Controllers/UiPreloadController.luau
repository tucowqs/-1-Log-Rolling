--[[
	UiPreloadController — once the save has loaded, preloads the UI's assets in the background
	(ContentProvider:PreloadAsync on UiPackConfig.Preload.Roots: the pack's images and the item models' meshes /
	textures) so windows and their viewports never pop in. Viewports themselves are built ahead of time by
	their views (Shop / Rewards / the offer popup at Start; an Index via IndexView:Prebuild).
]]
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.UiPackConfig)

local UiPreloadController = {}

function UiPreloadController.Start()
	local player = Players.LocalPlayer
	if not player:GetAttribute("Loaded") then
		player:GetAttributeChangedSignal("Loaded"):Wait()
	end
	local roots = {}
	for _, name in Config.Preload.Roots do
		local root = ReplicatedStorage:FindFirstChild(name)
		if root then
			table.insert(roots, root)
		end
	end
	ContentProvider:PreloadAsync(roots)
end

return UiPreloadController
