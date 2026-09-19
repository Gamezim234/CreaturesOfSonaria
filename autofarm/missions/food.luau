-- Executa a alimentacao e seleciona comida compativel com herbivoros.
return function(r)
	local state, UIS, Client = r.state, r.UIS, r.Client
	local status, active, pause, focus = r.status, r.active, r.pause, r.focus
	local progress, stopHover = r.progress, r.stopHover

	local Constants, ground = r.Constants, r.ground
	local m = {kind="EatFoodDrinkWater", tag="Food", resource="Food"}
	local function foodCompatible(object, c)
		local d = Constants.FoodData[object:GetAttribute("FoodDataName") or object.Name]
		if not d or object:GetAttribute("Rotten") or object:GetAttribute("Held")
				or (object:GetAttribute("Value") or 0) <= 0 then return false end
		return (d.Diet == "Herbivore" or d.Diet == "Omnivore")
			and (not d.AbilityRequirementToInteract or c.CharacterData:Get(d.AbilityRequirementToInteract))
	end

	function m.prepare(name,snapshot)
		local c,slot = snapshot.character,snapshot.slot
		local food = slot:FindFirstChild("Food")
		snapshot.hunger = not c.HasNoHunger and food and food.Value < c.CharacterData:GetWithModifiers("Appetite") - 0.5
		snapshot.waitingNeeds = snapshot.amount < snapshot.target and not snapshot.hunger and not snapshot.thirst
	end
	function m.destination(p,root,height,object)
		local destination

		local hit = ground(p)
		if not hit or hit.Material == Enum.Material.Water then return false end
		-- Quase no centro, mantendo a comida a frente para o menu de interacao.
		destination = Vector3.new(p.X, hit.Position.Y + height, p.Z + 0.75)

		return destination,p
	end
	function m.perform(name,object,duration,before,resource)

		status(name .. " | Comendo alimento herbivoro")
		if not focus() then stopHover(); return false end
		local character = Client:GetCurrentCharacter()
		local capacity = character.CharacterData:GetWithModifiers("Appetite")
		state.heldKey = 0x45
		keypress(0x45)
		local deadline = os.clock() + duration
		repeat task.wait(0.1)
		until not active()
			or (resource and resource.Value >= capacity - 0.1) or os.clock() >= deadline
		keyrelease(0x45)
		state.heldKey = nil
		stopHover()
		pause(1)

		return nil

	end
	function m.run(name,snapshot)
		local amount,target=progress(name,m.kind)
		if amount >= target then return false end
		if snapshot.hunger then
			for _,item in ipairs(r.sources(m.tag,name)) do
				if foodCompatible(item,snapshot.character) then r.interact(name,m,item,8); return true end
			end
		end
		return false
	end
	return m
end