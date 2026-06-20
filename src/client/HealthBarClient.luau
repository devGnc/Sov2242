-- HealthBarClient.luau
-- Affiche la barre de vie + overlay de mort.
-- CORRECTION : reconnexion automatique après chaque respawn via CharacterAdded.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ─── Construction UI (une seule fois, ResetOnSpawn = false) ──────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "CombatHUD"
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = playerGui

-- Conteneur barre de vie (bas gauche)
local hpContainer = Instance.new("Frame")
hpContainer.Name                     = "HPContainer"
hpContainer.Size                     = UDim2.new(0, 280, 0, 38)
hpContainer.Position                 = UDim2.new(0, 24, 1, -62)
hpContainer.BackgroundColor3         = Color3.fromRGB(15, 15, 15)
hpContainer.BackgroundTransparency   = 0.3
hpContainer.BorderSizePixel          = 0
hpContainer.Parent                   = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent       = hpContainer

-- Fond rouge sombre
local hpBg = Instance.new("Frame")
hpBg.Name             = "HPBackground"
hpBg.Size             = UDim2.new(1, -16, 0, 18)
hpBg.Position         = UDim2.new(0, 8, 0.5, -9)
hpBg.BackgroundColor3 = Color3.fromRGB(80, 20, 20)
hpBg.BorderSizePixel  = 0
hpBg.Parent           = hpContainer

local bgCorner = Instance.new("UICorner")
bgCorner.CornerRadius = UDim.new(0, 5)
bgCorner.Parent       = hpBg

-- Barre de vie
local hpBar = Instance.new("Frame")
hpBar.Name             = "HPBar"
hpBar.Size             = UDim2.new(1, 0, 1, 0)
hpBar.BackgroundColor3 = Color3.fromRGB(80, 210, 90)
hpBar.BorderSizePixel  = 0
hpBar.ClipsDescendants = true
hpBar.Parent           = hpBg

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 5)
barCorner.Parent       = hpBar

-- Texte PV
local hpLabel = Instance.new("TextLabel")
hpLabel.Name                   = "HPLabel"
hpLabel.Size                   = UDim2.new(1, 0, 1, 0)
hpLabel.BackgroundTransparency = 1
hpLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
hpLabel.TextStrokeColor3       = Color3.new(0, 0, 0)
hpLabel.TextStrokeTransparency = 0.4
hpLabel.Font                   = Enum.Font.GothamBold
hpLabel.TextSize               = 13
hpLabel.Text                   = "PV : 100 / 100"
hpLabel.ZIndex                 = 2
hpLabel.Parent                 = hpBg

-- Overlay de mort
local deathOverlay = Instance.new("Frame")
deathOverlay.Name                   = "DeathOverlay"
deathOverlay.Size                   = UDim2.new(1, 0, 1, 0)
deathOverlay.BackgroundColor3       = Color3.fromRGB(120, 0, 0)
deathOverlay.BackgroundTransparency = 1
deathOverlay.BorderSizePixel        = 0
deathOverlay.ZIndex                 = 10
deathOverlay.Parent                 = screenGui

local deathLabel = Instance.new("TextLabel")
deathLabel.Name                   = "DeathLabel"
deathLabel.Size                   = UDim2.new(1, 0, 0, 80)
deathLabel.Position               = UDim2.new(0, 0, 0.4, 0)
deathLabel.BackgroundTransparency = 1
deathLabel.TextColor3             = Color3.fromRGB(255, 80, 80)
deathLabel.Font                   = Enum.Font.GothamBold
deathLabel.TextSize               = 48
deathLabel.Text                   = "VOUS ÊTES MORT"
deathLabel.TextStrokeColor3       = Color3.new(0, 0, 0)
deathLabel.TextStrokeTransparency = 0.2
deathLabel.ZIndex                 = 11
deathLabel.Parent                 = deathOverlay

local respawnLabel = Instance.new("TextLabel")
respawnLabel.Name                   = "RespawnLabel"
respawnLabel.Size                   = UDim2.new(1, 0, 0, 40)
respawnLabel.Position               = UDim2.new(0, 0, 0.55, 0)
respawnLabel.BackgroundTransparency = 1
respawnLabel.TextColor3             = Color3.fromRGB(200, 200, 200)
respawnLabel.Font                   = Enum.Font.Gotham
respawnLabel.TextSize               = 22
respawnLabel.Text                   = "Retour au hub en cours…"
respawnLabel.ZIndex                 = 11
respawnLabel.Parent                 = deathOverlay

-- ─── Logique ──────────────────────────────────────────────────────────────────
local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function updateHealthBar(current: number, max: number)
	local ratio = math.clamp(current / math.max(max, 1), 0, 1)

	local color
	if ratio > 0.5 then
		color = Color3.fromRGB(math.floor((1 - ratio) * 2 * 175), 210, 90)
	else
		color = Color3.fromRGB(210, math.floor(ratio * 2 * 190), 20)
	end

	TweenService:Create(hpBar, tweenInfo, {
		Size             = UDim2.new(ratio, 0, 1, 0),
		BackgroundColor3 = color,
	}):Play()

	hpLabel.Text = ("PV : %d / %d"):format(current, max)
end

local function showDeathScreen()
	TweenService:Create(deathOverlay, TweenInfo.new(0.4), {
		BackgroundTransparency = 0.5,
	}):Play()

	task.delay(2.5, function()
		TweenService:Create(deathOverlay, TweenInfo.new(0.6), {
			BackgroundTransparency = 1,
		}):Play()
	end)
end

-- CORRECTION : sync locale depuis le Humanoid, appelée à chaque respawn
local function syncFromHumanoid(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		updateHealthBar(humanoid.Health, humanoid.MaxHealth)
	end
end

-- ─── Connexions RemoteEvents ─────────────────────────────────────────────────
RemoteEvents.UpdateHealth.OnClientEvent:Connect(function(data: { current: number, max: number })
	updateHealthBar(data.current, data.max)
end)

RemoteEvents.PlayerDied.OnClientEvent:Connect(function(_data)
	showDeathScreen()
end)

-- CORRECTION : re-sync à chaque apparition de personnage (respawn inclus)
player.CharacterAdded:Connect(function(character: Model)
	-- Attendre que le Humanoid soit bien chargé avant de lire ses PV
	task.defer(function()
		syncFromHumanoid(character)
	end)
end)

-- Sync initiale si le personnage existe déjà au chargement du script
if player.Character then
	syncFromHumanoid(player.Character)
end
