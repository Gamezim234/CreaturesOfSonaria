-- Fornece regioes, progresso, entrada, movimento e utilitarios compartilhados.
return function(ctx)
	local state, LocalPlayer, UIS = ctx.state, ctx.player, ctx.UIS
	local module = game:GetService("ReplicatedStorage"):FindFirstChild("Sonar") :: any
	local Sonar = require(module)
	local Client = Sonar("PlayerWrapper").GetClient()
	local RegionUtils = Sonar("RegionUtils")
	local Regions = Sonar(Sonar("StorageUtils").Get("Regions"))
	local Constants = Sonar("Constants")
	local Tags = game:GetService("CollectionService")
	local names, failures = {}, {}
	local r = {state=state, UIS=UIS, Client=Client, Constants=Constants, Tags=Tags, failures=failures, missions={}}
	r.actions=ctx.actions
	local survival=ctx.survival
	local function cleanupActions()
		r.actions.stopMovement()
		r.actions.setSprint(false)
	end
	r.players, r.player = ctx.players, LocalPlayer
	local previousCharacter, previousSlot, previousHealth
	local hungerDamage, thirstDamage = false, false
	function r.needsEmergency()
		local c, slot = Client:GetCurrentCharacter(), Client:GetCurrentSlot()
		local health = slot and slot:FindFirstChild("Health")
		local food = slot and slot:FindFirstChild("Food")
		local water = slot and slot:FindFirstChild("Water")
		if c ~= previousCharacter or slot ~= previousSlot or not c or not health then
			previousCharacter, previousSlot = c, slot
			previousHealth = health and health.Value
			hungerDamage, thirstDamage = false, false
			return false
		end
		local emptyFood = not c.HasNoHunger and food and food.Value <= 0
		local emptyWater = not c.HasNoThirst and water and water.Value <= 0
		-- Heuristica autorizada: recurso zerado junto com queda de vida.
		local lostHealth = previousHealth and health.Value > 0 and health.Value < previousHealth
		hungerDamage = emptyFood and (hungerDamage or lostHealth) or false
		thirstDamage = emptyWater and (thirstDamage or lostHealth) or false
		previousHealth = health.Value
		return hungerDamage or thirstDamage
	end
	local function stopHover() ctx.stopHover() end
	local function status(message)
		if message ~= state.status then
			cleanupActions()
			state.status = message
			print("[Auto farm] " .. message)
		end
	end
	local function active()
		if not state.enabled or not state.running then cleanupActions();return false end
		if survival and not survival.ensureReady() then cleanupActions();return false end
		local c = Client:GetCurrentCharacter()
		local slot = Client:GetCurrentSlot()
		if not c or not c.Root or not c.Root.Parent or not slot
				or (slot:FindFirstChild("Health") and slot.Health.Value <= 0) then
			cleanupActions()
			return false
		end
		r.needsEmergency()
		return true
	end
	local function pause(seconds)
		local untilTime = os.clock() + seconds
		repeat
			if not active() then return false end
			task.wait(0.1)
		until os.clock() >= untilTime
		return active()
	end
	local function focus()
		return active()
	end
	local function press(key, seconds)
		if not focus() then return false end
		state.heldKey = key
		keypress(key)
		local untilTime = os.clock() + seconds
		repeat task.wait(0.1)
		until not active() or os.clock() >= untilTime
		keyrelease(key)
		state.heldKey = nil
		return active()
	end
	local function missionFolder(name)
		local data = LocalPlayer.PlayerGui:FindFirstChild("Data")
		local missions = data and data:FindFirstChild("Missions")
		local regional = missions and missions:FindFirstChild("RegionMissions")
		return regional and regional:FindFirstChild(name)
	end
	local function progress(name, kind)
		local f = missionFolder(name)
		local m = f and f:FindFirstChild(kind)
		local amount = m and m:FindFirstChild("Amount")
		local target = m and m:FindFirstChild("TargetAmount")
		if not amount or not target then return 0, 0 end
		return amount.Value, target.Value
	end
	local kinds = {"ShoomPilesCollected", "Sniff", "ConcealScent", "EatFoodDrinkWater", "DistanceTravelled", "TimePlayed", "AttackOrHealCreatureOrNPC"}
	local function pending(name)
		for _, kind in ipairs(kinds) do
			local a, b = progress(name, kind)
			if a < b then return true end
		end
		return false
	end
	local function position(object)
		local p = object:GetAttribute("V3")
		if typeof(p) == "Vector3" then return p end
		if object:IsA("BasePart") then return object.Position end
		if object:IsA("Model") then
			local shoom = object:FindFirstChild("Shoom", true)
			return shoom and shoom:IsA("BasePart") and shoom.Position or object:GetPivot().Position
		end
		return nil
	end
	local function regionAt(p)
		return RegionUtils.getRegionFromPosition(p + Vector3.new(0, 10, 0))
	end
	local function sources(tag, name)
		local result = {}
		local objects = tag == "ShoomPile" and workspace:WaitForChild("Interactions"):WaitForChild("ShoomPiles"):GetChildren() or Tags:GetTagged(tag)
		for _, object in ipairs(objects) do
			if object.Name ~= "Nodes" and object:IsDescendantOf(workspace)
					and (failures[object] or 0) <= os.clock() then
				local p = position(object)
				if p and regionAt(p) == name then table.insert(result, object) end
			end
		end
		local root = Client:GetCurrentCharacter().Root
		table.sort(result, function(a, b)
			return (position(a) - root.Position).Magnitude < (position(b) - root.Position).Magnitude
		end)
		return result
	end
	local function ground(p)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = {workspace.Terrain, workspace:WaitForChild("Environment")}
		params.IgnoreWater = false
		return workspace:Raycast(Vector3.new(p.X, 1800, p.Z), Vector3.new(0, -2400, 0), params)
	end

	local function go(p, name, mode, object)
		cleanupActions()
		stopHover()
		if not focus() then return false end
		local c = Client:GetCurrentCharacter()
		local root = c.Root
		local humanoid = c.Model and c.Model:FindFirstChildOfClass("Humanoid")
		local height = root.Size.Y / 2 + (humanoid and humanoid.HipHeight or 2) + 0.5
		local destination = p
		if mode == "region" then
			pcall(function()
				LocalPlayer:RequestStreamAroundAsync(Vector3.new(p.X, 200, p.Z), 3)
			end)
			if not active() then return false end
			local hit = ground(p)
			if not hit or hit.Material == Enum.Material.Water then return false end
			destination = hit.Position + Vector3.new(0, height, 0)
		elseif r.missions[mode] and r.missions[mode].destination then
			destination, p = r.missions[mode].destination(p, root, height, object)
			if not destination then return false end
		else
			destination = p + Vector3.new(0, height, 0)
		end
		if regionAt(destination) ~= name then return false end
		local look = Vector3.new(p.X, destination.Y, p.Z)
		if (look - destination).Magnitude < 0.1 then look = destination + root.CFrame.LookVector end
		root.CFrame = CFrame.new(destination, look)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		if r.missions[mode] and r.missions[mode].afterMove then r.missions[mode].afterMove(root, c) end
		if not pause(1.5) then return false end
		local deadline = os.clock() + 8
		repeat
			-- O texto do HUD e traduzido; confirme pelo identificador interno da regiao.
			local current = Client:GetCurrentCharacter()
			if current and current.Root and regionAt(current.Root.Position) == name then return true end
			if not pause(0.3) then return false end
		until os.clock() > deadline
		return false
	end

	local function interact(name, mission, object, duration)
		local kind, tag = mission.kind, mission.tag
		local before, target = progress(name, kind)
		local isNeeds = mission.resource ~= nil
		if before >= target and not isNeeds then return false end
		local slot = Client:GetCurrentSlot()
		local resource = isNeeds and slot:FindFirstChild(mission.resource)
		local resourceBefore = resource and resource.Value or 0
		status(name .. " | " .. kind .. " " .. before .. "/" .. target)
		local p = position(object)
		if not p or not go(p, name, tag, object) then stopHover(); failures[object] = os.clock() + 60; return false end
		if mission.perform(name, object, duration, before, resource) == false then return false end
		local after = progress(name, kind)
		local gained = after > before or (resource and resource.Value > resourceBefore)
		if not gained then
			failures[object] = os.clock() + 45
			if isNeeds then status(name .. " | Sem aumento de fome/sede; tentando outro recurso") end
		end
		return gained == true
	end
	for name, data in pairs(Regions) do
		if (data.ZoneType == "Land" or data.RegionType == "Land") and missionFolder(name) then
			table.insert(names, name)
		end
	end
	assert(#names > 0, "Nenhum bioma terrestre encontrado")
	local root = Client:GetCurrentCharacter().Root
	local current = regionAt(root.Position)
	table.sort(names, function(a, b)
		if a == current then return b ~= current end
		if b == current then return false end
		return a < b
	end)

	function r.enter(name)
		local arrived = regionAt(Client:GetCurrentCharacter().Root.Position) == name
		if not arrived then
			-- Centros de regioes ficam sob o mapa: projetar no terreno antes de mover.
			local center = Regions[name].RegionCenterPosition
			for _, offset in ipairs({Vector3.zero, Vector3.new(70,0,0), Vector3.new(-70,0,0), Vector3.new(0,0,70)}) do
				if go(center + offset, name, "region") then arrived = true; break end
			end
		end

		return arrived
	end
	r.names, r.kinds = names, kinds
	r.active, r.pause, r.focus, r.press = active, pause, focus, press
	r.status, r.progress, r.pending = status, progress, pending
	r.position, r.regionAt, r.sources, r.ground = position, regionAt, sources, ground
	r.go, r.interact, r.stopHover = go, interact, stopHover
	return r
end