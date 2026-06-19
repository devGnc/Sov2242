-- LootBagModule.luau
-- Gère tout le cycle de vie d'un sac de loot volatile :
-- création à la mort, affichage en jeu, pillage, expiration.
-- Doit être require() uniquement côté SERVEUR.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local BAG_LIFETIME_SECONDS = 300  -- 5 minutes
local BAG_SIZE             = Vector3.new(2.5, 1.5, 1.5)
local BAG_COLOR            = Color3.fromRGB(180, 130, 60)

-- Dossier Workspace pour ranger les sacs (propre, facile à débugger)
local function getBagsFolder(): Folder
	local existing = Workspace:FindFirstChild("LootBags")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "LootBags"
	folder.Parent = Workspace
	return folder
end

-- Table interne : bagId → { model, loot, connections }
local activeBags: { [string]: { model: Model, loot: { [string]: number }, connections: { RBXScriptConnection } } } = {}

local LootBagModule = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Interne : destruction propre d'un sac
-- ─────────────────────────────────────────────────────────────────────────────
local function destroyBag(bagId: string)
	local entry = activeBags[bagId]
	if not entry then
		return
	end

	-- Déconnecter tous les listeners
	for _, conn in entry.connections do
		conn:Disconnect()
	end

	-- Détruire le model en jeu
	if entry.model and entry.model.Parent then
		entry.model:Destroy()
	end

	activeBags[bagId] = nil

	-- Notifier tous les clients pour enlever l'indicateur HUD
	RemoteEvents.LootRemoved:FireAllClients({ bagId = bagId })
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Spawn : crée un sac au sol à la position du joueur mort
-- lootTable : { ["Tissus mutés"] = 12, ["Composants corrompus"] = 3, ... }
-- ─────────────────────────────────────────────────────────────────────────────
function LootBagModule.Spawn(deadPlayer: Player, lootTable: { [string]: number })
	local character = deadPlayer.Character
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end

	-- Générer un ID unique
	local bagId = ("%d_%d"):format(deadPlayer.UserId, os.clock() * 1000 // 1)

	-- Créer le model du sac
	local bagsFolder = getBagsFolder()
	local model = Instance.new("Model")
	model.Name = ("LootBag_%s"):format(bagId)

	-- Part principale (le sac visible)
	local part = Instance.new("Part")
	part.Name        = "BagPart"
	part.Size        = BAG_SIZE
	part.Color       = BAG_COLOR
	part.Material    = Enum.Material.Fabric
	part.Anchored    = false
	part.CanCollide  = true
	-- Spawn légèrement au-dessus pour ne pas clipper le sol
	part.CFrame      = CFrame.new(rootPart.Position + Vector3.new(0, 2, 0))
	part.Parent      = model

	model.PrimaryPart = part

	-- BillboardGui : nom du joueur + compteur de loot au-dessus du sac
	local billboard = Instance.new("BillboardGui")
	billboard.Name            = "BagLabel"
	billboard.Adornee         = part
	billboard.Size            = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset     = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop     = false
	billboard.MaxDistance     = 40
	billboard.ResetOnSpawn    = false
	billboard.Parent          = part

	local label = Instance.new("TextLabel")
	label.Size                = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3          = Color3.fromRGB(255, 220, 100)
	label.TextStrokeColor3    = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.3
	label.Font                = Enum.Font.GothamBold
	label.TextScaled          = true
	label.Text                = ("💀 %s · %d items"):format(deadPlayer.DisplayName, #lootTable)
	label.Parent              = billboard

	-- Stocker le contenu du loot dans des StringValues (lisibles depuis le client si besoin)
	local lootFolder = Instance.new("Folder")
	lootFolder.Name   = "LootData"
	lootFolder.Parent = model

	local totalItems = 0
	for itemName, qty in lootTable do
		local v = Instance.new("NumberValue")
		v.Name   = itemName
		v.Value  = qty
		v.Parent = lootFolder
		totalItems += qty
	end

	-- Métadonnées
	local ownerVal = Instance.new("NumberValue")
	ownerVal.Name   = "OwnerId"
	ownerVal.Value  = deadPlayer.UserId
	ownerVal.Parent = model

	local bagIdVal = Instance.new("StringValue")
	bagIdVal.Name   = "BagId"
	bagIdVal.Value  = bagId
	bagIdVal.Parent = model

	model.Parent = bagsFolder

	-- ProximityPrompt pour piller
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name                = "LootPrompt"
	prompt.ActionText          = "Piller"
	prompt.ObjectText          = ("Sac de %s"):format(deadPlayer.DisplayName)
	prompt.HoldDuration        = 1.2
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent              = part

	-- Connexions
	local connections: { RBXScriptConnection } = {}

	-- Écouter la demande de pillage via le prompt en jeu
	table.insert(connections, prompt.Triggered:Connect(function(looter: Player)
		LootBagModule.Loot(looter, bagId)
	end))

	-- Écouter la demande de pillage via RemoteEvent (depuis le client)
	table.insert(connections, RemoteEvents.RequestLoot.OnServerEvent:Connect(function(looter: Player, data: { bagId: string })
		if data and data.bagId == bagId then
			LootBagModule.Loot(looter, bagId)
		end
	end))

	-- Enregistrer dans la table interne
	activeBags[bagId] = {
		model       = model,
		loot        = lootTable,
		connections = connections,
	}

	-- Timer d'expiration (5 minutes)
	task.delay(BAG_LIFETIME_SECONDS, function()
		destroyBag(bagId)
	end)

	-- Notifier tous les clients de l'existence du sac
	RemoteEvents.LootSpawned:FireAllClients({
		bagId      = bagId,
		position   = part.Position,
		lootCount  = totalItems,
		ownerId    = deadPlayer.UserId,
	})

	print(("[LootBag] Sac spawné pour %s — %d types d'items — ID: %s"):format(
		deadPlayer.Name, #lootTable, bagId
	))
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Loot : un joueur récupère le contenu du sac
-- Retourne la table de loot si succès, nil si sac inexistant
-- ─────────────────────────────────────────────────────────────────────────────
function LootBagModule.Loot(looter: Player, bagId: string): ({ [string]: number }?)
	local entry = activeBags[bagId]
	if not entry then
		return nil
	end

	local loot = entry.loot
	destroyBag(bagId)

	print(("[LootBag] %s a pillé le sac %s"):format(looter.Name, bagId))

	-- TODO Bloc 3 : ajouter le loot à l'inventaire du pilleur
	-- Pour l'instant, on log juste le contenu
	for itemName, qty in loot do
		print(("  → %s x%d"):format(itemName, qty))
	end

	return loot
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Utilitaire : récupérer le loot d'un sac sans le détruire (pour l'UI)
-- ─────────────────────────────────────────────────────────────────────────────
function LootBagModule.Peek(bagId: string): ({ [string]: number }?)
	local entry = activeBags[bagId]
	return entry and entry.loot or nil
end

return LootBagModule
