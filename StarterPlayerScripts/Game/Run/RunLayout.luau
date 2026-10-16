--[[
	RunLayout — which ramp field THIS client is looking at. The field is rolled here, on the client: a fresh random seed when the
	character spawns and again after every run (RunController.Release). The seed rides along with Launch, so the server
	(and everyone replaying the run) rebuilds the same field with Layout.For(seed); nothing else is synced.
	  RunLayout.Seed() -> number          RunLayout.Field() -> Layout field (Layout.For(Seed()))
	  RunLayout.Reroll(force?)            roll a new seed (ignored while a run is live unless force)
	  RunLayout.Use()                     a run started on the current field
	  RunLayout.ForLaunch() -> seed       the seed to Launch with: a fresh field first if the last run already used this one
	                                      (rolled again before the camera got back to the spawn)
	  RunLayout.OnChange(fn(field))       called after every reroll (SceneryController swaps the ramps)
	  RunLayout.Start()                   reroll on every spawn
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Modules.Layout)

local RunLayout = {}

local SEED_MAX = 2 ^ 30
local random = Random.new()
local seed = random:NextInteger(1, SEED_MAX)
local listeners: { (any) -> () } = {}
local used = false -- a run has been played on the current field

function RunLayout.Seed(): number
	return seed
end

function RunLayout.Field()
	return Layout.For(seed)
end

function RunLayout.OnChange(fn: (any) -> ())
	table.insert(listeners, fn)
end

function RunLayout.Reroll(force: boolean?)
	if Players.LocalPlayer:GetAttribute("Running") and not force then
		return
	end
	seed, used = random:NextInteger(1, SEED_MAX), false
	local field = Layout.For(seed)
	for _, fn in listeners do
		task.spawn(fn, field)
	end
end

function RunLayout.Use()
	used = true
end

function RunLayout.ForLaunch(): number
	if used then
		RunLayout.Reroll(true)
	end
	return seed
end

function RunLayout.Start()
	Players.LocalPlayer.CharacterAdded:Connect(function()
		RunLayout.Reroll() -- not the signal's argument: that would read as `force`
	end)
end

return RunLayout
