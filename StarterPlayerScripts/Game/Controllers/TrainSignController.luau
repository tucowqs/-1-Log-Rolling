--[[
	TrainSignController — the treadmill signs' per-player status. Each belt's billboard (built in Studio by tools/lobby_layout.lua)
	shows [rebirth icon] N, a "Status" line and "Nx SPEED"; here the Status reads UNLOCKED (green) once the player has the
	belt's rebirths, LOCKED (red) until then. A Robux zone (station Pass) reads its price (ONLY R$N, gold) until the pass is
	owned. Follows the player's "Rebirths" and zone pass attributes. Texts: BalanceConfig.Training.Sign.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local Curves = require(ReplicatedStorage.Shared.Modules.Curves)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)

local TrainSignController = {}

local S = Config.Training.Sign
local player = Players.LocalPlayer
local signs = {} -- { { Def, Status } }

local function refresh()
	local rebirths = player:GetAttribute("Rebirths") or 0
	for _, sign in signs do
		local def, status = sign.Def, sign.Status
		local pass = def.Pass and ShopConfig.Passes[def.Pass]
		local open = if pass then player:GetAttribute(pass.Attribute) == true else rebirths >= def.Rebirths
		if status:GetAttribute("Open") ~= open then
			status:SetAttribute("Open", open)
			UiPack.Text(status, if open then S.Unlocked elseif pass then S.Price:format(UiPack.Robux(pass.Price)) else S.Locked)
			UiPack.TextGradient(status, if open then "Green" elseif pass then "Gold" else "Red")
		end
	end
end

function TrainSignController.Start()
	local folder = workspace:WaitForChild("Training")
	for _, def in Curves.Treadmills do
		local deck = folder:WaitForChild(def.Id):WaitForChild("Belt")
		table.insert(signs, { Def = def, Status = deck:WaitForChild("Billboard"):WaitForChild("Status") })
	end
	player:GetAttributeChangedSignal("Rebirths"):Connect(refresh)
	for _, def in Config.Training.Treadmills do
		if def.Pass then
			player:GetAttributeChangedSignal(ShopConfig.Passes[def.Pass].Attribute):Connect(refresh)
		end
	end
	refresh()
end

return TrainSignController
