--!strict
-- Roubo: segure E num bicho de outra base, carregue até a SUA base.
-- Se o ladrão morrer, levar um tapa, sair do jogo ou demorar demais, o bicho volta.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CritterMath = require(ReplicatedStorage.Shared.CritterMath)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local WorldService = require(script.Parent.WorldService)
local EconomyService = require(script.Parent.EconomyService)
local BaseService = require(script.Parent.BaseService)
local CritterFactory = require(script.Parent.CritterFactory)

local StealService = {}

type Carry = {
	Thief: Player,
	Owner: Player,
	SlotIndex: number,
	Slot: DataService.SlotData,
	Model: Model,
	StartedAt: number,
	Connections: { RBXScriptConnection },
}

local carries: { [Player]: Carry } = {} -- por ladrão
local lastSlap: { [Player]: number } = {}

local function setWalkSpeed(player: Player, speed: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

function StealService.IsSlotBusy(owner: Player, index: number): boolean
	for _, carry in carries do
		if carry.Owner == owner and carry.SlotIndex == index then
			return true
		end
	end
	return false
end

-- Jogador está roubando ou sendo roubado agora?
function StealService.IsInvolved(player: Player): boolean
	for thief, carry in carries do
		if thief == player or carry.Owner == player then
			return true
		end
	end
	return false
end

local function finish(carry: Carry)
	carries[carry.Thief] = nil
	for _, connection in carry.Connections do
		connection:Disconnect()
	end
	carry.Model:Destroy()
	carry.Thief:SetAttribute("Carrying", nil)
	if carry.Thief.Parent then
		setWalkSpeed(carry.Thief, 16)
	end
end

local function cancel(carry: Carry, reason: string)
	if carries[carry.Thief] ~= carry then
		return
	end
	finish(carry)
	if carry.Owner.Parent then
		BaseService.SetSlotVisible(carry.Owner, carry.SlotIndex, true)
		EconomyService.Notify(carry.Owner, "Seu bicho voltou para casa! (" .. reason .. ")", "info")
	end
	if carry.Thief.Parent then
		EconomyService.Notify(carry.Thief, "Roubo falhou: " .. reason, "error")
	end
end

local function deliver(carry: Carry)
	if carries[carry.Thief] ~= carry then
		return
	end
	-- Confirma que o bicho ainda está na base do dono antes de transferir
	local ownerProfile = DataService.Get(carry.Owner)
	local current = ownerProfile and ownerProfile.Slots[tostring(carry.SlotIndex)]
	if not current or current.Id ~= carry.Slot.Id or current.Mutation ~= carry.Slot.Mutation then
		cancel(carry, "o bicho sumiu")
		return
	end
	if not BaseService.GetFreeSlot(carry.Thief) then
		cancel(carry, "sua base está cheia")
		return
	end
	finish(carry)
	BaseService.RemoveCritter(carry.Owner, carry.SlotIndex)
	BaseService.AddCritter(carry.Thief, carry.Slot)

	local thiefProfile = DataService.Get(carry.Thief)
	if thiefProfile then
		thiefProfile.TotalStolen += 1
	end
	local name = CritterMath.DisplayName(carry.Slot.Id, carry.Slot.Mutation)
	EconomyService.Notify(carry.Thief, "Você roubou " .. name .. "! 😈", "rare")
	EconomyService.Notify(carry.Owner, carry.Thief.DisplayName .. " roubou seu " .. name .. "! Tranque a base 🔒", "error")
	DataService.Save(carry.Owner)
	DataService.Save(carry.Thief)
end

function StealService.TryStart(thief: Player, owner: Player, index: number)
	if thief == owner or carries[thief] or StealService.IsSlotBusy(owner, index) then
		return
	end
	local ownerPlot = WorldService.GetPlot(owner)
	local ownerProfile = DataService.Get(owner)
	local slot = ownerProfile and ownerProfile.Slots[tostring(index)]
	if not ownerPlot or not slot or not WorldService.GetPlot(thief) then
		return
	end
	if BaseService.IsLocked(ownerPlot) then
		EconomyService.Notify(thief, "Esta base está trancada! 🔒", "error")
		return
	end
	if not BaseService.GetFreeSlot(thief) then
		EconomyService.Notify(thief, "Sua base está cheia! Venda um bicho antes de roubar.", "error")
		return
	end
	local character = thief.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not head then
		return
	end
	-- Validação anti-exploit de distância
	local slotModel = BaseService.GetSlotModel(owner, index)
	if not slotModel or (slotModel:GetPivot().Position - head.Position).Magnitude > 20 then
		return
	end

	local model = CritterFactory.Build(slot.Id, slot.Mutation, { LabelExtra = "😈 ROUBANDO!" })
	CritterFactory.MakeCarryable(model, head, CFrame.new(0, head.Size.Y / 2 + 0.5, 0))
	model.Parent = character

	local carry: Carry = {
		Thief = thief,
		Owner = owner,
		SlotIndex = index,
		Slot = { Id = slot.Id, Mutation = slot.Mutation },
		Model = model,
		StartedAt = os.clock(),
		Connections = {},
	}
	carries[thief] = carry
	table.insert(carry.Connections, humanoid.Died:Connect(function()
		cancel(carry, "o ladrão caiu")
	end))

	BaseService.SetSlotVisible(owner, index, false)
	thief:SetAttribute("Carrying", CritterMath.DisplayName(slot.Id, slot.Mutation))
	setWalkSpeed(thief, if MonetizationService.HasPass(thief, "FastThief") then Config.Steal.FastCarrySpeed else Config.Steal.CarrySpeed)
	EconomyService.Notify(owner, "🚨 " .. thief.DisplayName .. " está roubando seu bicho! Dê um TAPA nele!", "error")
end

function StealService.Slap(attacker: Player)
	local now = os.clock()
	if now - (lastSlap[attacker] or 0) < Config.Steal.SlapCooldown then
		return
	end
	lastSlap[attacker] = now
	local character = attacker.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	for _, target in Players:GetPlayers() do
		if target == attacker then
			continue
		end
		local targetCharacter = target.Character
		local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
		local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
		if not targetRoot or not targetHumanoid then
			continue
		end
		local offset = targetRoot.Position - root.Position
		if offset.Magnitude <= Config.Steal.SlapRange then
			local carry = carries[target]
			if carry then
				cancel(carry, "levou um tapa de " .. attacker.DisplayName)
			end
			-- atordoa e empurra
			targetHumanoid.WalkSpeed = 0
			targetHumanoid.Jump = true
			targetRoot:ApplyImpulse((offset.Unit + Vector3.new(0, 0.6, 0)) * targetRoot.AssemblyMass * 60)
			task.delay(Config.Steal.StunTime, function()
				if targetHumanoid.Parent and not carries[target] then
					targetHumanoid.WalkSpeed = 16
				end
			end)
		end
	end
end

function StealService.Init()
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for thief, carry in carries do
			if now - carry.StartedAt > Config.Steal.Timeout then
				cancel(carry, "demorou demais")
				continue
			end
			local plot = WorldService.GetPlot(thief)
			local character = thief.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if plot and root and WorldService.IsInsidePlot(plot, root.Position) then
				deliver(carry)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		for _, carry in carries do
			if carry.Thief == player then
				cancel(carry, "o ladrão saiu")
			elseif carry.Owner == player then
				cancel(carry, "o dono saiu")
			end
		end
		lastSlap[player] = nil
	end)
end

return StealService
