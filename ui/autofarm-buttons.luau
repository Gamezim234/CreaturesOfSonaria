-- Cria os botoes de iniciar, parar e consultar o autofarm.
return function(ctx)
	local state, Rayfield, Tab = ctx.state, ctx.Rayfield, ctx.Tab
	local LocalPlayer, UIS = ctx.player, ctx.UIS

	Tab:CreateButton({
		Name = "Auto farm - Iniciar / Parar",
		Callback = function()
			if state.busy then ctx.farm.stop(); return end
			if not state.enabled then return end
			if state.collecting then
				Rayfield:Notify({Title="Auto farm", Content="Aguarde a coleta de ShoomPiles terminar.", Duration=3})
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
				if state.enabled then Rayfield:Notify({Title="Auto farm", Content=state.status, Duration=5}) end
			end)
		end
	})
	Tab:CreateButton({
		Name = "Auto farm - Ver status",
		Callback = function()
			Rayfield:Notify({Title="Auto farm", Content=state.status, Duration=6})
		end
	})



end
