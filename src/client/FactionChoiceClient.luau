-- FactionChoiceClient.luau
-- Gère l'affichage du menu de sélection de faction à la demande.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FactionChoiceClient = {}

function FactionChoiceClient.Open()
	-- Sécurité : Si l'UI est déjà ouverte, on ne fait rien
	if playerGui:FindFirstChild("FactionChoice") then
		return
	end

	local confirmBtn: TextButton
	local selectedFaction = nil

	-- ─── ScreenGui ───────────────────────────────────────────────────────────
	local gui = Instance.new("ScreenGui")
	gui.Name = "FactionChoice"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- Fond obscurci
	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.new(1, 0, 1, 0)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.55
	backdrop.BorderSizePixel = 0
	backdrop.ZIndex = 30
	backdrop.Parent = gui

	-- Carte centrale
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.new(0, 540, 0, 380)
	card.Position = UDim2.new(0.5, -270, 0.5, -190)
	card.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
	card.BackgroundTransparency = 0.05
	card.BorderSizePixel = 0
	card.ZIndex = 31
	card.Parent = gui
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

	-- En-tête
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 60)
	header.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
	header.BorderSizePixel = 0
	header.ZIndex = 32
	header.Parent = card
	Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)

	local headerFix = Instance.new("Frame")
	headerFix.Size = UDim2.new(1, 0, 0, 10)
	headerFix.Position = UDim2.new(0, 0, 1, -10)
	headerFix.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
	headerFix.BorderSizePixel = 0
	headerFix.ZIndex = 32
	headerFix.Parent = header

	local headerTitle = Instance.new("TextLabel")
	headerTitle.Size = UDim2.new(1, 0, 0, 28)
	headerTitle.Position = UDim2.new(0, 0, 0, 10)
	headerTitle.BackgroundTransparency = 1
	headerTitle.TextColor3 = Color3.fromRGB(160, 160, 160)
	headerTitle.Font = Enum.Font.GothamBold
	headerTitle.TextSize = 11
	headerTitle.Text = "TEST D'APTITUDE — CHOISISSEZ VOTRE VOIE"
	headerTitle.ZIndex = 35
	headerTitle.Parent = header

	local headerSub = Instance.new("TextLabel")
	headerSub.Size = UDim2.new(1, 0, 0, 18)
	headerSub.Position = UDim2.new(0, 0, 0, 36)
	headerSub.BackgroundTransparency = 1
	headerSub.TextColor3 = Color3.fromRGB(80, 80, 80)
	headerSub.Font = Enum.Font.Gotham
	headerSub.TextSize = 11
	headerSub.Text = "Ce choix est définitif et ne peut pas être annulé."
	headerSub.ZIndex = 35
	headerSub.Parent = header

	-- Séparateur vertical
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Size = UDim2.new(0, 1, 0, 230)
	divider.Position = UDim2.new(0.5, 0, 0, 68)
	divider.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	divider.BorderSizePixel = 0
	divider.ZIndex = 32
	divider.Parent = card

	-- Pied de carte
	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.Size = UDim2.new(1, 0, 0, 52)
	footer.Position = UDim2.new(0, 0, 0, 300)
	footer.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
	footer.BorderSizePixel = 0
	footer.ZIndex = 32
	footer.Parent = card

	local footerFix = Instance.new("Frame")
	footerFix.Size = UDim2.new(1, 0, 0, 10)
	footerFix.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
	footerFix.BorderSizePixel = 0
	footerFix.ZIndex = 32
	footerFix.Parent = footer

	local warningLabel = Instance.new("TextLabel")
	warningLabel.Size = UDim2.new(0.6, 0, 1, 0)
	warningLabel.Position = UDim2.new(0, 16, 0, 0)
	warningLabel.BackgroundTransparency = 1
	warningLabel.TextColor3 = Color3.fromRGB(150, 50, 50)
	warningLabel.Font = Enum.Font.Gotham
	warningLabel.TextSize = 10
	warningLabel.TextXAlignment = Enum.TextXAlignment.Left
	warningLabel.Text = "⚠  Choix irréversible en V1"
	warningLabel.ZIndex = 35
	warningLabel.Parent = footer

	confirmBtn = Instance.new("TextButton")
	confirmBtn.Name = "ConfirmBtn"
	confirmBtn.Size = UDim2.new(0, 180, 0, 32)
	confirmBtn.Position = UDim2.new(1, -196, 0.5, -16)
	confirmBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	confirmBtn.BackgroundTransparency = 0.5
	confirmBtn.BorderSizePixel = 0
	confirmBtn.Font = Enum.Font.GothamBold
	confirmBtn.TextSize = 12
	confirmBtn.TextColor3 = Color3.fromRGB(100, 100, 100)
	confirmBtn.Text = "Choisissez une faction"
	confirmBtn.AutoButtonColor = false
	confirmBtn.ZIndex = 35
	confirmBtn.Parent = footer
	Instance.new("UICorner", confirmBtn).CornerRadius = UDim.new(0, 6)

	-- ─── Fabrique de carte faction ────────────────────────────────────────────
	local function makeCard(
		faction: string,
		xPos: number,
		primaryColor: Color3,
		lightColor: Color3,
		icon: string,
		name: string,
		hub: string,
		desc: string,
		currency: string
	)
		local btn = Instance.new("TextButton")
		btn.Name = faction .. "Card"
		btn.Size = UDim2.new(0, 258, 0, 230)
		btn.Position = UDim2.new(0, xPos, 0, 68)
		btn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		btn.BackgroundTransparency = 0.95 -- Visible pour l'interaction
		btn.BorderSizePixel = 0
		btn.Text = ""
		btn.ZIndex = 33
		btn.Parent = card

		local iconLabel = Instance.new("TextLabel")
		iconLabel.Size = UDim2.new(1, -20, 0, 36)
		iconLabel.Position = UDim2.new(0, 20, 0, 20)
		iconLabel.BackgroundTransparency = 1
		iconLabel.TextColor3 = primaryColor
		iconLabel.Font = Enum.Font.Gotham
		iconLabel.TextSize = 28
		iconLabel.TextXAlignment = Enum.TextXAlignment.Left
		iconLabel.Text = icon
		iconLabel.ZIndex = 35
		iconLabel.Parent = btn

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -20, 0, 22)
		nameLabel.Position = UDim2.new(0, 20, 0, 62)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = lightColor
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 15
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Text = name
		nameLabel.ZIndex = 35
		nameLabel.Parent = btn

		local hubLabel = Instance.new("TextLabel")
		hubLabel.Size = UDim2.new(1, -20, 0, 14)
		hubLabel.Position = UDim2.new(0, 20, 0, 86)
		hubLabel.BackgroundTransparency = 1
		hubLabel.TextColor3 = Color3.fromRGB(110, 110, 110)
		hubLabel.Font = Enum.Font.Gotham
		hubLabel.TextSize = 10
		hubLabel.TextXAlignment = Enum.TextXAlignment.Left
		hubLabel.Text = "HUB : " .. hub
		hubLabel.ZIndex = 35
		hubLabel.Parent = btn

		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(1, -28, 0, 72)
		descLabel.Position = UDim2.new(0, 20, 0, 108)
		descLabel.BackgroundTransparency = 1
		descLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextSize = 11
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextWrapped = true
		descLabel.Text = desc
		descLabel.ZIndex = 35
		descLabel.Parent = btn

		local currencyBadge = Instance.new("Frame")
		currencyBadge.Size = UDim2.new(0, 0, 0, 22)
		currencyBadge.Position = UDim2.new(0, 20, 0, 190)
		currencyBadge.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		currencyBadge.BorderSizePixel = 0
		currencyBadge.AutomaticSize = Enum.AutomaticSize.X
		currencyBadge.ZIndex = 34
		currencyBadge.Parent = btn
		Instance.new("UICorner", currencyBadge).CornerRadius = UDim.new(0, 4)

		local currLabel = Instance.new("TextLabel")
		currLabel.Size = UDim2.new(1, 0, 1, 0)
		currLabel.BackgroundTransparency = 1
		currLabel.TextColor3 = primaryColor
		currLabel.Font = Enum.Font.Gotham
		currLabel.TextSize = 10
		currLabel.Text = currency
		currLabel.ZIndex = 35
		currLabel.Parent = currencyBadge

		btn.MouseButton1Click:Connect(function()
			selectedFaction = faction
			TweenService:Create(btn, TweenInfo.new(0.15), {
				BackgroundTransparency = 0.7,
				BackgroundColor3 = primaryColor,
			}):Play()

			local otherName = if faction == "Soldier" then "OutcastCard" else "SoldierCard"
			local other = card:FindFirstChild(otherName)
			if other then
				TweenService:Create(
					other,
					TweenInfo.new(0.15),
					{ BackgroundTransparency = 0.95, BackgroundColor3 = Color3.fromRGB(20, 20, 20) }
				):Play()
			end

			confirmBtn.BackgroundTransparency = 0
			confirmBtn.AutoButtonColor = true
			confirmBtn.Text = "Rejoindre — " .. name
			confirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			confirmBtn.BackgroundColor3 = if faction == "Soldier"
				then Color3.fromRGB(99, 153, 34)
				else Color3.fromRGB(239, 159, 39)
		end)

		return btn
	end

	-- Génération des cartes avec les ZIndex corrigés
	makeCard(
		"Soldier",
		0,
		Color3.fromRGB(99, 153, 34),
		Color3.fromRGB(151, 196, 89),
		"⚔",
		"Combattant",
		"LA BASE",
		"Escouades lourdement armées. Sécurisez les largages orbitaux et purger les mutants.",
		"Crédits C"
	)

	makeCard(
		"Outcast",
		270,
		Color3.fromRGB(239, 159, 39),
		Color3.fromRGB(250, 199, 117),
		"◈",
		"Fuyard",
		"LE NID",
		"Infiltration, pièges, piratage. Volez le butin de la Base et disparaissez dans l'ombre.",
		"Pièces de Récup'"
	)

	-- Actions Finales
	confirmBtn.MouseButton1Click:Connect(function()
		if not selectedFaction then
			return
		end
		TweenService:Create(backdrop, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		TweenService
			:Create(
				card,
				TweenInfo.new(0.3),
				{ Position = UDim2.new(0.5, -270, 0.5, -160), BackgroundTransparency = 1 }
			)
			:Play()
		RemoteEvents.SetFaction:FireServer({ faction = selectedFaction })
		task.delay(0.35, function()
			gui:Destroy()
		end)
	end)
end

return FactionChoiceClient
