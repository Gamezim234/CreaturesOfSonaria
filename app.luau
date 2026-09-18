-- Monta logica + UI unica e tecla F8 (desinjetar).
return function(import)
	print("[CoS] app.luau iniciou")

	local Players = game:GetService("Players")
	local UIS = game:GetService("UserInputService")
	local LocalPlayer = Players.LocalPlayer
	local Camera = workspace.CurrentCamera

	local ctx: any = {
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
		if ctx.state.heldKey then
			pcall(keyrelease, ctx.state.heldKey)
		end
		ctx.state.heldKey = nil
	end

	local function loadMod(path)
		print("[CoS] import", path)
		local mod = import(path)
		if type(mod) ~= "function" then
			error(path .. " nao retornou function")
		end
		return mod(ctx)
	end

	-- logica (nao cria UI)
	ctx.teleport = loadMod("features/teleport.luau")
	ctx.shoom = loadMod("features/shoompiles.luau")
	ctx.servers = loadMod("features/servers.luau")
	ctx.farm.run = loadMod("autofarm/controller.luau")
	ctx.players = loadMod("features/players.luau")

	-- UI unica (nao usa ui/window nem autofarm-buttons)
	print("[CoS] carregando ui/interface.luau")
	local uiMod = import("ui/interface.luau")
	if type(uiMod) ~= "function" then
		error("ui/interface.luau nao retornou function")
	end
	local ui = uiMod(ctx)
	if not ui or not ui.Rayfield then
		ctx.players.destroy()
		error("UI nao inicializou (Rayfield nil). Veja warn de Falha ao carregar Rayfield.")
	end
	ctx.Rayfield = ui.Rayfield

	ctx.inputConn = UIS.InputBegan:Connect(function(input, gpe)
		if gpe or not ctx.state.enabled then
			return
		end
		if input.KeyCode == Enum.KeyCode.F8 then
			ctx.farm.stop()
			ctx.state.enabled = false
			ctx.players.destroy()
			if ctx.inputConn then
				ctx.inputConn:Disconnect()
			end
			pcall(function()
				ctx.Rayfield:Destroy()
			end)
			print("Desinjetado")
		end
	end)

	print("[CoS] UI pronta | F8 = desinjetar")
end
