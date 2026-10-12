--!strict
-- Base do jogador: vagas com bichos, vender, cadeado, spawn e ferramenta de tapa.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local CritterMath = require(ReplicatedStorage.Shared.CritterMath)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local WorldService = require(script.Parent.WorldService)
local EconomyService = require(script.Parent.EconomyService)
local CritterFactory = require(script.Parent.CritterFactory)

local BaseService = {}

local function StealService()
	return require(script.Parent.StealService) :: any
end

-- modelos renderizados: [player][slotIndex] = Model
local rendered: { [Player]: { [number]: Model } } = {}
local lockCooldownUntil: { [Player]: number } = {}

function BaseService.MaxSlots(player: Player): number
	return Config.BaseSlots + (if MonetizationService.HasPass(player, "ExtraSlots") then Config.ExtraSlotsFromPass else 0)
end

function BaseService.GetFreeSlot(player: Player): number?
	local profile = DataService.Get(player)
	if not profile then
		return nil
	end
	for i = 1, BaseService.MaxSlots(player) do
		if not profile.Slots[tostring(i)] then
			return i
		end
	end
	return nil
end

function BaseService.IsLocked(plot: WorldService.Plot): boolean
	local lockedUntil = plot.Model:GetAttribute("LockedUntil") :: number?
	return lockedUntil ~= nil and os.time() < lockedUntil
end

