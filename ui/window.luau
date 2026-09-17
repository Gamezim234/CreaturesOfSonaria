-- Carrega o Rayfield e cria a janela e a aba originais.
return function()
	local success, Rayfield = pcall(function()
		return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
	end)

	if not success or not Rayfield then
		warn("Falha ao carregar Rayfield")
		return
	end

	local Players = game:GetService("Players")
	local UIS = game:GetService("UserInputService")
	local LocalPlayer = Players.LocalPlayer
	local Camera = workspace.CurrentCamera


	local Window = Rayfield:CreateWindow({
		Name = "CoS Biome TP",
		LoadingTitle = "Biome TP",
		LoadingSubtitle = "pos + camera",
		Theme = "Default",
		ConfigurationSaving = { Enabled = false },
		KeySystem = false
	})

	local Tab = Window:CreateTab("Teleport", 4483362458)


	return {Rayfield=Rayfield, Tab=Tab, player=LocalPlayer, UIS=UIS, camera=Camera}
end
