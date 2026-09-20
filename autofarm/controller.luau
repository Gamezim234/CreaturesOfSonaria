-- Agenda as regioes e mantem todas as contas locais sincronizadas no mesmo bioma.
return function(ctx)
	return function()
		local r=ctx.import("autofarm/region.luau")(ctx)
		local missions={}
		for key,file in pairs({water="water",food="food",mud="mud",sniff="sniff",walk="walk",shoom="shoom_piles_mission",attack="attack"}) do
			local mission=ctx.import("autofarm/missions/"..file..".luau")(r)
			missions[key]=mission
			if mission.tag then r.missions[mission.tag]=mission end
		end

		local active,pending,status,focus,pause,progress=r.active,r.pending,r.status,r.focus,r.pause,r.progress
		local names,kinds,Client=r.names,r.kinds,r.Client
		local sync=ctx.groupSync
		local state=r.state

		local function pendingMap()
			local result={}
			for _,name in ipairs(names) do
				result[name]=pending(name)
			end
			return result
		end

		local function emergencyRegion(current)
			if not r.needsEmergency() then return nil end
			local amount,target=progress(current,missions.food.kind)
			if amount < target then return nil end

			local candidates={}
			for _,name in ipairs(names) do
				amount,target=progress(name,missions.food.kind)
				if name ~= current and amount < target then table.insert(candidates,name) end
			end
			table.sort(candidates)
			return candidates[1]
		end

		local function refreshGroup(current)
			local emergency=emergencyRegion(current)
			sync.update(pendingMap(),current,emergency)
			local target,members=sync.chooseBiome()
			sync.setTarget(target)
			state.groupMembers=members
			state.groupTarget=target
			return target,members,emergency
		end

		local function groupLabel(members)
			local count=#members
			return tostring(count) .. (count==1 and " conta" or " contas")
		end

		do
			local current=r.regionAt(Client:GetCurrentCharacter().Root.Position)
			sync.update(pendingMap(),current,emergencyRegion(current))
			status("Sincronizando autofarm em grupo...")
			pause(1)
		end

		while active() do
			local current=r.regionAt(Client:GetCurrentCharacter().Root.Position)
			local target,members,emergency=refreshGroup(current)

			if not target then
				status("Grupo sem missoes pendentes | " .. groupLabel(members))
				pause(5)
				continue
			end

			if current ~= target then
				if emergency then
					status("Emergencia do grupo: indo para " .. target .. " | " .. groupLabel(members))
				else
					status("Grupo indo para " .. target .. " | " .. groupLabel(members))
				end
				if not r.enter(target) then
					status(target .. " | Falha ao entrar; grupo tentara novamente")
					pause(5)
					continue
				end
				current=target
				refreshGroup(current)
			end

			local lastProgress=os.clock()
			local lastSignature=""

			while active() do
				current=r.regionAt(Client:GetCurrentCharacter().Root.Position)
				local groupTarget,currentMembers=refreshGroup(current)
				if groupTarget ~= target then break end

				if current ~= target then
					status("Voltando ao bioma do grupo: " .. target)
					break
				end

				if not pending(target) then
					status(target .. " | Minhas missoes prontas; aguardando grupo | " .. groupLabel(currentMembers))
					pause(1)
					continue
				end

				if not focus() then break end

				local signature={}
				for _,kind in ipairs(kinds) do
					local a,b=progress(target,kind)
					table.insert(signature,tostring(a).."/"..tostring(b))
				end
				local sig=table.concat(signature,",")
				if sig ~= lastSignature then
					lastProgress=os.clock()
					lastSignature=sig
				end

				local snapshot:any={character=Client:GetCurrentCharacter(),slot=Client:GetCurrentSlot()}
				if not r.needsEmergency() then missions.sniff.run(target) end
				snapshot.amount,snapshot.target=progress(target,missions.food.kind)
				missions.water.prepare(snapshot)
				missions.food.prepare(target,snapshot)
				local waitingNeeds=snapshot.waitingNeeds
				local attempted=missions.water.run(target,snapshot)
				attempted=missions.food.run(target,snapshot) or attempted

				local waitingAttack=false
				if not attempted and not r.needsEmergency() then
					local attacked
					attacked,waitingAttack=missions.attack.run(target)
					attempted=attacked or attempted
				end

				if not attempted then
					attempted=missions.shoom.run(target) or attempted
					attempted=missions.mud.run(target) or attempted
				end

				missions.walk.run(target,snapshot,attempted)

				if waitingNeeds then
					status(target .. " | Aguardando fome/sede; demais missoes continuam")
				elseif not attempted and not waitingAttack then
					status(target .. " | Aguardando intervalo ou recurso disponivel")
				end

				if not waitingNeeds and not waitingAttack and os.clock()-lastProgress>180 then
					status(target .. " | Sem progresso por 3 min; permanecendo com o grupo")
					lastProgress=os.clock()
					pause(5)
				else
					pause(1)
				end
			end

			pause(0.2)
		end
	end
end
