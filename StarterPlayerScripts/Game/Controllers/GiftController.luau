--[[
	GiftController — the "who is this gift for?" list (GiftConfig, PackViews/ListView in menu "GiftPick"). Open(key) lists
	every other player in the server (avatar, name, GIFT button; players who already own a pass / one-time item are greyed);
	picking one sends GiftPick { Key, UserId } and prompts the item's Gift product (ShopMath.GiftOf(key)).
	  GiftController.Open(key)
]]
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GiftConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local ListView = require(ReplicatedStorage.Shared.Modules.PackViews.ListView)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local ShopMath = require(ReplicatedStorage.Shared.Modules.ShopMath)
local ClientState = require(script.Parent.Parent.State.ClientState)
local NotifyController = require(script.Parent.NotifyController)

local GiftController = {}

local T = Config.Text
local player = Players.LocalPlayer
local view
local current: string? = nil
local back: string? = nil -- the menu to return to (the shop)
local avatars = {}

local function owns(other: Player, key: string): boolean
	local item = ShopMath.Items[key]
	if item.Kind == "Pass" then
		return other:GetAttribute(item.Def.Attribute) == true
	end
	return item.Def.OneTime == true and other:GetAttribute(key .. "Bought") == true
end

local function avatar(other: Player): string
	if not avatars[other.UserId] then
		local ok, image = pcall(Players.GetUserThumbnailAsync, Players, other.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		avatars[other.UserId] = if ok then image else ""
	end
	return avatars[other.UserId]
end

local function send(other: Player, key: string)
	if owns(other, key) then
		return NotifyController.Toast(T.Owned:format(other.DisplayName), "Error")
	end
	local gift = ShopMath.GiftOf(key)
	if gift.Product == 0 then
		return NotifyController.Toast(ShopConfig.Ui.ComingSoon, "Error")
	end
	Net.Get("GiftPick"):Fire({ Key = key, UserId = other.UserId })
	MarketplaceService:PromptProductPurchase(player, gift.Product)
end

local function refresh()
	local rows = {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local owned = owns(other, current)
			table.insert(rows, { Key = tostring(other.UserId), Title = other.DisplayName, Text = "@" .. other.Name .. "\n" .. T.Row,
				Icon = avatar(other), Button = if owned then "OWNED" else T.Button, Color = if owned then "Gray" else "Purple",
				OnPress = function()
					send(other, current)
				end })
		end
	end
	view:Set(rows)
	return #rows
end

function GiftController.Open(key: string)
	current = key
	back = ClientState.MenuOpen()
	ClientState.OpenMenu(Config.Menu)
end

function GiftController.Start()
	view = ListView.new(Config.Menu, { Window = { OnClose = function()
		ClientState.CloseMenu()
		if back then
			ClientState.OpenMenu(back)
		end
	end } })
	ClientState.RegisterMenu(Config.Menu, function()
		view.Window:SetTitle(T.Title:format(ShopMath.Items[current].Def.Name))
		if refresh() == 0 then
			NotifyController.Toast(T.Alone, "Error")
		end
		view:Open()
	end, function()
		view:Close()
	end)
	Players.PlayerAdded:Connect(function()
		if ClientState.MenuOpen() == Config.Menu then
			refresh()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			if ClientState.MenuOpen() == Config.Menu then
				refresh()
			end
		end)
	end)
end

return GiftController
