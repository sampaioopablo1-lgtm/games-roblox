--!strict
-- Esteira central: bichos aleatórios passam e qualquer jogador pode comprar.
-- Inclui os produtos "Sorte do Servidor" e "Chuva Mítica" (compras sociais
-- que beneficiam/agitam o servidor inteiro — ótimas para viralizar).

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local CritterMath = require(ReplicatedStorage.Shared.CritterMath)
local MonetizationService = require(script.Parent.MonetizationService)
local WorldService = require(script.Parent.WorldService)
local EconomyService = require(script.Parent.EconomyService)
local BaseService = require(script.Parent.BaseService)
local CritterFactory = require(script.Parent.CritterFactory)

local ConveyorService = {}

type Pod = { Model: Model, CritterId: string, Distance: number, PriorityUserId: number?, PriorityUntil: number }

local pods: { Pod } = {}
local random = Random.new()
local podFolder: Folder

local function serverLuckActive(): boolean
	return os.time() < ((workspace:GetAttribute("ServerLuckUntil") :: number?) or 0)
end

local function pickCritter(onlyRarities: { string }?): string
	local luck = if serverLuckActive() then Config.ServerLuckMultiplier else 1
	local rarityWeights: { [string]: number } = {}
	local totalWeight = 0
	for key, rarity in Config.Rarities do
		if onlyRarities and not table.find(onlyRarities, key) then
			continue
		end
		local weight = if key == "Comum" then rarity.Weight else rarity.Weight * luck
		rarityWeights[key] = weight
		totalWeight += weight
	end

	local roll = random:NextNumber() * totalWeight
	local chosenRarity = "Comum"
	for key, weight in rarityWeights do
		roll -= weight
		if roll <= 0 then
			chosenRarity = key
			break
		end
	end

	local options = {}
	for _, critter in Config.Critters do
		if critter.Rarity == chosenRarity then
			table.insert(options, critter.Id)
		end
	end
	-- Dentro da raridade, os mais baratos aparecem mais
	local weights, total = {}, 0
	for i, id in options do
		local w = 1 / i
		weights[id] = w
		total += w
	end
	local pick = random:NextNumber() * total
	for _, id in options do
		pick -= weights[id]
		if pick <= 0 then
			return id
		end
	end
	return options[1]
end

local function rollMutation(player: Player): string?
	local luck = if MonetizationService.HasPass(player, "Lucky") then 2 else 1
	local roll = random:NextNumber()
	if roll < Config.Mutations.Diamante.Chance * luck then
		return "Diamante"
	elseif roll < (Config.Mutations.Diamante.Chance + Config.Mutations.Ouro.Chance) * luck then
		return "Ouro"
	end
	return nil
end

local function removePod(pod: Pod)
	local index = table.find(pods, pod)
	if index then
		table.remove(pods, index)
	end
	pod.Model:Destroy()
end

local function tryBuy(player: Player, pod: Pod)
	if not table.find(pods, pod) then
		return
	end
	local reserved = pod.PriorityUserId ~= nil and os.clock() < pod.PriorityUntil
	if reserved and pod.PriorityUserId ~= player.UserId then
		EconomyService.Notify(player, "Este bicho está reservado para quem comprou a Chuva Mítica!", "error")
		return
	end
	local critter = Config.GetCritter(pod.CritterId)
	if not critter then
		return
	end
	if not BaseService.GetFreeSlot(player) then
		EconomyService.Notify(player, "Sua base está cheia! Venda um bicho (F) ou compre +4 Vagas.", "error")
		return
	end
	if not reserved and not EconomyService.TrySpend(player, critter.Price) then
		EconomyService.Notify(player, "Dinheiro insuficiente!", "error")
		return
	end
	removePod(pod)
	local mutation = rollMutation(player)
	BaseService.AddCritter(player, { Id = critter.Id, Mutation = mutation })

	local name = CritterMath.DisplayName(critter.Id, mutation)
	local rarity = Config.Rarities[critter.Rarity]
	if rarity.Order >= 4 or mutation then
		EconomyService.NotifyAll(("✨ %s pegou %s (%s)!"):format(player.DisplayName, name, rarity.Name), "rare")
	else
		EconomyService.Notify(player, "Você comprou " .. name .. "!", "info")
	end
