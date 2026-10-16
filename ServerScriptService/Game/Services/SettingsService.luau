--[[
	SettingsService — the saved settings (data.Settings, SettingsConfig.Rows of Kind "Toggle"): defaults
	them on load, sends them in the client snapshot (ClientState.Settings) and stores the client's changes
	from "SaveSettings" { [Key] = value } — only known keys, only the Default's type. The keys in
	SettingsConfig.Attributes are mirrored to Player attributes (Ambient reads "ReducedEffects").
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.SettingsConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local DataService = require(script.Parent.DataService)

local SettingsService = {}

local defaults = {}
for _, row in Config.Rows do
	if row.Kind == "Toggle" then
		defaults[row.Key] = row.Default
	end
end

local function mirror(player: Player, settings)
	for _, key in Config.Attributes do
		player:SetAttribute(key, settings[key])
	end
end

function SettingsService.Get(player: Player, key: string): any
	local data = DataService.Get(player)
	return data and data.Settings[key]
end

function SettingsService.Start()
	DataService.AddSnapshot("Settings")
	DataService.OnPrepare(function(player, data)
		data.Settings = data.Settings or {}
		for key, value in defaults do
			if typeof(data.Settings[key]) ~= typeof(value) then
				data.Settings[key] = value
			end
		end
		mirror(player, data.Settings)
	end)
	Net.Get("SaveSettings"):Connect(function(player, payload)
		local data = DataService.Get(player)
		if not data or typeof(payload) ~= "table" then
			return
		end
		for key, value in payload do
			if defaults[key] ~= nil and typeof(value) == typeof(defaults[key]) then
				data.Settings[key] = value
			end
		end
		mirror(player, data.Settings)
	end)
end

return SettingsService
