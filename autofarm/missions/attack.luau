-- Coordena a missao de ataque usando a posicao publicada pelas outras contas do grupo.
return function(r)
	local m={kind="AttackOrHealCreatureOrNPC",tag="AttackTarget"}

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

	function m.destination(p,root,_,targetInfo)
		local character=r.Client:GetCurrentCharacter()
		local head=character.Head
		local reach=head and math.abs(root.CFrame:PointToObjectSpace(head.Position).Z) or root.Size.Z/2
		local direction=Vector3.new(p.X-root.Position.X,0,p.Z-root.Position.Z)
		if direction.Magnitude<0.1 then
			direction=Vector3.new(0,0,-1)
		else
			direction=direction.Unit
		end
		local halfTarget=(targetInfo and targetInfo.sizeZ or 6)/2
		return p-direction*(reach+halfTarget+1),p
	end

	local function chooseTarget(name)
		local manual=r.state.attackTarget
		local best,bestDistance
		local own=r.Client:GetCurrentCharacter()
		local ownRoot=own and own.Root

		for _,member in ipairs(r.state.groupMembers or {}) do
			if type(member.userId)=="number" and member.userId~=r.player.UserId then
				if not manual or member.userId==manual then
					local p=vec3(member.position)
					if p and r.regionAt(p)==name then
						local distance=ownRoot and (p-ownRoot.Position).Magnitude or math.huge
						if not bestDistance or distance<bestDistance then
							best={
								id=member.userId,
								name=member.name,
								position=p,
								sizeZ=sizeZ(member),
							}
							bestDistance=distance
						end
					end
				end
			end
		end

		if manual and not best then
			for _,member in ipairs(r.state.groupMembers or {}) do
				if type(member.userId)=="number" and member.userId~=r.player.UserId then
					local p=vec3(member.position)
					if p and r.regionAt(p)==name then
						local distance=ownRoot and (p-ownRoot.Position).Magnitude or math.huge
						if not bestDistance or distance<bestDistance then
							best={
								id=member.userId,
								name=member.name,
								position=p,
								sizeZ=sizeZ(member),
							}
							bestDistance=distance
						end
					end
				end
			end
		end

		return best
	end

	function m.run(name)
		if not pending(name) then return false,false end

		local target=chooseTarget(name)
		if not target then
			r.status(name.." | Aguardando outra conta do grupo neste bioma para atacar")
			return false,true
		end

		if not r.focus() then return false,true end
		if not r.go(target.position,name,m.tag,{sizeZ=target.sizeZ}) then return false,true end
		if not r.active() or not pending(name) then return false,false end

		target=chooseTarget(name)
		local character=r.Client:GetCurrentCharacter()
		if not target or not character then return false,true end

		local head=character.Head or character.Root
		local maxDistance=target.sizeZ/2+head.Size.Magnitude/2+8
		if (head.Position-target.position).Magnitude>maxDistance then
			return false,true
		end

		r.status(name.." | Atacando "..(target.name or tostring(target.id)))
		if not r.actions.attack() then return false,true end
		local cooldown=character.CharacterData:GetWithModifiers("BiteCooldown")
		r.pause(math.max(type(cooldown)=="number" and cooldown or 1,0.5))
		return true,false
	end

	return m
end
