--[[
	LogAffordController — a toast nudging the player to the log stand when they can afford a new log. Only the BEST log their Wins cover and they
	don't own is announced (never a cheaper one), and only if it beats every log they already own (Speed / hit, Curves.LogMult:
	nobody is sent to buy a downgrade), once per log per session (BalanceConfig.LogPads.Afford). It waits while a roll is in flight (the Wins arrive when the log
	breaks, mid-cutscene), while the player is lying down, and during the tutorial (its Buy step already points at the log).
	With the toast, the tutorial's arrow beam and marker (GuidePointer) point at that log's pad until they own it or start
	another roll; it hides while a window is open. Only one nudge at a time: while an egg nudge is up
	(EggGuideController.Wanted) the log waits, so a pet beats a log.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local Curves = require(ReplicatedStorage.Shared.Modules.Curves)
local Worlds = require(ReplicatedStorage.Shared.Modules.Worlds)
local Emphasis = require(ReplicatedStorage.Shared.Modules.Emphasis)
local GuidePointer = require(ReplicatedStorage.Shared.Modules.GuidePointer)
local ClientState = require(script.Parent.Parent.State.ClientState)
local EggGuideController = require(script.Parent.EggGuideController)
local NotifyController = require(script.Parent.NotifyController)

local LogAffordController = {}

local A = Config.LogPads.Afford
local player = Players.LocalPlayer
local told: { [string]: boolean } = {}
local guiding: string? = nil -- the announced log the beam points at
local pointer

-- The Speed / hit of the strongest log they own (a Better log counts at its boosted value).
local function bestOwnedMult(owned): number
	local top = 0
	for id, has in owned do
		if has and Curves.LogById[id] then
			top = math.max(top, Curves.LogMult(id, owned))
		end
	end
	return top
end

-- The best (most expensive) log they don't own that their Wins cover and that beats everything they own, or nil.
local function bestAffordable()
	local owned, wins, best = ClientState.Data.Logs or {}, player:GetAttribute("Wins") or 0, nil
	local ownedTop = bestOwnedMult(owned)
	for _, log in Config.Logs do
		local here = (log.World or 1) == Worlds.Of(player) -- only logs on this world's pads
		local upgrade = Curves.LogMult(log.Id, owned) > ownedTop
		if here and upgrade and not owned[log.Id] and wins >= log.Price and (not best or log.Price > best.Price) then
			best = log
		end
	end
	return best
end

local function check()
	local log = bestAffordable()
	local calm = player:GetAttribute("Loaded") == true and not player:GetAttribute("Running") and not player:GetAttribute("Fallen")
		and player:GetAttribute("Tutorial") == nil
	if log and calm and not told[log.Id] and not EggGuideController.Wanted() then
		told[log.Id], guiding = true, log.Id
		NotifyController.Toast(A.Text:format(Emphasis.Em(log.Name, A.Kind)), A.Kind)
	end
end

local function padOf(id: string): BasePart?
	local pads = workspace:FindFirstChild("LogPads")
	local model = pads and pads:FindFirstChild(id)
	local pad = model and model:FindFirstChild("Pad")
	return if pad and pad:IsA("BasePart") then pad else nil
end

local function update()
	local owned = ClientState.Data.Logs or {}
	if guiding and (owned[guiding] or Curves.LogMult(guiding, owned) <= bestOwnedMult(owned)) then
		guiding = nil -- bought it, or got something better meanwhile
	end
	local busy = player:GetAttribute("Running") or player:GetAttribute("Tutorial") ~= nil or ClientState.MenuOpen() ~= nil
		or EggGuideController.Wanted()
	pointer:Update(if guiding and not busy then padOf(guiding) else nil, A.Marker or "BUY")
end

function LogAffordController.Start()
	pointer = GuidePointer.new("LogGuide")
	player:GetAttributeChangedSignal("Running"):Connect(function()
		if player:GetAttribute("Running") then
			guiding = nil -- they rolled again instead
		end
	end)
	RunService.RenderStepped:Connect(update)
	for _, attribute in { "Wins", "Running", "Fallen", "Tutorial", "Loaded" } do
		player:GetAttributeChangedSignal(attribute):Connect(check)
	end
	ClientState.On("Data", check)
	check()
end

return LogAffordController
