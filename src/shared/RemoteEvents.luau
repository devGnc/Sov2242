-- RemoteEvents.luau
-- Module centralisé qui crée (côté serveur) ou récupère (côté client)
-- tous les RemoteEvents du jeu.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IS_SERVER = RunService:IsServer()

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
	return folder:WaitForChild(name, 15) :: Instance
end

local folder = getOrCreateFolder()

-- Server → Client
local UpdateHealth = getOrCreate(folder, "UpdateHealth", "RemoteEvent") -- { current, max }
local PlayerDied = getOrCreate(folder, "PlayerDied", "RemoteEvent") -- { killerFaction? }
local LootSpawned = getOrCreate(folder, "LootSpawned", "RemoteEvent") -- { bagId, position, lootCount, ownerId }
local LootRemoved = getOrCreate(folder, "LootRemoved", "RemoteEvent") -- { bagId }
local OpenFactionMenu = getOrCreate(folder, "OpenFactionMenu", "RemoteEvent") -- 🌟 AJOUT : Ouvre l'UI de faction
local MutantDied = getOrCreate(folder, "MutantDied", "RemoteEvent") -- 🌟 AJOUT MUTANT

-- Client → Server
local RequestLoot = getOrCreate(folder, "RequestLoot", "RemoteEvent") -- { bagId }
local WeaponFire = getOrCreate(folder, "WeaponFire", "RemoteEvent") -- { origin, direction, weaponName }
local WeaponMelee = getOrCreate(folder, "WeaponMelee", "RemoteEvent") -- { weaponName }
local SetFaction = getOrCreate(folder, "SetFaction", "RemoteEvent")
local EquipWeapon = getOrCreate(folder, "EquipWeapon", "RemoteEvent")

return {
	UpdateHealth = UpdateHealth :: RemoteEvent,
	PlayerDied = PlayerDied :: RemoteEvent,
	LootSpawned = LootSpawned :: RemoteEvent,
	LootRemoved = LootRemoved :: RemoteEvent,
	OpenFactionMenu = OpenFactionMenu :: RemoteEvent,
	MutantDied = MutantDied :: RemoteEvent, -- 🌟 FIX : Exportation indispensable pour l'étape 3
	RequestLoot = RequestLoot :: RemoteEvent,
	WeaponFire = WeaponFire :: RemoteEvent,
	WeaponMelee = WeaponMelee :: RemoteEvent,
	SetFaction = SetFaction :: RemoteEvent,
	EquipWeapon = EquipWeapon :: RemoteEvent,
}
