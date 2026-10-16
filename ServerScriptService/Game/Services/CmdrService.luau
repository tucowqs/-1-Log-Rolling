--[[
	CmdrService — the Cmdr admin console on the server (settings: CmdrConfig): registers Cmdr's built-ins,
	the game's types (Game.CmdrTypes, if the folder exists) BEFORE its commands (Game.Commands), and a
	BeforeRun hook so only admins (or anyone in a Studio playtest) can run anything.
	  CmdrService.IsAdmin(player) -> bool
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Cmdr = require(ServerStorage.ServerPackages.Cmdr)
local Config = require(ReplicatedStorage.Shared.Config.CmdrConfig)

local CmdrService = {}

function CmdrService.IsAdmin(player: Player): boolean
	return (Config.StudioOpen and RunService:IsStudio()) or table.find(Config.Admins, player.UserId) ~= nil
end

function CmdrService.Start()
	local root = script.Parent.Parent
	if Config.DefaultCommands then
		Cmdr:RegisterDefaultCommands()
	end
	local types = root:FindFirstChild("CmdrTypes")
	if types then
		Cmdr:RegisterTypesIn(types)
	end
	Cmdr:RegisterCommandsIn(root.Commands)
	Cmdr.Registry:RegisterHook("BeforeRun", function(context)
		if not CmdrService.IsAdmin(context.Executor) then
			return Config.Denied
		end
		return nil
	end)
end

return CmdrService
