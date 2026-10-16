--[[
	Net - the one registry of BridgeNet2 bridges. Net.Get("Name") returns the server or client bridge
	for the running side. Every bridge carries ONE table payload (BridgeNet2 drops extra arguments):
		server: Net.Get("Notify"):Fire(player, { Text = "Hi" })      handler (player, payload)
		client: Net.Get("Buy"):Fire({ Id = "Sword" })                 handler (payload)
	Bridge names are declared by systems, not here: every ModuleScript in Shared/Config may return a
	`Bridges = { "Name", ... }` list, and Net registers the union. One client Connect per bridge.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BridgeNet2 = require(ReplicatedStorage.Packages.BridgeNet2)

local Net = {}
local names: { [string]: string } = {} -- bridge name -> config that declared it
local cache = {}

for _, module in ReplicatedStorage.Shared.Config:GetChildren() do
	if module:IsA("ModuleScript") then
		local config = require(module)
		for _, name in if type(config) == "table" and config.Bridges then config.Bridges else {} do
			assert(not names[name], `bridge {name} declared by both {names[name]} and {module.Name}`)
			names[name] = module.Name
		end
	end
end

function Net.Get(name: string)
	assert(names[name], "unknown bridge " .. name .. " (add it to a Config's Bridges list)")
	if not cache[name] then
		cache[name] = if RunService:IsServer() then BridgeNet2.ServerBridge(name) else BridgeNet2.ClientBridge(name)
	end
	return cache[name]
end

function Net.All()
	return BridgeNet2.AllPlayers()
end

-- Server: create every bridge up front so clients never wait on a missing one.
function Net.Prepare()
	for name in names do
		Net.Get(name)
	end
end

return Net
