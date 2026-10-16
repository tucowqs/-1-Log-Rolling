--[[
	Client loader. Requires every ModuleScript in Controllers and starts each one in its own thread.
	Controllers connect their bridges synchronously at the top of Start, then ask for state (the core
	Data system's DataController defers ClientState.Ready, which fires the Ready bridge).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

-- The loading screen goes up before anything else builds UI (it holds every other screen back until the lobby is in).
require(script.Parent.Controllers.LoadingController).Start()

for _, module in script.Parent.Controllers:GetChildren() do
	if module:IsA("ModuleScript") then
		local controller = require(module)
		if controller.Start then
			task.spawn(controller.Start)
		end
	end
end

print(`[{GameConfig.Name}] client ready ({GameConfig.Version})`)
