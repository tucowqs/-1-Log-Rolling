--[[
	HudController — lays out the game's own HUD (HudConfig) in ScreenGui "Hud" from GameUI pack components
	(UiPack/Widgets) and wires every HudConfig.Buttons group (Left / Right / Top):
	  Menu buttons toggle their ClientState menu (Tab = its context); Buy buttons prompt a ShopMath item
	  (Shop system); Price fills an Offer / Gift button's Robux price; HideWhen hides it while a player attribute
	  is true; Badge shows a ClientState event's count on the red "!" bubble (e.g. Rewards' "RewardsReady");
	  Lock keeps the normal colour and toasts why it is locked, then toasts once when it unlocks.
	While any menu window is open the HudConfig.HideOnMenu groups slide off their edge.
	  Owned (pass toggles): once its pass attribute is true a click emits ClientState Event and the label shows On / Off
	  (player attribute Attribute .. "On", set by the server owner of the toggle).
	  HudController.Group(name) -> the HudConfig.Groups frame (made on first call; the stats / status
	  controllers and game controllers fill theirs). HudController.Button(name) -> a built button.
	  Settings is a TopbarPlus icon (Topbar).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.HudConfig)
local Ui = require(ReplicatedStorage.Shared.Modules.Ui)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local ClientState = require(script.Parent.Parent.State.ClientState)
local NotifyController = require(script.Parent.NotifyController)

local HudController = {}

local player = Players.LocalPlayer
local groups = {}
local buttons = {}

function HudController.Button(name: string): GuiObject?
	return buttons[name]
end

function HudController.Group(name: string): Frame
	if not groups[name] then
		local G = Config.Groups[name]
		groups[name] = Ui.Make("Frame", { Name = name, Size = G.Size, Position = G.Position, AnchorPoint = G.Anchor,
			SizeConstraint = Enum.SizeConstraint.RelativeYY, BackgroundTransparency = 1, Parent = UiPack.Hud() })
	end
	return groups[name]
end

local function unlocked(lock): boolean
	return (player:GetAttribute(lock.Attribute) or 0) >= lock.Min
end

local function act(def)
	local lock = def.Lock and Config.Locks[def.Lock]
	if lock and not unlocked(lock) then
		NotifyController.Toast(lock.Locked:format(lock.Min), "Error")
	elseif def.Fire then
		Net.Get(def.Fire):Fire({}) -- a plain server request (e.g. walk back to the top)
	elseif def.Owned and player:GetAttribute(def.Owned.Attribute) == true then
		ClientState.Emit(def.Owned.Event)
	elseif def.Buy then
		require(script.Parent.ShopController).Buy(def.Buy) -- Buy buttons need the Shop system
	elseif ClientState.MenuOpen() == def.Menu then
		ClientState.CloseMenu()
	else
		ClientState.OpenMenu(def.Menu, def.Tab)
	end
end

local function price(key: string): string
	local ShopMath = require(ReplicatedStorage.Shared.Modules.ShopMath) -- Price needs the Shop system
	return Config.PriceText:format(UiPack.Robux(ShopMath.Items[key].Def.Price))
end

local function badge(button: GuiObject, event: string)
	local bubble = UiPack.Badge(button)
	ClientState.On(event, function(count: number)
		bubble.Visible = count > 0
		bubble["!"].Text = tostring(count)
	end)
end

local function hideWhen(button: GuiObject, attribute: string)
	local function refresh()
		button.Visible = player:GetAttribute(attribute) ~= true
	end
	player:GetAttributeChangedSignal(attribute):Connect(refresh)
	refresh()
end

-- Reaching a lock's Min toasts its Unlocked text once (not on the first value after the save loads).
local function watchUnlock(lock)
	local was = if player:GetAttribute(lock.Attribute) == nil then nil else unlocked(lock)
	player:GetAttributeChangedSignal(lock.Attribute):Connect(function()
		local now = unlocked(lock)
		if now and was == false then
			NotifyController.Toast(lock.Unlocked, "Success")
		end
		was = now
	end)
end

-- An owned pass turns its offer button into an ON / OFF toggle (the price line hides).
local function owned(button: GuiObject, def)
	local O = def.Owned
	local function refresh()
		if player:GetAttribute(O.Attribute) == true then
			UiPack.SetLabel(button, if player:GetAttribute(O.Attribute .. "On") then O.On else O.Off)
			button.Price.Visible = false
			UiPack.Paint(button, if player:GetAttribute(O.Attribute .. "On") then "Green" else def.Color)
		end
	end
	player:GetAttributeChangedSignal(O.Attribute):Connect(refresh)
	player:GetAttributeChangedSignal(O.Attribute .. "On"):Connect(refresh)
	refresh()
end

local function build(group: Frame, defs)
	for order, def in defs do
		local props = table.clone(def.Box)
		props.Parent, props.Name, props.LayoutOrder = group, def.Name, order
		local spec = { Text = def.Text, Color = def.Color, Icon = def.Icon, Price = def.Price and price(def.Price), OnClick = function()
			act(def)
		end }
		local button = UiPack[def.Widget](spec, props)
		buttons[def.Name] = button
		if def.Owned then
			owned(button, def)
		end
		if def.Badge then
			badge(button, def.Badge)
		end
		if def.HideWhen then
			hideWhen(button, def.HideWhen)
		end
		if def.Lock then
			watchUnlock(Config.Locks[def.Lock])
		end
	end
end

-- Windows never sit over the HUD buttons: slide the groups off their edge while a menu is open.
local function onMenu(open: string?)
	local H = Config.HideOnMenu
	for name, direction in H.Groups do
		local G = Config.Groups[name]
		local away = UDim2.new(G.Position.X.Scale + direction * 0.5, G.Position.X.Offset, G.Position.Y.Scale, G.Position.Y.Offset)
		Ui.Tween(HudController.Group(name), H.Time, { Position = if open then away else G.Position }, Enum.EasingStyle.Quad)
	end
end

function HudController.Start()
	for name, defs in Config.Buttons do
		build(HudController.Group(name), defs)
	end
	ClientState.On("Menu", onMenu)
end

return HudController
