-- Mantem a criatura viva, reinicia o slot apos morte e coordena recuperacao.
return function(ctx)
	local ReplicatedStorage=game:GetService("ReplicatedStorage")
	local sonar=ReplicatedStorage:WaitForChild("Sonar")
	local Wrapper=require(sonar)("PlayerWrapper")
	local Client=Wrapper.GetClient()
	local state=ctx.state
	local api={}
	local lifeId=0
	local currentCharacter=nil
	local spawnedAt=0
	local lastSlotName=nil
	local restarting=false
	local resting=false
	local acuteWords={"bleed","injury","wound","burn","poison","frostbite","hypothermia","shock","corrosion","necropoison"}

	local function aliveValue(value)
		return value==true or (type(value)=="number" and value>0)
	end

	local function getCharacter()
		local ok,c=pcall(function() return Client:GetCurrentCharacter() end)
		return ok and c or nil
	end

	local function getSlot()
		local ok,slot=pcall(function() return Client:GetCurrentSlot() end)
		if ok and slot then
			lastSlotName=slot.Name
			return slot
		end
		return nil
	end

	local function maxHealth(character,currentHealth)
		local result
		if character and character.CharacterData then
			pcall(function() result=character.CharacterData:GetWithModifiers("Health") end)
			if type(result)~="number" or result<=0 then
				pcall(function() result=character.CharacterData:Get("Health") end)
			end
		end
		if type(result)~="number" or result<=0 then result=currentHealth end
		if type(result)~="number" or result<=0 then result=1 end
		if type(currentHealth)=="number" and currentHealth>result then result=currentHealth end
		return result
	end

	local function collectAilments(character)
		local found={}
		local model=character and (character.Model or ctx.player.Character)
		local folder=model and model:FindFirstChild("Ailments")
		if folder then
			for key,value in pairs(folder:GetAttributes()) do
				if aliveValue(value) then found[string.lower(tostring(key))]=value end
			end
		end
		if character and character.CharacterData and type(character.CharacterData.HasAilment)=="function" then
			for _,name in ipairs({"Bleed","Injury","Burn","Poison","Frostbite","Hypothermia","Shock","Corrosion","Necropoison","SpawnImmunity"}) do
				local ok,value=pcall(character.CharacterData.HasAilment,character.CharacterData,name)
				if ok and aliveValue(value) then found[string.lower(name)]=value end
			end
		end
		return found
	end

	local function hasAcute(ailments)
		for name,value in pairs(ailments or {}) do
			if aliveValue(value) then
				for _,word in ipairs(acuteWords) do
					if string.find(name,word,1,true) then return true,name end
				end
			end
		end
		return false,nil
	end

	local function hasWordInAttributes(instance,word)
		if not instance then return false end
		for key,value in pairs(instance:GetAttributes()) do
			if aliveValue(value) and string.find(string.lower(tostring(key)),word,1,true) then return true end
		end
		return false
	end

	function api.snapshot()
		local character=getCharacter()
		local slot=getSlot()
		local root=character and character.Root
		local healthObject=slot and slot:FindFirstChild("Health")
		local health=healthObject and healthObject.Value or 0
		local alive=character~=nil and root~=nil and root.Parent~=nil and health>0

		if alive and character~=currentCharacter then
			currentCharacter=character
			lifeId=lifeId+1
			spawnedAt=os.clock()
			resting=false
		elseif not alive and character==currentCharacter then
			currentCharacter=nil
		end

		local maximum=maxHealth(character,health)
		local ailments=collectAilments(character)
		local acute,acuteName=hasAcute(ailments)
		local model=character and (character.Model or ctx.player.Character)
		local tornado=hasWordInAttributes(model,"tornado")
			or hasWordInAttributes(model,"hurricane")
			or ailments.tornado~=nil
			or ailments.hurricane~=nil
		local spawnProtected=(os.clock()-spawnedAt)<10 or ailments.spawnimmunity~=nil

		return {
			alive=alive,
			character=character,
			slot=slot,
			slotName=slot and slot.Name or lastSlotName,
			health=health,
			maxHealth=maximum,
			healthPct=maximum>0 and health/maximum or 0,
			position=alive and root.Position or nil,
			rootSize=alive and root.Size or nil,
			lifeId=lifeId,
			spawnProtected=spawnProtected,
			recovering=state.recovering==true,
			ailments=ailments,
			acute=acute,
			acuteName=acuteName,
			tornado=tornado,
		}
	end

	function api.ensureReady(status)
		while state.enabled and state.running do
			local snapshot=api.snapshot()
			if snapshot.alive then return true,snapshot end
			ctx.actions.stopMovement()
			ctx.actions.setSprint(false)
			ctx.actions.stopEatDrink()
			ctx.stopHover()
			state.recovering=true
			if status then status("Morto | Reiniciando o slot como filhote") end

			if not restarting then
				restarting=true
				local slotName=snapshot.slotName or lastSlotName
				if slotName then ctx.actions.restartSlot(slotName) end
				restarting=false
			end

			local deadline=os.clock()+20
			repeat
				if not state.enabled or not state.running then return false,nil end
				task.wait(0.25)
				snapshot=api.snapshot()
				if snapshot.alive then
					state.recovering=false
					if status then status("Respawn concluido | Retomando autofarm") end
					return true,snapshot
				end
			until os.clock()>=deadline
			task.wait(1)
		end
		return false,nil
	end

	function api.needsRecovery(snapshot)
		snapshot=snapshot or api.snapshot()
		if not snapshot.alive then return true end
		return snapshot.healthPct<0.82 or snapshot.acute==true
	end

	function api.handle(status)
		local ok,snapshot=api.ensureReady(status)
		if not ok then return false,true end

		if snapshot.tornado then
			ctx.actions.stopMovement()
			ctx.actions.setSprint(false)
			if status then status("Preso por vento/tornado | Tentando escapar") end
			local deadline=os.clock()+4
			repeat
				ctx.actions.attack()
				task.wait(0.12)
				snapshot=api.snapshot()
			until not snapshot.alive or not snapshot.tornado or os.clock()>=deadline
			return true,false
		end

		if not api.needsRecovery(snapshot) then
			if resting then
				ctx.actions.setResting(false)
				resting=false
			end
			state.recovering=false
			return false,false
		end

		state.recovering=true
		ctx.actions.stopMovement()
		ctx.actions.setSprint(false)
		ctx.actions.stopEatDrink()
		ctx.stopHover()
		if status then
			status("Recuperando | HP "..math.floor(snapshot.healthPct*100).."%"
				..(snapshot.acuteName and (" | "..snapshot.acuteName) or ""))
		end
		if not resting then resting=ctx.actions.setResting(true) end

		local deadline=os.clock()+25
		repeat
			if not state.enabled or not state.running then break end
			task.wait(0.25)
			snapshot=api.snapshot()
			if not snapshot.alive then
				if resting then ctx.actions.setResting(false); resting=false end
				local ready=api.ensureReady(status)
				state.recovering=false
				return true,not ready
			end
		until (snapshot.healthPct>=0.95 and not snapshot.acute) or os.clock()>=deadline

		if resting then
			ctx.actions.setResting(false)
			resting=false
		end
		state.recovering=false
		return true,false
	end

	function api.reset()
		state.recovering=false
		if resting then
			ctx.actions.setResting(false)
			resting=false
		end
	end

	return api
end
