--[[
	PackViews/ShopView — the Robux shop as ONE vertical scroll (the Steal Treasure / "Steal an Egg" shop) in the
	pack's menu "Shop" shell (UiPackConfig.Menus.Shop: the pack Shop window, red header). Every section
	(ShopUiConfig.Sections) is a 3D header plus rows of pack shop cards (PackViews/ShopCards); a row is a Frame
	whose height follows its width (UIAspectRatioConstraint + a 100000 px tall box, so the WIDTH decides).
	No side buttons: one list, scrolled by the player; Open(section) starts it at a section ("+" by the cash
	opens it at Cash). 3D art moves only while the window is open. No game logic.
	  ShopView.new(spec, onBuy(key)) -> view
	      spec.Window = { OnClose, Parent? }; spec.Sections = { { Key, Header, Text, Rows = { { cardView } } } }
	  view:Open(section?)  view:ScrollTo(section)  view:Close()
	  view:SetOwned(key, owned)  view:SetNote(key, text?)  view:SetOdds(cardId, odds)  view:Refresh() (Pack amounts)
	  A section's Columns = the row's units; a card's Span (default 1) = its width in units (1.5 = a wide tile).
	  view:Source(key) -> that item's art (the celebration starts there), or nil
	  view.Window (UiPack.Window), view.Root (the Windows ScreenGui: celebrations draw over it), view.List
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.ShopUiConfig)
local Ui = require(ReplicatedStorage.Shared.Modules.Ui)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)
local ShopCards = require(script.Parent.ShopCards)

local ShopView = {}
ShopView.__index = ShopView

local L = Config.Layout

-- The pack's shop list (Main.Shop.Scrolling), emptied and turned into one vertical column with a content-sized canvas.
local function list(panel: Frame): ScrollingFrame
	local old = panel:FindFirstChild("Scrolling")
	if old then
		old:Destroy() -- the shell's own grid (the pack Index's cells)
	end
	local scroll = UiPack.Get("Main.Shop.Scrolling")
	for _, child in scroll:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	scroll.Name, scroll.Parent = "Scrolling", panel
	local layout = scroll:FindFirstChildOfClass("UIListLayout")
	layout.FillDirection, layout.Wraps, layout.SortOrder = Enum.FillDirection.Vertical, false, Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment, layout.Padding = Enum.HorizontalAlignment.Center, UDim.new(0, L.Padding)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.None
	local function fit()
		scroll.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + L.BottomRoom)
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
	fit()
	return scroll
end

local function row(scroll: ScrollingFrame, ratio: number, order: number, name: string): Frame
	local frame = Ui.Make("Frame", { Name = name, BackgroundTransparency = 1, Size = UDim2.new(L.Width, 0, 0, 100000),
		LayoutOrder = order, Parent = scroll })
	Ui.Make("UIAspectRatioConstraint", { AspectRatio = ratio, DominantAxis = Enum.DominantAxis.Width, Parent = frame })
	return frame
end

local function header(scroll: ScrollingFrame, section, order: number): Frame
	local frame = row(scroll, L.HeaderRatio, order, section.Key .. "Header")
	local label = UiPack.Get("StatText")
	label.Size, label.Position, label.AnchorPoint = UDim2.fromScale(0.7, 0.92), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5)
	for _, layer in { label, label:FindFirstChild("Color") } do
		layer.TextXAlignment = Enum.TextXAlignment.Center -- both 3D layers, or they drift apart
	end
	label.Parent = frame
	UiPack.Text(label, section.Header)
	UiPack.TextGradient(label, section.Text)
	return frame
end

