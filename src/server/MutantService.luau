local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")

local ZoneSetup = require(script.Parent.ZoneSetup)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local MutantService = {}

-- ⚙️ CONFIGURATION DE L'IA RUNNER
local SPAWN_ZONE_NAME = "Zone_TerreDesolee"
local MAX_RUNNERS = 8 -- Nombre maximum de Runners simultanés sur la map
local DETECTION_RADIUS = 35 -- Distance de détection d'un joueur (en studs)
local MEUTE_RADIUS = 45 -- Distance pour alerter les autres mutants
local ATTACK_RANGE = 4 -- Distance pour mordre le joueur
local ATTACK_DAMAGE = 15 -- Dégâts par coup
local ATTACK_COOLDOWN = 1.2 -- Temps entre deux attaques

-- 🌟 CRÉATION DE L'OBJET ANIMATION D'ATTAQUE GLOBAL
local attackAnimation = Instance.new("Animation")
attackAnimation.AnimationId = "rbxassetid://913384386" -- Coup de poing / Attaque R15

local activeRunners = {}
local templates = ServerStorage:WaitForChild("Monsters")
local runnerTemplate = templates:WaitForChild("MutantRunner")

-- Trouver le joueur le plus proche
local function findNearestTarget(runnerRoot: BasePart)
	local nearestPlayer = nil
	local shortestDistance = DETECTION_RADIUS

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then
			continue
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local rootPart = character:FindFirstChild("HumanoidRootPart")

		if humanoid and humanoid.Health > 0 and rootPart then
			local distance = (runnerRoot.Position - rootPart.Position).Magnitude
			if distance < shortestDistance then
				shortestDistance = distance
				nearestPlayer = character
			end
		end
	end
	return nearestPlayer, shortestDistance
end

-- Système de meute
local function alertMeute(fleeingPlayerCharacter, instigatorRunner)
	for runner, data in activeRunners do
		if runner == instigatorRunner then
			continue
		end
		if data.State == "Patrol" then
			local root = runner:FindFirstChild("HumanoidRootPart")
			local instigatorRoot = instigatorRunner:FindFirstChild("HumanoidRootPart")
			if root and instigatorRoot then
				local distance = (root.Position - instigatorRoot.Position).Magnitude
				if distance < MEUTE_RADIUS then
					data.State = "Chasing"
					data.Target = fleeingPlayerCharacter
				end
			end
		end
	end
end

-- Point aléatoire de patrouille
local function getRandomPatrolPoint()
	local zonePos = ZoneSetup.GetZonePosition(SPAWN_ZONE_NAME) or Vector3.new(6000, 0, 0)
	local randomX = math.random(-250, 250)
	local randomZ = math.random(-250, 250)
	return Vector3.new(zonePos.X + randomX, zonePos.Y + 3, zonePos.Z + randomZ)
end

