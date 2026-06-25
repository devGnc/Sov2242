-- src/server/init.server.luau
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MutantService = require(script.MutantService)
local ProfileService = require(ServerScriptService.ServerPackages.profileservice)
local ZoneSetup = require(script.ZoneSetup)
local PlaceConfig = require(ReplicatedStorage.Shared.PlaceConfig)

-- 🌟 RECTIFICATION : On charge le WeaponService pour que le serveur écoute les RemoteEvents de tir
require(script.WeaponService)

Players.CharacterAutoLoads = false

local FACTION_NONE = "None"
local FACTION_SOLDIER = "Soldier"
local FACTION_OUTCAST = "Outcast"

local ZONE_BASE = "Zone_Base"
local ZONE_NID = "Zone_Nid"
local ZONE_TEST = "Zone_Test"
local ZONE_TERRE_DESOLEE = "Zone_TerreDesolee"

local PROFILE_TEMPLATE = {
	Faction = FACTION_NONE,
	FactionLocked = false,
	CreditsC = 0,
	PiecesP = 0,
	PermanentInventory = {},
}

local PROFILE_STORE = ProfileService.GetProfileStore("Sov2242_PlayerData_V1", PROFILE_TEMPLATE)

local activeProfiles: { [Player]: any } = {}
local pendingSpawnZone: { [Player]: string } = {}

local isStudio = RunService:IsStudio()
local isTerreDesoleePlace = game.PlaceId == PlaceConfig.TerreDesoleePlaceId

local zoneDefinitions = {}
if isStudio then
	zoneDefinitions[ZONE_BASE] = true
	zoneDefinitions[ZONE_NID] = true
	zoneDefinitions[ZONE_TEST] = true
	zoneDefinitions[ZONE_TERRE_DESOLEE] = true
elseif isTerreDesoleePlace then
	zoneDefinitions[ZONE_TERRE_DESOLEE] = true
else
	zoneDefinitions[ZONE_BASE] = true
	zoneDefinitions[ZONE_NID] = true
	zoneDefinitions[ZONE_TEST] = true
end

ZoneSetup.Run(zoneDefinitions)
MutantService.InitSpawning()

local function ensurePrompt(parent: Instance, name: string, actionText: string, objectText: string): ProximityPrompt
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("ProximityPrompt") then
		existing.ActionText = actionText
		existing.ObjectText = objectText
		return existing
	end

	if existing then
		existing:Destroy()
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent

	return prompt
end

-- Point de transit en Zone de Test
local function ensureTestToBaseTeleporter()
	local testFolder = ZoneSetup.GetZoneFolder(ZONE_TEST)
	if not testFolder then
		warn("ZoneSetup n'a pas encore créé Zone_Test, le téléporteur ne peut pas être placé.")
		return
	end

	local testPosition = ZoneSetup.GetZonePosition(ZONE_TEST) or Vector3.new(0, 0, 0)

	local pad = testFolder:FindFirstChild("TeleportToBase")
	if not pad then
		local padPart = Instance.new("Part")
		padPart.Name = "TeleportToBase"
		padPart.Size = Vector3.new(6, 1, 6)
		padPart.CFrame = CFrame.new(testPosition + Vector3.new(20, 1, 0))
		padPart.Anchored = true
		padPart.Color = Color3.fromRGB(200, 60, 60)
		padPart.Parent = testFolder
		pad = padPart
	end

	local prompt = ensurePrompt(pad, "GoToBasePrompt", "Se rendre à la Base", "Convoi de la Base")

	prompt.Triggered:Connect(function(player: Player)
		local baseSpawn = ZoneSetup.GetSpawnPoint(ZONE_BASE)
		local character = player.Character
		if not baseSpawn or not character then
			return
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart then
			rootPart.CFrame = baseSpawn.CFrame + Vector3.new(0, 5, 0)
		end
	end)
end

local moveCharacterToSpawn

