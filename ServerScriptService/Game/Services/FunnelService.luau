--[[
	FunnelService — the game's ONE wrapper round AnalyticsService (server-only; logs nothing in Studio,
	shows in the published game's Creator Dashboard a day later). Every name comes from FunnelConfig;
	every call is pcall-guarded so analytics can never break gameplay.
	  Onboard(player, stepName)            one-time onboarding step (saved high-water data.OnboardingStep)
	  Step(player, funnel, step, session?) a repeatable funnel step; step 1 opens a new session, later steps
	                                       join the open one (pass `session` to key it yourself, e.g. an item uid)
	  Milestone(player, key, index, nameOf) a lifetime milestone funnel (saved high-water data.Milestones)
	  Economy(player, "Source"|"Sink", amount, transactionType, sku)   transactionType = an
	                                       Enum.AnalyticsEconomyTransactionType name ("Shop", "IAP", "Gameplay"...)
	  Event(player, key, fields?, value?)  a custom event (FunnelConfig.Events[key])
	The automatic watchers (onboarding, milestones, income, client reports) live in FunnelWatchService.
]]
local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.FunnelConfig)
local DataConfig = require(ReplicatedStorage.Shared.Config.DataConfig)
local DataService = require(script.Parent.DataService)

local FunnelService = {}

local FIELD_KEYS = { "CustomField01", "CustomField02", "CustomField03" }

local open: { [Player]: { [string]: string } } = {} -- funnel -> current session id
local reached: { [Player]: { [string]: number } } = {} -- session id -> last step logged in it

local function call(method: string, ...)
	local ok, err = pcall(AnalyticsService[method], AnalyticsService, ...)
	if not ok then
		warn("[FunnelService]", method, err)
	end
end

local function fieldsOf(names: { string }, values): { [string]: string }?
	if not values then
		return nil
	end
	local fields = {}
	for i, name in names do
		if values[name] ~= nil then
			fields[Enum.AnalyticsCustomFieldKeys[FIELD_KEYS[i]].Name] = tostring(values[name])
		end
	end
	return fields
end

function FunnelService.Onboard(player: Player, stepName: string)
	local data = DataService.Get(player)
	local index = table.find(Config.Onboarding, stepName)
	if not (data and index) or index <= data.OnboardingStep then
		return
	end
	data.OnboardingStep = index
	call("LogOnboardingFunnelStepEvent", player, index, stepName)
end

function FunnelService.Step(player: Player, funnel: string, step: string, session: string?)
	local def = Config.Funnels[funnel]
	local index = def and table.find(def.Steps, step)
	if not index or player.Parent ~= Players then
		return
	end
	open[player] = open[player] or {}
	reached[player] = reached[player] or {}
	if not session then
		if index == 1 or not open[player][funnel] then
			open[player][funnel] = HttpService:GenerateGUID(false)
		end
		session = open[player][funnel]
	end
	if (reached[player][session] or 0) >= index then
		return -- already logged this far in this session
	end
	reached[player][session] = index
	call("LogFunnelStepEvent", player, funnel, session, index, step)
	if index == #def.Steps then
		reached[player][session] = nil
		if open[player][funnel] == session then
			open[player][funnel] = nil
		end
	end
end

-- Lifetime milestone `index` of FunnelConfig.Milestones[key] (and every one below it not yet logged).
function FunnelService.Milestone(player: Player, key: string, index: number, nameOf: (number) -> string)
	local data = DataService.Get(player)
	local from = data and data.Milestones[key] or 0
	if not data or index <= from then
		return
	end
	data.Milestones[key] = index
	for i = from + 1, index do
		call("LogFunnelStepEvent", player, Config.Milestones[key].Funnel, tostring(player.UserId), i, nameOf(i))
	end
end

function FunnelService.Economy(player: Player, flow: string, amount: number, transactionType: string, sku: string?)
	local data = DataService.Get(player)
	if not data or not (amount > 0 and amount < math.huge) then
		return
	end
	call("LogEconomyEvent", player, Enum.AnalyticsEconomyFlowType[flow], Config.Currency, amount,
		data[DataConfig.Currency], Enum.AnalyticsEconomyTransactionType[transactionType].Name, sku)
end

function FunnelService.Event(player: Player, key: string, values, value: number?)
	local def = Config.Events[key]
	if def and player.Parent == Players then
		call("LogCustomEvent", player, def.Name, value or 1, fieldsOf(def.Fields, values))
	end
end

function FunnelService.Start()
	DataService.OnPrepare(function(_, data)
		data.OnboardingStep = data.OnboardingStep or 0
		data.Milestones = data.Milestones or {}
	end)
	Players.PlayerRemoving:Connect(function(player)
		open[player] = nil
		reached[player] = nil
	end)
end

return FunnelService
