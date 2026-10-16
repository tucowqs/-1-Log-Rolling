--[[
	Aura — a particle aura that follows a model: an invisible box whose surface sprays the emitters listed in AuraConfig
	(later logs by log id, rarer pets by rarity). The box lives outside the model, so Model:ScaleTo never rescales the
	particles; the owner moves it every frame.
	  Aura.Log(logId, parent) / Aura.Pet(petId, parent) -> aura?   (nil when that log / rarity has none)
	  aura:Place(cframe, size)   aura:Show(on)   aura:Destroy()
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.AuraConfig)
local PetMath = require(ReplicatedStorage.Shared.Modules.PetMath)
local VFXKit = require(ReplicatedStorage.Shared.Modules.VFXKit)

local Aura = {}
Aura.__index = Aura

Aura.Config = Config

function Aura.new(specs: { any }?, parent: Instance)
	if not specs then
		return nil
	end
	local box = Instance.new("Part")
	box.Name, box.Size, box.Transparency = "Aura", Vector3.one, 1
	box.Anchored, box.CanCollide, box.CanTouch, box.CanQuery, box.CastShadow = true, false, false, false, false
	local emitters = {}
	for _, spec in specs do
		local s = table.clone(spec)
		s.Shape = s.Shape or Config.Shape
		table.insert(emitters, VFXKit.Emitter(box, s))
	end
	box.Parent = parent
	return setmetatable({ Box = box, Emitters = emitters, On = true, Size = Vector3.one }, Aura)
end

function Aura.Log(logId: string, parent: Instance)
	return Aura.new(Config.Logs[logId], parent)
end

function Aura.Pet(petId: string, parent: Instance)
	return Aura.new(Config.Pets[PetMath.Pet(petId).Rarity], parent)
end

function Aura:Place(cframe: CFrame, size: Vector3)
	if size ~= self.Size then
		self.Box.Size, self.Size = size, size
	end
	self.Box.CFrame = cframe
end

function Aura:Show(on: boolean)
	if on ~= self.On then
		self.On = on
		for _, e in self.Emitters do
			e.Enabled = on
		end
	end
end

function Aura:Destroy()
	self.Box:Destroy()
end

return Aura
