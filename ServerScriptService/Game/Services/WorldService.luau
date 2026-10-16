--[[
	WorldService — which world each player is in (WorldsConfig / Worlds). Saved: data.World (the world they were last in) and
	data.Worlds (unlocked worlds, keyed by the world number AS A STRING so the save never becomes a sparse array). Attributes: "World" (current) and "Worlds" (comma list of unlocked, read by Worlds.Unlocked).
	  WorldTravel { World }  unlocks it if the player has its Need in Speed, then teleports them to its spawn (not mid-run);
	                         the Worlds window and the lobby portals send it
	Every (re)spawn lands at the player's world's spawn (the place's SpawnLocation is World 1's).
	  WorldService.Send(player, w)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.WorldsConfig)
local Em = require(ReplicatedStorage.Shared.Modules.Emphasis).Em
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)
local Worlds = require(ReplicatedStorage.Shared.Modules.Worlds)
local DataService = require(script.Parent.DataService)
local NotifyService = require(script.Parent.NotifyService)
local TrainingService = require(script.Parent.TrainingService)

local WorldService = {}

local T = Config.Text

local function publish(player: Player, data)
	local list = {}
	for w in data.Worlds do
		table.insert(list, w)
	end
	player:SetAttribute("Worlds", table.concat(list, ","))
	player:SetAttribute("World", data.World)
end

local function place(player: Player)
	local character = player.Character
	if character and Worlds.Of(player) ~= 1 then
		character:PivotTo(Worlds.Spawn(Worlds.Of(player)))
	end
end

function WorldService.Send(player: Player, w: number)
	local data = DataService.Get(player)
	if not data or not Worlds.Get(w) then
		return
	end
	TrainingService.Stop(player)
	player:SetAttribute("Fallen", nil)
	data.World = w
	publish(player, data)
	local character = player.Character
	if character then
		character:PivotTo(Worlds.Spawn(w))
	end
end

local function travel(player: Player, payload)
	local data = DataService.Get(player)
	local w = type(payload) == "table" and tonumber(payload.World)
	local def = w and Worlds.Get(w)
	if not data or not def or player:GetAttribute("Running") or Worlds.Of(player) == w then
		return
	end
	if not data.Worlds[tostring(w)] then
		if data.Speed < def.Need then
			return NotifyService.Send(player, T.NeedMore:format(Em(NumberFormat.Abbreviate(def.Need), "Error"), def.Name), "Error")
		end
		data.Worlds[tostring(w)] = true
		NotifyService.Send(player, T.Unlocked:format(Em(def.Name, "Success")), "Success")
	end
	WorldService.Send(player, w)
end

function WorldService.Start()
	DataService.OnPrepare(function(_, data)
		data.Worlds = data.Worlds or { ["1"] = true }
		data.World = if data.World and data.Worlds[tostring(data.World)] then data.World else 1
	end)
	DataService.OnLoaded(function(player, data)
		publish(player, data)
		place(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			task.defer(place, player)
		end)
	end)
	Net.Get("WorldTravel"):Connect(travel)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("World", player:GetAttribute("World") or 1)
	end
end

return WorldService
