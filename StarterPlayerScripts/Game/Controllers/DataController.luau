--[[
	DataController — tells the server this client is listening. Main.client spawns every controller's
	Start in one synchronous loop and controllers connect their bridges at the top of Start, so a deferred
	Ready runs after all of them: the server then resends the full snapshot ("Snapshot") and every system
	that listens to "Ready" (TutorialService...) resends its own state. Nothing is missed on join.
]]
local ClientState = require(script.Parent.Parent.State.ClientState)

local DataController = {}

function DataController.Start()
	task.defer(ClientState.Ready)
end

return DataController
