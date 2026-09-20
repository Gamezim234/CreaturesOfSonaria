-- Executa alimentacao e escolhe entre comida/agua pela porcentagem restante.
return function(r)
	local Client=r.Client
	local status,active,pause,focus=r.status,r.active,r.pause,r.focus
	local progress,stopHover=r.progress,r.stopHover
	local actions=r.actions
	local Constants,ground=r.Constants,r.ground

	local m={kind="EatFoodDrinkWater",tag="Food",resource="Food"}

	local function ratio(value,capacity)
		if type(capacity)~="number" or capacity<=0 then return math.huge end
		return value/capacity
	end

	local function foodCompatible(object,c)
		local d=Constants.FoodData[object:GetAttribute("FoodDataName") or object.Name]
		if not d or object:GetAttribute("Rotten") or object:GetAttribute("Held")
			or (object:GetAttribute("Value") or 0)<=0 then return false end
		return (d.Diet=="Herbivore" or d.Diet=="Omnivore")
			and (not d.AbilityRequirementToInteract or c.CharacterData:Get(d.AbilityRequirementToInteract))
	end

	local function chooseLower(snapshot,foodAllowed,waterAllowed)
		if foodAllowed and waterAllowed then
			return snapshot.foodPct<=snapshot.waterPct and "food" or "water"
		end
		if foodAllowed then return "food" end
		if waterAllowed then return "water" end
		return nil
	end

	function m.prepare(name,snapshot)
		local c,slot=snapshot.character,snapshot.slot
		local food=slot and slot:FindFirstChild("Food")
		local capacity=c and c.CharacterData:GetWithModifiers("Appetite") or 0
		snapshot.foodValue=food and food.Value or capacity
		snapshot.foodCapacity=capacity
		snapshot.foodPct=c and not c.HasNoHunger and ratio(snapshot.foodValue,capacity) or math.huge
		snapshot.canEat=c and not c.HasNoHunger and food and snapshot.foodValue<capacity-0.5 or false
		snapshot.criticalFood=snapshot.foodPct<=0.10
		snapshot.critical=snapshot.criticalFood or snapshot.criticalWater

		if snapshot.critical then
			snapshot.needMode="survival"
			snapshot.needChoice=chooseLower(snapshot,snapshot.criticalFood,snapshot.criticalWater)
		else
			local missionPending=snapshot.target>0 and snapshot.amount<snapshot.target
			snapshot.needMode=missionPending and "mission" or nil
			snapshot.needChoice=missionPending and chooseLower(snapshot,snapshot.canEat,snapshot.canDrink) or nil
		end

		snapshot.waitingNeeds=
			snapshot.target>0
			and snapshot.amount<snapshot.target
			and snapshot.needChoice==nil
	end

	function m.destination(p,root,height,object)
		local hit=ground(p)
		if not hit or hit.Material==Enum.Material.Water then return false end
		return Vector3.new(p.X,hit.Position.Y+height,p.Z+0.75),p
	end

	function m.perform(name,object,duration,before,resource)
		status(name.." | Comendo alimento")
		if not focus() then stopHover();return false end
		local character=Client:GetCurrentCharacter()
		local capacity=character.CharacterData:GetWithModifiers("Appetite")

		if not actions.startEat(object) then
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
		pause(0.5)
		return nil
	end

	function m.run(name,snapshot)
		if snapshot.needChoice~="food" then return false end
		for _,item in ipairs(r.sources(m.tag,name)) do
			if foodCompatible(item,snapshot.character) then
				return r.interact(name,m,item,8)==true
			end
		end
		return false
	end

	return m
end
