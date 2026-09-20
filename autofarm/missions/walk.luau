-- Conclui DistanceTravelled por saltos de teleporte validos dentro do proprio bioma.
return function(r)
	local progress,ground,regionAt,status,pause=r.progress,r.ground,r.regionAt,r.status,r.pause
	local m={kind="DistanceTravelled"}

	local function destinationAround(origin,name,index)
		local radii={55,80,105,130}
		local radius=radii[((index-1)%#radii)+1]
		local angle=(index*2.399963229728653)
		local point=origin+Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius)
		local hit=ground(point)
		if not hit or hit.Material==Enum.Material.Water then return nil end
		if regionAt(hit.Position)~=name then return nil end
		return hit.Position
	end

	function m.run(name,snapshot,attempted)
		local a,b=progress(name,m.kind)
		if a>=b or attempted then return false end

		status(name.." | Teleportando distancia "..a.."/"..b)
		local startLife=r.survival.snapshot().lifeId
		local origin=snapshot.character.Root.Position
		local lastProgress=a
		local stagnant=0

		for index=1,28 do
			if not r.active() then return false end
			local currentSnapshot=r.survival.snapshot()
			if not currentSnapshot.alive or currentSnapshot.lifeId~=startLife then return false end

			local destination=destinationAround(origin,name,index)
			if destination then
				local root=currentSnapshot.character.Root
				local height=root.Size.Y/2+2.5
				local final=destination+Vector3.new(0,height,0)
				if regionAt(final)==name then
					local look=final+Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)
					root.CFrame=CFrame.new(final,look)
					root.AssemblyLinearVelocity=Vector3.zero
					root.AssemblyAngularVelocity=Vector3.zero
					if not pause(0.18) then return false end
				end
			end

			a,b=progress(name,m.kind)
			if a>=b then
				status(name.." | DistanceTravelled concluida")
				return true
			end
			if a>lastProgress then
				lastProgress=a
				stagnant=0
			else
				stagnant=stagnant+1
				if stagnant>=8 then break end
			end
		end
		return lastProgress>a
	end

	return m
end
