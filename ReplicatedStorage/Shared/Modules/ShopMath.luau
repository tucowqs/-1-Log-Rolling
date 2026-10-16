--[[
	ShopMath — shared by ShopService (what is granted) and ShopController (what the window shows), so the
	window always shows exactly what the server sells.
	  ShopMath.Items                 -> { [key] = { Key, Kind, Def, Product } } every Robux item
	  ShopMath.ByProduct(id)         -> item (a developer product id from a receipt)
	  ShopMath.ByPass(id)            -> pass key (a game pass id)
	  ShopMath.PassActive(player, k) -> whether pass k is active (the attribute ShopService sets)
	  ShopMath.Restricted(player)    -> paid random items can't be offered (true until ShopService checked)
	  ShopMath.Blocked(player, item) -> this item is a paid random item they can't buy
	  ShopMath.Map(id, key)          -> test hook: point a product id at an item (before real ids exist)
	  ShopMath.GiftOf(key)           -> the "Gift<key>" item that buys item `key` for someone else (nil = not giftable)
	Gift items: every pass / product with a Gift field gets Items["Gift" .. key] = { Kind = "Gift", Target = key, Product = Gift }.
	  ShopMath.Amount(item, player)  -> the cash a "Cash" item grants this player: Def.Amount, or with Def.Minutes and
	                                    ShopConfig.IncomeAttribute set, max(Amount, Minutes x 60 x the player's income/s)
	                                    (packs that grow with progress - the card shows exactly what is granted)
]]
local Config = require(script.Parent.Parent.Config.ShopConfig)

local ShopMath = {}

ShopMath.Items = {}
local byProduct, byPass = {}, {}

for key, pass in Config.Passes do
	ShopMath.Items["Pass" .. key] = { Key = "Pass" .. key, Kind = "Pass", Def = pass, Product = 0, Pass = key }
	if pass.Pass ~= 0 then
		byPass[pass.Pass] = key
	end
end
local function add(item)
	assert(not ShopMath.Items[item.Key], "duplicate shop key " .. item.Key)
	ShopMath.Items[item.Key] = item
	if item.Product ~= 0 then
		byProduct[item.Product] = item
	end
end

for _, def in Config.Products do
	add({ Key = def.Key, Kind = def.Kind, Def = def, Product = def.Product })
end
for _, item in table.clone(ShopMath.Items) do
	if item.Def.Gift then
		add({ Key = "Gift" .. item.Key, Kind = "Gift", Target = item.Key, Def = item.Def, Product = item.Def.Gift })
	end
end

function ShopMath.GiftOf(key: string)
	return ShopMath.Items["Gift" .. key]
end

function ShopMath.Amount(item, player: Player): number
	local def = item.Def
	local rate = Config.IncomeAttribute and player:GetAttribute(Config.IncomeAttribute)
	if def.Minutes and type(rate) == "number" then
		return math.max(def.Amount, math.floor(def.Minutes * 60 * rate))
	end
	return def.Amount
end

function ShopMath.ByProduct(id: number)
	return byProduct[id]
end

function ShopMath.ByPass(id: number): string?
	return byPass[id]
end

function ShopMath.Map(id: number, key: string)
	byProduct[id] = ShopMath.Items[key]
end

function ShopMath.PassActive(player: Player, key: string): boolean
	return player:GetAttribute(Config.Passes[key].Attribute) == true
end

function ShopMath.Restricted(player: Player): boolean
	return player:GetAttribute("PaidRandomRestricted") ~= false
end

function ShopMath.Blocked(player: Player, item): boolean
	return Config.RandomKinds[item.Kind] == true and ShopMath.Restricted(player)
end

return ShopMath
