--[[
	PoseConfig — the procedural character animations (Poses builds them into KeyframeSequences at runtime, no uploaded
	animation assets needed). Each pose is { Time, { JointName = {rx, ry, rz} degrees } } on the R15 joints:
	HumanoidRootPart > LowerTorso > UpperTorso > (Head, LeftUpperArm > LeftLowerArm > LeftHand, RightUpperArm ...),
	LowerTorso > LeftUpperLeg > LeftLowerLeg > LeftFoot (and Right). Rotations are relative to the joint's rest pose.
	Right arm +Z lifts it away from the body (left arm -Z); LowerArm -X bends the elbow forward.
]]
return {
	-- Riding the log: arms out and rocking, knees soft.
	Balance = {
		Loop = true, Length = 0.8,
		Frames = {
			{ 0.0, { RightUpperArm = { 0, 0, 78 }, LeftUpperArm = { 0, 0, -62 }, UpperTorso = { -7, 0, 4 }, LeftUpperLeg = { 0, 0, -10 }, RightUpperLeg = { 0, 0, 10 }, LeftLowerLeg = { 14, 0, 0 }, RightLowerLeg = { 14, 0, 0 } } },
			{ 0.4, { RightUpperArm = { 0, 0, 62 }, LeftUpperArm = { 0, 0, -78 }, UpperTorso = { -7, 0, -4 }, LeftUpperLeg = { 0, 0, -10 }, RightUpperLeg = { 0, 0, 10 }, LeftLowerLeg = { 22, 0, 0 }, RightLowerLeg = { 22, 0, 0 } } },
			{ 0.8, { RightUpperArm = { 0, 0, 78 }, LeftUpperArm = { 0, 0, -62 }, UpperTorso = { -7, 0, 4 }, LeftUpperLeg = { 0, 0, -10 }, RightUpperLeg = { 0, 0, 10 }, LeftLowerLeg = { 14, 0, 0 }, RightLowerLeg = { 14, 0, 0 } } },
		},
	},
	-- Weight rep: hands at the shoulders -> pressed overhead -> back down.
	Press = {
		Loop = false, Length = 1.0,
		Frames = {
			{ 0.0, { RightUpperArm = { 0, 0, 35 }, LeftUpperArm = { 0, 0, -35 }, RightLowerArm = { -110, 0, 0 }, LeftLowerArm = { -110, 0, 0 } } },
			{ 0.5, { RightUpperArm = { 0, 0, 165 }, LeftUpperArm = { 0, 0, -165 }, RightLowerArm = { 0, 0, 0 }, LeftLowerArm = { 0, 0, 0 }, UpperTorso = { 6, 0, 0 } } },
			{ 1.0, { RightUpperArm = { 0, 0, 35 }, LeftUpperArm = { 0, 0, -35 }, RightLowerArm = { -110, 0, 0 }, LeftLowerArm = { -110, 0, 0 } } },
		},
	},
}
