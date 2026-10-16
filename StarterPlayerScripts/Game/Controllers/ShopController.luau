--[[
	ShopController — the client side of buying (ShopService decides and grants everything):
	  ShopController.Buy(key)        prompts the game pass / developer product for a ShopMath item key (an id of
	                                 0 = "not for sale yet"; paid random items refused where restricted; owned
	                                 passes and bought OneTime products never prompt again)
	  ShopController.Owned(key)      pass active / OneTime product bought
	  ShopController.SetNotes(fn)    fn(key, def) -> string? a live description for a card (e.g. a pack worth N
	                                 minutes of income); default: "Cash" products show ShopUiConfig.Texts.Cash
	  ShopController.SetOdds(cardId, rows)   an Offer card's odds row { { Chance, Name, Art } } (game-filled)
	  ShopController.CardView(id)    a ShopUiConfig.Cards entry resolved with ShopMath prices / names (the
	                                 offer popup reuses it)
	  ShopController.Celebrate(root, key, from?)   the purchase celebration for an item key
	  ShopController.Open(section?)  opens the shop scrolled to a ShopUiConfig.Sections key ("Cash", ...; nil = top)
	and the Robux shop window (PackViews/ShopView: ONE vertical scroll of GameUI pack cards under section
	headers, no side buttons), registered as the ClientState menu ShopConfig.Ui.Menu ("Shop"; context = section key). It keeps OWNED passes / one-time offers
	and the live notes (refreshed on open and every NoteEvery seconds while open). "ShopPurchased" { Key } from
	ShopService plays the celebration: confetti + the item's icons flying into its HUD stat (Cards[id].Fly).
	Cards with Then (the Mega pack): once the first-time Key is bought, the card shows and sells the Then key instead.
	Card gift buttons open GiftController; the Codes card's Redeem fires "RedeemCode" { Code } (CodesService).
]]
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.ShopConfig)
local UiConfig = require(ReplicatedStorage.Shared.Config.ShopUiConfig)
local PackConfig = require(ReplicatedStorage.Shared.Config.UiPackConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)
local ShopMath = require(ReplicatedStorage.Shared.Modules.ShopMath)
local PetMath = require(ReplicatedStorage.Shared.Modules.PetMath)
local PetsConfig = require(ReplicatedStorage.Shared.Config.PetsConfig)
local ShopView = require(ReplicatedStorage.Shared.Modules.PackViews.ShopView)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)
local ClientState = require(script.Parent.Parent.State.ClientState)
local AnalyticsController = require(script.Parent.AnalyticsController)
local GiftController = require(script.Parent.GiftController)
local NotifyController = require(script.Parent.NotifyController)
local ShopCards = require(ReplicatedStorage.Shared.Modules.PackViews.ShopCards)
local SoundController = require(script.Parent.SoundController)

local ShopController = {}

local U = Config.Ui
local player = Players.LocalPlayer
local shop = nil
local flyOf = {} -- ShopMath key -> { image, Targets kind }
local odds = {} -- card id -> the last SetOdds rows (applied once the window exists)
local thenOf = {} -- first-time key -> the key sold after it (ShopUiConfig Cards[].Then)

for _, card in UiConfig.Cards do
	flyOf[card.Key or ""] = card.Fly
	if card.Then then
		thenOf[card.Key], flyOf[card.Then] = card.Then, card.Fly
	end
	for _, button in card.Buttons or {} do
		flyOf[button.Key] = card.Fly
	end
end

local function defaultNote(_, def): string?
	return if def.Kind == "Cash" then UiConfig.Texts.Cash:format(NumberFormat.Abbreviate(def.Amount)) else nil
end
local notes: (string, any) -> string? = defaultNote

function ShopController.Owned(key: string): boolean
	local item = ShopMath.Items[key]
	if item.Kind == "Pass" then
		return ShopMath.PassActive(player, item.Pass)
	end
	return item.Def.OneTime == true and player:GetAttribute(key .. "Bought") == true
end

function ShopController.Buy(key: string)
	if thenOf[key] and ShopController.Owned(key) then
		key = thenOf[key]
	end
	local item = ShopMath.Items[key]
	if ShopController.Owned(key) then
		return
	elseif ShopMath.Blocked(player, item) then
		NotifyController.Toast(U.Restricted, "Error")
	elseif (if item.Kind == "Pass" then item.Def.Pass else item.Product) == 0 then
		NotifyController.Toast(U.ComingSoon, "Error")
	else
		AnalyticsController.Step("RobuxShop", "Prompted")
		if item.Kind == "Pass" then
			MarketplaceService:PromptGamePassPurchase(player, item.Def.Pass)
		else
			MarketplaceService:PromptProductPurchase(player, item.Product)
		end
	end
end

function ShopController.SetNotes(fn: (string, any) -> string?)
	notes = fn
end

function ShopController.SetOdds(cardId: string, rows)
	odds[cardId] = rows
	if shop then
		shop:SetOdds(cardId, rows)
	end
end

