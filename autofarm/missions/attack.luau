-- Coordena a missao de ataque sem deixar as contas se matarem.
return function(r)
	local m={kind="AttackOrHealCreatureOrNPC",tag="AttackTarget"}
	local SAFE_TARGET_HP=0.90
	local MIN_TARGET_SIZE_RATIO=0.65

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

	local function members()
		if r.groupSync and type(r.groupSync.members)=="function" then
			local ok,result=pcall(r.groupSync.members)
			if ok and type(result)=="table" then
				r.state.groupMembers=result
				return result
			end
		end
		return r.state.groupMembers or {}
	end

	local function myTurn(name)
		local candidates={}
		for _,member in ipairs(members()) do
			if member.alive==true
				and member.recovering~=true
				and member.spawnProtected~=true
				and type(member.attackPending)=="table"
				and member.attackPending[name]==true then
				table.insert(candidates,member.userId)
			end
		end
		table.sort(candidates)
		return candidates[1]==r.player.UserId
	end

	local function eligibleTarget(member,name,ownSize)
		if type(member)~="table" or member.userId==r.player.UserId then return false end
		if member.alive~=true or member.recovering==true or member.spawnProtected==true then return false end
		if type(member.lifeId)~="number" then return false end
		if type(member.healthPct)~="number" or member.healthPct<SAFE_TARGET_HP then return false end
		local p=vec3(member.position)
		if not p or r.regionAt(p)~=name then return false end
		local targetSize=sizeZ(member)
		if ownSize and targetSize<ownSize*MIN_TARGET_SIZE_RATIO then return false end
		return true,p,targetSize
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
		local snapshot=r.survival.snapshot()
		local ownSize=snapshot.rootSize and snapshot.rootSize.Z or nil
		local manual=r.state.attackTarget
		local list=members()
		local function find(onlyManual)
			local best,bestDistance
			for _,member in ipairs(list) do
				if not onlyManual or member.userId==manual then
					local ok,p,targetSize=eligibleTarget(member,name,ownSize)
					if ok then
						local distance=snapshot.position and (p-snapshot.position).Magnitude or math.huge
						if not bestDistance or distance<bestDistance then
							best={
								id=member.userId,
								name=member.name,
								position=p,
								sizeZ=targetSize,
								lifeId=member.lifeId,
								healthPct=member.healthPct,
							}
							bestDistance=distance
						end
					end
				end
			end
			return best
		end
		if manual then
			local selected=find(true)
			if selected then return selected end
		end
		return find(false)
	end

	function m.run(name)
		if not pending(name) then return false,false end

		local own=r.survival.snapshot()
		if not own.alive or own.recovering or own.spawnProtected then
			return false,true
		end

		if not myTurn(name) then
			r.status(name.." | Ataque: aguardando turno de outra conta")
			return false,true
		end

		local target=chooseTarget(name)
		if not target then
			r.status(name.." | Ataque: aguardando alvo saudavel do grupo")
			return false,true
		end

		local targetId,targetLife=target.id,target.lifeId
		if not r.focus() then return false,true end
		if not r.go(target.position,name,m.tag,{sizeZ=target.sizeZ}) then return false,true end
		if not r.active() or not pending(name) then return false,false end

		target=chooseTarget(name)
		local character=r.Client:GetCurrentCharacter()
		if not target or target.id~=targetId or target.lifeId~=targetLife or not character then
			return false,true
		end
		if target.healthPct<SAFE_TARGET_HP then return false,true end

		local head=character.Head or character.Root
		local maxDistance=target.sizeZ/2+head.Size.Magnitude/2+8
		if (head.Position-target.position).Magnitude>maxDistance then return false,true end

		r.status(name.." | Atacando "..(target.name or tostring(target.id)).." | 1 mordida segura")
		if not r.actions.attack() then return false,true end
		local cooldown=character.CharacterData:GetWithModifiers("BiteCooldown")
		r.pause(math.max(type(cooldown)=="number" and cooldown or 1,0.5)+0.4)
		return true,false
	end

	return m
end
