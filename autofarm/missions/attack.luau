-- Usa o ataque normal; alvo manual e opcional, com fallback automatico para outra conta do grupo.
return function(r)
	local m={kind="AttackOrHealCreatureOrNPC",tag="AttackTarget"}

	local function pending(name)
		local amount,target=r.progress(name,m.kind)
		return amount<target
	end

	function m.destination(p,root,_,targetRoot)
		local character=r.Client:GetCurrentCharacter()
		local head=character.Head
		local reach=head and math.abs(root.CFrame:PointToObjectSpace(head.Position).Z) or root.Size.Z/2
		local direction=Vector3.new(p.X-root.Position.X,0,p.Z-root.Position.Z)
		if direction.Magnitude<0.1 then direction=Vector3.new(0,0,-1) else direction=direction.Unit end
		return p-direction*(reach+targetRoot.Size.Z/2+1),p
	end

	local function chooseTarget(name)
		local manual=r.state.attackTarget
		if manual then
			local target=r.players.character(manual)
			if target and r.regionAt(target.Root.Position)==name then
				local player=r.players.player(manual)
				return manual,target,player and player.Name or r.state.attackTargetName
			end
		end

		local own=r.Client:GetCurrentCharacter()
		local ownRoot=own and own.Root
		local bestId,bestTarget,bestName,bestDistance

		for _,member in ipairs(r.state.groupMembers or {}) do
			local id=member.userId
			if type(id)=="number" and id~=r.player.UserId then
				local target=r.players.character(id)
				if target and r.regionAt(target.Root.Position)==name then
					local distance=ownRoot and (target.Root.Position-ownRoot.Position).Magnitude or math.huge
					if not bestDistance or distance<bestDistance then
						bestId,bestTarget,bestName,bestDistance=id,target,member.name,distance
					end
				end
			end
		end

		return bestId,bestTarget,bestName
	end

	function m.run(name)
		if not pending(name) then return false,false end

		local id,target,targetName=chooseTarget(name)
		if not id or not target then
			r.status(name.." | Aguardando outra conta do grupo para a missao de ataque")
			return false,true
		end

		if not r.focus() then return false,true end
		if not r.go(target.Root.Position,name,m.tag,target.Root) then return false,true end
		if not r.active() or not pending(name) or r.needsEmergency() then return false,false end

		target=r.players.character(id)
		local character=r.Client:GetCurrentCharacter()
		if not target or r.regionAt(target.Root.Position)~=name then return false,true end

		local head=character.Head or character.Root
		if (head.Position-target.Root.Position).Magnitude>target.Root.Size.Magnitude/2+head.Size.Magnitude/2+5 then
			return false,true
		end

		-- Evitar uma mordida quando um terceiro jogador tambem estiver ao alcance.
		for _,player in ipairs(game:GetService("Players"):GetPlayers()) do
			if player.UserId~=id and player~=r.player then
				local other=r.players.character(player.UserId)
				if other and (other.Root.Position-head.Position).Magnitude<other.Root.Size.Magnitude/2+head.Size.Magnitude/2+10 then
					r.status(name.." | Aguardando outros jogadores se afastarem do alvo")
					return false,true
				end
			end
		end

		r.status(name.." | Atacando "..(targetName or tostring(id)))
		if not r.actions.attack() then return false,true end
		local cooldown=character.CharacterData:GetWithModifiers("BiteCooldown")
		r.pause(math.max(type(cooldown)=="number" and cooldown or 1,0.5))
		return true,false
	end

	return m
end
