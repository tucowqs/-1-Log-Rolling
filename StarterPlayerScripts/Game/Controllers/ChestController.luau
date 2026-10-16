--[[
	ChestController — the free group chest in the lobby (ChestConfig): the Blender FreeChest on Workspace.FreeChest, a billboard
	(a big CLAIM + "Join the Group to claim!", or the countdown to the next chest from the attribute ChestReadyAt) and a prompt.
	Claiming when not in the group opens Roblox's join prompt (then claims again); a claim swings the lid open and back.
]]
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.ChestConfig)
local AssetLibrary = require(ReplicatedStorage.Shared.Modules.AssetLibrary)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)
local Ui = require(ReplicatedStorage.Shared.Modules.Ui)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)
local WorldLabel = require(ReplicatedStorage.Shared.Modules.WorldLabel)

local ChestController = {}

local T = Config.Text
local player = Players.LocalPlayer
local chest: Model

local function label(parent: Instance, text: string, kind: string, y: number, h: number): TextLabel
	local item = UiPack.Get("StatText")
	item.Size, item.Position, item.AnchorPoint = UDim2.fromScale(1, h), UDim2.fromScale(0.5, y), Vector2.new(0.5, 0.5)
	for _, layer in { item, item:FindFirstChild("Color") } do
		layer.TextXAlignment = Enum.TextXAlignment.Center
	end
	item.Parent = parent
	UiPack.Text(item, text)
	UiPack.TextGradient(item, kind)
	return item
end

-- Swings every Lid* part about the hinge (model space) open and back.
local function openLid()
	local base = chest:GetPivot()
	local lids = {}
	for _, part in chest:GetChildren() do
		if part:IsA("BasePart") and part.Name:match("^Lid") then
			lids[part] = base:ToObjectSpace(part.CFrame)
		end
	end
	local L = Config.Lid
	local function set(angle: number)
		for part, rel in lids do
			local hinge = CFrame.new(L.Hinge)
			part.CFrame = base * hinge * CFrame.Angles(math.rad(-angle), 0, 0) * hinge:Inverse() * rel
		end
	end
	for _, step in { { 0, L.Open }, { L.Open, 0 } } do
		local t = 0
		while t < L.Time do
			t += task.wait()
			set(step[1] + (step[2] - step[1]) * math.clamp(t / L.Time, 0, 1))
		end
		task.wait(0.6)
	end
end

local function claim()
	if Config.GroupId ~= 0 and not player:IsInGroup(Config.GroupId) then
		pcall(GroupService.PromptJoinAsync, GroupService, Config.GroupId)
		if not player:IsInGroup(Config.GroupId) then
			return
		end
	end
	if (player:GetAttribute("ChestReadyAt") or 0) <= workspace:GetServerTimeNow() then
		task.spawn(openLid)
	end
	Net.Get("ChestClaim"):Fire({})
end

function ChestController.Start()
	local anchor = workspace:WaitForChild(Config.Anchor)
	chest = AssetLibrary.Wait("FreeChest")
	chest:PivotTo(anchor.CFrame)
	chest.Parent = workspace
	local gui = Ui.Make("BillboardGui", { Name = "FreeChest", Adornee = anchor, LightInfluence = 0, MaxDistance = 300, ResetOnSpawn = false,
		StudsOffsetWorldSpace = Vector3.new(0, Config.Billboard.Lift, 0), ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	WorldLabel.Apply(gui, Config.Billboard)
	local title = label(gui, T.Claim, "Pink", 0.32, 0.62)
	local hint = label(gui, T.Hint, "Gold", 0.82, 0.3)
	gui.Parent = player:WaitForChild("PlayerGui")
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText, prompt.ObjectText, prompt.MaxActivationDistance, prompt.RequiresLineOfSight, prompt.HoldDuration = T.Claim, "Free Chest",
		Config.Prompt.Distance, false, 0
	prompt.Triggered:Connect(claim)
	prompt.Parent = anchor
	task.spawn(function()
		while true do
			local left = (player:GetAttribute("ChestReadyAt") or 0) - workspace:GetServerTimeNow()
			UiPack.Text(title, if left > 0 then NumberFormat.Clock(left) else T.Claim)
			UiPack.Text(hint, if left > 0 then T.Wait:format("") else T.Hint)
			task.wait(1)
		end
	end)
end

return ChestController
