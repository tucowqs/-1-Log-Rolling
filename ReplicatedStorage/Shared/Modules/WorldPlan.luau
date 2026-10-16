--[[
	WorldPlan — every FIXED scenery item of the hill as data, seeded and identical on every client (the models are built
	and streamed client-side, see SceneryController). One list sorted by S:
	  { Kind = "Prop" | "Landmark" | "Gate" | "Training" | "Obstacle", Model, S, Lane, Scale, Yaw, Area, Item = obstacle?, Text? }
	Props scatter down both sides of the hill by area (BalanceConfig.World), landmarks sit at a set point of each area, an arch
	spans the start line (the area gates are Studio-built), and the training racks / mats stand on the plateau behind the start line.
	The bumps / ramps are NOT here: they are rolled per run (Layout.For(seed)).
	  WorldPlan.Build(world)        (re)plans the scenery of that world's zones (WorldsConfig Props / Landmark); WorldPlan.World = it
	  WorldPlan.Items               sorted by S         WorldPlan.Obstacles(field) -> sorted "Obstacle" items of one run's ramp field
	  WorldPlan.Frame(item) -> CFrame  (where the model's origin goes)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local Track = require(script.Parent.Track)
local Worlds = require(script.Parent.Worlds)

local WorldPlan = {}

local W = Config.World
local items = {}

local function add(item)
	table.insert(items, item)
end


local function pick(random: Random, props)
	local total = 0
	for _, p in props do
		total += p[2]
	end
	local roll = random:NextNumber() * total
	for _, p in props do
		roll -= p[2]
		if roll <= 0 then
			return p
		end
	end
	return props[1]
end

function WorldPlan.Build(world: number)
	items = {}
	WorldPlan.World = world
	local random = Random.new(W.Seed + world)
	for index in Config.Areas do
		local plan = Worlds.Area(world, index)
		local s, stop = Track.AreaStart(index) + 10, Track.AreaEnd(index)
		while s < stop - 10 do
			for side = -1, 1, 2 do
				local p = pick(random, plan.Props)
				local lane = side * (Config.Track.HalfWidth + random:NextNumber(W.Edge[1], W.Edge[2]))
				add({ Kind = "Prop", Model = p[1], S = s + random:NextNumber(-8, 8), Lane = lane, Scale = random:NextNumber(p[3][1], p[3][2]),
					Yaw = random:NextNumber(0, math.tau), Area = index })
			end
			s += random:NextNumber(W.PropGap[1], W.PropGap[2])
		end
		local L = plan.Landmark
		local at = Track.AreaStart(index) + (Track.AreaEnd(index) - Track.AreaStart(index)) * L[2]
		add({ Kind = "Landmark", Model = L[1], S = at, Lane = L[3] * (Config.Track.HalfWidth + L[4]), Scale = L[5], Yaw = if L[3] > 0 then math.pi / 2 else -math.pi / 2, Area = index })
		-- the gates between areas are built in Studio (tools/build_world.lua Gates), not streamed
	end
	-- the roll sign over the start line (2026-10-14: the Blender RollSign; SceneryController writes its 3D pack text)
	add({ Kind = "Gate", Model = "RollSign", S = W.Gates.StartAt, Lane = 0, Scale = W.Gates.Scale, Yaw = math.pi, Area = 1, Text = "ROLL!" })
	table.sort(items, function(a, b)
		return a.S < b.S
	end)
	WorldPlan.Items = items
end

WorldPlan.Build(1)

function WorldPlan.Obstacles(field)
	local list = {}
	for _, o in field.List do
		table.insert(list, { Kind = "Obstacle", Model = if o.Kind == "Super" then "SuperRamp" elseif o.Kind == "Hyper" then "HyperRamp" else o.Kind,
			S = o.S, Lane = o.Lane, Scale = o.Scale, Area = o.Area, Item = o })
	end
	return list
end

function WorldPlan.Frame(item): CFrame
	if item.Kind == "Obstacle" then
		local forward, up, right = Track.Basis(item.S)
		return CFrame.fromMatrix(Track.Pos(item.S, item.Lane), right, up, forward)
	elseif item.Pos then
		return CFrame.new(item.Pos) * CFrame.Angles(0, item.Yaw, 0)
	end
	return CFrame.new(Track.Pos(item.S, item.Lane)) * CFrame.Angles(0, item.Yaw or 0, 0)
end

return WorldPlan
