-- RemoteEvents.luau
-- Module centralisé qui crée (côté serveur) ou récupère (côté client)
-- tous les RemoteEvents et RemoteFunctions du jeu.
-- Usage : local RE = require(ReplicatedStorage.Shared.RemoteEvents)
--         RE.PlayerDied:FireClient(player, data)

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IS_SERVER = RunService:IsServer()

-- Dossier conteneur dans ReplicatedStorage
local function getOrCreateFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if existing and existing:IsA("Folder") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	if IS_SERVER then
		local folder = Instance.new("Folder")
		folder.Name = "RemoteEvents"
		folder.Parent = ReplicatedStorage
		return folder
	end
	-- Côté client : attendre que le serveur crée le dossier
	return ReplicatedStorage:WaitForChild("RemoteEvents", 15) :: Folder
end

local function getOrCreate(folder: Folder, name: string, className: string): Instance
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing
	end
	if IS_SERVER then
		local obj = Instance.new(className)
		obj.Name = name
		obj.Parent = folder
		return obj
	end
	return folder:WaitForChild(name, 15)
end

local folder = getOrCreateFolder()

-- ─────────────────────────────────────────────────────────────────────────────
-- RemoteEvents (Server → Client ou Client → Server)
-- ─────────────────────────────────────────────────────────────────────────────

-- Serveur → Client : met à jour la barre de vie affichée chez le joueur
-- Payload : { current: number, max: number }
local UpdateHealth = getOrCreate(folder, "UpdateHealth", "RemoteEvent")

-- Serveur → Client : le joueur vient de mourir, afficher l'écran de mort
-- Payload : { killerFaction: string? }
local PlayerDied = getOrCreate(folder, "PlayerDied", "RemoteEvent")

-- Serveur → Client : un sac de loot est apparu à une position
-- Payload : { bagId: string, position: Vector3, lootCount: number, ownerId: number }
local LootSpawned = getOrCreate(folder, "LootSpawned", "RemoteEvent")

-- Serveur → Client : un sac de loot a expiré ou a été pillé, l'enlever du HUD
-- Payload : { bagId: string }
local LootRemoved = getOrCreate(folder, "LootRemoved", "RemoteEvent")

-- Client → Serveur : le joueur demande à piller un sac
-- Payload : { bagId: string }
local RequestLoot = getOrCreate(folder, "RequestLoot", "RemoteEvent")

-- ─────────────────────────────────────────────────────────────────────────────
-- BindableEvents (Server → Server, pour communication inter-scripts)
-- ─────────────────────────────────────────────────────────────────────────────

-- CombatService → MainServer : demande de réapparition après mort
-- Payload : player
local RequestRespawn = getOrCreate(folder, "RequestRespawn", "BindableEvent")

return {
	UpdateHealth  = UpdateHealth  :: RemoteEvent,
	PlayerDied    = PlayerDied    :: RemoteEvent,
	LootSpawned   = LootSpawned   :: RemoteEvent,
	LootRemoved   = LootRemoved   :: RemoteEvent,
	RequestLoot   = RequestLoot   :: RemoteEvent,
	RequestRespawn = RequestRespawn :: BindableEvent,
}
