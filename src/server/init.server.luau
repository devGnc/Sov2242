local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local ProfileService = require(ServerScriptService.ServerPackages.profileservice)

Players.CharacterAutoLoads = false

local FACTION_NONE = "None"
local FACTION_SOLDIER = "Soldier"
local FACTION_OUTCAST = "Outcast"

local PROFILE_TEMPLATE = {
	Faction = FACTION_NONE,
	FactionLocked = false,
	CreditsC = 0,
	PiecesP = 0,
	PermanentInventory = {},
}

local PROFILE_STORE = ProfileService.GetProfileStore("Sov2242_PlayerData_V1", PROFILE_TEMPLATE)

local SPAWN_FOLDER_NAME = "SpawnPoints"
local SPAWN_NEUTRAL_BASE = "Spawn_Neutral_Base"
local SPAWN_SOLDIER_BASE = "Spawn_Soldier_Base"
local SPAWN_OUTCAST_HUB = "Spawn_Outcast_Hub"
local SPAWN_TEST_ZONE = "Spawn_Test_Zone"

local activeProfiles: {[Player]: any} = {}
local spawnPoints: {[string]: SpawnLocation} = {}

local function ensureSpawnLocation(
	folder: Instance,
	name: string,
	cframe: CFrame,
	color: Color3
): SpawnLocation
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("SpawnLocation") then
		return existing
	end

	if existing then
		existing:Destroy()
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = name
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = cframe
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.CanCollide = true
	spawn.Transparency = 0.2
	spawn.Color = color
	spawn.Parent = folder

	return spawn
end

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

local function ensureWorldSetup()
	local spawnFolder = Workspace:FindFirstChild(SPAWN_FOLDER_NAME)
	if not spawnFolder then
		spawnFolder = Instance.new("Folder")
		spawnFolder.Name = SPAWN_FOLDER_NAME
		spawnFolder.Parent = Workspace
	end

	spawnPoints[SPAWN_NEUTRAL_BASE] =
		ensureSpawnLocation(spawnFolder, SPAWN_NEUTRAL_BASE, CFrame.new(0, 6, 0), Color3.fromRGB(120, 150, 255))
	spawnPoints[SPAWN_SOLDIER_BASE] =
		ensureSpawnLocation(spawnFolder, SPAWN_SOLDIER_BASE, CFrame.new(16, 6, 0), Color3.fromRGB(80, 145, 255))
	spawnPoints[SPAWN_OUTCAST_HUB] =
		ensureSpawnLocation(spawnFolder, SPAWN_OUTCAST_HUB, CFrame.new(0, 6, 24), Color3.fromRGB(255, 170, 70))
	spawnPoints[SPAWN_TEST_ZONE] =
		ensureSpawnLocation(spawnFolder, SPAWN_TEST_ZONE, CFrame.new(120, 6, 0), Color3.fromRGB(255, 255, 120))

	local recruiter = Workspace:FindFirstChild("FactionRecruiter")
	if recruiter and not recruiter:IsA("BasePart") then
		recruiter:Destroy()
		recruiter = nil
	end

	if not recruiter then
		local recruiterPart = Instance.new("Part")
		recruiterPart.Name = "FactionRecruiter"
		recruiterPart.Size = Vector3.new(3, 6, 3)
		recruiterPart.CFrame = CFrame.new(0, 3, -10)
		recruiterPart.Anchored = true
		recruiterPart.BrickColor = BrickColor.new("Dark stone grey")
		recruiterPart.Parent = Workspace
		recruiter = recruiterPart
	end

	local soldierPrompt = ensurePrompt(
		recruiter,
		"ChooseSoldierPrompt",
		"Join Soldiers",
		"Recruitment Officer"
	)
	local outcastPrompt = ensurePrompt(
		recruiter,
		"ChooseOutcastPrompt",
		"Join Outcasts",
		"Recruitment Officer"
	)

	return soldierPrompt, outcastPrompt
end

local function getSpawnFromFaction(faction: string): SpawnLocation?
	if faction == FACTION_SOLDIER then
		return spawnPoints[SPAWN_SOLDIER_BASE]
	end

	if faction == FACTION_OUTCAST then
		return spawnPoints[SPAWN_OUTCAST_HUB]
	end

	return spawnPoints[SPAWN_NEUTRAL_BASE]
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

local soldierPrompt, outcastPrompt = ensureWorldSetup()

soldierPrompt.Triggered:Connect(function(player)
	setFaction(player, FACTION_SOLDIER)
end)

outcastPrompt.Triggered:Connect(function(player)
	setFaction(player, FACTION_OUTCAST)
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
