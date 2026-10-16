--[[
	SurfaceTextController — every text on a SurfaceGui in the world (island signs, plaques, chest
	pad signs, zone signs, owner boards...) gets the same semi-thick outline: a UIStroke sized as a
	fraction of the text (StrokeSizingMode ScaledSize, UIConfig.SurfaceText.Stroke), so big and
	small text read alike. Existing strokes keep their colour; old-style TextStroke is swapped for
	one. Covers signs made at runtime too (watches the workspace).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIConfig = require(ReplicatedStorage.Shared.Config.UIConfig)

local SurfaceTextController = {}

local function style(text: Instance)
	if not (text:IsA("TextLabel") or text:IsA("TextButton") or text:IsA("TextBox")) then
		return
	end
	if not text:FindFirstAncestorWhichIsA("SurfaceGui") then
		return
	end
	local stroke
	for _, child in text:GetChildren() do
		if child:IsA("UIStroke") and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
			stroke = child
		end
	end
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Color = text.TextStrokeTransparency < 1 and text.TextStrokeColor3 or Color3.new(0, 0, 0)
		stroke.Parent = text
	end
	text.TextStrokeTransparency = 1
	stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	stroke.Thickness = UIConfig.SurfaceText.Stroke
	stroke.LineJoinMode = Enum.LineJoinMode.Round
end

function SurfaceTextController.Start()
	workspace.DescendantAdded:Connect(function(thing)
		task.defer(style, thing) -- after its own setup (a sign's script may add its stroke right after)
	end)
	for _, thing in workspace:GetDescendants() do
		style(thing)
	end
end

return SurfaceTextController
