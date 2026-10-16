--[[
	CmdrController — the Cmdr admin console on the client (settings: CmdrConfig): opens with F2 for admins
	(and anyone in a Studio playtest); switched off for everyone else. The server checks again before
	running anything (CmdrService's BeforeRun hook), so this is only about showing the console.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.CmdrConfig)

local CmdrController = {}

function CmdrController.Start()
	local Cmdr = require(ReplicatedStorage:WaitForChild("CmdrClient"))
	local admin = (Config.StudioOpen and RunService:IsStudio()) or table.find(Config.Admins, Players.LocalPlayer.UserId) ~= nil
	Cmdr:SetActivationKeys(Config.ActivationKeys)
	Cmdr:SetEnabled(admin)
end

return CmdrController
