--[[
	EggGuideController — tells the player when they can afford an egg (PetsConfig.Eggs Price, in Wins) and points the way: a toast the
	first time their Wins cover each egg this session (only eggs they have never bought before), plus the tutorial's arrow beam and marker to its podium (PetsConfig.Guide). The beam
	follows the most expensive egg they can afford and stops once they walk up to the podium (within Billboard.Show, where the hatch panel
	opens) or can no longer afford it. Like the log nudge it waits while a roll is in flight and during the first-time tutorial.
	EggGuideController.Wanted() -> true while an egg nudge is (or is about to be) up: the log nudge (LogAffordController) waits for it.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.PetsConfig)
local Emphasis = require(ReplicatedStorage.Shared.Modules.Emphasis)
local GuidePointer = require(ReplicatedStorage.Shared.Modules.GuidePointer)
local Worlds = require(ReplicatedStorage.Shared.Modules.Worlds)
local ClientState = require(script.Parent.Parent.State.ClientState)
local HatchController = require(script.Parent.HatchController)
local NotifyController = require(script.Parent.NotifyController)

local EggGuideController = {}

local G = Config.Guide
local player = Players.LocalPlayer
local pointer
local told: { [string]: boolean } = {} -- eggs already announced this session
local guiding: { [string]: boolean } = {} -- announced and not reached yet

local function wins(): number
	return player:GetAttribute("Wins") or 0
end

-- Only eggs the player has never bought (PetService saves EggsHatched).
local function hatchedBefore(id: string): boolean
	return (ClientState.Data.EggsHatched or {})[id] == true
end

local function calm(): boolean
	return player:GetAttribute("Loaded") == true and not player:GetAttribute("Running") and not player:GetAttribute("Fallen")
		and player:GetAttribute("Tutorial") == nil
end

local function check()
	if not calm() then
		return
	end
	for _, egg in Config.Eggs do
		local here = not egg.Robux and not egg.Shop and (egg.World or 1) == Worlds.Of(player) -- Wins eggs in this world only
		if here and not told[egg.Id] and not hatchedBefore(egg.Id) and wins() >= egg.Price then
			told[egg.Id], guiding[egg.Id] = true, true
			NotifyController.Toast(G.Text:format(Emphasis.Em(egg.Name, G.Kind)), G.Kind)
		end
	end
end

local function standOf(id: string): Model?
	local hatchery = workspace:FindFirstChild("Hatchery")
	local stands = hatchery and hatchery:FindFirstChild("Stands")
	return stands and stands:FindFirstChild(id)
end

-- The pad of the most expensive egg still being guided and affordable; eggs the player has walked up to stop being guided.
local function target(): BasePart?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local pick
	for _, egg in Config.Eggs do
		local stand = guiding[egg.Id] and not hatchedBefore(egg.Id) and standOf(egg.Id)
		local pad, anchor = stand and stand:FindFirstChild("Pad"), stand and stand:FindFirstChild("Anchor")
		if pad and anchor and root then
			local flat = Vector3.new(root.Position.X - anchor.Position.X, 0, root.Position.Z - anchor.Position.Z).Magnitude
			if flat <= Config.World.Billboard.Show then
				guiding[egg.Id] = nil -- they found it
			elseif wins() >= egg.Price and (not pick or egg.Price > pick.Price) then
				pick = { Price = egg.Price, Pad = pad }
			end
		end
	end
	return pick and pick.Pad
end

local function update()
	local busy = player:GetAttribute("Running") or ClientState.MenuOpen() ~= nil or HatchController.Busy()
	local pad = next(guiding) and target() or nil
	pointer:Update(not busy and pad or nil, G.Marker)
end

function EggGuideController.Wanted(): boolean
	for _, egg in Config.Eggs do
		local here = not egg.Robux and not egg.Shop and (egg.World or 1) == Worlds.Of(player)
		if here and not hatchedBefore(egg.Id) and wins() >= egg.Price and (not told[egg.Id] or guiding[egg.Id]) then
			return true
		end
	end
	return false
end

function EggGuideController.Start()
	pointer = GuidePointer.new("EggGuide")
	for _, attribute in { "Wins", "Running", "Fallen", "Tutorial", "Loaded" } do
		player:GetAttributeChangedSignal(attribute):Connect(check)
	end
	ClientState.On("Data", check)
	RunService.RenderStepped:Connect(update)
	check()
end

return EggGuideController
