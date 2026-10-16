--[[
	PetRig — poses a chibi pet model every frame: the body where the caller puts it, and each joint part (attribute
	Joint = "<J>", AssetLibrary) swung about its hinge (model attributes Joint_<J> / JointKind_<J> / JointSide_<J>) by
	its kind's motion in PetsConfig.Follow.Anim (Ear flop, Tail wag, Leg trot, Wing flap). One BulkMoveTo per pose.
	  PetRig.new(model) -> rig        (call after the model's ScaleTo; the rig remembers that scale as its rest)
	  rig:Pose(cf, scale, t, move)    cf = the model pivot, scale = current model scale, t = seconds, move = 0..1 walk amount
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.PetsConfig)

local A = Config.Follow.Anim

local PetRig = {}
PetRig.__index = PetRig

function PetRig.new(model: Model)
	local self = setmetatable({ Model = model, Rest = model:GetScale(), Parts = {}, List = {}, CFrames = {} }, PetRig)
	local pivot = model:GetPivot()
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			local joint = part:GetAttribute("Joint")
			local entry = { Part = part, Offset = pivot:ToObjectSpace(part.CFrame) }
			if joint then
				entry.Kind = model:GetAttribute("JointKind_" .. joint)
				entry.Side = model:GetAttribute("JointSide_" .. joint)
				entry.Hinge = (model:GetAttribute("Joint_" .. joint) :: Vector3) * self.Rest
			end
			table.insert(self.Parts, entry)
			table.insert(self.List, part)
		end
	end
	return self
end

-- The joint's swing for its kind (radians, about the hinge, in model space).
local function swing(kind: string, side: number, t: number, move: number): CFrame
	local m = A[kind]
	local wave = math.sin(t * m.Speed + side * m.Phase) -- constant frequency: a changing one would jump the phase
	local amp = math.rad(m.Amp + m.MoveAmp * move)
	if kind == "Leg" then
		return CFrame.Angles(side * wave * amp, 0, 0)
	elseif kind == "Tail" then
		return CFrame.Angles(0, wave * amp, 0)
	elseif kind == "Wing" then
		return CFrame.Angles(0, 0, side * (wave * 0.5 + 0.5) * amp)
	end
	return CFrame.Angles(0, 0, side * wave * amp) -- Ear: flop outward
end

function PetRig:Pose(cf: CFrame, scale: number, t: number, move: number)
	local k = scale / self.Rest
	for i, entry in self.Parts do
		local offset = entry.Offset.Rotation + entry.Offset.Position * k
		if entry.Hinge then
			local hinge = entry.Hinge * k
			offset = CFrame.new(hinge) * swing(entry.Kind, entry.Side, t, move) * CFrame.new(-hinge) * offset
		end
		self.CFrames[i] = cf * offset
	end
	workspace:BulkMoveTo(self.List, self.CFrames, Enum.BulkMoveMode.FireCFrameChanged)
end

return PetRig
