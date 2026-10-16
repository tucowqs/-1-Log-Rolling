-- Flags the players' next Launch as infinite (RollService reads and clears the "InfinLog" attribute).
return function(_, players: { Player })
	for _, player in players do
		player:SetAttribute("InfinLog", true)
	end
	return ("Next run is an infinite log for %d player(s)."):format(#players)
end
