-- Shared by the runtime builder and the Studio edit-mode preview.
local MapScenery = {}
local rgb = Color3.fromRGB
local Objects = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.Objects)
local themes = {
	watermelon = { "MELON MEADOW", rgb(105, 181, 69), rgb(239, 214, 151) },
	coconut = { "COCONUT COVE", rgb(236, 210, 146), rgb(251, 233, 184) },
	tire = { "RUBBER YARD", rgb(105, 119, 116), rgb(177, 181, 165) },
	anvil = { "EMBER FORGE", rgb(102, 91, 84), rgb(178, 148, 119) },
	fridge = { "FROST GARDEN", rgb(215, 238, 241), rgb(162, 209, 219) },
	car = { "SUNSET GARAGE", rgb(186, 164, 131), rgb(226, 203, 158) },
	tank = { "JUNGLE OUTPOST", rgb(112, 139, 74), rgb(185, 170, 117) },
	boulder = { "STONE SUMMIT", rgb(148, 161, 144), rgb(208, 205, 175) },
}

local function part(parent, name, size, cf, color, material, shape, solid)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, cf
	p.Color, p.Material = color, material or Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.Anchored, p.CanCollide = true, solid == true
	p.CanTouch, p.CanQuery = false, solid == true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if name == "Ground" or name == "LobbyGround" or name == "Walkway" or name == "StationApron" then
		p.Material = Enum.Material.Plastic
		p.TopSurface = Enum.SurfaceType.Weld
	end
	p.Parent = parent
	return p
end

