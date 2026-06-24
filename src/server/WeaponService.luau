-- WeaponService.luau
-- Gère les attaques distance (raycast) et mêlée côté SERVEUR.
-- Corrections Bloc 1 :
--   • Config importée depuis WeaponConfig partagé (plus de duplication)
--   • Vérification faction avant application des dégâts (feu amical OFF)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)

-- ─── Cooldowns serveur ────────────────────────────────────────────────────────
local playerCooldowns: { [Player]: { [string]: number } } = {}

local function checkCooldown(player: Player, weaponName: string): boolean
	local config = WeaponConfig[weaponName]
	if not config then
		return false
	end

	if not playerCooldowns[player] then
		playerCooldowns[player] = {}
	end

	local last = playerCooldowns[player][weaponName] or 0
	local now = os.clock()
	if now - last < config.Cooldown then
		return false
	end

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
		-- 🌟 RECTIFICATION : La cible n'est pas un joueur (c'est un mutant)
		-- On retourne toujours 'false' pour AUTORISER les dégâts PvE !
		return false
	end

	local attackerFaction = attacker:GetAttribute("Faction") or "None"
	local targetFaction = targetPlayer:GetAttribute("Faction") or "None"

	-- Si l'un des deux JOUEURS n'a pas choisi de camp, on bloque le PvP
	if attackerFaction == "None" or targetFaction == "None" then
		return true
	end

	return attackerFaction == targetFaction
end

local function applyDamage(attacker: Player, targetModel: Model, damage: number)
	local humanoid = targetModel:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	-- On vérifie si la cible est un joueur réel (pour le PvP)
	local targetPlayer = game.Players:GetPlayerFromCharacter(targetModel)

	if targetPlayer then
		-- ─── LOGIQUE PVP (Joueur contre Joueur) ───
		if sameFaction(attacker, targetModel) then
			return
		end -- Bloque le friendly fire
		humanoid:TakeDamage(damage)
		print(("[WeaponService] PvP : %s → %s (%d dmg)"):format(attacker.Name, targetPlayer.Name, damage))
	else
		-- ─── LOGIQUE PVE (Joueur contre Mutant) ───
		-- Les mutants n'ont pas de faction, on leur met les dégâts directement !
		humanoid:TakeDamage(damage)
		print(("[WeaponService] PvE : %s → %s (%d dmg)"):format(attacker.Name, targetModel.Name, damage))
	end
end

-- ─── Tir à distance (CORRIGÉ) ───────────────────────────────────────────────────────────
RemoteEvents.WeaponFire.OnServerEvent:Connect(function(player: Player, data)
	if not data or not data.weaponName or not data.origin or not data.direction then
		return
	end

	local config = WeaponConfig[data.weaponName]
	if not config or config.Type ~= "Distance" then
		return
	end
	if not checkCooldown(player, data.weaponName) then
		return
	end

	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end

	-- 🌟 CORRECTION SÉCURITÉ : La caméra en 3e personne est souvent à plus de 10 studs du corps.
	-- On monte la tolérance à 120 studs pour permettre de tirer confortablement dézoomé.
	local distCheck = (character.HumanoidRootPart.Position - data.origin).Magnitude
	if distCheck > 120 then
		warn(("[ANTI-CHEAT] Tir rejeté pour %s : Caméra trop éloignée du corps."):format(player.Name))
		return
	end

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
	if not data or not data.weaponName then
		return
	end

	local config = WeaponConfig[data.weaponName]
	if not config or config.Type ~= "Melee" then
		return
	end
	if not checkCooldown(player, data.weaponName) then
		return
	end

	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end

	local origin = character.HumanoidRootPart.Position

	-- 🌟 CORRECTION : Zone sphérique ultra-optimisée
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { character }

	local partsInZone = workspace:GetPartBoundsInRadius(origin, config.Range, overlapParams)
	local alreadyHit = {} -- Pour ne pas frapper deux fois le même modèle

	for _, part in partsInZone do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not alreadyHit[model] then
			alreadyHit[model] = true
			local root = model:FindFirstChild("HumanoidRootPart")

			if root then
				applyDamage(player, model, config.Damage)
				break -- Un seul coup réussi par clic
			end
		end
	end
end)

-- ─── Nettoyage ────────────────────────────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player: Player)
	playerCooldowns[player] = nil
end)

return {}
