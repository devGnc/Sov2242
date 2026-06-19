-- HealthBarClient.luau
-- LocalScript : reçoit les mises à jour de PV depuis CombatService
-- et affiche une barre de vie + un overlay de mort temporaire.
-- Placé dans : src/client/HealthBarClient.luau → StarterPlayerScripts

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local player     = Players.LocalPlayer
local playerGui  = player:WaitForChild("PlayerGui")

-- ─────────────────────────────────────────────────────────────────────────────
-- Construction de l'UI (tout en code, pas de ScreenGui dans l'arborescence)
-- ─────────────────────────────────────────────────────────────────────────────

local screenGui = Instance.new("ScreenGui")
screenGui.Name            = "CombatHUD"
screenGui.ResetOnSpawn    = false
screenGui.IgnoreGuiInset  = true
screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
screenGui.Parent          = playerGui

-- ── Conteneur barre de vie (bas gauche) ─────────────────────────────────────
local hpContainer = Instance.new("Frame")
hpContainer.Name              = "HPContainer"
hpContainer.Size              = UDim2.new(0, 280, 0, 38)
hpContainer.Position          = UDim2.new(0, 24, 1, -62)
hpContainer.BackgroundColor3  = Color3.fromRGB(15, 15, 15)
hpContainer.BackgroundTransparency = 0.3
hpContainer.BorderSizePixel   = 0
hpContainer.Parent            = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent       = hpContainer

-- Barre de fond (rouge sombre)
local hpBg = Instance.new("Frame")
hpBg.Name              = "HPBackground"
hpBg.Size              = UDim2.new(1, -16, 0, 18)
hpBg.Position          = UDim2.new(0, 8, 0.5, -9)
hpBg.BackgroundColor3  = Color3.fromRGB(80, 20, 20)
hpBg.BorderSizePixel   = 0
hpBg.Parent            = hpContainer

local bgCorner = Instance.new("UICorner")
bgCorner.CornerRadius = UDim.new(0, 5)
bgCorner.Parent       = hpBg

-- Barre de vie (verte → rouge selon les PV)
local hpBar = Instance.new("Frame")
hpBar.Name              = "HPBar"
hpBar.Size              = UDim2.new(1, 0, 1, 0)
hpBar.BackgroundColor3  = Color3.fromRGB(80, 210, 90)
hpBar.BorderSizePixel   = 0
hpBar.ClipsDescendants  = true
hpBar.Parent            = hpBg

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 5)
barCorner.Parent       = hpBar

-- Texte PV
local hpLabel = Instance.new("TextLabel")
hpLabel.Name                 = "HPLabel"
hpLabel.Size                 = UDim2.new(1, 0, 1, 0)
hpLabel.BackgroundTransparency = 1
hpLabel.TextColor3           = Color3.fromRGB(255, 255, 255)
hpLabel.TextStrokeColor3     = Color3.new(0, 0, 0)
hpLabel.TextStrokeTransparency = 0.4
hpLabel.Font                 = Enum.Font.GothamBold
hpLabel.TextSize             = 13
hpLabel.Text                 = "PV : 100 / 100"
hpLabel.ZIndex               = 2
hpLabel.Parent               = hpBg

-- ── Overlay d'écran de mort (rouge transparent) ──────────────────────────────
local deathOverlay = Instance.new("Frame")
deathOverlay.Name                 = "DeathOverlay"
deathOverlay.Size                 = UDim2.new(1, 0, 1, 0)
deathOverlay.BackgroundColor3     = Color3.fromRGB(120, 0, 0)
deathOverlay.BackgroundTransparency = 1   -- caché par défaut
deathOverlay.BorderSizePixel      = 0
deathOverlay.ZIndex               = 10
deathOverlay.Parent               = screenGui

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

-- ─────────────────────────────────────────────────────────────────────────────
-- Logique : mise à jour de la barre de vie
-- ─────────────────────────────────────────────────────────────────────────────
local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function updateHealthBar(current: number, max: number)
	local ratio = math.clamp(current / math.max(max, 1), 0, 1)

	-- Couleur : vert (full) → orange (50%) → rouge (10%)
	local color
	if ratio > 0.5 then
		color = Color3.fromRGB(
			math.floor((1 - ratio) * 2 * 175),
			210,
			90
		)
	else
		color = Color3.fromRGB(
			210,
			math.floor(ratio * 2 * 190),
			20
		)
	end

	-- Tween fluide de la largeur
	TweenService:Create(hpBar, tweenInfo, {
		Size             = UDim2.new(ratio, 0, 1, 0),
		BackgroundColor3 = color,
	}):Play()

	hpLabel.Text = ("PV : %d / %d"):format(current, max)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Logique : overlay de mort
-- ─────────────────────────────────────────────────────────────────────────────
local function showDeathScreen()
	-- Fade in
	TweenService:Create(deathOverlay, TweenInfo.new(0.4), {
		BackgroundTransparency = 0.5,
	}):Play()

	-- Fade out après 2.5 secondes (légèrement avant le respawn)
	task.delay(2.5, function()
		TweenService:Create(deathOverlay, TweenInfo.new(0.6), {
			BackgroundTransparency = 1,
		}):Play()
	end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Connexion aux RemoteEvents
-- ─────────────────────────────────────────────────────────────────────────────
RemoteEvents.UpdateHealth.OnClientEvent:Connect(function(data: { current: number, max: number })
	updateHealthBar(data.current, data.max)
end)

RemoteEvents.PlayerDied.OnClientEvent:Connect(function(_data)
	showDeathScreen()
end)

-- Sync initial au chargement (au cas où le personnage existe déjà)
local character = player.Character
if character then
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		updateHealthBar(humanoid.Health, humanoid.MaxHealth)
	end
end