end

function ConveyorService.Spawn(critterId: string, priorityPlayer: Player?)
	local critter = Config.GetCritter(critterId)
	if not critter then
		return
	end
	local model = CritterFactory.Build(critterId, nil, { LabelExtra = Format.Cash(critter.Price) .. " • " .. Format.Cash(critter.Income) .. "/s" })
	local pod: Pod = {
		Model = model,
		CritterId = critterId,
		Distance = 0,
		PriorityUserId = if priorityPlayer then priorityPlayer.UserId else nil,
		PriorityUntil = os.clock() + 30,
	}

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = if priorityPlayer then "Pegar (reservado)" else "Comprar " .. Format.Cash(critter.Price)
	prompt.ObjectText = critter.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player)
		tryBuy(player, pod)
	end)
	prompt.Parent = model.PrimaryPart

	model:PivotTo(CFrame.lookAt(WorldService.ConveyorStart, WorldService.ConveyorStart + Vector3.new(0, 0, -1)))
	model.Parent = podFolder
	table.insert(pods, pod)
end

local function step(dt: number)
	local startPos = WorldService.ConveyorStart
	local direction = (WorldService.ConveyorEnd - startPos).Unit
	local length = (WorldService.ConveyorEnd - startPos).Magnitude
	for i = #pods, 1, -1 do
		local pod = pods[i]
		pod.Distance += Config.Conveyor.Speed * dt
		if pod.Distance >= length then
			removePod(pod)
		else
			local position = startPos + direction * pod.Distance
			local bob = math.abs(math.sin(pod.Distance * 0.6)) * 0.6
			pod.Model:PivotTo(CFrame.lookAt(position, position + Vector3.new(0, 0, -1)) + Vector3.new(0, bob - 2.5, 0))
		end
	end
end

function ConveyorService.Init()
	podFolder = Instance.new("Folder")
	podFolder.Name = "ConveyorCritters"
	podFolder.Parent = workspace

	RunService.Heartbeat:Connect(step)

	task.spawn(function()
		while true do
			ConveyorService.Spawn(pickCritter())
			task.wait(Config.Conveyor.SpawnInterval)
		end
	end)

	MonetizationService.RegisterProduct("ServerLuck", function(player)
		local current = math.max(os.time(), (workspace:GetAttribute("ServerLuckUntil") :: number?) or 0)
		workspace:SetAttribute("ServerLuckUntil", current + Config.ServerLuckDuration)
		EconomyService.NotifyAll(("🍀 %s ativou SORTE DO SERVIDOR! Raros 2x para todos!"):format(player.DisplayName), "rare")
		return true
	end)

	MonetizationService.RegisterProduct("MythicDrop", function(player)
		-- O comprador ganha um Mítico/Secreto na base (ou grátis na esteira se a base
		-- estiver cheia) e um bônus extra cai na esteira para o servidor disputar.
		local critterId = pickCritter({ "Mitico", "Secreto" })
		local name = CritterMath.DisplayName(critterId)
		if BaseService.AddCritter(player, { Id = critterId, Mutation = rollMutation(player) }) then
			EconomyService.Notify(player, name .. " foi para a sua base!", "rare")
		else
			ConveyorService.Spawn(critterId, player)
			EconomyService.Notify(player, "Base cheia! Pegue seu " .. name .. " GRÁTIS na esteira (30s).", "rare")
		end
		ConveyorService.Spawn(pickCritter({ "Mitico", "Secreto" }))
		EconomyService.NotifyAll(("🌠 %s soltou uma CHUVA MÍTICA! Tem um Mítico na esteira!"):format(player.DisplayName), "rare")
		return true
	end)
end

return ConveyorService
