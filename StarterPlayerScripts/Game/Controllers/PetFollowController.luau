--[[
	PetFollowController — equipped pets follow their owner (every player's, client-side only: a pet is a local clone of the
	Blender model). The server publishes each player's equipped pet ids as the attribute "PetsEquipped" ("PebblePup,FrostFox").
	Pets trail the character in a loose fan and shrink away (and come back) while the owner's log is rolling ("Running"), so
	they never sit on the hill. Walkers hop, waddle and trot; flyers (PetsConfig.Pets[].Fly) hover higher and bob; every
	pet's ears / tail / legs / wings move through PetRig; Rare and up carry a particle aura (AuraConfig.Pets). Numbers: PetsConfig.Follow.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AssetLibrary = require(ReplicatedStorage.Shared.Modules.AssetLibrary)
local Aura = require(ReplicatedStorage.Shared.Modules.Aura)
local Config = require(ReplicatedStorage.Shared.Config.PetsConfig)
local PetMath = require(ReplicatedStorage.Shared.Modules.PetMath)
local PetRig = require(ReplicatedStorage.Shared.Modules.PetRig)

local PetFollowController = {}

local F = Config.Follow
local followers: { [Player]: { Ids: string, Pets: { any } } } = {}
local folder: Folder

local function clear(player: Player)
	local entry = followers[player]
	if entry then
		for _, pet in entry.Pets do
			pet.Model:Destroy()
			if pet.Aura then
				pet.Aura:Destroy()
			end
		end
		followers[player] = nil
	end
end

-- (Re)builds a player's pets when their equipped list changes.
local function sync(player: Player)
	local ids = player:GetAttribute("PetsEquipped") or ""
	local entry = followers[player]
	if entry and entry.Ids == ids then
		return
	end
	clear(player)
	entry = { Ids = ids, Pets = {} }
	followers[player] = entry
	for id in string.gmatch(ids, "[^,]+") do
		-- Wait, not Get: on join the saved pets are equipped before the server has built the pet templates
		task.spawn(function()
			local model = AssetLibrary.Wait(id)
			if followers[player] ~= entry then -- the equipped list changed while waiting
				model:Destroy()
				return
			end
			local ext = model:GetExtentsSize() -- largest side, so wide pets (bee, turtle) don't outsize tall ones
			local scale = F.Size / math.max(ext.X, ext.Y, ext.Z)
			model:ScaleTo(model:GetScale() * scale)
			model.Parent = folder
			table.insert(entry.Pets, { Model = model, Rig = PetRig.new(model), Fly = PetMath.Pet(id).Fly == true, Pos = Vector3.zero,
				Facing = Vector3.zAxis, Grow = 0, Shown = -1, Move = 0, Base = model:GetScale(), Seed = #entry.Pets * 1.7, Fresh = true,
				Aura = Aura.Pet(id, folder), Extents = model:GetExtentsSize() * Aura.Config.PetFit })
		end)
	end
end

local function slotOffset(index: number, count: number): Vector3
	local row = (index - 1) // 2
	local side = if index % 2 == 1 then -1 else 1
	local x = if count == 1 then 0 else side * F.Side * (if row == 0 and count == 2 then 0.7 else 1)
	return Vector3.new(x, 0, F.Behind + row * F.Spacing)
end

-- Height and tilt for this frame: flyers hover and bob, walkers hop and waddle while moving.
local function lift(pet, now: number): (number, CFrame)
	if pet.Fly then
		return F.Fly.Height + math.sin(now * F.Fly.Bob[2] + pet.Seed) * F.Fly.Bob[1], CFrame.Angles(math.rad(F.Fly.Lean) * pet.Move, 0, 0)
	end
	local hop = math.abs(math.sin(now * F.Bob[2] + pet.Seed)) * F.Bob[1] * pet.Move
	local roll = math.sin(now * F.Waddle.Speed + pet.Seed) * math.rad(F.Waddle.Amp) * pet.Move
	return hop, CFrame.Angles(0, 0, roll)
end

local function step(dt: number)
	local now = os.clock()
	local camera = workspace.CurrentCamera
	local blend = 1 - math.exp(-F.Lerp * dt)
	for player, entry in followers do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local show = root ~= nil and humanoid ~= nil and not player:GetAttribute("Running") and (root.Position - camera.CFrame.Position).Magnitude < 260
		for index, pet in entry.Pets do
			pet.Grow = math.clamp(pet.Grow + (if show then 1 else -1) * dt / F.Pop, 0, 1)
			if root and humanoid then
				local floor = root.Position.Y - humanoid.HipHeight - root.Size.Y / 2
				local goal = (root.CFrame * CFrame.new(slotOffset(index, #entry.Pets))).Position
				goal = Vector3.new(goal.X, floor, goal.Z)
				if pet.Fresh or (goal - pet.Pos).Magnitude > 60 then -- spawned, or the owner teleported: snap
					pet.Pos, pet.Fresh = goal, false
				end
				local before = pet.Pos
				pet.Pos = before:Lerp(goal, blend)
				local move = Vector3.new(pet.Pos.X - before.X, 0, pet.Pos.Z - before.Z)
				pet.Move += (math.clamp(move.Magnitude / (dt * F.WalkSpeed), 0, 1) - pet.Move) * blend
				local aim = if move.Magnitude > 0.02 then move.Unit else (root.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
				pet.Facing = pet.Facing:Lerp(aim, blend).Unit
				local scale = pet.Base * math.max(pet.Grow, 0.001)
				if pet.Shown ~= pet.Grow then -- only resize while popping in / out
					pet.Model:ScaleTo(scale)
					pet.Shown = pet.Grow
				end
				local height, tilt = lift(pet, now)
				local at = pet.Pos + Vector3.new(0, height * pet.Grow, 0)
				pet.Rig:Pose(CFrame.lookAt(at, at + pet.Facing) * tilt, scale, now + pet.Seed, pet.Move)
				if pet.Aura then
					pet.Aura:Show(pet.Grow > 0.5)
					pet.Aura:Place(pet.Model:GetBoundingBox(), pet.Extents * pet.Grow)
				end
			end
		end
	end
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("PetsEquipped"):Connect(function()
		sync(player)
	end)
	sync(player)
end

function PetFollowController.Start()
	folder = Instance.new("Folder")
	folder.Name = "PetFollowers"
	folder.Parent = workspace
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)
	RunService.RenderStepped:Connect(step)
end

return PetFollowController
