--[[
	Juice — event-driven "juice" for world models (open a chest, pop a reward, collect an item), built
	the Steal Treasure way: every step is a Heartbeat loop (no TweenService), so the same code plays in
	game and in an edit-mode preview. Each call YIELDS until done; task.spawn one sequence per model so
	several can play at once. Numbers in JuiceConfig; `speed` (default 1) divides every duration.
		Juice.Over(time, function(alpha, seconds) ... end)  -- per-frame driver, ends on alpha = 1
		Juice.OutBack(a)                                  -- 1 + 2.7(a-1)^3 + 1.7(a-1)^2 (springy overshoot)
		local place, size = Juice.Placer(model)           -- place(cf, k?): put the model's BOX CENTRE at cf (k = scale since)
		Juice.Shake(model, time, speed?)                  -- wobble about its box centre, building up
		Juice.Burst(model, lid, speed?)                   -- hop + lid swings open about the body's top-back edge
		Juice.Rise(model, from, to, speed?)               -- outBack rise from -> to (CFrames), spinning
		Juice.FlyTo(model, getTarget, speed?)             -- Bezier arc into getTarget() (re-read each frame), shrinking
		Juice.Vanish(model, speed?)                       -- spin up + shrink to nothing (emitters shrink too), then Destroy
		Juice.PlayAuthored(source, holder) -> emitters    -- clone hand-made VFX, honour EmitDelay / EmitCount / EmitDuration
	Chest recipe: Shake(chest, JuiceConfig.Shake.Times[rank]) -> task.spawn(Burst, chest, lid) + Rise(item, ...)
	-> Over(Hold[rank], bob) -> FlyTo(item, playerHead) -> Vanish(chest). Launch the item the same frame
	the lid bursts (any delay felt bad).
]]
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Parent.Config.JuiceConfig)

local Juice = {}

function Juice.OutBack(a: number): number
	return 1 + 2.7 * (a - 1) ^ 3 + 1.7 * (a - 1) ^ 2
end

function Juice.Over(time: number, fn)
	local t = 0
	while t < time do
		fn(t / time, t)
		t += RunService.Heartbeat:Wait()
	end
	fn(1, time)
end

-- place(cf, k?) puts the model's bounding-box centre at cf (its pivot may sit anywhere); k = how much
-- the model has been ScaleTo'd since (the pivot -> centre offset scales with it). Also returns its size.
function Juice.Placer(model: Model)
	local box, size = model:GetBoundingBox()
	local offset = model:GetPivot():ToObjectSpace(box)
	return function(cf: CFrame, k: number?)
		model:PivotTo(cf * (CFrame.new(offset.Position * (k or 1)) * offset.Rotation):Inverse())
	end, size
end

local function centre(model: Model): CFrame
	return (model:GetBoundingBox())
end

function Juice.Shake(model: Model, time: number, speed: number?)
	local place = Juice.Placer(model)
	local rest = centre(model)
	local S = Config.Shake
	Juice.Over(time / (speed or 1), function(a, t)
		local angle = math.rad(S.Angle) * math.sin(t * S.Speed) * (0.25 + 0.75 * a)
		place(rest * CFrame.Angles(angle * 0.4, 0, angle))
	end)
	place(rest)
end

-- The lid's hinge: the top back (-Z) edge of the body (the model's PrimaryPart), in the model's
-- frame. Not the lid's own bounds: overhanging lid meshes put that hinge in mid-air ("lid fell off").
local function hingeOf(model: Model): CFrame
	local body = model.PrimaryPart
	local at = model:GetPivot():PointToObjectSpace(body.Position)
	return CFrame.new(at + Vector3.new(0, body.Size.Y / 2, -body.Size.Z / 2))
end

