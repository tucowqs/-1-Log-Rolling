--[[
	TrailService — trails (TrailConfig). Saved: data.Trails = { [id] = true }, data.Trail = the equipped id (nil = none).
	TrailBuy { Id }: not owned -> buy with Wins (PurchaseService.Charge) and equip; owned -> equip, or unequip if equipped.
	The equipped trail's Boost is the player attribute TrailBoost (BoostMath adds it to the Speed multiplier); its Trail
	instance hangs between two attachments on every character's HumanoidRootPart.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoostConfig = require(ReplicatedStorage.Shared.Config.BoostConfig)
local Config = require(ReplicatedStorage.Shared.Config.TrailConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local DataService = require(script.Parent.DataService)
local PurchaseService = require(script.Parent.PurchaseService)

local TrailService = {}

local byId = {}
for _, def in Config.Trails do
	byId[def.Id] = def
end

local function sequence(colors): ColorSequence
	local keys = {}
	for i, color in colors do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(#colors - 1, 1), color))
	end
	return ColorSequence.new(keys)
end

local function dress(player: Player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local data = DataService.Get(player)
	if not (root and data) then
		return
	end
	local old = root:FindFirstChild("PlayerTrail")
	if old then
		old:Destroy()
	end
	local def = data.Trail and byId[data.Trail]
	player:SetAttribute(BoostConfig.TrailAttribute, if def then def.Boost else 0)
	if not def then
		return
	end
	local L = Config.Look
	local folder = Instance.new("Folder")
	folder.Name = "PlayerTrail"
	local top, bottom = Instance.new("Attachment"), Instance.new("Attachment")
	top.Position, bottom.Position = Vector3.new(0, L.Lift + L.Width / 2, 0), Vector3.new(0, L.Lift - L.Width / 2, 0)
	top.Parent, bottom.Parent = root, root
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = top, bottom
	trail.Color, trail.Lifetime, trail.LightEmission = sequence(def.Colors), L.Life, L.Light
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.FaceCamera = true
	trail.Parent = folder
	folder.Parent = root
	folder.Destroying:Connect(function()
		top:Destroy()
		bottom:Destroy()
	end)
end

local function buy(player: Player, payload)
	local data = DataService.Get(player)
	local def = data and type(payload) == "table" and byId[payload.Id]
	if not def then
		return
	end
	if not data.Trails[def.Id] then
		if not PurchaseService.Charge(player, def.Price, def.Name) then
			return
		end
		data.Trails[def.Id] = true
		data.Trail = def.Id
	elseif data.Trail == def.Id then
		data.Trail = nil
	else
		data.Trail = def.Id
	end
	DataService.Sync(player)
	dress(player)
end

function TrailService.Start()
	DataService.AddSnapshot("Trails")
	DataService.AddSnapshot("Trail")
	DataService.OnPrepare(function(_, data)
		data.Trails = data.Trails or {}
	end)
	DataService.OnLoaded(function(player)
		dress(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			dress(player)
		end)
	end)
	Net.Get("TrailBuy"):Connect(buy)
	for _, player in Players:GetPlayers() do
		task.spawn(dress, player)
	end
end

return TrailService
