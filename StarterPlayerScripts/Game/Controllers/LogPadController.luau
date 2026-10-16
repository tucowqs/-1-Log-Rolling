--[[
	LogPadController — the billboard over every log pedestal near spawn (Workspace.LogPads, LogPadService): the log's name, then
	the Wins it costs ([trophy] 150), or EQUIPPED / OWNED once you have it. A world label, so it shrinks with distance
	(WorldLabelController), and a ProximityPrompt (Buy / Equip, hidden once equipped) that asks the server through LogPadUse; a purchase just plays the sound here.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AssetLibrary = require(ReplicatedStorage.Shared.Modules.AssetLibrary)
local Aura = require(ReplicatedStorage.Shared.Modules.Aura)
local Config = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local Curves = require(ReplicatedStorage.Shared.Modules.Curves)
local IconPick = require(ReplicatedStorage.Shared.Modules.IconPick)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)
local WorldLabel = require(ReplicatedStorage.Shared.Modules.WorldLabel)
local ClientState = require(script.Parent.Parent.State.ClientState)

local LogPadController = {}

local B = Config.LogPads.Billboard
local player = Players.LocalPlayer
local prices: { [string]: any } = {} -- log id -> its second line { Label, Icon }
local prompts: { [string]: ProximityPrompt } = {} -- log id -> the pedestal's prompt
local floating: { { Log: Model, Base: CFrame, Phase: number } } = {} -- the hovering logs

-- The price line: [trophy] N when it costs Wins (the pack text is TextScaled, so the label is sized to its characters and the
-- row is centred); the other states are a lone centred word.
local CHAR = 0.58 / (B.Size.X * 0.96) -- share of the row one character of the row's height takes

local function setPrice(entry, text: string, kind: string, trophy: boolean)
	UiPack.Text(entry.Label, text)
	UiPack.TextGradient(entry.Label, kind)
	entry.Icon.Visible = trophy
	entry.Label.Size = UDim2.fromScale(if trophy then math.min(#text * CHAR, 0.8) else 1, 1)
end

local function refresh()
	for _, log in Config.Logs do
		local entry = prices[log.Id]
		if entry and prompts[log.Id] then
			local data = ClientState.Data
			local prompt = prompts[log.Id]
			prompt.Enabled = data.Equipped ~= log.Id
			prompt.ActionText = if data.Logs and data.Logs[log.Id] then "Equip" else "Buy"
			if data.Equipped == log.Id then
				setPrice(entry, "EQUIPPED", "Blue", false)
			elseif data.Logs and data.Logs[log.Id] then
				setPrice(entry, "OWNED", "Green", false)
			elseif log.Price == 0 then
				setPrice(entry, "FREE", "Green", false)
			else
				setPrice(entry, NumberFormat.Commas(log.Price), if (player:GetAttribute("Wins") or 0) >= log.Price then "Green" else "Gold", true)
			end
		end
	end
end

local function centred(label: TextLabel)
	label.TextXAlignment = Enum.TextXAlignment.Center
	local top = label:FindFirstChild("Color")
	if top and top:IsA("TextLabel") then
		top.TextXAlignment = Enum.TextXAlignment.Center
	end
end

local function line(parent: Instance, text: string, kind: string, y: number, height: number): TextLabel
	local label = UiPack.Get("StatText")
	label.Size, label.Position, label.AnchorPoint, label.Parent = UDim2.fromScale(0.96, height), UDim2.fromScale(0.5, y), Vector2.new(0.5, 0.5), parent
	centred(label)
	UiPack.Text(label, text)
	UiPack.TextGradient(label, kind)
	return label
end

local function priceLine(parent: Instance, y: number, height: number)
	local row = Instance.new("Frame")
	row.BackgroundTransparency, row.Size, row.Position, row.AnchorPoint = 1, UDim2.fromScale(0.96, height), UDim2.fromScale(0.5, y), Vector2.new(0.5, 0.5)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection, layout.HorizontalAlignment, layout.VerticalAlignment, layout.Padding =
		Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center, UDim.new(0.01, 0)
	layout.Parent = row
	local icon = Instance.new("ImageLabel")
	icon.Name, icon.Image, icon.BackgroundTransparency, icon.ScaleType, icon.LayoutOrder = "Trophy", IconPick.Image("Trophy"), 1, Enum.ScaleType.Fit, 1
	icon.Size = UDim2.fromScale(height * B.Size.Y / (B.Size.X * 0.96), 1) -- a square the row's height
	icon.Parent = row
	local label = UiPack.Get("StatText")
	label.LayoutOrder, label.Size, label.Parent = 2, UDim2.fromScale(1, 1), row
	centred(label)
	row.Parent = parent
	return { Label = label, Icon = icon }
end

-- Each log hovers over its pedestal and bobs gently (client only: the Blender log replaces the Studio-built stand-in that sits on the pedestal in Edit).
local function float()
	local F = Config.LogPads.Float
	local now = os.clock()
	for _, item in floating do
		if item.Log.Parent then
			local lift = CFrame.new(0, F.Hover + math.sin(now * F.Speed + item.Phase) * F.Bob, 0)
			item.Log:PivotTo(lift * item.Base)
			if item.Aura then
				item.Aura:Place(lift * item.Box, item.Extents)
			end
		end
	end
end

local function decorate(pad: BasePart)
	local id = pad:GetAttribute("LogId")
	local gui = Instance.new("BillboardGui")
	gui.Name, gui.AlwaysOnTop, gui.LightInfluence, gui.MaxDistance = "Billboard", false, 0, 260
	gui.StudsOffsetWorldSpace = Vector3.new(0, B.Lift + pad.Size.Y / 2, 0)
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	WorldLabel.Apply(gui, B)
	line(gui, pad:GetAttribute("Text"), "White", 0.12, 0.24)
	prices[id] = priceLine(gui, 0.36, 0.26)
	line(gui, `+{NumberFormat.Abbreviate(Curves.LogById[id].Mult)} Speed / hit`, "Green", 0.62, 0.22)
	line(gui, `Lasts {Curves.LogById[id].Durability}s`, "LightBlue", 0.86, 0.22)
	gui.Adornee, gui.Parent = pad, pad
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText, prompt.MaxActivationDistance, prompt.RequiresLineOfSight, prompt.HoldDuration = pad:GetAttribute("Text"), Config.LogPads.Prompt.Distance, false, 0
	prompt.Triggered:Connect(function()
		Net.Get("LogPadUse"):Fire({ Id = id })
	end)
	prompt.Parent = pad
	prompts[id] = prompt
	refresh()
	local log = pad.Parent:FindFirstChild("Log")
	if log and log:IsA("Model") then
		-- swap the Studio-built stand-in for the log's real Blender model (the one it rolls as), same length and spot
		local box, size = log:GetBoundingBox()
		local model = AssetLibrary.Wait(id)
		model:ScaleTo(model:GetScale() * size.X / model:GetExtentsSize().X)
		model:PivotTo(CFrame.new(box.Position))
		model.Parent = log.Parent
		log:Destroy()
		local auraBox, extents = model:GetBoundingBox() -- later logs carry their particle aura on the pad too
		table.insert(floating, { Log = model, Base = model:GetPivot(), Phase = #floating * 0.9, Aura = Aura.Log(id, model.Parent), Box = auraBox, Extents = extents * Aura.Config.LogFit })
	end
end

function LogPadController.Start()
	local folder = workspace:WaitForChild("LogPads")
	local function add(model: Instance)
		local pad = model:WaitForChild("Pad", 30)
		if pad then
			decorate(pad)
		end
	end
	for _, model in folder:GetChildren() do
		task.spawn(add, model)
	end
	folder.ChildAdded:Connect(add)
	RunService.Heartbeat:Connect(float)
	ClientState.On("Data", refresh)
	player:GetAttributeChangedSignal("Wins"):Connect(refresh)
	Net.Get("LogBought"):Connect(function()
		refresh() -- the "Bought and equipped" toast (NotifyService) plays the Purchase sound
	end)
end

return LogPadController
