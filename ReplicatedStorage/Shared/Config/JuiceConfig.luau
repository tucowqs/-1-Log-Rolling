--[[
	JuiceConfig — the proven numbers behind Juice's event animations (Steal Treasure's chest opening).
	Lists indexed by rarity rank (1 Common .. 8) let rarer finds shake / hover longer; divide every
	duration by a speed factor for a "fast openings" setting (Juice functions take `speed`).
]]
return {
	Shake = { Angle = 7, Speed = 38, Times = { 0.6, 0.75, 0.9, 1.1, 1.35, 1.6, 1.9, 2.3 } }, -- degrees, rad/s wobble, seconds by rank
	Hop = 0.35, -- studs the body jumps as the lid bursts
	Lid = { Time = 0.35, Angle = 115 }, -- seconds to swing open, degrees back about the top-back hinge
	Rise = { Time = 0.4, Hover = 5.5, Spin = 1.8, Bob = 0.25, BobSpeed = 2.2 }, -- item launches the SAME frame the lid bursts
	Hold = { 1.1, 1.2, 1.3, 1.5, 1.7, 1.9, 2.1, 2.6 }, -- seconds hovering by rank
	Fly = { Time = 0.5, Arc = 3, Shrink = 0.75 }, -- quadratic Bezier to a (moving) target, shrinking by Shrink
	Vanish = { Time = 0.7, Spins = 2 }, -- spin faster and faster while ScaleTo -> 0.01
	FastSpeed = 2.5, -- the "fast openings" speed factor
}
