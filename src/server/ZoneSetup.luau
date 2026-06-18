local Workspace = game:GetService("Workspace")

local ZoneSetup = {}

-- Plan de calage des zones : volontairement très espacées pour qu'elles ne
-- se chevauchent jamais, même une fois que les vraies maps seront construites
-- par-dessus ces plateformes. Ajuste les tailles/positions ici quand tu veux,
-- le script ne fait que poser le décor, jamais le détruire si tu construis déjà dessus.
local ZONES = {
	{
		Name = "Zone_Base",
		DisplayName = "LA BASE (Hub Combattants)",
		Position = Vector3.new(0, 0, 0),
		Size = Vector3.new(200, 1, 200),
		Color = Color3.fromRGB(80, 145, 255),
	},
	{
		Name = "Zone_Nid",
		DisplayName = "LE NID (Hub Fuyards)",
		Position = Vector3.new(3000, 0, 0),
		Size = Vector3.new(150, 1, 150),
		Color = Color3.fromRGB(255, 170, 70),
	},
	{
		Name = "Zone_TerreDesolee",
		DisplayName = "TERRE DESOLEE (Map PvPvE)",
		Position = Vector3.new(6000, 0, 0),
		Size = Vector3.new(600, 1, 600),
		Color = Color3.fromRGB(150, 90, 60),
	},
	{
		Name = "Zone_Test",
		DisplayName = "ZONE DE TEST",
		Position = Vector3.new(9000, 0, 0),
		Size = Vector3.new(150, 1, 150),
		Color = Color3.fromRGB(255, 255, 120),
	},
}

local function ensureFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function ensureGround(folder: Folder, zoneData): BasePart
	-- Si le sol existe déjà (donc si tu as commencé à construire dessus),
	-- on ne touche plus à sa position ni à sa taille.
	local existing = folder:FindFirstChild("Ground")
	if existing and existing:IsA("BasePart") then
		return existing
	end
	if existing then
		existing:Destroy()
	end

	local ground = Instance.new("Part")
	ground.Name = "Ground"
	ground.Size = zoneData.Size
	ground.CFrame = CFrame.new(zoneData.Position)
	ground.Anchored = true
	ground.Color = zoneData.Color
	ground.Material = Enum.Material.SmoothPlastic
	ground.Parent = folder

	return ground
end

local function ensureLabel(ground: BasePart, text: string)
	local existing = ground:FindFirstChild("ZoneLabel")
	if existing then
		existing:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Adornee = ground
	billboard.Size = UDim2.new(0, 400, 0, 100)
	billboard.StudsOffset = Vector3.new(0, 40, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = ground

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.SourceSansBold
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard
end

local function ensureSpawnPoint(folder: Folder, zoneData): SpawnLocation
	-- Le point de TP propre à la zone. Une fois créé, sa position n'est plus
	-- jamais réécrite, donc tu peux le déplacer à la main dans Studio sans
	-- craindre qu'il revienne à sa position d'origine.
	local existing = folder:FindFirstChild("Spawn")
	if existing and existing:IsA("SpawnLocation") then
		return existing
	end
	if existing then
		existing:Destroy()
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(zoneData.Position + Vector3.new(0, 6, 0))
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.CanCollide = true
	spawn.Transparency = 0.3
	spawn.Color = zoneData.Color
	spawn.Parent = folder

	return spawn
end

-- Pratique pour positionner d'autres objets relatifs à une zone (PNJ, téléporteurs...).
function ZoneSetup.GetZonePosition(zoneName: string): Vector3?
	for _, zoneData in ZONES do
		if zoneData.Name == zoneName then
			return zoneData.Position
		end
	end
	return nil
end

-- Retourne le SpawnLocation propre à une zone, à utiliser avec player.RespawnLocation.
function ZoneSetup.GetSpawnPoint(zoneName: string): SpawnLocation?
	local zonesRoot = Workspace:FindFirstChild("Zones")
	if not zonesRoot then
		return nil
	end

	local folder = zonesRoot:FindFirstChild(zoneName)
	if not folder then
		return nil
	end

	local spawn = folder:FindFirstChild("Spawn")
	if spawn and spawn:IsA("SpawnLocation") then
		return spawn
	end

	return nil
end

-- Retourne le dossier d'une zone (Workspace.Zones.<ZoneName>), pour y parenter
-- d'autres objets propres à cette zone (PNJ, téléporteurs, décor...).
function ZoneSetup.GetZoneFolder(zoneName: string): Folder?
	local zonesRoot = Workspace:FindFirstChild("Zones")
	if not zonesRoot then
		return nil
	end
	return zonesRoot:FindFirstChild(zoneName)
end

function ZoneSetup.Run(activeZones: { [string]: boolean }?)
	local function shouldCreateZone(zoneName: string): boolean
		if not activeZones then
			return true
		end

		return activeZones[zoneName] == true
	end

	local zonesRoot = Workspace:FindFirstChild("Zones")
	if not zonesRoot then
		zonesRoot = Instance.new("Folder")
		zonesRoot.Name = "Zones"
		zonesRoot.Parent = Workspace
	end

	for _, zoneData in ZONES do
		if not shouldCreateZone(zoneData.Name) then
			continue
		end

		local folder = ensureFolder(zonesRoot, zoneData.Name)
		local ground = ensureGround(folder, zoneData)
		ensureLabel(ground, zoneData.DisplayName)
		ensureSpawnPoint(folder, zoneData)
	end
end

return ZoneSetup
