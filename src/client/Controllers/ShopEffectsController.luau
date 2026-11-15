-- Shop effects in the world (GDD 6.2–6.3):
--   VIP: a gold "VIP" tag above VIP players' heads, a [VIP] prefix on their chat messages, and the VIP area's
--        invisible walls stop colliding for the local player when they are VIP (the character is simulated on the
--        client, so only VIPs walk in).
--   Fun products: "Tenderize the Server" shakes everyone's camera, "Schnitzel Rain" is announced in chat.
--   Egg prompts: "Open 3" / "Fast Open" text and visibility per player (Open 3 Eggs / Fast Open gamepasses).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Ui = require(ReplicatedStorage.Shared.Ui)
local Chat = require(script.Parent.Parent.Util.Chat)
local Audio = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Audio"))
local ShopWindow = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("ShopWindow"))

local player = Players.LocalPlayer
local VIP_COLOR = Config.Shop.Vip.TagColor
local VIP_HEX = VIP_COLOR:ToHex()

local ShopEffectsController = {}

local function isVip(who: Player): boolean
	return who:GetAttribute("VIP") == true
end

-- the gold VIP tag above the head (built locally for every VIP player)
local function updateTag(who: Player)
	local character = who.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local existing = head:FindFirstChild("VipTag")
	if not isVip(who) then
		if existing then
			existing:Destroy()
		end
		return
	end
	if existing then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "VipTag"
	gui.Size = UDim2.fromOffset(70, 26)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "VIP"
	label.TextScaled = true
	label.TextColor3 = VIP_COLOR
	Ui.worldText(label, 2)
	label.Parent = gui
	gui.Parent = head
end

local function watchPlayer(who: Player)
	who:GetAttributeChangedSignal("VIP"):Connect(function()
		updateTag(who)
	end)
	who.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 10)
		updateTag(who)
	end)
	updateTag(who)
end

-- the VIP area walls: no collision for the local VIP player
local function updateBarriers()
	local vip = isVip(player)
	for _, part in CollectionService:GetTagged("VipBarrier") do
		if part:IsA("BasePart") then
			part.CanCollide = not vip
		end
	end
end

-- "Tenderize the Server": a short camera shake (Humanoid.CameraOffset, so the camera script keeps control)
local function shake(seconds: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local ends = os.clock() + seconds
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local left = ends - os.clock()
		if left <= 0 or not humanoid.Parent then
			connection:Disconnect()
			if humanoid.Parent then
				humanoid.CameraOffset = Vector3.zero
			end
			return
		end
		local strength = 0.6 * math.min(1, left / seconds + 0.3)
		humanoid.CameraOffset = Vector3.new(
			(math.random() - 0.5) * strength,
			(math.random() - 0.5) * strength,
			(math.random() - 0.5) * strength
		)
	end)
end

-- Egg prompts (decision 2026-11-15): "Open 3" opens three with the Open 3 Eggs gamepass, otherwise it shows the
-- gamepass price (the server then starts the purchase); "Fast Open" is only shown until you own it.
local function updateEggPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local kind = prompt:GetAttribute("EggPrompt")
	if kind == "Open3" then
		if player:GetAttribute("PassTripleEgg") then
			local price = (prompt:GetAttribute("EggPrice") or 0) * Config.Pets.MultiOpenCount
			prompt.ActionText = `Open 3 ({NumberFormat.money(price)})`
		else
			prompt.ActionText = `Open 3 · R$ {ShopWindow.passPrice("TripleEgg", os.time())}`
		end
	elseif kind == "FastOpen" then
		prompt.Enabled = not player:GetAttribute("PassFastEgg")
		prompt.ActionText = `Fast Open · R$ {ShopWindow.passPrice("FastEgg", os.time())}`
	end
end

local function updateEggPrompts()
	local plaza = workspace:FindFirstChild("EggPlaza")
	if plaza then
		for _, d in plaza:GetDescendants() do
			updateEggPrompt(d)
		end
	end
end

function ShopEffectsController.init()
	task.spawn(function()
		local plaza = workspace:WaitForChild("EggPlaza")
		plaza.DescendantAdded:Connect(updateEggPrompt)
		updateEggPrompts()
	end)
	player:GetAttributeChangedSignal("PassTripleEgg"):Connect(updateEggPrompts)
	player:GetAttributeChangedSignal("PassFastEgg"):Connect(updateEggPrompts)

	Players.PlayerAdded:Connect(watchPlayer)
	for _, who in Players:GetPlayers() do
		task.spawn(watchPlayer, who)
	end

	player:GetAttributeChangedSignal("VIP"):Connect(updateBarriers)
	CollectionService:GetInstanceAddedSignal("VipBarrier"):Connect(updateBarriers)
	updateBarriers()

	-- [VIP] before a VIP player's name in the chat
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local source = message.TextSource
		local who = source and Players:GetPlayerByUserId(source.UserId)
		if who and isVip(who) then
			local properties = Instance.new("TextChatMessageProperties")
			properties.PrefixText = `<font color="#{VIP_HEX}">[VIP]</font> {message.PrefixText}`
			return properties
		end
		return nil
	end

	local tenderize = Config.Shop.Products.Tenderize
	Remotes.FunEffect.OnClientEvent:Connect(function(kind: string, name: string)
		if kind == "Tenderize" then
			shake(tenderize.Duration)
			Audio.play("Impact") -- the mallet hit
			Chat.announce(`{name} tenderized the server!`, Config.Palette.Gold)
		elseif kind == "SchnitzelRain" then
			Chat.announce(`{name} made it rain schnitzels on the street! Grab them!`, Config.Palette.Gold)
		end
	end)
end

return ShopEffectsController
