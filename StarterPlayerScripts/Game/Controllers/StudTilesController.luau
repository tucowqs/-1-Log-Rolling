--[[
	StudTilesController — keeps a UI pack's tiled stud pattern perfectly square on the game's
	hand-made menu screen (UIConfig.StudTiles: the ScreenGui name and the folder name the pack keeps
	its tiled images in). Packs tile by a share of the frame's width and height, so on a wide frame
	(cards, dialogs) every stud comes out stretched. Each tiled image keeps the pack's tile height and
	gets the width that makes its tiles square, re-worked whenever its size changes (screen size, the
	grow / shrink tweens), including frames cloned in later. Off when UIConfig.StudTiles.Gui is nil.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.UIConfig).StudTiles

local StudTilesController = {}

local watched = setmetatable({}, { __mode = "k" })

local function square(image: ImageLabel)
	local size = image.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	local tall = image:GetAttribute("StudTileHeight") -- the pack's own tile height (share of the frame)
	image.TileSize = UDim2.fromScale(tall * size.Y / size.X, tall)
end

local function watch(image: Instance)
	if watched[image] or not image:IsA("ImageLabel") or image.ScaleType ~= Enum.ScaleType.Tile then
		return
	end
	if not (image.Parent and image.Parent.Name == Config.Folder) then
		return
	end
	watched[image] = true
	if not image:GetAttribute("StudTileHeight") then
		image:SetAttribute("StudTileHeight", image.TileSize.Y.Scale)
	end
	image:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		square(image)
	end)
	square(image)
end

function StudTilesController.Start()
	if not Config.Gui then
		return
	end
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild(Config.Gui)
	gui.DescendantAdded:Connect(function(thing)
		task.defer(watch, thing) -- after a clone has been parented and laid out
	end)
	for _, thing in gui:GetDescendants() do
		watch(thing)
	end
end

return StudTilesController
