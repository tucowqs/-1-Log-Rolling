--[[
	ShopService — every Robux purchase (ShopConfig; lookups: ShopMath).
	  The game's ONE MarketplaceService.ProcessReceipt. A developer product receipt is granted exactly
	    once: its PurchaseId is saved in data.Purchases with the grant, and PurchaseGranted is only returned
	    after DataService.SaveConfirmed says that save landed. Anything else (no data yet, an unknown
	    product, a failed grant, the save not landing) returns NotProcessedYet, so Roblox retries later and
	    nothing is lost or doubled.
	  Game passes: checked on load (UserOwnsGamePassAsync) and applied live on
	    PromptGamePassPurchaseFinished. A pass is active while owned on Roblox OR granted (data.Passes);
	    active passes are published as their ShopConfig Attribute.
	  Paid random items: each player's PolicyService ArePaidRandomItemsRestricted is read into the attribute
	    PaidRandomRestricted (true if the check fails); ShopMath.Blocked refuses ShopConfig.RandomKinds.
	API:
	  ShopService.RegisterGrant(kind, fn(player, data, item) -> text)   fn writes saved data only, never
	                                       yields, returns the toast text; erroring leaves the receipt pending
	  ShopService.OnPass(key, fn(player))  a pass became active (join, purchase or GrantPass)
	  ShopService.OnPassOff(key, fn(player))   a pass was switched off (only the nopasses mock does this): undo cached effects
	  ShopService.MockNoPasses(player, on) -> count   the Cmdr "nopasses" test switch, THIS SESSION ONLY (nothing saved): on =
	                                       every active pass attribute is cleared (attribute "PassesMocked" = true), so the player
	                                       plays like a fresh save with no pass benefits; off = re-checks ownership and reapplies
	  ShopService.GrantPass(player, key)   saves + applies a pass without Roblox ownership (admin / gifts)
	  ShopService.ProcessReceipt           the handler itself, for tests (callbacks can't be read back)
	  ShopService.GrantItem(player, data, key) -> text   grants a ShopMath item without a receipt (gifts, codes):
	                                       a pass is granted (GrantPass), a product runs its grant + OneTime mark
	Robux spent: every fresh grant / pass purchase adds its price to data.RobuxSpent (attribute "RobuxSpent", the
	Top Robux Spent board).
	Every fresh grant / pass purchase also fires "ShopPurchased" { Key } to the buyer (the client celebrates).
	OneTime products: data.ShopBought[Key] = true with the grant, mirrored as the attribute "<Key>Bought".
	Offer: data.ShopSessions counts loads; on the ShopConfig.Offer.Session-th one (offer not bought yet) the
	attribute "ShopOffer" = Offer.Key tells ShopOfferController to pop it once (cleared when bought).
]]
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.ShopConfig)
local Em = require(ReplicatedStorage.Shared.Modules.Emphasis).Em
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)
local ShopMath = require(ReplicatedStorage.Shared.Modules.ShopMath)
local DataService = require(script.Parent.DataService)
local FunnelService = require(script.Parent.FunnelService)
local NotifyService = require(script.Parent.NotifyService)

local ShopService = {}

local grants = {}
local passCallbacks: { [string]: { (Player) -> () } } = {}
local passOffCallbacks: { [string]: { (Player) -> () } } = {}

-- Built in: "Cash" { Amount, Minutes? } (ShopMath.Amount: what the card showed).
function grants.Cash(player: Player, _, item): string
	local amount = ShopMath.Amount(item, player)
	DataService.AddCash(player, amount)
	FunnelService.Economy(player, "Source", amount, "IAP", item.Key)
	return "+" .. NumberFormat.Abbreviate(amount) .. " Wins"
end

-- Turn a pass's effect on (idempotent).
local function applyPass(player: Player, key: string)
	local pass = Config.Passes[key]
	if player:GetAttribute(pass.Attribute) == true then
		return
	end
	player:SetAttribute(pass.Attribute, true)
	for _, callback in passCallbacks[key] or {} do
		task.spawn(callback, player)
	end
end

-- Turn a pass's effect off (the nopasses mock): drop the attribute every system reads, then let owners undo cached effects.
local function removePass(player: Player, key: string)
	local pass = Config.Passes[key]
	if player:GetAttribute(pass.Attribute) ~= true then
		return
	end
	player:SetAttribute(pass.Attribute, nil)
	for _, callback in passOffCallbacks[key] or {} do
		task.spawn(callback, player)
	end
end

local function ownsOnRoblox(player: Player, pass): boolean
	if pass.Pass == 0 then
		return false
	end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Pass)
	return ok and owns
end

local function checkPasses(player: Player, data)
	for key, pass in Config.Passes do
		if data.Passes[key] or ownsOnRoblox(player, pass) then
			applyPass(player, key)
		end
	end
end

local function spent(player: Player, data, robux: number)
	data.RobuxSpent += robux
	player:SetAttribute("RobuxSpent", data.RobuxSpent)
end

