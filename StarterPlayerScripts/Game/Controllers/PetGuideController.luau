--[[
	PetGuideController — the first-pet guide. While the save's PetGuided is false (PetService: a new player who has never
	equipped a pet) and they own a pet, a sticky toast (PetsConfig.FirstPet) and the screen dim (Spotlight, TutorialConfig.Dim)
	point at, in turn: the HUD Pets button -> that pet's tile in the Pets window -> its EQUIP button. Equipping sets PetGuided
	and it ends for good. It waits during the first-time tutorial, a roll, a hatch and while another window is open.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.PetsConfig)
local TutorialConfig = require(ReplicatedStorage.Shared.Config.TutorialConfig)
local Emphasis = require(ReplicatedStorage.Shared.Modules.Emphasis)
local PetMath = require(ReplicatedStorage.Shared.Modules.PetMath)
local Spotlight = require(ReplicatedStorage.Shared.Modules.Spotlight)
local ClientState = require(script.Parent.Parent.State.ClientState)
local HatchController = require(script.Parent.HatchController)
local HudController = require(script.Parent.HudController)
local NotifyController = require(script.Parent.NotifyController)
local PetsController = require(script.Parent.PetsController)

local PetGuideController = {}

local F = Config.FirstPet
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
		toast = NotifyController.Toast(text, "Info", true, F.Header)
	end
end

-- The pet to guide to: the best one they own (the list's first, the one the Pets window shows first).
local function firstPet()
	local list = PetMath.Sorted(ClientState.Data.Pets or {})
	return list[1]
end

local function visible(gui: GuiObject?): GuiObject?
	return if gui and gui.Visible and gui.AbsoluteSize.X > 0 then gui else nil
end

local function update()
	local data = ClientState.Data
	local pet = data.PetGuided == false and firstPet()
	local menu = ClientState.MenuOpen()
	local calm = pet and player:GetAttribute("Loaded") and player:GetAttribute("Tutorial") == nil and not player:GetAttribute("Running")
		and not HatchController.Busy() and (menu == nil or menu == Config.Menu)
	if not calm then
		say(nil)
		spotlight:Set(nil)
		return
	end
	if menu ~= Config.Menu then
		say(F.Open)
		spotlight:Set(visible(HudController.Button("Pets")))
		return
	end
	local view = PetsController.View()
	local tile = view and view.Tiles[pet.Uid]
	if view and view.Picked == pet.Uid and view.Selected == pet.Uid then
		say(F.Equip)
		spotlight:Set(visible(view.Equip))
	else
		say(F.Select:format(Emphasis.Em(pet.Def.Name, "Success")))
		spotlight:Set(visible(tile and tile.Cell))
	end
end

function PetGuideController.Start()
	spotlight = Spotlight.new("PetGuideDim", TutorialConfig.Dim)
	RunService.RenderStepped:Connect(update)
end

return PetGuideController
