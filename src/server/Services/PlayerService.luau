local Players = game:GetService("Players")

local PlayerService = {}

function PlayerService.init()
	Players.PlayerAdded:Connect(function(player)
		print(`[Schnitzel] {player.Name} csatlakozott`)
	end)
end

return PlayerService
