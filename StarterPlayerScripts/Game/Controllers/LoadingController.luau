--[[
	LoadingController — the join loading screen (LoadingConfig). Main starts it first thing: a strong blur over the world, every
	other ScreenGui held disabled (also the ones created later: they are caught as they appear), and an animated
	"Loading game..." label, until the whole lobby is in: the save, the character, the lobby's folders (walls, cliffs, hatchery,
	...) preloaded, the lobby's Blender models, and the egg podiums' eggs. Then the label scales out, the blur fades, the UI
	comes back and the held-back toasts play.
	  LoadingController.Active() -> boolean
	  LoadingController.WhenDone(fn)   run fn once loading is complete (right away if it already is)
]]
local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local AssetGroups = require(ReplicatedStorage.Shared.Modules.AssetGroups)
local AssetLibrary = require(ReplicatedStorage.Shared.Modules.AssetLibrary)
local C = require(ReplicatedStorage.Shared.Config.LoadingConfig)
local PetsConfig = require(ReplicatedStorage.Shared.Config.PetsConfig)
local Ui = require(ReplicatedStorage.Shared.Modules.Ui)

local LoadingController = {}

local player = Players.LocalPlayer
local started = false
local active = false
local callbacks: { () -> () } = {}
local held: { [ScreenGui]: { Want: boolean, Conn: RBXScriptConnection } } = {}
local coreHidden: { Enum.CoreGuiType } = {}

function LoadingController.Active(): boolean
	return active
end

function LoadingController.WhenDone(callback: () -> ())
	if active then
		table.insert(callbacks, callback)
	else
		task.spawn(callback)
	end
end

-- Disable a ScreenGui (remembering whether it wanted to be on); if something turns it back on while loading, it is switched off again.
local function hold(gui: Instance)
	if not gui:IsA("ScreenGui") or held[gui] or gui.Name == "Loading" then
		return
	end
	local entry = { Want = gui.Enabled, Conn = nil :: any }
	held[gui] = entry
	gui.Enabled = false
	entry.Conn = gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if active and gui.Enabled then
			entry.Want = true
			gui.Enabled = false
		end
	end)
end

local function releaseAll()
	for gui, entry in held do
		entry.Conn:Disconnect()
		if gui.Parent then
			gui.Enabled = entry.Want
		end
	end
	table.clear(held)
	for _, kind in coreHidden do
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, kind, true)
	end
	table.clear(coreHidden)
end

local function waitUntil(condition: () -> boolean, deadline: number)
	while not condition() and os.clock() < deadline do
		task.wait(C.Poll)
	end
end

-- The Blender models the lobby needs, in AssetGroups order.
local function lobbyAssets(): { string }
	local wanted, names, seen = {}, {}, {}
	for _, name in C.Groups do
		wanted[name] = true
	end
	for _, group in AssetGroups() do
		if wanted[group.Name] then
			for _, name in group.List do
				if not seen[name] then
					seen[name] = true
					table.insert(names, name)
				end
			end
		end
	end
	return names
end

local function eggStands(): number
	local count = 0
	for _, def in PetsConfig.Eggs do
		if not def.Shop then
			count += 1
		end
	end
	return count
end

-- Everything the lobby needs, or the deadline. All the checks run side by side (the wait is the slowest one, not their
-- sum): each folder starts preloading the moment it exists, while the save, character, models and eggs arrive.
local function waitForLobby(deadline: number)
	local roots: { Instance } = { MaterialService }
	local started: { [string]: boolean } = {}
	local preloading = 0
	local function preload(list: { Instance })
		preloading += 1
		task.spawn(function()
			pcall(ContentProvider.PreloadAsync, ContentProvider, list)
			preloading -= 1
		end)
	end
	preload({ MaterialService })

	local assets = lobbyAssets()
	local nextAsset = 1
	local need = eggStands() * 2 -- EggController puts each podium's egg and pad into HatcheryFx
	waitUntil(function()
		local ready = true
		for _, name in C.Folders do
			if not started[name] then
				local folder = workspace:FindFirstChild(name)
				if folder then
					started[name] = true
					table.insert(roots, folder)
					preload({ folder })
				else
					ready = false
				end
			end
		end
		while assets[nextAsset] and AssetLibrary.Ready(assets[nextAsset]) do
			nextAsset += 1
		end
		if assets[nextAsset] or not ready then
			return false
		end
		local character = player.Character
		local fx = workspace:FindFirstChild("HatcheryFx")
		return game:IsLoaded()
			and player:GetAttribute("Loaded") == true
			and character ~= nil and character:FindFirstChild("HumanoidRootPart") ~= nil
			and fx ~= nil and #fx:GetChildren() >= need
			and preloading == 0
	end, deadline)

	-- One last pass over everything: props the controllers dropped in after a folder's first preload get fetched too
	-- (whatever is already downloaded returns at once), so the screen never lifts on half-loaded content.
	preload(roots)
	waitUntil(function()
		return preloading == 0
	end, deadline)
