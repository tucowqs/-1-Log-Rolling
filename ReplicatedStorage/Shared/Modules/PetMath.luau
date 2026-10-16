--[[
	PetMath — the one source of truth for pet numbers, shared by the server (PetService, Progress) and every client view.
	All knobs: PetsConfig.
	  PetMath.Format(mult) -> text       PetMath.Pet(id) -> def            PetMath.Egg(id) -> def
	  PetMath.Sum(pets, equipped)        total Mult of the equipped pets (pets = { [uid] = petId }, equipped = { [uid] = true })
	  PetMath.Total(rebirths, sum)       the Speed-gain multiplier: RebirthMath.Mult x (1 + sum)
	  PetMath.Roll(egg, random)          one pet id by the egg's odds
	  PetMath.Sorted(pets) -> { {Uid, Id, Def, Mult} }    best first (Mult, then uid)
	  PetMath.MultOf(id, pets)           a pet's Mult; a Better pet (the limited King Bones) = Better x the best other owned pet
	  PetMath.EquipMax(player)           pets that may be equipped (attribute "EquipMax", PetService keeps it)
	  PetMath.Best(player, price)        R "Hatch xN": eggs to hatch now, eggs wanted (all passes owned), pass to suggest
	  PetMath.Multi(player)              most eggs the player may hatch at once (MultiBase, or the biggest Eggs* pass owned)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.PetsConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local RebirthMath = require(ReplicatedStorage.Shared.Modules.RebirthMath)

local PetMath = {}

local pets, eggs = {}, {}
for _, def in Config.Pets do
	pets[def.Id] = def
end
for _, def in Config.Eggs do
	eggs[def.Id] = def
end

-- A Mult as text without trailing zeros: 0.1 -> "0.1", 1.35 -> "1.35", 3 -> "3".
function PetMath.Format(value: number): string
	return (string.format("%.2f", value):gsub("%.?0+$", ""))
end

function PetMath.Pet(id: string)
	return pets[id]
end

function PetMath.Egg(id: string)
	return eggs[id]
end

-- The best Mult among owned pets that aren't Better pets themselves.
local function bestPlain(owned): number
	local best = 0
	for _, id in owned or {} do
		local def = pets[id]
		if def and not def.Better then
			best = math.max(best, def.Mult)
		end
	end
	return best
end

function PetMath.MultOf(id: string, owned): number
	local def = pets[id]
	return if def.Better then def.Better * bestPlain(owned) else def.Mult
end

function PetMath.Sum(owned, equipped): number
	local sum = 0
	for uid in equipped or {} do
		local id = (owned or {})[uid]
		if pets[id] then
			sum += PetMath.MultOf(id, owned)
		end
	end
	return sum
end

function PetMath.EquipMax(player: Player): number
	return player:GetAttribute("EquipMax") or Config.EquipMax
end

function PetMath.Multi(player: Player): number
	local count = Config.MultiBase
	for _, key in Config.MultiPasses do
		local pass = ShopConfig.Passes[key]
		if player:GetAttribute(pass.Attribute) == true then
			count = math.max(count, pass.Eggs)
		end
	end
	return count
end

-- The R "Hatch xN" button: the most eggs the Wins cover if every Eggs* pass were owned (capped at the biggest pass),
-- how many of those the player may hatch now, and the smallest unowned pass that would unlock the rest (nil if none or too dear).
function PetMath.Best(player: Player, price: number): (number, number, string?)
	local top = Config.MultiBase
	for _, key in Config.MultiPasses do
		top = math.max(top, ShopConfig.Passes[key].Eggs)
	end
	local want = math.clamp(math.floor((player:GetAttribute("Wins") or 0) / price), 1, top)
	local have = PetMath.Multi(player)
	if want > have then
		for _, key in Config.MultiPasses do
			local eggs = ShopConfig.Passes[key].Eggs
			if eggs > have and eggs <= want then
				return have, want, key
			end
		end
	end
	return math.min(want, have), want, nil
end

function PetMath.Total(rebirths: number, sum: number): number
	return RebirthMath.Mult(rebirths) * (1 + sum)
end

function PetMath.Roll(egg, random: Random): string
	local pick, ids = random:NextNumber() * 100, {}
	for id in egg.Odds do
		table.insert(ids, id)
	end
	table.sort(ids) -- a stable walk through the odds
	local acc = 0
	for _, id in ids do
		acc += egg.Odds[id]
		if pick < acc then
			return id
		end
	end
	return ids[#ids]
end

function PetMath.Sorted(owned)
	local list = {}
	for uid, id in owned or {} do
		if pets[id] then
			table.insert(list, { Uid = uid, Id = id, Def = pets[id], Mult = PetMath.MultOf(id, owned) })
		end
	end
	table.sort(list, function(a, b)
		if a.Mult ~= b.Mult then
			return a.Mult > b.Mult
		end
		return a.Uid < b.Uid
	end)
	return list
end

return PetMath
