-- HealthBarClient.luau
-- HUD complet Bloc 1 :
--   • Barre de vie (couleur dynamique, tween fluide)
--   • Badge faction + devise (thème Combattant/Fuyard)
--   • Écran de mort amélioré (loot lâché, barre de respawn)
--   • Notification sac de loot (panneau droit, timer)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ─── Couleurs par faction ─────────────────────────────────────────────────────
local THEME = {
	Soldier = {
		primary   = Color3.fromRGB(99,  153, 34),
		light     = Color3.fromRGB(151, 196, 89),
		label     = "ORDRE DES COMBATTANTS",
		hub       = "Retour à La Base…",
		currency  = "Crédits C",
	},
	Outcast = {
		primary   = Color3.fromRGB(239, 159, 39),
		light     = Color3.fromRGB(250, 199, 117),
		label     = "L'EXODE — FUYARDS",
		hub       = "Retour au Nid…",
		currency  = "Pièces de Récup'",
	},
}

local function getTheme(): typeof(THEME.Soldier)
	local faction = player:GetAttribute("Faction") or "None"
	return if faction == "Outcast" then THEME.Outcast else THEME.Soldier
end

-- ─── ScreenGui principale ─────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name           = "CombatHUD"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent         = playerGui

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. BARRE DE VIE (bas gauche)
-- ═══════════════════════════════════════════════════════════════════════════════
local hpContainer = Instance.new("Frame")
hpContainer.Name                   = "HPContainer"
hpContainer.Size                   = UDim2.new(0, 240, 0, 44)
hpContainer.Position               = UDim2.new(0, 20, 1, -68)
hpContainer.BackgroundColor3       = Color3.fromRGB(10, 10, 10)
hpContainer.BackgroundTransparency = 0.35
hpContainer.BorderSizePixel        = 0
hpContainer.Parent                 = gui
Instance.new("UICorner", hpContainer).CornerRadius = UDim.new(0, 8)

local hpBg = Instance.new("Frame")
hpBg.Name             = "HPBg"
hpBg.Size             = UDim2.new(1, -16, 0, 14)
hpBg.Position         = UDim2.new(0, 8, 0, 10)
hpBg.BackgroundColor3 = Color3.fromRGB(60, 15, 15)
hpBg.BorderSizePixel  = 0
hpBg.Parent           = hpContainer
Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 4)

local hpBar = Instance.new("Frame")
hpBar.Name             = "HPBar"
hpBar.Size             = UDim2.new(1, 0, 1, 0)
hpBar.BackgroundColor3 = Color3.fromRGB(99, 153, 34)
hpBar.BorderSizePixel  = 0
hpBar.ClipsDescendants = true
hpBar.Parent           = hpBg
Instance.new("UICorner", hpBar).CornerRadius = UDim.new(0, 4)

local hpLabel = Instance.new("TextLabel")
hpLabel.Name                   = "HPLabel"
hpLabel.Size                   = UDim2.new(1, -16, 0, 16)
hpLabel.Position               = UDim2.new(0, 8, 0, 25)
hpLabel.BackgroundTransparency = 1
hpLabel.TextColor3             = Color3.fromRGB(200, 200, 200)
hpLabel.TextXAlignment         = Enum.TextXAlignment.Left
hpLabel.Font                   = Enum.Font.GothamBold
hpLabel.TextSize               = 11
hpLabel.Text                   = "PV : 100 / 100"
hpLabel.Parent                 = hpContainer

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. BADGE FACTION + DEVISE (haut centre)
-- ═══════════════════════════════════════════════════════════════════════════════
local factionFrame = Instance.new("Frame")
factionFrame.Name                   = "FactionHUD"
factionFrame.Size                   = UDim2.new(0, 260, 0, 44)
factionFrame.Position               = UDim2.new(0.5, -130, 0, 12)
factionFrame.BackgroundTransparency = 1
factionFrame.BorderSizePixel        = 0
factionFrame.Parent                 = gui

