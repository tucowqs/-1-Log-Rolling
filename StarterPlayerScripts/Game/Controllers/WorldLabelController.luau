--[[
	WorldLabelController — sizes every "WorldLabel" billboard (WorldLabel module) in screen pixels
	each frame as if it were a real sign of WorldSize studs, but measured from no closer than its
	Near distance: far away it shrinks like an object in the world, up close it stops growing.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WorldLabel = require(ReplicatedStorage.Shared.Modules.WorldLabel)

local WorldLabelController = {}

local function place(gui: BillboardGui): Vector3?
	local adornee = gui.Adornee or gui.Parent
	if adornee and adornee:IsA("BasePart") then
		return adornee.Position + gui.StudsOffsetWorldSpace
	elseif adornee and adornee:IsA("Attachment") then
		return adornee.WorldPosition + gui.StudsOffsetWorldSpace
	end
	return nil
end

local function update()
	local camera = workspace.CurrentCamera
	local eye = camera.CFrame.Position
	-- Pixels one stud covers at 1 stud away; divide by distance for any other distance.
	local pxPerStud = camera.ViewportSize.Y / (2 * math.tan(math.rad(camera.FieldOfView) / 2))
	for _, gui in CollectionService:GetTagged(WorldLabel.Tag) do
		local at = gui.Enabled and place(gui)
		local size = gui:GetAttribute("WorldSize")
		if at and size then
			local distance = (at - eye).Magnitude
			if distance <= gui.MaxDistance then
				local scale = pxPerStud / math.max(distance, gui:GetAttribute("Near") or 0)
				gui.Size = UDim2.fromOffset(size.X * scale, size.Y * scale)
			end
		end
	end
end

function WorldLabelController.Start()
	RunService.RenderStepped:Connect(update)
end

return WorldLabelController
