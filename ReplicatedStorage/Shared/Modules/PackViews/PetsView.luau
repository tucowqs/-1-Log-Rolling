--[[
	PackViews/PetsView — the "My Pets" window (UiPackConfig menu "Pets", the pack's Shop shell with its scroll replaced):
	a pet card on the left (name, 3D model on rarity rays, rarity, +Mult, EQUIP / DELETE), the backpack + equipped counters, and
	the grid of owned pets (pack index cells, a green tick on the equipped ones) with EQUIP BEST under it. No game logic.
	  PetsView.new({ Window = { OnClose, Parent? }, OnEquip = (uid, on), OnDelete = (uid), OnEquipBest = () }) -> view
	  view:Set({ Pets = { {Uid, Id, Def, Equipped} } (best first), Stored, Storage, Equipped, EquipMax })
	  view:Open()  view:Close()
	  view.Picked = the uid of the last tile the player clicked (the auto-selected first pet doesn't count)
	  view.Tiles[uid].Cell / view.Equip   (PetGuideController points at them)
	Tiles are built once per pet uid (a viewport each) and only re-tinted afterwards.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.PetsConfig)
local IconPick = require(ReplicatedStorage.Shared.Modules.IconPick)
local PetMath = require(ReplicatedStorage.Shared.Modules.PetMath)
local Ui = require(ReplicatedStorage.Shared.Modules.Ui)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)
local UiPackConfig = require(ReplicatedStorage.Shared.Config.UiPackConfig)
local AssetLibrary = require(ReplicatedStorage.Shared.Modules.AssetLibrary)

local T = Config.Text
local GROUP = "Pets" -- UiPack.Art group: the card's model only turns while the window is open
local CELL = { Width = 0.215, Gap = 0.03 } -- grid cell: share of the grid's width; height keeps it square, and the gap (share of the width) is the same in pixels both ways (set in Resize)

local PetsView = {}
PetsView.__index = PetsView

local function centred(label: TextLabel)
	label.TextXAlignment = Enum.TextXAlignment.Center
	local top = label:FindFirstChild("Color")
	if top and top:IsA("TextLabel") then
		top.TextXAlignment = Enum.TextXAlignment.Center
	end
end

-- A dark pack well (the window body's look: black glass with the pack's two strokes).
local function well(panel: Frame, props)
	local frame = Ui.Make("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, Name = props.Name,
		Size = props.Size, Position = props.Position, AnchorPoint = props.AnchorPoint or Vector2.zero, Parent = panel })
	panel.Inner:Clone().Parent = frame
	panel.Outer:Clone().Parent = frame
	return frame
end

local function label(parent: Instance, text: string, kind: string?, y: number, h: number): TextLabel
	local item = UiPack.Get("StatText")
	item.Size, item.Position, item.AnchorPoint, item.Parent = UDim2.fromScale(0.94, h), UDim2.fromScale(0.5, y), Vector2.new(0.5, 0.5), parent
	centred(item)
	UiPack.Text(item, text)
	UiPack.TextGradient(item, kind)
	return item
end

local function pill(panel: Frame, icon: string, x: number, w: number)
	local item = UiPack.ValuePill({ Icon = icon }, { Size = UDim2.fromScale(w, 0.085), Position = UDim2.fromScale(x, 0.215), AnchorPoint = Vector2.new(0, 0.5), Parent = panel })
	item.Timer:Destroy()
	item.Value.Size = UDim2.fromScale(0.7, 0.9)
	UiPack.TextGradient(item.Value, "Gold")
	return item
end

function PetsView.new(spec)
	local self = setmetatable({ Spec = spec, Tiles = {}, Selected = nil, Data = nil }, PetsView)
	local window = UiPack.Window("Pets", spec.Window)
	self.Window = window
	local panel = window.Panel
	panel.Scrolling:Destroy()
	self.Stored = pill(panel, IconPick.Image("Backpack"), 0.03, 0.3)
	self.Equipped = pill(panel, IconPick.Image("Paw"), 0.36, 0.34)

	-- the pet card (left)
	local card = well(panel, { Name = "Card", Size = UDim2.fromScale(0.3, 0.68), Position = UDim2.fromScale(0.03, 0.27) })
	self.Card = card
	self.Name = label(card, "", nil, 0.075, 0.1)
	self.Rarity = label(card, "", nil, 0.6, 0.075)
	self.Mult = UiPack.StatRow(IconPick.Image("Boost"), "Green", { Size = UDim2.fromScale(0.62, 0.095), Position = UDim2.fromScale(0.5, 0.69), AnchorPoint = Vector2.new(0.5, 0.5), Parent = card })
	self.Equip = UiPack.Button("Green", T.Equip, function()
		local tile = self.Tiles[self.Selected]
		if tile then
			spec.OnEquip(self.Selected, not tile.Entry.Equipped)
		end
	end, { Size = UDim2.fromScale(0.58, 0.14), Position = UDim2.fromScale(0.03, 0.835), Parent = card })
	local trash = UiPack.Button("Red", "", function()
		if self.Selected then
			spec.OnDelete(self.Selected)
		end
	end, { Size = UDim2.fromScale(0.3, 0.14), Position = UDim2.fromScale(0.67, 0.835), Parent = card })
	Ui.Make("ImageLabel", { Image = IconPick.Image("Trash"), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.9), ZIndex = 20, Parent = UiPack.Face(trash) })
	self.Trash = trash

	-- the grid (right)
	local grid = well(panel, { Name = "Grid", Size = UDim2.fromScale(0.62, 0.69), Position = UDim2.fromScale(0.35, 0.27) })
	local scroll = Ui.Make("ScrollingFrame", { Name = "List", Size = UDim2.fromScale(0.97, 0.96), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, AutomaticCanvasSize = Enum.AutomaticSize.None, CanvasSize = UDim2.new(), Parent = grid })
	self.Scroll = scroll
	self.Layout = Ui.Make("UIGridLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	Ui.Make("UIPadding", { PaddingLeft = UDim.new(0.012, 0), PaddingTop = UDim.new(0.02, 0), Parent = scroll })
	self.EmptyText = label(grid, T.Empty, "LightBlue", 0.5, 0.1)
	self.EmptyText.Size = UDim2.fromScale(0.8, 0.1)
	self.Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() -- the canvas is as tall as every row plus a bottom margin, so the last row never clips
		self:Resize()
	end)
	grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:Resize()
	end)

	UiPack.Button("Green", T.EquipBest, spec.OnEquipBest, { Size = UDim2.fromScale(0.235, 0.085), Position = UDim2.fromScale(0.735, 0.215), AnchorPoint = Vector2.new(0, 0.5), Parent = panel })
	return self
