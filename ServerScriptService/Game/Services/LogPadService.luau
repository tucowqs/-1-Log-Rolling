--[[
	LogPadService — the purchasable logs on the podium near spawn (Workspace.LogPads.<LogId>, built in Studio by tools/build_lobby.lua from
	BalanceConfig.LogPads). Each pedestal is a Studs plate with a part-built log on it. Using the pedestal's ProximityPrompt (made by LogPadController, it sends LogPadUse) calls LogService.Touch: enough Wins
	buys and equips the log (an owned one just equips); the server checks the player is beside the pedestal. The price/name sit on the pedestal as attributes for the client's billboard
	(LogPadController); the server alone decides every purchase.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local LogService = require(script.Parent.LogService)

local LogPadService = {}

local P = Config.LogPads
local recent: { [string]: number } = {} -- "<userId>:<logId>" -> os.clock of the last trigger

local function used(player: Player, payload)
	local id = typeof(payload) == "table" and payload.Id
	local model = typeof(id) == "string" and workspace:FindFirstChild("LogPads") and workspace.LogPads:FindFirstChild(id)
	local pad, root = model and model:FindFirstChild("Pad"), player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not pad or not root or (root.Position - pad.Position).Magnitude > P.Prompt.Distance + P.Prompt.Slack + pad.Size.X / 2 then
		return
	end
	local key, now = `{player.UserId}:{id}`, os.clock()
	if recent[key] and now - recent[key] < P.Cooldown then
		return
	end
	recent[key] = now
	LogService.Touch(player, id)
end

function LogPadService.Start()
	Net.Get("LogPadUse"):Connect(used)
end

return LogPadService
