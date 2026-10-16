--[[
	SettingsMenu — the Settings window (SettingsConfig): the pack's Upgrades window shell (menu "Settings",
	PackViews/UpgradesView) with one pack row per setting: title on the border, icon, a short description and
	one button. Toggles flip a saved ClientState setting (ON green / OFF grey); SkipTutorial shows only while
	the tutorial runs (the "Tutorial" attribute) and fires "SkipTutorial". The Settings topbar icon (TopbarController) opens it.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.SettingsConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local UpgradesView = require(ReplicatedStorage.Shared.Modules.PackViews.UpgradesView)
local ClientState = require(script.Parent.Parent.State.ClientState)

local SettingsMenu = {}

local player = Players.LocalPlayer
local view = nil
local shown = {} -- key -> the button text last drawn (a change pops the row)

local function press(def)
	if def.Kind == "Toggle" then
		ClientState.SetSetting(def.Key, not ClientState.Settings[def.Key])
	elseif def.Kind == "SkipTutorial" then
		Net.Get("SkipTutorial"):Fire({})
	end
end

-- The button's text and palette for a setting's current state.
local function look(def): (string, string)
	local B = Config.Buttons
	if def.Kind == "Toggle" then
		local on = ClientState.Settings[def.Key] == true
		if def.Inverted then
			on = not on
		end
		return on and "ON" or "OFF", on and B.On or B.Off
	end
	return "SKIP", B.Skip
end

local function refresh()
	for _, def in Config.Rows do
		local text, color = look(def)
		view:SetRow(def.Key, { Before = def.Desc or "", Button = text, Color = color })
		if shown[def.Key] and shown[def.Key] ~= text then
			view:Pop(def.Key)
		end
		shown[def.Key] = text
		if def.Kind == "SkipTutorial" then
			view:SetVisible(def.Key, player:GetAttribute("Tutorial") ~= nil)
		end
	end
end

function SettingsMenu.Start()
	local rows = {}
	for _, def in Config.Rows do
		table.insert(rows, { Key = def.Key, Title = def.Title, Icon = def.Icon or "", OnPress = function()
			press(def)
		end })
	end
	view = UpgradesView.new(Config.Menu, { Window = { OnClose = ClientState.CloseMenu }, Rows = rows })
	ClientState.RegisterMenu(Config.Menu, function()
		refresh()
		view:Open()
	end, function()
		view:Close()
	end)
	ClientState.On("Settings", refresh)
	player:GetAttributeChangedSignal("Tutorial"):Connect(refresh)
	refresh()
end

return SettingsMenu
