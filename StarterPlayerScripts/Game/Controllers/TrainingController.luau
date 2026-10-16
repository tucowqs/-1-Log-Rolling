--[[
	TrainingController — the treadmill row near spawn.
	  start    using a belt's prompt (on or beside it) (that you have the Speed for) sends TrainBegin; the server checks you are on it and sets your
	           "Training" attribute to the treadmill id. After DONE you must step off the belt before it re-arms.
	  running  the character is held in place facing the belt's sign end (toward the spawn path) and plays the standard Roblox run animation (it replicates to
	           everyone). The SERVER pays Speed every tick and replies TrainResult, which
	           flies a "[speed icon] +N" into the Speed label (Run/GainFly). Stepping off ends it (no panel, no DONE); menus can be opened while running.
	  signs    a billboard over each belt, built in Studio by tools/build_lobby.lua (name + Skill needed)
	Numbers: BalanceConfig.Training.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local Curves = require(ReplicatedStorage.Shared.Modules.Curves)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)
local ClientState = require(script.Parent.Parent.State.ClientState)
local ShopController = require(script.Parent.ShopController)
local SoundController = require(script.Parent.SoundController)
local GainFly = require(script.Parent.Parent.Run.GainFly)
local LogRig = require(script.Parent.Parent.Run.LogRig)

local TrainingController = {}

local T = Config.Training
local player = Players.LocalPlayer
local track: AnimationTrack?
local stationId: string? = nil
local prompts: { [string]: ProximityPrompt } = {} -- treadmill id -> its Run / Stop prompt
local savedWalk, savedJump = 16, 50
local startedAt = 0 -- os.clock() when the current session began (the off-belt check waits for the snap to land)


local function belt(id: string): BasePart?
	local folder = workspace:FindFirstChild("Training")
	local model = folder and folder:FindFirstChild(id)
	return model and model:FindFirstChild("Belt")
end

-- The treadmill id whose belt the root part is standing on (or nil).
local function standingOn(root: BasePart): string?
	for _, def in Curves.Treadmills do
		local deck = belt(def.Id)
		if deck then
			local rel = deck.CFrame:PointToObjectSpace(root.Position)
			if math.abs(rel.X) <= deck.Size.X / 2 + 1 and math.abs(rel.Z) <= deck.Size.Z / 2 + 1 and rel.Y > -1 and rel.Y < T.Reach + 2 then
				return def.Id
			end
		end
	end
	return nil
end

local function stop()
	if stationId then
		Net.Get("TrainEnd"):Fire({})
	end
end

local function onTraining(id: string?)
	stationId = id
	startedAt = os.clock()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if id then
		savedWalk, savedJump = humanoid and humanoid.WalkSpeed or 16, humanoid and humanoid.JumpPower or 50
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local deck = belt(id)
		if humanoid then
			humanoid.WalkSpeed, humanoid.JumpPower = 0, 0
			local animation = Instance.new("Animation")
			animation.AnimationId = T.RunAnimation
			track = humanoid:WaitForChild("Animator"):LoadAnimation(animation)
			track.Priority, track.Looped = Enum.AnimationPriority.Action, true
			track:Play(0.15, 1, T.RunAnimSpeed)
		end
		if root and deck then -- centre on the belt (across its width, and pulled in from its ends: the prompt works from beside the belt), on top of the log, facing away from the spawn path
			local rel = deck.CFrame:PointToObjectSpace(root.Position)
			local inset = math.max(deck.Size.Z / 2 - Config.Track.LogRadius * T.LogScale - 1, 0)
			local y = math.clamp(rel.Y, 3, T.Reach - Config.Track.LogRadius * T.LogScale * 2 - 1)
			local at = deck.CFrame:PointToWorldSpace(Vector3.new(0, y + Config.Track.LogRadius * T.LogScale * 2, math.clamp(rel.Z, -inset, inset)))
			root.CFrame = CFrame.lookAt(at, at + deck.CFrame.ZVector * T.RunFacing * 40)
		end
	else
		if humanoid then
			humanoid.WalkSpeed, humanoid.JumpPower = savedWalk, savedJump
		end
		if track then
			track:Stop(0.15)
			track = nil
		end
	end
end

-- The visual log under each runner (every client builds one per training player). Only the local player gets an invisible
-- collider on top of it, so the character stands on the log instead of the belt (replicates to others via the character).
local rigs: { [Player]: any } = {}
local collider: Part? = nil

