-- Logica de coordenadas salvas, camera e teleporte (sem UI).
return function(ctx)
	local state = ctx.state
	local LocalPlayer = ctx.player
	local Camera = ctx.camera

	local HEIGHT = 6
	local Saved = {}
	local Selected = nil

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

		if data.camCF then
			Camera.CameraType = Enum.CameraType.Scriptable
			Camera.CFrame = data.camCF
			task.delay(0.1, function()
				Camera.CameraType = Enum.CameraType.Custom
			end)
		end
	end

	local function listNames()
		local names = {}
		for name in pairs(Saved) do
			table.insert(names, name)
		end
		table.sort(names)
		if #names == 0 then names = {"(nenhuma)"} end
		return names
	end

	return {
		getRoot = getHRP,
		getHeight = function() return HEIGHT end,
		setHeight = function(v) HEIGHT = v end,
		listNames = listNames,
		save = function(name)
			local hrp = getHRP()
			if not hrp then return false, "Personagem nao encontrado" end
			if not name or name == "" then return false, "Coloca um nome" end
			Saved[name] = {
				pos = hrp.Position,
				look = hrp.CFrame.LookVector,
				camCF = Camera.CFrame,
			}
			Selected = name
			return true, name
		end,
		select = function(name)
			if name and name ~= "(nenhuma)" and Saved[name] then
				Selected = name
				return true
			end
			return false
		end,
		getSelected = function() return Selected end,
		teleportSelected = function()
			if not Selected or not Saved[Selected] then
				return false, "Nenhuma coord selecionada"
			end
			safeTeleport(Saved[Selected])
			return true
		end,
	}
end
