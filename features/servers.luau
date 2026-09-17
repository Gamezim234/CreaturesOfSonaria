-- Busca servidores publicos com ate dois jogadores e solicita a entrada pelo botao.
return function(ctx)
	local state, Rayfield, Tab = ctx.state, ctx.Rayfield, ctx.Tab
	local LocalPlayer, UIS = ctx.player, ctx.UIS

	local ServerSearchBusy = false
	Tab:CreateButton({
		Name = "Servidor - Buscar com ate 2 jogadores",
		Callback = function()
			if ServerSearchBusy or not state.enabled then return end
			ServerSearchBusy = true
			task.spawn(function()
				local teleportConnection = nil
				local function notify(message)
					if state.enabled then Rayfield:Notify({Title="Servidor com ate 2 jogadores", Content=message, Duration=7}) end
				end
				local ok, err = pcall(function()
					local httpService = game:GetService("HttpService")
					local cursor = nil
					local candidate = nil
					local candidateCount = math.huge
					local minimum = math.huge
					local pages = 0
					local seen = {}
					notify("Buscando servidores publicos com ate 2 jogadores...")
					repeat
						if not state.enabled then return end
						pages = pages + 1
						local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true"
						if cursor then url = url .. "&cursor=" .. httpService:UrlEncode(cursor) end
						local response = request({Url=url, Method="GET"})
						if type(response) ~= "table" or response.StatusCode ~= 200 then
							error("Falha na consulta de servidores: " .. (type(response) == "table" and tostring(response.StatusCode) or tostring(response)))
						end
						local data = httpService:JSONDecode(response.Body)
						assert(type(data.data) == "table", "Resposta de servidores invalida")
						for _, server in ipairs(data.data) do
							if type(server.id) == "string" and server.id ~= game.JobId and type(server.playing) == "number" then
								minimum = math.min(minimum, server.playing)
								if server.playing <= 2 and server.playing < candidateCount then
									candidate = server.id
									candidateCount = server.playing
								end
							end
						end
						cursor = data.nextPageCursor
						if type(cursor) ~= "string" or cursor == "" or seen[cursor] then break end
						seen[cursor] = true
						if candidateCount ~= 0 then task.wait(0.5) end
					until candidateCount == 0 or pages >= 10
					if not candidate then
						notify(minimum < math.huge and ("Nenhum servidor com ate 2 jogadores. O menor encontrado tem " .. minimum .. " jogador(es). Voce permanece aqui.") or "Nenhum outro servidor encontrado nas paginas consultadas.")
						return
					end
					if not state.enabled then return end
					if state.collecting then notify("Aguarde a coleta de cogumelos terminar e tente novamente."); return end
					ctx.farm.stop()
					local teleportService = game:GetService("TeleportService")
					local failed = false
					teleportConnection = teleportService.TeleportInitFailed:Connect(function(player, _, message)
						if player == LocalPlayer then failed = true; notify("Nao foi possivel entrar: " .. message) end
					end)
					notify("Servidor listado com " .. candidateCount .. " jogador(es) encontrado. Entrando...")
					teleportService:TeleportToPlaceInstance(game.PlaceId, candidate, LocalPlayer)
					local deadline = os.clock() + 15
					repeat task.wait(0.2) until failed or not state.enabled or os.clock() >= deadline
					if not failed and state.enabled then notify("Pedido de entrada enviado; se continuar aqui, tente novamente.") end
				end)
				if teleportConnection then teleportConnection:Disconnect() end
				ServerSearchBusy = false
				if not ok then notify(tostring(err)) end
			end)
		end
	})


end
