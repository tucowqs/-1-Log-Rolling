--[[
	EconomyConfig — THE economy knobs (2026-10-15 rework). Every price, multiplier and payout in the game is generated from
	these few numbers by Shared/Modules/Economy, so the whole economy is retuned here and nowhere else.
	Pacing these numbers were simulated for (a player rolling non-stop, steering into ramps, ~25% of Wins on eggs):
	  log 2 at ~2 min, 1st rebirth at ~4 min, rebirths every 3-20 min, World 2 at ~1 h (rebirth ~13), all 20 logs at ~3 h.
	  With no pets at all the same milestones land ~20% later; nothing hard-walls before the last log.
	  World 3 (Dream Kingdom, 2026-10-16) just continues the same ladders (nothing here changed for it): logs tier 21-30 (Mult 12K .. 830K,
	  price 27M .. 8.6B), zones g 17-24 (300K .. 75M Wins), pets Rank 21-28, belts x12 .. x20 from rebirth 25. It opens at 9e8 Speed (WorldsConfig
	  Need) = ~60% of the Speed cap at 24 rebirths, as World 2's 1e6 was at 12. Not simulated for pacing yet.

	  Level      XP to leave level L = BaseXP x Growth^(L-1)                       (Curves.XPForLevel)
	             x Early[L] for the first levels before the first rebirth (a softer start); rebirth 1 = the plain curve;
	             from rebirth 2 the first Hard.Levels levels cost a bit more per rebirth (Curves.XPForLevel(level, rebirths))
	  Rebirth    level cap MaxLevel(N) = BaseMaxLevel + LevelsPerRebirth x N     (each rebirth raises the cap Speed ~1.76x)
	             Speed multiplier Mult(N) = 1 + MultPerRebirth x N  (ADDITIVE: x1, x1.5, x2 ... x11 at 20; RebirthMath)
	  Wins       zone g pays Growth^(g-1) x EarlyBoost[g] x StartBuff[g] Wins, g = ZonesPerWorld x (world - 1) + zone: ONE ladder through every world
	  Logs       tier t = the log's place in BalanceConfig.Logs (Limited logs skipped), PerWorld logs per world:
	             Mult(t) = MultGrowth^(t-1)   Price(2) = FirstPrice, then x PriceGrowth[world] per log, x WorldJump into a new world
	             Durability = Life[world].Start + Life[world].Step x (i-1) seconds (i = place in its world), on its OWN world's hill;
	             on another world's hill it lasts x Wear^(world - log's world) (an old log wears out 4x faster one world on)
	  Pets       a pet's bonus = Base x Growth^(Rank-1) (PetsConfig gives each pet a Rank; the Robux pets sit on the same ladder)
	  Eggs/Trails  cost the same as the log of their Tier (an egg is worth "one log" of progress)
	  Training   Speed per treadmill tick = Rate x the belt's Mult x the equipped log's Mult: Rate 1 = the "+N Speed / hit" on
	             the log's pad, every tick on the Jogging Belt (x1)
	Every generated number is rounded to 2 significant figures (Economy.Nice).
]]
return {
	-- Early: XP multiplier per level from level 1: levels 1-5 cost half, 6-10 cost 20% less, then normal
	-- (only before the first rebirth: rebirth 1 is the plain curve)
	-- Hard: from rebirth 2 the first Levels levels cost x(1 + PerRebirth x (rebirths - 1)), at most x Max
	Level = { BaseXP = 80, Growth = 1.12, Early = { 0.5, 0.5, 0.5, 0.5, 0.5, 0.8, 0.8, 0.8, 0.8, 0.8 },
		Hard = { Levels = 20, PerRebirth = 0.15, Max = 3 } },
	Rebirth = { BaseMaxLevel = 10, LevelsPerRebirth = 5, MultPerRebirth = 0.5 },
	Wins = {
		Growth = 2.2,
		ZonesPerWorld = 8,
		-- extra x on the first zones of the ladder (zone g = this list's g-th entry), so a new player's first rolls pay enough
		-- for the Birch Log inside the tutorial; it fades to x1 by zone 6 so later pacing is unchanged
		EarlyBoost = { 6, 4.5, 3.2, 2.2, 1.5 },
		-- a further x on top (2026-10-15): +50% in World 1's first 5 zones, easing back to x1 over zones 6-8 (World 2 is unchanged)
		StartBuff = { 1.5, 1.5, 1.5, 1.5, 1.5, 1.35, 1.2, 1.1 },
	},
	Logs = {
		PerWorld = 10,
		FirstPrice = 20, -- the Birch Log (the Basic Log is free)
		PriceGrowth = { 2.3, 1.9 }, -- per world (later worlds use the last); World 2 logs climb slower because its zones pay more per log
		WorldJump = 2.3, -- the first log of a new world costs this x the last log of the world before
		MultGrowth = 1.6,
		Life = { { Start = 14, Step = 2.2 }, { Start = 13, Step = 1.9 } }, -- seconds, per world (later worlds use the last)
		Wear = 0.25,
	},
	Pets = { Base = 0.1, Growth = 1.35 },
	Training = { Rate = 1 },
}
