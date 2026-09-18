-- Toda a UI Rayfield em um unico arquivo.
return function(ctx)
	local success, Rayfield = pcall(function()
		return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
	end)
	if not success or not Rayfield then
		warn("Falha ao carregar Rayfield")
		return nil
	end

	local Players = game:GetService("Players")
	local UIS = game:GetService("UserInputService")
	local LocalPlayer = Players.LocalPlayer
	local Camera = workspace.CurrentCamera

	local Window = Rayfield:CreateWindow({
		Name = "Creatures of Sonaria",
		LoadingTitle = "CoS Script",
		LoadingSubtitle = "autofarm + utils",
		Theme = "Default",
		ConfigurationSaving = { Enabled = false },
		KeySystem = false,
	end)

	local TabTeleport = Window:CreateTab("Teleport", 4483362458)
	local TabFarm = Window:CreateTab("Auto Farm", 4483362458)
	local TabUtils = Window:CreateTab("Utilidades", 4483362458)

	ctx.Rayfield = Rayfield
	ctx.player = LocalPlayer
	ctx.UIS = UIS
	ctx.camera = Camera
	ctx.Window = Window

	local teleport = ctx.teleport
	local shoom = ctx.shoom
	local servers = ctx.servers
	local state = ctx.state

	local SaveName = "Bioma1"
	local Dropdown

	TabTeleport:CreateInput({
		Name = "Nome da coordenada",
		PlaceholderText = "ex: Lago, Desert, Swamp",
		CurrentValue = "Bioma1",
		Callback = function(v)
			SaveName = v
		end,
	})

	TabTeleport:CreateButton({
		Name = "Salvar pos + direcao + camera",
		Callback = function()
			local ok, msg = teleport.save(SaveName)
			if not ok then
				Rayfield:Notify({ Title = "Erro", Content = tostring(msg), Duration = 3 })
				return
			end
			Rayfield:Notify({ Title = "Salvo!", Content = msg .. " (pos + dir + camera)", Duration = 4 })
		end,
	})

	Dropdown = TabTeleport:CreateDropdown({
		Name = "Selecionar coordenada",
		Options = { "(nenhuma)" },
		CurrentOption = { "(nenhuma)" },
		Callback = function(opt)
			local name = typeof(opt) == "table" and opt[1] or opt
			teleport.select(name)
		end,
	})

	TabTeleport:CreateButton({
		Name = "Atualizar lista",
		Callback = function()
			Dropdown:Refresh(teleport.listNames())
			Rayfield:Notify({ Title = "Lista", Content = "Atualizada", Duration = 2 })
		end,
	})

	TabTeleport:CreateButton({
		Name = "Teleportar para selecionada",
		Callback = function()
			local ok, msg = teleport.teleportSelected()
			if not ok then
				Rayfield:Notify({ Title = "Erro", Content = tostring(msg), Duration = 3 })
			end
		end,
	})

	TabTeleport:CreateSlider({
		Name = "Altura acima do chao",
		Range = { 2, 15 },
		Increment = 1,
		CurrentValue = 6,
		Callback = function(v)
			teleport.setHeight(v)
		end,
	})

	TabFarm:CreateButton({
		Name = "Iniciar / Parar",
		Callback = function()
			if state.busy then
				ctx.farm.stop()
				return
			end
			if not state.enabled then return end
			if state.collecting then
				Rayfield:Notify({ Title = "Auto farm", Content = "Aguarde a coleta de ShoomPiles terminar.", Duration = 3 })
				return
			end
			state.running = true
			state.busy = true
			task.spawn(function()
				local ok, err = pcall(ctx.farm.run)
				ctx.farm.stop()
				state.busy = false
				local character = LocalPlayer.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if humanoid then humanoid:Move(Vector3.zero) end
				state.status = ok and "Parado" or tostring(err)
				if state.enabled then
					Rayfield:Notify({ Title = "Auto farm", Content = state.status, Duration = 5 })
				end
			end)
		end,
	})

	TabFarm:CreateButton({
		Name = "Ver status",
		Callback = function()
			Rayfield:Notify({ Title = "Auto farm", Content = state.status, Duration = 6 })
		end,
	})

	TabFarm:CreateButton({
		Name = "Coletar ShoomPiles",
		Callback = function()
			local ok, msg = shoom.collect()
			if not ok then
				Rayfield:Notify({ Title = "ShoomPiles", Content = tostring(msg), Duration = 3 })
			end
		end,
	})

	TabUtils:CreateButton({
		Name = "Buscar servidor (<=2 jogadores)",
		Callback = function()
			servers.searchLowPop()
		end,
	})

	TabUtils:CreateButton({
		Name = "DESINJETAR",
		Callback = function()
			ctx.farm.stop()
			state.enabled = false
			if ctx.inputConn then ctx.inputConn:Disconnect() end
			pcall(function() Rayfield:Destroy() end)
			print("Desinjetado")
		end,
	})

	return {
		Rayfield = Rayfield,
		Window = Window,
		player = LocalPlayer,
		UIS = UIS,
		camera = Camera,
	}
end