end

-- Square cells: height as a share of the grid's height from its width share.
function PetsView:Resize()
	local size = self.Scroll.AbsoluteSize
	if size.X > 0 and size.Y > 0 then
		local gap = math.floor(size.X * CELL.Gap)
		self.Layout.CellPadding = UDim2.fromOffset(gap, gap)
		self.Layout.CellSize = UDim2.new(CELL.Width, 0, 0, math.floor(size.X * CELL.Width))
		self.Scroll.CanvasSize = UDim2.fromOffset(0, self.Layout.AbsoluteContentSize.Y + size.Y * 0.02 + gap * 3)
	end
end

-- The pet's 3D art; a pet owned at join may not have replicated its model yet (Get = nil draws nothing), so wait for it.
local function addArt(cell: Frame, def, rarity)
	if not AssetLibrary.Ready(def.Id) then
		AssetLibrary.Build(def.Id)
		if not cell.Parent then
			return
		end
	end
	local art = UiPack.Art.Replace(cell.Icon, { Model = AssetLibrary.Get(def.Id), Rays = rarity.Rays }, GROUP)
	art.Size = UDim2.fromScale(0.78, 0.78)
	art.Position = UDim2.fromScale(0.5, 0.44)
	art.AnchorPoint = Vector2.new(0.5, 0.5)
end

