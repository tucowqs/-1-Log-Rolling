--[[
	GuidePointer — the guiding arrows: a beam of scrolling chevrons from the avatar's feet to a target part plus a bouncing
	marker over it (look and numbers: TutorialConfig.Arrow / Marker). Used by the tutorial and the post-rebirth treadmill guide.
	  GuidePointer.new(name)
	  pointer:Update(target?, text?, icon?)   call every frame: a part points at it (marker text, Marker.Icons key), nil hides it.
	                                          Both hide while the avatar stands on the target.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.TutorialConfig)
local Ui = require(script.Parent.Ui)

local GuidePointer = {}
GuidePointer.__index = GuidePointer

local player = Players.LocalPlayer

function GuidePointer.new(name: string)
	local A, M = Config.Arrow, Config.Marker
	local self = setmetatable({ Name = name }, GuidePointer)
	local point = Ui.Make("Part", { Name = name .. "Point", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
		Transparency = 1, Size = Vector3.one, Parent = workspace })
	self.End = Ui.Make("Attachment", { Parent = point })
	self.Beam = Ui.Make("Beam", {
		Texture = A.Texture, TextureMode = Enum.TextureMode.Wrap, TextureLength = A.Spacing, TextureSpeed = A.Speed,
		Color = ColorSequence.new(A.Color), Width0 = A.Width, Width1 = A.Width, FaceCamera = true,
		Transparency = NumberSequence.new(0), LightEmission = A.LightEmission, Segments = 1, Enabled = false,
		Attachment1 = self.End, Parent = point, -- you (Attachment0) -> the target
	})
	self.Marker = Ui.Make("BillboardGui", { Name = name .. "Marker", Size = UDim2.fromOffset(M.Size.X, M.Size.Y), AlwaysOnTop = true, Enabled = false,
		Parent = player:WaitForChild("PlayerGui") })
	self.Icon = Ui.Make("ImageLabel", { Size = UDim2.fromScale(1, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit, Image = M.Icons.Down, Parent = self.Marker })
	self.Text = Ui.Label({ Size = UDim2.fromScale(1, 0.45), Text = M.Text, Title = true, MaxSize = 48, TextColor3 = M.Color, Parent = self.Marker })
	return self
end

local function standingOn(part: BasePart, root: BasePart): boolean
	local at = part.CFrame:PointToObjectSpace(root.Position)
	return math.abs(at.X) <= part.Size.X / 2 and math.abs(at.Z) <= part.Size.Z / 2
end

function GuidePointer:Update(target: BasePart?, text: string?, icon: string?)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local on = target ~= nil and root ~= nil and not standingOn(target, root)
	self.Beam.Enabled, self.Marker.Enabled = on, on
	if not on then
		return
	end
	local A, M = Config.Arrow, Config.Marker
	self.Text.Text = text or M.Text
	self.Icon.Image = M.Icons[icon or "Down"]
	local attachment = root:FindFirstChild(self.Name .. "Beam") or Ui.Make("Attachment", { Name = self.Name .. "Beam", Parent = root })
	-- the beam starts a few studs ahead of the avatar (toward the target), so the avatar never hides it
	local flat = Vector3.new(target.Position.X - root.Position.X, 0, target.Position.Z - root.Position.Z)
	local ahead = if flat.Magnitude > A.Lead then flat.Unit * A.Lead else flat
	attachment.Position = root.CFrame:VectorToObjectSpace(ahead) + Vector3.new(0, -A.FootOffset, 0)
	self.Beam.Attachment0 = attachment
	self.End.WorldPosition = target.Position + Vector3.new(0, target.Size.Y / 2 + A.Lift, 0)
	self.Marker.Adornee = target
	self.Marker.StudsOffsetWorldSpace = Vector3.new(0, target.Size.Y / 2 + M.Lift + math.abs(math.sin(os.clock() * M.BounceSpeed)) * M.Bounce, 0)
end

return GuidePointer