function Juice.Burst(model: Model, lid: Instance?, speed: number?)
	local pivot0 = model:GetPivot()
	local lidRel = lid and pivot0:ToObjectSpace(lid:GetPivot())
	local hinge = lid and hingeOf(model)
	Juice.Over(Config.Lid.Time / (speed or 1), function(a)
		local pivot = pivot0 * CFrame.new(0, Config.Hop * math.sin(a * math.pi), 0)
		model:PivotTo(pivot)
		if lid then
			lid:PivotTo(pivot * hinge * CFrame.Angles(math.rad(-Config.Lid.Angle * Juice.OutBack(a)), 0, 0) * hinge:Inverse() * lidRel)
		end
	end)
end

function Juice.Rise(model: Model, from: CFrame, to: CFrame, speed: number?)
	local place = Juice.Placer(model)
	local started = os.clock()
	Juice.Over(Config.Rise.Time / (speed or 1), function(a)
		local turn = ((os.clock() - started) * Config.Rise.Spin) % (math.pi * 2)
		place(from:Lerp(to, Juice.OutBack(a)) * CFrame.Angles(0, turn, 0))
	end)
end

function Juice.FlyTo(model: Model, getTarget: () -> Vector3?, speed: number?)
	local place = Juice.Placer(model)
	local start = centre(model).Position
	local target, scale = start, model:GetScale()
	Juice.Over(Config.Fly.Time / (speed or 1), function(a)
		target = getTarget() or target
		local e = a * a
		local mid = (start + target) / 2 + Vector3.new(0, Config.Fly.Arc, 0)
		local k = 1 - Config.Fly.Shrink * e
		model:ScaleTo(scale * k)
		place(CFrame.new((1 - e) ^ 2 * start + 2 * (1 - e) * e * mid + e * e * target), k)
	end)
end

local function scaled(size: NumberSequence, k: number): NumberSequence
	local points = {}
	for _, p in size.Keypoints do
		table.insert(points, NumberSequenceKeypoint.new(p.Time, p.Value * k, p.Envelope * k))
	end
	return NumberSequence.new(points)
end

function Juice.Vanish(model: Model, speed: number?)
	local place = Juice.Placer(model)
	local rest, scale = centre(model), model:GetScale()
	local emitters = {}
	for _, e in model:GetDescendants() do
		if e:IsA("ParticleEmitter") then
			table.insert(emitters, { Emitter = e, Size = e.Size, Speed = e.Speed })
		end
	end
	Juice.Over(Config.Vanish.Time / (speed or 1), function(a)
		local k = math.max(1 - a * a, 0.01)
		model:ScaleTo(scale * k) -- ScaleTo is absolute: always from the starting scale
		place(rest * CFrame.Angles(0, (Config.Vanish.Spins * math.pi * 2 * a * a) % (math.pi * 2), 0), k)
		for _, entry in emitters do
			entry.Emitter.Size = scaled(entry.Size, k)
			entry.Emitter.Speed = NumberRange.new(entry.Speed.Min * k, entry.Speed.Max * k)
		end
	end)
	model:Destroy()
end

-- Clones hand-made VFX (an Attachment / Folder of emitters) into holder: each emitter waits its
-- EmitDelay, emits EmitCount, then runs EmitDuration seconds. Returns the emitters.
function Juice.PlayAuthored(source: Instance, holder: Instance): { ParticleEmitter }
	local vfx = source:Clone()
	vfx.Parent = holder
	local list = {}
	for _, emitter in vfx:GetDescendants() do
		if emitter:IsA("ParticleEmitter") then
			table.insert(list, emitter)
			local count, duration = emitter:GetAttribute("EmitCount") or 0, emitter:GetAttribute("EmitDuration") or 0
			task.delay(emitter:GetAttribute("EmitDelay") or 0, function()
				if count > 0 then
					emitter:Emit(count)
				end
				if duration > 0 then
					emitter.Enabled = true
					task.delay(duration, function()
						emitter.Enabled = false
					end)
				end
			end)
		end
	end
	return list
end

return Juice
