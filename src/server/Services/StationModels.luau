-- Authored, asset-free station props. Coordinates are in a one-stud design space.
-- Keep the invisible interaction root a BasePart for prompts and cinematics.
local StationModels = {}
local rgb = Color3.fromRGB
local v = Vector3.new
local cf = CFrame.new
local angles = CFrame.Angles
local pi = math.pi
local wood = Enum.Material.Wood
local metal = Enum.Material.Metal
local dark = rgb(39, 46, 48)
local steel = rgb(130, 151, 157)

local function part(parent, name, size, frame, color, material, shape)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, frame
	p.Color, p.Material = color, material or Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function builder(parent, origin, scale)
	return function(name, size, position, color, material, shape, rotation)
		return part(parent, name, size * scale, origin * cf(position * scale) * (rotation or cf()), color, material, shape)
	end
end

local function ball(add, name, size, pos, color, material, rotation)
	local p = add(name, size, pos, color, material, nil, rotation)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- Cylinders have their axle along local X.
local function disc(add, name, diameter, depth, pos, color, rotation, material)
	return add(name, v(depth, diameter, diameter), pos, color, material, Enum.PartType.Cylinder, rotation)
end

local recipes = {}

function recipes.watermelon(add)
	ball(add, "Rind", v(1.08, 1, 1), v(0, 0, 0), rgb(104, 174, 51))
	-- Thin overlapping surface patches follow the ellipsoid, including its poles.
	for stripe = 0, 9 do
		for step = 0, 15 do
			local latitude = -pi / 2 + (step + 0.5) * pi / 16
			local longitude = stripe * 2 * pi / 10 + 0.055 * math.sin(latitude * 5 + stripe)
			local normal = v(math.cos(latitude) * math.cos(longitude), math.sin(latitude), math.cos(latitude) * math.sin(longitude))
			local position = normal * v(0.542, 0.502, 0.502)
			local tangent = v(-math.sin(longitude), 0, math.cos(longitude))
			local up = normal:Cross(tangent).Unit
			local rotation = CFrame.fromMatrix(v(0, 0, 0), tangent, up, normal)
			add("RindStripe", v(0.082 * math.cos(latitude) + 0.014, 0.113, 0.012), position,
				stripe % 2 == 0 and rgb(28, 103, 43) or rgb(40, 119, 44), nil, nil, rotation)
		end
	end
	disc(add, "StemScar", 0.13, 0.035, v(0, 0.499, 0), rgb(114, 124, 39), angles(0, 0, pi / 2))
	add("Stem", v(0.055, 0.16, 0.055), v(0.018, 0.575, 0), rgb(86, 98, 36), wood, nil, angles(0, 0, -0.28))
	ball(add, "Leaf", v(0.25, 0.025, 0.12), v(0.13, 0.57, 0), rgb(54, 139, 45), nil, angles(0.1, -0.4, -0.3))
end

function recipes.coconut(add)
	ball(add, "Husk", v(0.98, 1, 0.92), v(0, 0, 0), rgb(128, 83, 45), Enum.Material.Sand)
	for stripe = 0, 13 do
		for step = 0, 6 do
			local latitude = -1.2 + step * 0.37
			local longitude = stripe * pi / 7 + 0.025 * math.sin(step * 3 + stripe)
			local normal = v(math.cos(latitude) * math.cos(longitude), math.sin(latitude), math.cos(latitude) * math.sin(longitude))
			local tangent = v(-math.sin(longitude), 0, math.cos(longitude))
			ball(add, "HuskFibre", v(0.012, 0.18, 0.012), normal * v(0.489, 0.501, 0.461),
				stripe % 3 == 0 and rgb(168, 116, 65) or rgb(95, 59, 34), wood,
				CFrame.fromMatrix(v(0, 0, 0), tangent, normal:Cross(tangent).Unit, normal))
		end
	end
	-- Three dark pores on the upper, player-facing end.
	local normal = v(0, 0.68, 0.733).Unit
	local face = CFrame.lookAt(normal * 0.475, normal)
	for _, offset in ipairs({v(-0.105, 0.045, 0), v(0.105, 0.045, 0), v(0, -0.115, 0)}) do
		local pos = face:PointToWorldSpace(offset)
		ball(add, "EyeRim", v(0.145, 0.13, 0.045), pos, rgb(96, 59, 31), nil, face.Rotation)
		ball(add, "Eye", v(0.088, 0.075, 0.046), pos + normal * 0.021, rgb(44, 30, 22), nil, face.Rotation)
	end
end

