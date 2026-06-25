-- src/client/WeaponController.luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local lastAttackTime = 0

-- Fonction locale pour changer d'arme et avertir le serveur
local function requestWeaponSwitch(weaponName: string)
	-- 🐛 BUG 2 FIX : Si on a déjà cette arme équipée, on ignore la requête (Anti-Spam)
	if player:GetAttribute("EquippedWeapon") == weaponName then
		return
	end

	player:SetAttribute("EquippedWeapon", weaponName)
	RemoteEvents.EquipWeapon:FireServer({ weaponName = weaponName })
end

-- 🌟 ÉTAPE 2 CORRIGÉE : Déclencher les effets depuis le Handle (sons) et le Muzzle (particules)
local function playMuzzleVFX(character: Model)
	local visualModel = character:FindFirstChild("WeaponVisual")
	if not visualModel then
		return
	end

	-- 🔊 1. GESTION DES SONS (Dans le Handle)
	local handle = visualModel:FindFirstChild("Handle")
	if handle then
		-- On cherche "FireSound", et s'il n'existe pas, on cherche "shoot" (vu sur ta capture)
		local fireSound = handle:FindFirstChild("FireSound") or handle:FindFirstChild("shoot")

		if fireSound and fireSound:IsA("Sound") then
			-- Modulation aléatoire de la vitesse (Pitch) pour un effet sonore plus réaliste et moins linéaire
			fireSound.PlaybackSpeed = math.random(95, 105) / 100
			fireSound:Play()
		end
	end

	-- ✨ 2. GESTION DES PARTICULES (Dans le Muzzle)
	local muzzle = visualModel:FindFirstChild("Muzzle")
	if muzzle then
		-- Faire émettre des particules au MuzzleEffect volé
		local muzzleEffect = muzzle:FindFirstChild("MuzzleEffect")
		if muzzleEffect then
			for _, particle in ipairs(muzzleEffect:GetDescendants()) do
				if particle:IsA("ParticleEmitter") then
					particle:Emit(math.random(3, 6)) -- Émet un flash d'étincelles/fumée
				end
			end
		end
	end
end

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
		-- 🌟 EFFETS VISUELS locales instantanés
		playMuzzleVFX(character)

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

	-- Raccourcis clavier mis à jour pour appeler notre nouvelle fonction de switch
	if input.KeyCode == Enum.KeyCode.One then
		requestWeaponSwitch("Fusil")
	elseif input.KeyCode == Enum.KeyCode.Two then
		requestWeaponSwitch("Pistolet")
	elseif input.KeyCode == Enum.KeyCode.Three then
		requestWeaponSwitch("Couteau")
	elseif input.KeyCode == Enum.KeyCode.Four then
		-- 🌟 Touche 4 pour équiper le magnifique fusil d'assaut
		requestWeaponSwitch("FusilAssaut")
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Gamepad1 then
		onActivated()
	end
end)

-- Initialisation de l'arme de base au spawn
requestWeaponSwitch("Fusil")

return nil
