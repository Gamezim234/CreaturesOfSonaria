-- Executa a missao da lama com apoio no solo e tecla E mantida.
return function(r)
	local state, UIS, Client = r.state, r.UIS, r.Client
	local status, active, pause, focus = r.status, r.active, r.pause, r.focus
	local progress, stopHover = r.progress, r.stopHover

	local Tags, Constants, failures = r.Tags, r.Constants, r.failures
	local m = {kind="ConcealScent",tag="Mud"}
	function m.perform(name,object,duration,before,resource)
		local kind = m.kind

		-- A interacao so aparece quando a criatura esta apoiada sobre a lama.
		local ready = false
		local deadline = os.clock() + 8
		while active() and os.clock() < deadline do
			local character = Client:GetCurrentCharacter()
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = Tags:GetTagged("Mud")
			local hit = workspace:Raycast(character.Root.Position + Vector3.new(0, 10, 0), Vector3.new(0, -200, 0), params)
			if character.IsGrounded and hit and (hit.Instance == object or hit.Instance:IsDescendantOf(object)) then
				ready = true
				break
			end
			if not pause(0.1) then return false end
		end
		if not ready then
			status(name .. " | Lama: personagem ainda nao esta apoiado sobre a poca")
			failures[object] = os.clock() + 15
			return false
		end
		if not pause(0.5) or not focus() then return false end
		-- Segurar continuamente; nunca soltar entre quadros.
		status(name .. " | Lama: segurando E ate concluir a rolagem")
		state.heldKey = 0x45
		keypress(0x45)
		local holdDeadline = os.clock() + math.max(12, (Constants.MUD_ROLL_DURATION or 5) + 5)
		repeat
			task.wait(0.1)
		until not active() or not isrbxactive() or UIS:GetFocusedTextBox()
			or progress(name, kind) > before or os.clock() >= holdDeadline
		keyrelease(0x45)
		state.heldKey = nil
		-- Alguns estados so confirmam a rolagem depois de soltar E.
		local confirmDeadline = os.clock() + 3
		while active() and progress(name, kind) <= before and os.clock() < confirmDeadline do
			if not pause(0.1) then break end
		end
		if progress(name, kind) <= before then
			status(name .. " | Lama: tentativa sem progresso confirmado")
		end

		return nil
	end
	function m.run(name)
		local a,b=progress(name,m.kind)
		if a<b then
			local objects=r.sources(m.tag,name)
			if objects[1] then r.interact(name,m,objects[1],(Constants.MUD_ROLL_DURATION or 5)+1); return true end
		end
		return false
	end
	return m
end
