--[[
	HatchController — the egg hatching reveal (+1 Rock Skipping's). The server answers a hatch with "PetHatched" { Egg, Pets }
	(also after a Robux egg purchase); this plays it:
	  1. the world blurs and dims, the HUD hides, the eggs drop in (one big egg, or a grid of up to 16) and wobble while
	     "Click to hatch (N)" waits for a click anywhere
	  2. the click shakes them harder in quick stages, a white flash, and each egg becomes its pet (3D model on rarity rays)
	     with its name, its chance in % and its bonus (lightning +Mult)
	  3. "Click to continue" closes it (the pets shrink away, the blur and HUD come back)
	While EggController's Auto hatching is on (HatchController.SetAuto) nothing waits for clicks: each wait is AutoHold seconds.
	Numbers: PetsConfig.Hatch.
	  HatchController.Busy() -> boolean    true while a reveal plays (EggController blocks new hatches)
	  HatchController.SetAuto(on)
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AssetLibrary = require(ReplicatedStorage.Shared.Modules.AssetLibrary)
local Config = require(ReplicatedStorage.Shared.Config.PetsConfig)
local IconPick = require(ReplicatedStorage.Shared.Modules.IconPick)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local PetMath = require(ReplicatedStorage.Shared.Modules.PetMath)
local Ui = require(ReplicatedStorage.Shared.Modules.Ui)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)

local HatchController = {}

local H = Config.Hatch
local T = Config.Text
local GROUP = "Hatch"
local player = Players.LocalPlayer
local queue = {}
local busy, auto = false, false
local screen: ScreenGui
local blur: BlurEffect

function HatchController.Busy(): boolean
	return busy
end

function HatchController.SetAuto(on: boolean)
	auto = on
end

local function over(time: number, fn)
	local t = 0
	while t < time do
		fn(t / time)
		t += RunService.Heartbeat:Wait()
	end
	fn(1)
end

local function line(parent: Instance, text: string, kind: string?, y: number, h: number): TextLabel
	local item = UiPack.Get("StatText")
	item.Size, item.Position, item.AnchorPoint, item.Parent = UDim2.fromScale(1.6, h), UDim2.fromScale(0.5, y), Vector2.new(0.5, 0.5), parent
	for _, layer in { item, item:FindFirstChild("Color") } do
		layer.TextXAlignment = Enum.TextXAlignment.Center
	end
	UiPack.Text(item, text)
	UiPack.TextGradient(item, kind)
	return item
end

-- Waits for a click on the reveal (or AutoHold seconds while auto hatching), showing `text` at the bottom.
local function waitClick(root: Frame, prompt: TextLabel, text: string)
	UiPack.Text(prompt, text)
	prompt.Visible = true
	if auto then
		task.wait(H.AutoHold)
	else
		local clicked = false
		local hit = Ui.Make("TextButton", { Name = "Hit", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 300, Parent = root })
		hit.Activated:Connect(function()
			clicked = true
		end)
		while not clicked and root.Parent do
			task.wait()
		end
		hit:Destroy()
	end
	prompt.Visible = false
end

-- Egg slots: 1 big egg, or a grid whose column count gives the biggest eggs that still fit the screen (so 16 eggs fill most of it).
-- Each slot is a square holder sized by screen height.
local function slots(root: Frame, egg, count: number)
	local G = H.Grid
	local viewport = workspace.CurrentCamera.ViewportSize
	local perRow, size = 1, H.Size
	if count > 1 then
		size = 0
		for cols = 1, count do
			local fit = math.min(H.MultiSize, G.Width * viewport.X / viewport.Y / (cols * G.CellW), G.Height / (math.ceil(count / cols) * G.CellH))
			if fit > size then
				perRow, size = cols, fit
			end
		end
	end
	local rows = math.ceil(count / perRow)
	local list = {}
	for index = 1, count do
		local col, row = (index - 1) % perRow, (index - 1) // perRow
		local inRow = math.min(perRow, count - row * perRow)
		local x = (col - (inRow - 1) / 2) * size * (if count == 1 then 1 else G.CellW) * viewport.Y
		local y = (if count == 1 then 0.44 else G.Y) + (row - (rows - 1) / 2) * size * G.CellH
		local holder = Ui.Make("Frame", { Name = "Slot" .. index, SizeConstraint = Enum.SizeConstraint.RelativeYY, Size = UDim2.fromScale(size, size),
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, x, -0.4, 0), BackgroundTransparency = 1, Parent = root })
		local art = UiPack.Art.new(holder, { Model = AssetLibrary.Get(egg.Model) }, { Size = UDim2.fromScale(1, 1), Group = GROUP })
		art.AnchorPoint, art.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
		list[index] = { Holder = holder, Art = art, X = x, Y = y, Scale = Ui.Make("UIScale", { Parent = holder }) }
	end
	return list
end

local function shake(item, stage: number)
	local time, angle, swings = table.unpack(H.Shake[stage])
	local grow = 1 + 0.07 * stage
	over(time, function(a)
		item.Holder.Rotation = math.sin(a * swings * math.pi * 2) * angle * math.sin(a * math.pi) ^ 0.5
		item.Scale.Scale = 1 + (grow - 1) * a
	end)
	item.Holder.Rotation = 0
end

-- The idle wobble while waiting for the first click.
local function wobble(list, token)
	local t0 = os.clock()
	while token.On do
		local t = os.clock() - t0
		for i, item in list do
			item.Holder.Rotation = math.sin(t * H.Wobble.Speed + i) * H.Wobble.Angle
		end
		RunService.Heartbeat:Wait()
	end
end

local function reveal(root: Frame, egg, item, id: string)
	local def = PetMath.Pet(id)
	local rarity = Config.Rarities[def.Rarity]
	item.Art:Destroy()
	local art = UiPack.Art.new(item.Holder, { Model = AssetLibrary.Get(id), Rays = rarity.Rays, Spin = "Swing" },
		{ Size = UDim2.fromScale(H.PetSize, H.PetSize), Group = GROUP, ZIndex = 4 })
	art.AnchorPoint, art.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	local texts = Ui.Make("Frame", { Name = "Texts", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = item.Holder })
	line(texts, def.Name, rarity.Text, 0.5 - H.PetSize / 2 - 0.16, 0.2)
	line(texts, T.Chance:format(PetMath.Format(egg.Odds[id] or 0)), "White", 0.5 - H.PetSize / 2 - 0.03, 0.1)
	local bonus = if def.Better then T.Better:format(def.Better * 100) else T.Mult:format(PetMath.Format(def.Mult))
	local row = UiPack.StatRow(IconPick.Image("Boost"), "Green", { Size = UDim2.fromScale(0.8, 0.17), Position = UDim2.fromScale(0.5, 0.5 + H.PetSize / 2 + 0.08),
		AnchorPoint = Vector2.new(0.5, 0.5), Parent = texts })
	UiPack.Text(row.Amount, bonus)
	item.Scale.Scale = 0.2
	Ui.Tween(item.Scale, H.Pop, { Scale = 1 }, Enum.EasingStyle.Back)
	if rarity.Order >= 3 then
		UiPack.Celebrate.Play(root, { From = item.Holder, Images = { IconPick.Image("Paw") } })
	end
end

local function setHud(on: boolean)
	local gui = player:FindFirstChild("PlayerGui")
	for _, name in H.HideGuis do
		local item = gui and gui:FindFirstChild(name)
		if item and item:IsA("ScreenGui") then
			item.Enabled = on
		end
	end
	Ui.Tween(blur, 0.3, { Size = if on then 0 else H.Blur })
end

local function play(result)
	busy = true
	local egg = PetMath.Egg(result.Egg)
	local count = #result.Pets
	setHud(false)
	local root = Ui.Make("Frame", { Name = "Hatch", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Parent = screen })
	local white = Ui.Make("Frame", { Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = 250, Parent = root })
	local prompt = line(root, "", "White", 0.86, 0.06)
	prompt.Visible = false
	UiPack.Art.SetActive(GROUP, true)
	Ui.Tween(root, 0.3, { BackgroundTransparency = H.Dim })
	local list = slots(root, egg, count)
	for _, item in list do
		Ui.Tween(item.Holder, H.Drop, { Position = UDim2.new(0.5, item.X, item.Y, 0) }, Enum.EasingStyle.Bounce)
	end
	task.wait(H.Drop)
	local token = { On = true }
	task.spawn(wobble, list, token)
	waitClick(root, prompt, if count == 1 then T.ClickHatch else T.ClickHatchN:format(count))
	token.On = false
	for stage = 1, #H.Shake do
		for _, item in list do
			task.spawn(shake, item, stage)
		end
		task.wait(H.Shake[stage][1] + 0.03)
	end
	Ui.Tween(white, H.Flash * 0.4, { BackgroundTransparency = 0 })
	task.wait(H.Flash * 0.4)
	for index, item in list do
		reveal(root, egg, item, result.Pets[index])
	end
	Ui.Tween(white, H.Flash, { BackgroundTransparency = 1 })
	task.wait(H.Pop)
	waitClick(root, prompt, T.ClickContinue)
	for _, item in list do
		Ui.Tween(item.Scale, H.Out, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	end
	Ui.Tween(root, H.Out, { BackgroundTransparency = 1 })
	task.wait(H.Out)
	UiPack.Art.SetActive(GROUP, false)
	root:Destroy()
	if #queue == 0 then
		setHud(true)
	end
	busy = false
end

local function drain()
	while #queue > 0 do
		play(table.remove(queue, 1))
	end
end

function HatchController.Start()
	screen = UiPack.Screen("Hatch", 20)
	blur = Instance.new("BlurEffect")
	blur.Name, blur.Size, blur.Parent = "HatchBlur", 0, Lighting
	Net.Get("PetHatched"):Connect(function(result)
		table.insert(queue, result)
		if not busy then
			task.spawn(drain)
		end
	end)
end

return HatchController