-- The imported pack is kept in ServerStorage, out of the playable map.
local function natureCatalog()
	local pack = game:GetService("ServerStorage"):FindFirstChild("Stylised Low-Poly Nature Pack")
		or workspace:FindFirstChild("Stylised Low-Poly Nature Pack")
	assert(pack, "Import Stylised Low-Poly Nature Pack into ServerStorage before building the map")
	local catalog = { Trees = {}, Pines = {}, Rocks = {} }
	for _, group in ipairs(pack:GetChildren()) do
		for _, asset in ipairs(group:GetChildren()) do
			if asset:IsA("Model") or asset:IsA("BasePart") then
				local category = group.Name
				if category == "Trees" then
					for _, item in ipairs(asset:GetDescendants()) do
						if item.Name:find("TreePine", 1, true) then
							category = "Pines"
							break
						end
					end
				end
				if catalog[category] then
					table.insert(catalog[category], asset)
				end
			end
		end
	end
	for category, assets in pairs(catalog) do
		assert(#assets > 0, "Nature pack missing " .. category)
	end
	return catalog
end

local function plant(parent, catalog, category, index, position, height, rotation, snow)
	local assets = catalog[category]
	local source = assets[(index - 1) % #assets + 1]
	local model = Instance.new("Model")
	model.Name = "NaturePack_" .. category
	model:SetAttribute("NaturePackSource", source.Name)
	local clone = source:Clone()
	clone.Parent = model
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("LuaSourceContainer") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide, item.CanTouch, item.CanQuery = false, false, false
			if snow and item.Name:find("Cone", 1, true) then
				item.Color = rgb(223, 239, 240)
			end
		end
	end
	local cf, size = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(cf.Position)
	model:ScaleTo(height / math.max(size.Y, 0.01))
	model.Parent = parent
	model:PivotTo(CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, rotation, 0))

	-- Mesh bounding boxes often contain a little empty space below the visible
	-- roots. Ground the final rotated bounds, then bury the asset just enough
	-- that roots and rocks cannot appear to float.
	local placedCf, placedSize = model:GetBoundingBox()
	local bottom = placedCf.Position.Y - placedSize.Y / 2
	local bury = category == "Rocks" and 0.12 or math.clamp(height * 0.05, 0.8, 1.3)
	model:PivotTo(model:GetPivot() + Vector3.new(0, position.Y - bottom - bury, 0))
	return model
end

local DETAIL_OFFSETS = {
	Vector3.new(-56, 0, -38), Vector3.new(-49, 0, -17), Vector3.new(-54, 0, 35),
	Vector3.new(-37, 0, -69), Vector3.new(-34, 0, -31), Vector3.new(-36, 0, 44),
	Vector3.new(-22, 0, -49), Vector3.new(-20, 0, 34), Vector3.new(-12, 0, -70),
	Vector3.new(12, 0, -68), Vector3.new(18, 0, -37), Vector3.new(21, 0, 39),
	Vector3.new(34, 0, -47), Vector3.new(37, 0, 32), Vector3.new(45, 0, -23),
	Vector3.new(51, 0, 43), Vector3.new(57, 0, -62), Vector3.new(57, 0, 63),
}

local function grassCluster(parent, position, color, seed)
	local cluster = Instance.new("Model")
	cluster.Name = "WeldGrass"
	cluster.Parent = parent

	for bladeIndex = 1, 3 do
		local blade = Instance.new("WedgePart")
		local height = 0.55 + ((seed * 7 + bladeIndex * 5) % 5) * 0.09
		local width = 0.2 + ((seed + bladeIndex) % 3) * 0.055
		local angle = seed * 1.91 + bladeIndex * math.pi / 3
		local lean = (bladeIndex - 2) * 0.09
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (bladeIndex - 1) * 0.12

		blade.Name = "GrassBlade"
		blade.Size = Vector3.new(width, height, 0.11)
		blade.CFrame = CFrame.new(position + offset + Vector3.new(0, height / 2 - 0.03, 0))
			* CFrame.Angles(lean, angle, -lean)
		blade.Color = color:Lerp(rgb(224, 211, 91), bladeIndex == 2 and 0.12 or 0)
		blade.Material = Enum.Material.Plastic
		blade.Anchored = true
		blade.CanCollide, blade.CanTouch, blade.CanQuery = false, false, false
		blade.TopSurface = Enum.SurfaceType.Weld
		blade.BottomSurface = Enum.SurfaceType.Weld
		blade.Parent = cluster
	end

	return cluster
end

local function detailPart(parent, name, size, frame, color, material, shape, className)
	local p = Instance.new(className or "Part")
	p.Name, p.Size, p.CFrame = name, size, frame
	p.Color, p.Material = color, material or Enum.Material.SmoothPlastic
	if p:IsA("Part") and shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function groundDetail(parent, objectId, position, color, seed)
	if objectId == "watermelon" then
		return grassCluster(parent, position, color:Lerp(rgb(42, 135, 53), 0.42), seed)
	end

	local cluster = Instance.new("Model")
	cluster.Name = "GroundDetail_" .. objectId
	cluster.Parent = parent
	local angle = seed * 1.91

	if objectId == "coconut" then
		-- Beach pebbles and pale shell fragments.
		for i = 1, 3 do
			local diameter = 0.18 + ((seed + i) % 3) * 0.07
			local offset = Vector3.new(math.cos(angle + i * 2), 0, math.sin(angle + i * 2)) * i * 0.12
			detailPart(cluster, i == 1 and "Shell" or "BeachPebble",
				Vector3.new(diameter * 1.4, diameter * 0.45, diameter),
				CFrame.new(position + offset + Vector3.new(0, diameter * 0.16, 0)) * CFrame.Angles(0, angle + i, 0),
				i == 1 and rgb(244, 224, 178) or rgb(151, 116, 78), Enum.Material.Sand, Enum.PartType.Ball)
		end
	elseif objectId == "tire" then
		-- Short strips of discarded tread.
		for i = 1, 2 do
			detailPart(cluster, "RubberScrap", Vector3.new(0.16, 0.08, 0.45 + i * 0.08),
				CFrame.new(position + Vector3.new((i - 1.5) * 0.22, 0.04, 0)) * CFrame.Angles(0, angle + i * 1.2, 0),
				rgb(42 + i * 5, 46 + i * 5, 48 + i * 5), Enum.Material.SmoothPlastic)
		end
	elseif objectId == "anvil" then
		-- Coal chips with an occasional warm ember.
		for i = 1, 3 do
			local diameter = 0.16 + i * 0.045
			local ember = i == 2 and seed % 3 == 0
			detailPart(cluster, ember and "Ember" or "Coal", Vector3.new(diameter, diameter * 0.7, diameter),
				CFrame.new(position + Vector3.new(math.cos(angle + i) * 0.2, diameter * 0.25, math.sin(angle + i) * 0.2)),
				ember and rgb(255, 117, 42) or rgb(49, 45, 43), ember and Enum.Material.Neon or Enum.Material.Slate,
				Enum.PartType.Ball)
		end
	elseif objectId == "fridge" then
		-- Small translucent ice shards.
		for i = 1, 3 do
			local shard = detailPart(cluster, "IceShard", Vector3.new(0.16 + i * 0.025, 0.3 + i * 0.07, 0.13),
				CFrame.new(position + Vector3.new((i - 2) * 0.16, 0.13 + i * 0.025, 0))
					* CFrame.Angles(0, angle + i, (i - 2) * 0.15),
				rgb(190, 231, 240), Enum.Material.Ice, nil, "WedgePart")
			shard.Transparency = 0.12
		end
	elseif objectId == "car" then
		-- Nuts and thin metal offcuts around the garage.
		for i = 1, 2 do
			detailPart(cluster, i == 1 and "Bolt" or "MetalScrap", Vector3.new(0.14, 0.09, 0.38),
				CFrame.new(position + Vector3.new((i - 1.5) * 0.22, 0.045, 0)) * CFrame.Angles(0, angle + i, 0),
				i == 1 and rgb(111, 122, 121) or rgb(157, 92, 57), Enum.Material.Metal)
		end
	elseif objectId == "tank" then
		-- Flat jungle leaf litter, not grass blades.
		for i = 1, 3 do
			local leaf = detailPart(cluster, "FallenLeaf", Vector3.new(0.22, 0.045, 0.48),
				CFrame.new(position + Vector3.new(math.cos(angle + i * 2) * 0.22, 0.025, math.sin(angle + i * 2) * 0.22))
					* CFrame.Angles(0, angle + i * 0.9, 0),
				i % 2 == 0 and rgb(125, 104, 52) or rgb(75, 111, 48), Enum.Material.SmoothPlastic)
			leaf.TopSurface = Enum.SurfaceType.Weld
		end
	else
		-- Stone summit: irregular slate pebbles.
		for i = 1, 3 do
			local diameter = 0.2 + ((seed + i) % 4) * 0.06
			detailPart(cluster, "StoneChip", Vector3.new(diameter * 1.25, diameter * 0.55, diameter),
				CFrame.new(position + Vector3.new(math.cos(angle + i * 2.1) * 0.24, diameter * 0.2, math.sin(angle + i * 2.1) * 0.24))
					* CFrame.Angles(0, angle + i, 0),
				color:Lerp(rgb(105, 112, 108), 0.62), Enum.Material.Slate, Enum.PartType.Ball)
		end
	end

	return cluster
end

local function createZoneGate(parent, previousObject, targetObject, boundaryX)
	local gate = Instance.new("Model")
	gate.Name = string.format("Gate_%02d_%s", targetObject.index, targetObject.id)
	gate:SetAttribute("TargetObjectId", targetObject.id)
	gate:SetAttribute("TargetZoneName", (themes[targetObject.id] or { targetObject.name })[1])
	gate:SetAttribute("PreviousObjectId", previousObject.id)
	gate:SetAttribute("RequiredPower", Objects.getUnlockCost(targetObject))
	gate:SetAttribute("BoundaryX", boundaryX)
	gate.Parent = parent

	local blocker = part(
		gate,
		"ZoneBlocker",
		Vector3.new(1.5, 28, 128),
		CFrame.new(boundaryX, 14, 0),
		rgb(18, 20, 24),
		Enum.Material.SmoothPlastic,
		nil,
		false
	)
	blocker.Transparency = 1
	blocker.CastShadow = false
	blocker:SetAttribute("TargetObjectId", targetObject.id)

	-- Invisible zone wall: only the sign (progress bar + texts) shows at the
	-- gate line; the blocker below is what stops locked players.
	local wall = part(
		gate,
		"GateWall",
		Vector3.new(2.5, 26, 128),
		CFrame.new(boundaryX, 13, 0),
		rgb(8, 8, 10),
		Enum.Material.SmoothPlastic
	)
	wall.Transparency = 1
	wall.CastShadow = false

	-- Invisible panel the client paints the unlock sign on; it sits flush on
	-- the wall face and is centered on the wall (z = 0).
	local signAnchor = part(
		gate,
		"GateSign",
		Vector3.new(0.2, 22, 60),
		CFrame.new(boundaryX - 1.35, 13, 0),
		rgb(3, 4, 7),
		Enum.Material.SmoothPlastic
	)
	signAnchor.Transparency = 1
	signAnchor.CastShadow = false

	-- Player-height anchor on the walkway so the unlock prompt is right in
	-- front of the player approaching the gate.
	local promptAnchor = part(
		gate,
		"GatePromptAnchor",
		Vector3.new(1, 8, 32),
		CFrame.new(boundaryX - 0.75, 4.5, 14),
		rgb(18, 20, 24),
		Enum.Material.SmoothPlastic
	)
	promptAnchor.Transparency = 1
	promptAnchor.CastShadow = false

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZoneUnlockPrompt"
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.ActionText = "UNLOCK ZONE"
	prompt.ObjectText = targetObject.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 18
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("TargetObjectId", targetObject.id)
	prompt.Parent = promptAnchor

	return gate
end

function MapScenery.build(map, objects, spacing)
	local catalog = natureCatalog()
	local previous = map:FindFirstChild("Scenery")
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	-- Construct off-tree so a failed build leaves the previous scenery intact.
	local ok, err = pcall(function()
		local gates = Instance.new("Folder")
		gates.Name, gates.Parent = "ZoneGates", scenery
		for _, object in ipairs(objects) do
			local theme = themes[object.id] or { object.name, rgb(115, 165, 95), rgb(215, 200, 156) }
			local x = 30 + (object.index - 1) * spacing
			local zone = Instance.new("Model")
			zone.Name, zone.Parent = string.format("%02d_%s", object.index, object.id), scenery
			zone:SetAttribute("ObjectId", object.id)
			part(zone, "Earth", Vector3.new(spacing, 5, 160), CFrame.new(x, -3.5, 0), rgb(119, 87, 59), Enum.Material.Ground, nil, true)
			part(zone, "Ground", Vector3.new(spacing, 1, 160), CFrame.new(x, -0.5, 0), theme[2], Enum.Material.SmoothPlastic, nil, true)
			part(zone, "Walkway", Vector3.new(spacing, 0.08, 12), CFrame.new(x, 0.04, 14), theme[3])
			part(zone, "StationApron", Vector3.new(18, 0.09, 18), CFrame.new(x, 0.045, 0), theme[3])
			part(zone, "ZoneSeam", Vector3.new(0.5, 0.1, 160), CFrame.new(x + spacing / 2 - 0.25, 0.05, 0), theme[3])
			local groundDetails = Instance.new("Model")
			groundDetails.Name = object.id == "watermelon" and "Grass" or "GroundDetails"
			groundDetails.Parent = zone
			for detailIndex, offset in ipairs(DETAIL_OFFSETS) do
				groundDetail(
					groundDetails,
					object.id,
					Vector3.new(x, 0, 0) + offset,
					theme[2],
					object.index * 100 + detailIndex
				)
			end
			for _, z in ipairs({ -79, 79 }) do
				part(zone, "EdgeCoping", Vector3.new(spacing, 0.65, 1), CFrame.new(x, 0.325, z), theme[3], nil, nil, true)
			end
			for j, offset in ipairs({ Vector3.new(-44, 0, -57), Vector3.new(44, 0, -58), Vector3.new(-44, 0, 58), Vector3.new(44, 0, 59), Vector3.new(0, 0, -62), Vector3.new(0, 0, 62) }) do
				local pos = Vector3.new(x, 0, 0) + offset
				local scale = 1.2 + (j % 3) * 0.15
				if object.id == "boulder" then
					plant(zone, catalog, "Rocks", j, pos, 12 + j, j * 1.7)
				else
					local category = (object.id == "fridge" or object.id == "tank") and "Pines" or "Trees"
					local treeVariant = object.id == "watermelon" and 2 or object.index
					plant(zone, catalog, category, treeVariant, pos, 18 * scale, j * 1.7, object.id == "fridge")
				end
				if object.id == "boulder" then
					plant(zone, catalog, "Rocks", j, pos + Vector3.new(9, 0, -5), 2 + j % 3, j)
				end
			end
			local details = Instance.new("Model")
			details.Name, details.Parent = "Details", zone
			if object.id == "coconut" then
				part(details, "LagoonBank", Vector3.new(17, 0.12, 11), CFrame.new(x + 20, 0.07, -8), rgb(248, 231, 181), nil, Enum.PartType.Ball)
				part(details, "LagoonWater", Vector3.new(14, 0.13, 8), CFrame.new(x + 20, 0.12, -8), rgb(66, 189, 196), nil, Enum.PartType.Ball)
			elseif object.id == "tire" or object.id == "car" then
				part(details, "WorkshopSlab", Vector3.new(19, 0.2, 13), CFrame.new(x + 20, 0.1, -8), rgb(68, 77, 80))
				for j = 1, 3 do
					part(details, "TyreStack", Vector3.new(1.4, 3.8, 3.8), CFrame.new(x + 16, 0.7 + (j - 1) * 1.4, -8) * CFrame.Angles(0, 0, math.pi / 2), rgb(37, 42, 46), nil, Enum.PartType.Cylinder)
				end
				for _, dx in ipairs({ 13, 27 }) do
					part(details, "AwningPost", Vector3.new(0.5, 8, 0.5), CFrame.new(x + dx, 4, -13), rgb(74, 85, 83))
				end
				part(details, "WorkshopAwning", Vector3.new(19, 0.5, 9), CFrame.new(x + 20, 8, -11), object.id == "car" and rgb(219, 104, 65) or rgb(233, 187, 66))
			elseif object.id == "anvil" then
				part(details, "Forge", Vector3.new(9, 5, 7), CFrame.new(x + 21, 2.5, -9), rgb(74, 65, 62), Enum.Material.Brick)
				part(details, "Fire", Vector3.new(5, 2, 0.2), CFrame.new(x + 21, 2, -5.4), rgb(255, 147, 57), Enum.Material.Neon)
				part(details, "Chimney", Vector3.new(3, 8, 3), CFrame.new(x + 23, 9, -10), rgb(86, 79, 74), Enum.Material.Brick)
			elseif object.id == "tank" then
				for j = 1, 4 do
					part(details, "SupplyCrate", Vector3.new(3, 3, 3), CFrame.new(x + 16 + (j % 2) * 3.3, 1.5 + math.floor((j - 1) / 2) * 3, -9), rgb(112, 106, 62), Enum.Material.WoodPlanks)
				end
			end
			if #details:GetChildren() > 0 then
				details:PivotTo(details:GetPivot() + Vector3.new(object.id == "watermelon" and -16 or 16, 0, -24))
			end
		end
		for targetIndex = 2, #objects do
			local previousObject = objects[targetIndex - 1]
			local targetObject = objects[targetIndex]
			local previousX = 30 + (previousObject.index - 1) * spacing
			createZoneGate(gates, previousObject, targetObject, previousX + spacing / 2)
		end
		-- The lobby connects the existing spawn at the origin to the first zone.
		part(scenery, "LobbyGround", Vector3.new(36, 1, 160), CFrame.new(12 - spacing / 2, -0.5, 0), rgb(105, 181, 69), nil, nil, true)
		part(scenery, "LobbyEarth", Vector3.new(36, 5, 160), CFrame.new(12 - spacing / 2, -3.5, 0), rgb(119, 87, 59), Enum.Material.Ground, nil, true)

		-- Invisible barriers around the map so nobody can fall off the edge.
		local minX = 12 - spacing / 2 - 18
		local maxX = 30 + (#objects - 1) * spacing + spacing / 2
		local barrierHeight = 30
		local barrierLength = maxX - minX
		local midX = (minX + maxX) / 2
		local barriers = {
			part(scenery, "BarrierLeft", Vector3.new(2, barrierHeight, 160), CFrame.new(minX, barrierHeight / 2, 0), rgb(0, 0, 0), nil, nil, true),
			part(scenery, "BarrierRight", Vector3.new(2, barrierHeight, 160), CFrame.new(maxX, barrierHeight / 2, 0), rgb(0, 0, 0), nil, nil, true),
			part(scenery, "BarrierBack", Vector3.new(barrierLength, barrierHeight, 2), CFrame.new(midX, barrierHeight / 2, -80), rgb(0, 0, 0), nil, nil, true),
			part(scenery, "BarrierFront", Vector3.new(barrierLength, barrierHeight, 2), CFrame.new(midX, barrierHeight / 2, 80), rgb(0, 0, 0), nil, nil, true),
		}
		for _, barrier in ipairs(barriers) do
			barrier.Transparency = 1
			barrier.CastShadow = false
		end
	end)
	if not ok then
		scenery:Destroy()
		error(err)
	end
	if previous then
		previous:Destroy()
	end
	scenery.Parent = map
	return scenery
end

return MapScenery
