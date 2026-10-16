--[[
	Server loader. Creates every bridge up front, requires every ModuleScript in Services, then starts
	each one in its own thread (one throw or hang never stalls the rest). Drop a service in the folder
	and it runs. A Start still running after GameConfig.HangWarning seconds is reported as HANGING.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
Net.Prepare()

local services = {}
for _, module in script.Parent.Services:GetChildren() do
	if module:IsA("ModuleScript") then
		services[module.Name] = require(module)
	end
end

for name, service in services do
	if service.Start then
		local done = false
		task.spawn(function()
			service.Start()
			done = true
		end)
		task.delay(GameConfig.HangWarning, function()
			if not done then
				warn(`[{GameConfig.Name}] {name}.Start is HANGING (>{GameConfig.HangWarning}s)`)
			end
		end)
	end
end

print(`[{GameConfig.Name}] server ready ({GameConfig.Version})`)
