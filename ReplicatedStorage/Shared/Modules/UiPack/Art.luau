--[[
	UiPack/Art — item art placed where the pack shows an item image (card icons, day cards, index cells):
	real 3D models in a ViewportFrame, or a single icon image, on the pack's spinning sunburst rays.
	Viewports turn / swing from ONE Heartbeat loop, only for groups switched on with SetActive (the open
	page of an open window), so closed windows cost nothing. Knobs: UiPackConfig.Art.
	  Art.new(parent, spec, props) -> holder    props: Size, Position, AnchorPoint, ZIndex, Group
	    spec.Models = { { Path = "ShopArt.Chest", Count = 3, Size = 1.6, Tint = Color3?, Front = true? }, ... }
	    spec.Model  = Model (an already-built model, e.g. a character built by game code)
	    spec.Image  = "rbxassetid://..."     spec.Rays = Color3 (tint of the rays; nil = no rays)
	    spec.Spin   = "Turn" | "Swing" | nil
	  Art.Replace(icon, spec, group?) -> holder   puts art exactly where a pack ImageLabel was and hides it (with
	                                              spec.Rays it also hides the frame's static pack rays: one ray layer)
	  Art.SetActive(group, on)
	  Art.Silhouette(holder, on)                  black silhouette (undiscovered index entries)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.UiPackConfig)
local Ui = require(ReplicatedStorage.Shared.Modules.Ui)

local Art = {}

local A = Config.Art
local active: { [any]: boolean } = {}
local spinning: { [Camera]: any } = {}
local rays: { ImageLabel } = {}

function Art.SetActive(group: any, on: boolean)
	active[group] = on or nil
end

local function find(path: string): Instance?
	local node: Instance? = ReplicatedStorage:FindFirstChild(A.Assets)
	for name in path:gmatch("[^%.]+") do
		node = node and node:FindFirstChild(name)
	end
	return node
end

-- A clean, anchored copy scaled so its longest side is `size` studs.
local function prepare(model: Model, size: number?, tint: Color3?): Model
	for _, item in model:GetDescendants() do
		if item:IsA("LuaSourceContainer") or item:IsA("ParticleEmitter") or item:IsA("Sound") or item:IsA("Light") or item:IsA("LayerCollector") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = true
			if tint and not item.Name:match(A.TintSkip) then
				item.Color = tint
			end
		end
	end
	if size then
		local _, extent = model:GetBoundingBox()
		model:ScaleTo(model:GetScale() * size / math.max(extent.X, extent.Y, extent.Z))
	end
	return model
end

local function place(model: Model, cf: CFrame)
	local box = model:GetBoundingBox()
	model:PivotTo(cf * box:ToObjectSpace(model:GetPivot()))
end

-- A little pyramid of models (bottom row first, higher rows set back); Front ones stand before it.
local function pile(units, world: Model)
	local n, unit = 0, 0
	for _, u in units do
		n += if u.Front then 0 else 1
		unit = math.max(unit, if u.Front then 0 else u.Size)
	end
	local rows = 1
	while rows * (rows + 1) / 2 < n do
		rows += 1
	end
	local random = Random.new(n)
	local row, col, count = 0, 0, rows
	for _, u in units do
		local source = find(u.Path)
		if source and source:IsA("Model") then
			local model = prepare(source:Clone(), u.Size, u.Tint)
			if u.Front then
				place(model, CFrame.new(0, u.Size * 0.5, -unit * 0.95))
			else
				local x = (col - (count - 1) / 2) * unit * 1.04
				place(model, CFrame.new(x, unit * (0.5 + row * 0.86), row * unit * 0.3) * CFrame.Angles(0, math.rad(random:NextNumber(-22, 22)), 0))
				col += 1
				if col >= count then
					row, col, count = row + 1, 0, math.max(count - 1, 1)
				end
			end
			model.Parent = world
		else
			warn("[UiPack.Art] no model at Assets." .. u.Path)
		end
	end
end

local function aim(camera: Camera, s, yaw: number)
	local pitch = math.rad(A.Pitch)
	local dir = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch))
	camera.CFrame = CFrame.lookAt(s.Center + dir * s.Distance, s.Center)
end

