-- CombatService.luau
-- Cœur du Bloc 1 : écoute les morts de personnages, extrait le loot volatile
-- de session, crée le sac, et déclenche la réapparition au hub de faction.
-- Doit être placé dans : src/server/CombatService.luau → ServerScriptService

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteEvents  = require(ReplicatedStorage.Shared.RemoteEvents)
local LootBagModule = require(ReplicatedStorage.Shared.LootBagModule)

-- ─────────────────────────────────────────────────────────────────────────────
-- Constantes
-- ─────────────────────────────────────────────────────────────────────────────
local MAX_HEALTH    = 100
local RESPAWN_DELAY = 2   -- secondes avant réapparition (pour laisser voir l'écran de mort)

-- ─────────────────────────────────────────────────────────────────────────────
-- Loot volatile de session : ce que le joueur a ramassé DEPUIS SON DERNIER SPAWN
-- (distinct de l'inventaire permanent — cf. Bloc 3)
-- Pour l'instant, simulé en mémoire locale ; le Bloc 3 branchera le DataStore.
-- ─────────────────────────────────────────────────────────────────────────────
local sessionLoot: { [Player]: { [string]: number } } = {}

-- Ajouter un item au loot volatile d'un joueur (appelé par l'IA mutants — Bloc 2)
local CombatService = {}

function CombatService.AddSessionLoot(player: Player, itemName: string, quantity: number)
	if not sessionLoot[player] then
		sessionLoot[player] = {}
	end
	sessionLoot[player][itemName] = (sessionLoot[player][itemName] or 0) + quantity
end

-- Récupérer et vider le loot volatile (appelé à la mort)
local function popSessionLoot(player: Player): { [string]: number }
	local loot = sessionLoot[player] or {}
	sessionLoot[player] = {}
	return loot
end

-- Réinitialiser le loot de session au spawn (nouvelle session propre)
local function resetSessionLoot(player: Player)
	sessionLoot[player] = {}
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Connexion aux PV : écoute Humanoid.HealthChanged pour sync client
-- ─────────────────────────────────────────────────────────────────────────────
local function onHealthChanged(player: Player, humanoid: Humanoid)
	humanoid.HealthChanged:Connect(function(newHealth: number)
		RemoteEvents.UpdateHealth:FireClient(player, {
			current = math.floor(newHealth),
			max     = math.floor(humanoid.MaxHealth),
		})
	end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Mort : sac + réapparition
-- ─────────────────────────────────────────────────────────────────────────────
local function onCharacterDied(player: Player, humanoid: Humanoid)
	-- Notifier le client pour l'écran de mort
	RemoteEvents.PlayerDied:FireClient(player, {
		killerFaction = nil,  -- TODO Bloc 4 : déduire depuis le PvP
	})

	-- Récupérer et vider le loot volatile de session
	local loot = popSessionLoot(player)

	-- Spawner le sac seulement si le joueur avait du loot
	-- (évite les sacs vides qui polluent la zone)
	local hasLoot = false
	for _ in loot do
		hasLoot = true
		break
	end

	if hasLoot then
		-- Légère pause pour que le personnage soit bien "mort" et visible
		task.wait(0.1)
		LootBagModule.Spawn(player, loot)
	end

	-- Délai avant réapparition (temps pour voir l'écran de mort)
	task.delay(RESPAWN_DELAY, function()
		if player.Parent == Players then
			-- Demander au MainServer de respawn via BindableEvent
			-- (MainServer écoute RequestRespawn et appelle spawnPlayer)
			RemoteEvents.RequestRespawn:Fire(player)
		end
	end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Connexion d'un personnage : branche les listeners PV et mort
-- ─────────────────────────────────────────────────────────────────────────────
local function onCharacterAdded(player: Player, character: Model)
	resetSessionLoot(player)

	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		warn(("[CombatService] Humanoid introuvable pour %s"):format(player.Name))
		return
	end

	-- Forcer le MaxHealth à notre constante (évite les valeurs Roblox par défaut)
	humanoid.MaxHealth = MAX_HEALTH
	humanoid.Health    = MAX_HEALTH

	-- Sync immédiate au chargement
	RemoteEvents.UpdateHealth:FireClient(player, {
		current = MAX_HEALTH,
		max     = MAX_HEALTH,
	})

	-- Écoute HealthChanged
	onHealthChanged(player, humanoid)

	-- Écoute la mort une seule fois
	humanoid.Died:Once(function()
		onCharacterDied(player, humanoid)
	end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Init : brancher tous les joueurs présents et futurs
-- ─────────────────────────────────────────────────────────────────────────────
local function initPlayer(player: Player)
	-- Personnage actuel (si déjà spawné)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end

	-- Personnages futurs
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

-- ─────────────────────────────────────────────────────────────────────────────
-- Exposer AddSessionLoot pour les futurs modules (IA Mutants — Bloc 2)
-- ─────────────────────────────────────────────────────────────────────────────
return CombatService
