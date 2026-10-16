--[[
	MusicController — background music by mood (MusicConfig). Every Check seconds it picks the mood:
	SetOverride's mood if one is set (a boss fight, an area's own music), else the first Rule whose player
	attribute is truthy (e.g. "Chased" -> Chase), else Default. Moods crossfade; each mood's playlist
	rotates when a track ends. The SettingKey setting silences the "Music" SoundGroup.
	  MusicController.SetOverride(mood?)   nil hands control back to the rules
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config.MusicConfig)
local Ui = require(ReplicatedStorage.Shared.Modules.Ui)
local ClientState = require(script.Parent.Parent.State.ClientState)

local MusicController = {}

local player = Players.LocalPlayer
local group: SoundGroup
local current = { Mood = nil, Sound = nil }
local playlistIndex = {}
local override: string? = nil

local function nextTrack(mood: string): string
	local tracks = Config.Moods[mood].Tracks
	playlistIndex[mood] = (playlistIndex[mood] or math.random(#tracks)) % #tracks + 1
	return tracks[playlistIndex[mood]]
end

local function fadeOut(sound: Sound)
	Ui.Tween(sound, Config.Fade, { Volume = 0 }).Completed:Connect(function()
		sound:Destroy()
	end)
end

local function play(mood: string)
	if current.Sound then
		fadeOut(current.Sound)
	end
	local def = Config.Moods[mood]
	local sound = Ui.Make("Sound", {
		Name = "Music_" .. mood, SoundId = nextTrack(mood), Volume = 0, Looped = #def.Tracks == 1,
		SoundGroup = group, Parent = SoundService,
	})
	sound.Ended:Connect(function()
		if current.Sound == sound then
			current.Mood = nil -- the next check starts the next track of the playlist
		end
	end)
	sound:Play()
	Ui.Tween(sound, Config.Fade, { Volume = def.Volume })
	current.Mood, current.Sound = mood, sound
end

local function moodNow(): string
	if override then
		return override
	end
	for _, rule in Config.Rules do
		if player:GetAttribute(rule.Attribute) then
			return rule.Mood
		end
	end
	return Config.Default
end

function MusicController.SetOverride(mood: string?)
	assert(mood == nil or Config.Moods[mood], "unknown mood")
	override = mood
end

function MusicController.Start()
	group = Ui.Make("SoundGroup", { Name = "Music", Volume = Config.Volume, Parent = SoundService })
	local function applySetting()
		group.Volume = ClientState.Settings[Config.SettingKey] and 0 or Config.Volume
	end
	ClientState.On("Settings", applySetting)
	applySetting()
	while true do
		local mood = moodNow()
		if mood ~= current.Mood and Config.Moods[mood] then
			play(mood)
		end
		task.wait(Config.Check)
	end
end

return MusicController
