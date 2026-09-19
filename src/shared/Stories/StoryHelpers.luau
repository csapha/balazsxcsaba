-- UI Labs helpers for mounting the existing controller-driven interfaces safely.
local StarterPlayer = game:GetService("StarterPlayer")

local StoryHelpers = {}

local function createPreviewRoot(target, controllerName)
	local root = Instance.new("Frame")
	root.Name = controllerName .. "Preview"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.Parent = target
	return root
end

-- Builds a controller UI inside an isolated preview root. Preview mode keeps the
-- controllers away from TopbarPlus, RemoteEvents, global input, and background loops.
function StoryHelpers.mount(controllerName, target, openFn)
	local root = createPreviewRoot(target, controllerName)
	local controller = nil

	local ok, err = pcall(function()
		local controllers = StarterPlayer.StarterPlayerScripts.Client.Controllers
		controller = require(controllers[controllerName])
		controller.init({
			gui = root,
			preview = true,
		})

		local open = openFn or controller.open
		if open then
			open()
		end
	end)

	if not ok then
		StoryHelpers.showError(root, controllerName .. " story error:", err)
	end

	return function()
		if controller and controller.destroy then
			pcall(controller.destroy)
		elseif controller and controller.close then
			pcall(controller.close)
		end
		root:Destroy()
	end
end

-- Shows errors in the preview instead of repeatedly filling Studio's Output.
function StoryHelpers.showError(target, title, err)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextWrapped = true
	label.TextColor3 = Color3.fromRGB(255, 120, 120)
	label.Text = title .. "\n" .. tostring(err)
	label.Parent = target

	return function()
		label:Destroy()
	end
end

return StoryHelpers
