--[[
	TrainingService — the treadmill row near spawn. Using a belt's ProximityPrompt (TrainingController, it sends TrainBegin) starts
	a session: the player attribute "Training" = the treadmill id. While it is set the server pays Speed every
	Curves.TrainTick(data.TotalLevels, data.Rebirths) seconds, per player (faster for brand-new players until their first rebirth; Curves.TrainGain: Rate x belt Mult x the equipped log's Mult = the log pad's Speed / hit on the x1 belt, numbers in BalanceConfig.Training / EconomyConfig) and replies
	TrainResult for the "+N" popup. The session ends on TrainEnd, leaving the belt, rolling, or dying/leaving.
	Treadmills: Workspace.Training.<station Id> = a Model built in Studio (tools/lobby_layout.lua) per Curves.Treadmills station
	(a Robux zone station needs its ShopConfig Pass)
	(just the Belt collider; at start this service lays the Blender "Conveyor" over it, tinted with the treadmill's colour).
	The client plays the run animation.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local AssetLibrary = require(ReplicatedStorage.Shared.Modules.AssetLibrary)
local Curves = require(ReplicatedStorage.Shared.Modules.Curves)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Progress = require(script.Parent.Parent.Modules.Progress)
local DataService = require(script.Parent.DataService)
local NotifyService = require(script.Parent.NotifyService)

local TrainingService = {}

local T = Config.Training
local STEP = 0.05 -- how often the payout clock is checked
local nextPay: { [Player]: number } = {} -- when each training player is paid next (os.clock)

local function belt(def): BasePart?
	local model = workspace:FindFirstChild("Training") and workspace.Training:FindFirstChild(def.Id)
	return model and model:FindFirstChild("Belt")
end

function TrainingService.Stop(player: Player)
	player:SetAttribute("Training", nil)
	nextPay[player] = nil
end

local function onBelt(character: Model?, def): boolean
	local root, deck = character and character:FindFirstChild("HumanoidRootPart"), belt(def)
	if not root or not deck then
		return false
	end
	local rel = deck.CFrame:PointToObjectSpace(root.Position)
	return math.abs(rel.X) <= deck.Size.X / 2 + 2 and math.abs(rel.Z) <= deck.Size.Z / 2 + 2 and rel.Y < T.Reach + 4
end

-- Beside the belt (within the prompt's reach of its edge): where the Run prompt can be used from.
local function nearBelt(character: Model?, def): boolean
	local root, deck = character and character:FindFirstChild("HumanoidRootPart"), belt(def)
	if not root or not deck then
		return false
	end
	local rel, slack = deck.CFrame:PointToObjectSpace(root.Position), T.Prompt.Distance + 3
	return math.abs(rel.X) <= deck.Size.X / 2 + slack and math.abs(rel.Z) <= deck.Size.Z / 2 + slack and rel.Y < T.Reach + 4
end

local function begin(player: Player, payload)
	local def = typeof(payload) == "table" and Curves.TreadmillById[payload.Station]
	local data = DataService.Get(player)
	if not def or not data or player:GetAttribute("Running") or player:GetAttribute("Training") == def.Id then
		return
	end
	if not nearBelt(player.Character, def) then
		return
	end
	if def.Pass and player:GetAttribute(ShopConfig.Passes[def.Pass].Attribute) ~= true then
		return -- a Robux zone (the client prompts the pass)
	end
	if data.Rebirths < def.Rebirths then
		NotifyService.Send(player, `Need {def.Rebirths} Rebirths to use this treadmill!`, "Warning")
		return
	end
	player:SetAttribute("Training", def.Id)
	nextPay[player] = os.clock() + Curves.TrainTick(data.TotalLevels, data.Rebirths)
end

local function payout()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local def, data = Curves.TreadmillById[player:GetAttribute("Training")], DataService.Get(player)
		if def and data and not nextPay[player] then
			nextPay[player] = now + Curves.TrainTick(data.TotalLevels, data.Rebirths) -- training set some other way: start its clock
		elseif def and data and now >= nextPay[player] then
			nextPay[player] = math.max(nextPay[player] + Curves.TrainTick(data.TotalLevels, data.Rebirths), now)
			local locked = def.Pass and player:GetAttribute(ShopConfig.Passes[def.Pass].Attribute) ~= true -- a Robux zone whose pass went off (nopasses)
			if player:GetAttribute("Running") or locked or not onBelt(player.Character, def) then
				TrainingService.Stop(player)
			else
				local gain = Curves.TrainGain(def, Curves.LogMult(data.Equipped, data.Logs))
				local levels, gained = Progress.AddSpeed(data, gain, player)
				DataService.Changed(player)
				DataService.Sync(player)
				Net.Get("TrainResult"):Fire(player, { Gain = gained, Speed = data.Speed, Station = def.Id, Level = data.Level, LevelHits = data.LevelHits, Levels = levels })
			end
		end
	end
end

-- The Blender conveyor over each belt: ground centre on the belt's underside, front = the belt's +Z. The Belt collider stays
-- (invisible) as the walkable surface; the model's Main parts (rail caps + chevrons) take the treadmill's colour.
local function dress()
	for _, def in Curves.Treadmills do
		local deck = belt(def)
		local conveyor = AssetLibrary.Wait(def.Model) -- the tier's themed treadmill
		if deck then
			for _, part in conveyor:GetChildren() do
				if part.Name == "Main" then
					part.Color = def.Color
				end
			end
			conveyor.Name = "Conveyor"
			conveyor.Parent = deck.Parent
			conveyor:PivotTo(deck.CFrame * CFrame.new(0, -deck.Size.Y / 2, 0))
			deck.Transparency = 1
		end
	end
end

function TrainingService.Start()
	task.spawn(dress)
	Net.Get("TrainBegin"):Connect(begin)
	Net.Get("TrainEnd"):Connect(TrainingService.Stop)
	task.spawn(function()
		while true do
			task.wait(STEP)
			payout()
		end
	end)
	local function watch(player: Player)
		player.CharacterRemoving:Connect(function()
			TrainingService.Stop(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		nextPay[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return TrainingService