local factionBadge = Instance.new("Frame")
factionBadge.Name                   = "Badge"
factionBadge.Size                   = UDim2.new(1, 0, 0, 24)
factionBadge.BackgroundColor3       = Color3.fromRGB(10, 10, 10)
factionBadge.BackgroundTransparency = 0.4
factionBadge.BorderSizePixel        = 0
factionBadge.Parent                 = factionFrame
Instance.new("UICorner", factionBadge).CornerRadius = UDim.new(0, 5)

local factionDot = Instance.new("Frame")
factionDot.Name             = "Dot"
factionDot.Size             = UDim2.new(0, 6, 0, 6)
factionDot.Position         = UDim2.new(0, 10, 0.5, -3)
factionDot.BackgroundColor3 = Color3.fromRGB(99, 153, 34)
factionDot.BorderSizePixel  = 0
factionDot.Parent           = factionBadge
Instance.new("UICorner", factionDot).CornerRadius = UDim.new(1, 0)

local factionLabel = Instance.new("TextLabel")
factionLabel.Name                   = "Label"
factionLabel.Size                   = UDim2.new(1, -24, 1, 0)
factionLabel.Position               = UDim2.new(0, 24, 0, 0)
factionLabel.BackgroundTransparency = 1
factionLabel.TextColor3             = Color3.fromRGB(151, 196, 89)
factionLabel.Font                   = Enum.Font.GothamBold
factionLabel.TextSize               = 10
factionLabel.LetterSpacing          = 2
factionLabel.Text                   = "ORDRE DES COMBATTANTS"
factionLabel.Parent                 = factionBadge

local currencyLabel = Instance.new("TextLabel")
currencyLabel.Name                   = "Currency"
currencyLabel.Size                   = UDim2.new(1, 0, 0, 16)
currencyLabel.Position               = UDim2.new(0, 0, 0, 27)
currencyLabel.BackgroundTransparency = 1
currencyLabel.TextColor3             = Color3.fromRGB(140, 140, 140)
currencyLabel.Font                   = Enum.Font.Gotham
currencyLabel.TextSize               = 10
currencyLabel.Text                   = "Crédits C : 0"
currencyLabel.Parent                 = factionFrame

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. NOTIFICATION SAC DE LOOT (haut droite)
-- ═══════════════════════════════════════════════════════════════════════════════
local lootPanel = Instance.new("Frame")
lootPanel.Name                   = "LootNotif"
lootPanel.Size                   = UDim2.new(0, 200, 0, 70)
lootPanel.Position               = UDim2.new(1, 220, 0, 12)  -- hors écran par défaut
lootPanel.BackgroundColor3       = Color3.fromRGB(10, 10, 10)
lootPanel.BackgroundTransparency = 0.3
lootPanel.BorderSizePixel        = 0
lootPanel.Parent                 = gui
Instance.new("UICorner", lootPanel).CornerRadius = UDim.new(0, 7)

-- Barre colorée gauche
local lootAccent = Instance.new("Frame")
lootAccent.Name             = "Accent"
lootAccent.Size             = UDim2.new(0, 3, 1, 0)
lootAccent.BackgroundColor3 = Color3.fromRGB(99, 153, 34)
lootAccent.BorderSizePixel  = 0
lootAccent.Parent           = lootPanel
Instance.new("UICorner", lootAccent).CornerRadius = UDim.new(0, 7)

local lootTitle = Instance.new("TextLabel")
lootTitle.Name                   = "Title"
lootTitle.Size                   = UDim2.new(1, -14, 0, 14)
lootTitle.Position               = UDim2.new(0, 11, 0, 8)
lootTitle.BackgroundTransparency = 1
lootTitle.TextColor3             = Color3.fromRGB(151, 196, 89)
lootTitle.TextXAlignment         = Enum.TextXAlignment.Left
lootTitle.Font                   = Enum.Font.GothamBold
lootTitle.TextSize               = 10
lootTitle.LetterSpacing          = 1
lootTitle.Text                   = "SAC DE LOOT DÉTECTÉ"
lootTitle.Parent                 = lootPanel