local function teleportPlayerBackToMainPlace(player: Player, destinationSpawnZone: string, sourceZoneName: string)
	if PlaceConfig.MainPlaceId <= 0 then
		warn(("Aucun ID de place principale valide depuis %s."):format(sourceZoneName))
		return
	end

	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions:SetTeleportData({
		sourceZone = sourceZoneName,
		returnSpawnZone = destinationSpawnZone,
	})

	local ok, err = pcall(function()
		TeleportService:TeleportAsync(PlaceConfig.MainPlaceId, { player }, teleportOptions)
	end)
	if not ok then
		warn(("Téléportation de retour impossible pour %s: %s"):format(player.Name, tostring(err)))
		if isStudio then
			local fallbackSpawn = ZoneSetup.GetSpawnPoint(destinationSpawnZone)
			if moveCharacterToSpawn(player, fallbackSpawn) then
				warn(
					("Fallback Studio actif : %s a été déplacé localement vers %s."):format(
						player.Name,
						destinationSpawnZone
					)
				)
			end
		end
	end
end

moveCharacterToSpawn = function(player: Player, spawn: SpawnLocation?)
	if not spawn then
		return false
	end

	local character = player.Character
	if not character then
		return false
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	-- ✅ CORRECTION : Si le rootPart n'existe PAS, on s'arrête. S'il existe, on continue !
	if not rootPart then
		return false
	end

	rootPart.CFrame = spawn.CFrame + Vector3.new(0, 5, 0)
	return true
end
local function teleportPlayerToPlace(player: Player, destinationPlaceId: number, sourceZoneName: string)
	if destinationPlaceId <= 0 then
		warn(("Aucun ID de place valide pour la Terre désolée depuis %s."):format(sourceZoneName))
		return
	end

	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions:SetTeleportData({
		sourceZone = sourceZoneName,
		destinationZone = ZONE_TERRE_DESOLEE,
	})

	local ok, err = pcall(function()
		TeleportService:TeleportAsync(destinationPlaceId, { player }, teleportOptions)
	end)
	if not ok then
		warn(("Téléportation vers la Terre désolée impossible pour %s: %s"):format(player.Name, tostring(err)))
		if RunService:IsStudio() then
			local fallbackSpawn = ZoneSetup.GetSpawnPoint(ZONE_TERRE_DESOLEE)
			if moveCharacterToSpawn(player, fallbackSpawn) then
				warn(
					("Fallback Studio actif : %s a été déplacé localement vers la Terre désolée de test."):format(
						player.Name
					)
				)
			end
		end
	end
end

local function ensureTerreDesoleeTeleporter(sourceZoneName: string, padName: string, offset: Vector3)
	local sourceFolder = ZoneSetup.GetZoneFolder(sourceZoneName)
	if not sourceFolder then
		warn(("ZoneSetup n'a pas encore créé %s, le téléporteur ne peut pas être placé."):format(sourceZoneName))
		return
	end

	local sourcePosition = ZoneSetup.GetZonePosition(sourceZoneName) or Vector3.new(0, 0, 0)

	local pad = sourceFolder:FindFirstChild(padName)
	if not pad then
		local padPart = Instance.new("Part")
		padPart.Name = padName
		padPart.Size = Vector3.new(6, 1, 6)
		padPart.CFrame = CFrame.new(sourcePosition + offset)
		padPart.Anchored = true
		padPart.Color = Color3.fromRGB(120, 70, 50)
		padPart.Parent = sourceFolder
		pad = padPart
	end

	local prompt = ensurePrompt(pad, "GoToTerreDesoleePrompt", "Aller à la Terre désolée", "Portail de transfert")
	prompt.Triggered:Connect(function(player: Player)
		teleportPlayerToPlace(player, PlaceConfig.TerreDesoleePlaceId, sourceZoneName)
	end)
end

local function ensureReturnTeleporter(
	sourceZoneName: string,
	padName: string,
	offset: Vector3,
	destinationSpawnZone: string,
	actionText: string,
	objectText: string
)
	local sourceFolder = ZoneSetup.GetZoneFolder(sourceZoneName)
	if not sourceFolder then
		warn(("ZoneSetup n'a pas encore créé %s, le téléporteur ne peut pas être placé."):format(sourceZoneName))
		return
	end

	local sourcePosition = ZoneSetup.GetZonePosition(sourceZoneName) or Vector3.new(0, 0, 0)

	local pad = sourceFolder:FindFirstChild(padName)
	if not pad then
		local padPart = Instance.new("Part")
		padPart.Name = padName
		padPart.Size = Vector3.new(6, 1, 6)
		padPart.CFrame = CFrame.new(sourcePosition + offset)
		padPart.Anchored = true
		padPart.Color = Color3.fromRGB(90, 130, 220)
		padPart.Parent = sourceFolder
		pad = padPart
	end

	local prompt = ensurePrompt(pad, "ReturnToMainPlacePrompt", actionText, objectText)

	prompt.Triggered:Connect(function(player: Player)
		local profile = activeProfiles[player]
		local allowed = false
		if profile then
			if destinationSpawnZone == ZONE_BASE then
				allowed = profile.Data.Faction == FACTION_SOLDIER
			elseif destinationSpawnZone == ZONE_NID then
				allowed = profile.Data.Faction == FACTION_OUTCAST
			end
		end

		if not allowed then
			warn(("%s n'est pas autorisé à utiliser le portail vers %s."):format(player.Name, destinationSpawnZone))
			return
		end

		teleportPlayerBackToMainPlace(player, destinationSpawnZone, sourceZoneName)
	end)
