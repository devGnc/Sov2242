-- WeaponService.luau
-- Gère les attaques distance (raycast) et mêlée côté SERVEUR.
-- Corrections Bloc 1 :
--   • Config importée depuis WeaponConfig partagé (plus de duplication)
--   • Vérification faction avant application des dégâts (feu amical OFF)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents  = require(ReplicatedStorage.Shared.RemoteEvents)
local WeaponConfig  = require(ReplicatedStorage.Shared.WeaponConfig)

-- ─── Cooldowns serveur ────────────────────────────────────────────────────────
local playerCooldowns: { [Player]: { [string]: number } } = {}

local function checkCooldown(player: Player, weaponName: string): boolean
	local config = WeaponConfig[weaponName]
	if not config then return false end

	if not playerCooldowns[player] then
		playerCooldowns[player] = {}
	end

	local last = playerCooldowns[player][weaponName] or 0
	local now  = os.clock()
	if now - last < config.Cooldown then return false end

	playerCooldowns[player][weaponName] = now
	return true
end

-- ─── Vérification faction (feu amical désactivé) ──────────────────────────────
-- Retourne true si l'attaquant et la cible sont dans la MÊME faction.
-- Dans ce cas, les dégâts sont bloqués.
local function sameFaction(attacker: Player, targetModel: Model): boolean
	-- Vérifier si la cible est un joueur
	local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
	if not targetPlayer then
		-- La cible est un PNJ (mutant, mannequin) → toujours autorisé
		return false
	end

	local attackerFaction = attacker:GetAttribute("Faction") or "None"
	local targetFaction   = targetPlayer:GetAttribute("Faction") or "None"

	-- Si l'une des deux factions est "None" (pas encore choisi), on bloque
	-- pour éviter les accidents en zone de test
	if attackerFaction == "None" or targetFaction == "None" then
		return true
	end

	return attackerFaction == targetFaction
end

local function applyDamage(attacker: Player, targetModel: Model, damage: number)
	if sameFaction(attacker, targetModel) then return end

	local humanoid = targetModel:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid:TakeDamage(damage)
		print(("[WeaponService] %s → %s (%d dmg)"):format(
			attacker.Name, targetModel.Name, damage
		))
	end
end

-- ─── Tir à distance ───────────────────────────────────────────────────────────
RemoteEvents.WeaponFire.OnServerEvent:Connect(function(player: Player, data)
	if not data or not data.weaponName or not data.origin or not data.direction then return end

	local config = WeaponConfig[data.weaponName]
	if not config or config.Type ~= "Distance" then return end
	if not checkCooldown(player, data.weaponName) then return end

	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end

	-- Sécurité : l'origine du rayon ne doit pas être trop loin du personnage
	local distCheck = (character.HumanoidRootPart.Position - data.origin).Magnitude
	if distCheck > 10 then return end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }

	local result = workspace:Raycast(data.origin, data.direction.Unit * config.Range, raycastParams)
	if result and result.Instance then
		local targetModel = result.Instance:FindFirstAncestorOfClass("Model")
		if targetModel then
			applyDamage(player, targetModel, config.Damage)
		end
	end
end)

-- ─── Corps à corps ────────────────────────────────────────────────────────────
RemoteEvents.WeaponMelee.OnServerEvent:Connect(function(player: Player, data)
	if not data or not data.weaponName then return end

	local config = WeaponConfig[data.weaponName]
	if not config or config.Type ~= "Melee" then return end
	if not checkCooldown(player, data.weaponName) then return end

	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end

	local origin = character.HumanoidRootPart.Position

	-- Chercher tous les Humanoids à portée (joueurs ET PNJs)
	for _, model in workspace:GetDescendants() do
		if model:IsA("Model") and model ~= character then
			local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and (root.Position - origin).Magnitude <= config.Range then
				applyDamage(player, model, config.Damage)
				break  -- Un seul hit par swing
			end
		end
	end
end)

-- ─── Nettoyage ────────────────────────────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player: Player)
	playerCooldowns[player] = nil
end)

return {}
