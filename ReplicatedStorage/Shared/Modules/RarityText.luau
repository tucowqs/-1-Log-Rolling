--[[
	RarityText — paints a TextLabel in its rarity's gradient (UIConfig.Rarities[].Gradient).
	Shimmering rarities get a horizontal gradient tagged "RarityShimmer", which the client's
	RarityShimmerController slides along so the colours sweep across the text. Works on server
	billboards too (the tag replicates).
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIConfig = require(ReplicatedStorage.Shared.Config.UIConfig)

local RarityText = {}

RarityText.Tag = "RarityShimmer"

function RarityText.Apply(label: TextLabel, rarityName: string)
	local rarity = UIConfig.Rarities[rarityName]
	local stops = {}
	for index, color in rarity.Gradient do
		table.insert(stops, ColorSequenceKeypoint.new((index - 1) / (#rarity.Gradient - 1), color))
	end
	label.TextColor3 = Color3.new(1, 1, 1)
	local gradient = label:FindFirstChild("RarityGradient") or Instance.new("UIGradient")
	gradient.Name = "RarityGradient"
	gradient.Color = ColorSequence.new(stops)
	gradient.Rotation = rarity.Shimmer and 0 or 90
	gradient.Offset = Vector2.zero
	gradient.Parent = label
	if rarity.Shimmer then
		CollectionService:AddTag(gradient, RarityText.Tag)
	else
		CollectionService:RemoveTag(gradient, RarityText.Tag)
	end
	return gradient
end

return RarityText
