local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local MenuCameraController = {}

local RENDER_STEP_NAME = "MenuCameraRotation"
local HORIZONTAL_SENSITIVITY = math.rad(0.5)
local VERTICAL_SENSITIVITY = HORIZONTAL_SENSITIVITY * 0.77
local MIN_PITCH = math.rad(-80)
local MAX_PITCH = math.rad(80)

local initialized = false
local rotating = false
local pendingMouseDelta = Vector2.zero
local savedMouseBehavior = nil

local function stopRotating()
	if not rotating then
		return
	end

	rotating = false
	pendingMouseDelta = Vector2.zero

	if savedMouseBehavior then
		UserInputService.MouseBehavior = savedMouseBehavior
		savedMouseBehavior = nil
	end
end

local function rotateCamera()
	if not rotating or pendingMouseDelta == Vector2.zero then
		return
	end

	local camera = Workspace.CurrentCamera
	if not camera or camera.CameraType == Enum.CameraType.Scriptable then
		pendingMouseDelta = Vector2.zero
		return
	end

	local delta = pendingMouseDelta
	pendingMouseDelta = Vector2.zero

	local cameraPosition = camera.CFrame.Position
	local focusPosition = camera.Focus.Position
	local focusOffset = focusPosition - cameraPosition
	local focusDistance = focusOffset.Magnitude

	if focusDistance < 0.001 then
		return
	end

	local lookDirection = focusOffset.Unit
	local yaw = math.atan2(-lookDirection.X, -lookDirection.Z)
	local pitch = math.asin(math.clamp(lookDirection.Y, -1, 1))

	yaw -= delta.X * HORIZONTAL_SENSITIVITY
	pitch = math.clamp(pitch - delta.Y * VERTICAL_SENSITIVITY, MIN_PITCH, MAX_PITCH)

	local cosPitch = math.cos(pitch)
	local rotatedLook = Vector3.new(
		-math.sin(yaw) * cosPitch,
		math.sin(pitch),
		-math.cos(yaw) * cosPitch
	)
	local rotatedPosition = focusPosition - rotatedLook * focusDistance

	camera.CFrame = CFrame.lookAt(rotatedPosition, focusPosition, Vector3.yAxis)
end

function MenuCameraController.init()
	if initialized then
		return
	end
	initialized = true

	-- The default camera ignores a right-click when a GuiButton consumes it.
	-- Handle only that case; otherwise Roblox keeps full control of the camera.
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.UserInputType ~= Enum.UserInputType.MouseButton2 or not gameProcessed then
			return
		end

		local camera = Workspace.CurrentCamera
		if not camera or camera.CameraType == Enum.CameraType.Scriptable then
			return
		end

		rotating = true
		pendingMouseDelta = Vector2.zero
		savedMouseBehavior = UserInputService.MouseBehavior
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	end)

	UserInputService.InputChanged:Connect(function(input)
		if rotating and input.UserInputType == Enum.UserInputType.MouseMovement then
			pendingMouseDelta += Vector2.new(input.Delta.X, input.Delta.Y)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			stopRotating()
		end
	end)

	UserInputService.WindowFocusReleased:Connect(stopRotating)

	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, rotateCamera)
end

return MenuCameraController
