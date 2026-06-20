-- RemoteEvents.luau
-- Module centralisé qui crée (côté serveur) ou récupère (côté client)
-- tous les RemoteEvents et RemoteFunctions du jeu.

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

local UpdateHealth = getOrCreate(folder, "UpdateHealth", "RemoteEvent")
local PlayerDied = getOrCreate(folder, "PlayerDied", "RemoteEvent")
local LootSpawned = getOrCreate(folder, "LootSpawned", "RemoteEvent")
local LootRemoved = getOrCreate(folder, "LootRemoved", "RemoteEvent")
local RequestLoot = getOrCreate(folder, "RequestLoot", "RemoteEvent")

-- 🌟 NOUVEAUX ÉVÉNEMENTS DE COMBAT
-- Client → Serveur : Le joueur tire avec une arme à distance
-- Payload : { origin: Vector3, direction: Vector3, weaponName: string }
local WeaponFire = getOrCreate(folder, "WeaponFire", "RemoteEvent")

-- Client → Serveur : Le joueur attaque au corps à corps
-- Payload : { weaponName: string }
local WeaponMelee = getOrCreate(folder, "WeaponMelee", "RemoteEvent")

-- ─────────────────────────────────────────────────────────────────────────────
-- BindableEvents (Server → Server, pour communication inter-scripts)
-- ─────────────────────────────────────────────────────────────────────────────

local RequestRespawn = getOrCreate(folder, "RequestRespawn", "BindableEvent")

return {
	UpdateHealth = UpdateHealth :: RemoteEvent,
	PlayerDied = PlayerDied :: RemoteEvent,
	LootSpawned = LootSpawned :: RemoteEvent,
	LootRemoved = LootRemoved :: RemoteEvent,
	RequestLoot = RequestLoot :: RemoteEvent,
	WeaponFire = WeaponFire :: RemoteEvent,
	WeaponMelee = WeaponMelee :: RemoteEvent,
	RequestRespawn = RequestRespawn :: BindableEvent,
}
