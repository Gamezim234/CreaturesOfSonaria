-- Monta os modulos, compartilha o estado e conecta os controles originais.
return function(import)
	local ctx=import("ui/window.luau")()
	if not ctx then return end
	ctx.import=import
	ctx.state={enabled=true,running=false,busy=false,collecting=false,status="Parado"}
	local state,Rayfield,Tab=ctx.state,ctx.Rayfield,ctx.Tab
	local LocalPlayer,UIS=ctx.player,ctx.UIS
	local conn
	function ctx.stopHover()
		if state.hover then state.hover:Disconnect(); state.hover=nil end
	end
	ctx.farm={}
	function ctx.farm.stop()
		state.running=false
		ctx.stopHover()
		if state.heldKey then pcall(keyrelease,state.heldKey) end
		state.heldKey=nil
	end
	ctx.teleport=import("features/teleport.luau")(ctx)
	import("features/shoompiles.luau")(ctx)
	ctx.farm.run=import("autofarm/controller.luau")(ctx)
	import("ui/autofarm-buttons.luau")(ctx)
	import("features/servers.luau")(ctx)
	ctx.teleport.addHeightSlider()
	Tab:CreateButton({
		Name = "DESINJETAR",
		Callback = function()
			ctx.farm.stop()
			state.enabled = false
			if conn then conn:Disconnect() end
			pcall(function() Rayfield:Destroy() end)
			print("Desinjetado")
		end
	})

	conn = UIS.InputBegan:Connect(function(input, gpe)
		if gpe or not state.enabled then return end

		if input.KeyCode == Enum.KeyCode.R then
			ctx.teleport.selected()
		end

		if input.KeyCode == Enum.KeyCode.F8 then
			ctx.farm.stop()
			state.enabled = false
			if conn then conn:Disconnect() end
			pcall(function() Rayfield:Destroy() end)
			print("Desinjetado")
		end
	end)

	print("Biome TP | salva pos + direção + câmera | R = TP | F8 = sair")

end
