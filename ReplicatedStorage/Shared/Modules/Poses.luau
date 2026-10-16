--[[
	Poses — builds a character animation from PoseConfig data into a KeyframeSequence at runtime (registered locally with
	KeyframeSequenceProvider, so no animation asset has to be uploaded) and plays it on a humanoid's Animator at
	Action priority. Animations played by the owning client replicate to everyone.
	  Poses.Play(humanoid, name, speed?) -> AnimationTrack    (looping as configured)
	  Poses.Stop(track?)
]]
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.PoseConfig)

local Poses = {}

-- R15 joint hierarchy: a Pose must sit under its parent joint's Pose.
local TREE = {
	HumanoidRootPart = { LowerTorso = {
		UpperTorso = { Head = {}, LeftUpperArm = { LeftLowerArm = { LeftHand = {} } }, RightUpperArm = { RightLowerArm = { RightHand = {} } } },
		LeftUpperLeg = { LeftLowerLeg = { LeftFoot = {} } },
		RightUpperLeg = { RightLowerLeg = { RightFoot = {} } },
	} },
}

local ids: { [string]: string } = {}

local function register(name: string): string
	local def = Config[name]
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name, sequence.Loop, sequence.Priority = name, def.Loop, Enum.AnimationPriority.Action
	for _, frame in def.Frames do
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = frame[1]
		local function make(joint: string, children): Pose
			local pose = Instance.new("Pose")
			local angles = frame[2][joint]
			pose.Name, pose.Weight = joint, if angles then 1 else 0
			pose.CFrame = if angles then CFrame.Angles(math.rad(angles[1]), math.rad(angles[2]), math.rad(angles[3])) else CFrame.identity
			for childName, grandchildren in children do
				make(childName, grandchildren).Parent = pose
			end
			return pose
		end
		for joint, children in TREE do
			make(joint, children).Parent = keyframe
		end
		keyframe.Parent = sequence
	end
	return KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
end

function Poses.Play(humanoid: Humanoid, name: string, speed: number?): AnimationTrack
	ids[name] = ids[name] or register(name)
	local animation = Instance.new("Animation")
	animation.AnimationId = ids[name]
	local track = (humanoid:FindFirstChildOfClass("Animator") :: Animator):LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = Config[name].Loop
	track:Play(0.15, 1, speed or 1)
	return track
end

function Poses.Stop(track: AnimationTrack?)
	if track then
		track:Stop(0.15)
	end
end

return Poses