local lootOwner = Instance.new("TextLabel")
lootOwner.Name                   = "Owner"
lootOwner.Size                   = UDim2.new(1, -14, 0, 16)
lootOwner.Position               = UDim2.new(0, 11, 0, 23)
lootOwner.BackgroundTransparency = 1
lootOwner.TextColor3             = Color3.fromRGB(220, 220, 220)
lootOwner.TextXAlignment         = Enum.TextXAlignment.Left
lootOwner.Font                   = Enum.Font.Gotham
lootOwner.TextSize               = 12
lootOwner.Text                   = "Sac de —"
lootOwner.Parent                 = lootPanel

local lootCount = Instance.new("TextLabel")
lootCount.Name                   = "Count"
lootCount.Size                   = UDim2.new(1, -14, 0, 14)
lootCount.Position               = UDim2.new(0, 11, 0, 40)
lootCount.BackgroundTransparency = 1
lootCount.TextColor3             = Color3.fromRGB(120, 120, 120)
lootCount.TextXAlignment         = Enum.TextXAlignment.Left
lootCount.Font                   = Enum.Font.Gotham
lootCount.TextSize               = 10
lootCount.Text                   = ""
lootCount.Parent                 = lootPanel

-- Timer bar (bas du panel)
local lootTimerBg = Instance.new("Frame")
lootTimerBg.Name             = "TimerBg"
lootTimerBg.Size             = UDim2.new(1, 0, 0, 2)
lootTimerBg.Position         = UDim2.new(0, 0, 1, -2)
lootTimerBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
lootTimerBg.BorderSizePixel  = 0
lootTimerBg.Parent           = lootPanel

local lootTimerFill = Instance.new("Frame")
lootTimerFill.Name             = "TimerFill"
lootTimerFill.Size             = UDim2.new(1, 0, 1, 0)
lootTimerFill.BackgroundColor3 = Color3.fromRGB(99, 153, 34)
lootTimerFill.BorderSizePixel  = 0
lootTimerFill.Parent           = lootTimerBg

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. ÉCRAN DE MORT (plein écran)
-- ═══════════════════════════════════════════════════════════════════════════════
local deathOverlay = Instance.new("Frame")
deathOverlay.Name                   = "DeathOverlay"
deathOverlay.Size                   = UDim2.new(1, 0, 1, 0)
deathOverlay.BackgroundColor3       = Color3.fromRGB(80, 0, 0)
deathOverlay.BackgroundTransparency = 1
deathOverlay.BorderSizePixel        = 0
deathOverlay.ZIndex                 = 20
deathOverlay.Parent                 = gui

local deathTitle = Instance.new("TextLabel")
deathTitle.Name                   = "Title"
deathTitle.Size                   = UDim2.new(1, 0, 0, 70)
deathTitle.Position               = UDim2.new(0, 0, 0.38, 0)
deathTitle.BackgroundTransparency = 1
deathTitle.TextColor3             = Color3.fromRGB(226, 75, 74)
deathTitle.Font                   = Enum.Font.GothamBold
deathTitle.TextSize               = 46
deathTitle.Text                   = "VOUS ÊTES MORT"
deathTitle.TextStrokeColor3       = Color3.new(0, 0, 0)
deathTitle.TextStrokeTransparency = 0.3
deathTitle.ZIndex                 = 21
deathTitle.Parent                 = deathOverlay

local deathSub = Instance.new("TextLabel")
deathSub.Name                   = "Sub"
deathSub.Size                   = UDim2.new(1, 0, 0, 30)
deathSub.Position               = UDim2.new(0, 0, 0.53, 0)
deathSub.BackgroundTransparency = 1
deathSub.TextColor3             = Color3.fromRGB(180, 180, 180)
deathSub.Font                   = Enum.Font.Gotham
deathSub.TextSize               = 18
deathSub.Text                   = "Retour au hub en cours…"
deathSub.ZIndex                 = 21
deathSub.Parent                 = deathOverlay

