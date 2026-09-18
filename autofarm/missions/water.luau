-- Executa a bebida e controla o posicionamento e a sustentacao no lago.
return function(r)
	local state, UIS, Client = r.state, r.UIS, r.Client
	local status, active, pause, focus = r.status, r.active, r.pause, r.focus
	local progress, stopHover = r.progress, r.stopHover

	local m = {kind="EatFoodDrinkWater", tag="DrinkableWater", resource="Water"}
	function m.prepare(snapshot)
		local c, slot = snapshot.character, snapshot.slot
		local water = slot:FindFirstChild("Water")
		snapshot.thirst = not c.HasNoThirst and water and water.Value < c.CharacterData:GetWithModifiers("ThirstAppetite") - 0.5
	end
	function m.destination(p, root, height, object)
		local destination

		local surface = object and object:FindFirstChild("Surface", true)
		if not surface or not surface:IsA("BasePart") then return false end
		p = surface.Position
		local top = surface.CFrame:PointToWorldSpace(Vector3.new(0, surface.Size.Y / 2, 0))
		destination = Vector3.new(p.X, top.Y + root.Size.Y / 2 + 0.3, p.Z)

		return destination, p
	end
	function m.afterMove(root,c)
		local hoverFrame = root.CFrame
		state.hover = game:GetService("RunService").Heartbeat:Connect(function()
			if not state.enabled or not state.running or not root.Parent or not isrbxactive()
					or UIS:GetFocusedTextBox() or Client:GetCurrentCharacter() ~= c then
				stopHover(); return
			end
			root.CFrame = hoverFrame
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end)

	end
	function m.perform(name, object, duration, before, resource)

		status(name .. " | Bebendo no centro do lago")
		if not focus() then stopHover(); return false end
		local character = Client:GetCurrentCharacter()
		local capacity = character.CharacterData:GetWithModifiers("ThirstAppetite")
		state.heldKey = 0x45
		keypress(0x45)
		local deadline = os.clock() + duration
		repeat task.wait(0.1)
		until not active() or not isrbxactive() or UIS:GetFocusedTextBox()
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
		if snapshot.thirst then
			for _, lake in ipairs(r.sources(m.tag,name)) do
				if lake:GetAttribute("CanDrink") ~= false and not lake:GetAttribute("Sickly") and not lake:GetAttribute("IsPoisoned")
						and not lake:GetAttribute("CorruptedWater") and not lake:GetAttribute("FakeWater") and (lake:GetAttribute("Water") or 0)>0 then
					r.interact(name,m,lake,8); return true
				end
			end
		end
		return false
	end
	return m
end