local function addPrompt(parent: BasePart, kind: string, actionText: string, objectText: string, hold: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = kind .. "Prompt"
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = if kind == "Steal" then Enum.KeyCode.E else Enum.KeyCode.F
	prompt:SetAttribute("PromptKind", kind)
	prompt.Parent = parent
	return prompt
end

local function renderSlot(player: Player, plot: WorldService.Plot, index: number, slot: DataService.SlotData)
	local pad = plot.SlotPads[index]
	local model = CritterFactory.Build(slot.Id, slot.Mutation)
	local position = pad.Position + Vector3.new(0, 0.2, 0)
	model:PivotTo(CFrame.lookAt(position, position + plot.Spawn.LookVector))
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("SlotIndex", index)

	local body = model.PrimaryPart :: BasePart
	local name = CritterMath.DisplayName(slot.Id, slot.Mutation)
	local sell = addPrompt(body, "Sell", "Vender " .. Format.Cash(CritterMath.SellValue(slot.Id, slot.Mutation)), name, 0.5)
	sell.Triggered:Connect(function(who)
		if who == player then
			BaseService.Sell(player, index)
		end
	end)
	local steal = addPrompt(body, "Steal", "Roubar", name, Config.Steal.HoldDuration)
	steal.Triggered:Connect(function(who)
		if who ~= player then
			StealService().TryStart(who, player, index)
		end
	end)

	model.Parent = plot.Model
	rendered[player][index] = model
end

function BaseService.Render(player: Player)
	local profile = DataService.Get(player)
	local plot = WorldService.GetPlot(player)
	if not profile or not plot then
		return
	end
	rendered[player] = rendered[player] or {}
	for _, model in rendered[player] do
		model:Destroy()
	end
	table.clear(rendered[player])
	for key, slot in profile.Slots do
		local index = tonumber(key)
		if index and Config.GetCritter(slot.Id) then
			renderSlot(player, plot, index, slot)
		end
	end
	-- Destaca vagas extras liberadas pelo passe
	local hasExtra = MonetizationService.HasPass(player, "ExtraSlots")
	for i = Config.BaseSlots + 1, #plot.SlotPads do
		local pad = plot.SlotPads[i]
		pad.Color = if hasExtra then Color3.fromRGB(255, 230, 120) else Color3.fromRGB(60, 60, 60)
		local label = pad:FindFirstChildOfClass("BillboardGui")
		if label then
			label.Enabled = not hasExtra
		end
	end
end

function BaseService.GetSlotModel(player: Player, index: number): Model?
	local models = rendered[player]
	return models and models[index]
end

function BaseService.SetSlotVisible(player: Player, index: number, visible: boolean)
	local model = BaseService.GetSlotModel(player, index)
	if not model then
		return
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = if visible then 0 else 1
		elseif descendant:IsA("BillboardGui") or descendant:IsA("ProximityPrompt") or descendant:IsA("Light") or descendant:IsA("Sparkles") then
			(descendant :: any).Enabled = visible
		end
	end
end

-- Coloca um bicho numa vaga livre. Retorna o índice ou nil se a base está cheia.
function BaseService.AddCritter(player: Player, slot: DataService.SlotData): number?
	local profile = DataService.Get(player)
	local plot = WorldService.GetPlot(player)
	local index = BaseService.GetFreeSlot(player)
	if not profile or not plot or not index then
		return nil
	end
	profile.Slots[tostring(index)] = slot
	renderSlot(player, plot, index, slot)
	return index
end

function BaseService.RemoveCritter(player: Player, index: number): DataService.SlotData?
	local profile = DataService.Get(player)
	if not profile then
		return nil
	end
	local slot = profile.Slots[tostring(index)]
	profile.Slots[tostring(index)] = nil
	local model = BaseService.GetSlotModel(player, index)
	if model then
		model:Destroy()
		rendered[player][index] = nil
	end
	return slot
end

function BaseService.Sell(player: Player, index: number)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local slot = profile.Slots[tostring(index)]
	if not slot or StealService().IsSlotBusy(player, index) then
		return
	end
	local value = CritterMath.SellValue(slot.Id, slot.Mutation)
	BaseService.RemoveCritter(player, index)
	EconomyService.AddCash(player, value)
	EconomyService.Notify(player, ("Vendeu %s por %s"):format(CritterMath.DisplayName(slot.Id, slot.Mutation), Format.Cash(value)), "cash")
end

function BaseService.Lock(player: Player, ignoreCooldown: boolean?): boolean
	local plot = WorldService.GetPlot(player)
	if not plot or BaseService.IsLocked(plot) then
		return false
	end
	local now = os.time()
	if not ignoreCooldown and now < (lockCooldownUntil[player] or 0) then
		return false
	end
	local duration = if MonetizationService.HasPass(player, "SuperLock") then Config.Lock.SuperDuration else Config.Lock.Duration
	plot.Model:SetAttribute("LockedUntil", now + duration)
	lockCooldownUntil[player] = now + duration + Config.Lock.Cooldown
	plot.Barrier.Transparency = 0.4
	EconomyService.Notify(player, ("🔒 Base trancada por %ds!"):format(duration), "info")
	return true
end

local function updateLockVisuals()
	local now = os.time()
	for _, plot in WorldService.GetPlots() do
		local owner = plot.Owner
		local gui = plot.LockButton:FindFirstChildOfClass("BillboardGui")
		local label = gui and gui:FindFirstChildOfClass("TextLabel")
		if not owner or not label then
			continue
		end
		local lockedUntil = (plot.Model:GetAttribute("LockedUntil") :: number?) or 0
		if now < lockedUntil then
			label.Text = "🔒 Trancada " .. Format.Time(lockedUntil - now)
			plot.Barrier.Transparency = 0.4
		else
			plot.Barrier.Transparency = 1
			local cooldown = (lockCooldownUntil[owner] or 0) - now
			label.Text = if cooldown > 0 then "⏳ " .. Format.Time(cooldown) else "🔓 Pise para trancar"
		end
	end
end

local function giveSlapTool(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack or backpack:FindFirstChild("Tapa") then
		return
	end
	local tool = Instance.new("Tool")
	tool.Name = "Tapa"
	tool.ToolTip = "Bata em ladrões para recuperar seus bichos!"
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool.Activated:Connect(function()
		StealService().Slap(player)
	end)
	tool.Parent = backpack
end

local function onCharacterAdded(player: Player, character: Model)
	local plot = WorldService.GetPlot(player)
	giveSlapTool(player)
	if plot then
		local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
		if root then
			task.wait() -- deixa o Roblox posicionar o personagem antes de mover
			character:PivotTo(plot.Spawn)
		end
	end
end

function BaseService.Init()
	DataService.OnLoaded(function(player, _profile)
		local plot = WorldService.AssignPlot(player)
		if not plot then
			player:Kick("Servidor cheio, tente outro servidor.")
			return
		end
		rendered[player] = {}
		BaseService.Render(player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
	end)

	MonetizationService.OnPassGranted(function(player, passKey)
		if passKey == "ExtraSlots" then
			BaseService.Render(player)
		end
		EconomyService.Notify(player, "Obrigado pela compra! 🎉", "rare")
	end)

	MonetizationService.RegisterProduct("InstantLock", function(player)
		local plot = WorldService.GetPlot(player)
		if not plot then
			return false
		end
		if not BaseService.IsLocked(plot) then
			BaseService.Lock(player, true)
		end
		return true
	end)

	for _, plot in WorldService.GetPlots() do
		plot.LockButton.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player and plot.Owner == player then
				BaseService.Lock(player)
			end
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		local models = rendered[player]
		if models then
			for _, model in models do
				model:Destroy()
			end
		end
		rendered[player] = nil
		lockCooldownUntil[player] = nil
	end)

	task.spawn(function()
		while true do
			updateLockVisuals()
			task.wait(1)
		end
	end)
end

return BaseService
