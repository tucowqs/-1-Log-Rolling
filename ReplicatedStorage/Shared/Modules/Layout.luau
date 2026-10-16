--[[
	Layout — the bump/ramp field of ONE run, rolled from a seed. There is no fixed hill layout: each client rolls a fresh random
	seed when it spawns and after every run (Run/RunLayout), shows that field, and sends the seed with Launch. The server and
	every client that replays the run rebuild the very same field from the seed, so nothing else is synced.
	  Layout.For(seed) -> field           built once per seed (a small cache); the same seed always gives the same field
	  field.List                          { {Id, S, Lane, Kind, Area, Scale, Width, Depth, Height, HitS} } sorted by S
	  field:First(s) -> index             first obstacle with S >= s (binary search)
	  field:Lift(s, lane) -> studs        how high the bump/ramp surface is under the log (0 off the obstacles)
	  o.HitS: where the hit fires (a bump's peak, a ramp's lip)
	Rules (BalanceConfig.Obstacles): every obstacle is a weighted roll over Ramp / Super / Hyper (the worse ones weigh more),
	the same on the whole hill (no per-area odds or sizes). A dense start zone, MinSpacing edge to edge so nothing overlaps,
	AfterRampGap after a ramp. Better kinds roll bigger sizes (Obstacles.<Kind>.Scale).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local Track = require(script.Parent.Track)

local Layout = {}
Layout.__index = Layout

local O = Config.Obstacles
local KINDS = { "Ramp", "Super", "Hyper" } -- no Bumps (the rocks) any more: the mini Ramp is the smallest obstacle
local CACHE_MAX = 32
local cache: { [number]: any } = {}
local order: { number } = {}

local totalWeight = 0
for _, kind in KINDS do
	totalWeight += O.Weights[kind]
end

local function rollKind(random: Random): string
	local roll = random:NextNumber() * totalWeight
	for _, kind in KINDS do
		roll -= O.Weights[kind]
		if roll <= 0 then
			return kind
		end
	end
	return "Ramp"
end

local function build(seed: number)
	local random = Random.new(seed)
	local list = {}
	local limit = Track.Length - Config.Track.FinishMargin - 40
	local s = O.StartMargin
	local previous = nil
	while s < limit do
		local inStart = s < O.StartMargin + O.StartZone.Length
		local kind = rollKind(random)
		local spec = O[kind]
		local scale = random:NextNumber(spec.Scale[1], spec.Scale[2])
		local width, depth = spec.Width * scale, spec.Depth * scale
		local lane = random:NextNumber(-1, 1) * math.max(Config.Track.HalfWidth - width / 2, 4)
		local gap = if inStart then O.StartZone.Spacing * random:NextNumber(0.85, 1.15) else O.Gap * random:NextNumber(0.6, 1.5)
		if previous then
			local clear = previous.Depth / 2 + depth / 2 + O.MinSpacing + (if previous.Kind ~= "Bump" then previous.AfterGap else 0)
			gap = math.max(gap, clear)
		end
		s += gap
		if s < limit then
			previous = { Id = #list + 1, S = s, HitS = s + (if kind ~= "Bump" then depth / 2 else 0), Lane = lane, Kind = kind, Area = Track.AreaIndex(s),
				Scale = scale, Width = width, Depth = depth, Height = spec.Height * scale, AfterGap = O.AfterRampGap }
			table.insert(list, previous)
		end
	end
	return setmetatable({ Seed = seed, List = list }, Layout)
end

function Layout.For(seed: number?)
	local key = math.floor(tonumber(seed) or 0)
	local field = cache[key]
	if not field then
		field = build(key)
		cache[key] = field
		table.insert(order, key)
		if #order > CACHE_MAX then
			cache[table.remove(order, 1)] = nil
		end
	end
	return field
end

function Layout:First(s: number): number
	local list = self.List
	local lo, hi = 1, #list + 1
	while lo < hi do
		local mid = (lo + hi) // 2
		if list[mid].S < s then
			lo = mid + 1
		else
			hi = mid
		end
	end
	return lo
end

-- Surface height of the obstacle under (s, lane): a bump is a dome, a ramp climbs to its lip.
function Layout:Lift(s: number, lane: number): number
	local list = self.List
	for i = self:First(s - 60), #list do
		local o = list[i]
		if o.S - o.Depth / 2 > s then
			break
		end
		local ds, dl = s - o.S, lane - o.Lane
		if math.abs(ds) <= o.Depth / 2 and math.abs(dl) <= o.Width / 2 then
			local across = 1 - (2 * dl / o.Width) ^ 2
			if o.Kind ~= "Bump" then
				return o.Height * (ds + o.Depth / 2) / o.Depth
			end
			return o.Height * math.max(0, 1 - (2 * ds / o.Depth) ^ 2) * across
		end
	end
	return 0
end

return Layout
