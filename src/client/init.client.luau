-- init.client.luau
-- Point d'entrée client : charge tous les modules UI dans l'ordre.
-- Note : avec $path sur src/client, ce script devient StarterPlayerScripts lui-même.
-- Les autres fichiers du dossier sont des enfants directs (script.X).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Attendre que le dossier Shared soit prêt
ReplicatedStorage:WaitForChild("Shared", 15)

require(script.HealthBarClient)
require(script.FactionChoiceClient)
require(script.WeaponController)
