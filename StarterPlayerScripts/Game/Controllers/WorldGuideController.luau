--[[
	WorldGuideController — prompts the player to unlock the next world. Once their Speed reaches the next locked world's Need
	(WorldsConfig) and they have not unlocked it, a sticky toast + the screen dim (Spotlight, TutorialConfig.Dim) point at, in turn:
	the HUD Worlds button -> that world's LOCKED button in the Worlds window (a click unlocks it, WorldService checks the Speed).
	It ends by itself once the world is unlocked, and waits during the first-time tutorial, a run and while another window is open.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.WorldsConfig)
local TutorialConfig = require(ReplicatedStorage.Shared.Config.TutorialConfig)
local Emphasis = require(ReplicatedStorage.Shared.Modules.Emphasis)
local Spotlight = require(ReplicatedStorage.Shared.Modules.Spotlight)
local Worlds = require(ReplicatedStorage.Shared.Modules.Worlds)
local ClientState = require(script.Parent.Parent.State.ClientState)
local HudController = require(script.Parent.HudController)
local NotifyController = require(script.Parent.NotifyController)
local WorldController = require(script.Parent.WorldController)

local WorldGuideController = {}

local G = { Header = "New world!", Open = "You're fast enough for %s! Open Worlds.", Unlock = "Tap UNLOCK to enter %s!" }
local player = Players.LocalPlayer
local spotlight
local toast, shown = nil, nil

local function say(text: string?)
	if text == shown then
		return
	end
	shown = text
	if not text then
		NotifyController.Dismiss(toast)
		toast = nil
	elseif toast and toast.Parent and toast:FindFirstChild("Text") then
		toast.Text.Text = text
	else
		toast = NotifyController.Toast(text, "Info", true, G.Header)
	end
end

local function visible(gui: GuiObject?): GuiObject?
	return if gui and gui.Visible and gui.AbsoluteSize.X > 0 then gui else nil
end

-- The first world they have not unlocked, when their Speed already reaches its Need.
local function nextWorld(): number?
	local speed = player:GetAttribute("Speed") or 0
	for w = 2, Worlds.Count do
		if not Worlds.Unlocked(player, w) then
			return if speed >= Worlds.Get(w).Need then w else nil
		end
	end
	return nil
end

local function update()
	local w = nextWorld()
	local menu = ClientState.MenuOpen()
	local calm = w and player:GetAttribute("Loaded") and player:GetAttribute("Tutorial") == nil and not player:GetAttribute("Running")
		and (menu == nil or menu == Config.Menu)
	if not calm then
		say(nil)
		spotlight:Set(nil)
		return
	end
	local name = Emphasis.Em(Worlds.Get(w).Name, "Success")
	if menu ~= Config.Menu then
		say(G.Open:format(name))
		spotlight:Set(visible(HudController.Button("Worlds")))
		return
	end
	say(G.Unlock:format(name))
	local button = visible(WorldController.Button(w))
	if button then
		local pane = button:FindFirstAncestorOfClass("ScrollingFrame")
		if pane and (button.AbsolutePosition.Y < pane.AbsolutePosition.Y or button.AbsolutePosition.Y + button.AbsoluteSize.Y > pane.AbsolutePosition.Y + pane.AbsoluteSize.Y) then
			WorldController.Focus(w)
		end
	end
	spotlight:Set(button)
end

function WorldGuideController.Start()
	spotlight = Spotlight.new("WorldGuideDim", TutorialConfig.Dim)
	RunService.RenderStepped:Connect(update)
end

return WorldGuideController
