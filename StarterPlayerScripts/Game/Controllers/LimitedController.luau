--[[
	LimitedController — the limited-stock pedestals in the lobby (LimitedConfig; Rock Skipping's "STOCK 8535/10000 / BEST IN
	GAME / Always 1200% Better"). On every Workspace.LimitedPedestals.<key> anchor this client places the Blender pedestal, the
	item floating and turning over it, a billboard (live STOCK from the workspace attribute Limited<Key>Sold, the config Lines,
	the Robux price or SOLD OUT) and a prompt: Buy (ShopController.Buy of the item's product), or for an owned log Equip.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.LimitedConfig)
local AssetLibrary = require(ReplicatedStorage.Shared.Modules.AssetLibrary)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)
local ShopMath = require(ReplicatedStorage.Shared.Modules.ShopMath)
local Ui = require(ReplicatedStorage.Shared.Modules.Ui)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)
local WorldLabel = require(ReplicatedStorage.Shared.Modules.WorldLabel)
local ClientState = require(script.Parent.Parent.State.ClientState)
local ShopController = require(script.Parent.ShopController)

local LimitedController = {}

local T = Config.Text
local B, F = Config.Billboard, Config.Float
local floating = {}

local function line(parent: Instance, text: string, kind: string, y: number, h: number): TextLabel
	local label = UiPack.Get("StatText")
	label.Size, label.Position, label.AnchorPoint = UDim2.fromScale(1, h), UDim2.fromScale(0.5, y), Vector2.new(0.5, 0.5)
	for _, layer in { label, label:FindFirstChild("Color") } do
		layer.TextXAlignment = Enum.TextXAlignment.Center
	end
	label.Parent = parent
	UiPack.Text(label, text)
	UiPack.TextGradient(label, kind)
	return label
end

local function billboard(key: string, item, anchor: BasePart)
	local gui = Ui.Make("BillboardGui", { Name = "Limited_" .. key, Adornee = anchor, LightInfluence = 0, MaxDistance = 300, ResetOnSpawn = false, AlwaysOnTop = true,
		StudsOffsetWorldSpace = Vector3.new(0, B.Lift, 0), ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	WorldLabel.Apply(gui, B)
	local rows = #item.Lines + 2
	local h = 1 / rows
	local stock = line(gui, "", "White", h / 2, h * 0.8)
	for i, entry in item.Lines do
		line(gui, entry[1], entry[2], h * (i + 0.5), h)
	end
	local price = line(gui, T.Price:format(UiPack.Robux(ShopMath.Items[item.Product].Def.Price)), "Green", h * (rows - 0.5), h * 0.9)
	local function refresh()
		local sold = workspace:GetAttribute("Limited" .. key .. "Sold") or 0
		UiPack.Text(stock, T.Stock:format(NumberFormat.Commas(math.max(item.Stock - sold, 0)), NumberFormat.Commas(item.Stock)))
		if sold >= item.Stock then
			UiPack.Text(price, T.SoldOut)
			UiPack.TextGradient(price, "Red")
		end
	end
	workspace:GetAttributeChangedSignal("Limited" .. key .. "Sold"):Connect(refresh)
	refresh()
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function owned(item): boolean
	return item.Log ~= nil and (ClientState.Data.Logs or {})[item.Log] == true
end

local function prompt(key: string, item, anchor: BasePart)
	local p = Instance.new("ProximityPrompt")
	p.ObjectText, p.MaxActivationDistance, p.RequiresLineOfSight, p.HoldDuration = ShopMath.Items[item.Product].Def.Name, Config.Prompt.Distance, false, 0
	local function refresh()
		p.ActionText = if owned(item) then Config.Prompt.Equip else Config.Prompt.Buy
	end
	p.Triggered:Connect(function()
		if owned(item) then
			Net.Get("EquipLog"):Fire({ Id = item.Log })
		elseif (workspace:GetAttribute("Limited" .. key .. "Sold") or 0) < item.Stock then
			ShopController.Buy(item.Product)
		end
	end)
	ClientState.On("Data", refresh)
	refresh()
	p.Parent = anchor
end

local function build(key: string, item, anchor: BasePart)
	local pedestal = AssetLibrary.Wait("LimitedPedestal")
	pedestal:PivotTo(anchor.CFrame)
	pedestal.Parent = workspace
	local model = AssetLibrary.Wait(item.Model)
	model:ScaleTo(model:GetScale() * item.ModelSize / math.max(model:GetExtentsSize().X, model:GetExtentsSize().Y, model:GetExtentsSize().Z))
	model.Parent = workspace
	table.insert(floating, { Model = model, Base = anchor.CFrame * CFrame.new(0, 2.5 + F.Lift, 0), Phase = #floating })
	billboard(key, item, anchor)
	prompt(key, item, anchor)
end

function LimitedController.Start()
	local folder = workspace:WaitForChild(Config.Folder)
	for key, item in Config.Items do
		task.spawn(build, key, item, folder:WaitForChild(key))
	end
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for _, entry in floating do
			local bob = math.sin(now * F.Speed + entry.Phase) * F.Bob
			entry.Model:PivotTo(entry.Base * CFrame.new(0, bob, 0) * CFrame.Angles(0, now * F.Turn, 0))
		end
	end)
end

return LimitedController
