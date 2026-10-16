--[[
	RarityShimmerController — slides every "RarityShimmer" gradient (RarityText) along its text so
	the top rarities' names (Shimmer = true in UIConfig.Rarities) sweep with colour. Speed in
	UIConfig.RarityShimmer.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UIConfig = require(ReplicatedStorage.Shared.Config.UIConfig)
local RarityText = require(ReplicatedStorage.Shared.Modules.RarityText)

local RarityShimmerController = {}

function RarityShimmerController.Start()
	RunService.RenderStepped:Connect(function()
		-- Offset runs -1 -> 1 so the whole gradient passes across; stops wrap so it loops cleanly.
		local x = (os.clock() * UIConfig.RarityShimmer.Speed) % 2 - 1
		for _, gradient in CollectionService:GetTagged(RarityText.Tag) do
			gradient.Offset = Vector2.new(x, 0)
		end
	end)
end

return RarityShimmerController
