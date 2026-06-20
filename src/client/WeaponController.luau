-- WeaponController.luau
-- Gère les inputs du joueur (Clics de souris) pour déclencher les attaques via le réseau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Arme actuellement équipée (Simulée pour les tests)
-- Change par "Fusil", "Pistolet", ou "Couteau" pour tester les différents modes !
local currentWeapon = "Fusil"

local COOLDOWNS = {
	["Fusil"] = 0.5,
	["Pistolet"] = 0.3,
	["Couteau"] = 0.7,
}
local lastAttackTime = 0

local function onActivated()
	local character = player.Character
	if not character or not character:FindFirstChild("Humanoid") then
		return
	end
	if character.Humanoid.Health <= 0 then
		return
	end -- Morts interdits de tirer

	local now = os.clock()
	local cooldown = COOLDOWNS[currentWeapon] or 0.5
	if now - lastAttackTime < cooldown then
		return
	end -- Cooldown local actif
	lastAttackTime = now

	if currentWeapon == "Couteau" then
		-- Corps à corps : On notifie simplement le serveur
		RemoteEvents.WeaponMelee:FireServer({
			weaponName = currentWeapon,
		})
	else
		-- Arme à feu : On calcule la direction vers laquelle regarde la souris/caméra
		local mouseLocation = UserInputService:GetMouseLocation()
		local unitRay = camera:ScreenPointToRay(mouseLocation.X, mouseLocation.Y)

		RemoteEvents.WeaponFire:FireServer({
			origin = unitRay.Origin,
			direction = unitRay.Direction,
			weaponName = currentWeapon,
		})
	end
end

-- Écoute le clic gauche de la souris ou la gâchette manette
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end -- Ignore si on clique sur un bouton UI ou le Chat

	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Gamepad1 then
		onActivated()
	end
end)

return nil
