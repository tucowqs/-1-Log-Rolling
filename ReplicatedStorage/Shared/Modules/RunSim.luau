--[[
	RunSim — the deterministic 1D simulation of one log run down the hill. The SERVER runs it at launch to decide
	hits, Speed, the break point and Wins (authoritative); every CLIENT replays the very same function from the
	same params to draw the log smoothly with no per-frame network traffic.

	  RunSim.Simulate({ Speed, LogId, Seed, Steer?, Infinite?, LogMult?, World? }) -> run     (Seed picks the ramp field: Layout.For;
	                                  World = the hill it rolls on: a log from an earlier world wears out faster there, Curves.Life)
	    run.Dt, run.N                     sample step and count
	    run.S[i] V[i] H[i] Size[i] Lane[i] Rot[i]    parallel sample arrays (distance, speed, air height, size, lane, roll angle)
	    run.Hits   { {T, S, Kind, Gain, Obs, Air, Lane, Cine?} }  in time order
	    run.BreakT, run.BreakS, run.Finished, run.SpeedGained, run.Life
	    run.Warps  { {T0, T1, Rate, W0, W1, Launch?, Lane, Obs} }  Hyper Ramp cutscenes: the run plays at Rate x between W0 and W1
	  RunSim.StateAt(run, t) -> s, v, h, size, lane, rot    linear interpolation (t clamps to the run)
	  RunSim.RateAt(run, t) -> playback rate (1 outside a cutscene)
	  RunSim.HitsBetween(run, t0, t1) -> iterator of hits with t0 < T <= t1

	Steer is the player's input log { {T, D} } (D in -1..1, sorted by T): the lane moves at Physics.Steer.Speed * D and never
	changes otherwise (no autopilot wander). Same params -> same run everywhere.
	TIME: the samples run on sim time (Dt steps), everything the outside sees (Hits[].T, BreakT, StateAt, Steer T) is WALL time
	since the launch. They differ only by the Hyper Ramp cutscenes: from the foot of a Hyper Ramp the log is carried up it in slow
	motion (Obstacles.HyperCine; steering is locked meanwhile) and launches from the lip. The warps come from the run itself,
	so the server and every client stretch time identically.
	The log rolls at ONE constant velocity, Curves.MaxSpeed(Speed at launch): no acceleration, hits and ramps don't change it.
	Hits still add to the Speed stat (paid out for the NEXT run). Life is Curves.Life(log, World) (seconds).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local Curves = require(script.Parent.Curves)
local Layout = require(script.Parent.Layout)
local Track = require(script.Parent.Track)

local RunSim = {}

local P, O, SH = Config.Physics, Config.Obstacles, Config.Shrink
local HALF = Config.Track.HalfWidth

-- sim time -> wall time: each warp stretches its span from 1 to 1/Rate
local function toWall(warps, t: number): number
	local wall = t
	for _, k in warps do
		if t <= k.T0 then
			break
		end
		wall += (math.min(t, k.T1) - k.T0) * (1 / k.Rate - 1)
	end
	return wall
end

local function toSim(warps, wall: number): number
	local extra = 0
	for _, k in warps do
		local w0 = k.T0 + extra
		if wall <= w0 then
			break
		end
		local span = (k.T1 - k.T0) / k.Rate
		if wall < w0 + span then
			return k.T0 + (wall - w0) * k.Rate
		end
		extra += span - (k.T1 - k.T0)
	end
	return wall - extra
end

function RunSim.Simulate(params)
	local log = Curves.LogById[params.LogId]
	local speed0 = params.Speed
	local life = Curves.Life(log, params.World)
	local dt = P.Dt
	local limit = Track.Length - Config.Track.FinishMargin
	local radius = Config.Track.LogRadius
	local v = Curves.MaxSpeed(speed0) -- constant for the whole run: the log never accelerates, hits don't change it
	local field = Layout.For(params.Seed)
	local list = field.List
	local warps = {}
	local run = { Dt = dt, S = {}, V = {}, H = {}, Size = {}, Lane = {}, Rot = {}, Hits = {}, Warps = warps, Life = life, SpeedGained = 0 }

	local t, s, rot = 0, 0, 0
	local lane = 0 -- the log starts mid-track and only the player moves it sideways
	local airLeft, airTotal, airHeight, airFrom = 0, 1, 0, 0
	local nextObs = field:First(0)
	local count = 0
	local breakAt = nil
	local steer = params.Steer or {}
	local steerIndex, steerDir = 1, 0

	local lastH = 0 -- the log's height above the slope last step
	local touched = {} -- ramps already launched from (each ramp launches you once per pass)
	local armed = {} -- Hyper Ramps the log has started climbing

	local pending = {} -- Obs id -> its warp, until the launch
	local function launch(o, hitS: number)
		local spec = O[o.Kind]
		local gain = (params.LogMult or log.Mult) * spec.Speed -- LogMult: the server's Curves.LogMult (a Better log)
		run.SpeedGained += gain
		airTotal = spec.AirTime * o.Scale ^ 0.5
		airLeft, airHeight = airTotal, spec.AirHeight * o.Scale ^ 0.7
		airFrom = lastH -- the arc starts from wherever the log is right now (on the ground, or already in the air)
		local hit = { T = t, S = hitS, Kind = o.Kind, Gain = gain, Obs = o.Id, Air = airTotal, Lane = lane }
		table.insert(run.Hits, hit)
		return hit
	end

	-- The log reaches the foot of a Hyper Ramp: slow time down for the climb and a beat after the launch (skipped when a warp is still running).
	local function openWarp(o, from: number)
		local last = warps[#warps]
		local C = O.HyperCine
		local climb = (o.HitS - from) / v
		if (last and t < last.T1) or climb < 0.05 then
			return nil
		end
		local rate = math.clamp(climb / C.Climb, C.MinRate, C.MaxRate)
		-- Frac: how far up the ramp the log already is when the warp opens (landed halfway up), so the camera can start there
		local foot = o.S - o.Depth / 2
		local frac = math.clamp((from - foot) / math.max(o.HitS - foot, 1e-3), 0, 1)
		-- the slow motion ends AT the launch (the explosion): the log speeds up the moment it hits the blast
		local warp = { T0 = t, T1 = t + climb, Rate = rate, Lane = lane, Obs = o.Id, Frac = frac }
		table.insert(warps, warp)
		return warp
	end

	local function record(h: number, size: number)
		count += 1
		run.S[count], run.V[count], run.H[count], run.Size[count], run.Lane[count], run.Rot[count] = s, v, h, size, lane, rot
	end
	record(0, 1)

	while true do
		local size = if params.Infinite then 1 else 1 - (1 - SH.MinSize) * math.min(t / life, 1) -- Infinite (the infinlog command): the log never shrinks or breaks
		s += v * dt
		rot += v * dt / (radius * size)

		-- Steering: the lane only changes while the player holds a direction; released, the log rolls dead straight.
		local locked = #warps > 0 and t < warps[#warps].T1 -- carried up a Hyper Ramp: no steering
		while steer[steerIndex] and steer[steerIndex].T <= toWall(warps, t) do
			steerDir = steer[steerIndex].D
			steerIndex += 1
		end
		if not locked then
			lane = math.clamp(lane + steerDir * P.Steer.Speed * dt, -HALF, HALF)
		end

		-- Bumps: hit at their peak while the log is on the ground and inside the width.
		while list[nextObs] and list[nextObs].HitS <= s do
			local o = list[nextObs]
			nextObs += 1
			if o.Kind == "Bump" and airLeft <= 0 and math.abs(lane - o.Lane) < o.Width / 2 + O.HitSlack then
				launch(o, o.HitS)
			end
		end

		-- Ramps (Ramp / Super): the moment the log touches one it launches from where it is, even mid-flight.
		for i = field:First(s - O.TouchLookBack), #list do
			local o = list[i]
			if o.S - o.Depth / 2 > s then
				break
			end
			local hyper = o.Kind == "Hyper"
			if o.Kind ~= "Bump" and not touched[o.Id] and s <= o.S + o.Depth / 2 + (if hyper then v * dt else 0)
				and math.abs(lane - o.Lane) < o.Width / 2 + O.HitSlack + radius * size
				and lastH <= field:Lift(math.min(s, o.HitS - 0.01), lane) + radius * size then
				if not hyper then
					touched[o.Id] = true
					launch(o, s)
				else
					if not armed[o.Id] then
						armed[o.Id] = true
						pending[o.Id] = openWarp(o, s)
							airLeft = 0 -- landed on the ramp: ride its surface up (the air arc would sink the log under it)
					end
					if s >= o.HitS then -- the Hyper Ramp launches from its lip
						touched[o.Id] = true
						local hit = launch(o, o.HitS)
						local warp = pending[o.Id]
						if warp then
							warp.Hit, hit.Cine = hit, true
								warp.T1 = t -- normal speed from the very step of the launch, whatever the climb estimate said
						end
					end
				end
			end
		end

		local h = 0
		if airLeft > 0 then
			local u = 1 - airLeft / airTotal
			h = airFrom * (1 - u) + 4 * airHeight * u * (1 - u)
			airLeft -= dt
		else
			h = field:Lift(s, lane) -- riding up a bump or ramp
		end

		lastH = h
		t += dt
		record(h, size)
		if size <= SH.MinSize + 1e-4 and breakAt == nil then
			breakAt = t
		end
		local landed = airLeft <= 0 or (breakAt and t - breakAt > SH.LandWait)
		if breakAt and landed then
			break
		end
		if s >= limit then
			run.Finished = true
			break
		end
		if t >= P.MaxRunTime and not params.Infinite then
			break
		end
	end
	if run.Finished then
		run.S[count] = limit
		s = limit
	end
	run.N, run.SimEnd, run.BreakS = count, (count - 1) * dt, s
	run.BreakT = toWall(warps, run.SimEnd)
	for _, k in warps do
		k.W0, k.W1 = toWall(warps, k.T0), toWall(warps, k.T1)
		k.Launch = k.Hit and toWall(warps, k.Hit.T)
		k.Hit = nil
	end
	for _, hit in run.Hits do
		hit.T = toWall(warps, hit.T)
	end
	return run
end

function RunSim.StateAt(run, t: number)
	local f = math.clamp(toSim(run.Warps, t), 0, run.SimEnd) / run.Dt
	local i = math.min(math.floor(f) + 1, run.N - 1)
	local a = f - (i - 1)
	local function mix(array)
		return array[i] + (array[i + 1] - array[i]) * a
	end
	return mix(run.S), mix(run.V), mix(run.H), mix(run.Size), mix(run.Lane), mix(run.Rot)
end

function RunSim.RateAt(run, t: number): number
	for _, k in run.Warps do
		if t >= k.W0 and t < k.W1 then
			return k.Rate
		end
	end
	return 1
end

function RunSim.HitsBetween(run, t0: number, t1: number)
	local index = 0
	return function()
		while true do
			index += 1
			local hit = run.Hits[index]
			if not hit or hit.T > t1 then
				return nil
			end
			if hit.T > t0 then
				return hit
			end
		end
	end
end

return RunSim
