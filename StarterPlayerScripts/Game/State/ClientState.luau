--[[
	ClientState — the client's single source of truth: the saved-data snapshot (DataService "Snapshot"
	bridge, partial snapshots merged in), Settings, a tiny event bus and the menu registry (one menu open
	at a time). Controllers read it and subscribe with On; relay bridge data to other controllers through
	Emit rather than a second Connect on the same bridge (a second Connect may never receive anything).
	  ClientState.Data / ClientState.Settings
	  On(event, cb) / Emit(event, ...)   built-in events: "Data", "Settings", "Menu"
	  SetSetting(key, value)             saves through the "SaveSettings" bridge (SettingsService)
	  RegisterMenu(name, open, close) / OpenMenu(name, context) / CloseMenu() / ToggleMenu(name) / MenuOpen()
	  Ready()                            asks the server to resend everything (DataController defers it)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)

local ClientState = {
	Data = {},
	Settings = {},
}

local listeners = {}
local menus = {}
local openMenu: string? = nil

function ClientState.On(event: string, callback)
	listeners[event] = listeners[event] or {}
	table.insert(listeners[event], callback)
end

function ClientState.Emit(event: string, ...)
	for _, callback in listeners[event] or {} do
		task.spawn(callback, ...)
	end
end

-- A Partial snapshot carries only the fields that changed (DataService.Sync): merge them in.
function ClientState.SetData(snapshot)
	local partial = snapshot.Partial
	snapshot.Partial = nil
	if partial then
		for key, value in snapshot do
			ClientState.Data[key] = value
		end
	else
		ClientState.Data = snapshot
	end
	if snapshot.Settings then
		ClientState.Settings = snapshot.Settings
		ClientState.Emit("Settings")
	end
	ClientState.Emit("Data")
end

function ClientState.SetSetting(key: string, value: any)
	ClientState.Settings[key] = value
	Net.Get("SaveSettings"):Fire({ [key] = value })
	ClientState.Emit("Settings")
end

-- Menus register an open(context) / close() pair; only one menu is open at a time.
function ClientState.RegisterMenu(name: string, open, close)
	menus[name] = { Open = open, Close = close }
end

function ClientState.OpenMenu(name: string, context)
	if openMenu and openMenu ~= name then
		menus[openMenu].Close()
	end
	openMenu = name
	menus[name].Open(context)
	ClientState.Emit("Menu", name)
end

function ClientState.CloseMenu()
	if openMenu then
		menus[openMenu].Close()
		openMenu = nil
		ClientState.Emit("Menu", nil)
	end
end

function ClientState.ToggleMenu(name: string)
	if openMenu == name then
		ClientState.CloseMenu()
	elseif menus[name] then
		ClientState.OpenMenu(name)
	end
end

function ClientState.MenuOpen(): string?
	return openMenu
end

Net.Get("Snapshot"):Connect(ClientState.SetData)

-- Called once every controller is listening: the server resends the full snapshot (and its own state).
function ClientState.Ready()
	Net.Get("Ready"):Fire({})
end

return ClientState
