--[[
	PetsController — the "My Pets" window (PackViews/PetsView, menu "Pets", opened by the Pets button in the HUD's left column).
	It only draws ClientState.Data.Pets / PetsEquipped and sends the player's asks (PetEquip / PetEquipBest / PetDelete); the
	server (PetService) decides. Numbers and texts: PetsConfig.
	  PetsController.View() -> the PetsView (PetGuideController reads its tiles, Picked and Equip button)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.PetsConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local PetMath = require(ReplicatedStorage.Shared.Modules.PetMath)
local PetsView = require(ReplicatedStorage.Shared.Modules.PackViews.PetsView)
local ClientState = require(script.Parent.Parent.State.ClientState)

local PetsController = {}

local view

local function refresh()
	local owned, equipped = ClientState.Data.Pets or {}, ClientState.Data.PetsEquipped or {}
	local list, stored, worn = PetMath.Sorted(owned), 0, 0
	for _, entry in list do
		stored += 1
		entry.Equipped = equipped[entry.Uid] == true
		worn += if entry.Equipped then 1 else 0
	end
	view:Set({ Pets = list, Stored = stored, Storage = Config.Storage, Equipped = worn, EquipMax = PetMath.EquipMax(Players.LocalPlayer) })
end

function PetsController.View()
	return view
end

function PetsController.Start()
	view = PetsView.new({
		Window = { OnClose = ClientState.CloseMenu },
		OnEquip = function(uid, on)
			Net.Get("PetEquip"):Fire({ Uid = uid, On = on })
		end,
		OnDelete = function(uid)
			Net.Get("PetDelete"):Fire({ Uid = uid })
		end,
		OnEquipBest = function()
			Net.Get("PetEquipBest"):Fire({})
		end,
	})
	ClientState.RegisterMenu(Config.Menu, function()
		refresh()
		view:Open()
	end, function()
		view:Close()
	end)
	ClientState.On("Data", refresh)
	Players.LocalPlayer:GetAttributeChangedSignal("EquipMax"):Connect(refresh)
	refresh()
end

return PetsController
