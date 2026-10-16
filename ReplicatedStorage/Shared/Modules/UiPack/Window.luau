--[[
	UiPack/Window — a menu window cloned from the pack (UiPackConfig.Menus[name]): the pack window named
	by Source with its header repainted (Color), retitled (Title), its corner icon and faint header art
	swapped (Icon), the X wired, and optionally a tab column on the right (the pack Index's rarity column).
	Every window lives in one shared ScreenGui "Windows". On short (phone) viewports it grows by Compact.
	  Window.new(name, { OnClose = fn, Parent = Instance? }) -> window
	  window.Frame (the root, centred), window.Panel (the dark body with Top), window.Top, window.Title,
	  window.Extra (the kept header button), window.Column (tab column Container, when Tabs)
	  window:SetTitle(text)   window:SetTabs({ { Key, Title, Color } }, onSelect)   window:Select(key)
	  window:Highlight(key)  (light a tab without onSelect)
	  window:TabBadge(key) -> badge   window:Open()   window:Close()   window.IsOpen
	  Every window's body is centred on screen; side tab columns hang off to the right (Window:Center, re-run on every size change).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.UiPackConfig)
local Ui = require(ReplicatedStorage.Shared.Modules.Ui)
local Core = require(script.Parent.Core)

local Window = {}
Window.__index = Window

local W = Config.Windows
local EXTRAS = { "ClaimAll", "PremiumPass", "Restock" }
local screens = {}
local live = {}

local function screenFor(parent: Instance?): ScreenGui
	local key = parent or "Player"
	if not screens[key] then
		screens[key] = Core.Screen("Windows", W.Order, parent)
	end
	return screens[key]
end

local function title(top: Instance): TextLabel
	for _, child in top.Container:GetChildren() do
		if child:IsA("TextLabel") and child:FindFirstChild("Color") then
			return child
		end
	end
	error("[UiPack] header without a title")
end

-- Puts a window without a tab column into a wrapper beside a clone of the pack Index's column.
local function wrap(frame: Frame): Frame
	local aspect = (frame:FindFirstChildOfClass("UIAspectRatioConstraint") :: UIAspectRatioConstraint).AspectRatio
	local wrapper = Ui.Make("Frame", { Name = frame.Name, Size = frame.Size, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Visible = false })
	Ui.Make("UIAspectRatioConstraint", { AspectRatio = aspect, Parent = wrapper })
	Core.Find("Main.Index.UIListLayout"):Clone().Parent = wrapper
	frame.Name, frame.Size, frame.LayoutOrder, frame.Visible, frame.Parent = "Main", UDim2.fromScale(1, 1), 1, true, wrapper
	local column = Core.Get("TabColumn")
	column.Size, column.LayoutOrder, column.Parent = UDim2.fromScale(W.TabWidth * 1.48 / aspect, 1), 2, wrapper
	return wrapper
end

function Window.new(name: string, opts)
	local def = Config.Menus[name] or error("[UiPack] no menu " .. name)
	local frame = Core.Get("Main." .. def.Source)
	frame.Name, frame.Visible = name, false
	frame.AnchorPoint, frame.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	if def.Size then
		frame.Size = def.Size
	end
	if def.Aspect then
		(frame:FindFirstChildOfClass("UIAspectRatioConstraint") :: UIAspectRatioConstraint).AspectRatio = def.Aspect
	end
	local panel = if frame:FindFirstChild("Top") then frame else frame.Main
	local top = panel.Top
	local self = setmetatable({ Name = name, Panel = panel, Top = top, IsOpen = false, Tabs = {} }, Window)
	Core.Paint(top, def.Color)
	self.Title = title(top)
	Core.Text(self.Title, def.Title)
	self.Icon = top:FindFirstChild("Icon") or top:FindFirstChild("ImageLabel") or top.Container:FindFirstChild("Icon") -- pack windows vary
	self.Icon.Image = def.Icon
	local art = top.Container:FindFirstChild("ImageBg")
	if art then
		art.Image = def.Icon
	end
	for _, extra in EXTRAS do
		local button = top:FindFirstChild(extra)
		if button and extra ~= def.Extra then
			button:Destroy()
		end
	end
	self.Extra = def.Extra and top[def.Extra]
	Core.Clickable(top.Close, function()
		(opts.OnClose or function()
			self:Close()
		end)()
	end)
	if def.Tabs and not frame:FindFirstChild("Buttons") then
		frame = wrap(frame)
	end
	self.Frame = frame
	self.Column = if def.Tabs then frame.Buttons.Container else nil
	self.Base = frame.Size
	self.Lift = def.Lift or 0
	frame.Parent = screenFor(opts.Parent)
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:Center()
	end)
	task.defer(self.Center, self)
	table.insert(live, self)
	return self
end

function Window:SetTitle(text: string)
	Core.Text(self.Title, text)
end

function Window:SetTabs(defs, onSelect)
	for _, child in self.Column:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local height = math.min(W.TabHeight, (1 - (#defs - 1) * W.TabGap) / #defs)
	for i, def in defs do
		local tab = Core.Get("Tab")
		tab.Name, tab.LayoutOrder, tab.Size = def.Key, i, UDim2.fromScale(1, height)
		Core.Text(tab.Container.Text, def.Title)
		Core.Paint(tab, def.Color)
		tab.Parent = self.Column
		Core.Clickable(tab, function()
			self:Select(def.Key)
		end)
		self.Tabs[def.Key] = tab
	end
	self.OnSelect = onSelect
end

-- Lights one tab and dims the others, without calling onSelect (a scroll-follow highlight).
function Window:Highlight(key: string)
	self.Tab = key
	for k, tab in self.Tabs do
		Core.Dim(tab, k ~= key)
	end
end

function Window:Select(key: string)
	self:Highlight(key)
	self.OnSelect(key)
end

function Window:TabBadge(key: string)
	return Core.Badge(self.Tabs[key])
end

-- Pack windows are sized in screen fractions: grow them on short (phone) screens.
function Window:Fit()
	local k = if workspace.CurrentCamera.ViewportSize.Y < W.CompactHeight then W.Compact else 1
	self.Frame.Size = UDim2.fromScale(self.Base.X.Scale * k, self.Base.Y.Scale * k)
end

-- The window BODY (the dark panel with its header) sits in the screen centre; a side tab column hangs off
-- to the right of it instead of pulling the body left.
function Window:Center()
	local frame = self.Frame
	local lo, hi = self.Panel.AbsolutePosition, self.Panel.AbsolutePosition + self.Panel.AbsoluteSize
	if frame.AbsoluteSize.X <= 0 then
		return
	end
	local scale = Ui.BounceScale(frame).Scale
	local delta = ((lo + hi) / 2 - (frame.AbsolutePosition + frame.AbsoluteSize / 2)) / math.max(scale, 0.01)
	frame.Position = UDim2.new(0.5, -math.round(delta.X), 0.5 - self.Lift, -math.round(delta.Y))
end

function Window:Open()
	self.IsOpen = true
	self:Fit()
	local O = W.Open
	local scale = Ui.BounceScale(self.Frame)
	self.Frame.Visible = true
	scale.Scale = O.From
	Ui.Tween(scale, O.Time, { Scale = 1 }, Enum.EasingStyle.Back)
	local settle = self.Icon:GetAttribute("Rotation") or self.Icon.Rotation
	self.Icon:SetAttribute("Rotation", settle)
	self.Icon.Rotation = O.IconFrom
	Ui.Tween(self.Icon, O.IconTime, { Rotation = settle }, Enum.EasingStyle.Elastic)
end

function Window:Close()
	if not self.IsOpen then
		return
	end
	self.IsOpen = false
	local C = W.Close
	local scale = Ui.BounceScale(self.Frame)
	Ui.Tween(scale, C.Time, { Scale = C.To }, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Once(function()
		if not self.IsOpen then
			self.Frame.Visible = false
			scale.Scale = 1
		end
	end)
end

workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	for _, window in live do
		window:Fit()
	end
end)

return Window
