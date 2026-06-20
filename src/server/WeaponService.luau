-- WeaponService.luau
-- Gère la logique des attaques à distance (Raycasting) et mêlée côté SERVEUR.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

-- Configuration basique des types d'armes (Simulé en attendant le Bloc 3)
local WEAPONS_CONFIG = {
	["Fusil"] = { Damage = 25, Range = 150, Cooldown = 0.5, Type = "Distance" },
	["Pistolet"] = { Damage = 15, Range = 80, Cooldown = 0.3, Type = "Distance" },
	["Couteau"] = { Damage = 35, Range = 6, Cooldown = 0.7, Type = "Melee" },
}

-- Table pour suivre les cooldowns des joueurs côté serveur
local playerCooldowns: { [Player]: { [string]: number } } = {}

local WeaponService = {}

local function checkCooldown(player: Player, weaponName: string, config): boolean
	if not playerCooldowns[player] then
		playerCooldowns[player] = {}
	end

	local lastAttack = playerCooldowns[player][weaponName] or 0
	local now = os.clock()

	if now - lastAttack < config.Cooldown then
		return false -- Trop rapide
	end

	playerCooldowns[player][weaponName] = now
	return true
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Logique Tir à distance (Raycast)
-- ─────────────────────────────────────────────────────────────────────────────
RemoteEvents.WeaponFire.OnServerEvent:Connect(function(player: Player, data)
	if not data or not data.weaponName or not data.origin or not data.direction then
		return
	end

	local config = WEAPONS_CONFIG[data.weaponName]
	if not config or config.Type ~= "Distance" then
		return
	end

	-- 1. Vérification anti-spam
	if not checkCooldown(player, data.weaponName, config) then
		return
	end

	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end

	-- 2. Sécurité de distance d'origine
	local distancePlayerToOrigin = (character.HumanoidRootPart.Position - data.origin).Magnitude
	if distancePlayerToOrigin > 10 then
		return
	end

	-- 3. Paramétrage du Raycast
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character } -- Ne pas se tirer dessus

	-- Calcul de la ligne de tir
	local raycastResult = workspace:Raycast(data.origin, data.direction.Unit * config.Range, raycastParams)

	if raycastResult and raycastResult.Instance then
		local hitInstance = raycastResult.Instance
		local targetModel = hitInstance:FindFirstAncestorOfClass("Model")

		if targetModel then
			local humanoid = targetModel:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				-- Appliquer les dégâts
				humanoid:TakeDamage(config.Damage)
				print(
					("[Combat] %s a touché %s avec un %s (%d dmg)"):format(
						player.Name,
						targetModel.Name,
						data.weaponName,
						config.Damage
					)
				)
			end
		end
	end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Logique Corps à Corps (Mêlée)
-- ─────────────────────────────────────────────────────────────────────────────
RemoteEvents.WeaponMelee.OnServerEvent:Connect(function(player: Player, data)
	if not data or not data.weaponName then
		return
	end

	local config = WEAPONS_CONFIG[data.weaponName]
	if not config or config.Type ~= "Melee" then
		return
	end

	-- 1. Vérification anti-spam
	if not checkCooldown(player, data.weaponName, config) then
		return
	end

	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end

	-- 2. Chercher les cibles à proximité de l'attaquant
	local origin = character.HumanoidRootPart.Position
	for _, targetPlayer in Players:GetPlayers() do
		if
			targetPlayer ~= player
			and targetPlayer.Character
			and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
		then
			local targetChar = targetPlayer.Character
			local targetRoot = targetChar.HumanoidRootPart

			local distance = (targetRoot.Position - origin).Magnitude
			if distance <= config.Range then
				local humanoid = targetChar:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 then
					humanoid:TakeDamage(config.Damage)
					print(
						("[Combat Mêlée] %s a lacéré %s avec un %s"):format(
							player.Name,
							targetPlayer.Name,
							data.weaponName
						)
					)
					break
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	playerCooldowns[player] = nil
end)

-- 🛠️ ZONE DE TEST MONO-JOUEUR : Création d'un mannequin de test
-- (Placé obligatoirement AVANT le return WeaponService)
task.spawn(function()
	task.wait(5) -- Attendre que la map et les zones soient générées

	local ZoneSetup = require(game:GetService("ServerScriptService").Scripts.ZoneSetup)
	local terreDesoleePos = ZoneSetup.GetZonePosition("Zone_TerreDesolee") or Vector3.new(6000, 0, 0)

	-- Création du mannequin (Cible)
	local dummy = Instance.new("Model")
	dummy.Name = "Cible_Test"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(3, 5, 3)
	root.CFrame = CFrame.new(terreDesoleePos + Vector3.new(0, 3, 15)) -- Devant le joueur
	root.Anchored = true
	root.Color = Color3.fromRGB(255, 60, 60)
	root.Material = Enum.Material.Neon
	root.Parent = dummy

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.Parent = dummy

	dummy.PrimaryPart = root
	dummy.Parent = workspace
	print("[TEST SYSTEM] Mannequin généré sur la Terre Désolée !")
end)

return WeaponService
