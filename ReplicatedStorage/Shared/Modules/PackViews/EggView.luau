--[[
	PackViews/EggView — the egg card over an egg podium (+1 Rock Skipping's): the egg's name, one pack cell per pet it can
	hatch (3D model on rarity rays, its chance in %), four to a row and centred, and the centred hatch buttons
	E Hatch / R Hatch xN (the most eggs the Wins cover, see EggController) / T Auto (green while on). A Robux egg
	shows one "E Buy" button with its Robux price. It is a BillboardGui in PlayerGui (so its pack buttons are clickable)
	adorned to the stand. No game logic.
	  EggView.new({ Egg = def, Adornee = BasePart, OnHatch = (count), OnMulti = (), OnAuto = () }) -> view
	  view:SetOpen(bool)   tweens the card up / down and the sign the other way; view.Title = the rarity + price sign
	  view:SetMulti(count)   the R button's count
	  view:SetAuto(on)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AssetLibrary = require(ReplicatedStorage.Shared.Modules.AssetLibrary)
local Config = require(ReplicatedStorage.Shared.Config.PetsConfig)
local IconPick = require(ReplicatedStorage.Shared.Modules.IconPick)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)
local PetMath = require(ReplicatedStorage.Shared.Modules.PetMath)
local Ui = require(ReplicatedStorage.Shared.Modules.Ui)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)
local WorldLabel = require(ReplicatedStorage.Shared.Modules.WorldLabel)

local T = Config.Text
local B = Config.World.Billboard
local COLS = 4
local CELL_W, GAP = 0.215, 0.02
local GRID_X = 0.5 -- the pet grid's centre
local GRID_TOP, GRID_BOTTOM = 0.15, 0.79 -- the band between the name and the buttons the grid is centred in
local CLOSED = 0.001 -- the panel's size share while shut

local EggView = {}
EggView.__index = EggView

local function centred(label: TextLabel)
	label.TextXAlignment = Enum.TextXAlignment.Center
	local top = label:FindFirstChild("Color")
	if top and top:IsA("TextLabel") then
		top.TextXAlignment = Enum.TextXAlignment.Center
	end
end

local function line(parent: Instance, text: string, kind: string?, box): TextLabel
	local item = UiPack.Get("StatText")
	item.Size, item.Position, item.AnchorPoint, item.Parent = box.Size, box.Position, Vector2.new(0.5, 0.5), parent
	centred(item)
	UiPack.Text(item, text)
	UiPack.TextGradient(item, kind)
	return item
end

local function cells(panel: Frame, egg)
	local ids = {}
	for id in egg.Odds do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b) -- best chance first
		return egg.Odds[a] > egg.Odds[b]
	end)
	local cellH = CELL_W * B.Size.X / B.Size.Y
	local rows = math.ceil(#ids / COLS)
	local top = GRID_TOP + (GRID_BOTTOM - GRID_TOP - (rows * cellH + (rows - 1) * GAP)) / 2
	for index, id in ids do
		local col, row = (index - 1) % COLS, (index - 1) // COLS
		local rowCount = math.min(COLS, #ids - row * COLS)
		local x = GRID_X + (col - (rowCount - 1) / 2) * (CELL_W + GAP)
		local cell = UiPack.Cell({ Name = id, Size = UDim2.fromScale(CELL_W, cellH), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(x, top + row * (cellH + GAP)), Parent = panel })
		local def = PetMath.Pet(id)
		UiPack.Art.Replace(cell.Icon, { Model = AssetLibrary.Get(id), Rays = Config.Rarities[def.Rarity].Rays }, nil)
		local name = cell:FindFirstChild("Name")
		name.Size, name.Position = UDim2.fromScale(0.96, 0.24), UDim2.fromScale(0.5, 0.86)
		UiPack.Text(name, T.Chance:format(PetMath.Format(egg.Odds[id])))
	end
end

-- The always-on sign over the egg: its rarity and its price in Wins behind the trophy icon.
function EggView.Sign(egg, adornee: BasePart): (BillboardGui, Frame)
	local S = Config.World.Title
	local gui = Ui.Make("BillboardGui", { Name = "EggSign_" .. egg.Id, AlwaysOnTop = false, LightInfluence = 0, MaxDistance = 400, Adornee = adornee,
		StudsOffsetWorldSpace = Vector3.new(0, S.Lift, 0), ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	WorldLabel.Apply(gui, S)
	local holder = Ui.Make("Frame", { Name = "Holder", Size = UDim2.fromScale(1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Parent = gui })
	line(holder, egg.Rarity, egg.Title, { Size = UDim2.fromScale(1, 0.5), Position = UDim2.fromScale(0.5, 0.27) })
	local row = Ui.Make("Frame", { Size = UDim2.fromScale(1, 0.4), Position = UDim2.fromScale(0.5, 0.74), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = holder })
	Ui.Make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0.03, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
	if not egg.Robux then
		Ui.Make("ImageLabel", { Image = IconPick.Image("Trophy"), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, LayoutOrder = 1,
			Size = UDim2.fromScale(1, 1), SizeConstraint = Enum.SizeConstraint.RelativeYY, Parent = row })
	end
	local price = UiPack.Get("StatText")
	price.LayoutOrder, price.Size, price.Parent = 2, UDim2.fromScale(0.7, 1), row
	price.TextXAlignment = Enum.TextXAlignment.Left
	UiPack.Text(price, if egg.Robux then UiPack.Robux(egg.Price) else NumberFormat.Abbreviate(egg.Price) .. " Wins")
	UiPack.TextGradient(price, if egg.Robux then "Green" else "Gold")
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui, holder
end

function EggView.new(spec)
	local egg = spec.Egg
	local self = setmetatable({ Egg = egg }, EggView)
	local gui = Ui.Make("BillboardGui", { Name = "EggBillboard_" .. egg.Id, AlwaysOnTop = true, LightInfluence = 0, MaxDistance = B.Far + 60, Enabled = false, ResetOnSpawn = false,
		StudsOffsetWorldSpace = Vector3.new(0, B.Lift, B.Front), ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Active = true, Adornee = spec.Adornee })
	WorldLabel.Apply(gui, B)
	self.Gui = gui
	local panel = Ui.Make("Frame", { Name = "Panel", Size = UDim2.fromScale(CLOSED, CLOSED), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0, Parent = gui })
	Ui.Make("UICorner", { CornerRadius = UDim.new(0.05, 0), Parent = panel })
	Ui.Make("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.6, Thickness = 2, Parent = panel })
	line(panel, egg.Name, egg.Title, { Size = UDim2.fromScale(0.9, 0.12), Position = UDim2.fromScale(0.5, 0.09) })
	self.Panel = panel -- the open / close tween scales this (a UIScale does nothing on a BillboardGui)
	cells(panel, egg)
	self:Buttons(panel, spec)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.Title, self.TitleHolder = EggView.Sign(egg, spec.Adornee)
	return self
end

local function button(panel: Frame, kind: string, key: string, text: string, x: number, width: number, fn): GuiObject
	return UiPack.Button(kind, T.Hint:format(key, text), fn, { Size = UDim2.fromScale(width, 0.14), Position = UDim2.fromScale(x, 0.87),
		AnchorPoint = Vector2.new(0.5, 0.5), Parent = panel })
end

-- E Hatch / R Multi / T Auto (a Robux egg: one wide E Buy), the price under them.
function EggView:Buttons(panel: Frame, spec)
	local egg = self.Egg
	if egg.Robux then
		button(panel, "Green", T.Keys[1], UiPack.Robux(egg.Price), 0.5, 0.56, function()
			spec.OnHatch(1)
		end)
		return
	end
	button(panel, "Green", T.Keys[1], T.Hatch, 0.19, 0.26, function()
		spec.OnHatch(1)
	end)
	self.Multi = button(panel, "Orange", T.Keys[2], T.Multi, 0.5, 0.26, function()
		spec.OnMulti()
	end)
	self.Auto = button(panel, "Purple", T.Keys[3], T.Auto, 0.81, 0.26, function()
		spec.OnAuto()
	end)
end

function EggView:SetMulti(count: number)
	if self.Multi then
		UiPack.SetText(self.Multi, T.Hint:format(T.Keys[2], T.HatchMulti:format(count)))
	end
end

function EggView:SetAuto(on: boolean)
	if self.Auto then
		UiPack.Paint(self.Auto, if on then "Green" else "Purple")
		UiPack.SetText(self.Auto, T.Hint:format(T.Keys[3], if on then T.AutoOn else T.Auto))
	end
end

-- Grows (overshooting a little) or shrinks a box from / to nothing about its centre; a shrunk one switches its gui off.
local function resize(box: Frame, gui: BillboardGui, grow: boolean, previous: Tween?): Tween
	if previous then
		previous:Cancel()
	end
	if grow then
		gui.Enabled = true
	end
	local info = if grow then TweenInfo.new(B.In, Enum.EasingStyle.Back, Enum.EasingDirection.Out) else TweenInfo.new(B.Out, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local tween = TweenService:Create(box, info, { Size = if grow then UDim2.fromScale(1, 1) else UDim2.fromScale(CLOSED, CLOSED) })
	tween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and not grow then
			gui.Enabled = false
		end
	end)
	tween:Play()
	return tween
end

-- Walking up grows the odds panel while the name / price sign over it shrinks away (and the reverse when leaving), so only one shows.
function EggView:SetOpen(open: boolean)
	if self.Open == open then
		return
	end
	self.Open = open
	self.Tween = resize(self.Panel, self.Gui, open, self.Tween)
	self.TitleTween = resize(self.TitleHolder, self.Title, not open, self.TitleTween)
end

return EggView
