-- Gondoskodik róla, hogy egyszerre csak egy teljes képernyős menü legyen nyitva.
local MenuCoordinator = {}

local closeCallbacks = {}
local activeMenu = nil

function MenuCoordinator.register(name, closeCallback)
	closeCallbacks[name] = closeCallback
end

function MenuCoordinator.unregister(name, closeCallback)
	if closeCallbacks[name] == closeCallback then
		closeCallbacks[name] = nil
	end
	if activeMenu == name then
		activeMenu = nil
	end
end

function MenuCoordinator.opening(name)
	if activeMenu == name then
		return
	end

	local previousMenu = activeMenu
	activeMenu = nil

	if previousMenu then
		local closePrevious = closeCallbacks[previousMenu]
		if closePrevious then
			closePrevious()
		end
	end

	activeMenu = name
end

function MenuCoordinator.closed(name)
	if activeMenu == name then
		activeMenu = nil
	end
end

function MenuCoordinator.getActiveMenu()
	return activeMenu
end

return MenuCoordinator