-- Info loot perdu
local deathLootFrame = Instance.new("Frame")
deathLootFrame.Name                   = "LootLost"
deathLootFrame.Size                   = UDim2.new(0, 320, 0, 32)
deathLootFrame.Position               = UDim2.new(0.5, -160, 0.61, 0)
deathLootFrame.BackgroundColor3       = Color3.fromRGB(40, 8, 8)
deathLootFrame.BackgroundTransparency = 0.4
deathLootFrame.BorderSizePixel        = 0
deathLootFrame.ZIndex                 = 21
deathLootFrame.Parent                 = deathOverlay
Instance.new("UICorner", deathLootFrame).CornerRadius = UDim.new(0, 6)

local deathLootLabel = Instance.new("TextLabel")
deathLootLabel.Name                   = "LootLabel"
deathLootLabel.Size                   = UDim2.new(1, 0, 1, 0)
deathLootLabel.BackgroundTransparency = 1
deathLootLabel.TextColor3             = Color3.fromRGB(200, 80, 80)
deathLootLabel.Font                   = Enum.Font.Gotham
deathLootLabel.TextSize               = 12
deathLootLabel.Text                   = "Sac lâché — items perdus si non pillés sous 5 min"
deathLootLabel.ZIndex                 = 22
deathLootLabel.Parent                 = deathLootFrame

