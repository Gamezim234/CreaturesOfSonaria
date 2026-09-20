-- Sincroniza varias instancias locais do autofarm pelo filesystem compartilhado do Real.
return function(ctx)
	local HttpService=game:GetService("HttpService")
	local RunService=game:GetService("RunService")
	local ReplicatedStorage=game:GetService("ReplicatedStorage")
	local state=ctx.state
	local player=ctx.player
	local api:any={}

	local FOLDER="CoS_Sync"
	local OWN_FILE=FOLDER.."/"..tostring(player.UserId)..".json"
	local WRITE_INTERVAL=0.60
	local STALE_MS=5000

	local advertised={pending={},attackPending={},biome=nil,priorityBiome=nil,targetBiome=nil}
	local lastPayload
	local elapsed=0
	local destroyed=false
	local lastCharacter
	local lastRoot
	local lifeId

	local Client
	pcall(function()
		local sonar=ReplicatedStorage:FindFirstChild("Sonar") :: any
		if not sonar then return end
		local Sonar=require(sonar)
		Client=Sonar("PlayerWrapper").GetClient()
	end)

	pcall(makefolder,FOLDER)

	local function nowMs()
		return DateTime.now().UnixTimestampMillis
	end

	local function copyMap(source)
		local result={}
		if type(source)=="table" then
			for key,value in pairs(source) do result[key]=value==true end
		end
		return result
	end

	local function vectorData(v)
		if typeof(v)~="Vector3" then return nil end
		return {x=v.X,y=v.Y,z=v.Z}
	end

	local function readStat(c,slot,names,modified)
		for _,name in ipairs(names) do
			local child=slot and slot:FindFirstChild(name)
			if child and type(child.Value)=="number" then return child.Value end
			if c and c.CharacterData then
				local value
				pcall(function()
					value=modified and c.CharacterData:GetWithModifiers(name) or c.CharacterData:Get(name)
				end)
				if type(value)=="number" then return value end
			end
			local model=c and c.Model or player.Character
			local data=model and model:FindFirstChild("Data")
			if data then
				local attr=data:GetAttribute(name)
				if type(attr)=="number" then return attr end
			end
		end
		return nil
	end

	local function ailments(c)
		local result={}
		local model=c and c.Model or player.Character
		local folder=model and model:FindFirstChild("Ailments")
		if folder then
			for name,value in pairs(folder:GetAttributes()) do
				if value==true or (type(value)=="number" and value>0) then result[name]=value end
			end
		end
		return result
	end

	local function characterData()
		if not Client then return {} end
		local c,slot
		pcall(function() c=Client:GetCurrentCharacter() end)
		pcall(function() slot=Client:GetCurrentSlot() end)
		local root=c and c.Root
		local health=slot and slot:FindFirstChild("Health")
		local alive=root and root.Parent and health and type(health.Value)=="number" and health.Value>0

		if alive and (c~=lastCharacter or root~=lastRoot) then
			lastCharacter=c
			lastRoot=root
			lifeId=tostring(player.UserId)..":"..tostring(nowMs())
		end

		local maximum=readStat(c,slot,{"Health","MaxHealth"},true)
		if type(maximum)~="number" or maximum<=0 then
			local model=c and c.Model or player.Character
			local data=model and model:FindFirstChild("Data")
			maximum=data and (data:GetAttribute("mh") or data:GetAttribute("MaxHealth")) or nil
		end
		if health and (type(maximum)~="number" or maximum<=0) then maximum=math.max(health.Value,1) end

		local age=readStat(c,slot,{"Age","Growth","GrowthValue"},false)
		local damage=readStat(c,slot,{"Damage","BiteDamage"},true)

		return {
			alive=alive==true,
			lifeId=lifeId,
			position=alive and vectorData(root.Position) or nil,
			rootSize=alive and vectorData(root.Size) or nil,
			health=health and health.Value or nil,
			maxHealth=maximum,
			healthPct=health and maximum and maximum>0 and math.clamp(health.Value/maximum,0,1) or nil,
			age=age,
			damage=damage,
			ailments=ailments(c),
		}
	end

	local function buildPayload()
		local character=characterData()
		return {
			version=3,
			userId=player.UserId,
			name=player.Name,
			jobId=game.JobId,
			placeId=game.PlaceId,
			gameId=game.GameId,
			updatedAt=nowMs(),
			running=state.running==true,
			biome=advertised.biome,
			priorityBiome=advertised.priorityBiome,
			targetBiome=advertised.targetBiome,
			pending=copyMap(advertised.pending),
			attackPending=copyMap(advertised.attackPending),
			position=character.position,
			rootSize=character.rootSize,
			alive=character.alive,
			lifeId=character.lifeId,
			health=character.health,
			maxHealth=character.maxHealth,
			healthPct=character.healthPct,
			age=character.age,
			damage=character.damage,
			ailments=character.ailments,
			recovering=state.recovering==true or state.survivalBusy==true,
		}
	end

	local function writeNow()
		if destroyed or not state.running then return false end
		local payload=buildPayload()
		lastPayload=payload
		local ok,encoded=pcall(HttpService.JSONEncode,HttpService,payload)
		if not ok then return false end
		return pcall(writefile,OWN_FILE,encoded)
	end

	function api.update(pendingByBiome,biome,priorityBiome,attackPendingByBiome)
		advertised.pending=copyMap(pendingByBiome)
		advertised.attackPending=copyMap(attackPendingByBiome)
		advertised.biome=type(biome)=="string" and biome or nil
		advertised.priorityBiome=type(priorityBiome)=="string" and priorityBiome or nil
		writeNow()
	end

	function api.setTarget(targetBiome)
		advertised.targetBiome=type(targetBiome)=="string" and targetBiome or nil
	end

	function api.stop()
		advertised.targetBiome=nil
		advertised.priorityBiome=nil
		lastPayload=nil
		pcall(function()
			if isfile(OWN_FILE) then delfile(OWN_FILE) end
		end)
	end

	local function validMember(data,currentTime)
		if type(data)~="table" or data.running~=true then return false end
		if data.jobId~=game.JobId or data.placeId~=game.PlaceId or data.gameId~=game.GameId then return false end
		if type(data.userId)~="number" or type(data.updatedAt)~="number" then return false end
		local age=currentTime-data.updatedAt
		return age>=-2000 and age<=STALE_MS
	end

	function api.members()
		local result={}
		local foundSelf=false
		local currentTime=nowMs()
		local okList,paths=pcall(listfiles,FOLDER)
		if okList and type(paths)=="table" then
			for _,path in ipairs(paths) do
				if string.sub(string.lower(path),-5)==".json" and isfile(path) then
					local okRead,raw=pcall(readfile,path)
					if okRead and type(raw)=="string" then
						local okDecode,data=pcall(HttpService.JSONDecode,HttpService,raw)
						if okDecode and validMember(data,currentTime) then
							table.insert(result,data)
							if data.userId==player.UserId then foundSelf=true end
						end
					end
				end
			end
		end

		if state.running and not foundSelf and lastPayload then
			local localCopy={}
			for key,value in pairs(lastPayload) do localCopy[key]=value end
			localCopy.updatedAt=currentTime
			table.insert(result,localCopy)
		end

		table.sort(result,function(a,b) return a.userId<b.userId end)
		return result
	end

	local function firstSortedKey(set)
		local keys={}
		for key,enabled in pairs(set) do if enabled==true then table.insert(keys,key) end end
		table.sort(keys)
		return keys[1]
	end

	function api.chooseBiome()
		local members=api.members()
		local priorities={}
		local unionPending={}
		for _,member in ipairs(members) do
			if type(member.priorityBiome)=="string" and member.priorityBiome~="" then priorities[member.priorityBiome]=true end
			if type(member.pending)=="table" then
				for biome,isPending in pairs(member.pending) do if isPending==true then unionPending[biome]=true end end
			end
		end
		return firstSortedKey(priorities) or firstSortedKey(unionPending),members
	end

	function api.destroy()
		if destroyed then return end
		destroyed=true
		api.stop()
		if api.connection then api.connection:Disconnect();api.connection=nil end
	end

	api.connection=RunService.Heartbeat:Connect(function(dt)
		if destroyed then return end
		if not state.enabled then api.destroy();return end
		if not state.running then return end
		elapsed+=dt
		if elapsed<WRITE_INTERVAL then return end
		elapsed=0
		writeNow()
	end)

	return api
end
