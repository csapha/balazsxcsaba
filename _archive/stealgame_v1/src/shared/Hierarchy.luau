-- Segédek a strukturált eléréshez (path alapú find / ensure).
-- Példa:
--   Hierarchy.find(Workspace, { "Map", "Mine", "MineRock" })
--   Hierarchy.ensureFolder(Workspace, { "Drops" })

local Hierarchy = {}

function Hierarchy.find(root, path)
	local current = root
	for _, name in ipairs(path) do
		if not current then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

function Hierarchy.ensureFolder(root, path)
	local current = root
	for _, name in ipairs(path) do
		local child = current:FindFirstChild(name)
		if not child then
			child = Instance.new("Folder")
			child.Name = name
			child.Parent = current
		end
		current = child
	end
	return current
end

return Hierarchy
