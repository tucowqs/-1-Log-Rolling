--[[
	FunnelConfig — every analytics name the game logs (FunnelService / FunnelWatchService on the server,
	AnalyticsController on the client). Results show in the Creator Dashboard -> Analytics (Funnels,
	Economy, Custom Events) of the PUBLISHED game, about a day later. Studio logs nothing.
	NEVER rename or reorder a step once published: the dashboard keys funnels on step numbers.
	Add new steps / funnels / events at the END only.
]]
return {
	Bridges = { "Analytics" }, -- the client's reports (Net registers it)

	-- One time per player, ever (LogOnboardingFunnelStepEvent). The saved high-water mark
	-- data.OnboardingStep makes every step log once. "Joined" is logged on load.
	-- Adding analytics to a LIVE game: add a DataMigrations step that sets data.OnboardingStep =
	-- #Onboarding for old saves, or veterans walk the funnel on their next join.
	Onboarding = { "Joined", "Tutorial Done" },
	-- TutorialConfig step id -> the onboarding step reached when that tutorial step starts (the player's
	-- "Tutorial" attribute). Finishing the tutorial logs TutorialDone; skipping it, the TutorialSkipped event.
	Tutorial = {},
	TutorialDone = "Tutorial Done",

	-- Repeatable funnels (LogFunnelStepEvent): step 1 starts a new session. Client = the steps a client may
	-- report over the "Analytics" bridge (AnalyticsController.Step); everything else is server-only.
	Funnels = {
		RobuxShop = { Steps = { "Opened Shop", "Prompted", "Purchased" }, Client = { "Opened Shop", "Prompted" } },
	},
	-- Opening one of these ClientState menus is that funnel step.
	MenuSteps = {
		Shop = { "RobuxShop", "Opened Shop" },
	},

	-- Lifetime milestones, each its own funnel with one session per player (saved high-water mark
	-- data.Milestones[key]): a player attribute compared to the ascending At thresholds.
	Milestones = {
		Wins = { Funnel = "Wins Milestones", Attribute = "Wins", At = { 100, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9 } },
		Rebirths = { Funnel = "Rebirth Milestones", Attribute = "Rebirths", At = { 1, 2, 4, 6, 10, 15, 25 } },
	},

	-- Custom events (LogCustomEvent); fields go in CustomField01..03 in the order listed.
	Events = {
		MenuOpened = { Name = "Menu Opened", Fields = { "Menu" } },
		TutorialSkipped = { Name = "Tutorial Skipped", Fields = { "Step" } },
		RobuxPurchase = { Name = "Robux Purchase", Fields = { "Item", "Kind" } },
	},
	-- Menus the client may report (anything else is ignored: keeps the field's values few).
	Menus = { "Shop", "Settings", "Pets", "Rebirth", "Trails", "Inventory", "Gifts", "Worlds" },

	-- Economy (LogEconomyEvent). Currency = the name on the dashboard (the balance is DataConfig.Currency).
	Currency = "Wins",
	-- Passive income: the player attribute holding income per second, summed and logged as one Source
	-- every IncomeFlush seconds (nil = no passive income logging).
	IncomeAttribute = nil, -- no passive income (Wins come from rolls)
	IncomeFlush = 120,
	PollInterval = 2, -- seconds between milestone checks
	ClientCooldown = 0.2, -- seconds between a client's "Analytics" reports
}
