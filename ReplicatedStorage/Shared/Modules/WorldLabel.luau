--[[
	WorldLabel — marks a BillboardGui as a world label of a UIConfig.WorldLabels kind: its size in
	studs and the Near distance it stops growing at go on as attributes, plus the "WorldLabel" tag
	the client's WorldLabelController sizes each frame. Used by the builder and the server.
]]
local CollectionService = game:GetService("CollectionService")

local WorldLabel = {}

WorldLabel.Tag = "WorldLabel"

function WorldLabel.Apply(gui: BillboardGui, spec)
	gui.Size = UDim2.fromScale(spec.Size.X, spec.Size.Y) -- until the client sizes it
	gui:SetAttribute("WorldSize", spec.Size)
	gui:SetAttribute("Near", spec.Near)
	CollectionService:AddTag(gui, WorldLabel.Tag)
	return gui
end

return WorldLabel
