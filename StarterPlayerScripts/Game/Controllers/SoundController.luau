--[[
	SoundController — plays named effects from SoundConfig, 2D (SoundService) or 3D at a part / attachment:
	  SoundController.Play(name, at?, pitch?)
	and hooks every UiKit button click (Ui.OnClick) to the "Click" sound. Game-specific stings (pickups,
	splashes, gains) are wired by the controllers that own those moments, calling Play.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config.SoundConfig)
local Ui = require(ReplicatedStorage.Shared.Modules.Ui)

local SoundController = {}

function SoundController.Play(name: string, at: Instance?, pitch: number?)
	local entry = Config.Sounds[name]
	if not entry or entry.Id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = entry.Id
	sound.Volume = entry.Volume * Config.Volume
	sound.PlaybackSpeed = pitch or entry.Pitch or 1
	sound.Parent = at or SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	task.delay(Config.MaxLifetime, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

function SoundController.Start()
	Ui.OnClick = function()
		SoundController.Play("Click")
	end
end

return SoundController
