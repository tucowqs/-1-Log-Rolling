--[[
	RunController — draws every live log run on this client, smoothly, with no per-frame network traffic.
	The server announces a run once (RunStarted {UserId, StartTime, Speed, LogId, Seed}); every client replays the very
	same deterministic RunSim from those params and positions the log from the shared server clock. Hits, the break
	and the area changes come out of that replay, so the visuals line up with what the server pays out.
	For the LOCAL run it also drives the chase camera, rides the avatar on the log, and plays the hit juice
	(shake, FOV kick, thud, "+N"). Server-authoritative totals arrive on RunHits / RunResult and are relayed through
	ClientState.Emit("RunHits" | "RunResult") to the HUD, level bar and ResultController.
The ramp field is the LOCAL client's own random one (RunLayout): the local run sends its seed with Launch and every replay of it uses
that seed; other players' logs are replayed over OUR field so they ride the ramps we see. A Hyper Ramp hit slows the run down
(RunSim warps) and the owner gets HyperCutscene (camera, lightning, explosion).
	  RunController.Local() -> live snapshot of the local run { Active, S, Size, Area, Speed01, T, BreakT, Hits } or nil
	  RunController.Time() -> seconds into the local run (server clock; nil when none)
	  RunController.Release()   give the camera back after a run (after the pan back to the spawn)
	Events (ClientState): "RunStart" (rec), "AreaEntered" (areaIndex), "RunBreak" (rec), "RunHits", "RunResult".
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local Curves = require(ReplicatedStorage.Shared.Modules.Curves)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local RunSim = require(ReplicatedStorage.Shared.Modules.RunSim)
local Track = require(ReplicatedStorage.Shared.Modules.Track)
local Worlds = require(ReplicatedStorage.Shared.Modules.Worlds)
local ClientState = require(script.Parent.Parent.State.ClientState)
local LogRig = require(script.Parent.Parent.Run.LogRig)
local RunAvatar = require(script.Parent.Parent.Run.RunAvatar)
local CameraZoom = require(script.Parent.Parent.Run.CameraZoom)
local RunCamera = require(script.Parent.Parent.Run.RunCamera)
local RunLayout = require(script.Parent.Parent.Run.RunLayout)
local HyperCutscene = require(script.Parent.Parent.Run.HyperCutscene)
local RunFx = require(script.Parent.Parent.Run.RunFx)
local SpeedLines = require(script.Parent.Parent.Run.SpeedLines)
local SoundController = require(script.Parent.SoundController)

local RunController = {}

local F = Config.Feel
local localId = Players.LocalPlayer.UserId
local runs: { [number]: any } = {}
local folder: Folder
local snapshot = { Active = false, S = 0, Size = 1, Area = 1, Speed01 = 0, T = 0, BreakT = 1, Hits = 0 }

local function surfaceFrame(s: number, lane: number, lift: number): CFrame
	local forward, up, right = Track.Basis(s)
	return CFrame.fromMatrix(Track.Pos(s, lane) + up * lift, right, up, forward)
end

local function drop(rec)
	if rec.Rig then
		rec.Rig:Destroy()
		rec.Rig = nil
	end
	runs[rec.UserId] = nil
end

local function onStarted(p)
	local old = runs[p.UserId]
	if old then
		drop(old)
	end
	if p.UserId ~= localId and (p.World or 1) ~= Worlds.Of(Players.LocalPlayer) then
		return -- a run in another world (every world is the same hill at another Offset: it would draw in ours)
	end
	local seed = if p.UserId == localId then p.Seed else RunLayout.Seed() -- other players ride the ramps WE see
	local params = { Speed = p.Speed, LogId = p.LogId, LogMult = p.LogMult, Seed = seed, Steer = table.clone(p.Steer or {}), Infinite = p.Infinite, World = p.World }
	local run = RunSim.Simulate(params)
	if workspace:GetServerTimeNow() - p.StartTime > run.BreakT + 1 then
		return -- a late joiner arriving after that run already finished
	end
	local rec = { UserId = p.UserId, Run = run, Params = params, Start = p.StartTime, Owner = p.UserId == localId, LastT = -1, Area = 1, LogId = p.LogId,
		Rig = LogRig.new(p.LogId, folder), Cap = Curves.MaxSpeed(p.Speed) * 1.15 }
	runs[p.UserId] = rec
	if rec.Owner then
		RunLayout.Use()
		RunAvatar.Begin()
		RunCamera.Begin()
		ClientState.Emit("RunStart", rec)
		ClientState.Emit("AreaEntered", 1)
	end
end

-- Steering from the server ({UserId, T, D}, the owner's too): add it to that run's input log and replay from the same params.
local function onSteer(p)
	local rec = runs[p.UserId]
	if not rec or rec.Broken or p.UserId == localId then -- the owner applied its own input when it sent it
		return
	end
	table.insert(rec.Params.Steer, { T = p.T, D = p.D })
	rec.Run = RunSim.Simulate(rec.Params)
end

local function broke(rec)
	rec.Broken = true
	local center = rec.Rig:Center().Position
	RunFx.Break(center, Curves.LogById[rec.LogId].Rays)
	rec.Rig:Destroy()
	rec.Rig = nil
	if rec.Owner then
		SoundController.Play(Config.SoundNames.Break)
		RunCamera.Shake(F.Camera.ShakeBreak)
		RunAvatar.Fall()
		HyperCutscene.Stop()
		snapshot.Active = false
		ClientState.Emit("RunBreak", rec)
	end
end

local function hits(rec, t: number)
	for hit in RunSim.HitsBetween(rec.Run, rec.LastT, t) do
		local _, _, h = RunSim.StateAt(rec.Run, hit.T)
		local frame = surfaceFrame(hit.S, hit.Lane, h)
		if rec.Owner then
			if not hit.Cine then -- the Hyper cutscene has its own camera and flash
				CameraZoom.Pulse(F.HitZoom[hit.Kind])
			end
			SpeedLines.Burst(hit.Kind)
			RunCamera.Shake(if hit.Kind == "Hyper" then F.Camera.ShakeHyper elseif hit.Kind == "Super" then F.Camera.ShakeSuper elseif hit.Kind == "Ramp" then F.Camera.ShakeRamp else F.Camera.ShakeHit)
			RunFx.Hit(frame, hit, Worlds.Area(Worlds.Of(Players.LocalPlayer), Track.AreaIndex(hit.S)).Ground, true)
			snapshot.Hits += 1
		elseif (frame.Position - workspace.CurrentCamera.CFrame.Position).Magnitude < F.Dust.Near then
			RunFx.Hit(frame, hit, Worlds.Area(Worlds.Of(Players.LocalPlayer), Track.AreaIndex(hit.S)).Ground, false)
		end
	end
end

local function step(dt: number)
	local now = workspace:GetServerTimeNow()
	for _, rec in runs do
		local run = rec.Run
		local t = now - rec.Start
		local s, v, h, size, lane, rot = RunSim.StateAt(run, math.max(t, 0))
		local forward, up = Track.Basis(s)
		local speed01 = math.clamp(v / rec.Cap * RunSim.RateAt(run, t), 0, 1) -- slow motion (Hyper Ramp) slows the animation, FOV and lines too
		if rec.Rig then
			local frame = surfaceFrame(s, lane, 0)
			rec.Rig:Place(frame, rot, size, h, speed01)
			if rec.Owner then
				RunAvatar.Place(frame, size, h, speed01)
			end
			hits(rec, t)
			rec.LastT = t
			local area = Track.AreaIndex(s)
			if rec.Owner then
				snapshot.Active, snapshot.S, snapshot.Size, snapshot.Area, snapshot.Speed01, snapshot.T, snapshot.BreakT =
					true, s, size, area, speed01, math.max(t, 0), run.BreakT
				if area ~= rec.Area then
					ClientState.Emit("AreaEntered", area)
				end
				rec.Focus = rec.Rig:Center().Position
				rec.Forward, rec.Up = forward, up
			end
			rec.Area = area
			if t >= run.BreakT then
				broke(rec)
			end
		elseif t > run.BreakT + F.BreakHold + 6 then
			drop(rec)
		end
		if rec.Owner and rec.Focus then
			if not rec.Broken then
				HyperCutscene.Update(dt, rec, t)
			end
			RunCamera.Update(dt, rec.Focus, rec.Forward, rec.Up, if rec.Broken then 0 else speed01)
			SpeedLines.Update(dt, if rec.Broken then nil else speed01)
		end
	end
end

function RunController.Local()
	return if snapshot.Active then snapshot else nil
end

-- The owner's own steering, applied at once (the server gets the same {T, D}). Returns the T used.
function RunController.Steer(direction: number): number?
	local rec = runs[localId]
	if not rec or not rec.Rig then
		return nil
	end
	local log = rec.Params.Steer
	local at = math.max(workspace:GetServerTimeNow() - rec.Start, if #log > 0 then log[#log].T else 0)
	table.insert(log, { T = at, D = direction })
	rec.Run = RunSim.Simulate(rec.Params)
	return at
end

function RunController.Time(): number?
	local rec = runs[localId]
	return if rec and rec.Rig then workspace:GetServerTimeNow() - rec.Start else nil
end

function RunController.Release()
	RunLayout.Reroll() -- a fresh random ramp field for the next run
	snapshot.Active = false
	RunCamera.End()
	SpeedLines.Update(0, nil)
end

function RunController.Start()
	folder = Instance.new("Folder")
	folder.Name = "RunLogs"
	folder.Parent = workspace
	RunLayout.Start()
	Net.Get("RunStarted"):Connect(onStarted)
	Net.Get("RunSteer"):Connect(onSteer)
	Net.Get("RunEnded"):Connect(function() end) -- the replay already knows when each log breaks
	Net.Get("RunHits"):Connect(function(payload)
		ClientState.Emit("RunHits", payload)
	end)
	Net.Get("RunResult"):Connect(function(payload)
		ClientState.Emit("RunResult", payload)
	end)
	RunService.RenderStepped:Connect(step)
end

return RunController
