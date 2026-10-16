--[[
	TrailsController — the Trails window (menu "Trails", PackViews/ListView): every TrailConfig trail with its Speed bonus and
	a colour swatch; the button buys (green when affordable, gold when not), equips or unequips (TrailBuy; TrailService decides).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.TrailConfig)
local ListView = require(ReplicatedStorage.Shared.Modules.PackViews.ListView)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)
local Ui = require(ReplicatedStorage.Shared.Modules.Ui)
local ClientState = require(script.Parent.Parent.State.ClientState)

local TrailsController = {}

local T = Config.Text
local player = Players.LocalPlayer
local view
local swatched = {}

-- A diagonal colour streak in the row's icon frame (the trail's own colours).
local function swatch(row: Frame, def)
	if swatched[def.Id] == row then
		return
	end
	swatched[def.Id] = row
	row.IconFrame.Icon.Image = ""
	local bar = Ui.Make("Frame", { Name = "Swatch", Size = UDim2.fromScale(0.95, 0.32), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Rotation = -28, BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), Parent = row.IconFrame.Icon })
	Ui.Make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = bar })
	local keys = {}
	for i, color in def.Colors do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(#def.Colors - 1, 1), color))
	end
	Ui.Make("UIGradient", { Color = ColorSequence.new(keys), Parent = bar })
	Ui.Make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(25, 25, 25), Parent = bar })
end

local function refresh()
	local owned, equipped, wins = ClientState.Data.Trails or {}, ClientState.Data.Trail, player:GetAttribute("Wins") or 0
	local rows = {}
	for _, def in Config.Trails do
		local has, on = owned[def.Id] == true, equipped == def.Id
		table.insert(rows, { Key = def.Id, Title = def.Name, Text = T.Boost:format(math.floor(def.Boost * 100 + 0.5)),
			Button = if on then "UNEQUIP" elseif has then "EQUIP" else T.Price:format(NumberFormat.Abbreviate(def.Price)),
			Color = if on then "Blue" elseif has or wins >= def.Price then "Green" else "Orange",
			OnPress = function()
				Net.Get("TrailBuy"):Fire({ Id = def.Id })
			end })
	end
	view:Set(rows)
	for _, def in Config.Trails do
		swatch(view.Rows[def.Id].Row, def)
	end
end

function TrailsController.Start()
	view = ListView.new(Config.Menu, { Window = { OnClose = ClientState.CloseMenu } })
	ClientState.RegisterMenu(Config.Menu, function()
		refresh()
		view:Open()
	end, function()
		view:Close()
	end)
	ClientState.On("Data", function()
		if ClientState.MenuOpen() == Config.Menu then
			refresh()
		end
	end)
	player:GetAttributeChangedSignal("Wins"):Connect(function()
		if ClientState.MenuOpen() == Config.Menu then
			refresh()
		end
	end)
end

return TrailsController
