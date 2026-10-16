--[[
	PackViews/ListView — a pack window holding a live list of the pack's upgrade rows (Main.Upgrades.Scrolling.Template):
	the title on the row's top border, an icon (image or a 3D model on rays) on the left, one wide middle text and one button
	on the right. The game's list windows share it: the gift picker, Items (potions / logs), Trails, Gifts.
	  ListView.new(menu, { Window = { OnClose, Parent? } }) -> view
	  view:Set(rows)   rows = { { Key, Title, Text, Button, Color, OnPress, Icon? | Art?, Order? } } (Art = a UiPack/Art spec);
	                   rows are kept by Key: new keys are built, missing ones removed, the rest updated in place
	  view:Open()  view:Close()  view.Window  view.List
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)

local ListView = {}
ListView.__index = ListView

local BUTTON = UDim2.fromScale(1, 0.55)

local function middle(row: Frame): Frame
	local first
	for _, child in row.Middle:GetChildren() do
		if child:IsA("Frame") and child.Name ~= "-" then
			if not first or child.LayoutOrder < first.LayoutOrder then
				first = child
			end
		end
	end
	for _, child in row.Middle:GetChildren() do
		if child:IsA("GuiObject") and child ~= first then
			child.Visible = false
		end
	end
	first.Size = UDim2.fromScale(1, first.Size.Y.Scale)
	return first
end

function ListView.new(menu: string, spec)
	local self = setmetatable({ Rows = {} }, ListView)
	self.Window = UiPack.Window(menu, spec.Window)
	self.List = self.Window.Panel.Scrolling
	for _, child in self.List:GetChildren() do
		if child:IsA("GuiObject") and child.Name ~= "_" then
			child:Destroy()
		end
	end
	return self
end

function ListView:Build(def)
	local row = UiPack.Row({ Parent = self.List, Name = def.Key })
	row.Buttons["R$"]:Destroy()
	local entry = { Row = row, Button = row.Buttons.Cash, Text = middle(row) }
	entry.Button.Size = BUTTON
	UiPack.Clickable(entry.Button, function()
		if entry.OnPress then
			entry.OnPress()
		end
	end)
	if def.Art then
		UiPack.Art.Replace(row.IconFrame.Icon, def.Art, self.List)
	end
	self.Rows[def.Key] = entry
	return entry
end

function ListView:Set(rows)
	local keep = {}
	for order, def in rows do
		keep[def.Key] = true
		local entry = self.Rows[def.Key] or self:Build(def)
		entry.Row.LayoutOrder, entry.OnPress = def.Order or order, def.OnPress
		entry.Row.Title.Text = def.Title
		if def.Icon then
			entry.Row.IconFrame.Icon.Image = def.Icon
		end
		UiPack.Text(entry.Text.Main.Container.Amount, def.Text or "")
		UiPack.SetText(entry.Button, def.Button)
		if entry.Button:GetAttribute("Paint") ~= def.Color then
			UiPack.Paint(entry.Button, def.Color)
		end
	end
	for key, entry in self.Rows do
		if not keep[key] then
			entry.Row:Destroy()
			self.Rows[key] = nil
		end
	end
end

function ListView:Open()
	self.Window:Open()
	UiPack.Art.SetActive(self.List, true)
	self.List.CanvasPosition = Vector2.zero
end

function ListView:Close()
	self.Window:Close()
	UiPack.Art.SetActive(self.List, false)
end

return ListView
