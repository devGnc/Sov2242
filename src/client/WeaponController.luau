-- WeaponController.luau
-- Gère les inputs joueur et envoie les actions d'attaque au serveur.
-- CORRECTION : config importée depuis WeaponConfig partagé (plus de duplication).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Arme équipée (simulée en attendant le système d'inventaire — Bloc 3)
-- Remplace par "Pistolet" ou "Couteau" pour tester les autres modes.
local currentWeapon = "Fusil"

local lastAttackTime = 0

local function onActivated()
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local config = WeaponConfig[currentWeapon]
	if not config then
		return
	end

	-- Cooldown local (confort : évite les envois réseau inutiles)
	local now = os.clock()
	if now - lastAttackTime < config.Cooldown then
		return
	end
	lastAttackTime = now

	if config.Type == "Melee" then
		RemoteEvents.WeaponMelee:FireServer({ weaponName = currentWeapon })
	else
		local mouseLocation = UserInputService:GetMouseLocation()
		local unitRay = camera:ScreenPointToRay(mouseLocation.X, mouseLocation.Y)
		RemoteEvents.WeaponFire:FireServer({
			origin = unitRay.Origin,
			direction = unitRay.Direction,
			weaponName = currentWeapon,
		})
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Gamepad1 then
		onActivated()
	end
end)

return nil