-- A OneTime product was granted: remember it, show OWNED, drop a pending offer for it.
local function markBought(player: Player, data, key: string)
	data.ShopBought[key] = true
	player:SetAttribute(key .. "Bought", true)
	if player:GetAttribute("ShopOffer") == key then
		player:SetAttribute("ShopOffer", nil)
	end
end

local function processReceipt(receipt)
	local item = ShopMath.ByProduct(receipt.ProductId)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and DataService.Get(player)
	if not (item and data) then
		if not item then
			warn("[ShopService] receipt for an unknown product", receipt.ProductId)
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local id = receipt.PurchaseId
	if not table.find(data.Purchases, id) then
		local ok, result = pcall(ShopService.GrantItem, player, data, item.Key)
		if not ok then
			warn("[ShopService] grant failed", item.Key, result)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		spent(player, data, receipt.CurrencySpent or item.Def.Price)
		DataService.Remember(player, id)
		DataService.Changed(player)
		FunnelService.Step(player, "RobuxShop", "Purchased")
		FunnelService.Event(player, "RobuxPurchase", { Item = item.Key, Kind = item.Kind })
		NotifyService.Send(player, Config.Purchased:format(Em(result, "Success")), "Success")
		Net.Get("ShopPurchased"):Fire(player, { Key = item.Key })
	end
	if DataService.SaveConfirmed(player, id) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Whether paid random items may be offered to this player; restricted unless Roblox says otherwise.
local function checkPolicy(player: Player)
	local ok, policy = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	player:SetAttribute("PaidRandomRestricted", not (ok and policy.ArePaidRandomItemsRestricted == false))
end

function ShopService.RegisterGrant(kind: string, fn)
	grants[kind] = fn
end

function ShopService.OnPass(key: string, callback: (Player) -> ())
	assert(Config.Passes[key], "unknown pass " .. key)
	passCallbacks[key] = passCallbacks[key] or {}
	table.insert(passCallbacks[key], callback)
	for _, player in Players:GetPlayers() do
		if ShopMath.PassActive(player, key) then
			task.spawn(callback, player)
		end
	end
end

function ShopService.OnPassOff(key: string, callback: (Player) -> ())
	assert(Config.Passes[key], "unknown pass " .. key)
	passOffCallbacks[key] = passOffCallbacks[key] or {}
	table.insert(passOffCallbacks[key], callback)
end

function ShopService.MockNoPasses(player: Player, on: boolean): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	player:SetAttribute("PassesMocked", if on then true else nil)
	if not on then
		checkPasses(player, data)
	end
	local count = 0
	for key, pass in Config.Passes do
		if on and player:GetAttribute(pass.Attribute) == true then
			removePass(player, key)
			count += 1
		elseif not on and player:GetAttribute(pass.Attribute) == true then
			count += 1
		end
	end
	return count
end

function ShopService.GrantItem(player: Player, data, key: string): string
	local item = ShopMath.Items[key]
	if item.Kind == "Pass" then
		ShopService.GrantPass(player, item.Pass)
		return item.Def.Name
	end
	local grant = assert(grants[item.Kind], "no grant for kind " .. item.Kind)
	local text = grant(player, data, item)
	if item.Def.OneTime and item.Kind ~= "Gift" then -- a gift's Def is its target's: the recipient's grant marks it
		markBought(player, data, item.Key)
	end
	return text
end

function ShopService.GrantPass(player: Player, key: string): boolean
	local data = DataService.Get(player)
	if not (data and Config.Passes[key]) then
		return false
	end
	data.Passes[key] = true
	applyPass(player, key)
	return true
end

ShopService.ProcessReceipt = processReceipt

function ShopService.Start()
	MarketplaceService.ProcessReceipt = processReceipt
	DataService.OnPrepare(function(player, data)
		data.Passes = data.Passes or {}
		data.ShopBought = data.ShopBought or {}
		data.ShopSessions = (data.ShopSessions or 0) + 1
		data.RobuxSpent = data.RobuxSpent or 0
		player:SetAttribute("RobuxSpent", data.RobuxSpent)
		local offer = Config.Offer
		if offer and data.ShopSessions == offer.Session and not data.ShopBought[offer.Key] then
			player:SetAttribute("ShopOffer", offer.Key)
		end
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = purchased and ShopMath.ByPass(passId)
		local data = key and DataService.Get(player)
		if data then
			spent(player, data, Config.Passes[key].Price)
			applyPass(player, key)
			NotifyService.Send(player, Em(Config.Passes[key].Name, "Success") .. " is now active!", "Success")
			Net.Get("ShopPurchased"):Fire(player, { Key = "Pass" .. key })
			FunnelService.Step(player, "RobuxShop", "Purchased")
			FunnelService.Event(player, "RobuxPurchase", { Item = "Pass" .. key, Kind = "Pass" })
		end
	end)
	Players.PlayerAdded:Connect(checkPolicy)
	for _, player in Players:GetPlayers() do
		task.spawn(checkPolicy, player)
	end
	DataService.OnLoaded(function(player, data)
		for key in data.ShopBought do
			player:SetAttribute(key .. "Bought", true)
		end
		checkPasses(player, data)
	end)
end

return ShopService
