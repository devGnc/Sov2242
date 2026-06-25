-- src/client/init.client.luau
local StarterGui = game:GetService("StarterGui")

-- Désactive la barre de vie native de Roblox
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

-- Chargement de la barre de vie et du HUD
require(script.HealthBarClient)

-- 🌟 RECTIFICATION : On charge explicitement le WeaponController pour activer les armes !
require(script.WeaponController)

-- Importation du module de choix de faction
local FactionChoiceClient = require(script.FactionChoiceClient)

-- Écoute l'ordre du PNJ envoyé par ZoneSetup
RemoteEvents.OpenFactionMenu.OnClientEvent:Connect(function()
	FactionChoiceClient.Open()
end)
