--[[
	TutorialService — the first-time sequence (TutorialConfig.Steps). Game services report progress with
	Advance(player, stepId); only the current step can advance. Steps with a Duration advance on their own.
	The step is saved (data.TutorialStep / TutorialDone), so the tutorial resumes on rejoin; a tutorial left
	half-done under an older TutorialConfig.Version starts again from the first step.
	Publishes the player attribute "Tutorial" (current step Id, nil once finished) and "TutorialSkipped".
	  Current(p) -> id?   Goal(p) -> number?   Advance(p, id)   Rewind(p, id)   Restart(p, id?) -> bool
	  OnStepStarted(cb(player, id))
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.TutorialConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local DataService = require(script.Parent.DataService)

local TutorialService = {}

local startedCallbacks = {}

local function indexOf(id: string): number?
	for index, step in Config.Steps do
		if step.Id == id then
			return index
		end
	end
	return nil
end

-- resendOnly: just repeat the current step to the client (it asked with "Ready").
local function send(player: Player, resendOnly: boolean?)
	local data = DataService.Get(player)
	if not data then
		return
	end
	if data.TutorialDone then
		player:SetAttribute("Tutorial", nil)
		Net.Get("Tutorial"):Fire(player, { Done = true })
		return
	end
	local step = Config.Steps[data.TutorialStep]
	player:SetAttribute("Tutorial", step.Id)
	Net.Get("Tutorial"):Fire(player, { Index = data.TutorialStep, Count = #Config.Steps, Id = step.Id })
	if resendOnly then
		return
	end
	for _, callback in startedCallbacks do
		task.spawn(callback, player, step.Id)
	end
	if step.Duration then
		local at = data.TutorialStep
		task.delay(step.Duration, function()
			local now = DataService.Get(player)
			if now and not now.TutorialDone and now.TutorialStep == at then
				TutorialService.Advance(player, step.Id)
			end
		end)
	end
end

function TutorialService.Current(player: Player): string?
	local data = DataService.Get(player)
	if not data or data.TutorialDone then
		return nil
	end
	return Config.Steps[data.TutorialStep].Id
end

function TutorialService.Goal(player: Player): number?
	local data = DataService.Get(player)
	return data and not data.TutorialDone and Config.Steps[data.TutorialStep].Goal or nil
end

function TutorialService.Advance(player: Player, id: string)
	local data = DataService.Get(player)
	if not data or data.TutorialDone or Config.Steps[data.TutorialStep].Id ~= id then
		return
	end
	if data.TutorialStep >= #Config.Steps then
		data.TutorialDone = true
	else
		data.TutorialStep += 1
	end
	send(player)
end

-- Jump the tutorial back (e.g. the tutorial item was lost): only moves backwards.
function TutorialService.Rewind(player: Player, id: string)
	local data = DataService.Get(player)
	local index = indexOf(id)
	if data and not data.TutorialDone and index and index < data.TutorialStep then
		data.TutorialStep = index
		send(player)
	end
end

-- Back to the first step (or the step with this id), even after finishing (Cmdr "tutorial").
function TutorialService.Restart(player: Player, id: string?): boolean
	local data = DataService.Get(player)
	local index = if id then indexOf(id) else 1
	if data and index then
		data.TutorialDone, data.TutorialStep = false, index
		player:SetAttribute("TutorialSkipped", nil)
		send(player)
	end
	return index ~= nil
end

function TutorialService.OnStepStarted(callback)
	table.insert(startedCallbacks, callback)
end

function TutorialService.Start()
	DataService.OnPrepare(function(_, data)
		data.TutorialStep = data.TutorialStep or 1
		data.TutorialDone = data.TutorialDone or false
		if data.TutorialVersion == nil and Config.SkipIf and Config.SkipIf(data) then
			data.TutorialDone = true -- a save from before the tutorial existed
		end
		if not data.TutorialDone and (data.TutorialVersion or Config.Version) < Config.Version then
			data.TutorialStep = 1 -- the steps changed since they started
		end
		data.TutorialVersion = Config.Version
		local step = Config.Steps[data.TutorialStep]
		if not data.TutorialDone and (step == nil or step.ResumeAt) then
			data.TutorialStep = step and indexOf(step.ResumeAt) or 1 -- unsaved progress: resume earlier
		end
	end)
	DataService.OnLoaded(function(player)
		send(player)
	end)
	Net.Get("Ready"):Connect(function(player)
		send(player, true)
	end)
	Net.Get("SkipTutorial"):Connect(function(player)
		local data = DataService.Get(player)
		if data and not data.TutorialDone then
			data.TutorialDone = true
			player:SetAttribute("TutorialSkipped", true)
			send(player)
		end
	end)
end

return TutorialService
