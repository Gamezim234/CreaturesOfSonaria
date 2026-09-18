-- Gerencia alvos por nick e o seguimento independente, sem criar UI.
return function(ctx)
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local sonarModule = game:GetService("ReplicatedStorage"):WaitForChild("Sonar") :: any
	local Wrapper = require(sonarModule)("PlayerWrapper")
	local state = ctx.state
	local api, connections = {}, {}
	local empty = "(selecione um jogador)"
	state.followDistance = 15
	state.following = false
	function api.player(id)
		if not id or id == ctx.player.UserId then return nil end
		return Players:GetPlayerByUserId(id)
	end
	function api.character(id)
		local player = api.player(id)
		local character = player and Wrapper.getCharacterFromPlayer(player)
		local root = character and character.Root
		local health = character and character.CharacterData and character.CharacterData:Get("Health")
		if not root or not root.Parent or type(health) ~= "number" or health <= 0 then return nil end
		return character
	end
	function api.options(selectedName)
		local names = {}
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= ctx.player then table.insert(names, player.Name) end
		end
		if selectedName and not table.find(names, selectedName) then table.insert(names, selectedName) end
		table.sort(names)
		table.insert(names, 1, empty)
		return names
	end
	function api.select(key,value)
		local name = type(value) == "table" and value[1] or value
		if name == empty then state[key]=nil; state[key.."Name"]=nil; return end
		local player = name and Players:FindFirstChild(name)
		if player and player ~= ctx.player then state[key]=player.UserId; state[key.."Name"]=player.Name end
	end
	function api.step()
		-- O seguimento aguarda enquanto outra funcao controla o movimento desta conta.
		if not state.enabled or not state.following or state.running or state.collecting or state.heldKey or state.hover then return end
		local target = api.character(state.followTarget)
		local character = Wrapper.GetClient():GetCurrentCharacter()
		local root = character and character.Root
		if not target or not root or not root.Parent then return end
		local slot = Wrapper.GetClient():GetCurrentSlot()
		local health = slot and slot:FindFirstChild("Health")
		if not health or health.Value <= 0 then return end
		if (root.Position-target.Root.Position).Magnitude <= state.followDistance then return end
		local offset = math.min(6,state.followDistance/2)
		root.CFrame = target.Root.CFrame * CFrame.new(0,0,offset)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	function api.destroy()
		state.following = false
		api.onRosterChanged = nil
		for _, connection in ipairs(connections) do connection:Disconnect() end
		table.clear(connections)
	end
	local function rosterChanged()
		task.defer(function() if state.enabled and api.onRosterChanged then api.onRosterChanged() end end)
	end
	table.insert(connections, Players.PlayerAdded:Connect(rosterChanged))
	table.insert(connections, Players.PlayerRemoving:Connect(rosterChanged))
	local elapsed = 0
	table.insert(connections, RunService.Heartbeat:Connect(function(dt)
		if not state.enabled then api.destroy(); return end
		elapsed += dt
		if elapsed < 0.3 then return end
		elapsed = 0
		local ok, err = pcall(api.step)
		if not ok then state.following=false; warn("[Seguir jogador] " .. tostring(err)) end
	end))
	return api
end
