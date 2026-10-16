--[[
	ShopOfferController — the one-time offer popup (ShopConfig.Offer, a OneTime product). ShopService sets the
	"ShopOffer" attribute (= the offer key) on the player's Offer.Session-th session; Offer.AfterRun seconds after the
	end of a roll (never during one) this window opens once, as the ClientState menu ShopConfig.Ui.OfferMenu:
	the GameUI pack window shell (UiPackConfig.Menus[OfferMenu]) holding the shop's own card for the offer
	(ShopUiConfig.Cards[Offer.Key], via ShopController.CardView). It never shows once "<Key>Bought" is true;
	the shop's tabs keep the card. No ShopConfig.Offer = this controller does nothing. Runs ended during the
	first-time tutorial (the "Tutorial" attribute) don't count; if another window is open or they rolled again, the next run end tries again.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.ShopConfig)
local ShopCards = require(ReplicatedStorage.Shared.Modules.PackViews.ShopCards)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)
local ClientState = require(script.Parent.Parent.State.ClientState)
local ShopController = require(script.Parent.ShopController)

local ShopOfferController = {}

local MENU = Config.Ui.OfferMenu
local CARD = UDim2.fromScale(0.968, 0.92) -- the card fills the popup body
local player = Players.LocalPlayer

function ShopOfferController.Start()
	local offer = Config.Offer
	if not offer then
		return
	end
	local bought = offer.Key .. "Bought"
	local window = UiPack.Window(MENU, { OnClose = ClientState.CloseMenu })
	local list = window.Panel.Scrolling
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") and child.Name ~= "_" then
			child:Destroy()
		end
	end
	list.CanvasSize, list.ScrollingEnabled, list.ScrollBarThickness = UDim2.fromScale(0, 1), false, 0
	local entry = ShopCards.new(list, 1, ShopController.CardView(offer.Key), ShopController.Buy, list)
	entry.Card.Size = CARD
	ClientState.RegisterMenu(MENU, function()
		window:Open()
		UiPack.Art.SetActive(list, true)
	end, function()
		window:Close()
		UiPack.Art.SetActive(list, false)
	end)
	player:GetAttributeChangedSignal(bought):Connect(function()
		if player:GetAttribute(bought) and ClientState.MenuOpen() == MENU then
			ClientState.CloseMenu()
		end
	end)
	local shown = false
	local function due(): boolean
		return not shown and player:GetAttribute("ShopOffer") == offer.Key and not player:GetAttribute(bought)
			and player:GetAttribute("Tutorial") == nil
	end
	player:GetAttributeChangedSignal("Running"):Connect(function()
		if player:GetAttribute("Running") or not due() then
			return
		end
		task.delay(offer.AfterRun or 1.5, function() -- the run just ended: let the result land first
			if due() and not player:GetAttribute("Running") and ClientState.MenuOpen() == nil then
				shown = true
				ClientState.OpenMenu(MENU)
			end
		end)
	end)
end

return ShopOfferController