function ShopView:AddCards(scroll: ScrollingFrame, cards, order: number, onBuy, columns: number?)
	local units = 0
	for _, view in ipairs(cards) do
		units += view.Span or 1
	end
	local n = math.max(units, columns or 0)
	local unit = (1 - L.Gap * (math.ceil(n) - 1)) / n
	local used = units * unit + (#cards - 1) * L.Gap
	local x = (1 - used) / 2 -- a short row sits centred
	local frame = row(scroll, L.Ratio[cards[1].Card] / unit, order, "Row")
	for i, view in ipairs(cards) do
		local width = (view.Span or 1) * unit
		local slot = Ui.Make("Frame", { Name = view.Id, BackgroundTransparency = 1, Size = UDim2.fromScale(width, 1),
			Position = UDim2.fromScale(x, 0), Parent = frame })
		x += width + L.Gap
		local entry = ShopCards.new(slot, i, view, onBuy, scroll, true)
		for key in entry.Buys do
			self.Entries[key] = self.Entries[key] or {}
			table.insert(self.Entries[key], entry)
		end
		self.Entries[view.Id] = self.Entries[view.Id] or {}
		table.insert(self.Entries[view.Id], entry)
	end
end

function ShopView.new(spec, onBuy)
	local self = setmetatable({ Entries = {}, Headers = {}, First = spec.Sections[1].Key }, ShopView)
	local window = UiPack.Window("Shop", spec.Window)
	self.Window, self.Root = window, window.Frame.Parent
	local panel = window.Panel
	local bar = panel:FindFirstChild("Percentage")
	if bar then
		bar:Destroy()
	end
	local scroll = list(panel)
	self.List = scroll
	local order = 0
	for _, section in spec.Sections do
		order += 1
		self.Headers[section.Key] = header(scroll, section, order)
		for _, cards in section.Rows do
			order += 1
			self:AddCards(scroll, cards, order, onBuy, cards.Columns or section.Columns)
		end
	end
	return self
end

-- Where the list must scroll for a section's header to sit at the top (clamped to the canvas).
function ShopView:Refresh()
	for id, entries in self.Entries do
		for _, entry in entries do
			if entry.Refresh and entry.Card.Name == id then
				entry.Refresh()
			end
		end
	end
end

function ShopView:Target(key: string): number
	local scroll = self.List
	local y = self.Headers[key].AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y
	return math.clamp(y, 0, math.max(0, scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteWindowSize.Y))
end

function ShopView:ScrollTo(key: string)
	self.List.CanvasPosition = Vector2.new(0, self:Target(key))
end

function ShopView:Open(section: string?)
	local key = if section and self.Headers[section] then section else self.First
	self:ScrollTo(key) -- before the pop-in scale (it skews absolute positions)
	self.Window:Open()
	UiPack.Art.SetActive(self.List, true)
	local opened = {}
	self.Opened = opened
	task.delay(L.Settle, function() -- the first open has no layout yet: place it again once the window settled
		if self.Opened == opened and self.Window.IsOpen and key ~= self.First then
			self:ScrollTo(key)
		end
	end)
end

function ShopView:Close()
	self.Window:Close()
	UiPack.Art.SetActive(self.List, false)
end

function ShopView:SetOwned(key: string, owned: boolean)
	for _, entry in self.Entries[key] or {} do
		if entry.Buys[key] then
			ShopCards.SetOwned(entry, key, owned)
		end
	end
end

function ShopView:SetPrice(key: string, robux: number)
	for _, entry in self.Entries[key] or {} do
		if entry.Buys[key] then
			ShopCards.SetPrice(entry, key, robux)
		end
	end
end

function ShopView:SetNote(key: string, text: string?)
	for _, entry in self.Entries[key] or {} do
		if text and entry.Desc then
			entry.Desc.Text = text
		end
	end
end

function ShopView:SetOdds(cardId: string, odds)
	for _, entry in self.Entries[cardId] or {} do
		ShopCards.SetOdds(entry, odds)
	end
end

function ShopView:Source(key: string): GuiObject?
	local entry = (self.Entries[key] or {})[1]
	return if entry and self.Window.IsOpen then entry.Art else nil
end

return ShopView
