--[[
	WorldController — the local player's world on the client (WorldsConfig):
	  * the attribute "World" sets Track.Offset (every run / scenery position is drawn in that world) and emits the ClientState
	    event "World" (w) so world-bound controllers (scenery, wall props, roll zone) rebuild for it
	  * the Worlds window (menu "Worlds", +1 Rock Skipping's): one pack Wide card per world, its art on rays, "World N", its
	    name and the Speed it needs, and YOU ARE HERE (blue) / TELEPORT (green) / LOCKED (red: a click tries to unlock it, the
	    server checks the Speed) -> WorldTravel { World }. The HUD Worlds button and the lobby portals open it.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.WorldsConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)
local Track = require(ReplicatedStorage.Shared.Modules.Track)
local Ui = require(ReplicatedStorage.Shared.Modules.Ui)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)
local Worlds = require(ReplicatedStorage.Shared.Modules.Worlds)
local ClientState = require(script.Parent.Parent.State.ClientState)

local WorldController = {}

local T = Config.Text
local player = Players.LocalPlayer
local window
local list: ScrollingFrame
local cards = {}
local WORLD_TINT = { "Green", "Purple", "Pink" } -- the Worlds window card colour per world (later worlds: Purple)

local function scroll(panel: Frame): ScrollingFrame
	local old = panel:FindFirstChild("Scrolling")
	if old then
		old:Destroy()
	end
	local frame = UiPack.Get("Main.Shop.Scrolling")
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	frame.Name, frame.Parent = "Scrolling", panel
	local layout = frame:FindFirstChildOfClass("UIListLayout")
	layout.FillDirection, layout.Wraps, layout.SortOrder = Enum.FillDirection.Vertical, false, Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment, layout.Padding = Enum.HorizontalAlignment.Center, UDim.new(0, 10)
	frame.AutomaticCanvasSize = Enum.AutomaticSize.None
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		frame.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 24)
	end)
	return frame
end

local function card(w: number)
	local def = Worlds.Get(w)
	local row = Ui.Make("Frame", { Name = "World" .. w, BackgroundTransparency = 1, Size = UDim2.new(0.968, 0, 0, 100000), LayoutOrder = w, Parent = list })
	Ui.Make("UIAspectRatioConstraint", { AspectRatio = 3.21, DominantAxis = Enum.DominantAxis.Width, Parent = row })
	local face = UiPack.Card("Wide", { Parent = row, Name = "Card" })
	face.Size, face.Position, face.AnchorPoint = UDim2.fromScale(1, 1), UDim2.new(), Vector2.zero
	local aspect = face:FindFirstChildOfClass("UIAspectRatioConstraint")
	if aspect then
		aspect:Destroy()
	end
	UiPack.Paint(face, WORLD_TINT[w] or "Purple")
	UiPack.Art.Replace(face.Icon, def.Art, list)
	face.Title.Text = T.Title:format(w)
	face.Multiplier.Visible = false
	face.Desc.Text = def.Name .. "\n" .. (if def.Need > 0 then T.Need:format(NumberFormat.Abbreviate(def.Need)) else "")
	local button = face.Buttons.Buy
	UiPack.Clickable(button, function()
		if Worlds.Of(player) ~= w then
			Net.Get("WorldTravel"):Fire({ World = w })
		end
	end)
	cards[w] = button
end

local function refresh()
	for w, button in cards do
		local here, open = Worlds.Of(player) == w, Worlds.Unlocked(player, w)
		UiPack.SetText(button, if here then T.Here elseif open then T.Go else T.Locked)
		UiPack.Paint(button, if here then "Blue" elseif open then "Green" else "Red")
	end
end

local function onWorld()
	local w = Worlds.Of(player)
	Track.Offset = Worlds.Offset(w)
	refresh()
	ClientState.Emit("World", w)
	if ClientState.MenuOpen() == Config.Menu then
		ClientState.CloseMenu()
	end
end

-- The Worlds window's TELEPORT / LOCKED button of world w (WorldGuideController spotlights it).
function WorldController.Button(w: number): GuiObject?
	return cards[w]
end

-- Scrolls the window so world w's card is on screen.
function WorldController.Focus(w: number)
	local row = list and list:FindFirstChild("World" .. w)
	if row then
		local y = row.AbsolutePosition.Y - list.AbsolutePosition.Y + list.CanvasPosition.Y - 10
		list.CanvasPosition = Vector2.new(0, math.max(0, y))
	end
end

function WorldController.Start()
	window = UiPack.Window(Config.Menu, { OnClose = ClientState.CloseMenu })
	local bar = window.Panel:FindFirstChild("Percentage")
	if bar then
		bar:Destroy()
	end
	list = scroll(window.Panel)
	for w = 1, Worlds.Count do
		card(w)
	end
	ClientState.RegisterMenu(Config.Menu, function()
		refresh()
		window:Open()
		UiPack.Art.SetActive(list, true)
	end, function()
		window:Close()
		UiPack.Art.SetActive(list, false)
	end)
	player:GetAttributeChangedSignal("World"):Connect(onWorld)
	player:GetAttributeChangedSignal("Worlds"):Connect(refresh)
	onWorld()
end

return WorldController