local function def(key: string)
	local item = ShopMath.Items[key]
	assert(item, "ShopUiConfig names an unknown shop key " .. key)
	return item.Def
end

function ShopController.CardView(id: string)
	local view = table.clone(assert(UiConfig.Cards[id], "no ShopUiConfig.Cards." .. id))
	view.Id = id
	if view.Key then
		local d = def(view.Key)
		view.Price, view.Title, view.Old = d.Price, view.Title or d.Name or view.Key, view.Old or d.Old
		view.Desc = view.Desc or notes(view.Key, d) or d.Desc
	end
	if view.Card == "Pack" then -- the amount this player would get right now (ShopMath.Amount = what is granted)
		view.Amount = function()
			return "+" .. NumberFormat.Abbreviate(ShopMath.Amount(ShopMath.Items[view.Key], player)) .. " Wins"
		end
	end
	view.Buttons = view.Buttons and table.clone(view.Buttons)
	for i, button in view.Buttons or {} do
		view.Buttons[i] = table.clone(button)
		view.Buttons[i].Price = def(button.Key).Price
	end
	return view
end

local function sections()
	local list = {}
	for _, section in UiConfig.Sections do
		local rows = {}
		for _, ids in section.Rows do
			local cards = {}
			for _, id in ipairs(ids) do -- array part only: a row may carry a Columns field
				table.insert(cards, ShopController.CardView(id))
			end
			cards.Columns = ids.Columns -- a row's own column count (overrides the section's)
			table.insert(rows, cards)
		end
		local copy = table.clone(section)
		copy.Rows = rows
		table.insert(list, copy)
	end
	return list
end

function ShopController.Open(section: string?)
	ClientState.OpenMenu(U.Menu, section)
end

local function target(kind: string?): GuiObject?
	local node: Instance? = player:FindFirstChild("PlayerGui")
	for _, name in if kind then PackConfig.Targets[kind] or {} else {} do
		node = node and node:FindFirstChild(name)
	end
	return if kind and node and node:IsA("GuiObject") then node else nil
end

function ShopController.Celebrate(root: GuiBase2d, key: string, from: GuiObject?)
	local fly = flyOf[key]
	SoundController.Play(UiConfig.Sounds.Celebrate)
	UiPack.Celebrate.Play(root, { From = from, Images = { if fly then fly[1] else PackConfig.Icons.Gift }, Target = target(fly and fly[2]),
		OnArrive = function()
			SoundController.Play(UiConfig.Sounds.Arrive)
		end })
end

local function refresh()
	for key, item in ShopMath.Items do
		if thenOf[key] and ShopController.Owned(key) then
			shop:SetPrice(key, ShopMath.Items[thenOf[key]].Def.Price)
		elseif item.Kind ~= "Gift" then
			shop:SetOwned(key, ShopController.Owned(key))
		end
		shop:SetNote(key, notes(key, item.Def))
	end
end

-- Offer cards with OddsEgg show that egg's pets: chance, name, the 3D pet on its rarity rays (best chance first).
local function eggOdds()
	for id, card in UiConfig.Cards do
		local egg = card.OddsEgg and PetMath.Egg(card.OddsEgg)
		if egg then
			local rows = {}
			for petId, chance in egg.Odds do
				local def = PetMath.Pet(petId)
				table.insert(rows, { Chance = PetMath.Format(chance) .. "%", Name = def.Name, Odds = chance,
					Art = { Models = { { Path = "Pets." .. petId } }, Spin = "Swing", Rays = PetsConfig.Rarities[def.Rarity].Rays } })
			end
			table.sort(rows, function(a, b)
				return a.Odds > b.Odds
			end)
			ShopController.SetOdds(id, rows)
		end
	end
end

function ShopController.Start()
	eggOdds()
	ShopCards.OnGift = GiftController.Open
	ShopCards.OnRedeem = function(code: string)
		Net.Get("RedeemCode"):Fire({ Code = code })
	end
	shop = ShopView.new({ Window = { OnClose = ClientState.CloseMenu }, Sections = sections() }, ShopController.Buy)
	for id, rows in odds do
		shop:SetOdds(id, rows)
	end
	ClientState.RegisterMenu(U.Menu, function(context)
		refresh()
		shop:Refresh() -- Pack amounts grow with the player's income
		shop:Open(context)
	end, function()
		shop:Close()
	end)
	for _, pass in Config.Passes do
		player:GetAttributeChangedSignal(pass.Attribute):Connect(refresh)
	end
	for _, product in Config.Products do
		if product.OneTime then
			player:GetAttributeChangedSignal(product.Key .. "Bought"):Connect(refresh)
		end
	end
	Net.Get("ShopPurchased"):Connect(function(payload)
		ShopController.Celebrate(shop.Root, payload.Key, shop:Source(payload.Key))
	end)
	refresh()
	task.spawn(function() -- a loop inside Start would read as a HANGING Start
		while true do
			task.wait(UiConfig.NoteEvery)
			if shop.Window.IsOpen then
				refresh()
			end
		end
	end)
end

return ShopController
