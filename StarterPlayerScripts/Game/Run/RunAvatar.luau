--[[
	RunAvatar — rides the LOCAL character on top of its log. The client owns its character, so placing it each frame
	replicates to everyone as normal movement; no server work. The humanoid is put in PlatformStand so nothing fights
	the placement, and the standard Roblox run animation plays on top, quicker the faster the log rolls (Feel.RunAnim).
	  RunAvatar.Begin() -> boolean         take the character (false when there is none)
	  RunAvatar.Place(surface: CFrame, size, h, speed01)   stand on the log whose surface frame is `surface` (Y = up, -Z = forward)
	  RunAvatar.End()                      give the character back (it stays where it stopped)
	  RunAvatar.Fall()                     the log broke: the avatar drops and faceplants, then stays frozen until the server clears the
	                                       "Fallen" attribute (next Launch / ReturnTop), which stands it back up
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.BalanceConfig)

local RunAvatar = {}

local RUN = Config.Feel.RunAnim
local FALL = Config.Feel.Fall
local LIE = 0.6 -- studs the root sits above the surface when lying face down
local RADIUS = Config.Track.LogRadius
local fallen: { Humanoid: Humanoid, Root: BasePart, Walk: number, Jump: number } | nil = nil
local held: { Humanoid: Humanoid, Root: BasePart, Track: AnimationTrack } | nil = nil

function RunAvatar.Begin(): boolean
	RunAvatar.Recover()
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return false
	end
	humanoid.PlatformStand = true
	humanoid.AutoRotate = false
	local animation = Instance.new("Animation")
	animation.AnimationId = RUN.Id
	local track = (humanoid:WaitForChild("Animator") :: Animator):LoadAnimation(animation)
	track.Priority, track.Looped = Enum.AnimationPriority.Action, true
	track:Play(0.15, 1, RUN.Speed[1])
	held = { Humanoid = humanoid, Root = root, Track = track }
	return true
end

function RunAvatar.Place(surface: CFrame, size: number, h: number, speed01: number)
	if not held then
		return
	end
	held.Track:AdjustSpeed(RUN.Speed[1] + (RUN.Speed[2] - RUN.Speed[1]) * speed01)
	local rootHeight = held.Humanoid.HipHeight + held.Root.Size.Y / 2
	local pos = surface.Position + surface.YVector * (RADIUS * 2 * size + h + rootHeight)
	held.Root.CFrame = CFrame.lookAt(pos, pos + surface.ZVector, surface.YVector)
	held.Root.AssemblyLinearVelocity = Vector3.zero
	held.Root.AssemblyAngularVelocity = Vector3.zero
end

function RunAvatar.End()
	if held then
		held.Track:Stop(0.15)
		held.Humanoid.PlatformStand = false
		held.Humanoid.AutoRotate = true
		held = nil
	end
end

-- Stand the frozen avatar back up (new run, or back at the top).
function RunAvatar.Recover()
	local state = fallen
	if not state then
		return
	end
	fallen = nil
	state.Root.Anchored = false
	state.Humanoid.WalkSpeed, state.Humanoid.JumpHeight = state.Walk, state.Jump
	state.Humanoid.PlatformStand, state.Humanoid.AutoRotate = false, true
	local at = state.Root.Position
	state.Root.CFrame = CFrame.new(at + Vector3.new(0, 2, 0)) * CFrame.Angles(0, select(2, state.Root.CFrame:ToEulerAnglesYXZ()), 0)
	-- The default Animate script misses the "stopped" event after all the PlatformStand time and keeps the run animation
	-- on a standing avatar: clear its tracks and restart it so it begins again from idle.
	local animator = state.Humanoid:FindFirstChildOfClass("Animator")
	local animate = state.Humanoid.Parent and state.Humanoid.Parent:FindFirstChild("Animate")
	if animator and animate and animate:IsA("LocalScript") then
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop(0.1)
		end
		animate.Enabled = false
		task.defer(function()
			animate.Enabled = true
		end)
	end
end

function RunAvatar.Fall()
	if not held then
		return
	end
	local humanoid, root = held.Humanoid, held.Root
	held.Track:Stop(0.05)
	held = nil
	fallen = { Humanoid = humanoid, Root = root, Walk = humanoid.WalkSpeed, Jump = humanoid.JumpHeight }
	humanoid.WalkSpeed, humanoid.JumpHeight = 0, 0
	local state = fallen
	-- Ground under the avatar (the log is gone): tip forward about the feet until the face is on the ground.
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { root.Parent }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -60, 0), params)
	local ground = if hit then hit.Position else root.Position - Vector3.new(0, 6, 0)
	local normal = if hit then hit.Normal else Vector3.yAxis
	local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	forward = if forward.Magnitude > 0.01 then forward.Unit else Vector3.new(0, 0, -1)
	forward = (forward - normal * forward:Dot(normal)).Unit -- along the surface
	-- the final pose lies on the surface: face (look) into it, head (up) toward the direction it was travelling
	local lying = CFrame.fromMatrix(ground + normal * LIE, forward:Cross(normal), forward, normal)
	local standing = CFrame.fromMatrix(ground + normal * (humanoid.HipHeight + root.Size.Y / 2), forward:Cross(normal), normal, -forward)
	local startPos, startRot = root.Position, root.CFrame.Rotation
	local began = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if fallen ~= state then
			connection:Disconnect()
			return
		end
		local alpha = math.clamp((os.clock() - began) / FALL.Time, 0, 1)
		local tip = alpha * alpha -- accelerates like a real fall
		local settle = math.min(alpha * 2.2, 1) -- first drops off the log's height to the ground, then tips over
		local base = standing:Lerp(lying, tip)
		root.CFrame = CFrame.new(startPos:Lerp(base.Position, settle)) * startRot:Lerp(base.Rotation, settle)
		root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
		if alpha >= 1 then
			root.Anchored = true
			connection:Disconnect()
		end
	end)
end

Players.LocalPlayer:GetAttributeChangedSignal("Fallen"):Connect(function()
	if not Players.LocalPlayer:GetAttribute("Fallen") then
		RunAvatar.Recover()
	end
end)

return RunAvatar