-- Logique de comportement et d'animation de l'IA
local function startRunnerBehavior(runner: Model)
	local humanoid = runner:FindFirstChildOfClass("Humanoid")
	local rootPart = runner:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then
		return
	end

	-- INJECTION DES ANIMATIONS DE MOUVEMENT
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)

	local runAnim = Instance.new("Animation")
	runAnim.AnimationId = "rbxassetid://913376220"

	local idleAnim = Instance.new("Animation")
	idleAnim.AnimationId = "rbxassetid://913402848"

	local runTrack = animator:LoadAnimation(runAnim)
	local idleTrack = animator:LoadAnimation(idleAnim)
	local attackTrack = animator:LoadAnimation(attackAnimation) -- 🌟 Pré-chargement de l'attaque ici
	local currentTrack = nil

	local function playAnimation(newTrack)
		if currentTrack == newTrack then
			return
		end
		if currentTrack then
			currentTrack:Stop(0.1)
		end
		currentTrack = newTrack
		if currentTrack then
			currentTrack:Play(0.1)
		end
	end

	playAnimation(idleTrack)

	humanoid.Running:Connect(function(speed)
		if speed > 0.5 then
			playAnimation(runTrack)
			runTrack:AdjustSpeed(speed / 16)
		else
			playAnimation(idleTrack)
		end
	end)

	local runnerData = {
		State = "Patrol",
		Target = nil,
		NextAttackTime = 0,
		PatrolTarget = getRandomPatrolPoint(),
	}
	activeRunners[runner] = runnerData

	task.spawn(function()
		while runner.Parent and humanoid.Health > 0 do
			local currentState = runnerData.State

			if currentState == "Patrol" then
				local target, dist = findNearestTarget(rootPart)
				if target then
					runnerData.State = "Chasing"
					runnerData.Target = target
					alertMeute(target, runner)
				else
					humanoid:MoveTo(runnerData.PatrolTarget)
					if (rootPart.Position - runnerData.PatrolTarget).Magnitude < 8 then
						runnerData.PatrolTarget = getRandomPatrolPoint()
						task.wait(math.random(1, 3))
					end
				end
			elseif currentState == "Chasing" then
				local target = runnerData.Target
				local targetRoot = target and target:FindFirstChild("HumanoidRootPart")
				local targetHumanoid = target and target:FindFirstChildOfClass("Humanoid")

				if not targetRoot or not targetHumanoid or targetHumanoid.Health <= 0 then
					runnerData.State = "Patrol"
					runnerData.Target = nil
					runnerData.PatrolTarget = getRandomPatrolPoint()
				else
					local distance = (rootPart.Position - targetRoot.Position).Magnitude
					if distance > DETECTION_RADIUS * 1.5 then
						runnerData.State = "Patrol"
						runnerData.Target = nil
					elseif distance <= ATTACK_RANGE then
						runnerData.State = "Attacking"
					else
						humanoid:MoveTo(targetRoot.Position)
					end
				end
			elseif currentState == "Attacking" then
				local target = runnerData.Target
				local targetRoot = target and target:FindFirstChild("HumanoidRootPart")
				local targetHumanoid = target and target:FindFirstChildOfClass("Humanoid")

				if not targetRoot or not targetHumanoid or targetHumanoid.Health <= 0 then
					runnerData.State = "Patrol"
					runnerData.Target = nil
				else
					local distance = (rootPart.Position - targetRoot.Position).Magnitude
					if distance > ATTACK_RANGE then
						runnerData.State = "Chasing"
					else
						-- On lui dit de suivre le joueur mais de s'arrêter s'il est au contact
						humanoid:MoveTo(rootPart.Position)

						if os.clock() >= runnerData.NextAttackTime then
							runnerData.NextAttackTime = os.clock() + ATTACK_COOLDOWN

							-- 🌟 FIX : Joue la piste préalablement chargée sans planter
							if attackTrack then
								attackTrack:Play()
							end

							targetHumanoid:TakeDamage(ATTACK_DAMAGE)

							-- Effet visuel de flash rouge sur la victime
							task.spawn(function()
								for _, part in target:GetChildren() do
									if part:IsA("BasePart") then
										local oldColor = part.Color
										part.Color = Color3.fromRGB(255, 0, 0)
										task.wait(0.1)
										part.Color = oldColor
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

		task.wait(4)
		runner:Destroy()
	end)
end

-- Boucle d'apparition des mutants
function MutantService.InitSpawning()
	local zoneFolder = ZoneSetup.GetZoneFolder(SPAWN_ZONE_NAME)
	if not zoneFolder then
		warn("[MUTANT SERVICE] Impossible d'initialiser le spawn, la Terre Désolée n'existe pas.")
		return
	end

	task.spawn(function()
		while true do
			local currentCount = 0
			for _ in activeRunners do
				currentCount += 1
			end

			if currentCount < MAX_RUNNERS then
				local spawnNeeded = MAX_RUNNERS - currentCount
				for i = 1, spawnNeeded do
					local clone = runnerTemplate:Clone()
					local randomSpawnPos = getRandomPatrolPoint()

					clone:SetPrimaryPartCFrame(CFrame.new(randomSpawnPos + Vector3.new(0, 5, 0)))
					clone.Parent = zoneFolder

					-- On s'assure qu'ils ont une vitesse équilibrée
					local humanoid = clone:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid.WalkSpeed = 15
					end

					startRunnerBehavior(clone)
				end
				print("[MUTANT SERVICE] Vague de Runners générée. Total actif : " .. MAX_RUNNERS)
			end
			task.wait(10)
		end
	end)
end

return MutantService
