-- Executa a coleta de cogumelos que pertence as missoes regionais.
return function(r)
	local m={kind="ShoomPilesCollected",tag="ShoomPile"}
	function m.perform(name,object,duration,before,resource)
		r.press(0x45,duration)
		r.pause(1)
	end
	function m.run(name)
		local a,b=r.progress(name,m.kind)
		if a<b then
			local objects=r.sources(m.tag,name)
			if objects[1] then r.interact(name,m,objects[1],1.2); return true end
		end
		return false
	end
	return m
end
