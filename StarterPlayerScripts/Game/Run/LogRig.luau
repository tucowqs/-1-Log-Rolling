--[[
	LogRig — the client-side visual of one rolling log: the Blender log model (Assets.Logs.<Id>, built by AssetLibrary)
	spinning about its axis, shrinking with the run's size, plus a non-rotating anchor that carries a skid trail
	(brighter the faster the log). Until the model's template is built a plain cylinder stands in for it.
	  LogRig.new(logId, parent) -> rig       rig.Anchor (the track-frame part)
	  rig:Place(frame, rot, size, h, speed01)   frame = CFrame at the surface point (X = right, Y = up, -Z = forward)
	  rig:Center() -> CFrame of the log's centre        rig:Destroy()
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local Curves = require(ReplicatedStorage.Shared.Modules.Curves)
local AssetLibrary = require(ReplicatedStorage.Shared.Modules.AssetLibrary)
local Aura = require(ReplicatedStorage.Shared.Modules.Aura)

local LogRig = {}
LogRig.__index = LogRig

local RADIUS = Config.Track.LogRadius

function LogRig.new(logId: string, parent: Instance)
	local self = setmetatable({ LogId = logId, Size = 1, Parent = parent }, LogRig)
	local anchor = Instance.new("Part")
	anchor.Name, anchor.Size, anchor.Transparency = "LogAnchor", Vector3.one, 1
	anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery, anchor.CastShadow = true, false, false, false, false
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(-3.6, 0.4, 0), Vector3.new(3.6, 0.4, 0)
	a0.Parent, a1.Parent = anchor, anchor
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime, trail.MinLength, trail.FaceCamera = 0.55, 0.2, false
	trail.LightEmission, trail.Color = 0.5, ColorSequence.new(Curves.LogById[logId].Rays)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	trail.Enabled = false
	trail.Parent = anchor
	anchor.Parent = parent
	self.Anchor, self.Trail = anchor, trail
	self.Aura = Aura.Log(logId, parent) -- later logs only (AuraConfig.Logs)
	self:Bind()
	return self
end

-- Swap the stand-in cylinder for the real model as soon as its template exists.
function LogRig:Bind()
	local model = AssetLibrary.Get(self.LogId)
	if model then
		if self.Model then
			self.Model:Destroy()
		end
		self.Model, self.Real = model, true
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.CastShadow = true
			end
		end
		model.Parent = self.Parent
	elseif not self.Model then
		local cylinder = Instance.new("Part")
		cylinder.Shape, cylinder.Size, cylinder.Color = Enum.PartType.Cylinder, Vector3.new(9.6, RADIUS * 2, RADIUS * 2), Curves.LogById[self.LogId].Rays
		cylinder.Anchored, cylinder.CanCollide, cylinder.CanTouch, cylinder.CanQuery = true, false, false, false
		cylinder.Parent = self.Parent
		self.Model = cylinder
	end
end

function LogRig:Place(frame: CFrame, rot: number, size: number, h: number, speed01: number)
	if not self.Real and AssetLibrary.Ready(self.LogId) then
		self:Bind()
	end
	local center = frame * CFrame.new(0, RADIUS * size + h, 0)
	local oriented = CFrame.fromMatrix(center.Position, frame.XVector, frame.YVector, frame.ZVector) * CFrame.Angles(rot % math.tau, 0, 0)
	self.CenterCFrame = oriented
	self.Anchor.CFrame = frame * CFrame.new(0, h * 0.6, 0)
	if self.Aura then -- the aura box follows the log but doesn't roll with it
		self.Aura:Place(CFrame.fromMatrix(center.Position, frame.XVector, frame.YVector, frame.ZVector), Vector3.new(9.6, RADIUS * 2, RADIUS * 2) * Aura.Config.LogFit * size)
	end
	self.Trail.Enabled = speed01 > 0.3
	self.Trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7 - 0.5 * speed01), NumberSequenceKeypoint.new(1, 1) })
	if self.Real then
		if math.abs(size - self.Size) > 0.004 then
			self.Model:ScaleTo(size)
			self.Size = size
		end
		self.Model:PivotTo(oriented)
	else
		self.Model.CFrame = oriented * CFrame.new(0, 0, 0)
		self.Model.Size = Vector3.new(9.6 * size, RADIUS * 2 * size, RADIUS * 2 * size)
	end
end

function LogRig:Center(): CFrame
	return self.CenterCFrame
end

function LogRig:Destroy()
	self.Model:Destroy()
	self.Anchor:Destroy()
	if self.Aura then
		self.Aura:Destroy()
	end
end

return LogRig
