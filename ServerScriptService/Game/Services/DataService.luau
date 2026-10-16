--[[
	DataService — ProfileStore sessions: the only owner of saved player data (settings: DataConfig).
	Other services read with Get(player), mutate the table directly, then call Changed (re-mirror
	attributes) and/or Sync (resend the client snapshot).
	Load order: AddUserId, Reconcile, migrations (DataMigrations), OnPrepare callbacks (systems default
	their own fields), mirror attributes, Sync, attribute "Loaded" = true, OnLoaded callbacks.
	A failed load kicks WITHOUT writing, so a bad load never overwrites a real save.
	Double-load guard: the PlayerAdded connection plus the GetPlayers() sweep can load one player twice;
	overlapping StartSessionAsync calls return nil to the EARLIER call, which would kick a healthy player.
	  Get(p) / Changed(p) / Sync(p) / Count(map)
	  AddCash(p, n, quiet?)          quiet = don't re-mirror the attribute now (frequent income ticks)
	  Spend(p, cost) -> bool         never yields, so purchases can't race
	  Remember(p, purchaseId)        records a receipt id (DataConfig.KeepPurchases kept)
	  SaveConfirmed(p, purchaseId)   saves until the id is in the DataStore (receipts: grant exactly once)
	  Reset(p)                       wipe to the Template in place, keep receipts, kick (Cmdr resetdata)
	  AddSnapshot(key) / AddAttribute(key)       systems extend what the client / HUD sees
	  OnPrepare(cb) / OnLoaded(cb) / OnSynced(cb) / OnLeaving(cb)   cb(player, data); OnLoaded also
	                                 fires for players already loaded
]]
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ProfileStore = require(ServerStorage.ServerPackages.ProfileStore)
local Config = require(ReplicatedStorage.Shared.Config.DataConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Migrations = require(script.Parent.Parent.Modules.DataMigrations)

local DataService = {}

local store = ProfileStore.New(Config.StoreName, Config.Template)
local profiles: { [Player]: any } = {}
local loading: { [Player]: boolean } = {}
local sent: { [Player]: { [string]: string } } = {} -- what each client's snapshot holds, per field (JSON)
local callbacks = { Prepare = {}, Loaded = {}, Synced = {}, Leaving = {} }
local snapshot = table.clone(Config.Snapshot)
local attributes = table.clone(Config.Attributes)

local function deepCopy(value)
	if typeof(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = deepCopy(v)
	end
	return out
end

local function mirror(player: Player)
	local data = profiles[player].Data
	for _, key in attributes do
		player:SetAttribute(key, data[key])
	end
end

local function migrate(data)
	local from = data.DataVersion or 1
	for version = from + 1, Config.Version do
		local step = Migrations[version]
		if step then
			step(data)
		end
	end
	data.DataVersion = math.max(from, Config.Version)
end

local function load(player: Player)
	if loading[player] or profiles[player] then
		return
	end
	loading[player] = true
	local profile = store:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	loading[player] = nil
	if not profile then
		if player.Parent == Players then
			player:Kick(Config.LoadFailKick)
		end
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	migrate(profile.Data)
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players then
			player:Kick(Config.SessionEndKick)
		end
	end)
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	for _, callback in callbacks.Prepare do
		callback(player, profile.Data) -- synchronous: defaults land before the first snapshot
	end
	profiles[player] = profile
	mirror(player)
	DataService.Sync(player)
	player:SetAttribute("Loaded", true)
	for _, callback in callbacks.Loaded do
		task.spawn(callback, player, profile.Data)
	end
end

function DataService.Count(map): number
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end

function DataService.Get(player: Player)
	local profile = profiles[player]
	return profile and profile.Data
end

-- Re-mirror attributes after a service changed saved fields directly.
function DataService.Changed(player: Player)
	if profiles[player] then
		mirror(player)
	end
end

function DataService.AddCash(player: Player, amount: number, quiet: boolean?)
	local data = DataService.Get(player)
	if data then
		data[Config.Currency] += amount
		if not quiet then
			player:SetAttribute(Config.Currency, data[Config.Currency])
		end
	end
end

-- Deducts only if affordable. No yields: purchases can't race.
function DataService.Spend(player: Player, cost: number): boolean
	local data = DataService.Get(player)
	if not data or data[Config.Currency] < cost then
		return false
	end
	data[Config.Currency] -= cost
	player:SetAttribute(Config.Currency, data[Config.Currency])
	return true
end

-- Sends the snapshot fields: the whole set the first time (and on "Ready"), afterwards only the fields
-- whose JSON changed since the last send ({ Partial = true, ...changed }; ClientState merges them).
function DataService.Sync(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local last = sent[player]
	local payload, fresh = { Partial = last ~= nil }, {}
	for _, key in snapshot do
		local ok, json = pcall(HttpService.JSONEncode, HttpService, data[key])
		fresh[key] = ok and json or nil -- unencodable: always resent
		if not last or not ok or last[key] ~= json then
			payload[key] = data[key]
		end
	end
	sent[player] = fresh
	Net.Get("Snapshot"):Fire(player, payload)
	for _, callback in callbacks.Synced do
		task.spawn(callback, player, data)
	end
end

function DataService.Remember(player: Player, purchaseId: string)
	local data = DataService.Get(player)
	if data then
		table.insert(data.Purchases, purchaseId)
		while #data.Purchases > Config.KeepPurchases do
			table.remove(data.Purchases, 1)
		end
	end
end

-- Has `purchaseId` reached the DataStore? Saves and waits until it has, so a developer product is only
-- reported granted once its grant is safely stored.
function DataService.SaveConfirmed(player: Player, purchaseId: string): boolean
	local profile = profiles[player]
	local function saved()
		local last = profile and profile.LastSavedData
		return last ~= nil and last.Purchases ~= nil and table.find(last.Purchases, purchaseId) ~= nil
	end
	while profile and profile:IsActive() and not saved() do
		local before = profile.LastSavedData
		profile:Save()
		if profile.LastSavedData == before then
			profile.OnAfterSave:Wait()
		end
	end
	return saved()
end

-- Wipes the live save table in place (ProfileStore saves it when the kicked player leaves); receipt ids
-- stay so a Robux purchase Roblox retries is never granted twice.
function DataService.Reset(player: Player): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	local receipts = data.Purchases
	for key in data do
		data[key] = nil
	end
	for key, value in Config.Template do
		data[key] = deepCopy(value)
	end
	data.Purchases = receipts or {}
	-- Systems default their own fields in OnPrepare; re-run them so nothing ticking before the kick
	-- lands meets a half-empty save.
	for _, callback in callbacks.Prepare do
		callback(player, data)
	end
	player:Kick(Config.ResetKick)
	return true
end

function DataService.AddSnapshot(key: string)
	if not table.find(snapshot, key) then
		table.insert(snapshot, key)
	end
end

function DataService.AddAttribute(key: string)
	if not table.find(attributes, key) then
		table.insert(attributes, key)
	end
end

function DataService.OnPrepare(callback)
	table.insert(callbacks.Prepare, callback)
end

function DataService.OnLoaded(callback)
	table.insert(callbacks.Loaded, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile.Data)
	end
end

function DataService.OnSynced(callback)
	table.insert(callbacks.Synced, callback)
end

function DataService.OnLeaving(callback)
	table.insert(callbacks.Leaving, callback)
end

function DataService.Start()
	Net.Get("Ready"):Connect(function(player)
		sent[player] = nil -- a fresh client: send everything
		DataService.Sync(player)
	end)
	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(function(player)
		for _, callback in callbacks.Leaving do
			pcall(callback, player, DataService.Get(player))
		end
		local profile = profiles[player]
		profiles[player], sent[player], loading[player] = nil, nil, nil
		if profile then
			profile:EndSession()
		end
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
end

return DataService
