-- Gerencia coordenadas salvas, camera e teleporte manual.
return function(ctx)
	local state, Rayfield, Tab = ctx.state, ctx.Rayfield, ctx.Tab
	local LocalPlayer, UIS = ctx.player, ctx.UIS

	local Camera, HEIGHT, Saved, Selected = ctx.camera, 6, {}, nil
	local function getHRP()
		local char = LocalPlayer.Character
		if not char then return nil end
		return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("RootPart")
	end

	local function safeTeleport(data)
		if not state.enabled or not data then return end
		local hrp = getHRP()
		if not hrp then return end

		local pos = data.pos
		local look = data.look

		local origin = pos + Vector3.new(0, 50, 0)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {LocalPlayer.Character}

		local hit = workspace:Raycast(origin, Vector3.new(0, -100, 0), params)
		local finalPos = hit and (hit.Position + Vector3.new(0, HEIGHT, 0)) or (pos + Vector3.new(0, HEIGHT + 2, 0))

		hrp.CFrame = CFrame.new(finalPos, finalPos + look)
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero

		-- restaura a câmera
		if data.camCF then
			Camera.CameraType = Enum.CameraType.Scriptable
			Camera.CFrame = data.camCF
			task.delay(0.1, function()
				Camera.CameraType = Enum.CameraType.Custom
			end)
		end
	end

	local function refreshNames()
		local names = {}
		for name in pairs(Saved) do
			table.insert(names, name)
		end
		table.sort(names)
		if #names == 0 then names = {"(nenhuma)"} end
		return names
	end

	local SaveName = "Bioma1"

	Tab:CreateInput({
		Name = "Nome da coordenada",
		PlaceholderText = "ex: Lago, Desert, Swamp",
		CurrentValue = "Bioma1",
		Callback = function(v)
			SaveName = v
		end
	})

	Tab:CreateButton({
		Name = "Salvar pos + direção + câmera",
		Callback = function()
			local hrp = getHRP()
			if not hrp then
				Rayfield:Notify({Title = "Erro", Content = "Personagem não encontrado", Duration = 3})
				return
			end
			if not SaveName or SaveName == "" then
				Rayfield:Notify({Title = "Erro", Content = "Coloca um nome", Duration = 3})
				return
			end

			Saved[SaveName] = {
				pos = hrp.Position,
				look = hrp.CFrame.LookVector,
				camCF = Camera.CFrame
			}
			Selected = SaveName

			Rayfield:Notify({
				Title = "Salvo!",
				Content = SaveName .. " (pos + dir + camera)",
				Duration = 4
			})
			print("Salvo:", SaveName)
		end
	})

	local Dropdown
	Dropdown = Tab:CreateDropdown({
		Name = "Selecionar coordenada",
		Options = {"(nenhuma)"},
		CurrentOption = {"(nenhuma)"},
		Callback = function(opt)
			local name = typeof(opt) == "table" and opt[1] or opt
			if name and name ~= "(nenhuma)" and Saved[name] then
				Selected = name
			end
		end
	})

	Tab:CreateButton({
		Name = "Atualizar lista",
		Callback = function()
			Dropdown:Refresh(refreshNames())
			Rayfield:Notify({Title = "Lista", Content = "Atualizada", Duration = 2})
		end
	})

	Tab:CreateButton({
		Name = "Teleportar para selecionada",
		Callback = function()
			if not Selected or not Saved[Selected] then
				Rayfield:Notify({Title = "Erro", Content = "Nenhuma coord selecionada", Duration = 3})
				return
			end
			safeTeleport(Saved[Selected])
		end
	})


	return {
		getRoot=getHRP,
		selected=function()
			if Selected and Saved[Selected] then safeTeleport(Saved[Selected])
			else warn("Nenhuma coord selecionada") end
		end,
		addHeightSlider=function()
			Tab:CreateSlider({
				Name = "Altura acima do chão",
				Range = {2, 15},
				Increment = 1,
				CurrentValue = 6,
				Callback = function(v)
					HEIGHT = v
				end
			})


		end,
	}
end
