--[[
	EggController — the two egg podiums behind the spawn (Workspace.Hatchery.Stands.<EggId>, built in Studio by tools/build_eggs.lua).
	Each client puts the floating, turning Blender egg over its podium and keeps one odds billboard per egg (PackViews/EggView):
	it stands in front of the egg and tweens up / down as the player walks up to / away from the podium (Billboard.Show / Far); a separate always-on sign over the egg shows its rarity + price.
	E = Hatch 1, R = Hatch xN (PetMath.Best: the most eggs the Wins cover, else suggests the next "+N Eggs" pass), T = Auto (hatches the Multi count again and
	again, PetsConfig.Auto.Every after each reveal, until T again, walking away or running out of Wins). A Robux egg's E prompts
	its ShopConfig product instead. Presses only ask the server (PetService re-checks room and Wins, then HatchController plays
	the animation). Shop-only eggs (PetsConfig Eggs[].Shop) have no podium. Numbers: PetsConfig.World.Egg / Billboard.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local AssetLibrary = require(ReplicatedStorage.Shared.Modules.AssetLibrary)
local Config = require(ReplicatedStorage.Shared.Config.PetsConfig)
local EggView = require(ReplicatedStorage.Shared.Modules.PackViews.EggView)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local ClientState = require(script.Parent.Parent.State.ClientState)
local HatchController = require(script.Parent.HatchController)
local NotifyController = require(script.Parent.NotifyController)
local PetMath = require(ReplicatedStorage.Shared.Modules.PetMath)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local ShopController = require(script.Parent.ShopController)

local EggController = {}

local W = Config.World
local player = Players.LocalPlayer
local stands = {} -- egg id -> { Def, Anchor, Egg, View, Phase }
local near: string? = nil
local auto: string? = nil -- the egg auto-hatching

local function request(id: string, count: number)
	local stand = stands[id]
	if not (stand and stand.View.Open and not HatchController.Busy()) then
		return
	end
	if stand.Def.Robux then
		ShopController.Buy(stand.Def.Robux)
	else
		Net.Get("PetHatch"):Fire({ Egg = id, Count = count })
	end
end

-- R / the Hatch xN button: hatch the most eggs the Wins cover; if that is more than the owned passes allow and the Wins
-- cover the next "+N Eggs" pass's amount, suggest that pass instead (PetMath.Best).
local function hatchMax(id: string)
	local stand = stands[id]
	if not (stand and stand.View.Open and not HatchController.Busy()) or stand.Def.Robux then
		return
	end
	local count, _, pass = PetMath.Best(player, stand.Def.Price)
	if pass then
		local eggs = ShopConfig.Passes[pass].Eggs
		NotifyController.Toast(Config.Text.NeedPass:format(eggs, eggs), "Info")
		ShopController.Buy("Pass" .. pass)
	else
		request(id, count)
	end
end

local function setAuto(id: string?)
	if auto and stands[auto] then
		stands[auto].View:SetAuto(false)
	end
	auto = id
	HatchController.SetAuto(id ~= nil)
	if id then
		stands[id].View:SetAuto(true)
		NotifyController.Toast(Config.Text.AutoOn, "Info")
	end
end

local function toggleAuto(id: string)
	setAuto(if auto == id then nil else id)
end

-- Auto: hatch the Multi count (or 1 if that's too dear) whenever no reveal is playing; stops when the player can't pay or leaves.
local function autoLoop()
	while true do
		task.wait(Config.Auto.Every)
		local stand = auto and stands[auto]
		if stand and not HatchController.Busy() then
			local wins, multi = player:GetAttribute("Wins") or 0, PetMath.Multi(player)
			local count = if wins >= stand.Def.Price * multi then multi elseif wins >= stand.Def.Price then 1 else 0
			if count == 0 or near ~= auto then
				setAuto(nil)
			else
				request(auto, count)
				task.wait(0.5) -- the server answers, then HatchController is busy
			end
		end
	end
end

local function refreshMulti()
	for _, stand in stands do
		local _, want = PetMath.Best(player, stand.Def.Price)
		stand.View:SetMulti(want)
	end
end

local function build(def, model: Model)
	local anchor = model:WaitForChild("Anchor") :: BasePart -- the egg's centre height over the podium
	local egg = AssetLibrary.Wait(def.Model)
	egg:ScaleTo(egg:GetScale() * W.Egg.Size / egg:GetExtentsSize().Y)
	local fx = workspace:FindFirstChild("HatcheryFx") or Instance.new("Folder")
	fx.Name, fx.Parent = "HatcheryFx", workspace
	egg.Parent = fx
	local pad = AssetLibrary.Wait(W.Podium.Model) -- the small pad under the egg, sitting on the plaza floor
	local top = anchor.Position - Vector3.new(0, W.Egg.Gap + W.Egg.Size / 2 + W.Podium.Height, 0)
	pad:PivotTo(CFrame.new(top))
	pad.Parent = fx
	local view = EggView.new({ Egg = def, Adornee = anchor, OnHatch = function(count)
		request(def.Id, count)
	end, OnMulti = function()
		hatchMax(def.Id)
	end, OnAuto = function()
		toggleAuto(def.Id)
	end })
	stands[def.Id] = { Def = def, Anchor = anchor, Egg = egg, View = view, Phase = #egg.Name }
	refreshMulti()
end

local function animate()
	local now = os.clock()
	for _, stand in stands do
		local bob = math.sin(now * W.Egg.BobSpeed + stand.Phase) * W.Egg.Bob
		local base = stand.Anchor.Position - Vector3.new(0, W.Egg.Size / 2 - bob, 0)
		stand.Egg:PivotTo(CFrame.new(base) * CFrame.Angles(0, now * W.Egg.Turn + stand.Phase, 0))
	end
end

-- Flat distance from the player to a podium (nil while rolling or watching a hatch).
local function distanceTo(stand): number?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or player:GetAttribute("Running") or HatchController.Busy() or ClientState.MenuOpen() ~= nil then
		return nil
	end
	return Vector3.new(root.Position.X - stand.Anchor.Position.X, 0, root.Position.Z - stand.Anchor.Position.Z).Magnitude
end

-- Opens each odds panel (a tween) once the player is within Show of its podium and closes it past Far (a gap, so it
-- doesn't flicker at the edge); "near" (the hatch keys) is the closest podium inside Show.
local function refresh()
	local B = W.Billboard
	local best, bestDistance = nil, B.Show
	for id, stand in stands do
		local distance = distanceTo(stand)
		if distance and distance < B.Show then
			stand.View:SetOpen(true)
		elseif not distance or distance > B.Far then
			stand.View:SetOpen(false)
		end
		if distance and distance < bestDistance then
			best, bestDistance = id, distance
		end
	end
	near = best
end

function EggController.Start()
	local folder = workspace:WaitForChild("Hatchery"):WaitForChild("Stands")
	for _, def in Config.Eggs do
		if not def.Shop then
			task.spawn(build, def, folder:WaitForChild(def.Id))
		end
	end
	for _, key in Config.MultiPasses do
		player:GetAttributeChangedSignal(ShopConfig.Passes[key].Attribute):Connect(refreshMulti)
	end
	player:GetAttributeChangedSignal("Wins"):Connect(refreshMulti)
	task.spawn(autoLoop)
	RunService.RenderStepped:Connect(animate)
	RunService.RenderStepped:Connect(refresh)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not near then
			return
		end
		local K = Config.Text.Keys
		if input.KeyCode == Enum.KeyCode[K[1]] then
			request(near, 1)
		elseif input.KeyCode == Enum.KeyCode[K[2]] and not stands[near].Def.Robux then
			hatchMax(near)
		elseif input.KeyCode == Enum.KeyCode[K[3]] and not stands[near].Def.Robux then
			toggleAuto(near)
		end
	end)
end

return EggController
