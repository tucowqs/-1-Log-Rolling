--[[
	TutorialFlowService — decides when each TutorialConfig step is done (TutorialService only saves and sends them):
	  Train / TrainMore   (steps with GoalAttribute "Level") their Level reached the "TutorialGoal" attribute set when the step
	         started: the step's Goal, or one above their Level then if that is higher, so it is never done before it shows
	  Edge   the player stands in Workspace.RollZone (the throw pad)
	  Roll   a roll started (the "Running" attribute)
	  Steer  the roll ended and the player is back at the top (Running and Fallen are both clear again)
	  Buy    they own the log picked when the step started (TutorialConfig.BuyLog, else the cheapest they didn't own;
	         "TutorialLog" attribute for the client)
	  Gifts  they claimed the step's Gift (GiftsService's "GiftsClaimed" attribute, a comma list of indexes)
	Polled a few times a second: nothing here is time critical.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.TutorialConfig)
local DataService = require(script.Parent.DataService)
local NotifyService = require(script.Parent.NotifyService)
local TutorialService = require(script.Parent.TutorialService)

local TutorialFlowService = {}

local POLL = 0.2
local fell: { [Player]: boolean } = {} -- Steer: the roll ended (Fallen was seen), so the next clear Fallen means "back at the top"

local function inZone(player: Player): boolean
	local zone, root = workspace:FindFirstChild("RollZone"), player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not zone or not root then
		return false
	end
	local at = zone.CFrame:PointToObjectSpace(root.Position)
	return math.abs(at.X) <= zone.Size.X / 2 and math.abs(at.Z) <= zone.Size.Z / 2 and math.abs(at.Y) <= Config.ZoneHeight
end

local rules = {
	Edge = inZone,
	Roll = function(player)
		return player:GetAttribute("Running") == true
	end,
	Steer = function(player)
		if player:GetAttribute("Fallen") then
			fell[player] = true
		end
		return fell[player] == true and not player:GetAttribute("Running") and not player:GetAttribute("Fallen")
	end,
	Buy = function(player)
		local data, id = DataService.Get(player), player:GetAttribute("TutorialLog")
		return data ~= nil and (id == nil or data.Logs[id] == true)
	end,
	Gifts = function(player)
		local want = tostring(Config.Steps[#Config.Steps].Gift or 1)
		for index in string.gmatch(player:GetAttribute("GiftsClaimed") or "", "%d+") do
			if index == want then
				return true
			end
		end
		return false
	end,
}

local function trained(player)
	local goal = player:GetAttribute("TutorialGoal")
	return goal ~= nil and (player:GetAttribute("Level") or 1) >= goal
end
rules.Train, rules.TrainMore = trained, trained

local function stepOf(id: string)
	for _, step in Config.Steps do
		if step.Id == id then
			return step
		end
	end
	return nil
end

local function poll()
	for _, player in Players:GetPlayers() do
		local id = TutorialService.Current(player)
		if id ~= "Steer" then
			fell[player] = nil
		end
		local rule = id and rules[id]
		if rule and rule(player) then
			TutorialService.Advance(player, id)
			if id == Config.Steps[#Config.Steps].Id then -- the last step ends the tutorial
				NotifyService.Send(player, "Tutorial complete!", "Success")
			end
		end
	end
end

function TutorialFlowService.Start()
	TutorialService.OnStepStarted(function(player, id)
		local step = stepOf(id)
		if step and step.GoalAttribute == "Level" then
			local data = DataService.Get(player)
			player:SetAttribute("TutorialGoal", math.max(step.Goal or 0, (data and data.Level or 1) + 1))
		elseif id == "Buy" then
			local data = DataService.Get(player)
			local log = data and (if data.Logs[Config.BuyLog] then Config.CheapestUnowned(data.Logs) else Config.BuyLog)
			player:SetAttribute("TutorialLog", log)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		fell[player] = nil
	end)
	task.spawn(function() -- (Start must return, or the loader reports it as HANGING)
		while true do
			task.wait(POLL)
			poll()
		end
	end)
end

return TutorialFlowService
