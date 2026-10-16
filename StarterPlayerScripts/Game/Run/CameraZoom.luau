--[[
	CameraZoom — a quick FOV dip and back (CameraZoom.Pulse(spec?), spec = { Fov, In, Out }, default the level-up zoom; hits pass Feel.HitZoom[kind]). The change is ADDITIVE on top of whatever FOV the
	camera has that frame (RunCamera rewrites it every frame during a run), applied last each frame and removed again when it ends,
	so the FOV always settles back to the value it had before. Numbers: BalanceConfig.Feel.LevelZoom.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.BalanceConfig)

local CameraZoom = {}

local Z = Config.Feel.LevelZoom
local spec = Z
local born: number? = nil
local lastSet, applied = nil, 0
local bound = false

local function offset(t: number): number
	if t < spec.In then
		return spec.Fov * TweenService:GetValue(t / spec.In, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end
	return spec.Fov * (1 - TweenService:GetValue(math.min((t - spec.In) / spec.Out, 1), Enum.EasingStyle.Back, Enum.EasingDirection.Out))
end

local function step()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local fov = camera.FieldOfView
	if lastSet and math.abs(fov - lastSet) < 1e-3 then
		fov -= applied -- still our own value: strip it to get the base
	end
	local t = os.clock() - (born :: number)
	local done = t >= spec.In + spec.Out
	lastSet = if done then fov else math.max(fov + offset(t), Config.Feel.HitZoom.MinFov) -- the x3 hit zooms are clamped so the FOV never nears zero
	applied = lastSet - fov
	camera.FieldOfView = lastSet
	if done then
		RunService:UnbindFromRenderStep("CameraZoom")
		bound, lastSet = false, nil
	end
end

function CameraZoom.Pulse(custom)
	spec = custom or Z
	born = os.clock()
	if not bound then
		bound = true
		RunService:BindToRenderStep("CameraZoom", Enum.RenderPriority.Last.Value, step)
	end
end

return CameraZoom
