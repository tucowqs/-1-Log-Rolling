--[[
	GiftsController — the free playtime gifts window (menu "Gifts", PackViews/ListView) and the HUD Gifts badge
	(ClientState event "GiftsReady" = how many are claimable now). Each row: what it gives, a countdown, then CLAIM
	(GiftClaim; GiftsService checks the time) and CLAIMED. Ticks once a second.
	  GiftsController.Status(index) -> claimable, seconds left   GiftsController.ClaimButton(index) -> its row's button (window built)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoostConfig = require(ReplicatedStorage.Shared.Config.BoostConfig)
local Config = require(ReplicatedStorage.Shared.Config.GiftsConfig)
local PackConfig = require(ReplicatedStorage.Shared.Config.UiPackConfig)
local ListView = require(ReplicatedStorage.Shared.Modules.PackViews.ListView)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)
local ClientState = require(script.Parent.Parent.State.ClientState)

local GiftsController = {}

local T = Config.Text
local player = Players.LocalPlayer
local view

local function describe(reward): string
	local parts = {}
	if reward.Wins then
		table.insert(parts, "+" .. NumberFormat.Abbreviate(reward.Wins) .. " Wins")
	end
	if reward.Speed then
		table.insert(parts, "+" .. reward.Speed .. " Levels")
	end
	for kind, count in reward.Potions or {} do
		table.insert(parts, count .. "x " .. BoostConfig.Potions[kind].Name)
	end
	return table.concat(parts, " + ")
end

local function state()
	local done = {}
	for index in string.gmatch(player:GetAttribute("GiftsClaimed") or "", "%d+") do
		done[tonumber(index)] = true
	end
	local played = workspace:GetServerTimeNow() - (player:GetAttribute("SessionStart") or workspace:GetServerTimeNow())
	return done, played
end

local function tick()
	local done, played = state()
	local rows, ready = {}, 0
	for index, gift in Config.Gifts do
		local left = gift.Minutes * 60 - played
		local claimable = left <= 0 and not done[index]
		ready += if claimable then 1 else 0
		table.insert(rows, { Key = tostring(index), Title = T.Title:format(index), Text = describe(gift.Reward), Icon = PackConfig.Icons.Gift,
			Button = if done[index] then T.Claimed elseif claimable then T.Ready else T.Wait:format(NumberFormat.Clock(left)),
			Color = if done[index] then "Gray" elseif claimable then "Green" else "Orange",
			OnPress = function()
				if claimable then
					Net.Get("GiftClaim"):Fire({ Index = index })
				end
			end })
	end
	if ClientState.MenuOpen() == Config.Menu then
		view:Set(rows)
	end
	ClientState.Emit("GiftsReady", ready) -- every tick: the HUD badge may connect after the first one
	return rows
end

function GiftsController.Status(index: number): (boolean, number)
	local done, played = state()
	local left = math.max(Config.Gifts[index].Minutes * 60 - played, 0)
	return left <= 0 and not done[index], left
end

function GiftsController.ClaimButton(index: number): GuiObject?
	local entry = view and view.Rows[tostring(index)]
	return entry and entry.Button
end

function GiftsController.Start()
	view = ListView.new(Config.Menu, { Window = { OnClose = ClientState.CloseMenu } })
	ClientState.RegisterMenu(Config.Menu, function()
		view:Set(tick())
		view:Open()
	end, function()
		view:Close()
	end)
	player:GetAttributeChangedSignal("GiftsClaimed"):Connect(tick)
	task.spawn(function()
		while true do
			tick()
			task.wait(1)
		end
	end)
end

return GiftsController
