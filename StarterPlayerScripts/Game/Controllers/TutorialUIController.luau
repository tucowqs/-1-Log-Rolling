--[[
	TutorialUIController — hides HUD pieces until the tutorial reaches the step where each first matters
	(TutorialConfig.Gates). Follows the player's "Tutorial" attribute (the current step Id, nil once finished)
	and "Loaded" (until the save loads nothing gated shows, so a new player never sees it flash on).
	A gated piece remembers the visibility its own controller asks for while hidden and gets that back when
	revealed, so nothing here fights the code that normally shows / hides it.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.TutorialConfig)

local TutorialUIController = {}

local player = Players.LocalPlayer
local gates = {}

local function stepIndex(id: string?): number?
	for index, step in Config.Steps do
		if step.Id == id then
			return index
		end
	end
	return nil
end

-- Whether a piece revealed From this step shows now.
local function reached(from: string): boolean
	if not player:GetAttribute("Loaded") then
		return false
	end
	local current = player:GetAttribute("Tutorial")
	if current == nil then
		return true -- tutorial finished (or never needed)
	end
	if from == "Done" then
		return false
	end
	local at, need = stepIndex(current), stepIndex(from)
	return at ~= nil and need ~= nil and at >= need
end

-- Gate one instance: ScreenGuis by Enabled, everything else by Visible.
local function gate(instance: Instance, from: string)
	local target: any = instance
	local property = instance:IsA("LayerCollector") and "Enabled" or "Visible"
	local wanted = target[property]
	local written = nil -- the last value we set (change signals arrive deferred, so a flag can't spot our own writes)
	local function apply()
		written = wanted and reached(from)
		target[property] = written
	end
	instance:GetPropertyChangedSignal(property):Connect(function()
		if target[property] == written then
			return -- our own write
		end
		wanted = target[property] -- its own controller's choice, honoured once revealed
		if wanted and not reached(from) then
			apply()
		end
	end)
	table.insert(gates, apply)
	apply()
end

local function find(path: { string }): Instance
	local node: Instance = player:WaitForChild("PlayerGui")
	for _, name in path do
		node = node:WaitForChild(name)
	end
	return node
end

local function refresh()
	for _, apply in gates do
		apply()
	end
end

function TutorialUIController.Start()
	for _, entry in Config.Gates do
		task.spawn(function()
			gate(find(entry.Path), entry.From)
		end)
	end
	player:GetAttributeChangedSignal("Tutorial"):Connect(refresh)
	player:GetAttributeChangedSignal("Loaded"):Connect(refresh)
end

return TutorialUIController
