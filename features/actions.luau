-- Executa as acoes confirmadas do jogo com referencias atuais e falha segura.
return function()
	local Actions={}
	local lastController
	local commandedLaying=false

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

	local function layingState(character)
		if not character then return nil end
		local names={"Laying","IsLaying","LayingDown","Resting"}
		local data=character.CharacterData
		if data then
			for _,name in ipairs(names) do
				local ok,value=pcall(function() return data:Get(name) end)
				if ok and type(value)=="boolean" then return value end
			end
		end
		local model=character.Model
		if model then
			for _,name in ipairs(names) do
				local value=model:GetAttribute(name)
				if type(value)=="boolean" then return value end
			end
		end
		for _,name in ipairs(names) do
			local ok,value=pcall(function() return character[name] end)
			if ok and type(value)=="boolean" then return value end
		end
		return nil
	end

	local function tapKey(code)
		local ok=pcall(function()
			keypress(code)
			task.wait(0.05)
			keyrelease(code)
		end)
		return ok
	end

	function Actions.isLaying()
		local detected=layingState(getCharacter())
		if detected~=nil then commandedLaying=detected end
		return detected
	end

	function Actions.setLaying(enabled)
		enabled=enabled==true
		local character=getCharacter()
		if not character then return false end
		local detected=layingState(character)
		if detected~=nil then commandedLaying=detected end
		if detected==enabled then return true end

		for _,name in ipairs({"SetLaying","SetLay","SetResting"}) do
			local fn=character[name]
			if type(fn)=="function" then
				pcall(fn,character,enabled)
				task.wait(0.15)
				detected=layingState(character)
				if detected==enabled then commandedLaying=enabled;return true end
			end
		end

		if commandedLaying~=enabled then
			tapKey(0x59)
			task.wait(0.2)
			detected=layingState(character)
			if detected~=nil then commandedLaying=detected else commandedLaying=enabled end
			if detected~=nil and detected~=enabled then
				tapKey(0x54)
				task.wait(0.2)
				detected=layingState(character)
				if detected~=nil then commandedLaying=detected end
			end
		end
		return commandedLaying==enabled or layingState(character)==enabled
	end

	local function actionFromMenu(menu,hint)
		if type(menu)~="table" or type(menu.Actions)~="table" then return nil end
		for _,action in ipairs(menu.Actions) do
			if type(action)=="table" and action.Hint==hint and type(action.Run)=="function" then
				return action
			end
		end
		return nil
	end

	local function findObjectAction(object,hint)
		if type(filtergc)~="function" or typeof(object)~="Instance" then return nil end

		local candidates={object}
		if object:IsA("Model") then
			if object.PrimaryPart then table.insert(candidates,object.PrimaryPart) end
			local root=object:FindFirstChild("Root",true)
			if root and root:IsA("BasePart") then table.insert(candidates,root) end
			local part=object:FindFirstChildWhichIsA("BasePart",true)
			if part then table.insert(candidates,part) end
		end

		for _,candidate in ipairs(candidates) do
			local direct=filtergc("table",{
				Keys={"Actions","Object"},
				Values={candidate},
			},true)
			local action=actionFromMenu(direct,hint)
			if action then return action end

			local matches=filtergc("table",{Values={candidate}},false)
			if type(matches)=="table" then
				for _,wrapper in ipairs(matches) do
					if type(wrapper)=="table" then
						action=actionFromMenu(rawget(wrapper,"ProximityMenu"),hint)
						if action then return action end
					end
				end
			end
		end

		return nil
	end

	local function runObjectAction(object,hint)
		return safe(function()
			local action
			for _=1,15 do
				action=findObjectAction(object,hint)
				if action then break end
				task.wait(0.1)
			end
			if not action then return false end
			action.Run()
			return true
		end)
	end

	function Actions.collectShoomPile(object)
		return runObjectAction(object,"Collect")
	end

	function Actions.hideScent(object)
		return runObjectAction(object,"Hide Scent")
	end

	local function findFoodAction(object)
		local Food=module("Food")
		if not Food or type(Food.GetFoodFromModel)~="function" then return nil end
		local food=Food.GetFoodFromModel(object)
		local menu=food and food.ProximityMenu
		local action=actionFromMenu(menu,"Eat")
		if action and type(action.End)=="function" then return action end
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

	function Actions.moveForward()
		return Actions.setMovement(0,-1)
	end

	function Actions.stopMovement()
		local previous=lastController
		lastController=nil
		if previous then pcall(movement,previous,0,0) end
		return Actions.setMovement(0,0)
	end

	return Actions
end
