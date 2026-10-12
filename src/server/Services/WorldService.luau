--!strict
-- Constrói o mapa proceduralmente (não precisa de .rbxl): esteira central,
-- 8 bases de jogadores, ponto de spawn e placar global.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

export type Plot = {
	Index: number,
	Model: Model,
	Floor: BasePart,
	SlotPads: { BasePart },
	CollectPad: BasePart,
	LockButton: BasePart,
	Barrier: BasePart,
	SignLabel: TextLabel,
	Spawn: CFrame,
	Owner: Player?,
}

local WorldService = {}

local PLOT_SIZE = 60
local PLOT_Z = 75
local PLOT_XS = { -135, -45, 45, 135 }
local TOTAL_SLOTS = Config.BaseSlots + Config.ExtraSlotsFromPass

local plots: { Plot } = {}
local plotByPlayer: { [Player]: Plot } = {}

WorldService.Map = nil :: Folder?
WorldService.ConveyorStart = Vector3.new(-Config.Conveyor.Length / 2, 4, 0)
WorldService.ConveyorEnd = Vector3.new(Config.Conveyor.Length / 2, 4, 0)
WorldService.LeaderboardFrame = nil :: ScrollingFrame?

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function billboard(parent: Instance, text: string, size: UDim2, offset: Vector3): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffset = offset
	gui.AlwaysOnTop = false
	gui.MaxDistance = 150
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
	return label
end

