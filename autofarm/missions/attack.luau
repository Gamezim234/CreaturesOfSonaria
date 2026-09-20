-- Coordena ataques seguros: um atacante por vez, alvo vivo e recuperado, vida atualizada a cada mordida.
return function(r)
	local m={kind="AttackOrHealCreatureOrNPC",tag="AttackTarget"}
	local SAFE_TARGET_HEALTH=0.96
	local SAFE_SELF_HEALTH=0.90
	local MIN_TARGET_AGE=33

	local recoveryWords={"bleed","injur","fract","broken","ligament","poison","necro","burn","erosion","radiat","frost","hypother","disease","wound","shock"}

	local function pending(name)
		local amount,target=r.progress(name,m.kind)
		return amount<target
	end

	local function vec3(data)
		if type(data)~="table" then return nil end
		if type(data.x)~="number" or type(data.y)~="number" or type(data.z)~="number" then return nil end
		return Vector3.new(data.x,data.y,data.z)
	end

	local function sizeZ(member)
		local size=member and member.rootSize
		return type(size)=="table" and type(size.z)=="number" and size.z or 6
	end

	local function hasRecoveryAilment(member)
		if type(member.ailments)~="table" then return false end
		for name,value in pairs(member.ailments) do
			if value==true or (type(value)=="number" and value>0) then
				local lower=string.lower(tostring(name))
				for _,word in ipairs(recoveryWords) do
					if string.find(lower,word,1,true) then return true end
				end
			end
		end
		return false
	end

	local function grownEnough(member)
		local age=member.age
		if type(age)~="number" then return true end
		if age>=0 and age<=1 then return age>=0.33 end
		return age>=MIN_TARGET_AGE
	end

	local function safeMember(member)
		if type(member)~="table" or member.userId==r.player.UserId then return false end
		if member.alive~=true or member.recovering==true then return false end
		if type(member.lifeId)~="string" or not vec3(member.position) then return false end
		if type(member.healthPct)=="number" and member.healthPct<SAFE_TARGET_HEALTH then return false end
		if not grownEnough(member) then return false end
		if hasRecoveryAilment(member) then return false end
		return true
	end

	local function ownMember()
		for _,member in ipairs(r.state.groupMembers or {}) do
			if member.userId==r.player.UserId then return member end
		end
		return nil
	end

	local function ownSafe()
		local member=ownMember()
		if member then
			if member.alive~=true or member.recovering==true then return false end
			if type(member.healthPct)=="number" and member.healthPct<SAFE_SELF_HEALTH then return false end
			if hasRecoveryAilment(member) then return false end
		end
		return not r.state.survivalBusy and not r.state.recovering
	end

	local function myTurn(name)
		local ownId=r.player.UserId
		local turn=ownId
		for _,member in ipairs(r.state.groupMembers or {}) do
			local map=member.attackPending
			if member.userId~=ownId and member.alive==true and member.recovering~=true
				and type(map)=="table" and map[name]==true and member.userId<turn then
				turn=member.userId
			end
		end
		return turn==ownId
	end

	local function damageLooksSafe(target)
		local own=ownMember()
		if not own or type(own.damage)~="number" or type(target.health)~="number" then return true end
		return own.damage<=target.health*0.15
	end

	function m.destination(p,root,_,targetInfo)
		local character=r.Client:GetCurrentCharacter()
		local head=character and character.Head
		local reach=head and math.abs(root.CFrame:PointToObjectSpace(head.Position).Z) or root.Size.Z/2
		local direction=Vector3.new(p.X-root.Position.X,0,p.Z-root.Position.Z)
		if direction.Magnitude<0.1 then direction=Vector3.new(0,0,-1) else direction=direction.Unit end
		local halfTarget=(targetInfo and targetInfo.sizeZ or 6)/2
		return p-direction*(reach+halfTarget+1),p
	end

	local function chooseTarget(name)
		local manual=r.state.attackTarget
		local best,bestDistance
		local own=r.Client:GetCurrentCharacter()
		local ownRoot=own and own.Root

		local function consider(member,manualOnly)
			if manualOnly and member.userId~=manual then return end
			if not safeMember(member) or not damageLooksSafe(member) then return end
			local p=vec3(member.position)
			if not p or r.regionAt(p)~=name then return end
			local distance=ownRoot and (p-ownRoot.Position).Magnitude or math.huge
			if not bestDistance or distance<bestDistance then
				best={id=member.userId,name=member.name,position=p,sizeZ=sizeZ(member),lifeId=member.lifeId,healthPct=member.healthPct}
				bestDistance=distance
			end
		end

		if manual then
			for _,member in ipairs(r.state.groupMembers or {}) do consider(member,true) end
		end
		if not best then
			for _,member in ipairs(r.state.groupMembers or {}) do consider(member,false) end
		end
		return best
	end

	function m.run(name)
		if not pending(name) then return false,false end
		if not ownSafe() then
			r.status(name.." | Ataque pausado: esta conta precisa recuperar")
			return false,true
		end
		if not myTurn(name) then
			r.status(name.." | Ataque: aguardando a vez da outra conta")
			return false,true
		end

		local target=chooseTarget(name)
		if not target then
			r.status(name.." | Ataque: aguardando alvo adulto/saudavel no grupo")
			return false,true
		end

		if not r.focus() then return false,true end
		if not r.go(target.position,name,m.tag,{sizeZ=target.sizeZ}) then return false,true end
		if not r.active() or not pending(name) or not ownSafe() then return false,false end

		local refreshed=chooseTarget(name)
		local character=r.Client:GetCurrentCharacter()
		if not refreshed or not character or refreshed.id~=target.id or refreshed.lifeId~=target.lifeId then
			r.status(name.." | Ataque cancelado: alvo mudou/respawnou")
			return false,true
		end

		local head=character.Head or character.Root
		local maxDistance=refreshed.sizeZ/2+head.Size.Magnitude/2+8
		if (head.Position-refreshed.position).Magnitude>maxDistance then return false,true end

		r.status(name.." | Mordida segura em "..(refreshed.name or tostring(refreshed.id)))
		if not r.actions.attack() then return false,true end
		local cooldown=character.CharacterData:GetWithModifiers("BiteCooldown")
		r.pause(math.max(type(cooldown)=="number" and cooldown or 1,1.4))
		return true,false
	end

	return m
end
