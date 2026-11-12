-- Játékos adatok (DataServiceTyped + ProfileStore), szerver → kliens replikációval.
-- Szerveren: Data.server[player] (Value), Data.server.Service (szolgáltatás).
-- Kliensen: Data.client (Value) – a require addig vár, amíg az adat betölt!
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataServiceTyped = require(ReplicatedStorage.Packages.Dataservicetyped)
local Config = require(script.Parent.Config)
local Template = require(script.Parent.DataTemplate)

return DataServiceTyped({
	template = Template,
	profileStoreIndex = Config.Game.DataStoreIndex,
	useMock = RunService:IsStudio() and Config.Game.StudioMockData,
})
