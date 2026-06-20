-- CombatService.luau
-- Bloc 1 : PV, mort, sac de loot volatile, réapparition au hub.
-- Expose AddSessionLoot() pour l'IA Mutants (Bloc 2).

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

local RemoteEvents  = require(ReplicatedStorage.Shared.RemoteEvents)
local LootBagModule = require(ReplicatedStorage.Shared.LootBagModule)

-- ─── Constantes ───────────────────────────────────────────────────────────────
local MAX_HEALTH    = 100
local RESPAWN_DELAY = 2   -- secondes avant réapparition

-- ─── BindableEvent interne (server-only) ──────────────────────────────────────
-- Créé ici, écouté dans init.server.luau via CombatService.RequestRespawn.
-- Un BindableEvent doit rester dans ServerScriptService/Scripts, jamais dans
-- ReplicatedStorage.
local RequestRespawn = Instance.new("BindableEvent")
RequestRespawn.Name  = "RequestRespawn"

-- ─── Loot volatile de session ─────────────────────────────────────────────────
-- { [Player]: { [itemName]: quantity } }
-- Réinitialisé à chaque spawn, vidé (et transformé en sac) à la mort.
local sessionLoot: { [Player]: { [string]: number } } = {}

local CombatService = {}

-- Exposé pour l'IA Mutants (Bloc 2) et les largages (Bloc 4)
function CombatService.AddSessionLoot(player: Player, itemName: string, quantity: number)
	if not sessionLoot[player] then
		sessionLoot[player] = {}
	end
	sessionLoot[player][itemName] = (sessionLoot[player][itemName] or 0) + quantity
end

-- Exposé pour que LootBagModule puisse créditer le pilleur (Bug 3)
function CombatService.GetSessionLoot(player: Player): { [string]: number }
	return sessionLoot[player] or {}
end

-- BindableEvent que init.server.luau connecte pour déclencher spawnPlayer()
CombatService.RequestRespawn = RequestRespawn

local function popSessionLoot(player: Player): { [string]: number }
	local loot = sessionLoot[player] or {}
	sessionLoot[player] = {}
	return loot
end

local function resetSessionLoot(player: Player)
	sessionLoot[player] = {}
end

-- ─── Sync PV → client ─────────────────────────────────────────────────────────
local function onHealthChanged(player: Player, humanoid: Humanoid)
	humanoid.HealthChanged:Connect(function(newHealth: number)
		RemoteEvents.UpdateHealth:FireClient(player, {
			current = math.floor(newHealth),
			max     = math.floor(humanoid.MaxHealth),
		})
	end)
end

-- ─── Mort ─────────────────────────────────────────────────────────────────────
local function onCharacterDied(player: Player)
	-- Notifier le client (écran de mort)
	RemoteEvents.PlayerDied:FireClient(player, { killerFaction = nil })

	-- Récupérer et vider le loot de session
	local loot = popSessionLoot(player)

	local hasLoot = next(loot) ~= nil
	if hasLoot then
		task.wait(0.1)
		LootBagModule.Spawn(player, loot)
	end

	-- Réapparition différée
	task.delay(RESPAWN_DELAY, function()
		if player.Parent == Players then
			RequestRespawn:Fire(player)
		end
	end)
end

-- ─── Connexion d'un personnage ─────────────────────────────────────────────────
local function onCharacterAdded(player: Player, character: Model)
	resetSessionLoot(player)

	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		warn(("[CombatService] Humanoid introuvable pour %s"):format(player.Name))
		return
	end

	humanoid.MaxHealth = MAX_HEALTH
	humanoid.Health    = MAX_HEALTH

	RemoteEvents.UpdateHealth:FireClient(player, {
		current = MAX_HEALTH,
		max     = MAX_HEALTH,
	})

	onHealthChanged(player, humanoid)

	humanoid.Died:Once(function()
		onCharacterDied(player)
	end)
end

-- ─── Init ─────────────────────────────────────────────────────────────────────
local function initPlayer(player: Player)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
	player.CharacterAdded:Connect(function(character: Model)
		task.spawn(onCharacterAdded, player, character)
	end)
end

Players.PlayerAdded:Connect(initPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(initPlayer, player)
end

Players.PlayerRemoving:Connect(function(player: Player)
	sessionLoot[player] = nil
end)

return CombatService
