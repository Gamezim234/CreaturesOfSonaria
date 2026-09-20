-- Executa bebida e calcula sede para missao/sobrevivencia.
return function(r)
	local state,Client=r.state,r.Client
	local status,active,pause,focus=r.status,r.active,r.pause,r.focus
	local progress,stopHover=r.progress,r.stopHover
	local actions=r.actions

	local m={kind="EatFoodDrinkWater",tag="DrinkableWater",resource="Water"}

	local function ratio(value,capacity)
		if type(capacity)~="number" or capacity<=0 then return math.huge end
		return value/capacity
	end

	function m.prepare(snapshot)
		local c,slot=snapshot.character,snapshot.slot
		local water=slot and slot:FindFirstChild("Water")
		local capacity=c and c.CharacterData:GetWithModifiers("ThirstAppetite") or 0
		snapshot.waterValue=water and water.Value or capacity
		snapshot.waterCapacity=capacity
		snapshot.waterPct=c and not c.HasNoThirst and ratio(snapshot.waterValue,capacity) or math.huge
		snapshot.canDrink=c and not c.HasNoThirst and water and snapshot.waterValue<capacity-0.5 or false
		snapshot.criticalWater=snapshot.waterPct<=0.10
	end

	function m.destination(p,root,height,object)
		local surface=object and object:FindFirstChild("Surface",true)
		if not surface or not surface:IsA("BasePart") then return false end
		p=surface.Position
		local top=surface.CFrame:PointToWorldSpace(Vector3.new(0,surface.Size.Y/2,0))
		return Vector3.new(p.X,top.Y+root.Size.Y/2+0.3,p.Z),p
	end

	function m.afterMove(root,c)
		local hoverFrame=root.CFrame
		state.hover=game:GetService("RunService").Heartbeat:Connect(function()
			if not state.enabled or not state.running or not root.Parent or Client:GetCurrentCharacter()~=c then
				stopHover()
				return
			end
			root.CFrame=hoverFrame
			root.AssemblyLinearVelocity=Vector3.zero
			root.AssemblyAngularVelocity=Vector3.zero
		end)
	end

	function m.perform(name,object,duration,before,resource)
		status(name.." | Bebendo no centro do lago")
		if not focus() then stopHover();return false end
		local character=Client:GetCurrentCharacter()
		local capacity=character.CharacterData:GetWithModifiers("ThirstAppetite")

		if not actions.startDrink() then
			stopHover()
			return false
		end

		local deadline=os.clock()+duration
		repeat
			task.wait(0.1)
			local amount,target=progress(name,m.kind)
			if target>0 and amount>=target then break end
		until not active()
			or (resource and resource.Value>=capacity-0.1)
			or os.clock()>=deadline

		actions.stopEatDrink()
		stopHover()
		r.ensureLand(name)
		pause(0.5)
		return nil
	end

	function m.run(name,snapshot)
		if snapshot.needChoice~="water" then return false end
		for _,lake in ipairs(r.sources(m.tag,name)) do
			if lake:GetAttribute("CanDrink")~=false
				and not lake:GetAttribute("Sickly")
				and not lake:GetAttribute("IsPoisoned")
				and not lake:GetAttribute("CorruptedWater")
				and not lake:GetAttribute("FakeWater")
				and (lake:GetAttribute("Water") or 0)>0 then
				return r.interact(name,m,lake,8)==true
			end
		end
		return false
	end

	return m
end
