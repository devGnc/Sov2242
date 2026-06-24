-- MutantService.luau
-- Bloc 2 : IA Runner (Rôdeur) + Tank (Alpha) + loot mutants.

local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ZoneSetup = require(script.Parent.ZoneSetup)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

-- CombatService chargé en lazy pour éviter les dépendances circulaires
local CombatService = nil
local function getCombatService()
	if not CombatService then
		CombatService = require(game:GetService("ServerScriptService").Scripts.CombatService)
	end
	return CombatService
end

local MutantService = {}

-- ─── ZONE ────────────────────────────────────────────────────────────────────
local SPAWN_ZONE_NAME = "Zone_TerreDesolee"

-- ─── CONFIG RUNNER ───────────────────────────────────────────────────────────
local MAX_RUNNERS = 8
local RUNNER_DETECTION = 35
local RUNNER_MEUTE = 45
local RUNNER_ATTACK_RANGE = 4
local RUNNER_DAMAGE = 15
local RUNNER_COOLDOWN = 1.2
local RUNNER_SPEED = 15

-- ─── CONFIG TANK ─────────────────────────────────────────────────────────────
local MAX_TANKS = 2
local TANK_DETECTION = 50 -- aggro de zone large
local TANK_ATTACK_RANGE = 6
local TANK_DAMAGE = 30
local TANK_COOLDOWN = 2.0
local TANK_SPEED_WALK = 10
local TANK_SPEED_CHARGE = 26 -- vitesse de charge (x2.6)
local TANK_ARMOR = 0.80 -- 80% réduction des dégâts
local TANK_AGGRO_RADIUS = 80 -- alerte tous les mutants dans ce rayon

-- ─── LOOT TABLES ─────────────────────────────────────────────────────────────
-- { itemName, minQty, maxQty, chance (0-1) }
local RUNNER_LOOT = {
	{ item = "Tissu muté", min = 1, max = 3, chance = 0.80 },
	{ item = "Composant", min = 1, max = 2, chance = 0.50 },
}

local TANK_LOOT = {
	{ item = "Tissu muté", min = 2, max = 5, chance = 1.00 },
	{ item = "Composant", min = 2, max = 4, chance = 0.90 },
	{ item = "Tissu muté rare", min = 1, max = 2, chance = 0.60 },
	{ item = "Plaque blindée", min = 1, max = 1, chance = 0.35 },
}

local function rollLoot(lootTable: { { item: string, min: number, max: number, chance: number } })
	local result: { [string]: number } = {}
	for _, entry in lootTable do
		if math.random() <= entry.chance then
			local qty = math.random(entry.min, entry.max)
			result[entry.item] = (result[entry.item] or 0) + qty
		end
	end
	return result
end

-- ─── ÉTAT ────────────────────────────────────────────────────────────────────
local activeRunners: { [Model]: { State: string, Target: Model?, NextAttackTime: number, PatrolTarget: Vector3 } } = {}
local activeTanks: { [Model]: { State: string, Target: Model?, NextAttackTime: number, PatrolTarget: Vector3, IsCharging: boolean } } =
	{}

local templates = ServerStorage:WaitForChild("Monsters")
local runnerTemplate = templates:WaitForChild("MutantRunner")
local tankTemplate = templates:FindFirstChild("MutantTank") -- peut être nil si pas encore créé en Studio

-- ─── ANIMATIONS PARTAGÉES ────────────────────────────────────────────────────
local attackAnimation = Instance.new("Animation")
attackAnimation.AnimationId = "rbxassetid://913384386"

-- ─── UTILITAIRES ─────────────────────────────────────────────────────────────
local function getRandomPatrolPoint()
	local zonePos = ZoneSetup.GetZonePosition(SPAWN_ZONE_NAME) or Vector3.new(6000, 0, 0)
	return Vector3.new(zonePos.X + math.random(-250, 250), zonePos.Y + 3, zonePos.Z + math.random(-250, 250))
end

local function findNearestTarget(rootPart: BasePart, detectionRadius: number)
	local nearest = nil
	local shortest = detectionRadius
	for _, player in Players:GetPlayers() do
		local char = player.Character
		if not char then
			continue
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		local root = char:FindFirstChild("HumanoidRootPart")
		if hum and hum.Health > 0 and root then
			local dist = (rootPart.Position - root.Position).Magnitude
			if dist < shortest then
				shortest = dist
				nearest = char
			end
		end
	end
	return nearest, shortest
end

local function applyArmorDamage(humanoid: Humanoid, raw: number, armor: number)
	local actual = math.max(1, math.floor(raw * (1 - armor)))
	humanoid:TakeDamage(actual)
end

