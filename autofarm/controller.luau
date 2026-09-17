-- Agenda as regioes e chama os modulos de missao na ordem original.
return function(ctx)
	return function()
		local r=ctx.import("autofarm/region.luau")(ctx)
		local missions={}
		for key,file in pairs({water="water",food="food",mud="mud",sniff="sniff",walk="walk",shoom="shoom_piles_mission"}) do
			local mission=ctx.import("autofarm/missions/"..file..".luau")(r)
			missions[key]=mission
			if mission.tag then r.missions[mission.tag]=mission end
		end
		local active,pending,status,focus,pause,progress=r.active,r.pending,r.status,r.focus,r.pause,r.progress
		local names,kinds,Client=r.names,r.kinds,r.Client
		local retryAt={}
		while active() do
			local worked = false
			for _, name in ipairs(names) do
				if not active() then break end
				if not pending(name) or (retryAt[name] or 0) > os.clock() then continue end
				worked = true
				status("Entrando em " .. name)
				local arrived = r.enter(name)
				if not arrived then retryAt[name] = os.clock() + 120; continue end
				local lastProgress = os.clock()
				local lastSignature = ""
				while active() and pending(name) do
					if not focus() then break end
					local signature = {}
					for _, kind in ipairs(kinds) do table.insert(signature, tostring(progress(name, kind))) end
					local sig = table.concat(signature, ",")
					if sig ~= lastSignature then lastProgress = os.clock(); lastSignature = sig end
					local snapshot: any={character=Client:GetCurrentCharacter(),slot=Client:GetCurrentSlot()}
					missions.sniff.run(name)
					snapshot.amount,snapshot.target=progress(name,missions.food.kind)
					missions.water.prepare(snapshot)
					missions.food.prepare(name,snapshot)
					local waitingNeeds=snapshot.waitingNeeds
					local attempted=missions.water.run(name,snapshot)
					attempted=missions.food.run(name,snapshot) or attempted
					if not attempted then
						attempted=missions.shoom.run(name) or attempted
						attempted=missions.mud.run(name) or attempted
					end
					missions.walk.run(name,snapshot,attempted)
					if waitingNeeds then
						status(name .. " | Aguardando fome/sede; demais missoes continuam")
					elseif not attempted then status(name .. " | Aguardando intervalo ou recurso disponivel") end
					-- Fome/sede podem demorar: nao tratar essa espera como falha.
					if not waitingNeeds and os.clock() - lastProgress > 180 then
						status(name .. " | Sem progresso por 3 min; nova tentativa em 2 min")
						retryAt[name] = os.clock() + 120
						break
					end
					pause(1)
				end
			end
			if not worked then status("Aguardando renovacao das missoes ou nova tentativa (ataque ignorado)") end
			pause(5)
		end
	end
end
