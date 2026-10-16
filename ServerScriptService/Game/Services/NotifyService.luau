--[[
	NotifyService — the server's way into the one toast system (NotifyController draws them):
	  NotifyService.Send(player, text, kind?)   "Notify" { Text, Kind } to one player
	  NotifyService.Announce(text)             "Announcement" { Text } to everyone (announcement sound)
	kind: "Success" | "Warning" | "Error" | "Info" (default). Build text with Emphasis.Em for the key words.
	Only send what the screen doesn't already show (NotifyConfig header).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)

local NotifyService = {}

function NotifyService.Send(player: Player, text: string, kind: string?)
	Net.Get("Notify"):Fire(player, { Text = text, Kind = kind or "Info" })
end

function NotifyService.Announce(text: string)
	Net.Get("Announcement"):Fire(Net.All(), { Text = text })
end

function NotifyService.Start() end

return NotifyService
