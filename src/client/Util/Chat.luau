-- Szerver-szintű rendszerüzenet a chatbe (GDD 3.4, 8: social proof – ritka schnitzel, legendás pet).
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

local Chat = {}

function Chat.announce(text: string, color: Color3)
	task.spawn(function()
		pcall(function()
			if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
				local channels = TextChatService:WaitForChild("TextChannels", 5)
				local general = channels and channels:FindFirstChild("RBXGeneral") :: TextChannel?
				if general then
					general:DisplaySystemMessage(`<font color="#{color:ToHex()}">{text}</font>`)
				end
			else
				StarterGui:SetCore("ChatMakeSystemMessage", { Text = text, Color = color })
			end
		end)
	end)
end

return Chat