end

local function getSpawnFromFaction(faction: string): SpawnLocation?
	if faction == FACTION_SOLDIER then
		return ZoneSetup.GetSpawnPoint(ZONE_BASE)
	end

	if faction == FACTION_OUTCAST then
		return ZoneSetup.GetSpawnPoint(ZONE_NID)
	end

	return ZoneSetup.GetSpawnPoint(ZONE_TEST)
end

local function getJoinSpawnZone(player: Player): string?
	local joinData = player:GetJoinData()
	local teleportData = joinData.TeleportData
	if teleportData and typeof(teleportData) == "table" then
		local returnSpawnZone = teleportData.returnSpawnZone
		if returnSpawnZone == ZONE_BASE or returnSpawnZone == ZONE_NID then
			return returnSpawnZone
		end
	end

	return nil
end

local function spawnPlayer(player: Player)
	local profile = activeProfiles[player]
	if not profile then
		return
	end

	local overrideZone = pendingSpawnZone[player]
	local targetSpawn = overrideZone and ZoneSetup.GetSpawnPoint(overrideZone)
		or getSpawnFromFaction(profile.Data.Faction)
	if not targetSpawn then
		return
	end

	if overrideZone then
		pendingSpawnZone[player] = nil
	end

	local factionSpawn = getSpawnFromFaction(profile.Data.Faction)
	if factionSpawn then
		player.RespawnLocation = factionSpawn
	end

	player:LoadCharacter()

	if overrideZone then
		task.spawn(function()
			local character = player.Character or player.CharacterAdded:Wait()
			if character and character.Parent then
				local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if rootPart then
					rootPart.CFrame = targetSpawn.CFrame + Vector3.new(0, 5, 0)
				end
			end
		end)
	end
end

local function setFaction(player: Player, faction: string)
	local profile = activeProfiles[player]
	if not profile then
		return
	end

	if faction ~= FACTION_SOLDIER and faction ~= FACTION_OUTCAST then
		return
	end

	local data = profile.Data
	if data.FactionLocked then
		return
	end

	data.Faction = faction
	data.FactionLocked = true

	player:SetAttribute("Faction", data.Faction)
	player:SetAttribute("FactionLocked", data.FactionLocked)

	spawnPlayer(player)
end

-- ─── INITIALISATION MAPS ET TÉLÉPORTEURS ──────────────────────────────────────
if isStudio or not isTerreDesoleePlace then
	ensureTestToBaseTeleporter()

	ensureTerreDesoleeTeleporter(ZONE_BASE, "TeleportToTerreDesolee", Vector3.new(18, 1, 0))
	ensureTerreDesoleeTeleporter(ZONE_NID, "TeleportToTerreDesolee", Vector3.new(18, 1, 0))
end

if isStudio or isTerreDesoleePlace then
	ensureReturnTeleporter(
		ZONE_TERRE_DESOLEE,
		"ReturnToBase",
		Vector3.new(18, 1, 0),
		ZONE_BASE,
		"Rentrer à La Base",
		"Portail des Combattants"
	)
	ensureReturnTeleporter(
		ZONE_TERRE_DESOLEE,
		"ReturnToNid",
		Vector3.new(18, 1, 12),
		ZONE_NID,
		"Rentrer au Nid",
		"Portail des Fuyards"
	)
end

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
RemoteEvents.SetFaction.OnServerEvent:Connect(function(player: Player, data)
	if type(data) == "table" and data.faction then
		setFaction(player, data.faction)
	end
end)