function recipes.tire(add)
	-- An actual open ring, with rounded sidewalls and alternating tread blocks.
	for i = 0, 31 do
		local a = i * pi / 16
		local rotation = angles(0, 0, a)
		local center = v(-math.sin(a) * 0.365, math.cos(a) * 0.365, 0)
		add("RubberTread", v(0.092, 0.265, 0.33), center, rgb(31, 35, 39), nil, nil, rotation)
		for _, side in ipairs({-1, 1}) do
			ball(add, "Sidewall", v(0.12, 0.22, 0.12), center + v(0, 0, side * 0.155), rgb(44, 49, 53), nil, rotation)
			add("TreadLug", v(0.063, 0.032, 0.17),
				v(-math.sin(a) * 0.494, math.cos(a) * 0.494, side * 0.083), rgb(53, 59, 62), nil, nil,
				rotation * angles(0, side * 0.3, 0))
		end
	end
end

function recipes.anvil(add)
	add("Foot", v(0.8, 0.13, 0.63), v(-0.03, -0.435, 0), dark, metal)
	add("Base", v(0.62, 0.15, 0.48), v(-0.03, -0.3, 0), rgb(68, 79, 86), metal)
	add("Waist", v(0.37, 0.35, 0.31), v(-0.07, -0.075, 0), rgb(77, 87, 94), metal)
	add("Shoulder", v(0.64, 0.16, 0.44), v(-0.04, 0.15, 0), rgb(93, 105, 111), metal)
	add("Face", v(0.79, 0.16, 0.48), v(-0.08, 0.31, 0), steel, metal)
	add("FacePolish", v(0.72, 0.018, 0.42), v(-0.08, 0.399, 0), rgb(185, 201, 202), metal)
	for i = 0, 5 do
		local diameter = 0.34 * (1 - i / 6)
		disc(add, "TaperedHorn", diameter, 0.075, v(0.335 + i * 0.059, 0.26, 0), steel, nil, metal)
	end
	add("HardySocket", v(0.07, 0.007, 0.07), v(-0.33, 0.411, 0.1), dark)
end

function recipes.fridge(add)
	add("Cabinet", v(0.65, 0.94, 0.57), v(0, 0.03, 0), rgb(196, 221, 222), metal)
	add("DoorSeal", v(0.62, 0.9, 0.027), v(0, 0.035, 0.296), dark)
	add("FreezerDoor", v(0.6, 0.265, 0.065), v(0, 0.34, 0.332), rgb(233, 244, 235), metal)
	add("FridgeDoor", v(0.6, 0.59, 0.065), v(0, -0.104, 0.332), rgb(221, 237, 232), metal)
	for _, y in ipairs({0.315, 0.07}) do
		add("HandleMount", v(0.052, 0.14, 0.058), v(-0.215, y, 0.39), dark)
		add("ChromeHandle", v(0.036, 0.18, 0.045), v(-0.215, y, 0.426), steel, metal)
	end
	add("Badge", v(0.14, 0.036, 0.009), v(0.13, 0.395, 0.369), steel, metal)
	add("VentPlate", v(0.56, 0.06, 0.022), v(0, -0.445, 0.296), dark)
	for i = -3, 3 do
		add("VentSlat", v(0.025, 0.035, 0.012), v(i * 0.065, -0.445, 0.313), steel)
	end
	for _, x in ipairs({-0.23, 0.23}) do
		for _, z in ipairs({-0.2, 0.2}) do
			add("Foot", v(0.085, 0.06, 0.085), v(x, -0.47, z), dark)
		end
	end
end

local function wheel(add, x, y, z, radius)
	disc(add, "Tire", radius * 2, 0.105, v(x, y, z), rgb(32, 37, 41))
	disc(add, "AlloyRim", radius * 1.25, 0.112, v(x, y, z), steel, nil, metal)
	disc(add, "Hub", radius * 0.5, 0.119, v(x, y, z), dark, nil, metal)
end

function recipes.car(add)
	local red = rgb(206, 58, 43)
	add("Chassis", v(0.61, 0.11, 1.04), v(0, -0.29, 0), dark)
	add("Body", v(0.68, 0.2, 1.07), v(0, -0.155, 0), red)
	add("Hood", v(0.65, 0.065, 0.29), v(0, -0.027, 0.36), rgb(223, 70, 47))
	add("CabinGlass", v(0.55, 0.245, 0.49), v(0, 0.055, -0.055), rgb(68, 132, 152), Enum.Material.Glass)
	add("Roof", v(0.58, 0.045, 0.51), v(0, 0.19, -0.055), red)
	for _, x in ipairs({-0.287, 0.287}) do
		for _, z in ipairs({-0.285, -0.04, 0.175}) do
			add("WindowPillar", v(0.03, 0.26, 0.035), v(x, 0.055, z), red)
		end
		add("DoorHandle", v(0.014, 0.025, 0.08), v(x * 1.195, -0.07, -0.12), steel, metal)
		add("WingMirror", v(0.09, 0.057, 0.083), v(x * 1.25, 0.01, 0.14), red)
	end
	for _, x in ipairs({-0.34, 0.34}) do
		for _, z in ipairs({-0.34, 0.34}) do
			wheel(add, x, -0.36, z, 0.14)
		end
	end
	for _, z in ipairs({-0.55, 0.55}) do
		add("Bumper", v(0.64, 0.063, 0.043), v(0, -0.24, z), steel, metal)
		for _, x in ipairs({-0.235, 0.235}) do
			add("Lamp", v(0.14, 0.068, 0.014), v(x, -0.115, z), z > 0 and rgb(255, 235, 162) or rgb(255, 103, 68))
		end
	end
	add("Grille", v(0.25, 0.067, 0.014), v(0, -0.14, 0.55), dark)
	for _, x in ipairs({-0.075, 0.075}) do
		add("HoodStripe", v(0.063, 0.008, 0.265), v(x, 0.01, 0.36), rgb(249, 230, 190))
	end
