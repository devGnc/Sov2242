-- LootBagModule.luau
-- Gère tout le cycle de vie d'un sac de loot volatile :
-- création à la mort, affichage en jeu, pillage, expiration.
-- Requis uniquement côté SERVEUR.
-- Correction Bloc 1 : le pilleur reçoit bien le loot dans son sessionLoot.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

-- CombatService est requis en différé (évite la dépendance circulaire au chargement)
local CombatService = nil
local function getCombatService()
	if not CombatService then
		CombatService = require(game:GetService("ServerScriptService").Scripts.CombatService)
	end
	return CombatService
end

local BAG_LIFETIME_SECONDS = 300   -- 5 minutes
local BAG_SIZE             = Vector3.new(2.5, 1.5, 1.5)
local BAG_COLOR            = Color3.fromRGB(180, 130, 60)

local function getBagsFolder(): Folder
	local existing = Workspace:FindFirstChild("LootBags")
	if existing and existing:IsA("Folder") then return existing end
	local folder = Instance.new("Folder")
	folder.Name   = "LootBags"
	folder.Parent = Workspace
	return folder
end

-- { bagId → { model, loot, connections } }
local activeBags: { [string]: {
	model       : Model,
	loot        : { [string]: number },
	connections : { RBXScriptConnection },
}} = {}

local LootBagModule = {}

-- ─── Destruction propre ───────────────────────────────────────────────────────
local function destroyBag(bagId: string)
	local entry = activeBags[bagId]
	if not entry then return end

	for _, conn in entry.connections do conn:Disconnect() end

	if entry.model and entry.model.Parent then
		entry.model:Destroy()
	end

	activeBags[bagId] = nil
	RemoteEvents.LootRemoved:FireAllClients({ bagId = bagId })
end

-- ─── Spawn ────────────────────────────────────────────────────────────────────
function LootBagModule.Spawn(deadPlayer: Player, lootTable: { [string]: number })
	local character = deadPlayer.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then return end

	local bagId = ("%d_%d"):format(deadPlayer.UserId, math.floor(os.clock() * 1000))

	-- ── Model ──
	local bagsFolder = getBagsFolder()
	local model = Instance.new("Model")
	model.Name = ("LootBag_%s"):format(bagId)

	local part = Instance.new("Part")
	part.Name       = "BagPart"
	part.Size       = BAG_SIZE
	part.Color      = BAG_COLOR
	part.Material   = Enum.Material.Fabric
	part.Anchored   = false
	part.CanCollide = true
	part.CFrame     = CFrame.new(rootPart.Position + Vector3.new(0, 2, 0))
	part.Parent     = model

	model.PrimaryPart = part

	-- ── BillboardGui ──
	local billboard = Instance.new("BillboardGui")
	billboard.Name         = "BagLabel"
	billboard.Adornee      = part
	billboard.Size         = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset  = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop  = false
	billboard.MaxDistance  = 40
	billboard.ResetOnSpawn = false
	billboard.Parent       = part

	local label = Instance.new("TextLabel")
	label.Size                  = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3            = Color3.fromRGB(255, 220, 100)
	label.TextStrokeColor3      = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.3
	label.Font                  = Enum.Font.GothamBold
	label.TextScaled            = true
	label.Text                  = ("💀 %s"):format(deadPlayer.DisplayName)
	label.Parent                = billboard

	-- ── LootData ──
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
	local ownerVal    = Instance.new("NumberValue")
	ownerVal.Name     = "OwnerId"
	ownerVal.Value    = deadPlayer.UserId
	ownerVal.Parent   = model

	local bagIdVal    = Instance.new("StringValue")
	bagIdVal.Name     = "BagId"
	bagIdVal.Value    = bagId
	bagIdVal.Parent   = model

	model.Parent = bagsFolder

	-- ── ProximityPrompt ──
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name                  = "LootPrompt"
	prompt.ActionText            = "Piller"
	prompt.ObjectText            = ("Sac de %s"):format(deadPlayer.DisplayName)
	prompt.HoldDuration          = 1.2
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight   = false
	prompt.Parent                = part

	-- ── Connexions ──
	local connections: { RBXScriptConnection } = {}

	local function doLoot(looter: Player)
		LootBagModule.Loot(looter, bagId)
	end

	table.insert(connections, prompt.Triggered:Connect(doLoot))

	table.insert(connections, RemoteEvents.RequestLoot.OnServerEvent:Connect(
		function(looter: Player, data: { bagId: string })
			if data and data.bagId == bagId then
				doLoot(looter)
			end
		end
	))

	activeBags[bagId] = { model = model, loot = lootTable, connections = connections }

	-- Expiration automatique
	task.delay(BAG_LIFETIME_SECONDS, function()
		destroyBag(bagId)
	end)

	-- Notifier les clients
	RemoteEvents.LootSpawned:FireAllClients({
		bagId     = bagId,
		position  = part.Position,
		lootCount = totalItems,
		ownerId   = deadPlayer.UserId,
	})

	print(("[LootBag] Sac spawné pour %s — %d items — ID: %s"):format(
		deadPlayer.Name, totalItems, bagId
	))
end

-- ─── Pillage ──────────────────────────────────────────────────────────────────
-- CORRECTION : le loot est maintenant crédité au sessionLoot du pilleur.
function LootBagModule.Loot(looter: Player, bagId: string): ({ [string]: number }?)
	local entry = activeBags[bagId]
	if not entry then return nil end

	local loot = entry.loot
	destroyBag(bagId)

	-- Créditer chaque item au loot volatile du pilleur
	local cs = getCombatService()
	for itemName, qty in loot do
		cs.AddSessionLoot(looter, itemName, qty)
		print(("[LootBag] %s reçoit %s x%d"):format(looter.Name, itemName, qty))
	end

	print(("[LootBag] %s a pillé le sac %s"):format(looter.Name, bagId))
	return loot
end

-- ─── Peek (lecture sans destruction, pour l'UI) ───────────────────────────────
function LootBagModule.Peek(bagId: string): ({ [string]: number }?)
	local entry = activeBags[bagId]
	return entry and entry.loot or nil
end

return LootBagModule
