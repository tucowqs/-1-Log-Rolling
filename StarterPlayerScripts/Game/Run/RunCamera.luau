--[[
	RunCamera — the chase camera for the local player's run (numbers: BalanceConfig.Feel.Camera). Scriptable while a
	run is live: sits behind and above the log, pulls back and widens its FOV with speed, kicks the FOV on boosts and
	shakes on hits. After the log breaks it keeps looking at the splinters (Hold) until the run is over.
	  RunCamera.Begin()    take over            RunCamera.End()   hand back to the default camera
	  RunCamera.Update(dt, focus: Vector3, forward: Vector3, up: Vector3, speed01)
	  RunCamera.Pan(goal: CFrame, time)   quick eased pan to a pose (yields); holds it until End
	  RunCamera.Kick()     FOV kick (boost)     RunCamera.Shake(amount)
	  RunCamera.Cine(pos, look, fov, weight)   blend toward a cutscene pose (Hyper Ramp): weight 0 = the chase camera, 1 = the pose;
	                                           call every frame while it is on, RunCamera.Cine(nil) drops it
	  RunCamera.Active() -> boolean
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.BalanceConfig)

local RunCamera = {}

local C = Config.Feel.Camera
local random = Random.new()
local active, panning, panToken = false, false, 0
local position: Vector3? = nil
local kick, shake, fovBase = 0, 0, 70
local cine: { Pos: Vector3, Look: Vector3, Fov: number, Weight: number }? = nil
local saved = { Type = Enum.CameraType.Custom, Fov = 70 }

function RunCamera.Active(): boolean
	return active
end

function RunCamera.Begin()
	local camera = workspace.CurrentCamera
	if not active then
		saved = { Type = camera.CameraType, Fov = camera.FieldOfView }
	end
	active, panning, position, kick, shake, cine = true, false, nil, 0, 0, nil
	panToken += 1
	camera.CameraType = Enum.CameraType.Scriptable
end

function RunCamera.End()
	if not active then
		return
	end
	active, panning, cine = false, false, nil
	panToken += 1
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = saved.Fov
	local humanoid = game:GetService("Players").LocalPlayer.Character and game:GetService("Players").LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid -- the default camera picks the character up again
	end
end

-- Quick eased pan from wherever the camera is to `goal`; Update is suspended meanwhile and the camera stays there until End.
function RunCamera.Pan(goal: CFrame, time: number)
	if not active then
		return
	end
	panToken += 1
	local id = panToken
	local camera = workspace.CurrentCamera
	local from, fov = camera.CFrame, camera.FieldOfView
	panning = true
	local t = 0
	while t < time and panToken == id and active do
		local a = TweenService:GetValue(t / time, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
		camera.CFrame = from:Lerp(goal, a)
		camera.FieldOfView = fov + (saved.Fov - fov) * a
		t += RunService.RenderStepped:Wait()
	end
	if panToken == id and active then
		camera.CFrame, camera.FieldOfView = goal, saved.Fov
	end
end

function RunCamera.Kick()
	kick = C.FovKick
end

function RunCamera.Shake(amount: number)
	shake = math.max(shake, amount)
end

function RunCamera.Cine(pos: Vector3?, look: Vector3?, fov: number?, weight: number?)
	cine = if pos and look and fov and weight and weight > 0 then { Pos = pos, Look = look, Fov = fov, Weight = math.min(weight, 1) } else nil
end

function RunCamera.Update(dt: number, focus: Vector3, forward: Vector3, up: Vector3, speed01: number)
	if not active or panning then
		return
	end
	local camera = workspace.CurrentCamera
	local back = C.Back * (1 + 0.35 * speed01)
	local goal = focus - forward * back + up * C.Height
	position = if position then position:Lerp(goal, 1 - math.exp(-9 * dt)) else goal
	local look = focus + forward * C.Look
	local offset = Vector3.zero
	if shake > 0.01 then
		offset = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(-1, 1), random:NextNumber(-1, 1)) * shake
		shake *= math.exp(-C.ShakeDecay * dt)
	end
	local frame = CFrame.lookAt(position + offset, look + offset * 0.5)
	kick *= math.exp(-C.KickDecay * dt)
	fovBase = C.Fov + C.FovBoost * speed01 + kick
	if cine then
		frame = frame:Lerp(CFrame.lookAt(cine.Pos + offset, cine.Look + offset * 0.5), cine.Weight)
		fovBase += (cine.Fov - fovBase) * cine.Weight
	end
	camera.CFrame = frame
	camera.Focus = CFrame.new(focus)
	camera.FieldOfView = fovBase
end

return RunCamera
