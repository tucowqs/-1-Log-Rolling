--[[
	TreadmillFxController — brings the themed treadmills to life on every client: rollers, water wheel, sawblades and gears
	spin, the speed dial swings, the duck bobs, beacons blink and the particles play (river splash, sawdust + smoke, rocket
	flames + sparks). Everything runs faster while someone trains on that belt (player attribute Training = its Id).
	The server places each model (TrainingService) as Workspace.Training.<Id>.Conveyor; moving pieces are its joint parts
	(attribute Joint, hinge = model attribute Joint_<J>, kind = JointKind_<J>; AssetLibrary). Numbers: TreadmillFxConfig.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Curves = require(ReplicatedStorage.Shared.Modules.Curves)
local Config = require(ReplicatedStorage.Shared.Config.TreadmillFxConfig)
local VFXKit = require(ReplicatedStorage.Shared.Modules.VFXKit)

local TreadmillFxController = {}

local rigs = {}
local folder: Folder

local function motionFor(spec, model: Model, joint: string)
	return (spec.Joints and spec.Joints[joint]) or spec.Motions[model:GetAttribute("JointKind_" .. joint)]
end

-- Collects one treadmill's moving parts, particle boxes and blinking lamps.
local function rig(def, model: Model)
	local spec = Config.Models[def.Model]
	local pivot = model:GetPivot()
	local entry = { Id = def.Id, Model = model, Pivot = pivot, Power = 0, Pieces = {}, Fx = {}, Flash = {} }
	for _, part in model:GetChildren() do
		local joint = part:IsA("BasePart") and part:GetAttribute("Joint")
		local motion = joint and motionFor(spec, model, joint)
		if motion then
			local hinge = pivot * CFrame.new(model:GetAttribute("Joint_" .. joint))
			table.insert(entry.Pieces, { Part = part, Motion = motion, Hinge = hinge, Rel = hinge:ToObjectSpace(part.CFrame), Joint = joint })
		end
	end
	for _, fx in spec.Fx do
		local box = Instance.new("Part")
		box.Name, box.Size, box.Transparency, box.CFrame = "TreadFx", fx.Size, 1, pivot * CFrame.new(fx.At)
		box.Anchored, box.CanCollide, box.CanTouch, box.CanQuery, box.CastShadow = true, false, false, false, false
		for _, layer in fx.Spec do
			local s = table.clone(layer)
			s.Shape, s.Dir = s.Shape or { "Box", "Volume" }, fx.Dir
			local e = VFXKit.Emitter(box, s)
			table.insert(entry.Fx, { Emitter = e, Rate = layer.Rate, Idle = fx.Idle })
		end
		box.Parent = folder
	end
	for _, flash in spec.Flash do
		local part = model:FindFirstChild(flash.Part)
		if part then
			table.insert(entry.Flash, { Part = part, On = part.Color, Def = flash })
		end
	end
	table.insert(rigs, entry)
end

local function busy(id: string): boolean
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Training") == id then
			return true
		end
	end
	return false
end

-- A piece's offset from its hinge this frame.
local function pose(piece, entry, now: number, dt: number): CFrame
	local m, p = piece.Motion, entry.Power
	local axis = entry.Pivot:VectorToWorldSpace(m.Axis or Vector3.xAxis)
	if m.Spin then
		piece.Angle = ((piece.Angle or 0) + m.Spin * (m.Idle + (1 - m.Idle) * p) * dt) % math.tau
		return CFrame.fromAxisAngle(axis, piece.Angle)
	elseif m.Swing then
		local deg = m.Swing[1] + (m.Swing[2] - m.Swing[1]) * p + math.sin(now * m.Rate) * m.Jitter * p
		return CFrame.fromAxisAngle(axis, math.rad(-deg))
	end
	local roll = math.rad(math.sin(now * m.Bob[2] * 0.8) * m.Rock)
	return CFrame.new(0, math.sin(now * m.Bob[2]) * m.Bob[1], 0) * CFrame.fromAxisAngle(entry.Pivot.LookVector, roll)
end

local function step(dt: number)
	local now = os.clock()
	local eye = workspace.CurrentCamera.CFrame.Position
	for _, entry in rigs do
		if (entry.Pivot.Position - eye).Magnitude < Config.Range then
			entry.Power += ((if busy(entry.Id) then 1 else 0) - entry.Power) * math.min(1, Config.Ease * dt)
			local parts, cframes = {}, {}
			for _, piece in entry.Pieces do
				local turn = pose(piece, entry, now, dt)
				table.insert(parts, piece.Part)
				table.insert(cframes, (CFrame.new(piece.Hinge.Position) * turn * piece.Hinge.Rotation) * piece.Rel)
			end
			workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
			for _, fx in entry.Fx do
				fx.Emitter.Rate = fx.Rate * (fx.Idle + (1 - fx.Idle) * entry.Power)
			end
			for _, flash in entry.Flash do
				local rate = flash.Def.Rate * (1 + (Config.Boost - 1) * entry.Power)
				flash.Part.Color = if math.sin(now * rate * math.tau) > 0 then flash.On else flash.Def.Dim
			end
		end
	end
end

function TreadmillFxController.Start()
	folder = Instance.new("Folder")
	folder.Name = "TreadmillFx"
	folder.Parent = workspace
	local training = workspace:WaitForChild("Training")
	for _, def in Curves.Treadmills do
		task.spawn(function()
			-- generous timeout: belts stream in late on slow joins; a nil result just skips that belt's fx
			local belt = training:WaitForChild(def.Id, Config.LoadTimeout or 60)
			local model = belt and belt:WaitForChild("Conveyor", Config.LoadTimeout or 60)
			if not model then
				return
			end
			task.wait() -- the server pivots it into place in the same frame it parents it
			rig(def, model)
		end)
	end
	RunService.RenderStepped:Connect(step)
end

return TreadmillFxController
