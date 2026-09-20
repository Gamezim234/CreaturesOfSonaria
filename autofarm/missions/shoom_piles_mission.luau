-- Coleta ShoomPiles pela acao interna Collect, sem depender do foco da janela.
return function(r)
	local m={kind="ShoomPilesCollected",tag="ShoomPile"}

	function m.perform(name,object,duration,before,resource)
		r.status(name.." | Coletando ShoomPile")

		if not r.actions.collectShoomPile(object) then
			r.status(name.." | ShoomPile: acao Collect nao encontrada")
			return false
		end

		local deadline=os.clock()+3
		while r.active() and r.progress(name,m.kind)<=before and os.clock()<deadline do
			if not r.pause(0.1) then break end
		end

		return nil
	end

	function m.run(name)
		local a,b=r.progress(name,m.kind)
		if a<b then
			local objects=r.sources(m.tag,name)
			if objects[1] then
				r.interact(name,m,objects[1],1.2)
				return true
			end
		end
		return false
	end

	return m
end
