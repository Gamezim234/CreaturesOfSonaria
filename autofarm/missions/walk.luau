-- Executa os movimentos da missao de distancia percorrida.
return function(r)
	local progress,ground,regionAt,status,pause=r.progress,r.ground,r.regionAt,r.status,r.pause
	local m={kind="DistanceTravelled"}
	function m.run(name,snapshot,attempted)
		local c=snapshot.character
		local a, b = progress(name, "DistanceTravelled")
		if a < b and not attempted then
			local angle = math.random() * math.pi * 2
			local point = c.Root.Position + Vector3.new(math.cos(angle)*35, 0, math.sin(angle)*35)
			local hit = ground(point)
			if hit and hit.Material ~= Enum.Material.Water and math.abs(hit.Position.Y-c.Root.Position.Y) < 15 and regionAt(hit.Position) == name then
				status(name .. " | Caminhando " .. a .. "/" .. b)
				local ok,err=pcall(function()
					local deadline=os.clock()+4
					while r.active() and os.clock()<deadline do
						local current=r.Client:GetCurrentCharacter()
						if current~=c then break end
						local delta=hit.Position-current.Root.Position
						local direction=Vector3.new(delta.X,0,delta.Z)
						if direction.Magnitude<2 then break end
						direction=direction.Unit
						local camera=workspace.CurrentCamera
						if not camera then break end
						local look,right=camera.CFrame.LookVector,camera.CFrame.RightVector
						local forward=Vector3.new(look.X,0,look.Z)
						right=Vector3.new(right.X,0,right.Z)
						if forward.Magnitude<0.01 or right.Magnitude<0.01 then break end
						if not r.actions.setMovement(direction:Dot(right.Unit),-direction:Dot(forward.Unit)) then break end
						if not pause(0.1) then break end
					end
				end)
				r.actions.stopMovement()
				r.actions.setSprint(false)
				if not ok then error(err,0) end
			end
		end

	end
	return m
end