local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local ProfileService = require(ServerScriptService.ServerPackages.profileservice)
local ZoneSetup = require(script.ZoneSetup)

Players.CharacterAutoLoads = false

local FACTION_NONE = "None"
local FACTION_SOLDIER = "Soldier"
local FACTION_OUTCAST = "Outcast"

local ZONE_BASE = "Zone_Base"
local ZONE_NID = "Zone_Nid"
local ZONE_TEST = "Zone_Test"

local PROFILE_TEMPLATE = {
	Faction = FACTION_NONE,
	FactionLocked = false,
	CreditsC = 0,
	PiecesP = 0,
	PermanentInventory = {},
}

local PROFILE_STORE = ProfileService.GetProfileStore("Sov2242_PlayerData_V1", PROFILE_TEMPLATE)

local activeProfiles: {[Player]: any} = {}

-- Pose les 4 zones (sol + panneau + point de spawn dédié) si elles n'existent pas déjà.
ZoneSetup.Run()

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

-- Le PNJ recruteur de la Base. Propose le choix définitif de faction.
-- Volontairement situé DANS la zone Base : une recrue doit s'y rendre avant de
-- pouvoir choisir, elle ne peut pas choisir depuis la Zone de Test.
local function ensureRecruiterNpc(): (ProximityPrompt?, ProximityPrompt?)
	local baseFolder = ZoneSetup.GetZoneFolder(ZONE_BASE)
	if not baseFolder then
		warn("ZoneSetup n'a pas encore créé Zone_Base, le recruteur ne peut pas être placé.")
		return nil, nil
	end

	local basePosition = ZoneSetup.GetZonePosition(ZONE_BASE) or Vector3.new(0, 0, 0)

	local recruiter = baseFolder:FindFirstChild("FactionRecruiter")
	if recruiter and not recruiter:IsA("BasePart") then
		recruiter:Destroy()
		recruiter = nil
	end

	if not recruiter then
		local recruiterPart = Instance.new("Part")
		recruiterPart.Name = "FactionRecruiter"
		recruiterPart.Size = Vector3.new(3, 6, 3)
		recruiterPart.CFrame = CFrame.new(basePosition + Vector3.new(0, 3, -10))
		recruiterPart.Anchored = true
		recruiterPart.BrickColor = BrickColor.new("Dark stone grey")
		recruiterPart.Parent = baseFolder
		recruiter = recruiterPart
	end

	local stayPrompt = ensurePrompt(recruiter, "StaySoldierPrompt", "Rester Combattant", "Officier de Liaison")
	local fleePrompt = ensurePrompt(recruiter, "FleeOutcastPrompt", "Fuir et devenir Fuyard", "Officier de Liaison")

	return stayPrompt, fleePrompt
end

-- Point de transit en Zone de Test : la recrue n'a pas encore de faction,
-- elle doit interagir ici pour être emmenée à la Base où le choix se fera.
-- Ceci ne change QUE la position physique du joueur, jamais son RespawnLocation :
-- s'il meurt avant d'avoir choisi, il doit réapparaître en Zone de Test, pas à la Base.
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

local function getSpawnFromFaction(faction: string): SpawnLocation?
	if faction == FACTION_SOLDIER then
		return ZoneSetup.GetSpawnPoint(ZONE_BASE)
	end

	if faction == FACTION_OUTCAST then
		return ZoneSetup.GetSpawnPoint(ZONE_NID)
	end

	-- Pas encore de faction (FACTION_NONE) : on est une simple recrue potentielle,
	-- on apparaît toujours en Zone de Test.
	return ZoneSetup.GetSpawnPoint(ZONE_TEST)
end

local function spawnPlayer(player: Player)
	local profile = activeProfiles[player]
	if not profile then
		return
	end

	local targetSpawn = getSpawnFromFaction(profile.Data.Faction)
	if not targetSpawn then
		return
	end

	player.RespawnLocation = targetSpawn
	player:LoadCharacter()
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

local stayPrompt, fleePrompt = ensureRecruiterNpc()
ensureTestToBaseTeleporter()

if stayPrompt then
	stayPrompt.Triggered:Connect(function(player)
		setFaction(player, FACTION_SOLDIER)
	end)
end

if fleePrompt then
	fleePrompt.Triggered:Connect(function(player)
		setFaction(player, FACTION_OUTCAST)
	end)
end

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
		return
	end

	profile:Release()
	activeProfiles[player] = nil
end)

game:BindToClose(function()
	for player, profile in pairs(activeProfiles) do
		if player and profile then
			profile:Release()
			activeProfiles[player] = nil
		end
	end
end)