local function viewport(holder: Frame, spec, props)
	local view = Ui.Make("ViewportFrame", { Name = "Viewport", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(175, 175, 175), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-0.5, -1, 0.7),
		ZIndex = holder.ZIndex + 1, Parent = holder })
	local world = Ui.Make("Model", { Name = "Pile", Parent = view })
	if spec.Model then
		prepare(spec.Model).Parent = world
	else
		local units = {}
		for _, entry in spec.Models do
			for _ = 1, entry.Count or 1 do
				table.insert(units, { Path = entry.Path, Size = entry.Size or 2, Tint = entry.Tint, Front = entry.Front })
			end
		end
		pile(units, world)
	end
	local box, extent = world:GetBoundingBox()
	local half = math.tan(math.rad(A.Fov / 2))
	local wide = if spec.Spin == "Turn" then math.max(extent.X, extent.Z) else extent.X
	local s = { Center = box.Position, Mode = spec.Spin, Group = props.Group, Phase = math.random() * 6,
		Distance = math.max(extent.Y / 2 / half, wide / 2 / half) * 1.25 + math.max(extent.X, extent.Z) / 2 }
	local camera = Ui.Make("Camera", { FieldOfView = A.Fov, Parent = view })
	view.CurrentCamera = camera
	aim(camera, s, 0)
	if spec.Spin then
		spinning[camera] = s
	end
end

function Art.new(parent: Instance, spec, props): Frame
	local z = props.ZIndex or 2
	local holder = Ui.Make("Frame", { Name = "Art", Size = props.Size, Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero, BackgroundTransparency = 1, ZIndex = z, Parent = parent })
	Ui.Make("UIAspectRatioConstraint", { AspectRatio = 1, Parent = holder })
	if spec.Rays then
		table.insert(rays, Ui.Make("ImageLabel", { Name = "Rays", Image = Config.Icons.Rays, ImageColor3 = spec.Rays, BackgroundTransparency = 1,
			ImageTransparency = A.RaysTransparency, Size = UDim2.fromScale(1.35, 1.35), Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = z, Parent = holder }))
	end
	if spec.Model then
		viewport(holder, spec, props)
	elseif spec.Models then
		task.spawn(function() -- server-built models (AssetLibrary) may not have replicated yet: draw once they all exist
			for _ = 1, 240 do
				local missing = false
				for _, entry in spec.Models do
					missing = missing or find(entry.Path) == nil
				end
				if not missing then
					return holder.Parent and viewport(holder, spec, props)
				end
				task.wait(0.5)
			end
			viewport(holder, spec, props) -- still missing after 2 minutes: draw what exists (pile() warns)
		end)
	end
	if spec.Image then
		Ui.Make("ImageLabel", { Name = "Image", Image = spec.Image, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(1, 1), ZIndex = z + 1, Parent = holder })
	end
	return holder
end

-- ONE ray layer per frame: art that brings its own spinning rays hides the pack's static ones beside it.
local function hideStaticRays(frame: Instance)
	for _, item in frame:GetDescendants() do
		if item:IsA("ImageLabel") and item.Image == Config.Icons.Rays and item.Name ~= "Rays" then
			item.Visible = false
		end
	end
end

function Art.Replace(icon: GuiObject, spec, group: any?): Frame
	icon.Visible = false
	if spec.Rays then
		hideStaticRays(icon.Parent :: Instance)
	end
	local holder = Art.new(icon.Parent :: Instance, spec, { Size = icon.Size, Position = icon.Position, AnchorPoint = icon.AnchorPoint,
		ZIndex = icon.ZIndex, Group = group })
	holder.Name = icon.Name .. "Art"
	return holder
end

function Art.Silhouette(holder: Frame, on: boolean)
	local view = holder:FindFirstChild("Viewport") :: ViewportFrame?
	if view then
		local black = Color3.new(0, 0, 0)
		view.ImageColor3 = if on then black else Color3.new(1, 1, 1)
		view.Ambient = if on then black else Color3.fromRGB(175, 175, 175)
		view.LightColor = if on then black else Color3.new(1, 1, 1)
	end
end

RunService.Heartbeat:Connect(function()
	local t = os.clock()
	for camera, s in spinning do
		if not camera.Parent then
			spinning[camera] = nil
		elseif s.Group == nil or active[s.Group] then
			aim(camera, s, if s.Mode == "Turn" then t * A.Turn + s.Phase else math.rad(A.Swing[1]) * math.sin(t * A.Swing[2] + s.Phase))
		end
	end
	local angle = (t * 360 / A.RaysSpin) % 360
	for i = #rays, 1, -1 do
		if rays[i].Parent then
			rays[i].Rotation = angle
		else
			table.remove(rays, i)
		end
	end
end)

return Art
