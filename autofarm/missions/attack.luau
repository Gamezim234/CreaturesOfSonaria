-- Usa cliques esquerdos no alvo selecionado somente durante a missao de ataque pendente.
return function(r)
	local m = {kind="AttackOrHealCreatureOrNPC", tag="AttackTarget"}
	local function pending(name)
		local amount,target=r.progress(name,m.kind)
		return amount < target
	end
	function m.destination(p,root,_,targetRoot)
		local character=r.Client:GetCurrentCharacter()
		local head=character.Head
		local reach=head and math.abs(root.CFrame:PointToObjectSpace(head.Position).Z) or root.Size.Z/2
		local direction=Vector3.new(p.X-root.Position.X,0,p.Z-root.Position.Z)
		if direction.Magnitude < 0.1 then direction=Vector3.new(0,0,-1) else direction=direction.Unit end
		return p-direction*(reach+targetRoot.Size.Z/2+1),p
	end
	function m.run(name)
		if not pending(name) then return false,false end
		local id=r.state.attackTarget
		local target=r.players.character(id)
		if not target or r.regionAt(target.Root.Position) ~= name then
			r.status(name .. " | Aguardando alvo de ataque vivo neste bioma")
			return false,true
		end
		if not r.focus() then return false,true end
		if not r.go(target.Root.Position,name,m.tag,target.Root) then return false,true end
		if not r.active() or r.state.attackTarget ~= id or not pending(name) or r.needsEmergency() then return false,false end
		target=r.players.character(id)
		local character=r.Client:GetCurrentCharacter()
		if not target or r.regionAt(target.Root.Position) ~= name then return false,true end
		local head=character.Head or character.Root
		if (head.Position-target.Root.Position).Magnitude > target.Root.Size.Magnitude/2+head.Size.Magnitude/2+5 then return false,true end
		-- Evitar uma mordida quando outro jogador tambem estiver ao alcance.
		for _,player in ipairs(game:GetService("Players"):GetPlayers()) do
			if player.UserId ~= id and player ~= r.player then
				local other=r.players.character(player.UserId)
				if other and (other.Root.Position-head.Position).Magnitude < other.Root.Size.Magnitude/2+head.Size.Magnitude/2+10 then
					r.status(name .. " | Aguardando outros jogadores se afastarem do alvo")
					return false,true
				end
			end
		end
		if not isrbxactive() or r.UIS:GetFocusedTextBox() then return false,true end
		r.status(name .. " | Atacando " .. (r.state.attackTargetName or tostring(id)))
		mouse1click()
		local cooldown=character.CharacterData:GetWithModifiers("BiteCooldown")
		r.pause(math.max(type(cooldown)=="number" and cooldown or 1,0.5))
		return true,false
	end
	return m
end
