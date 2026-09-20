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

		local function refreshGroup(current)
			-- Fome/sede nunca mudam o bioma do grupo. Sao resolvidas localmente.
			sync.update(pendingMap(),current,nil)
			local target,members=sync.chooseBiome()
			sync.setTarget(target)
			state.groupMembers=members
			state.groupTarget=target
			return target,members
		end

		local function groupLabel(members)
			local count=#members
			return tostring(count)..(count==1 and " conta" or " contas")
		end

		local function prepareNeeds(name)
			local snapshot:any={
				character=Client:GetCurrentCharacter(),
				slot=Client:GetCurrentSlot(),
			}
			snapshot.amount,snapshot.target=progress(name,missions.food.kind)
			missions.water.prepare(snapshot)
			missions.food.prepare(name,snapshot)
			return snapshot
		end

		local function runNeeds(name,snapshot)
			local attempted=missions.water.run(name,snapshot)
			attempted=missions.food.run(name,snapshot) or attempted
			return attempted
		end

		do
			local current=r.regionAt(Client:GetCurrentCharacter().Root.Position)
			sync.update(pendingMap(),current,nil)
			status("Sincronizando autofarm em grupo...")
			pause(1)
		end

		while active() do
			local current=r.regionAt(Client:GetCurrentCharacter().Root.Position)
			local target,members=refreshGroup(current)

			if not target then
				-- Mesmo sem missoes, a criatura ainda precisa sobreviver.
				local snapshot=prepareNeeds(current)
				if snapshot.critical then
					if not runNeeds(current,snapshot) then
						status(current.." | Necessidade critica: sem comida/agua utilizavel neste bioma")
						pause(0.5)
					end
				else
					status("Grupo sem missoes pendentes | "..groupLabel(members))
					pause(5)
				end
				continue
			end

			if current~=target then
				status("Grupo indo para "..target.." | "..groupLabel(members))
				if not r.enter(target) then
					status(target.." | Falha ao entrar; grupo tentara novamente")
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
				if groupTarget~=target then break end

				if current~=target then
					status("Voltando ao bioma do grupo: "..target)
					break
				end

				if not focus() then break end

				local snapshot=prepareNeeds(target)
				local attempted=runNeeds(target,snapshot)

				-- Abaixo de 10% comida/agua tem prioridade absoluta, mas a conta
				-- continua no mesmo bioma do grupo.
				if snapshot.critical then
					if not attempted then
						status(target.." | Necessidade critica: procurando comida/agua no bioma atual")
					end
					pause(0.5)
					continue
				end

				if not pending(target) then
					status(target.." | Minhas missoes prontas; aguardando grupo | "..groupLabel(currentMembers))
					pause(1)
					continue
				end

				local signature={}
				for _,kind in ipairs(kinds) do
					local a,b=progress(target,kind)
					table.insert(signature,tostring(a).."/"..tostring(b))
				end
				local sig=table.concat(signature,",")
				if sig~=lastSignature then
					lastProgress=os.clock()
					lastSignature=sig
				end

				if not attempted then
					missions.sniff.run(target)
				end

				local waitingNeeds=snapshot.waitingNeeds
				local waitingAttack=false
				if not attempted then
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
					status(target.." | Aguardando fome/sede cair; demais missoes continuam")
				elseif not attempted and not waitingAttack then
					status(target.." | Aguardando intervalo ou recurso disponivel")
				end

				if not waitingNeeds and not waitingAttack and os.clock()-lastProgress>180 then
					status(target.." | Sem progresso por 3 min; permanecendo com o grupo")
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
