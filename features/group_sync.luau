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
	local WRITE_INTERVAL=0.75
	local STALE_MS=6000

	local advertised={pending={},biome=nil,priorityBiome=nil,targetBiome=nil}
	local lastPayload
	local elapsed=0
	local destroyed=false

	local Client
	pcall(function()
		local sonar=ReplicatedStorage:WaitForChild("Sonar")
		Client=require(sonar)("PlayerWrapper").GetClient()
	end)

	pcall(makefolder,FOLDER)

	local function nowMs()
		return DateTime.now().UnixTimestampMillis
	end

	local function copyMap(source)
		local result={}
		if type(source)=="table" then
			for key,value in pairs(source) do
				result[key]=value==true
			end
		end
		return result
	end

	local function vectorData(v)
		if typeof(v)~="Vector3" then return nil end
		return {x=v.X,y=v.Y,z=v.Z}
	end

	local function characterData()
		if not Client then return nil,nil end
		local ok,c=pcall(function() return Client:GetCurrentCharacter() end)
		local root=ok and c and c.Root
		if not root or not root.Parent then return nil,nil end
		return vectorData(root.Position),vectorData(root.Size)
	end

	local function buildPayload()
		local position,rootSize=characterData()
		return {
			version=2,
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
			position=position,
			rootSize=rootSize,
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

	function api.update(pendingByBiome,biome,priorityBiome)
		advertised.pending=copyMap(pendingByBiome)
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
		for key,enabled in pairs(set) do
			if enabled==true then table.insert(keys,key) end
		end
		table.sort(keys)
		return keys[1]
	end

	function api.chooseBiome()
		local members=api.members()
		local priorities={}
		local unionPending={}

		for _,member in ipairs(members) do
			if type(member.priorityBiome)=="string" and member.priorityBiome~="" then
				priorities[member.priorityBiome]=true
			end
			if type(member.pending)=="table" then
				for biome,isPending in pairs(member.pending) do
					if isPending==true then unionPending[biome]=true end
				end
			end
		end

		return firstSortedKey(priorities) or firstSortedKey(unionPending),members
	end

	function api.destroy()
		if destroyed then return end
		destroyed=true
		api.stop()
		if api.connection then
			api.connection:Disconnect()
			api.connection=nil
		end
	end

	api.connection=RunService.Heartbeat:Connect(function(dt)
		if destroyed then return end
		if not state.enabled then
			api.destroy()
			return
		end
		if not state.running then return end
		elapsed+=dt
		if elapsed<WRITE_INTERVAL then return end
		elapsed=0
		writeNow()
	end)

	return api
end
