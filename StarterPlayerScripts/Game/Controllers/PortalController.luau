--[[
	PortalController — the physical Worlds portal in every lobby (Workspace.Portals.<world number>, anchors placed by hand: WorldsConfig.Portal.Place
	from each world's start line, facing the lobby path). The Blender WorldPortal (stone gate + glowing swirl) stands on the anchor, tinted with that
	world's Art.Rays colour; its GlowSpiral arms turn forever; a sign over the arch says WORLDS. A ProximityPrompt (E / tap, no hold) opens the
	Worlds window (WorldController), where the player picks a world to teleport to (the server checks the Speed). Numbers: WorldsConfig.Portal.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.WorldsConfig)
local AssetLibrary = require(ReplicatedStorage.Shared.Modules.AssetLibrary)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)
local WorldLabel = require(ReplicatedStorage.Shared.Modules.WorldLabel)
local ClientState = require(script.Parent.Parent.State.ClientState)

local PortalController = {}

local P = Config.Portal
local player = Players.LocalPlayer
local spirals = {} -- { Part, Base (CFrame) }

local function tint(portal: Model, color: Color3)
	for _, part in portal:GetChildren() do
		if part.Name == "Main" then
			part.Color = color
		elseif part.Name == "GlowSwirl" then
			part.Color = color
		elseif part.Name == "GlowGem" then
			part.Color = color:Lerp(Color3.new(1, 1, 1), 0.35)
		elseif part.Name == "GlowSpiral" then
			part.Color = color:Lerp(Color3.new(1, 1, 1), 0.7)
		end
	end
end

local function line(parent: Instance, text: string, kind: string, y: number, height: number)
	local label = UiPack.Get("StatText")
	label.Size, label.Position, label.AnchorPoint, label.Parent = UDim2.fromScale(0.96, height), UDim2.fromScale(0.5, y), Vector2.new(0.5, 0.5), parent
	label.TextXAlignment = Enum.TextXAlignment.Center
	local top = label:FindFirstChild("Color")
	if top and top:IsA("TextLabel") then
		top.TextXAlignment = Enum.TextXAlignment.Center
	end
	UiPack.Text(label, text)
	UiPack.TextGradient(label, kind)
end

local function sign(anchor: BasePart, w: number)
	local B = P.Billboard
	local gui = Instance.new("BillboardGui")
	gui.Name, gui.AlwaysOnTop, gui.LightInfluence, gui.MaxDistance = "Sign", false, 0, B.Max
	gui.StudsOffsetWorldSpace = Vector3.new(0, B.Lift, 0)
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	WorldLabel.Apply(gui, B)
	line(gui, P.Text.Title, P.Gradients[w] or "Blue", 0.34, 0.5)
	line(gui, P.Text.World:format(w, Config.Worlds[w].Name), "White", 0.8, 0.3)
	gui.Adornee, gui.Parent = anchor, anchor
end

local function build(anchor: BasePart)
	local w = tonumber(anchor.Name)
	local def = w and Config.Worlds[w]
	if not def then
		return
	end
	local portal = AssetLibrary.Wait("WorldPortal")
	tint(portal, def.Art.Rays)
	portal:PivotTo(anchor.CFrame)
	portal.Parent = workspace
	for _, part in portal:GetChildren() do
		if part.Name == "GlowSpiral" then
			table.insert(spirals, { Part = part, Base = part.CFrame })
		end
	end
	sign(anchor, w)
	local spot = Instance.new("Attachment")
	spot.Name, spot.Position, spot.Parent = "PromptAt", Vector3.new(0, P.Prompt.Lift, 0), anchor
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText, prompt.ObjectText, prompt.MaxActivationDistance = P.Prompt.Action, P.Prompt.Object, P.Prompt.Reach
	prompt.RequiresLineOfSight, prompt.HoldDuration, prompt.Exclusivity = false, 0, Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Triggered:Connect(function()
		ClientState.OpenMenu(Config.Menu)
	end)
	player:GetAttributeChangedSignal("Running"):Connect(function()
		prompt.Enabled = not player:GetAttribute("Running")
	end)
	prompt.Parent = spot
end

function PortalController.Start()
	local folder = workspace:WaitForChild("Portals")
	for _, anchor in folder:GetChildren() do
		task.spawn(build, anchor)
	end
	RunService.RenderStepped:Connect(function()
		local angle = os.clock() * P.Spin
		for _, s in spirals do
			s.Part.CFrame = s.Base * CFrame.Angles(0, 0, angle)
		end
	end)
end

return PortalController