local function dropLog(who: Player)
	local rig = rigs[who]
	if rig then
		rig.Rig:Destroy()
		rigs[who] = nil
	end
	if who == player and collider then
		collider:Destroy()
		collider = nil
	end
end

local function raiseLog(who: Player, id: string)
	dropLog(who)
	local deck = belt(id)
	if not deck then
		return
	end
	local folder = workspace:FindFirstChild("TrainLogs") or Instance.new("Folder")
	folder.Name, folder.Parent = "TrainLogs", workspace
	local rig = LogRig.new(who:GetAttribute("Equipped") or "Wood", folder)
	rigs[who] = { Rig = rig, Deck = deck, Rot = 0, Who = who }
	if who == player then
		local lift = Config.Track.LogRadius * T.LogScale * 2
		collider = Instance.new("Part")
		collider.Name, collider.Transparency, collider.Anchored, collider.CanQuery, collider.CanTouch = "LogStand", 1, true, false, false
		collider.Size = Vector3.new(deck.Size.X, 1, deck.Size.Z) -- the whole belt, so you stay up wherever you stand
		collider.CFrame = deck.CFrame * CFrame.new(0, deck.Size.Y / 2 + lift - 0.5, 0)
		collider.Parent = folder
	end
end

local function watch(who: Player)
	who:GetAttributeChangedSignal("Training"):Connect(function()
		local id = who:GetAttribute("Training")
		if id then
			raiseLog(who, id)
		else
			dropLog(who)
		end
		if who == player then
			onTraining(id)
		end
	end)
	Players.PlayerRemoving:Connect(function(leaving)
		if leaving == who then
			dropLog(who)
		end
	end)
end

function TrainingController.Start()
	Net.Get("TrainResult"):Connect(function(payload)
		ClientState.Emit("TrainResult", payload) -- the level bar follows Speed too
		SoundController.Play(Config.SoundNames.Lift)
		GainFly.Play("+" .. NumberFormat.Abbreviate(payload.Gain))
	end)
	for _, who in Players:GetPlayers() do
		watch(who)
		if who:GetAttribute("Training") then
			raiseLog(who, who:GetAttribute("Training"))
		end
	end
	RunService.Heartbeat:Connect(function(dt)
		for _, entry in rigs do
			entry.Rot += T.LogSpin * dt
			-- frame = deck top under the runner (clamped to the belt); the log's axis lies across the belt, its top rolling toward the belt's back (+Z)
			local deck, root = entry.Deck, entry.Who.Character and entry.Who.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local half = deck.Size.Z / 2 - Config.Track.LogRadius * T.LogScale
			local z = if root then math.clamp(deck.CFrame:PointToObjectSpace(root.Position).Z, -half, half) else 0
			entry.Rig:Place(deck.CFrame * CFrame.new(0, deck.Size.Y / 2, z), entry.Rot, T.LogScale, 0, 0)
		end
	end)
	Players.PlayerAdded:Connect(watch)
	-- a Run / Stop prompt on every belt; stepping off the belt while running also ends the session (the server checks the same box)
	for _, def in Curves.Treadmills do
		task.spawn(function()
			local deck = belt(def.Id)
			while not deck do
				task.wait(0.5)
				deck = belt(def.Id)
			end
			local prompt = Instance.new("ProximityPrompt")
			prompt.ObjectText, prompt.MaxActivationDistance, prompt.RequiresLineOfSight, prompt.HoldDuration = def.Name, T.Prompt.Distance, false, 0
			prompt.Triggered:Connect(function()
				if stationId == def.Id then
					stop()
				elseif def.Pass and player:GetAttribute(ShopConfig.Passes[def.Pass].Attribute) ~= true then
					ShopController.Buy("Pass" .. def.Pass) -- a Robux zone: buy it first
				elseif not stationId then
					Net.Get("TrainBegin"):Fire({ Station = def.Id })
				end
			end)
			prompt.Parent = deck
			prompts[def.Id] = prompt
		end)
	end
	task.spawn(function()
		while true do
			task.wait(0.2)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if stationId and os.clock() - startedAt > 0.5 and not (root and standingOn(root)) then
				stop()
			end
			local idle = not player:GetAttribute("Running") and ClientState.MenuOpen() == nil
			for id, prompt in prompts do
				prompt.Enabled = idle and (stationId == nil or stationId == id)
				prompt.ActionText = if stationId == id then "Stop" else "Run"
			end
		end
	end)
end

return TrainingController
