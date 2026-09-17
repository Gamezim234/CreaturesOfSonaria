-- Cria o botao de coleta manual de ShoomPiles e seu percurso.
return function(ctx)
	local state, Rayfield, Tab = ctx.state, ctx.Rayfield, ctx.Tab
	local LocalPlayer, UIS = ctx.player, ctx.UIS

	local getHRP=ctx.teleport.getRoot
	-- Coleta dos modelos de ShoomPiles (uma passagem por clique).
	Tab:CreateButton({
		Name = "Coletar ShoomPiles",
		Callback = function()
			if state.collecting or state.busy or not state.enabled then return end
			local interactions = workspace:FindFirstChild("Interactions")
			local folder = interactions and interactions:FindFirstChild("ShoomPiles")
			if not folder then
				Rayfield:Notify({Title = "ShoomPiles", Content = "Pasta nao encontrada.", Duration = 3})
				return
			end
			state.collecting = true
			task.spawn(function()
				local keyHeld = false
				local visited = 0
				local function pause(seconds)
					local deadline = os.clock() + seconds
					repeat
						if not state.enabled then return false end
						task.wait(0.05)
					until os.clock() >= deadline
					return state.enabled
				end
				local function waitForFocus()
					while state.enabled and (not isrbxactive() or UIS:GetFocusedTextBox()) do
						task.wait(0.1)
					end
					return state.enabled
				end
				local ok, err = pcall(function()
					local targets = folder:GetChildren()
					table.sort(targets, function(a, b) return a.Name < b.Name end)
					for _, target in ipairs(targets) do
						if not state.enabled then break end
						if target.Name == "Nodes" or not target:IsA("Model") or target.Parent ~= folder then
							continue
						end
						local part = target:FindFirstChild("Shoom", true)
						if not part or not part:IsA("BasePart") then
							part = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
						end
						if not part then continue end
						if not waitForFocus() then break end
						local hrp = getHRP()
						if not hrp then error("Personagem nao encontrado.") end
						if not target:IsDescendantOf(folder) then continue end
						local destination = part.Position + Vector3.new(0, 3, 0)
						hrp.CFrame = CFrame.new(destination, destination + hrp.CFrame.LookVector)
						hrp.AssemblyLinearVelocity = Vector3.zero
						hrp.AssemblyAngularVelocity = Vector3.zero
						if not pause(0.6) or not waitForFocus() then break end
						keyHeld = true
						keypress(0x45) -- tecla E
						local heldUntil = os.clock() + 1
						repeat
							task.wait(0.05)
						until not state.enabled or not isrbxactive() or os.clock() >= heldUntil
						keyrelease(0x45)
						keyHeld = false
						visited = visited + 1
						if not pause(0.5) then break end
					end
				end)
				if keyHeld then pcall(function() keyrelease(0x45) end) end
				state.collecting = false
				if state.enabled then
					Rayfield:Notify({
						Title = "ShoomPiles",
						Content = ok and ("Percurso finalizado: " .. visited .. " locais visitados.")
							or ("Coleta interrompida: " .. tostring(err)),
						Duration = 4
					})
				end
			end)
		end
	})




end
