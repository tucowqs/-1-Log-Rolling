--[[
	PackViews/RebirthView — the pack's Rebirth window (UiPackConfig menu "Rebirth"): "Rebirth N  x1.5 Money ->
	Rebirth N+1  x2 Money", the requirements box (a line, a description, the progress bar) and REBIRTH OR SKIP
	(the Robux skip with its price in the corner). No game logic.
	  RebirthView.new({ Window = { OnClose, Parent? }, OnRebirth, Icon?, Tile?, OnSkip?, SkipPrice, SkipNote })  (no OnSkip = the skip button and the OR are removed) -> view
	  view:Set({ Now, NowValue, Next, NextValue, Need, Desc, Share (0..1), Ready, Button })
	  view:Open()  view:Close()
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.UiPackConfig)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)

local FLASH = { Transparency = 0.55, Size = 2.4, Spin = 16 } -- the sunbeams behind a tile's art: image alpha, size (x tile height), seconds per turn

local RebirthView = {}
RebirthView.__index = RebirthView

-- The children named `name` under parent, top to bottom.
local function stacked(parent: Instance, name: string): { TextLabel }
	local list = {}
	for _, child in parent:GetChildren() do
		if child.Name == name and child:IsA("TextLabel") then
			table.insert(list, child)
		end
	end
	table.sort(list, function(a, b)
		return a.Position.Y.Scale < b.Position.Y.Scale
	end)
	return list
end

-- Repaints a value tile in a pack palette (spec.Tile) with slowly spinning sunbeams behind its art.
local function paintTile(tile: Frame, kind: string)
	local p = Config.Colors[kind]
	local box, inside = tile.Container, tile.Container.Inside
	box.BackgroundColor3, box.Outer.Color = p.Lip, p.Outer
	inside.UIGradient.Color, inside.ClipsDescendants = ColorSequence.new(p.Top, p.Bottom), true
	local rays = Instance.new("ImageLabel")
	rays.Name, rays.Image, rays.ImageColor3, rays.ImageTransparency = "Flash", Config.Icons.Rays, p.Shadow, FLASH.Transparency
	rays.BackgroundTransparency, rays.AnchorPoint, rays.Position, rays.ZIndex = 1, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), 0
	rays.SizeConstraint, rays.Size, rays.Parent = Enum.SizeConstraint.RelativeYY, UDim2.fromScale(FLASH.Size, FLASH.Size), inside
	TweenService:Create(rays, TweenInfo.new(FLASH.Spin, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 }):Play()
end

function RebirthView.new(spec)
	local self = setmetatable({}, RebirthView)
	local window = UiPack.Window("Rebirth", spec.Window)
	self.Window = window
	local main = window.Panel.Main
	self.Now, self.Next = main.Top.Rebirth1, main.Top.Rebirth2
	self.Need, self.Desc = table.unpack(stacked(main.Middle, "Text"))
	self.Bar = main.Middle.Bar
	if spec.Tile then
		paintTile(self.Now, spec.Tile)
		paintTile(self.Next, spec.Tile)
	end
	if spec.Icon then -- the big faded art in the two value tiles (the pack ships cash)
		for _, tile in { self.Now, self.Next } do -- centred and fitted: the pack art is a wide, offset cash pile
			local art = tile.Container.Inside.ImageBg
			art.Image, art.AnchorPoint, art.Position, art.Size = spec.Icon, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.9, 1.25)
		end
	end
	self.Rebirth = main.Bottom.Rebirth.Btn
	if spec.OnSkip then
		local skip = main.Bottom.Skip.Btn
		local price, note = table.unpack(stacked(skip, "Text"))
		UiPack.Text(price, UiPack.Robux(spec.SkipPrice))
		UiPack.Text(note, spec.SkipNote)
		UiPack.Clickable(skip, spec.OnSkip)
	else
		main.Bottom.Skip:Destroy()
		main.Bottom.Middle:Destroy()
		main.Bottom.UIListLayout:Destroy() -- the button is centred by its own anchor instead
		local holder = main.Bottom.Rebirth
		holder.AnchorPoint, holder.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	end
	UiPack.Clickable(self.Rebirth, function()
		if self.Ready then
			spec.OnRebirth()
		end
	end)
	return self
end

function RebirthView:Set(data)
	UiPack.Text(self.Now.Text, data.Now)
	UiPack.Text(self.Now.Container.Inside.Amount, data.NowValue)
	UiPack.Text(self.Next.Text, data.Next)
	UiPack.Text(self.Next.Container.Inside.Amount, data.NextValue)
	UiPack.Text(self.Need, data.Need)
	UiPack.Text(self.Desc, data.Desc)
	UiPack.SetBar(self.Bar, data.Share)
	UiPack.SetText(self.Rebirth, data.Button)
	if self.Ready ~= data.Ready then
		self.Ready = data.Ready
		UiPack.Paint(self.Rebirth, if data.Ready then "Green" else "Gray")
	end
end

function RebirthView:Open()
	self.Window:Open()
end

function RebirthView:Close()
	self.Window:Close()
end

return RebirthView
