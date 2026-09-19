-- Testa a camada de acoes com modulos falsos, sem enviar inputs ou atacar no jogo.
return function(factory)
	local checks={}
	local setEnv:any=setfenv
	local function check(value,name) assert(value,name);table.insert(checks,name) end
	local function controller()
		return {UpdateMovement=function(self,arg)
			assert(arg==nil)
			self.x=self.leftValue+self.rightValue
			self.z=self.forwardValue+self.backwardValue
		end}
	end
	local calls={attack=0,jump=0,mud=0,sniff=0,sprint=0,stopSprint=0}
	local function character()
		return {Attack=function() calls.attack+=1 end,Jump=function() calls.jump+=1 end,Roll=function(_,kind) assert(kind=="Mud");calls.mud+=1 end}
	end
	local oldController=controller()
	local client:any={CurrentCharacter=character(),PlayerControls={activeController=oldController}}
	local modules:any={
		PlayerWrapper={GetClient=function() return client end},
		SprintService={Sprint=function() calls.sprint+=1 end,StopSprinting=function() calls.stopSprint+=1 end},
		Sonar=function(name) assert(name=="Sniff");return {Sniff=function() calls.sniff+=1 end} end,
	}
	local folder={FindFirstChild=function(_,name) return modules[name] and name end}
	local storage={FindFirstChild=function(_,name) if name=="_replicationFolder" then return folder end;return modules[name] and name end}
	local oldEnv=getfenv(factory)
	local env=setmetatable({game={GetService=function(_,name) assert(name=="ReplicatedStorage");return storage end},require=function(name) return modules[name] end,
		isrbxactive=function() error("Acoes nao podem consultar foco") end,
		keypress=function() error("Input fisico proibido") end,mouse1click=function() error("Clique fisico proibido") end},{__index=oldEnv})
	setEnv(factory,env)
	local actions=factory()
	check(actions.attack() and calls.attack==1,"Attack normal")
	check(actions.jump() and calls.jump==1,"Jump normal")
	check(actions.rollMud() and calls.mud==1,"Roll Mud normal")
	check(actions.sniff() and calls.sniff==1,"Sniff correto, sem foco")
	check(actions.setSprint(true) and actions.setSprint(false) and calls.sprint==1 and calls.stopSprint==1,"Sprint e parada")
	check(actions.moveForward() and oldController.z==-1 and oldController.x==0,"Movimento para frente")
	check(actions.setMovement(5,-5) and oldController.x==1 and oldController.z==-1,"Clamp dos eixos")
	check(actions.setMovement(-0.5,0.75) and oldController.leftValue==-0.5 and oldController.backwardValue==0.75,"Sinais dos eixos")
	check(actions.stopMovement() and oldController.x==0 and oldController.z==0,"Parada completa")
	local originalCharacter=client.CurrentCharacter
	client.CurrentCharacter=character()
	check(actions.attack() and calls.attack==2,"Personagem atualizado apos troca")
	client.CurrentCharacter.Attack=function() error("Personagem removido durante a acao") end
	check(actions.attack()==false,"Erro de acao contido")
	client.CurrentCharacter=nil
	check(not actions.attack() and not actions.jump() and not actions.rollMud() and not actions.sniff() and not actions.setSprint(true),"Personagem ausente")
	check(not actions.moveForward() and oldController.z==0,"Sem personagem nao inicia movimento")
	client.CurrentCharacter=originalCharacter
	actions.moveForward()
	local newController=controller()
	client.PlayerControls.activeController=newController
	check(actions.moveForward() and newController.z==-1 and oldController.z==0,"Controlador atualizado e anterior liberado")
	client.PlayerControls.activeController=nil
	check(not actions.stopMovement() and newController.z==0,"Controlador ausente libera movimento anterior")
	client.PlayerControls=nil
	check(not actions.setMovement(1,0),"PlayerControls ausente")
	client=nil
	check(not actions.attack() and not actions.jump() and not actions.rollMud() and not actions.sniff() and not actions.moveForward(),"Cliente ausente")
	check(type(actions.setSprint(false))=="boolean" and type(actions.stopMovement())=="boolean","Cleanup sem cliente nao gera erro")
	modules.PlayerWrapper=nil
	check(not actions.attack(),"Modulo ainda indisponivel")
	modules.SprintService.StopSprinting=function() error("Indisponivel") end
	check(not actions.setSprint(false),"Erro de cleanup contido")
	check(not actions.setMovement("invalid",0) and not actions.setMovement(0/0,0),"Eixos invalidos falham de forma segura")
	setEnv(factory,oldEnv)
	return checks
end