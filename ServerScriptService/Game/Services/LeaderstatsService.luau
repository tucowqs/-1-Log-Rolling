--[[
	LeaderstatsService — the player list's columns (LeaderstatsConfig): a "leaderstats" folder on each
	player with one value per stat, kept in step with the player attribute it mirrors. It never writes
	data: whoever owns the value (DataService's attribute mirror, a game service) sets the attribute.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.LeaderstatsConfig)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)

local LeaderstatsService = {}

local function show(value: any, amount: number)
	value.Value = if Config.Abbreviate then NumberFormat.Abbreviate(amount) else math.floor(amount)
end

local function setup(player: Player)
	if player:FindFirstChild("leaderstats") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	for _, stat in Config.Stats do
		local value = Instance.new(Config.Abbreviate and "StringValue" or "IntValue")
		value.Name = stat.Name
		value.Parent = folder
		local function sync()
			show(value, player:GetAttribute(stat.Attribute) or 0)
		end
		player:GetAttributeChangedSignal(stat.Attribute):Connect(sync)
		sync()
	end
	folder.Parent = player
end

function LeaderstatsService.Start()
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
end

return LeaderstatsService