local function tile(self, entry)
	local def, rarity = entry.Def, Config.Rarities[entry.Def.Rarity]
	local cell = UiPack.Cell({ Name = entry.Uid, Parent = self.Scroll })
	task.spawn(addArt, cell, def, rarity)
	local name = cell:FindFirstChild("Name")
	name.Size, name.Position, name.AnchorPoint = UDim2.fromScale(0.62, 0.2), UDim2.fromScale(0.64, 0.87), Vector2.new(0.5, 0.5)
	UiPack.Text(name, T.Mult:format(PetMath.Format(entry.Mult)))
	UiPack.TextGradient(name, "Green")
	Ui.Make("ImageLabel", { Image = IconPick.Image("Boost"), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(0.26, 0.26),
		Position = UDim2.fromScale(0.04, 0.74), ZIndex = 8, Parent = cell })
	local tick = Ui.Make("ImageLabel", { Name = "Tick", Image = UiPackConfig.Icons.Check, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Visible = false,
		AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromScale(0.34, 0.34), Position = UDim2.fromScale(1.02, -0.02), ZIndex = 10, Parent = cell })
	local hit = Ui.Make("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 30, Parent = cell })
	hit.Activated:Connect(function()
		if Ui.OnClick then
			Ui.OnClick()
		end
		self.Picked = entry.Uid
		self:Select(entry.Uid)
	end)
	return { Cell = cell, Tick = tick, Entry = entry, Ink = cell.Outer.Color }
end

function PetsView:Select(uid: string?)
	self.Selected = uid
	for id, item in self.Tiles do
		item.Cell.Outer.Color = if id == uid then Color3.fromRGB(120, 235, 255) else item.Ink
	end
	local item = uid and self.Tiles[uid]
	self.Card.Visible = true
	if self.CardArt then
		self.CardArt:Destroy()
		self.CardArt = nil
	end
	self.Name.Visible, self.Rarity.Visible, self.Mult.Visible, self.Equip.Visible, self.Trash.Visible = item ~= nil, item ~= nil, item ~= nil, item ~= nil, item ~= nil
	if not item then
		return
	end
	local entry = item.Entry
	local rarity = Config.Rarities[entry.Def.Rarity]
	UiPack.Text(self.Name, entry.Def.Name)
	UiPack.Text(self.Rarity, entry.Def.Rarity)
	UiPack.TextGradient(self.Rarity, rarity.Text)
	UiPack.Text(self.Mult.Amount, T.Mult:format(PetMath.Format(entry.Mult)))
	self.CardArt = UiPack.Art.new(self.Card, { Model = AssetLibrary.Get(entry.Def.Id), Rays = rarity.Rays, Spin = "Swing" }, { Size = UDim2.fromScale(0.96, 0.4), Position = UDim2.fromScale(0.5, 0.33),
		AnchorPoint = Vector2.new(0.5, 0.5), Group = GROUP, ZIndex = 3 })
	self:PaintButtons()
end

function PetsView:PaintButtons()
	local item = self.Selected and self.Tiles[self.Selected]
	if item then
		local on = item.Entry.Equipped
		UiPack.Paint(self.Equip, if on then "Red" else "Green")
		UiPack.SetText(self.Equip, if on then T.Unequip else T.Equip)
		UiPack.Dim(self.Trash, on) -- an equipped pet can't be deleted
	end
end

function PetsView:Set(data)
	local seen = {}
	for index, entry in data.Pets do
		seen[entry.Uid] = true
		local item = self.Tiles[entry.Uid]
		if not item then
			item = tile(self, entry)
			self.Tiles[entry.Uid] = item
		end
		item.Entry = entry
		item.Cell.LayoutOrder = index
		item.Tick.Visible = entry.Equipped
	end
	for uid, item in self.Tiles do
		if not seen[uid] then
			item.Cell:Destroy()
			self.Tiles[uid] = nil
		end
	end
	self.EmptyText.Visible = #data.Pets == 0
	UiPack.Text(self.Stored.Value, T.Stored:format(data.Stored, data.Storage))
	UiPack.Text(self.Equipped.Value, T.Equipped:format(data.Equipped, data.EquipMax))
	if not self.Selected or not self.Tiles[self.Selected] then
		self:Select(if data.Pets[1] then data.Pets[1].Uid else nil)
	else
		self:Select(self.Selected)
	end
	self:Resize()
end

function PetsView:Open()
	UiPack.Art.SetActive(GROUP, true)
	self.Window:Open()
end

function PetsView:Close()
	UiPack.Art.SetActive(GROUP, false)
	self.Window:Close()
end

return PetsView
