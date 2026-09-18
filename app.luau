-- Monta logica + UI unica e tecla F8 (desinjetar).
return function(import)
	local Players = game:GetService("Players")
	local UIS = game:GetService("UserInputService")
	local LocalPlayer = Players.LocalPlayer
	local Camera = workspace.CurrentCamera

	local ctx = {
		state = {
			enabled = true,
			running = false,
			busy = false,
			collecting = false,
			status = "Parado",
		},
		player = LocalPlayer,
		UIS = UIS,
		camera = Camera,
		import = import,
	}

	function ctx.stopHover()
		if ctx.state.hover then
			ctx.state.hover:Disconnect()
			ctx.state.hover = nil
		end
	end

	ctx.farm = {}
	function ctx.farm.stop()
		ctx.state.running = false
		ctx.stopHover()
		if ctx.state.heldKey then pcall(keyrelease, ctx.state.heldKey) end
		ctx.state.heldKey = nil
	end

	ctx.teleport = import("features/teleport.luau")(ctx)
	ctx.shoom = import("features/shoompiles.luau")(ctx)
	ctx.servers = import("features/servers.luau")(ctx)
	ctx.farm.run = import("autofarm/controller.luau")(ctx)

	local ui = import("ui/interface.luau")(ctx)
	if not ui then return end
	ctx.Rayfield = ui.Rayfield

	ctx.inputConn = UIS.InputBegan:Connect(function(input, gpe)
		if gpe or not ctx.state.enabled then return end
		if input.KeyCode == Enum.KeyCode.F8 then
			ctx.farm.stop()
			ctx.state.enabled = false
			if ctx.inputConn then ctx.inputConn:Disconnect() end
			pcall(function() ctx.Rayfield:Destroy() end)
			print("Desinjetado")
		end
	end)

	print("CoS carregado | F8 = desinjetar")
end