end

function recipes.tank(add)
	local olive = rgb(103, 123, 66)
	add("Hull", v(0.65, 0.22, 0.83), v(0, -0.12, 0), olive, metal)
	add("UpperArmor", v(0.59, 0.1, 0.66), v(0, 0.035, -0.055), rgb(130, 144, 78), metal)
	for _, x in ipairs({-0.355, 0.355}) do
		add("TrackBody", v(0.16, 0.24, 0.82), v(x, -0.34, 0), dark)
		for i = 0, 4 do
			wheel(add, x + (x > 0 and 0.06 or -0.06), -0.355, -0.3 + i * 0.15, 0.115)
		end
		for i = 0, 10 do
			for _, y in ipairs({-0.485, -0.205}) do
				add("TrackLink", v(0.19, 0.03, 0.049), v(x, y, -0.39 + i * 0.078), rgb(72, 76, 64), metal)
			end
		end
		add("TrackGuard", v(0.22, 0.048, 0.88), v(x, -0.157, 0), olive, metal)
	end
	disc(add, "TurretRing", 0.4, 0.075, v(0, 0.11, -0.08), dark, angles(0, 0, pi / 2), metal)
	add("Turret", v(0.4, 0.19, 0.38), v(0, 0.23, -0.095), olive, metal)
	disc(add, "Hatch", 0.2, 0.038, v(-0.045, 0.344, -0.11), rgb(155, 165, 98), angles(0, 0, pi / 2), metal)
	disc(add, "Barrel", 0.079, 0.53, v(0, 0.245, 0.33), olive, angles(0, pi / 2, 0), metal)
	add("Muzzle", v(0.125, 0.11, 0.14), v(0, 0.245, 0.62), rgb(79, 93, 54), metal)
	add("MuzzleOpening", v(0.073, 0.06, 0.008), v(0, 0.245, 0.694), dark)
	add("Antenna", v(0.012, 0.21, 0.012), v(0.16, 0.42, -0.23), dark, metal)
end

function recipes.boulder(add)
	local stone = Enum.Material.Slate
	ball(add, "StoneCore", v(0.87, 0.86, 0.81), v(0, -0.07, 0), rgb(130, 141, 140), stone)
	local facets = {
		{v(0.58, 0.5, 0.69), v(-0.17, -0.08, 0.1), v(0.16, 0.25, -0.2), rgb(144, 153, 147)},
		{v(0.57, 0.6, 0.55), v(0.16, -0.09, -0.09), v(-0.12, -0.3, 0.2), rgb(117, 131, 131)},
		{v(0.54, 0.23, 0.53), v(0, 0.32, 0), v(0.1, 0.15, -0.12), rgb(165, 174, 162)},
		{v(0.28, 0.48, 0.54), v(-0.34, -0.13, -0.06), v(0.23, 0.16, 0.25), rgb(106, 121, 117)},
		{v(0.34, 0.4, 0.38), v(0.3, -0.18, 0.13), v(-0.14, -0.15, -0.2), rgb(151, 160, 147)},
	}
	for _, f in ipairs(facets) do
		ball(add, "RockFacet", f[1], f[2], f[4], stone, angles(f[3].X, f[3].Y, f[3].Z))
	end
	ball(add, "Moss", v(0.39, 0.055, 0.31), v(-0.095, 0.431, 0.035), rgb(107, 137, 67), Enum.Material.Grass)
end

