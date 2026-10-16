--[[
	CodesService — RedeemCode { Code }: pays a CodesConfig code's reward once per player (saved data.Codes[CODE] = true).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.CodesConfig)
local Em = require(ReplicatedStorage.Shared.Modules.Emphasis).Em
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local DataService = require(script.Parent.DataService)
local MonetizeService = require(script.Parent.MonetizeService)
local NotifyService = require(script.Parent.NotifyService)

local CodesService = {}

local T = Config.Text
local last: { [Player]: number } = {}

local function redeem(player: Player, payload)
	local data = DataService.Get(player)
	local code = type(payload) == "table" and type(payload.Code) == "string" and payload.Code:upper():gsub("%s", "")
	if not data or not code or os.clock() - (last[player] or 0) < Config.Cooldown then
		return
	end
	last[player] = os.clock()
	local def = Config.Codes[code]
	if not def then
		return NotifyService.Send(player, T.Invalid, "Error")
	elseif def.Expires and os.time() > def.Expires then
		return NotifyService.Send(player, T.Expired, "Error")
	elseif data.Codes[code] then
		return NotifyService.Send(player, T.Used, "Error")
	end
	data.Codes[code] = true
	NotifyService.Send(player, T.Redeemed:format(Em(MonetizeService.Bundle(player, data, def.Reward), "Success")), "Success")
end

function CodesService.Start()
	DataService.OnPrepare(function(_, data)
		data.Codes = data.Codes or {}
	end)
	Net.Get("RedeemCode"):Connect(redeem)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		last[player] = nil
	end)
end

return CodesService
