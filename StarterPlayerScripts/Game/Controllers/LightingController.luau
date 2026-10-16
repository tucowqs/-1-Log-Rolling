--[[
	LightingController — the world's light follows the camera through the game's areas (ZoneLighting,
	LightingConfig), eased every frame: current = Blend(current, Look(camera), 1 - exp(-Ease * dt)).
	Nothing else tweens the lighting. It applies LightingConfig.World once, owns Lighting.Ambient /
	OutdoorAmbient, the Atmosphere, the "Grade" ColorCorrection and the Bloom (creating any that are
	missing), and tames lights: every light under the StreamFade roots is toned down (PointLights x its
	area's LightScale); accent lights (in AccentMarker parts under a folder whose AreaAttribute
	names the look) take that area's Lights colours / brightness / range; lights that stream in later fade up
	from dark instead of popping on.
	LightingConfig.Authored = true (the kit default): Lighting is hand-authored in Studio and is the source of
	truth, so only the stream-in light fade runs; nothing in Lighting is set at runtime (playtest = edit mode).
]]
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.LightingConfig)
local ZoneLighting = require(ReplicatedStorage.Shared.Modules.ZoneLighting)

local LightingController = {}

local counts: { [Instance]: number } = {} -- area folder -> accent lights dressed so far (to cycle colours)

local function effect(className: string, name: string): Instance
	local found = Lighting:FindFirstChild(name)
	if found and found:IsA(className) then
		return found
	end
	local made = Instance.new(className)
	made.Name = name
	made.Parent = Lighting
	return made
end

-- The nearest ancestor naming an area look (LightingLook attribute), and that look's config.
local function areaOf(light: Instance): (Instance?, any)
	local node = light.Parent
	while node and node ~= workspace do
		local name = node:GetAttribute(Config.AreaAttribute)
		if name and Config.Looks[name] then
			return node, Config.Looks[name]
		end
		node = node.Parent
	end
	return nil, nil
end

-- Dress (accent lights) and tone down a light, once per instance (a re-streamed one is a new instance).
local function tame(light: Light)
	if light:GetAttribute("Tamed") then
		return
	end
	light:SetAttribute("Tamed", true)
	local area, look = areaOf(light)
	local L = look and look.Lights
	if L and light.Parent.Name == Config.AccentMarker then
		counts[area] = (counts[area] or 0) + 1
		light.Color = L.Colors[(counts[area] - 1) % #L.Colors + 1]
		light.Brightness = L.Brightness
		light.Range = L.Range
	end
	light.Brightness *= Config.PointLights.Brightness * (look and look.LightScale or 1)
	light.Range *= Config.PointLights.Range
end

local function watchRoot(root: Instance, fade: TweenInfo)
	for _, light in root:GetDescendants() do
		if light:IsA("Light") then
			tame(light)
		end
	end
	root.DescendantAdded:Connect(function(light)
		if light:IsA("Light") then
			tame(light)
			local target = light.Brightness
			light.Brightness = 0
			TweenService:Create(light, fade, { Brightness = target }):Play()
		end
	end)
end

function LightingController.Start()
	local fade = TweenInfo.new(Config.StreamFade.Time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, name in Config.StreamFade.Roots do
		task.spawn(function() -- a root that streams in late must not hold up the others
			watchRoot(workspace:WaitForChild(name), fade)
		end)
	end
	if Config.Authored then
		return -- Studio's hand-authored Lighting is the look: never override it at runtime
	end
	for key, value in Config.World do
		Lighting[key] = value
	end
	local atmosphere = effect("Atmosphere", "Atmosphere")
	local grade = effect("ColorCorrectionEffect", "Grade")
	local bloom = effect("BloomEffect", "Bloom")
	bloom.Size, bloom.Threshold = Config.Bloom.Size, Config.Bloom.Threshold
	local current = ZoneLighting.Look(workspace.CurrentCamera.CFrame.Position)
	RunService.Heartbeat:Connect(function(dt)
		local target = ZoneLighting.Look(workspace.CurrentCamera.CFrame.Position)
		current = ZoneLighting.Blend(current, target, 1 - math.exp(-Config.Ease * dt))
		ZoneLighting.Apply(current, atmosphere, grade, bloom)
	end)
end

return LightingController
