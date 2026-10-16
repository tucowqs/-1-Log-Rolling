--[[
	PackViews/UpgradesView — a list window of the pack's upgrade rows (Main.Upgrades.Scrolling.Template): the
	title sits on the row's top border, an icon on the left, "before -> after" in the middle and one price
	button on the right (the pack's cash button; its second Robux button is removed). Used for upgrade lists
	(menu "Upgrades") and Settings (menu "Settings": the middle shows a description, no arrow).
	  UpgradesView.new(menu, { Window = { OnClose, Parent? }, Rows = { { Key, Title, Icon, OnPress } } }) -> view
	  view:SetRow(key, { Title?, Before, After?, Button, Color })   After nil = one wide middle text, no arrow
	  view:Pop(key)  view:SetVisible(key, on)  view:Open()  view:Close()
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ui = require(ReplicatedStorage.Shared.Modules.Ui)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)

local UpgradesView = {}
UpgradesView.__index = UpgradesView

local BUTTON = UDim2.fromScale(1, 0.55) -- the row's single button (bigger than the pack's two stacked ones)

-- The middle's value frames, left to right (pack names vary: "1" / "Frame" / "2"), and its arrow.
local function middle(row: Frame): (Frame, Frame, Frame)
	local frames = {}
	for _, child in row.Middle:GetChildren() do
		if child:IsA("Frame") and child.Name ~= "-" then
			table.insert(frames, child)
		end
	end
	table.sort(frames, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	return frames[1], row.Middle["-"], frames[2]
end

function UpgradesView.new(menu: string, spec)
	local self = setmetatable({ Rows = {} }, UpgradesView)
	local window = UiPack.Window(menu, spec.Window)
	self.Window = window
	local list = window.Panel.Scrolling
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") and child.Name ~= "_" then
			child:Destroy()
		end
	end
	self.List = list
	for order, def in spec.Rows do
		local row = UiPack.Row({ Parent = list, Name = def.Key, LayoutOrder = order })
		row.Buttons["R$"]:Destroy()
		local button = row.Buttons.Cash
		button.Size = BUTTON
		UiPack.Clickable(button, def.OnPress)
		row.IconFrame.Icon.Image = def.Icon
		row.Title.Text = def.Title
		local before, arrow, after = middle(row)
		self.Rows[def.Key] = { Row = row, Button = button, Before = before, Arrow = arrow, After = after, Width = before.Size }
	end
	return self
end

function UpgradesView:SetRow(key: string, data)
	local r = self.Rows[key]
	if data.Title then
		r.Row.Title.Text = data.Title
	end
	local single = data.After == nil
	r.Arrow.Visible, r.After.Visible = not single, not single
	r.Before.Size = if single then UDim2.fromScale(1, r.Width.Y.Scale) else r.Width
	UiPack.Text(r.Before.Main.Container.Amount, data.Before)
	if not single then
		UiPack.Text(r.After.Main.Container.Amount, data.After)
	end
	UiPack.SetText(r.Button, data.Button)
	if r.Button:GetAttribute("Paint") ~= data.Color then
		UiPack.Paint(r.Button, data.Color)
	end
end

function UpgradesView:Pop(key: string)
	Ui.Pop(self.Rows[key].Row, 0.9)
end

function UpgradesView:SetVisible(key: string, on: boolean)
	self.Rows[key].Row.Visible = on
end

function UpgradesView:Open()
	self.Window:Open()
	self.List.CanvasPosition = Vector2.zero
end

function UpgradesView:Close()
	self.Window:Close()
end

return UpgradesView
