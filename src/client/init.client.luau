-- src/client/init.client.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

-- Chargement de la barre de vie et du HUD (S'exécute normalement)
require(script.HealthBarClient)

-- Importation du module de choix de faction
local FactionChoiceClient = require(script.FactionChoiceClient)

-- 🌟 Écoute l'ordre du PNJ envoyé par ZoneSetup
RemoteEvents.OpenFactionMenu.OnClientEvent:Connect(function()
	FactionChoiceClient.Open()
end)
