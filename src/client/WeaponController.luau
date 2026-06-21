local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local lastAttackTime = 0

-- 🌟 On définit l'arme de base sur le personnage
player:SetAttribute("EquippedWeapon", "Fusil")

local function onActivated()
	local currentWeapon = player:GetAttribute("EquippedWeapon") or "Fusil"
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

	-- 🌟 AJOUT : Raccourcis clavier (1, 2, 3) pour changer d'arme
	if input.KeyCode == Enum.KeyCode.One then
		player:SetAttribute("EquippedWeapon", "Fusil")
	elseif input.KeyCode == Enum.KeyCode.Two then
		player:SetAttribute("EquippedWeapon", "Pistolet")
	elseif input.KeyCode == Enum.KeyCode.Three then
		player:SetAttribute("EquippedWeapon", "Couteau")
	end

	-- Tir / Attaque
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Gamepad1 then
		onActivated()
	end
end)

return nil
