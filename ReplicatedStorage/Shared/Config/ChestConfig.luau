--[[
	ChestConfig — the free group chest in the lobby (ChestService / ChestController; Rock Skipping's "CLAIM / Join Group/Like To
	Claim!"). A player in the Roblox group GroupId claims Reward every Cooldown seconds (saved data.ChestAt). GroupId = 0:
	not set yet, so anyone may claim (set it to the game's group id). Not in the group: the claim opens Roblox's join prompt.
]]
return {
	Bridges = {
		"ChestClaim", -- C->S {}
	},
	GroupId = 0, -- PLACEHOLDER: the friend's group id
	Cooldown = 12 * 3600,
	Reward = { Wins = 1000, Potions = { Speed = 1, Wins = 1 } }, -- a MonetizeService.Bundle
	Anchor = "FreeChest", -- workspace part (tools/lobby_layout.lua)
	Billboard = { Size = Vector2.new(12, 5), Lift = 9, Near = 26 },
	Lid = { Hinge = Vector3.new(0, 3.8, -2.3), Open = 70, Time = 0.5 }, -- model-space hinge (Blender FreeChest), degrees, seconds
	Prompt = { Distance = 12 },
	Text = { Claim = "CLAIM", Hint = "Join the Group to claim!", Wait = "Next chest in %s", Claimed = "Chest claimed: %s", NotYet = "Come back in %s!",
		NeedGroup = "Join the group to claim the chest!" },
}
