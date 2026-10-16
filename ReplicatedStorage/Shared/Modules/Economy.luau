--[[
	Economy — the economy formulas (knobs + the maths written out: Shared/Config/EconomyConfig). The configs call these at load
	to fill their numbers (BalanceConfig logs + Level, WorldsConfig zone Wins, PetsConfig pets + eggs, TrailConfig trails,
	RebirthConfig), and Curves.Life applies the world wear, so every system climbs the same ladders.
	  Economy.Nice(x)                 2 significant figures: 15659 -> 16000, 0.137 -> 0.14
	  Economy.ZoneWins(world, zone)   Wins paid in that zone (WorldsConfig WinsMult)
	  Economy.LogMult(tier)           Speed per hit of the tier-th log
	  Economy.LogPrice(tier)          its Wins price (tier 1 = the free Basic Log)
	  Economy.LogLife(tier)           seconds it lasts on its own world's hill
	  Economy.Wear(logWorld, world)   life factor for a log rolled in another world (Curves.Life)
	  Economy.FillLogs(logs)          writes Tier / World / Mult / Price / Durability into BalanceConfig.Logs (in order, Limited skipped)
	  Economy.PetMult(rank)           a pet's bonus from its Rank
]]
local Config = require(script.Parent.Parent.Config.EconomyConfig)

local Economy = {}

local L = Config.Logs

function Economy.Nice(x: number): number
	return tonumber(string.format("%.2g", x)) :: number
end

local function pick(list, w: number)
	return list[math.min(w, #list)]
end

local function worldOf(tier: number): (number, number)
	local w = math.ceil(tier / L.PerWorld)
	return w, tier - L.PerWorld * (w - 1)
end

function Economy.ZoneWins(world: number, zone: number): number
	local g = Config.Wins.ZonesPerWorld * (world - 1) + zone
	local boost = (Config.Wins.EarlyBoost and Config.Wins.EarlyBoost[g] or 1) * (Config.Wins.StartBuff and Config.Wins.StartBuff[g] or 1)
	return Economy.Nice(Config.Wins.Growth ^ (g - 1) * boost)
end

function Economy.LogMult(tier: number): number
	return Economy.Nice(L.MultGrowth ^ (tier - 1))
end

function Economy.LogPrice(tier: number): number
	if tier <= 1 then
		return 0
	end
	local price = L.FirstPrice
	for t = 3, tier do
		local w, i = worldOf(t)
		price *= if i == 1 then L.WorldJump else pick(L.PriceGrowth, w)
	end
	return Economy.Nice(price)
end

function Economy.LogLife(tier: number): number
	local w, i = worldOf(tier)
	local life = pick(L.Life, w)
	return math.floor(life.Start + life.Step * (i - 1) + 0.5)
end

function Economy.Wear(logWorld: number, world: number): number
	return L.Wear ^ (world - logWorld)
end

function Economy.FillLogs(logs)
	local tier = 0
	for _, log in logs do
		if not log.Limited then
			tier += 1
			log.Tier, log.World = tier, worldOf(tier)
			log.Mult, log.Price, log.Durability = Economy.LogMult(tier), Economy.LogPrice(tier), Economy.LogLife(tier)
		end
	end
	return logs
end

function Economy.PetMult(rank: number): number
	return Economy.Nice(Config.Pets.Base * Config.Pets.Growth ^ (rank - 1))
end

return Economy
