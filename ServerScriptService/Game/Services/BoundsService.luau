--[[
	BoundsService — a player who walks off the hill (past the banks or below the slope) is respawned at the top
	instead of free-falling thousands of studs (in their own world: positions are taken relative to its Offset). Checked once a second; a rolling player is never touched (their client
	places them on the log). Distances: BalanceConfig.Track.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local Track = require(ReplicatedStorage.Shared.Modules.Track)
local Worlds = require(ReplicatedStorage.Shared.Modules.Worlds)

local BoundsService = {}

local DROP = 140 -- studs below the slope surface before a respawn
local SIDE = math.max(Config.Track.SurfaceHalfWidth + 60, 225) -- the lobby is 200 wide each side (tools/lobby_layout.lua)

function BoundsService.Start()
	task.spawn(function() -- a loop inside Start would read as a HANGING Start
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and not player:GetAttribute("Running") then
					local p = root.Position - Worlds.Offset(Worlds.Of(player)) -- every world is the same hill, Offset away
					local surface = if p.Z < 0 then Config.Track.Origin.Y else Track.Pos(Track.SFromZ(p.Z)).Y
					if p.Y < surface - DROP or math.abs(p.X) > SIDE then
						player:LoadCharacter()
					end
				end
			end
		end
	end)
end

return BoundsService
