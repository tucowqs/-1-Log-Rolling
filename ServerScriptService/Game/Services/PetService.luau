--[[
	PetService — the authoritative pets (PetsConfig, PetMath). Saved fields: data.Pets = { [uid] = petId } and
	data.PetsEquipped = { [uid] = true } (both sent to the client snapshot). The client only ASKS; the server checks everything:
	  PetHatch {Egg, Count}  Count 1..the player's Multi (PetMath.Multi), room in storage, enough Wins -> rolls the pets
	                         by the egg's odds (PetMath.Roll), adds them and answers PetHatched {Egg, Pets}
	  PetEquip {Uid, On}     equip (up to EquipMax) / unequip      PetEquipBest {}  the highest-Mult pets that fit
	  PetDelete {Uid}        removes an unequipped pet
	Player attributes for everyone: "PetsEquipped" (comma list of pet model ids, read by PetFollowController) and "PetBonus"
	(the equipped Mults' sum), "EquipMax" (PetsConfig.EquipMax + slot passes + data.ExtraSlots). Progress.AddSpeed multiplies
	every Speed gain by PetMath.Total. Robux eggs are never hatched for Wins (ShopConfig "Egg" products call Grant).
	  PetService.Give(player, data, ids)          adds pets (bundles, limited items)
	  PetService.Grant(player, data, eggId, n)    rolls n pets of an egg (no cost) -> ids
	  PetService.Refresh(player, data)            republishes (slots changed)
]]
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.PetsConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local PetMath = require(ReplicatedStorage.Shared.Modules.PetMath)
local DataService = require(script.Parent.DataService)
local NotifyService = require(script.Parent.NotifyService)
local ShopService = require(script.Parent.ShopService)

local PetService = {}

local T = Config.Text
local random = Random.new()

local function count(map): number
	return DataService.Count(map)
end

local function equipMax(player: Player, data): number
	local max = Config.EquipMax + data.ExtraSlots
	for _, pass in ShopConfig.Passes do
		if pass.Slots and player:GetAttribute(pass.Attribute) == true then
			max += pass.Slots
		end
	end
	return max
end

local function publish(player: Player, data)
	player:SetAttribute("EquipMax", equipMax(player, data))
	local ids = {}
	for _, entry in PetMath.Sorted(data.Pets) do
		if data.PetsEquipped[entry.Uid] then
			table.insert(ids, entry.Id)
		end
	end
	player:SetAttribute("PetsEquipped", table.concat(ids, ","))
	player:SetAttribute("PetBonus", PetMath.Sum(data.Pets, data.PetsEquipped))
	DataService.Sync(player)
end

-- Older saves: an egg counts as bought when the player owns a pet only that egg can hatch (deleted pets can't be known).
local function backfill(data): { [string]: boolean }
	local seen = {}
	for _, egg in Config.Eggs do
		for petId in egg.Odds do
			seen[petId] = if seen[petId] == nil then egg.Id else false -- false = shared by several eggs
		end
	end
	local out = {}
	for _, petId in data.Pets do
		if seen[petId] then
			out[seen[petId]] = true
		end
	end
	return out
end

function PetService.Refresh(player: Player, data)
	publish(player, data)
end

function PetService.Give(player: Player, data, ids: { string })
	for _, id in ids do
		data.Pets[HttpService:GenerateGUID(false)] = id
	end
	publish(player, data)
end

-- Rolls n pets of an egg for free (the caller charged for them). Storage may overflow on Robux grants: never lose a purchase.
function PetService.Grant(player: Player, data, eggId: string, n: number): { string }
	local egg = PetMath.Egg(eggId)
	local ids = {}
	for _ = 1, n do
		table.insert(ids, PetMath.Roll(egg, random))
	end
	data.EggsHatched[egg.Id] = true -- the egg-affordability nudge (EggGuideController) only shows for eggs never bought
	PetService.Give(player, data, ids)
	return ids
end

local function hatch(player: Player, payload)
	local data = DataService.Get(player)
	local egg = type(payload) == "table" and PetMath.Egg(payload.Egg)
	local amount = egg and payload.Count
	if not data or not egg or egg.Robux or player:GetAttribute("Running") or not (type(amount) == "number" and amount % 1 == 0 and amount >= 1 and amount <= PetMath.Multi(player)) then
		return
	end
	if count(data.Pets) + amount > Config.Storage then
		return NotifyService.Send(player, T.Full, "Error")
	end
	if not DataService.Spend(player, egg.Price * amount) then
		return NotifyService.Send(player, T.Poor, "Error")
	end
	Net.Get("PetHatched"):Fire(player, { Egg = egg.Id, Pets = PetService.Grant(player, data, egg.Id, amount) })
end

local function equip(player: Player, payload)
	local data = DataService.Get(player)
	if not data or type(payload) ~= "table" or not data.Pets[payload.Uid] then
		return
	end
	if payload.On then
		local max = equipMax(player, data)
		if not data.PetsEquipped[payload.Uid] and count(data.PetsEquipped) >= max then
			return NotifyService.Send(player, T.MaxEquipped:format(max), "Error")
		end
		data.PetsEquipped[payload.Uid] = true
		data.PetGuided = true -- the first-pet guide (PetGuideController) is over
	else
		data.PetsEquipped[payload.Uid] = nil
	end
	publish(player, data)
end

local function equipBest(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.PetsEquipped = {}
	for index, entry in PetMath.Sorted(data.Pets) do
		if index > equipMax(player, data) then
			break
		end
		data.PetsEquipped[entry.Uid] = true
		data.PetGuided = true
	end
	publish(player, data)
end

local function delete(player: Player, payload)
	local data = DataService.Get(player)
	if not data or type(payload) ~= "table" or not data.Pets[payload.Uid] or data.PetsEquipped[payload.Uid] then
		return
	end
	local def = PetMath.Pet(data.Pets[payload.Uid])
	data.Pets[payload.Uid] = nil
	publish(player, data)
	NotifyService.Send(player, T.Deleted:format(def.Name), "Info")
end

function PetService.Start()
	DataService.AddSnapshot("Pets")
	DataService.AddSnapshot("PetsEquipped")
	DataService.AddSnapshot("EggsHatched")
	DataService.AddSnapshot("PetGuided")
	DataService.OnPrepare(function(_, data)
		data.Pets = data.Pets or {}
		data.PetsEquipped = data.PetsEquipped or {}
		data.ExtraSlots = data.ExtraSlots or 0
		if data.PetGuided == nil then
			data.PetGuided = next(data.Pets) ~= nil -- false until a new player first equips a pet; older saves with pets skip the guide
		end
		if not data.EggsHatched then
			data.EggsHatched = backfill(data) -- saves from before hatches were recorded
		end
	end)
	DataService.OnLoaded(publish)
	for key, pass in ShopConfig.Passes do
		if pass.Slots then
			ShopService.OnPass(key, function(player)
				local data = DataService.Get(player)
				if data then
					publish(player, data)
				end
			end)
			-- a slot pass switched off (the nopasses mock): unequip the weakest pets that no longer fit
			ShopService.OnPassOff(key, function(player)
				local data = DataService.Get(player)
				if not data then
					return
				end
				local max, kept = equipMax(player, data), 0
				for _, entry in PetMath.Sorted(data.Pets) do
					if data.PetsEquipped[entry.Uid] then
						kept += 1
						if kept > max then
							data.PetsEquipped[entry.Uid] = nil
						end
					end
				end
				DataService.Changed(player)
				publish(player, data)
			end)
		end
	end
	Net.Get("PetHatch"):Connect(hatch)
	Net.Get("PetEquip"):Connect(equip)
	Net.Get("PetEquipBest"):Connect(equipBest)
	Net.Get("PetDelete"):Connect(delete)
end

return PetService
