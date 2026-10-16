--[[
	HyperCutscene — the local player's Hyper Ramp cutscene. The slow motion itself is part of the run (RunSim time warp,
	run.Warps: from the ramp's foot to a beat after the launch the log plays at a fraction of its speed, steering locked), so the
	server and every client agree on it. This module is only the show for the OWNER, driven each frame by RunController:
	  - the camera sweeps off the chase position, slowly crosses to the side and low in front of the ramp (RunCamera.Cine) while the
	    log creeps up it, then holds as the log leaves the lip and swings back onto the chase camera (Feel.HyperCine.BlendOut)
	  - lightning: a steady crackle (VFXConfig HyperCharge) on a part that follows the log plus long jagged Neon bolts that strike
	    around it, faster as the lip nears; at the launch an explosion (HyperBlast), a hard shake and a white flash
	  HyperCutscene.Update(dt, rec, t)   rec = the local run record (Run, Focus, Forward, Up), t = seconds into the run
	  HyperCutscene.Stop()               drop everything now (the log broke / a new run)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local Config = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local VFXKit = require(ReplicatedStorage.Shared.Modules.VFXKit)
local RunCamera = require(script.Parent.RunCamera)

local HyperCutscene = {}

local C = Config.Feel.HyperCine
local B = C.Bolts
local random = Random.new()
local folder: Folder?
local anchor: Part?
local blast: Part?
local bolts: { { Parts: { Part }, Born: number } } = {}
local boltNext, boltClock = 1, 0
local fired: { [any]: boolean } = setmetatable({}, { __mode = "k" }) -- warps whose explosion has gone off
local flash: Frame?
local charging = false
local music: Sound? -- the cutscene sound, stretched (PlaybackSpeed) to span the climb
local musicFor: any -- the warp it was started for

local function ease(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
end

local function init()
	if folder then
		return
	end
	folder = Instance.new("Folder")
	folder.Name = "HyperCutscene"
	folder.Parent = workspace
	local function emitterPart(name: string, recipe: string): Part
		local part = Instance.new("Part")
		part.Name, part.Size, part.Transparency = name, Vector3.one, 1
		part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = true, false, false, false, false
		VFXKit.Recipe(part, recipe)
		part.Parent = folder
		return part
	end
	anchor = emitterPart("Charge", "HyperCharge")
	for _, e in anchor:GetChildren() do
		(e :: ParticleEmitter).Enabled = false
	end
	blast = emitterPart("Blast", "HyperBlast")
	for _ = 1, B.Pool do
		local parts = {}
		for i = 1, B.Segments do
			local part = Instance.new("Part")
			part.Name, part.Material, part.Color = "Bolt" .. i, Enum.Material.Neon, Color3.fromRGB(190, 240, 255)
			part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = true, false, false, false, false
			parts[i] = part
		end
		table.insert(bolts, { Parts = parts, Born = -1 })
	end
	music = Instance.new("Sound")
	music.Name, music.SoundId, music.Volume = "HyperCutsceneSound", C.Sound.Id, C.Sound.Volume
	music.Parent = SoundService
	task.spawn(ContentProvider.PreloadAsync, ContentProvider, { music })
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.IgnoreGuiInset, gui.ResetOnSpawn, gui.DisplayOrder = "HyperFlash", true, false, 50
	flash = Instance.new("Frame")
	flash.Size, flash.BackgroundColor3, flash.BackgroundTransparency, flash.BorderSizePixel = UDim2.fromScale(1, 1), Color3.new(1, 1, 1), 1, 0
	flash.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function randomUnit(): Vector3
	local v = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(-1, 1), random:NextNumber(-1, 1))
	return if v.Magnitude < 0.05 then Vector3.yAxis else v.Unit
end

-- One jagged bolt from `from` to `to`: Segments Neon bars along a line, every joint knocked sideways.
local function strike(from: Vector3, to: Vector3)
	local bolt = bolts[boltNext]
	boltNext = boltNext % #bolts + 1
	local points = { from }
	local line = to - from
	for i = 1, B.Segments - 1 do
		table.insert(points, from + line * (i / B.Segments) + randomUnit() * line.Magnitude * 0.09)
	end
	table.insert(points, to)
	for i, part in bolt.Parts do
		local a, b = points[i], points[i + 1]
		part.Size = Vector3.new(B.Thick, B.Thick, math.max((b - a).Magnitude, 0.1))
		part.CFrame = CFrame.lookAt((a + b) / 2, b)
		part.Transparency = 0
		part.Parent = folder
	end
	bolt.Born = os.clock()
end

local function fade()
	local now = os.clock()
	for _, bolt in bolts do
		if bolt.Born > 0 then
			local a = (now - bolt.Born) / B.Life
			for _, part in bolt.Parts do
				if a >= 1 then
					part.Parent = nil
				else
					part.Transparency = a * a
				end
			end
			if a >= 1 then
				bolt.Born = -1
			end
		end
	end
end

local function charge(on: boolean)
	if charging == on or not anchor then
		return
	end
	charging = on
	if on then
		VFXKit.InstantOn(anchor)
	else
		VFXKit.InstantOff(anchor)
	end
end

function HyperCutscene.Stop()
	if not folder then
		return
	end
	RunCamera.Cine(nil)
	charge(false)
	if music then
		music:Stop()
	end
	musicFor = nil
	for _, bolt in bolts do
		bolt.Born = -1
		for _, part in bolt.Parts do
			part.Parent = nil
		end
	end
end

local function explode(position: Vector3)
	(blast :: Part).Position = position
	VFXKit.Fire(blast :: Part)
	RunCamera.Shake(C.BlastShake)
	local frame = flash :: Frame
	frame.BackgroundTransparency = 0.05
	TweenService:Create(frame, TweenInfo.new(C.Flash, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
end

local function pose(key: { number }, side: number, focus: Vector3, forward: Vector3, up: Vector3): (Vector3, number)
	local right = up:Cross(forward)
	return focus + right * (key[1] * side) + up * key[2] + forward * key[3], key[4]
end

function HyperCutscene.Update(dt: number, rec, t: number)
	local warp
	for _, k in rec.Run.Warps do
		if k.Launch and t >= k.W0 and t < k.Launch + C.BlendOut then
			warp = k
			break
		end
	end
	if not warp or not rec.Focus then
		if folder and (charging or bolts[1].Born > 0) then
			HyperCutscene.Stop()
		end
		return
	end
	init()
	local focus, forward, up = rec.Focus, rec.Forward, rec.Up
	if musicFor ~= warp and t < warp.Launch then
		-- play the sound once per cutscene, slowed/sped so it lasts exactly until the launch
		musicFor = warp
		local m = music :: Sound
		local length = m.TimeLength
		m.PlaybackSpeed = if length > 0 then length / math.max(warp.Launch - t, 0.1) else 1
		m:Play()
	end
	local side = if warp.Lane > 0 then -1 else 1
	local climb = ease((t - warp.W0) / math.max(warp.Launch - warp.W0, 1e-3)) -- 0 at the foot .. 1 at the lip
	-- landed halfway up the ramp: the camera path starts that far along instead of at the foot
	local linear = math.clamp((t - warp.W0) / math.max(warp.Launch - warp.W0, 1e-3), 0, 1)
	linear = warp.Frac + (1 - warp.Frac) * linear

	-- camera: foot -> middle -> lip along the Path, then ease to After while the log flies off
	local path = C.Path
	local a, b, k
	if linear < 0.5 then
		a, b, k = path[1], path[2], ease(linear * 2)
	else
		a, b, k = path[2], path[3], ease(linear * 2 - 1)
	end
	local cam, fov = pose({ a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k, a[4] + (b[4] - a[4]) * k }, side, focus, forward, up)
	if t >= warp.Launch then
		local after = ease((t - warp.Launch) / C.BlendOut)
		local endPos, endFov = pose(path[3], side, focus, forward, up)
		local toPos, toFov = pose(C.After, side, focus, forward, up)
		cam, fov = endPos:Lerp(toPos, after), endFov + (toFov - endFov) * after
	end
	local weight = math.min(ease((t - warp.W0) / C.BlendIn), 1 - ease((t - warp.Launch) / C.BlendOut))
	local lookUp = C.LookUp + (C.LookEnd - C.LookUp) * ease(linear)
	RunCamera.Cine(cam, focus + up * lookUp, fov, weight)

	-- lightning while the log climbs; the blast at the lip
	if t < warp.Launch then
		(anchor :: Part).Position = focus
		charge(true)
		RunCamera.Shake(C.Shake * climb)
		boltClock += dt
		local every = B.Every / (0.5 + 1.5 * climb)
		if boltClock >= every then
			boltClock = 0
			local from = focus + up * 2 + randomUnit() * 3
			strike(from, from + randomUnit() * random:NextNumber(B.Reach[1], B.Reach[2]) * (0.7 + 0.5 * climb))
		end
	else
		charge(false)
		if music then
			music:Stop()
		end
		if not fired[warp] then
			fired[warp] = true
			explode(focus)
		end
	end
	fade()
end

return HyperCutscene