-- ─── LOOT DROP ───────────────────────────────────────────────────────────────
local function dropLootToNearestPlayer(rootPos: Vector3, lootTable)
	-- On cherche le joueur le plus proche au moment de la mort pour lui attribuer le loot
	local nearest = nil
	local shortest = 9999
	for _, player in Players:GetPlayers() do
		local char = player.Character
		if not char then
			continue
		end
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then
			local dist = (rootPos - root.Position).Magnitude
			if dist < shortest then
				shortest = dist
				nearest = player
			end
		end
	end

	if nearest then
		local loot = rollLoot(lootTable)
		local cs = getCombatService()
		for itemName, qty in loot do
			cs.AddSessionLoot(nearest, itemName, qty)
			print(("[MutantService] %s reçoit %s x%d"):format(nearest.Name, itemName, qty))
		end
	end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- RUNNER BEHAVIOR
-- ═══════════════════════════════════════════════════════════════════════════
local function alertMeuteRunners(targetChar: Model, instigator: Model)
	for runner, data in activeRunners do
		if runner == instigator then
			continue
		end
		if data.State == "Patrol" then
			local root = runner:FindFirstChild("HumanoidRootPart")
			local iRoot = instigator:FindFirstChild("HumanoidRootPart")
			if root and iRoot and (root.Position - iRoot.Position).Magnitude < RUNNER_MEUTE then
				data.State = "Chasing"
				data.Target = targetChar
			end
		end
	end
end

local function startRunnerBehavior(runner: Model)
	local humanoid = runner:FindFirstChildOfClass("Humanoid")
	local rootPart = runner:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)

	local runAnim = Instance.new("Animation")
	runAnim.AnimationId = "rbxassetid://913376220"
	local idleAnim = Instance.new("Animation")
	idleAnim.AnimationId = "rbxassetid://913402848"

	local runTrack = animator:LoadAnimation(runAnim)
	local idleTrack = animator:LoadAnimation(idleAnim)
	local attackTrack = animator:LoadAnimation(attackAnimation)
	local currentTrack = nil

	local function playAnim(track)
		if currentTrack == track then
			return
		end
		if currentTrack then
			currentTrack:Stop(0.1)
		end
		currentTrack = track
		if currentTrack then
			currentTrack:Play(0.1)
		end
	end

	playAnim(idleTrack)
	humanoid.Running:Connect(function(spd)
		if spd > 0.5 then
			playAnim(runTrack)
			runTrack:AdjustSpeed(spd / 16)
		else
			playAnim(idleTrack)
		end
	end)

	local data = { State = "Patrol", Target = nil, NextAttackTime = 0, PatrolTarget = getRandomPatrolPoint() }
	activeRunners[runner] = data

	task.spawn(function()
		while runner.Parent and humanoid.Health > 0 do
			if data.State == "Patrol" then
				local target = findNearestTarget(rootPart, RUNNER_DETECTION)
				if target then
					data.State = "Chasing"
					data.Target = target
					alertMeuteRunners(target, runner)
				else
					humanoid:MoveTo(data.PatrolTarget)
					if (rootPart.Position - data.PatrolTarget).Magnitude < 8 then
						data.PatrolTarget = getRandomPatrolPoint()
						task.wait(math.random(1, 3))
					end
				end
			elseif data.State == "Chasing" then
				local target = data.Target
				local targetRoot = target and target:FindFirstChild("HumanoidRootPart")
				local targetHum = target and target:FindFirstChildOfClass("Humanoid")
				if not targetRoot or not targetHum or targetHum.Health <= 0 then
					data.State = "Patrol"
					data.Target = nil
					data.PatrolTarget = getRandomPatrolPoint()
				else
					local dist = (rootPart.Position - targetRoot.Position).Magnitude
					if dist > RUNNER_DETECTION * 1.5 then
						data.State = "Patrol"
						data.Target = nil
					elseif dist <= RUNNER_ATTACK_RANGE then
						data.State = "Attacking"
					else
						humanoid:MoveTo(targetRoot.Position)
					end
				end
			elseif data.State == "Attacking" then
				local target = data.Target
				local targetRoot = target and target:FindFirstChild("HumanoidRootPart")
				local targetHum = target and target:FindFirstChildOfClass("Humanoid")
				if not targetRoot or not targetHum or targetHum.Health <= 0 then
					data.State = "Patrol"
					data.Target = nil
				else
					local dist = (rootPart.Position - targetRoot.Position).Magnitude
					if dist > RUNNER_ATTACK_RANGE then
						data.State = "Chasing"
					else
						humanoid:MoveTo(rootPart.Position)
						if os.clock() >= data.NextAttackTime then
							data.NextAttackTime = os.clock() + RUNNER_COOLDOWN
							if attackTrack then
								attackTrack:Play()
							end
							targetHum:TakeDamage(RUNNER_DAMAGE)
							task.spawn(function()
								for _, part in target:GetChildren() do
									if part:IsA("BasePart") then
										local old = part.Color
										part.Color = Color3.fromRGB(255, 0, 0)
										task.wait(0.1)
										part.Color = old
									end
								end
							end)
						end
					end
				end
			end
			task.wait(0.2)
		end
	end)

	humanoid.Died:Connect(function()
		activeRunners[runner] = nil
		if currentTrack then
			currentTrack:Stop(0.05)
		end
		if attackTrack then
			attackTrack:Stop(0.05)
		end
		RemoteEvents.MutantDied:FireAllClients(runner.Name, rootPart.Position)

		-- 🌟 BLOC 2 : Loot Runner
		dropLootToNearestPlayer(rootPart.Position, RUNNER_LOOT)

		task.wait(4)
		if runner.Parent then
			runner:Destroy()
		end
	end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- TANK (ALPHA) BEHAVIOR
-- ═══════════════════════════════════════════════════════════════════════════

-- Alerte TOUS les mutants (runners + tanks) dans un grand rayon autour du Tank
local function alertAllMutants(targetChar: Model, sourcePos: Vector3)
	for runner, data in activeRunners do
		if data.State == "Patrol" then
			local root = runner:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - sourcePos).Magnitude < TANK_AGGRO_RADIUS then
				data.State = "Chasing"
				data.Target = targetChar
			end
		end
	end
	for tank, data in activeTanks do
		if data.State == "Patrol" then
			local root = tank:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - sourcePos).Magnitude < TANK_AGGRO_RADIUS then
				data.State = "Chasing"
				data.Target = targetChar
			end
		end
	end
