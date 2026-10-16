--[[
	WallPropsController — the props standing on the ramp walls (2026-10-14, Preston: "make sure each zone has custom props on the
	walls"). tools/world_build.lua leaves invisible "Spot" parts on the wall ledges (attributes World, Zone; each faces the lane);
	this client puts one of that zone's WallProps (WorldsConfig, Worlds.Area(w, zone).WallProps: Blender models built at runtime)
	on every spot of the LOCAL player's world, picked and sized by a seeded random so every client sees the same walls. Changing
	world clears them and dresses the new world's walls. Scale = SCALE range, a random quarter turn of variety (Yaw).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetLibrary = require(ReplicatedStorage.Shared.Modules.AssetLibrary)
local Worlds = require(ReplicatedStorage.Shared.Modules.Worlds)
local ClientState = require(script.Parent.Parent.State.ClientState)

local WallPropsController = {}

local SCALE = { 1.3, 1.9 } -- the wall props are made at human scale; the walls are 10-stud cubes
local YAW = 25 -- degrees of random turn either way
local folder: Folder
local token = 0

local function spotsOf(w: number): { BasePart }
	local root = if w == 1 then workspace:FindFirstChild("RampTheme") else workspace:FindFirstChild("World" .. w) and workspace["World" .. w]:FindFirstChild("RampTheme")
	local list = {}
	for _, item in if root then root:GetDescendants() else {} do
		if item.Name == "Spot" and item:IsA("BasePart") then
			table.insert(list, item)
		end
	end
	table.sort(list, function(a, b)
		return a.Position.Z < b.Position.Z or (a.Position.Z == b.Position.Z and a.Position.X < b.Position.X)
	end)
	return list
end

local function dress(w: number)
	token += 1
	local mine = token
	folder:ClearAllChildren()
	local random = Random.new(9100 + w)
	for _, spot in spotsOf(w) do
		local names = Worlds.Area(w, spot:GetAttribute("Zone")).WallProps
		local name = names[random:NextInteger(1, #names)]
		local scale = random:NextNumber(SCALE[1], SCALE[2])
		local yaw = math.rad(random:NextNumber(-YAW, YAW))
		local model = AssetLibrary.Wait(name)
		if mine ~= token then
			return -- the player changed world meanwhile
		end
		model:ScaleTo(model:GetScale() * scale)
		model:PivotTo(spot.CFrame * CFrame.Angles(0, math.pi + yaw, 0)) -- the spot looks at the lane; a prop's front is its +Z
		model.Parent = folder
	end
end

function WallPropsController.Start()
	folder = Instance.new("Folder")
	folder.Name = "WallProps"
	folder.Parent = workspace
	ClientState.On("World", function(w)
		task.spawn(dress, w)
	end)
	task.spawn(dress, Worlds.Of(Players.LocalPlayer))
end

return WallPropsController
