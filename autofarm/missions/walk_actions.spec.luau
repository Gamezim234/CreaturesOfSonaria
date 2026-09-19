-- Verifica movimento e cleanup da caminhada sem mover personagens reais.
return function(factory)
	local checks={}
	local setEnv:any=setfenv
	for _,mode in ipairs({"stop","error","respawn"}) do
		local moved,stopped,sprintStopped,ticks=0,0,0,0
		local character={Root={Position=Vector3.zero},Model={FindFirstChildOfClass=function() return nil end}}
		local r={Client={GetCurrentCharacter=function() return mode=="respawn" and {} or character end}}
		r.progress=function() return 0,100 end
		r.ground=function(point) return {Position=point,Material=Enum.Material.Grass} end
		r.regionAt=function() return "Desert" end
		r.status=function() end
		r.active=function() ticks+=1;return ticks<4 end
		r.pause=function() if mode=="error" then error("Interrompido") end;return true end
		r.actions={setMovement=function(x,z) assert(x*x+z*z>0.5);moved+=1;return true end,
			stopMovement=function() stopped+=1;return true end,setSprint=function(enabled) assert(not enabled);sprintStopped+=1;return true end}
		local previous=getfenv(factory)
		setEnv(factory,setmetatable({workspace={CurrentCamera={CFrame=CFrame.new()}},isrbxactive=function() error("Nao consultar foco") end},{__index=previous}))
		local m=factory(r)
		local ok=pcall(m.run,"Desert",{character=character},false)
		assert(ok==(mode~="error"),"Propagacao de erro: "..mode)
		assert(stopped==1 and sprintStopped==1,"Cleanup obrigatorio: "..mode)
		assert((moved>0)==(mode~="respawn"),"Controle do personagem atual: "..mode)
		table.insert(checks,"Caminhada e cleanup: "..mode)
		setEnv(factory,previous)
	end
	return checks
end