-- init.client.luau
-- Point d'entrée client : charge tous les modules UI dans l'ordre.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Attendre que le dossier Shared soit prêt avant de charger quoi que ce soit
ReplicatedStorage:WaitForChild("Shared", 15)

-- Ordre d'initialisation :
-- 1. HealthBarClient  → HUD barre de vie, badge faction, devise, mort, loot notif
-- 2. FactionChoiceClient → Écran de choix faction (se ferme seul si déjà choisi)
-- 3. WeaponController → Inputs attaque

require(script.Parent.HealthBarClient)
require(script.Parent.FactionChoiceClient)
require(script.Parent.WeaponController)
