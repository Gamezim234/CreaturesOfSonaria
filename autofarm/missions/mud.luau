-- Executa a missao da lama pela acao interna Hide Scent do proprio jogo.
return function(r)
	local Client=r.Client
	local status,active,pause,focus=r.status,r.active,r.pause,r.focus
	local progress=r.progress
	local Tags,Constants,failures=r.Tags,r.Constants,r.failures
	local m={kind="ConcealScent",tag="Mud"}

	function m.perform(name,object,duration,before,resource)
		local kind=m.kind

		-- A acao Hide Scent so deve ser disparada quando a criatura esta realmente apoiada na lama.
		local ready=false
		local deadline=os.clock()+8
		while active() and os.clock()<deadline do
			local character=Client:GetCurrentCharacter()
			local params=RaycastParams.new()
			params.FilterType=Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances=Tags:GetTagged("Mud")
			local hit=workspace:Raycast(
				character.Root.Position+Vector3.new(0,10,0),
				Vector3.new(0,-200,0),
				params
			)
			if character.IsGrounded and hit
				and (hit.Instance==object or hit.Instance:IsDescendantOf(object)) then
				ready=true
				break
			end
			if not pause(0.1) then return false end
		end

		if not ready then
			status(name.." | Lama: personagem ainda nao esta apoiado sobre a poca")
			failures[object]=os.clock()+15
			return false
		end

		if not pause(0.5) or not focus() then return false end
		status(name.." | Lama: executando Hide Scent")

		-- Roll("Mud") sozinho anima a rolagem, mas nao executa toda a
		-- acao que o jogo usa para confirmar ConcealScent no servidor.
		if not r.actions.hideScent(object) then
			status(name.." | Lama: acao Hide Scent nao encontrada")
			failures[object]=os.clock()+15
			return false
		end

		local confirmDeadline=os.clock()+4
		while active() and progress(name,kind)<=before and os.clock()<confirmDeadline do
			if not pause(0.1) then break end
		end

		if progress(name,kind)<=before then
			status(name.." | Lama: rolagem terminou, mas a missao nao confirmou progresso")
			failures[object]=os.clock()+15
		end

		return nil
	end

	function m.run(name)
		local a,b=progress(name,m.kind)
		if a<b then
			local objects=r.sources(m.tag,name)
			if objects[1] then
				r.interact(name,m,objects[1],(Constants.MUD_ROLL_DURATION or 5)+1)
				return true
			end
		end
		return false
	end

	return m
end