local function buildPlot(map: Folder, index: number, x: number, side: number): Plot
	local model = Instance.new("Model")
	model.Name = "Plot" .. index

	-- side = 1 → base ao norte (z+), frente voltada para a esteira (z-)
	local center = Vector3.new(x, 0, PLOT_Z * side)
	local toFront = Vector3.new(0, 0, -side)
	local hue = (index - 1) / 8

	local floor = part({
		Name = "Floor",
		Size = Vector3.new(PLOT_SIZE, 1, PLOT_SIZE),
		Position = center + Vector3.new(0, 0.5, 0),
		Color = Color3.fromHSV(hue, 0.35, 0.85),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})

	-- Muros laterais e de trás (frente aberta com barreira de laser)
	local wallColor = Color3.fromHSV(hue, 0.5, 0.6)
	local back = center - toFront * (PLOT_SIZE / 2)
	part({ Name = "WallBack", Size = Vector3.new(PLOT_SIZE, 8, 1), Position = back + Vector3.new(0, 5, 0), Color = wallColor, Parent = model })
	for _, dx in { -1, 1 } do
		part({
			Name = "WallSide",
			Size = Vector3.new(1, 8, PLOT_SIZE),
			Position = center + Vector3.new(dx * PLOT_SIZE / 2, 5, 0),
			Color = wallColor,
			Parent = model,
		})
	end
	local front = center + toFront * (PLOT_SIZE / 2)
	for _, dx in { -1, 1 } do
		part({
			Name = "WallFront",
			Size = Vector3.new(20, 8, 1),
			Position = front + Vector3.new(dx * 20, 5, 0),
			Color = wallColor,
			Parent = model,
		})
	end
	local barrier = part({
		Name = "Barrier",
		Size = Vector3.new(20, 8, 0.4),
		Position = front + Vector3.new(0, 5, 0),
		Color = Color3.fromRGB(255, 40, 40),
		Material = Enum.Material.Neon,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})

	-- Vagas: grade 4 x 3 no fundo da base
	local slotPads: { BasePart } = {}
	for i = 1, TOTAL_SLOTS do
		local col = (i - 1) % 4
		local row = (i - 1) // 4
		local pos = center + Vector3.new((col - 1.5) * 12, 1.1, 0) - toFront * (20 - row * 11)
		local pad = part({
			Name = "Slot" .. i,
			Size = Vector3.new(9, 0.4, 9),
			Position = pos,
			Color = if i > Config.BaseSlots then Color3.fromRGB(60, 60, 60) else Color3.fromRGB(240, 240, 240),
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		})
		pad:SetAttribute("SlotIndex", i)
		if i > Config.BaseSlots then
			billboard(pad, "🔒 Passe +4 Vagas", UDim2.fromOffset(140, 30), Vector3.new(0, 2, 0))
		end
		table.insert(slotPads, pad)
	end

	local collectPad = part({
		Name = "CollectPad",
		Size = Vector3.new(10, 0.6, 6),
		Position = center + toFront * 14 + Vector3.new(-14, 1.2, 0),
		Color = Color3.fromRGB(60, 220, 90),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	billboard(collectPad, "💰 Coletar", UDim2.fromOffset(160, 50), Vector3.new(0, 3, 0)).Name = "Amount"

	local lockButton = part({
		Name = "LockButton",
		Size = Vector3.new(6, 0.6, 6),
		Position = center + toFront * 14 + Vector3.new(14, 1.2, 0),
		Color = Color3.fromRGB(255, 70, 70),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	billboard(lockButton, "🔒 Trancar", UDim2.fromOffset(160, 50), Vector3.new(0, 3, 0)).Name = "Status"

	local signPost = part({
		Name = "Sign",
		Size = Vector3.new(16, 4, 1),
		Position = front + Vector3.new(0, 11, 0),
		Color = Color3.fromRGB(30, 30, 40),
		Parent = model,
	})
	local signLabel = billboard(signPost, "Base livre", UDim2.fromOffset(260, 60), Vector3.new(0, 0, 0))

	model.PrimaryPart = floor
	model.Parent = map

	local plot: Plot = {
		Index = index,
		Model = model,
		Floor = floor,
		SlotPads = slotPads,
		CollectPad = collectPad,
		LockButton = lockButton,
		Barrier = barrier,
		SignLabel = signLabel,
		Spawn = CFrame.lookAt(center + Vector3.new(0, 4, 0), center + Vector3.new(0, 4, 0) + toFront),
		Owner = nil,
	}
	return plot
end

local function buildLeaderboard(map: Folder)
	local board = part({
		Name = "Leaderboard",
		Size = Vector3.new(1, 22, 30),
		Position = Vector3.new(Config.Conveyor.Length / 2 + 25, 12, 0),
		Color = Color3.fromRGB(25, 25, 35),
		Parent = map,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Left
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.12, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 215, 0)
	title.Text = "🏆 TOP RENASCIMENTOS"
	title.Parent = gui

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromScale(0.03, 0.13)
	list.Size = UDim2.fromScale(0.94, 0.85)
	list.BackgroundTransparency = 1
	list.ScrollBarThickness = 0
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	WorldService.LeaderboardFrame = list
end

function WorldService.Build()
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace
	WorldService.Map = map

	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 160)

	part({
		Name = "Ground",
		Size = Vector3.new(600, 2, 400),
		Position = Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(100, 190, 90),
		Material = Enum.Material.Grass,
		Parent = map,
	})

	-- Esteira
	local length = Config.Conveyor.Length
	part({
		Name = "Conveyor",
		Size = Vector3.new(length, 1.5, 12),
		Position = Vector3.new(0, 0.75, 0),
		Color = Color3.fromRGB(40, 40, 50),
		Material = Enum.Material.DiamondPlate,
		Parent = map,
	})
	for _, dz in { -6.5, 6.5 } do
		part({
			Name = "ConveyorRail",
			Size = Vector3.new(length, 2, 1),
			Position = Vector3.new(0, 1, dz),
			Color = Color3.fromRGB(255, 200, 0),
			Material = Enum.Material.Neon,
			Parent = map,
		})
	end
	local spawner = part({
		Name = "Spawner",
		Size = Vector3.new(6, 14, 16),
		Position = Vector3.new(-length / 2 - 3, 7, 0),
		Color = Color3.fromRGB(120, 60, 200),
		Material = Enum.Material.Neon,
		Parent = map,
	})
	billboard(spawner, "🥚 Bichos chegando!", UDim2.fromOffset(220, 50), Vector3.new(0, 10, 0))

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 0.5, -30)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = map

	local index = 0
	for _, side in { 1, -1 } do
		for _, x in PLOT_XS do
			index += 1
			table.insert(plots, buildPlot(map, index, x, side))
		end
	end

	buildLeaderboard(map)
end

function WorldService.AssignPlot(player: Player): Plot?
	for _, plot in plots do
		if not plot.Owner then
			plot.Owner = player
			plotByPlayer[player] = plot
			plot.SignLabel.Text = "Base de " .. player.DisplayName
			plot.Model:SetAttribute("OwnerUserId", player.UserId)
			player:SetAttribute("PlotIndex", plot.Index)
			return plot
		end
	end
	return nil
end

function WorldService.ReleasePlot(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	plotByPlayer[player] = nil
	plot.Owner = nil
	plot.SignLabel.Text = "Base livre"
	plot.Model:SetAttribute("OwnerUserId", nil)
	plot.Model:SetAttribute("LockedUntil", nil)
	plot.Barrier.Transparency = 1
end

function WorldService.GetPlot(player: Player): Plot?
	return plotByPlayer[player]
end

function WorldService.GetPlots(): { Plot }
	return plots
end

function WorldService.IsInsidePlot(plot: Plot, position: Vector3): boolean
	local relative = plot.Floor.CFrame:PointToObjectSpace(position)
	local half = PLOT_SIZE / 2
	return math.abs(relative.X) <= half and math.abs(relative.Z) <= half and relative.Y > -2 and relative.Y < 20
end

function WorldService.Init()
	WorldService.Build()
	Players.PlayerRemoving:Connect(WorldService.ReleasePlot)
end

return WorldService
