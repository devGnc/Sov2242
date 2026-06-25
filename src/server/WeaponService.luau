-- src/server/WeaponService.luau
-- Gère les tirs (raycast), le corps à corps, et l'ÉQUIPEMENT PHYSIQUE SÉCURISÉ côté SERVEUR.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)

local WeaponsAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weapons")
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

local function sameFaction(attacker: Player, targetModel: Model): boolean
	local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
	if not targetPlayer then
		return false
	end

	local attackerFaction = attacker:GetAttribute("Faction") or "None"
	local targetFaction = targetPlayer:GetAttribute("Faction") or "None"

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

	local targetPlayer = game.Players:GetPlayerFromCharacter(targetModel)
	if targetPlayer then
		if sameFaction(attacker, targetModel) then
			return
		end
		humanoid:TakeDamage(damage)
	else
		humanoid:TakeDamage(damage)
	end
end

-- ─── SÉCURISATION ET ALIGNEMENT VISUEL ────────────────────────────────────────
local function handleVisualEquip(player: Player, weaponName: string)
	local character = player.Character
	if not character then
		return
	end

	-- 1. Suppression nette de l'ancienne arme
	for _, child in ipairs(character:GetChildren()) do
		if child:GetAttribute("IsWeapon") == true then
			child:Destroy()
		end
	end

	local weaponTemplate = WeaponsAssets:FindFirstChild(weaponName)
	if not weaponTemplate then
		warn(("[WeaponService] Modèle introuvable dans ReplicatedStorage.Assets.Weapons : " .. tostring(weaponName)))
		return
	end

	local config = WeaponConfig[weaponName]
	local weaponClone = weaponTemplate:Clone()

	weaponClone.Name = weaponName
	weaponClone:SetAttribute("IsWeapon", true)

	-- 🛡️ SÉCURITÉ PHYSIQUE CRUCIALE : Neutraliser TOUTES les pièces avant insertion dans le personnage
	-- (Évite les forces résiduelles de la Toolbox qui font péter un câble au perso)
	for _, part in ipairs(weaponClone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Anchored = false
			part.Massless = true
		elseif part:IsA("BodyMover") or part:IsA("Constraint") then
			part:Destroy()
		end
	end

	local handle = weaponClone:FindFirstChild("Handle") :: BasePart?
	local rightHand = character:WaitForChild("RightHand", 5) :: BasePart?

	if rightHand and handle then
		-- 🔗 SOUDAGE MATRICIEL INTERNE : On force l'assemblage de toutes les pièces au Handle
		for _, part in ipairs(weaponClone:GetDescendants()) do
			if part:IsA("BasePart") and part ~= handle then
				local internalWeld = Instance.new("WeldConstraint")
				internalWeld.Part0 = handle
				internalWeld.Part1 = part
				internalWeld.Parent = part
			end
		end

		-- 📐 APPLICATION DU GRIP (ALIGNEMENT)
		local offset = (config and config.GripOffset) or CFrame.new()
		handle.CFrame = rightHand.CFrame * offset

		-- Parentage sécurisé : L'arme devient visible et solidaire du joueur
		weaponClone.Parent = character

		-- Soudure mécanique finale au poignet droit
		local handWeld = Instance.new("WeldConstraint")
		handWeld.Name = "HandWeaponWeld"
		handWeld.Part0 = rightHand
		handWeld.Part1 = handle
		handWeld.Parent = handle
	end
end

RemoteEvents.EquipWeapon.OnServerEvent:Connect(function(player: Player, data)
	if type(data) == "table" and data.weaponName then
		if WeaponConfig[data.weaponName] then
			player:SetAttribute("EquippedWeapon", data.weaponName)
			handleVisualEquip(player, data.weaponName)
		end
	end
end)

-- ─── ÉCOUTEURS DE TIR ET MÊLÉE ────────────────────────────────────────────────
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

	local distCheck = (character.HumanoidRootPart.Position - data.origin).Magnitude
	if distCheck > 120 then
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
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { character }

	local partsInZone = workspace:GetPartBoundsInRadius(origin, config.Range, overlapParams)
	local alreadyHit = {}

	for _, part in partsInZone do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not alreadyHit[model] then
			alreadyHit[model] = true
			local root = model:FindFirstChild("HumanoidRootPart")
			if root then
				applyDamage(player, model, config.Damage)
				break
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	playerCooldowns[player] = nil
end)

return {}
