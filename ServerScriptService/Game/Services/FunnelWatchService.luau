--[[
	FunnelWatchService — the analytics that need no hook in other systems (names: FunnelConfig, logging:
	FunnelService). Watches:
	  data loaded                   -> onboarding "Joined"
	  the "Tutorial" attribute      -> onboarding steps (FunnelConfig.Tutorial); cleared = TutorialDone, or the
	                                   TutorialSkipped event when TutorialService set "TutorialSkipped"
	  attributes (PollInterval)     -> the FunnelConfig.Milestones
	  the IncomeAttribute           -> passive income summed into one economy Source every IncomeFlush
	  the "Analytics" bridge        -> the client's menu opens and allowlisted client funnel steps
	Game-specific watchers (zones reached, items grabbed) belong in the game's own service.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.FunnelConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)
local DataService = require(script.Parent.DataService)
local FunnelService = require(script.Parent.FunnelService)

local FunnelWatchService = {}

local earned: { [Player]: number } = {} -- passive income not logged yet
local lastReport: { [Player]: number } = {}

local function atName(key: string)
	return function(i: number): string
		return NumberFormat.Abbreviate(Config.Milestones[key].At[i]) .. "+"
	end
end

-- How many of the ascending thresholds `value` has reached.
local function reachedOf(at: { number }, value: number): number
	local n = 0
	for i, threshold in at do
		if value >= threshold then
			n = i
		end
	end
	return n
end

local function onTutorial(player: Player, last: string?)
	local id = player:GetAttribute("Tutorial")
	if id then
		local step = Config.Tutorial[id]
		if step then
			FunnelService.Onboard(player, step)
		end
	elseif last then
		if player:GetAttribute("TutorialSkipped") then
			FunnelService.Event(player, "TutorialSkipped", { Step = last })
		else
			FunnelService.Onboard(player, Config.TutorialDone)
		end
	end
end

local function watch(player: Player)
	local last = player:GetAttribute("Tutorial")
	player:GetAttributeChangedSignal("Tutorial"):Connect(function()
		onTutorial(player, last)
		last = player:GetAttribute("Tutorial")
	end)
end

local function poll(player: Player)
	for key, def in Config.Milestones do
		local value = player:GetAttribute(def.Attribute)
		if typeof(value) == "number" then
			local n = reachedOf(def.At, value)
			if n > 0 then
				FunnelService.Milestone(player, key, n, atName(key))
			end
		end
	end
	if Config.IncomeAttribute then
		earned[player] = (earned[player] or 0) + (player:GetAttribute(Config.IncomeAttribute) or 0) * Config.PollInterval
	end
end

local function flush(player: Player)
	local amount = math.floor(earned[player] or 0)
	earned[player] = 0
	FunnelService.Economy(player, "Source", amount, "Gameplay", "Passive Income")
end

-- The client's reports: { Menu = name } or { Funnel = name, Step = name } (only FunnelConfig's Client steps).
local function onReport(player: Player, payload)
	local t = os.clock()
	if typeof(payload) ~= "table" or t - (lastReport[player] or 0) < Config.ClientCooldown then
		return
	end
	lastReport[player] = t
	if typeof(payload.Menu) == "string" and table.find(Config.Menus, payload.Menu) then
		FunnelService.Event(player, "MenuOpened", { Menu = payload.Menu })
		local step = Config.MenuSteps[payload.Menu]
		if step then
			FunnelService.Step(player, step[1], step[2])
		end
	elseif typeof(payload.Funnel) == "string" and typeof(payload.Step) == "string" then
		local def = Config.Funnels[payload.Funnel]
		if def and def.Client and table.find(def.Client, payload.Step) then
			FunnelService.Step(player, payload.Funnel, payload.Step)
		end
	end
end

function FunnelWatchService.Start()
	Net.Get("Analytics"):Connect(onReport)
	DataService.OnLoaded(function(player)
		FunnelService.Onboard(player, "Joined")
		onTutorial(player, nil)
	end)
	DataService.OnLeaving(flush)
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		earned[player], lastReport[player] = nil, nil
	end)
	task.spawn(function()
		local elapsed = 0
		while true do
			task.wait(Config.PollInterval)
			elapsed += Config.PollInterval
			local flushNow = Config.IncomeAttribute ~= nil and elapsed >= Config.IncomeFlush
			if flushNow then
				elapsed = 0
			end
			for _, player in Players:GetPlayers() do
				if DataService.Get(player) then
					poll(player)
					if flushNow then
						flush(player)
					end
				end
			end
		end
	end)
end

return FunnelWatchService
