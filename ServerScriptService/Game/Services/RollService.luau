--[[
	RollService — the authoritative side of a log run. On Launch it validates the request, replays the whole run
	through the shared RunSim (the same deterministic function every client uses to draw it) and then PAYS OUT as
	the run's clock reaches each hit: Speed, hit count and level progress are granted here in real time, batched to
	the owner at most every Feel.HitBatch seconds. When the log breaks it pays Wins for the area it stopped in and
	sends the result. Clients never tell the server what happened; they only ask to launch.
	  RollService.Active(player) -> bool        RollService.StartCFrame(world?) -> CFrame (the top of that world's hill)
	Worlds: a run is simulated in hill space; the player's world (Worlds.Of, kept on the run as rec.World) places them at its
	start, pays its zones' Wins and tells every client (RunStarted.World) so only that world draws the run.
	Launch carries the client's random ramp-field Seed. Bridges (BalanceConfig.Bridges): Launch / ReturnTop / ReturnSpawn in; RunStarted / RunHits / RunEnded / RunResult out.
	The player attribute "Running" is true while a run is live; "Fallen" is true from the break until the next Launch / ReturnTop.
Wall: Workspace.Plateau.Wall is in the "Barrier" collision group, so a player off a log is blocked and can't walk down the hill; while a run is live the
character is in the "Rolling" group, which doesn't collide with Barrier.
]]
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local BoostMath = require(ReplicatedStorage.Shared.Modules.BoostMath)
local Curves = require(ReplicatedStorage.Shared.Modules.Curves)
local Worlds = require(ReplicatedStorage.Shared.Modules.Worlds)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local RunSim = require(ReplicatedStorage.Shared.Modules.RunSim)
local Track = require(ReplicatedStorage.Shared.Modules.Track)
local Progress = require(script.Parent.Parent.Modules.Progress)
local DataService = require(script.Parent.DataService)
local TrainingService = require(script.Parent.TrainingService)
local TutorialConfig = require(ReplicatedStorage.Shared.Config.TutorialConfig)

local RollService = {}

local F = Config.Feel
local runs: { [Player]: any } = {}
local lastEnd: { [Player]: number } = {}

function RollService.Active(player: Player): boolean
	return runs[player] ~= nil
end

function RollService.StartCFrame(world: number?): CFrame
	local pos = Track.Pos(0) + Worlds.Offset(world or 1)
	return CFrame.lookAt(pos + Vector3.new(0, 4, 0), pos + Vector3.new(0, 4, 100))
end

-- Pays one hit: Speed, which is also the XP (Progress).
local function applyHit(player: Player, data, rec, hit)
	local levels, gained = Progress.AddSpeed(data, hit.Gain, player)
	data.Hits += 1
	rec.Pending.Gain += gained
	rec.Pending.Count += 1
	rec.Pending.Levels += levels
	rec.Levels += levels
end

local function flush(player: Player, data, rec)
	local p = rec.Pending
	if p.Count == 0 then
		return
	end
	DataService.Changed(player)
	DataService.Sync(player)
	Net.Get("RunHits"):Fire(player, { Gain = p.Gain, Count = p.Count, Speed = data.Speed, Level = data.Level,
		LevelHits = data.LevelHits, Hits = data.Hits, Levels = p.Levels })
	rec.Pending = { Gain = 0, Count = 0, Levels = 0 }
	rec.LastFlush = os.clock()
end

-- A character on a log passes through the plateau wall (Barrier); everyone else is blocked by it.
local function setRolling(player: Player, rolling: boolean)
	local character = player.Character
	if not character then
		return
	end
	local group = if rolling then "Rolling" else "Default"
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = group
		end
	end
end

local function finish(player: Player, rec)
	setRolling(player, false)
	runs[player] = nil
	lastEnd[player] = os.clock()
	player:SetAttribute("Running", nil)
	player:SetAttribute("Fallen", true) -- the avatar faceplants and stays down until the next Launch / ReturnTop (RunAvatar)
	local data = DataService.Get(player)
	if data then
		for i = rec.Next, #rec.Run.Hits do
			applyHit(player, data, rec, rec.Run.Hits[i])
		end
		flush(player, data, rec)
		local base, area = Curves.WinsFor(rec.Run.BreakS, rec.Run.Finished == true, rec.World)
		local wins = math.floor(base * BoostMath.Wins(player))
		local step = player:GetAttribute("Tutorial")
		if step == "Roll" or step == "Steer" then
			wins = math.max(wins, TutorialConfig.FirstRollWins or 0) -- the tutorial's first roll always buys the Birch Log
		end
		DataService.AddCash(player, wins)
		data.Runs += 1
		data.Best = math.max(data.Best, rec.Run.BreakS)
		DataService.Changed(player)
		DataService.Sync(player)
		Net.Get("RunResult"):Fire(player, { AreaIndex = area, Wins = wins, SpeedGained = rec.Run.SpeedGained, Distance = rec.Run.BreakS,
			Best = data.Best, Levels = rec.Levels, Finished = rec.Run.Finished == true, Hits = #rec.Run.Hits })
	end
	Net.Get("RunEnded"):Fire(Net.All(), { UserId = player.UserId })
end

-- The ramp field is rolled by the client (Run/RunLayout) and arrives as the Launch seed; the server just rebuilds it (Layout.For)
-- to replay and pay the run. A missing / malformed seed (the Cmdr roll command) gets a random one.
local function seedFrom(payload): number
	local seed = if type(payload) == "table" then payload.Seed else nil
	if type(seed) == "number" and seed == seed and seed >= 1 and seed <= 2 ^ 30 then
		return math.floor(seed)
	end
	return math.random(1, 2 ^ 30)
end

local function launch(player: Player, payload)
	local data = DataService.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not data or not humanoid or humanoid.Health <= 0 or runs[player] then
		return
	end
	if os.clock() - (lastEnd[player] or 0) < F.LaunchCooldown then
		return
	end
	TrainingService.Stop(player)
	local infinite = player:GetAttribute("InfinLog") == true -- set by the infinlog command, spent by this run
	player:SetAttribute("InfinLog", nil)
	local world = Worlds.Of(player)
	local params = { Speed = data.Speed, LogId = data.Equipped, LogMult = Curves.LogMult(data.Equipped, data.Logs), Seed = seedFrom(payload), Steer = {}, Infinite = infinite, World = world }
	local run = RunSim.Simulate(params)
	local startTime = workspace:GetServerTimeNow() + Config.Obstacles.LeadIn
	runs[player] = { Run = run, Params = params, Start = startTime, Next = 1, Pending = { Gain = 0, Count = 0, Levels = 0 }, LastFlush = 0, Levels = 0, PaidT = 0, World = world }
	player:SetAttribute("Running", true)
	player:SetAttribute("Fallen", nil)
	setRolling(player, true)
	character:PivotTo(RollService.StartCFrame(world))
	Net.Get("RunStarted"):Fire(Net.All(), { UserId = player.UserId, StartTime = startTime, Speed = params.Speed, LogId = params.LogId, Seed = params.Seed, Steer = params.Steer, Infinite = params.Infinite, World = world, LogMult = params.LogMult })
end

RollService.Launch = launch -- the Launch bridge and the Cmdr roll command share it

-- Steering input {T, D}: T is run time, D in -1..1. It can only change the future (never a hit already paid), so T is
-- clamped to at most Steer.Lag ago; the run is re-simulated from the input log and every client is told the same {T, D}.
local function steer(player: Player, payload)
	local rec = runs[player]
	if not rec or type(payload) ~= "table" or type(payload.T) ~= "number" or type(payload.D) ~= "number" or payload.T ~= payload.T or payload.D ~= payload.D then
		return
	end
	local now = workspace:GetServerTimeNow() - rec.Start
	local log = rec.Params.Steer
	local last = log[#log]
	local floor = math.max(now - Config.Physics.Steer.Lag, last and last.T or 0)
	local at = math.clamp(payload.T, floor, floor + 1)
	if now >= rec.Run.BreakT or #log >= 600 then
		return
	end
	local entry = { T = at, D = math.clamp(payload.D, -1, 1) }
	table.insert(log, entry)
	rec.Run = RunSim.Simulate(rec.Params)
	rec.Next = 1 -- the replay may differ inside the Lag window: resume after the last time already paid
	while rec.Run.Hits[rec.Next] and rec.Run.Hits[rec.Next].T <= rec.PaidT do
		rec.Next += 1
	end
	Net.Get("RunSteer"):Fire(Net.All(), { UserId = player.UserId, T = entry.T, D = entry.D })
end

local function returnTop(player: Player)
	local character = player.Character
	if character and not runs[player] and DataService.Get(player) then
		TrainingService.Stop(player)
		player:SetAttribute("Fallen", nil)
		character:PivotTo(RollService.StartCFrame(Worlds.Of(player)) * CFrame.new(0, 0, 60)) -- local +Z is behind the start line
	end
end

local function returnSpawn(player: Player)
	local character = player.Character
	if not character or runs[player] or not DataService.Get(player) then
		return
	end
	TrainingService.Stop(player)
	player:SetAttribute("Fallen", nil)
	character:PivotTo(Worlds.Spawn(Worlds.Of(player)))
end

local function step()
	local now = workspace:GetServerTimeNow()
	for player, rec in runs do
		local data = DataService.Get(player)
		if not data then
			runs[player] = nil
			continue
		end
		local t = now - rec.Start
		local hits = rec.Run.Hits
		rec.PaidT = math.max(rec.PaidT, t)
		while hits[rec.Next] and hits[rec.Next].T <= t do
			applyHit(player, data, rec, hits[rec.Next])
			rec.Next += 1
		end
		if rec.Pending.Count > 0 and os.clock() - rec.LastFlush >= F.HitBatch then
			flush(player, data, rec)
		end
		if t >= rec.Run.BreakT then
			finish(player, rec)
		end
	end
end

function RollService.Start()
	for _, name in { "Barrier", "Rolling" } do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	PhysicsService:CollisionGroupSetCollidable("Rolling", "Barrier", false)
	Net.Get("Launch"):Connect(launch)
	Net.Get("ReturnTop"):Connect(returnTop)
	Net.Get("ReturnSpawn"):Connect(returnSpawn)
	Net.Get("Steer"):Connect(steer)
	RunService.Heartbeat:Connect(step)
	Players.PlayerRemoving:Connect(function(player)
		local rec = runs[player]
		if rec then
			finish(player, rec) -- a leaver still banks the run they were on
		end
		lastEnd[player] = nil
	end)
	-- Late joiners replay every live run from its params.
	DataService.OnLoaded(function(player)
		task.wait(2)
		for owner, rec in runs do
			Net.Get("RunStarted"):Fire(player, { UserId = owner.UserId, StartTime = rec.Start, Speed = rec.Params.Speed, LogId = rec.Params.LogId, Seed = rec.Params.Seed, Steer = rec.Params.Steer, Infinite = rec.Params.Infinite, World = rec.World, LogMult = rec.Params.LogMult })
		end
	end)
end

return RollService
