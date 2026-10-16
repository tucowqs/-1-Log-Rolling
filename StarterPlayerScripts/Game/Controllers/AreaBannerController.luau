--[[
	AreaBannerController — the equipped-log chip (bottom-right HUD row): a spinning 3D preview of the real model on rays and the
	equipped log's Speed per hit. Reads saved data only. (Areas are announced by the Studio-built gates between them, not by UI.)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetLibrary = require(ReplicatedStorage.Shared.Modules.AssetLibrary)
local Curves = require(ReplicatedStorage.Shared.Modules.Curves)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)
local Ui = require(ReplicatedStorage.Shared.Modules.Ui)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)
local ClientState = require(script.Parent.Parent.State.ClientState)
local HudStatusController = require(script.Parent.HudStatusController)

local AreaBannerController = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local logChip: GuiButton

local function refreshChip()
	local id = ClientState.Data.Equipped or player:GetAttribute("Equipped") or "Wood"
	local log = Curves.LogById[id]
	if not log or logChip:GetAttribute("Shown") == id then
		return
	end
	local model = AssetLibrary.Get(id)
	if not model then
		return -- the Blender model isn't built yet; AssetsReady calls back
	end
	logChip:SetAttribute("Shown", id)
	local old = logChip:FindFirstChild("IconArt")
	if old then
		old:Destroy()
	end
	UiPack.Art.Replace(logChip.Icon, { Model = model, Rays = log.Rays, Spin = "Turn" }, "Hud")
	UiPack.SetLabel(logChip, `+{NumberFormat.Abbreviate(Curves.LogMult(id, ClientState.Data.Logs))}`)
end

function AreaBannerController.Start()
	gui = Ui.Screen("AreaBanner", 7)
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	logChip = UiPack.Chip({ Icon = "", Text = "", Gradient = "Green" }, { Parent = HudStatusController.Row(), Name = "Log", Size = UDim2.fromScale(0.3, 1), LayoutOrder = 1 })
	Ui.Make("UIAspectRatioConstraint", { AspectRatio = 1, Parent = logChip })
	UiPack.Art.SetActive("Hud", true)
	ClientState.On("Data", refreshChip)
	ClientState.On("AssetsReady", refreshChip)
	player:GetAttributeChangedSignal("Equipped"):Connect(refreshChip)
end

return AreaBannerController
