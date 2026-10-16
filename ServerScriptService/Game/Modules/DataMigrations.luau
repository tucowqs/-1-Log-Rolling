--[[
	DataMigrations — one function per DataConfig.Version step: [version] = function(data) ... end.
	DataService runs every step above a save's DataVersion once, in order, right after Reconcile.
	Never edit or remove a published step; add the next one and bump DataConfig.Version.
	Patterns that worked (Steal Treasure):
	  rescale an economy        [2] = function(data) data.Cash *= 1000 end
	  rename retired ids        for uid, id in data.Items do data.Items[uid] = Renamed[id] or id end
	  remap tiers               data.Tier = ({ 1, 2, 2, 3 })[data.Tier] or 1
	  drop a replaced field     data.OldField = nil
]]
return {
	[2] = function(data) -- Strength was renamed Speed
		data.Speed = (data.Speed or 0) + (data.Strength or 0)
		data.Strength = nil
	end,
	[3] = function(data) -- Level / XP became a function of Speed
		data.Level, data.LevelHits = require(game:GetService("ReplicatedStorage").Shared.Modules.Curves).LevelFor(data.Speed)
	end,
	[4] = function(data) -- TotalLevels (lifetime levels gained): each past rebirth needed its cap, so count those plus the current run
		local RebirthMath = require(game:GetService("ReplicatedStorage").Shared.Modules.RebirthMath)
		local total = (data.Level or 1) - 1
		for r = 0, (data.Rebirths or 0) - 1 do
			total += RebirthMath.MaxLevel(r) - 1
		end
		data.TotalLevels = math.max(data.TotalLevels or 0, total)
	end,
}
