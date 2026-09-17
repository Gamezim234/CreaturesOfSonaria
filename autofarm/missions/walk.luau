-- Executa os movimentos da missao de distancia percorrida.
return function(r)
	local progress,ground,regionAt,status,pause=r.progress,r.ground,r.regionAt,r.status,r.pause
	local m={kind="DistanceTravelled"}
	function m.run(name,snapshot,attempted)
		local c=snapshot.character
		local a, b = progress(name, "DistanceTravelled")
		if a < b and not attempted then
			local humanoid = c.Model and c.Model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local angle = math.random() * math.pi * 2
				local point = c.Root.Position + Vector3.new(math.cos(angle)*35, 0, math.sin(angle)*35)
				local hit = ground(point)
				if hit and hit.Material ~= Enum.Material.Water and math.abs(hit.Position.Y-c.Root.Position.Y) < 15 and regionAt(hit.Position) == name then
					status(name .. " | Caminhando " .. a .. "/" .. b)
					humanoid:MoveTo(hit.Position)
					pause(4)
					humanoid:Move(Vector3.zero)
				end
			end
		end

	end
	return m
end
