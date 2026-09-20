-- Executa as acoes confirmadas do jogo com referencias atuais e falha segura.
return function()
	local Actions = {}
	local lastController
	local function safe(callback)
		local ok,result=pcall(callback)
		return ok and result==true
	end
	local function module(name)
		local storage=game:GetService("ReplicatedStorage")
		local folder=name=="Sonar" and storage or storage:FindFirstChild("_replicationFolder")
		local object=folder and folder:FindFirstChild(name) :: any
		return object and require(object)
	end
	local function getClient()
		local wrapper=module("PlayerWrapper")
		return wrapper and wrapper.GetClient()
	end
	local function getCharacter()
		local client=getClient()
		return client and client.CurrentCharacter
	end
	local function getController()
		local client=getClient()
		local controls=client and client.PlayerControls
		return controls and controls.activeController
	end
	local function characterAction(name,...)
		local args=table.pack(...)
		return safe(function()
			local character=getCharacter()
			if not character or type(character[name])~="function" then return false end
			character[name](character,table.unpack(args,1,args.n))
			return true
		end)
	end
	function Actions.attack() return characterAction("Attack") end
	function Actions.jump() return characterAction("Jump") end
	function Actions.rollMud() return characterAction("Roll","Mud") end
	function Actions.sniff()
		return safe(function()
			if not getCharacter() then return false end
			local Sonar=module("Sonar")
			local sniff=Sonar and Sonar("Sniff")
			if not sniff or type(sniff.Sniff)~="function" then return false end
			sniff:Sniff()
			return true
		end)
	end
	function Actions.setSprint(enabled)
		return safe(function()
			if enabled and not getCharacter() then return false end
			local service=module("SprintService")
			if not service then return false end
			if enabled then service:Sprint() else service:StopSprinting() end
			return true
		end)
	end

	local function findFoodAction(object)
		local Food=module("Food")
		if not Food or type(Food.GetFoodFromModel)~="function" then return nil end
		local food=Food.GetFoodFromModel(object)
		local menu=food and food.ProximityMenu
		local actions=menu and menu.Actions
		if type(actions)~="table" then return nil end
		for _,action in ipairs(actions) do
			if type(action)=="table"
				and action.Hint=="Eat"
				and type(action.Run)=="function"
				and type(action.End)=="function" then
				return action
			end
		end
		return nil
	end

	local function findDrinkAction()
		if type(filtergc)~="function" then return nil end
		local run=filtergc("function",{
			Constants={"StartDrink"},
			IgnoreExecutor=true,
		},true)
		if type(run)~="function" then return nil end
		local action=filtergc("table",{
			Keys={"Run","End","InteractMenu"},
			Values={run},
		},true)
		if type(action)=="table" and type(action.Run)=="function" and type(action.End)=="function" then
			return action
		end
		return nil
	end

	function Actions.startEat(object)
		return safe(function()
			local action=findFoodAction(object)
			if not action then return false end
			action.Run()
			return true
		end)
	end

	function Actions.startDrink()
		return safe(function()
			local action
			for _=1,10 do
				action=findDrinkAction()
				if action then break end
				task.wait(0.1)
			end
			if not action then return false end
			action.Run()
			return true
		end)
	end

	function Actions.stopEatDrink()
		return characterAction("StopEatDrink")
	end

	local function movement(controller,x,z)
		controller.leftValue=math.min(x,0)
		controller.rightValue=math.max(x,0)
		controller.forwardValue=math.min(z,0)
		controller.backwardValue=math.max(z,0)
		controller:UpdateMovement(nil)
	end
	function Actions.setMovement(x,z)
		return safe(function()
			x,z=x or 0,z or 0
			if type(x)~="number" or type(z)~="number" or x~=x or z~=z then return false end
			local controller=getController()
			if lastController and lastController~=controller then
				pcall(movement,lastController,0,0)
				lastController=nil
			end
			if not controller then return false end
			if (x~=0 or z~=0) and not getCharacter() then
				movement(controller,0,0)
				lastController=nil
				return false
			end
			x,z=math.clamp(x,-1,1),math.clamp(z,-1,1)
			lastController=controller
			movement(controller,x,z)
			if x==0 and z==0 then lastController=nil end
			return true
		end)
	end
	function Actions.moveForward() return Actions.setMovement(0,-1) end
	function Actions.stopMovement()
		local previous=lastController
		lastController=nil
		if previous then pcall(movement,previous,0,0) end
		return Actions.setMovement(0,0)
	end
	return Actions
end
