--[[
	Worlds — the one source of truth for world lookups (WorldsConfig), shared by server and client.
	  Worlds.Count                    number of worlds
	  Worlds.Get(w) -> def            Worlds.Area(w, i) -> zone def (name, WinsMult, colours, props, wall look)
	  Worlds.Of(player) -> w          the world the player is in (attribute "World", 1 until WorldService sets it)
	  Worlds.Offset(w) -> Vector3     where world w is built relative to World 1
	  Worlds.Unlocked(player, w)      w is open for the player (attribute "Worlds" = a comma list of unlocked worlds; 1 always)
	  Worlds.Spawn(w) -> CFrame       the arrival point in world w (facing the start line)
	  Worlds.At(position) -> w        which world a position is in (nearest Offset on X)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local Config = require(ReplicatedStorage.Shared.Config.WorldsConfig)

local Worlds = {}

Worlds.Count = #Config.Worlds

function Worlds.Get(w: number)
	return Config.Worlds[w]
end

function Worlds.Area(w: number, index: number)
	return Config.Worlds[w].Areas[index]
end

function Worlds.Of(player: Player): number
	return player:GetAttribute("World") or 1
end

function Worlds.Offset(w: number): Vector3
	return Config.Worlds[w].Offset
end

function Worlds.Unlocked(player: Player, w: number): boolean
	return w == 1 or table.find(string.split(player:GetAttribute("Worlds") or "", ","), tostring(w)) ~= nil
end

function Worlds.Spawn(w: number): CFrame
	local at = BalanceConfig.Track.Origin + Config.Worlds[w].Offset + Config.Spawn
	return CFrame.lookAt(at, at + Vector3.new(0, 0, 1))
end

function Worlds.At(position: Vector3): number
	local best, gap = 1, math.huge
	for w, def in Config.Worlds do
		local d = math.abs(position.X - def.Offset.X)
		if d < gap then
			best, gap = w, d
		end
	end
	return best
end

return Worlds