end

local function startTankBehavior(tank: Model)
	local humanoid = tank:FindFirstChildOfClass("Humanoid")
	local rootPart = tank:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then
		return
	end

	-- Armure : on intercepte TakeDamage via un script sur le personnage
	-- On surcharge MaxHealth pour indiquer l'armure dans les stats
	humanoid.MaxHealth = 300
	humanoid.Health = 300

	-- Remplacer TakeDamage par une version avec armure
	-- On passe par un script local dans le modèle du tank
	local armorTag = Instance.new("NumberValue")
	armorTag.Name = "Armor"
	armorTag.Value = TANK_ARMOR
	armorTag.Parent = tank

	-- Patch : on connecte HealthChanged pour appliquer l'armure a posteriori
	-- (La méthode propre sans OverrideHealth est de patcher dans le script d'IA)
	local lastHealth = humanoid.Health
	humanoid.HealthChanged:Connect(function(newHealth)
		local delta = lastHealth - newHealth
		if delta > 0 then
			-- Réduire les dégâts réels en rendant une partie des PV
			local blocked = delta * TANK_ARMOR
			local restore = math.floor(blocked)
			if restore > 0 then
				humanoid.Health = math.min(humanoid.MaxHealth, newHealth + restore)
			end
		end
		lastHealth = humanoid.Health
	end)

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local attackTrack = animator:LoadAnimation(attackAnimation)

	local data = {
		State = "Patrol",
		Target = nil,
		NextAttackTime = 0,
		PatrolTarget = getRandomPatrolPoint(),
		IsCharging = false,
	}
	activeTanks[tank] = data

	humanoid.WalkSpeed = TANK_SPEED_WALK

	task.spawn(function()
		while tank.Parent and humanoid.Health > 0 do
			if data.State == "Patrol" then
				local target = findNearestTarget(rootPart, TANK_DETECTION)
				if target then
					data.State = "Charging"
					data.Target = target
					-- Le Tank aggro TOUT le monde autour
					alertAllMutants(target, rootPart.Position)
					print("[Tank Alpha] Aggro déclenchée — alerte de zone !")
				else
					humanoid:MoveTo(data.PatrolTarget)
					if (rootPart.Position - data.PatrolTarget).Magnitude < 10 then
						data.PatrolTarget = getRandomPatrolPoint()
						task.wait(math.random(2, 5))
					end
				end
			elseif data.State == "Charging" then
				local target = data.Target
				local targetRoot = target and target:FindFirstChild("HumanoidRootPart")
				local targetHum = target and target:FindFirstChildOfClass("Humanoid")

				if not targetRoot or not targetHum or targetHum.Health <= 0 then
					data.State = "Patrol"
					data.Target = nil
					data.IsCharging = false
					humanoid.WalkSpeed = TANK_SPEED_WALK
					data.PatrolTarget = getRandomPatrolPoint()
				else
					local dist = (rootPart.Position - targetRoot.Position).Magnitude
					if dist > TANK_DETECTION * 2 then
						data.State = "Patrol"
						data.Target = nil
						data.IsCharging = false
						humanoid.WalkSpeed = TANK_SPEED_WALK
					elseif dist <= TANK_ATTACK_RANGE then
						-- En portée : passe en frappe
						data.State = "Attacking"
						data.IsCharging = false
						humanoid.WalkSpeed = TANK_SPEED_WALK
					else
						-- Charge : vitesse x2.6
						if not data.IsCharging then
							data.IsCharging = true
							humanoid.WalkSpeed = TANK_SPEED_CHARGE
						end
						humanoid:MoveTo(targetRoot.Position)
					end
				end
			elseif data.State == "Attacking" then
				local target = data.Target
				local targetRoot = target and target:FindFirstChild("HumanoidRootPart")
				local targetHum = target and target:FindFirstChildOfClass("Humanoid")

				if not targetRoot or not targetHum or targetHum.Health <= 0 then
					data.State = "Patrol"
					data.Target = nil
					data.IsCharging = false
					humanoid.WalkSpeed = TANK_SPEED_WALK
				else
					local dist = (rootPart.Position - targetRoot.Position).Magnitude
					if dist > TANK_ATTACK_RANGE * 1.5 then
						data.State = "Charging"
					else
						humanoid:MoveTo(rootPart.Position)
						if os.clock() >= data.NextAttackTime then
							data.NextAttackTime = os.clock() + TANK_COOLDOWN
							if attackTrack then
								attackTrack:Play()
							end
							-- Les dégâts du Tank sont bruts (l'armure du joueur n'existe pas encore)
							targetHum:TakeDamage(TANK_DAMAGE)
							-- Flash orange (couleur distincte du Runner)
							task.spawn(function()
								for _, part in target:GetChildren() do
									if part:IsA("BasePart") then
										local old = part.Color
										part.Color = Color3.fromRGB(255, 140, 0)
										task.wait(0.15)
										part.Color = old
									end
								end
							end)
						end
					end
				end
			end
			task.wait(0.2)
		end
	end)

	humanoid.Died:Connect(function()
		activeTanks[tank] = nil
		if attackTrack then
			attackTrack:Stop(0.05)
		end
		RemoteEvents.MutantDied:FireAllClients(tank.Name, rootPart.Position)

		-- 🌟 BLOC 2 : Loot Tank (enrichi)
		dropLootToNearestPlayer(rootPart.Position, TANK_LOOT)

		task.wait(6)
		if tank.Parent then
			tank:Destroy()
		end
	end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SPAWN LOOP
-- ═══════════════════════════════════════════════════════════════════════════
function MutantService.InitSpawning()
	local zoneFolder = ZoneSetup.GetZoneFolder(SPAWN_ZONE_NAME)
	if not zoneFolder then
		warn("[MUTANT SERVICE] Impossible d'initialiser le spawn, la Terre Désolée n'existe pas.")
		return
	end

	-- Boucle Runners
	task.spawn(function()
		while true do
			local count = 0
			for _ in activeRunners do
				count += 1
			end
			if count < MAX_RUNNERS then
				for _ = 1, MAX_RUNNERS - count do
					local clone = runnerTemplate:Clone()
					clone:SetPrimaryPartCFrame(CFrame.new(getRandomPatrolPoint() + Vector3.new(0, 5, 0)))
					clone.Parent = zoneFolder
					local hum = clone:FindFirstChildOfClass("Humanoid")
					if hum then
						hum.WalkSpeed = RUNNER_SPEED
					end
					startRunnerBehavior(clone)
				end
				print("[MUTANT SERVICE] Vague Runners. Total actif : " .. MAX_RUNNERS)
			end
			task.wait(10)
		end
	end)

	-- Boucle Tanks (si le template existe)
	if tankTemplate then
		task.spawn(function()
			while true do
				local count = 0
				for _ in activeTanks do
					count += 1
				end
				if count < MAX_TANKS then
					for _ = 1, MAX_TANKS - count do
						local clone = tankTemplate:Clone()
						clone:SetPrimaryPartCFrame(CFrame.new(getRandomPatrolPoint() + Vector3.new(0, 5, 0)))
						clone.Parent = zoneFolder
						startTankBehavior(clone)
					end
					print("[MUTANT SERVICE] Spawn Tank Alpha. Total actif : " .. MAX_TANKS)
				end
				task.wait(30) -- les Tanks spawent moins souvent
			end
		end)
	else
		warn(
			"[MUTANT SERVICE] MutantTank introuvable dans ServerStorage/Monsters — tank désactivé. Crée le modèle en Studio."
		)
	end
end

return MutantService