end

function LoadingController.Start()
	if started then
		return
	end
	started = true
	active = true

	local blur = Instance.new("BlurEffect")
	blur.Name, blur.Size, blur.Parent = "LoadingBlur", C.Blur, Lighting

	local screen = Ui.Screen("Loading", C.DisplayOrder)
	screen.IgnoreGuiInset = true
	local holder = Ui.Make("Frame", { Size = UDim2.fromOffset(1000, 200), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1, Parent = screen })
	Ui.Fit(holder)
	local content = Ui.Make("Frame", { Name = "Content", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = holder })
	local grow = Ui.Make("UIScale", { Name = "Grow", Scale = 0, Parent = content })
	Ui.Make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = content })

	local size = C.FontSize
	local function text(props)
		local label = Ui.Label(props)
		label.TextScaled, label.TextSize = false, size
		label:FindFirstChildOfClass("UIStroke").Thickness = C.Stroke
		return label
	end
	text({ Name = "Word", Size = UDim2.fromOffset(0, size), AutomaticSize = Enum.AutomaticSize.X, Text = C.Text, Title = true,
		LayoutOrder = 0, Parent = content })
	local dots = {}
	for index = 1, 3 do
		local cell = Ui.Make("Frame", { Name = "Dot" .. index, Size = UDim2.fromOffset(size * C.DotWidth, size), BackgroundTransparency = 1,
			LayoutOrder = index, Parent = content })
		table.insert(dots, text({ Name = "Dot", Size = UDim2.fromScale(1, 1), Text = ".", Title = true, Parent = cell }))
	end
	Ui.Tween(grow, C.In, { Scale = 1 }, Enum.EasingStyle.Back)

	-- The dots hop one after the other (always fully opaque).
	local begin = os.clock()
	local dance = RunService.RenderStepped:Connect(function()
		local t = os.clock() - begin
		for index, dot in dots do
			local wave = math.max(0, math.sin((t * C.DotSpeed - (index - 1) * C.DotLag) * math.pi * 2))
			dot.Position = UDim2.fromOffset(0, -size * C.DotHop * wave)
		end
	end)

	-- Hide every other screen, now and as they appear.
	local playerGui = player:WaitForChild("PlayerGui")
	for _, child in playerGui:GetChildren() do
		hold(child)
	end
	local added = playerGui.ChildAdded:Connect(hold)
	for _, name in C.CoreGui do
		local kind = Enum.CoreGuiType[name]
		local ok, on = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, kind)
		if ok and on then
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, kind, false)
			table.insert(coreHidden, kind)
		end
	end

	task.spawn(function()
		local deadline = os.clock() + C.MaxTime
		waitForLobby(deadline)
		task.wait(math.max(C.Settle, begin + C.MinTime - os.clock()))

		-- Text out, then the blur fades while the UI and the held-back toasts come back.
		Ui.Tween(grow, C.Out, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Wait()
		dance:Disconnect()
		added:Disconnect()
		active = false
		local fade = Ui.Tween(blur, C.Unblur, { Size = 0 })
		releaseAll()
		for _, callback in callbacks do
			task.spawn(callback)
		end
		table.clear(callbacks)
		fade.Completed:Wait()
		blur:Destroy()
		screen:Destroy()
	end)
end

return LoadingController
