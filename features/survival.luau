-- Mantem a criatura viva: restart sem revive token, recuperacao e resposta a perigos.
return function(ctx)
	local ReplicatedStorage=game:GetService("ReplicatedStorage")
	local player=ctx.player
	local state=ctx.state
	local actions=ctx.actions
	local sonarModule=ReplicatedStorage:FindFirstChild("Sonar") :: any
	assert(sonarModule,"Sonar nao encontrado")
	local Sonar=require(sonarModule)
	local Client=Sonar("PlayerWrapper").GetClient()
	local RegionUtils=Sonar("RegionUtils")
	local api:any={}

	local lastSlotName
	local lastReadyAt=os.clock()
	local lastLifeCharacter
	local lastHealth
	local lastDamageAt=-math.huge
	local lastShelterAt=-math.huge
	local restartBusy=false

	local RECOVER_ENTER=0.98
	local RECOVER_EXIT=0.98
	local TARGET_STABLE_SECONDS=2.5

	local recoveryWords={
		"bleed","injur","fract","broken","ligament","poison","necro","burn","erosion",
		"radiat","frost","hypother","disease","sick","wound","shock","infect",
	}
	local tornadoWords={"tornado","twister","whirl","windtrap","wind_trap"}

	local function status(message)
		if state.status~=message then
			state.status=message
			print("[Survival] "..message)
		end
	end

	local function cleanup()
		pcall(actions.stopMovement)
		pcall(actions.setSprint,false)
		pcall(actions.stopEatDrink)
		pcall(ctx.stopHover)
	end

	local function characterAndSlot()
		local c,slot
		pcall(function() c=Client:GetCurrentCharacter() end)
		pcall(function() slot=Client:GetCurrentSlot() end)
		if slot and slot.Name then lastSlotName=slot.Name end
		return c,slot
	end

	local function healthData(c,slot)
		local health=slot and slot:FindFirstChild("Health")
		local value=health and health.Value
		local maximum
		if c and c.CharacterData then
			pcall(function() maximum=c.CharacterData:GetWithModifiers("Health") end)
			if type(maximum)~="number" or maximum<=0 then
				pcall(function() maximum=c.CharacterData:Get("Health") end)
			end
		end
		local model=c and c.Model or player.Character
		local data=model and model:FindFirstChild("Data")
		if (type(maximum)~="number" or maximum<=0) and data then
			maximum=data:GetAttribute("mh") or data:GetAttribute("MaxHealth")
		end
		if type(value)~="number" then return nil,nil,nil end
		if type(maximum)~="number" or maximum<=0 then maximum=math.max(value,1) end
		return value,maximum,math.clamp(value/maximum,0,1)
	end

	local function resourceCritical(c,slot)
		if not c or not slot then return false end
		local food=slot:FindFirstChild("Food")
		local water=slot:FindFirstChild("Water")
		local appetite,thirst
		pcall(function() appetite=c.CharacterData:GetWithModifiers("Appetite") end)
		pcall(function() thirst=c.CharacterData:GetWithModifiers("ThirstAppetite") end)
		local foodCritical=not c.HasNoHunger and food and type(appetite)=="number" and appetite>0 and food.Value/appetite<=0.10
		local waterCritical=not c.HasNoThirst and water and type(thirst)=="number" and thirst>0 and water.Value/thirst<=0.10
		return foodCritical==true or waterCritical==true
	end

	local function activeAilments(c)
		local result={}
		local model=c and c.Model or player.Character
		local folder=model and model:FindFirstChild("Ailments")
		if folder then
			for name,value in pairs(folder:GetAttributes()) do
				if value==true or (type(value)=="number" and value>0) then
					result[string.lower(name)]=value
				end
			end
		end
		return result
	end

	local function containsWord(map,words)
		for name in pairs(map) do
			for _,word in ipairs(words) do
				if string.find(name,word,1,true) then return true,name end
			end
		end
		return false,nil
	end

	local function recoveryAilment(c)
		local map=activeAilments(c)
		return containsWord(map,recoveryWords)
	end

	local function tornadoCaught(c)
		if not c then return false end
		if c._isBeingFlung==true or c.TornadoActive==true then return true end
		local map=activeAilments(c)
		local caught=containsWord(map,tornadoWords)
		return caught==true
	end

	local function isReady()
		local c,slot=characterAndSlot()
		local value=healthData(c,slot)
		local ready=c and c.Root and c.Root.Parent and slot and type(value)=="number" and value>0
		if ready then lastReadyAt=os.clock() end
		return ready==true,c,slot
	end

	local function confirmedDead(c,slot)
		local value=healthData(c,slot)
		if type(value)=="number" and value<=0 then return true end
		local gui=player:FindFirstChildOfClass("PlayerGui")
		local deathGui=gui and gui:FindFirstChild("DeathGui")
		if deathGui and deathGui:IsA("ScreenGui") and deathGui.Enabled then return true end
		return false
	end

	local function restartSlot(slotName)
		cleanup()
		status("Morreu | Reiniciando como filhote...")
		state.survivalBusy=true
		state.recovering=false

		pcall(function()
			local remote=ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("ClaimDeathRewardsRemote")
			if remote then remote:InvokeServer() end
		end)
		pcall(function()
			local folder=ReplicatedStorage:FindFirstChild("_replicationFolder")
			local death=folder and folder:FindFirstChild("DeathClient")
			if death then
				local module=require(death)
				if type(module.Close)=="function" then module.Close() end
			end
		end)

		local ok,result=pcall(function()
			local remote=ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RestartSlotRemote")
			return remote:InvokeServer(slotName,false)
		end)
		if not ok or not result then return false end

		task.wait(0.5)
		local respawned=false
		pcall(function()
			local folder=ReplicatedStorage:WaitForChild("_replicationFolder")
			local selectionModule=folder:FindFirstChild("SaveSelectionClient") :: any
			if not selectionModule then return end
			local selection=require(selectionModule)
			selection.Respawn(slotName)
			respawned=true
		end)
		return respawned
	end

	function api.ensureReady()
		if not state.enabled or not state.running then return false end
		while state.enabled and state.running do
			local ready,c,slot=isReady()
			if ready then
				if lastLifeCharacter~=c then
					lastLifeCharacter=c
					lastHealth=nil
				end
				if not state.recovering then state.survivalBusy=false end
				return true
			end

			if not confirmedDead(c,slot) then
				status("Aguardando personagem/slot ficar pronto")
				task.wait(0.25)
				continue
			end

			if restartBusy then
				task.wait(0.2)
				continue
			end
			restartBusy=true
			local slotName=(slot and slot.Name) or lastSlotName
			if not slotName then
				status("Morte detectada | aguardando slot atual")
				restartBusy=false
				task.wait(1)
				continue
			end

			local oldCharacter=lastLifeCharacter or c
			local ok=restartSlot(slotName)
			if not ok then
				status("Falha ao reiniciar slot; tentando novamente")
				restartBusy=false
				task.wait(2)
				continue
			end

			local deadline=os.clock()+30
			repeat
				task.wait(0.25)
				local newReady,newCharacter,newSlot=isReady()
				if newReady and (not oldCharacter or newCharacter~=oldCharacter) then
					lastLifeCharacter=newCharacter
					lastSlotName=newSlot and newSlot.Name or slotName
					restartBusy=false
					state.survivalBusy=false
					state.recovering=false
					lastHealth=nil
					status("Respawn concluido | retomando autofarm")
					task.wait(1.5)
					return true
				end
			until os.clock()>deadline or not state.enabled or not state.running

			restartBusy=false
			status("Respawn nao confirmou; tentando novamente")
			task.wait(2)
		end
		return false
	end

	local function groundAndRoof(point,regionName)
		local params=RaycastParams.new()
		params.FilterType=Enum.RaycastFilterType.Include
		local env=workspace:FindFirstChild("Environment")
		params.FilterDescendantsInstances=env and {workspace.Terrain,env} or {workspace.Terrain}
		params.IgnoreWater=false
		local down=workspace:Raycast(point+Vector3.new(0,220,0),Vector3.new(0,-500,0),params)
		if not down or down.Material==Enum.Material.Water then return nil end
		local ground=down.Position
		if RegionUtils.getRegionFromPosition(ground+Vector3.new(0,10,0))~=regionName then return nil end
		local up=workspace:Raycast(ground+Vector3.new(0,4,0),Vector3.new(0,70,0),params)
		if not up or up.Distance<6 then return nil end
		return ground
	end

	local function seekShelter(c)
		if not c or not c.Root or os.clock()-lastShelterAt<5 then return false end
		lastShelterAt=os.clock()
		local root=c.Root
		local regionName=RegionUtils.getRegionFromPosition(root.Position+Vector3.new(0,10,0))
		if not regionName then return false end
		for _,radius in ipairs({25,50,90,140,200}) do
			for step=1,10 do
				local angle=(step/10)*math.pi*2
				local point=root.Position+Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius)
				local ground=groundAndRoof(point,regionName)
				if ground then
					local height=root.Size.Y/2+2
					root.CFrame=CFrame.new(ground+Vector3.new(0,height,0))
					root.AssemblyLinearVelocity=Vector3.zero
					root.AssemblyAngularVelocity=Vector3.zero
					return true
				end
			end
		end
		return false
	end

	local function escapeTornado()
		state.survivalBusy=true
		state.recovering=true
		cleanup()
		status("Tornado | escapando...")

		local deadline=os.clock()+7
		repeat
			local c=Client:GetCurrentCharacter()
			if not c then break end
			if c._isBeingFlung==true then
				-- Equivale a concluir o "Click to escape!" do fluxo local do tornado.
				c._tornadoFlingCancelled=true
			end
			seekShelter(c)
			if not tornadoCaught(c) then break end
			task.wait(0.15)
		until os.clock()>deadline or not state.running or not state.enabled
	end

	local function recover(c,slot)
		state.survivalBusy=true
		state.recovering=true
		cleanup()
		status("Recuperando vida/debuffs")
		seekShelter(c)
		actions.setLaying(true)

		local stableSince=nil
		local previousHealth=select(1,healthData(c,slot))
		local deadline=os.clock()+90
		repeat
			task.wait(0.25)
			if not state.enabled or not state.running then break end
			if not api.ensureReady() then break end
			c,slot=characterAndSlot()
			local currentHealth,_,ratio=healthData(c,slot)
			if type(previousHealth)=="number" and type(currentHealth)=="number" and currentHealth<previousHealth then
				lastDamageAt=os.clock()
			end
			previousHealth=currentHealth
			local bad=recoveryAilment(c)
			if resourceCritical(c,slot) then break end
			if ratio and ratio>=RECOVER_EXIT and not bad then
				stableSince=stableSince or os.clock()
				if os.clock()-stableSince>=TARGET_STABLE_SECONDS then break end
			else
				stableSince=nil
			end
			if os.clock()-lastDamageAt<2 and c then seekShelter(c) end
		until os.clock()>deadline

		actions.setLaying(false)
		state.recovering=false
		state.survivalBusy=false
		status("Recuperacao concluida | retomando missoes")
		task.wait(0.5)
	end

	function api.handle()
		if not api.ensureReady() then return false end
		local c,slot=characterAndSlot()
		local value,_,ratio=healthData(c,slot)
		if not value or not ratio then return false end

		if c~=lastLifeCharacter then
			lastLifeCharacter=c
			lastHealth=value
		end
		if type(lastHealth)=="number" and value<lastHealth then lastDamageAt=os.clock() end
		lastHealth=value

		if tornadoCaught(c) then
			escapeTornado()
			recover(c,slot)
			return true
		end

		if resourceCritical(c,slot) then
			state.recovering=false
			state.survivalBusy=false
			return false
		end

		local bad=recoveryAilment(c)
		local recentlyHit=os.clock()-lastDamageAt<2.5 and ratio<RECOVER_ENTER
		if bad or ratio<0.82 or recentlyHit then
			recover(c,slot)
			return true
		end

		state.recovering=false
		state.survivalBusy=false
		return false
	end

	function api.snapshot()
		local c,slot=characterAndSlot()
		local value,maximum,ratio=healthData(c,slot)
		return {
			character=c,
			slot=slot,
			health=value,
			maxHealth=maximum,
			healthPct=ratio,
			alive=c~=nil and c.Root~=nil and c.Root.Parent~=nil and type(value)=="number" and value>0,
			ailments=activeAilments(c),
		}
	end

	return api
end