local function loadPlayerProfile(player: Player)
	local profile = PROFILE_STORE:LoadProfileAsync(("Player_%d"):format(player.UserId), "ForceLoad")
	if not profile then
		player:Kick("Failed to load profile data.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile:ListenToRelease(function()
		activeProfiles[player] = nil
		if player.Parent == Players then
			player:Kick("Profile session ended.")
		end
	end)

	if player.Parent ~= Players then
		profile:Release()
		return
	end

	activeProfiles[player] = profile
	local joinSpawnZone = getJoinSpawnZone(player)
	if joinSpawnZone then
		pendingSpawnZone[player] = joinSpawnZone
	end
	player:SetAttribute("Faction", profile.Data.Faction)
	player:SetAttribute("FactionLocked", profile.Data.FactionLocked)

	spawnPlayer(player)
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(loadPlayerProfile, player)
end)

for _, player in Players:GetPlayers() do
	task.spawn(loadPlayerProfile, player)
end

Players.PlayerRemoving:Connect(function(player)
	local profile = activeProfiles[player]
	if not profile then
		pendingSpawnZone[player] = nil
		return
	end

	profile:Release()
	activeProfiles[player] = nil
	pendingSpawnZone[player] = nil
end)

game:BindToClose(function()
	for player, profile in pairs(activeProfiles) do
		if player and profile then
			profile:Release()
			activeProfiles[player] = nil
		end
	end
end)

local CREATOR_ID = 11071882653

local function devResetData(player: Player)
	local profile = activeProfiles[player]
	if not profile then
		warn("[DEV SYSTEM] Impossible de reset : Aucun profil trouvé dans activeProfiles pour " .. player.Name)
		return
	end

	profile.Data.Faction = FACTION_NONE
	profile.Data.FactionLocked = false
	profile.Data.CreditsC = 0
	profile.Data.PiecesP = 0
	profile.Data.PermanentInventory = {}

	player:SetAttribute("Faction", FACTION_NONE)
	player:SetAttribute("FactionLocked", false)

	print("[DEV SYSTEM] Données réinitialisées avec succès pour " .. player.Name)
	spawnPlayer(player)
end

-- ─── ÉCOUTE DES COMMANDES DEV (MODIFIÉ) ──────────────────────────────────────
-- ─── ÉCOUTE DES COMMANDES DEV (BÉTONNÉE POUR LE STUDIO) ──────────────────────
local function registerDevCommands(player: Player)
	-- On autorise la commande si c'est ton ID OU si tu es en train de tester dans Studio
	if player.UserId ~= CREATOR_ID and not RunService:IsStudio() then
		return
	end

	print("[DEV SYSTEM] Commandes prêtes pour : " .. player.Name)

	player.Chatted:Connect(function(message)
		local cleanedMessage = message:lower()

		if cleanedMessage == "/resetdata" then
			print("[DEV COMMAND] Réinitialisation des données pour " .. player.Name)
			devResetData(player)
		elseif cleanedMessage == "/give fusil" then
			-- On applique l'attribut requis par ton WeaponController
			player:SetAttribute("EquippedWeapon", "Fusil")

			-- IMPORTANT : On affiche un gros message dans la console de test (F9) pour valider
			print("=========================================")
			print("[DEV COMMAND] FUSIL ACTIVÉ POUR " .. player.Name:upper())
			print("Clique gauche pour tirer (Raycast actif) !")
			print("=========================================")
		end
	end)
end

-- Sécurité pour les prochains joueurs
Players.PlayerAdded:Connect(registerDevCommands)

-- Application immédiate pour toi dans Studio
for _, player in Players:GetPlayers() do
	task.spawn(registerDevCommands, player)
end
if RunService:IsStudio() then
	Players.PlayerAdded:Connect(function(player)
		if player.UserId ~= CREATOR_ID then
			return
		end

		task.spawn(function()
			local attempts = 0
			while not activeProfiles[player] and attempts < 20 do
				task.wait(0.2)
				attempts += 1
			end

			if activeProfiles[player] then
				print("[STUDIO AUTOMATION] Profil détecté en mémoire. Reset de la session de test.")
				devResetData(player)
			else
				warn("[STUDIO AUTOMATION] Le profil a mis trop de temps à charger, reset auto annulé.")
			end
		end)
	end)
end

local CombatService = require(game:GetService("ServerScriptService").Scripts.CombatService)

CombatService.RequestRespawn.Event:Connect(function(player: Player)
	if player and player.Parent == Players then
		spawnPlayer(player)
	end
end)
