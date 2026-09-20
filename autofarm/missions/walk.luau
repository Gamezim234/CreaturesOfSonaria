-- Completa DistanceTravelled com saltos de teleporte dentro do mesmo bioma.
return function(r)
	local progress,ground,regionAt,status,pause=r.progress,r.ground,r.regionAt,r.status,r.pause
	local m={kind="DistanceTravelled"}

	local function validPoint(origin,name,distance,angle)
		local point=origin+Vector3.new(math.cos(angle)*distance,0,math.sin(angle)*distance)
		local hit=ground(point)
		if not hit or hit.Material==Enum.Material.Water then return nil end
		if regionAt(hit.Position)~=name then return nil end
		return hit.Position
	end

	local function teleport(root,position)
		local height=root.Size.Y/2+3
		root.CFrame=CFrame.new(position+Vector3.new(0,height,0),position+Vector3.new(0,height,1))
		root.AssemblyLinearVelocity=Vector3.zero
		root.AssemblyAngularVelocity=Vector3.zero
	end

	function m.run(name,snapshot,attempted)
		local a,b=progress(name,m.kind)
		if a>=b or attempted then return false end
		status(name.." | Teleportando para DistanceTravelled "..a.."/"..b)

		local character=snapshot.character
		if not character or not character.Root then return false end
		local root=character.Root
		local origin=root.Position
		local lastAmount=a
		local progressed=false

		for _=1,10 do
			if not r.active() then break end
			local current=r.Client:GetCurrentCharacter()
			if current~=character or not current.Root then break end
			local amount,target=progress(name,m.kind)
			if amount>=target then return true end

			local destination
			for _=1,16 do
				local distance=80+math.random()*140
				local angle=math.random()*math.pi*2
				destination=validPoint(current.Root.Position,name,distance,angle)
				if destination then break end
			end

			if not destination then
				status(name.." | DistanceTravelled: nenhum ponto seguro encontrado")
				break
			end

			teleport(current.Root,destination)

			if not pause(0.18) then break end
			local after=select(1,progress(name,m.kind))
			if after>lastAmount then
				lastAmount=after
				progressed=true
				status(name.." | DistanceTravelled "..after.."/"..b)
			end
		end

		local current=r.Client:GetCurrentCharacter()
		if current and current.Root and regionAt(current.Root.Position)~=name then
			local hit=ground(origin)
			if hit and regionAt(hit.Position)==name then teleport(current.Root,hit.Position) end
		end
		return progressed
	end

	return m
end