function StationModels.createObject(object, position)
	local root = part(nil, object.name, v(object.size, object.size, object.size), cf(position), Color3.fromHex(object.color))
	root.Transparency = 1
	root.CastShadow = false
	root:SetAttribute("ObjectId", object.id)
	root:SetAttribute("Weight", object.weight)
	root:SetAttribute("Active", true)
	local visual = Instance.new("Model")
	visual.Name = "Visual"
	visual.Parent = root
	-- Stations progress along +X; present the front toward players arriving from -X.
	-- The anvil's horn is authored along +X, the other fronts along +Z.
	local yaw = object.id == "anvil" and pi or -pi / 2
	local visualFrame = root.CFrame * angles(0, yaw, 0)
	local recipe = assert(recipes[object.id], "Missing station model: " .. object.id)
	-- Reuse the map's faceted rock mesh when available, so its silhouette matches
	-- the surrounding nature kit. The authored recipe also works without the kit.
	local rockSource = nil
	if object.id == "boulder" then
		local pack = game:GetService("ServerStorage"):FindFirstChild("Stylised Low-Poly Nature Pack")
		local rocks = pack and pack:FindFirstChild("Rocks")
		if rocks then
			for _, candidate in ipairs(rocks:GetChildren()) do
				if candidate:IsA("MeshPart") and (not rockSource or candidate.Size.Magnitude > rockSource.Size.Magnitude) then
					rockSource = candidate
				end
			end
		end
	end
	if rockSource then
		local rock = rockSource:Clone()
		rock:ClearAllChildren()
		rock.Name = "FacetedBoulder"
		rock.Size *= object.size / math.max(rock.Size.X, rock.Size.Y, rock.Size.Z)
		rock.CFrame = visualFrame * angles(0, 0.3, 0)
		rock.Anchored, rock.CanCollide, rock.CanTouch, rock.CanQuery = true, false, false, false
		rock.Parent = visual
	else
		recipe(builder(visual, visualFrame, object.size))
	end
	local bounds, size = visual:GetBoundingBox()
	local bottom = bounds.Position.Y - size.Y / 2
	local adjustment = v(0, position.Y - object.size / 2 - bottom, 0)
	visual:PivotTo(visual:GetPivot() + adjustment)
	return root
end

function StationModels.setVisible(root, visible)
	-- The root is always invisible, including after respawn.
	root.Transparency = 1
	local visual = root:FindFirstChild("Visual")
	if visual then
		for _, p in ipairs(visual:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Transparency = visible and 0 or 1
			end
		end
	end
end

function StationModels.createTable(object, position, height)
	local model = Instance.new("Model")
	model.Name = object.name .. "Workbench"
	local add = builder(model, cf(position), 1)
	local width = (object.size + 1.4) * 1.25
	local depth = width * 1.5
	local half = width / 2
	local halfDepth = depth / 2
	local industrial = object.index >= 3
	local frameColor = industrial and rgb(60, 75, 76) or rgb(92, 65, 42)
	local plankColor = industrial and rgb(162, 133, 89) or rgb(194, 145, 86)
	local planks = math.max(4, math.ceil(width / 0.65))
	for i = 1, planks do
		local tint = (i % 3 - 1) * 0.045
		local color = plankColor:Lerp(tint > 0 and rgb(255, 239, 200) or rgb(90, 56, 30), math.abs(tint))
		local p = add("TopPlank", v(width / planks - 0.018, 0.28, depth),
			v(-half + (i - 0.5) * width / planks, height - 0.14, 0), color, wood)
		p.CanCollide = true
	end
	for _, z in ipairs({-halfDepth + 0.11, halfDepth - 0.11}) do
		add("Apron", v(width, 0.34, 0.16), v(0, height - 0.45, z), frameColor, wood)
		add("EdgeBand", v(width + 0.035, 0.065, 0.055), v(0, height - 0.075, z * (halfDepth / (halfDepth - 0.11))), rgb(111, 81, 49), metal)
	end
	for _, x in ipairs({-half + 0.3, half - 0.3}) do
		for _, z in ipairs({-halfDepth + 0.3, halfDepth - 0.3}) do
			local leg = add("Leg", v(0.38, height - 0.28, 0.38), v(x, (height - 0.28) / 2, z), frameColor, industrial and metal or wood)
			leg.CanCollide = true
			add("FootCap", v(0.46, 0.16, 0.46), v(x, 0.08, z), dark, metal)
			add("CornerBracket", v(0.43, 0.35, 0.055), v(x, height - 0.47, z + (z > 0 and 0.2 or -0.2)), dark, metal)
			for _, y in ipairs({height - 0.38, height - 0.55}) do
				disc(add, "Bolt", 0.073, 0.035, v(x, y, z + (z > 0 and 0.237 or -0.237)), steel, angles(0, pi / 2, 0), metal)
			end
		end
		add("SideStretcher", v(0.18, 0.19, depth - 0.55), v(x, 0.72, 0), frameColor, wood)
	end
	add("CrossStretcher", v(width - 0.5, 0.19, 0.19), v(0, 0.72, 0), frameColor, wood)
	return model
end

return StationModels