-- Barre de respawn (bas d'écran)
local respawnBarBg = Instance.new("Frame")
respawnBarBg.Name             = "RespawnBarBg"
respawnBarBg.Size             = UDim2.new(1, 0, 0, 3)
respawnBarBg.Position         = UDim2.new(0, 0, 1, -3)
respawnBarBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
respawnBarBg.BorderSizePixel  = 0
respawnBarBg.ZIndex           = 21
respawnBarBg.Parent           = deathOverlay

local respawnBarFill = Instance.new("Frame")
respawnBarFill.Name             = "RespawnFill"
respawnBarFill.Size             = UDim2.new(0, 0, 1, 0)
respawnBarFill.BackgroundColor3 = Color3.fromRGB(226, 75, 74)
respawnBarFill.BorderSizePixel  = 0
respawnBarFill.ZIndex           = 22
respawnBarFill.Parent           = respawnBarBg

-- ─────────────────────────────────────────────────────────────────────────────
-- LOGIQUE
-- ─────────────────────────────────────────────────────────────────────────────
local RESPAWN_DELAY = 2
local tweenFast = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local lootHideThread = nil

-- Applique le thème faction à tous les éléments colorés
local function applyTheme()
	local t = getTheme()
	factionDot.BackgroundColor3  = t.primary
	factionLabel.TextColor3      = t.light
	factionLabel.Text            = t.label
	lootAccent.BackgroundColor3  = t.primary
	lootTitle.TextColor3         = t.light
	lootTimerFill.BackgroundColor3 = t.primary
	deathSub.Text                = t.hub
end

-- Mise à jour de la devise (appelée depuis FactionChoiceClient après achat)
local function updateCurrency(amount: number)
	local t = getTheme()
	currencyLabel.Text = ("%s : %d"):format(t.currency, amount)
end

-- Barre de vie
local function updateHealthBar(current: number, max: number)
	local ratio = math.clamp(current / math.max(max, 1), 0, 1)
	local color
	if ratio > 0.5 then
		color = Color3.fromRGB(math.floor((1 - ratio) * 2 * 155), 153, 34)
	else
		color = Color3.fromRGB(210, math.floor(ratio * 2 * 180), 20)
	end
	TweenService:Create(hpBar, tweenFast, {
		Size             = UDim2.new(ratio, 0, 1, 0),
		BackgroundColor3 = color,
	}):Play()
	hpLabel.Text = ("PV : %d / %d"):format(current, max)
end

-- Écran de mort
local function showDeathScreen(lootDescription: string?)
	applyTheme()
	if lootDescription then
		deathLootLabel.Text = lootDescription
		deathLootFrame.Visible = true
	else
		deathLootFrame.Visible = false
	end

	TweenService:Create(deathOverlay, TweenInfo.new(0.35), {
		BackgroundTransparency = 0.55,
	}):Play()

	-- Barre de respawn
	respawnBarFill.Size = UDim2.new(0, 0, 1, 0)
	TweenService:Create(respawnBarFill, TweenInfo.new(RESPAWN_DELAY, Enum.EasingStyle.Linear), {
		Size = UDim2.new(1, 0, 1, 0),
	}):Play()

	task.delay(RESPAWN_DELAY + 0.3, function()
		TweenService:Create(deathOverlay, TweenInfo.new(0.5), {
			BackgroundTransparency = 1,
		}):Play()
	end)
end

-- Notification sac de loot
local lootSlideIn  = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local lootSlideOut = TweenInfo.new(0.2,  Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local LOOT_VISIBLE_POS = UDim2.new(1, -216, 0, 12)
local LOOT_HIDDEN_POS  = UDim2.new(1,  220, 0, 12)

local function showLootNotification(data: { bagId: string, position: Vector3, lootCount: number, ownerId: number })
	applyTheme()

	-- Nom du propriétaire
	local owner = game:GetService("Players"):GetPlayerByUserId(data.ownerId)
	lootOwner.Text = "Sac de " .. (owner and owner.DisplayName or "joueur inconnu")
	lootCount.Text = ("%d item%s"):format(data.lootCount, if data.lootCount > 1 then "s" else "")

	-- Timer visuel (5 minutes → barre qui se vide)
	lootTimerFill.Size = UDim2.new(1, 0, 1, 0)
	TweenService:Create(lootTimerFill, TweenInfo.new(300, Enum.EasingStyle.Linear), {
		Size = UDim2.new(0, 0, 1, 0),
	}):Play()

	-- Slide in
	lootPanel.Position = LOOT_HIDDEN_POS
	TweenService:Create(lootPanel, lootSlideIn, { Position = LOOT_VISIBLE_POS }):Play()

	-- Auto-hide après 6 secondes (reste discret)
	if lootHideThread then task.cancel(lootHideThread) end
	lootHideThread = task.delay(6, function()
		TweenService:Create(lootPanel, lootSlideOut, { Position = LOOT_HIDDEN_POS }):Play()
	end)
end

local function hideLootNotification()
	TweenService:Create(lootPanel, lootSlideOut, { Position = LOOT_HIDDEN_POS }):Play()
end

local function syncFromHumanoid(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		updateHealthBar(humanoid.Health, humanoid.MaxHealth)
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- CONNEXIONS
-- ─────────────────────────────────────────────────────────────────────────────
RemoteEvents.UpdateHealth.OnClientEvent:Connect(function(data: { current: number, max: number })
	updateHealthBar(data.current, data.max)
end)

RemoteEvents.PlayerDied.OnClientEvent:Connect(function(data)
	local lootDesc = nil
	if data and data.lootDescription then
		lootDesc = data.lootDescription
	end
	showDeathScreen(lootDesc)
end)

RemoteEvents.LootSpawned.OnClientEvent:Connect(function(data)
	showLootNotification(data)
end)

RemoteEvents.LootRemoved.OnClientEvent:Connect(function(_data)
	hideLootNotification()
end)

-- Mise à jour devise via attribut
player:GetAttributeChangedSignal("CreditsC"):Connect(function()
	updateCurrency(player:GetAttribute("CreditsC") or 0)
end)
player:GetAttributeChangedSignal("PiecesP"):Connect(function()
	updateCurrency(player:GetAttribute("PiecesP") or 0)
end)
player:GetAttributeChangedSignal("Faction"):Connect(function()
	applyTheme()
end)

player.CharacterAdded:Connect(function(character: Model)
	task.defer(function() syncFromHumanoid(character) end)
end)

if player.Character then
	syncFromHumanoid(player.Character)
end

applyTheme()
