--[[
	LimitedService — the global stock of the limited Robux items (LimitedConfig). Grants never yield (they run inside
	ProcessReceipt), so the sale is counted locally at once and added to the DataStore counter in its own thread; every
	Refresh seconds the shared count is read back into workspace attributes "Limited<Key>Sold".
	  LimitedService.Grant(player, data, key) -> toast text   gives the pet / the log (owned + equipped) and counts the sale
]]
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.LimitedConfig)
local Curves = require(ReplicatedStorage.Shared.Modules.Curves)
local PetMath = require(ReplicatedStorage.Shared.Modules.PetMath)
local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)

local LimitedService = {}

local store = DataStoreService:GetDataStore(Config.Store)

local function attribute(key: string): string
	return "Limited" .. key .. "Sold"
end

local function sold(key: string): number
	return workspace:GetAttribute(attribute(key)) or 0
end

function LimitedService.Grant(player: Player, data, key: string): string
	local item = Config.Items[key]
	local name
	if item.Pet then
		PetService.Give(player, data, { item.Pet })
		name = PetMath.Pet(item.Pet).Name
	else
		data.Logs[item.Log] = true
		data.Equipped = item.Log
		DataService.Changed(player)
		DataService.Sync(player)
		name = Curves.LogById[item.Log].Name
	end
	workspace:SetAttribute(attribute(key), sold(key) + 1)
	task.spawn(pcall, store.IncrementAsync, store, key, 1)
	return Config.Text.Granted:format(name, sold(key), item.Stock)
end

local function read()
	for key in Config.Items do
		local ok, value = pcall(store.GetAsync, store, key)
		if ok then
			workspace:SetAttribute(attribute(key), math.max(value or 0, sold(key)))
		end
	end
end

function LimitedService.Start()
	for key in Config.Items do
		workspace:SetAttribute(attribute(key), 0)
	end
	task.spawn(function()
		while true do
			read()
			task.wait(Config.Refresh)
		end
	end)
end

return LimitedService
