-- Executa o farejar e preserva seu intervalo entre tentativas.
return function(r)
	local progress,status,pause,Constants=r.progress,r.status,r.pause,r.Constants
	local nextSniff=0
	local m={kind="Sniff"}
	function m.run(name)
		local a, b = progress(name, "Sniff")
		if a < b and os.clock() >= nextSniff then
			status(name .. " | Farejar " .. a .. "/" .. b)
			if not r.actions.sniff() then return end
			nextSniff = os.clock() + (Constants.SniffCooldown or 15) + 1
			pause(3.2)
		end

	end
	return m
end