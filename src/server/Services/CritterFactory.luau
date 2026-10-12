--!strict
-- Monta o visual dos bichos com peças simples (sem malhas externas).
-- Troque por modelos 3D próprios depois: basta retornar um Model com PrimaryPart.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Format = require(game:GetService("ReplicatedStorage").Shared.Format)
local CritterMath = require(game:GetService("ReplicatedStorage").Shared.CritterMath)

local CritterFactory = {}

local function newPart(shape: Enum.PartType, size: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- Gera uma variação visual estável a partir do id (formas diferentes por bicho).
local function seedFrom(id: string): number
	local seed = 0
	for i = 1, #id do
		seed = (seed * 31 + string.byte(id, i)) % 2147483647
	end
	return seed
end

export type BuildOptions = { ShowLabel: boolean?, LabelExtra: string? }

function CritterFactory.Build(critterId: string, mutation: string?, options: BuildOptions?): Model
	local critter = Config.GetCritter(critterId)
	assert(critter, "Bicho desconhecido: " .. critterId)
	local rarity = Config.Rarities[critter.Rarity]
	local mutationInfo = mutation and Config.Mutations[mutation]
	local color = if mutationInfo and mutationInfo.Color then mutationInfo.Color else rarity.Color
	local material = if mutationInfo then Enum.Material.Neon elseif rarity.Order >= 5 then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local size = critter.Size
	local rng = Random.new(seedFrom(critterId))

	local model = Instance.new("Model")
	model.Name = critter.Name

	local body = newPart(Enum.PartType.Ball, Vector3.one * size, color, material)
	body.Name = "Body"
	body.CFrame = CFrame.new(0, size / 2, 0)
	body.PivotOffset = CFrame.new(0, -size / 2, 0) -- pivô nos "pés" do bicho
	body.Parent = model
	model.PrimaryPart = body

	local function attach(p: BasePart, offset: CFrame)
		p.CFrame = body.CFrame * offset
		p.Parent = model
	end

	-- olhos
	for _, side in { -1, 1 } do
		local eye = newPart(Enum.PartType.Ball, Vector3.one * size * 0.28, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
		attach(eye, CFrame.new(side * size * 0.2, size * 0.12, -size * 0.38))
		local pupil = newPart(Enum.PartType.Ball, Vector3.one * size * 0.14, Color3.new(0.05, 0.05, 0.05), Enum.Material.SmoothPlastic)
		attach(pupil, CFrame.new(side * size * 0.2, size * 0.12, -size * 0.5))
	end

	-- orelhas / chifres variam por bicho
	local earStyle = rng:NextInteger(1, 3)
	for _, side in { -1, 1 } do
		local ear
		if earStyle == 1 then
			ear = newPart(Enum.PartType.Ball, Vector3.new(0.3, 0.6, 0.3) * size, color:Lerp(Color3.new(1, 1, 1), 0.3), material)
		elseif earStyle == 2 then
			ear = newPart(Enum.PartType.Block, Vector3.new(0.15, 0.5, 0.15) * size, color:Lerp(Color3.new(0, 0, 0), 0.3), material)
		else
			ear = newPart(Enum.PartType.Cylinder, Vector3.new(0.5, 0.25, 0.25) * size, color:Lerp(Color3.new(1, 1, 1), 0.5), material)
		end
		attach(ear, CFrame.new(side * size * 0.3, size * 0.48, 0) * CFrame.Angles(0, 0, side * -0.3))
	end

	-- brilho para raros+
	if rarity.Order >= 4 or mutationInfo then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 10 + size * 2
		light.Brightness = 1.5
		light.Parent = body
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = color
		sparkles.Parent = body
	end

	local opts: BuildOptions = options or {}
	if opts.ShowLabel ~= false then
		local gui = Instance.new("BillboardGui")
		gui.Name = "Label"
		gui.Size = UDim2.fromOffset(200, 70)
		gui.StudsOffsetWorldSpace = Vector3.new(0, size + 2, 0)
		gui.MaxDistance = 80
		gui.Parent = body

		local layout = Instance.new("UIListLayout")
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.Parent = gui

		local function line(text: string, textColor: Color3, height: number)
			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, 0, height, 0)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.TextColor3 = textColor
			label.TextStrokeTransparency = 0.3
			label.Text = text
			label.Parent = gui
			return label
		end

		line(CritterMath.DisplayName(critterId, mutation), Color3.new(1, 1, 1), 0.36)
		line(rarity.Name, rarity.Color, 0.28)
		local income = CritterMath.BaseIncome(critterId, mutation)
		line(opts.LabelExtra or (Format.Cash(income) .. "/s"), Color3.fromRGB(120, 255, 120), 0.36).Name = "Extra"
	end

	return model
end

-- Converte o modelo para ser carregado por um personagem (soldado e sem massa).
function CritterFactory.MakeCarryable(model: Model, attachTo: BasePart, offset: CFrame)
	local body = model.PrimaryPart :: BasePart
	model:PivotTo(attachTo.CFrame * offset)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.Massless = true
			descendant.CanCollide = false
			if descendant ~= body then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = body
				weld.Part1 = descendant
				weld.Parent = descendant
			end
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = attachTo
	weld.Part1 = body
	weld.Parent = body
end

return CritterFactory
