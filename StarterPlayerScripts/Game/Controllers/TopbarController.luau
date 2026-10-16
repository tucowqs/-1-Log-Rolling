--[[
	TopbarController — utility / inventory menus as TopbarPlus icons (TopbarConfig; default grey/white look, e.g.
	Settings). Each icon toggles its ClientState menu and follows it: closing the menu any other way (its X,
	another menu) deselects it. If TopbarPlus isn't in the place, it warns once and does nothing.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.TopbarConfig)
local ClientState = require(script.Parent.Parent.State.ClientState)

local TopbarController = {}

local function find(): ModuleScript?
	local node: Instance? = ReplicatedStorage
	for _, name in Config.Module do
		node = node and node:WaitForChild(name, Config.Wait)
	end
	return if node and node:IsA("ModuleScript") then node else nil
end

function TopbarController.Start()
	local module = find()
	if not module then
		warn("TopbarController: TopbarPlus (ReplicatedStorage." .. table.concat(Config.Module, ".") .. ") isn't in the place, so there are no topbar icons")
		return
	end
	local Icon = require(module) :: any
	local icons = {}
	for order, entry in Config.Icons do
		local icon = Icon.new():setLabel(entry.Label):setImage(entry.Image):setOrder(order)
		if entry.Right then
			icon:align("Right")
		end
		icon.selected:Connect(function()
			if ClientState.MenuOpen() ~= entry.Menu then
				ClientState.OpenMenu(entry.Menu)
			end
		end)
		icon.deselected:Connect(function()
			if ClientState.MenuOpen() == entry.Menu then
				ClientState.CloseMenu()
			end
		end)
		icons[entry.Menu] = icon
	end
	ClientState.On("Menu", function(open)
		for menu, icon in icons do
			if menu == open and not icon.isSelected then
				icon:select()
			elseif menu ~= open and icon.isSelected then
				icon:deselect()
			end
		end
	end)
end

return TopbarController
