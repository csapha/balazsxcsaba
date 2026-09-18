-- Csákány a kézbe.
-- A modellben lévő "Handle" partot használja fogásként (ha nincs, csinál egyet).
-- A többi alkatrészt ehhez hegeszti, majd Tool-ként a játékos kezébe adja.

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.Game)
local Hierarchy = require(Shared.Hierarchy)

local PickaxeService = {}

local TOOL_NAME = "Pickaxe"
local FALLBACK_HANDLE_OFFSET = 0.85 -- ha nincs Handle a modellben (a nyél aljától)
local TOOL_SCALE = 1.35 -- a csákány mérete a kézben (1.0 = eredeti)

-- Fogás beállítása: a csákány függőlegesen, enyhén előredöntve áll a kézben,
-- a penge pedig előre néz.
-- Ha nem stimmel, csak ezeket a szögeket hangold (fok):
local GRIP_TILT_FORWARD = -20 -- előre döntés (negatív = előre)
local GRIP_ROLL = -90         -- elforgatás a nyél tengelye körül (penge előre)

-- sablon keresési sorrend:
--   ServerStorage.Templates.Pickaxes.DefaultPickaxe -> ReplicatedStorage.Assets -> Workspace
local function findModel()
	local template = Hierarchy.find(ServerStorage, GameConfig.Paths.PickaxeTemplates)
	if template then
		return template
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets then
		local model = assets:FindFirstChild("DefaultPickaxe")
		if model then
			return model
		end
	end

	return Workspace:FindFirstChild("DefaultPickaxe")
end

local function makeFallbackHandle(pivot)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.35, 0.55, 0.35)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.CFrame = pivot * CFrame.new(0, FALLBACK_HANDLE_OFFSET, 0)
	return handle
end

local function buildTool()
	local model = findModel()
	if not model then
		return nil
	end

	local clone = model:Clone()

	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.Massless = true
		end
	end

	local handle = clone:FindFirstChild("Handle")
	if not (handle and handle:IsA("BasePart")) then
		handle = makeFallbackHandle(clone:GetPivot())
	end

	-- méretezés a fogási pont körül (a modell összes részére)
	if TOOL_SCALE ~= 1.0 then
		local base = handle.CFrame
		for _, descendant in ipairs(clone:GetDescendants()) do
			if descendant:IsA("BasePart") then
				local offset = descendant.CFrame.Position - base.Position
				descendant.Size = descendant.Size * TOOL_SCALE
				descendant.CFrame = CFrame.new(base.Position + offset * TOOL_SCALE)
					* descendant.CFrame.Rotation
			end
		end
	end

	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Mine the rock"

	handle.Parent = tool

	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= handle then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = descendant
			weld.Parent = descendant
			descendant.Parent = tool
		end
	end

	clone:Destroy()

	tool.Grip = CFrame.new(0, 0, 0)
		* CFrame.Angles(0, math.rad(GRIP_ROLL), 0)
		* CFrame.Angles(math.rad(GRIP_TILT_FORWARD), 0, 0)

	return tool
end

local function give(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	if backpack:FindFirstChild(TOOL_NAME) then
		return
	end

	local character = player.Character
	if character and character:FindFirstChild(TOOL_NAME) then
		return
	end

	local tool = buildTool()
	if not tool then
		warn("[PickaxeService] Nem találom a DefaultPickaxe modellt!")
		return
	end

	tool.Parent = backpack

	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:EquipTool(tool)
	end
end

function PickaxeService.init()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			give(player)
		end)
		task.wait(0.2)
		give(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		give(player)
	end
end

return PickaxeService
