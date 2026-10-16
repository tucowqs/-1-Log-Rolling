--[[
	SceneryController — streams and pools the hill's scenery on this client (WorldPlan: bumps, ramps, trees, rocks, area
	landmarks, gates, the training racks). Only items within World.Behind / World.Ahead studs of the camera (measured
	along the slope) exist; models leaving the window go back to a per-model pool and come out again further down, so
	a hill with ~1500 items costs a few hundred live models. Models are the Blender assets (AssetLibrary); an item whose
	model isn't built yet simply waits for the next tick. Obstacles are tinted per area, gates carry the area name.
	The bumps / ramps are this client's own random field (RunLayout): when it is rerolled the live ones go back to the pool and the new field streams in.
	Worlds: on the ClientState "World" event everything live goes back to the pool and WorldPlan is rebuilt for that world's zones
	(Track.Offset already points at it), so the scenery streams in again there.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetLibrary = require(ReplicatedStorage.Shared.Modules.AssetLibrary)
local Config = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)
local Track = require(ReplicatedStorage.Shared.Modules.Track)
local WorldPlan = require(ReplicatedStorage.Shared.Modules.WorldPlan)
local Worlds = require(ReplicatedStorage.Shared.Modules.Worlds)
local ClientState = require(script.Parent.Parent.State.ClientState)
local RunLayout = require(script.Parent.Parent.Run.RunLayout)

local SceneryController = {}

local W = Config.World
local FAR = { Landmark = 2.2, Gate = 1.6 } -- big pieces are kept alive further ahead
local items = WorldPlan.Items -- the fixed scenery plus the current ramp field, sorted by S
local active: { [any]: Model } = {}
local pool: { [string]: { Model } } = {}
local folder: Folder

local function tint(model: Model, area)
	for _, part in model:GetChildren() do
		if part.Name == "Main" then
			(part :: BasePart).Color = area.Obstacle.Main
		elseif part.Name == "Trim" or part.Name == "Accent" then
			(part :: BasePart).Color = if part.Name == "Trim" then area.Obstacle.Trim else area.Accent
		end
	end
end

-- The roll sign's board: the pack's 3D gradient title + a smaller hint, on both faces of SignFace (W.Sign).
local function sign(model: Model, text: string)
	local face = model:FindFirstChild("SignFace") :: BasePart?
	if not face or face:FindFirstChild("TextFront") then
		return
	end
	for _, side in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Name, gui.Face, gui.SizingMode, gui.PixelsPerStud, gui.LightInfluence = "Text" .. side.Name, side, Enum.SurfaceGuiSizingMode.PixelsPerStud, 30, 0
		gui.Parent = face
		for _, line in { { text, W.Sign.Title, 0.42, 0.72 }, { W.Sign.Hint, "White", 0.86, 0.24 } } do
			local label = UiPack.Get("StatText")
			label.Size, label.Position, label.AnchorPoint = UDim2.fromScale(0.94, line[4]), UDim2.fromScale(0.5, line[3]), Vector2.new(0.5, 0.5)
			for _, layer in { label, label:FindFirstChild("Color") } do
				layer.TextXAlignment = Enum.TextXAlignment.Center
			end
			label.Parent = gui
			UiPack.Text(label, line[1])
			UiPack.TextGradient(label, line[2])
		end
	end
end

local function spawn(item): Model?
	local list = pool[item.Model]
	local model = if list and #list > 0 then table.remove(list) else AssetLibrary.Get(item.Model)
	if not model then
		return nil
	end
	model:ScaleTo(item.Scale)
	if (item.Kind == "Obstacle" and item.Model ~= "SuperRamp" and item.Model ~= "HyperRamp") or item.Kind == "Gate" then -- the Super Ramp keeps its own gold look
		tint(model, Worlds.Area(WorldPlan.World, item.Area))
	end
	if item.Text then
		sign(model, item.Text)
	end
	model:PivotTo(WorldPlan.Frame(item))
	model.Parent = folder
	return model
end

local function release(item, model: Model)
	model.Parent = nil
	pool[item.Model] = pool[item.Model] or {}
	table.insert(pool[item.Model], model)
end

local function refresh()
	local camera = workspace.CurrentCamera
	local s = Track.SFromZ(camera.CFrame.Position.Z)
	local wanted = {}
	for _, item in items do
		local far = FAR[item.Kind] or 1
		if item.S >= s - W.Behind and item.S <= s + W.Ahead * far then
			wanted[item] = true
			if not active[item] then
				active[item] = spawn(item)
			end
		elseif item.S > s + W.Ahead * far * 1.3 then
			break -- the list is sorted by S
		end
	end
	for item, model in active do
		if not wanted[item] then
			release(item, model)
			active[item] = nil
		end
	end
end

-- A new ramp field: drop the old obstacles (back to the pool) and merge the new ones into the sorted list.
local function swapField(field)
	for item, model in active do
		if item.Kind == "Obstacle" then
			release(item, model)
			active[item] = nil
		end
	end
	items = table.clone(WorldPlan.Items)
	for _, item in WorldPlan.Obstacles(field) do
		table.insert(items, item)
	end
	table.sort(items, function(a, b)
		return a.S < b.S
	end)
	refresh()
end

function SceneryController.Start()
	folder = Instance.new("Folder")
	folder.Name = "Scenery"
	folder.Parent = workspace
	swapField(RunLayout.Field())
	RunLayout.OnChange(swapField)
	ClientState.On("World", function(w)
		for item, model in active do
			release(item, model)
		end
		table.clear(active)
		WorldPlan.Build(w)
		swapField(RunLayout.Field())
	end)
	task.spawn(function() -- a loop inside Start would read as a HANGING Start
		while true do
			refresh()
			task.wait(W.Tick)
		end
	end)
end

return SceneryController
