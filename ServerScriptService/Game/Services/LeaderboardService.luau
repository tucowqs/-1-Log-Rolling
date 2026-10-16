--[[
	LeaderboardService — the two lobby leaderboards (LeaderboardConfig). Every Refresh seconds this server writes each
	player's best Rebirths / Speed into that board's OrderedDataStore (a max, so a rebirth's Speed reset never lowers it),
	reads the global top 50, publishes it as the board model's "Entries" attribute (JSON; LeaderboardController fills the
	rows from it) and keeps the #1 player's avatar dancing on the podium (the Blender WinnerPodium, a part-built stand
	until it loads). A failed DataStore call keeps the last list (Studio without API access just shows what it had).
]]
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetLibrary = require(ReplicatedStorage.Shared.Modules.AssetLibrary)
local Config = require(ReplicatedStorage.Shared.Config.LeaderboardConfig)

local LeaderboardService = {}

local stores = {}
local sent: { [Player]: { [string]: number } } = {}
local names: { [number]: string } = {}
local champions: { [string]: number } = {} -- board id -> the userId currently dancing

local function stationOf(def): Model?
	local root = workspace:FindFirstChild("Leaderboards")
	return root and root:FindFirstChild(def.Id)
end

local function submit(player: Player)
	sent[player] = sent[player] or {}
	for _, def in Config.Boards do
		local value = player:GetAttribute(def.Attribute)
		local amount = if type(value) == "number" then math.min(math.floor(value), Config.MaxValue) else 0
		if amount >= 1 and amount > (sent[player][def.Id] or 0) then
			local ok = pcall(stores[def.Id].UpdateAsync, stores[def.Id], tostring(player.UserId), function(old)
				return math.max(old or 0, amount)
			end)
			if ok then
				sent[player][def.Id] = amount
			end
		end
	end
end

local function nameOf(userId: number): string
	if not names[userId] then
		local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		names[userId] = if ok then name else "Player"
	end
	return names[userId]
end

-- Swaps the dancing avatar on a station for userId's (or clears it).
local function crown(def, userId: number?, name: string?)
	local station = stationOf(def)
	if not station or champions[def.Id] == userId then
		return
	end
	champions[def.Id] = userId
	local old = station:FindFirstChild("Champion")
	if old then
		old:Destroy()
	end
	local spot = station.Stand.Spot
	local sign = spot.No1
	sign.Enabled = userId ~= nil
	if not userId then
		return
	end
	for _, label in { sign.Title, sign.PlayerName } do
		local text = if label == sign.Title then Config.Billboard.Text else name :: string
		label.Text = text
		label.Color.Text = text
	end
	local ok, description = pcall(Players.GetHumanoidDescriptionFromUserId, Players, userId)
	if not ok or champions[def.Id] ~= userId then
		return
	end
	local rig = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	if champions[def.Id] ~= userId then
		rig:Destroy()
		return
	end
	rig.Name = "Champion"
	rig:ScaleTo(Config.Podium.Scale)
	local humanoid = rig.Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	rig.HumanoidRootPart.Anchored = true
	rig.Parent = station
	rig:PivotTo(CFrame.new(spot.Position) * spot.CFrame.Rotation) -- the spot's look vector faces the viewers, like the rig's front
	local box, size = rig:GetBoundingBox()
	rig:PivotTo(rig:GetPivot() + Vector3.new(0, spot.Position.Y - (box.Position.Y - size.Y / 2), 0)) -- feet on the pad
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local dance = Instance.new("Animation")
	dance.AnimationId = Config.Dances[math.random(#Config.Dances)]
	local track = animator:LoadAnimation(dance)
	track.Looped = true
	track:Play()
end

local function refresh()
	for _, player in Players:GetPlayers() do
		submit(player)
	end
	for _, def in Config.Boards do
		local station = stationOf(def)
		local ok, page = pcall(function()
			return stores[def.Id]:GetSortedAsync(false, Config.Top):GetCurrentPage()
		end)
		if station and ok then
			local entries = {}
			for _, item in page do
				local id = tonumber(item.key)
				if id then
					table.insert(entries, { Id = id, Name = nameOf(id), Value = item.value })
				end
			end
			station:SetAttribute("Entries", HttpService:JSONEncode(entries))
			local first = entries[1]
			crown(def, first and first.Id, first and first.Name)
		end
	end
end

-- The Blender podium replaces the part-built stand once it exists (the stand stays if the meshes can't build).
local function dress()
	for _, def in Config.Boards do
		local station = stationOf(def)
		local stand = station and station:FindFirstChild("Stand")
		local ok, model = pcall(function()
			AssetLibrary.Build(Config.Podium.Model)
			return AssetLibrary.Get(Config.Podium.Model)
		end)
		if stand and ok and model then
			model.Name = "Blender"
			for _, part in model:GetDescendants() do
				if part.Name == "Main" and part:IsA("BasePart") then
					part.Color = def.Tint
				end
			end
			local spot = stand.Spot
			model:PivotTo(CFrame.new(spot.Position - Vector3.new(0, Config.Podium.Top, 0)) * spot.CFrame.Rotation)
			model.Parent = stand
			if stand:FindFirstChild("Fallback") then
				stand.Fallback:Destroy()
			end
		end
	end
end

function LeaderboardService.Start()
	for _, def in Config.Boards do
		stores[def.Id] = DataStoreService:GetOrderedDataStore(def.Store)
	end
	Players.PlayerRemoving:Connect(function(player)
		submit(player)
		sent[player] = nil
	end)
	task.spawn(dress)
	task.spawn(function()
		while true do
			refresh()
			task.wait(Config.Refresh)
		end
	end)
end

return LeaderboardService
