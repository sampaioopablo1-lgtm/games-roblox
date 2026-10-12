--!strict
-- Dinheiro, renda por segundo, coleta, renascimento, prêmio diário,
-- ganho offline, bônus de amigos e placar global.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local CritterMath = require(ReplicatedStorage.Shared.CritterMath)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local WorldService = require(script.Parent.WorldService)

local EconomyService = {}

local DAY = 24 * 60 * 60
local LEADERBOARD_REFRESH = 120

local leaderboardStore: OrderedDataStore? = nil
pcall(function()
	leaderboardStore = DataStoreService:GetOrderedDataStore("TopRebirths_v1")
end)

-- Evita require circular: carregado sob demanda.
local function BaseService()
	return require(script.Parent.BaseService) :: any
end
local function StealService()
	return require(script.Parent.StealService) :: any
end

local function notify(player: Player, text: string, kind: string?)
	Remotes.Notify:FireClient(player, text, kind or "info")
end
EconomyService.Notify = notify

function EconomyService.NotifyAll(text: string, kind: string?)
	Remotes.Notify:FireAllClients(text, kind or "info")
end

local function syncAttributes(player: Player, profile: DataService.Profile)
	player:SetAttribute("Cash", profile.Cash)
	player:SetAttribute("Rebirths", profile.Rebirths)
	player:SetAttribute("Uncollected", profile.Uncollected)
	player:SetAttribute("DailyStreak", profile.DailyStreak)
	player:SetAttribute("LastDaily", profile.LastDaily)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		(leaderstats:FindFirstChild("Dinheiro") :: StringValue).Value = Format.Cash(profile.Cash);
		(leaderstats:FindFirstChild("Renasc.") :: IntValue).Value = profile.Rebirths
	end
end
EconomyService.Sync = syncAttributes

function EconomyService.GetMultiplier(player: Player, profile: DataService.Profile): number
	local multiplier = 1 + profile.Rebirths * Config.Rebirth.IncomeBonusPerRebirth
	if MonetizationService.HasPass(player, "VIP") then
		multiplier *= 2
	end
	local friends = (player:GetAttribute("FriendsInServer") :: number?) or 0
	multiplier *= 1 + math.min(friends * Config.FriendBonusPerFriend, Config.FriendBonusMax)
	return multiplier
end

function EconomyService.GetIncomePerSecond(player: Player, profile: DataService.Profile): number
	local total = 0
	for _, slot in profile.Slots do
		total += CritterMath.BaseIncome(slot.Id, slot.Mutation)
	end
	return total * EconomyService.GetMultiplier(player, profile)
end

function EconomyService.AddCash(player: Player, amount: number)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	profile.Cash += amount
	syncAttributes(player, profile)
end

function EconomyService.TrySpend(player: Player, amount: number): boolean
	local profile = DataService.Get(player)
	if not profile or profile.Cash < amount then
		return false
	end
	profile.Cash -= amount
	syncAttributes(player, profile)
	return true
end

local function collect(player: Player)
	local profile = DataService.Get(player)
	if not profile or profile.Uncollected < 1 then
		return
	end
	local amount = math.floor(profile.Uncollected)
	profile.Uncollected -= amount
	profile.Cash += amount
	syncAttributes(player, profile)
	notify(player, "+" .. Format.Cash(amount), "cash")
end

local function updateCollectLabel(player: Player, profile: DataService.Profile)
	local plot = WorldService.GetPlot(player)
	if not plot then
		return
	end
	local gui = plot.CollectPad:FindFirstChildOfClass("BillboardGui")
	local label = gui and gui:FindFirstChildOfClass("TextLabel")
	if label then
		label.Text = if MonetizationService.HasPass(player, "AutoCollect")
			then "⚡ Coleta automática"
			else "💰 Coletar " .. Format.Cash(profile.Uncollected)
	end
end

local function tick()
	for _, player in Players:GetPlayers() do
		local profile = DataService.Get(player)
		if profile then
			local income = EconomyService.GetIncomePerSecond(player, profile)
			player:SetAttribute("IncomePerSecond", income)
			if MonetizationService.HasPass(player, "AutoCollect") then
				profile.Cash += income + math.floor(profile.Uncollected)
				profile.Uncollected = 0
			else
				profile.Uncollected += income
			end
			syncAttributes(player, profile)
			updateCollectLabel(player, profile)
		end
	end
end

local function rebirth(player: Player): (boolean, string)
	local profile = DataService.Get(player)
	if not profile then
		return false, "Carregando..."
	end
	local cost = Config.GetRebirthCost(profile.Rebirths)
	if profile.Cash < cost then
		return false, "Você precisa de " .. Format.Cash(cost)
	end
	if StealService().IsInvolved(player) then
		return false, "Termine de pegar o bicho primeiro!"
	end
	profile.Cash = Config.StartingCash
	profile.Uncollected = 0
	profile.Slots = {}
	profile.Rebirths += 1
	syncAttributes(player, profile)
	BaseService().Render(player)
	DataService.Save(player)
	local bonus = math.floor(profile.Rebirths * Config.Rebirth.IncomeBonusPerRebirth * 100)
	EconomyService.NotifyAll(("🔁 %s renasceu! (Renascimento %d)"):format(player.DisplayName, profile.Rebirths), "rare")
	return true, ("Renasceu! Bônus de renda: +%d%%"):format(bonus)
end

local function dailyAmount(profile: DataService.Profile, streak: number): number
	local rewards = Config.DailyRewards
	local base = rewards[math.min(streak, #rewards)]
	if Config.DailyRewardScalesWithRebirth then
		base *= 1 + profile.Rebirths
	end
	return base
end

local function claimDaily(player: Player): (boolean, string)
	local profile = DataService.Get(player)
	if not profile then
		return false, "Carregando..."
	end
	local now = os.time()
	local elapsed = now - profile.LastDaily
	if elapsed < DAY then
		return false, "Volte em " .. Format.Time(DAY - elapsed)
	end
	-- Perde a sequência se ficar mais de 48h sem resgatar
	profile.DailyStreak = if elapsed < 2 * DAY then profile.DailyStreak + 1 else 1
	profile.LastDaily = now
	local amount = dailyAmount(profile, profile.DailyStreak)
	profile.Cash += amount
	syncAttributes(player, profile)
	return true, ("Dia %d: +%s!"):format(profile.DailyStreak, Format.Cash(amount))
end

local function grantOffline(player: Player, profile: DataService.Profile)
	if profile.LastOnline <= 0 then
		return
	end
	local seconds = math.clamp(os.time() - profile.LastOnline, 0, Config.Offline.MaxSeconds)
	if seconds < 60 then
		return
	end
	local amount = math.floor(EconomyService.GetIncomePerSecond(player, profile) * seconds * Config.Offline.Rate)
	if amount > 0 then
		profile.Uncollected += amount
		task.delay(3, notify, player, ("Enquanto você estava fora seus bichos renderam %s!"):format(Format.Cash(amount)), "cash")
	end
end

-- Bônus de amigos: incentiva convidar amigos para o mesmo servidor.
local friendCache: { [string]: boolean } = {}
local function areFriends(a: Player, b: Player): boolean
	local cacheKey = math.min(a.UserId, b.UserId) .. "_" .. math.max(a.UserId, b.UserId)
	local cached = friendCache[cacheKey]
	if cached ~= nil then
		return cached
	end
	local ok, result = pcall(a.IsFriendsWithAsync, a, b.UserId)
	local value = ok and result == true
	friendCache[cacheKey] = value
	return value
end

local function refreshFriends()
	local players = Players:GetPlayers()
	for _, player in players do
		local count = 0
		for _, other in players do
			if other ~= player and other.Parent and areFriends(player, other) then
				count += 1
			end
		end
		if player.Parent then
			player:SetAttribute("FriendsInServer", count)
		end
	end
end

local function refreshLeaderboard()
	local frame = WorldService.LeaderboardFrame
	if not leaderboardStore or not frame then
		return
	end
	local ok, pages = pcall(function()
		return (leaderboardStore :: OrderedDataStore):GetSortedAsync(false, 10)
	end)
	if not ok then
		return
	end
	for _, child in frame:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for rank, entry in (pages :: DataStorePages):GetCurrentPage() do
		local userId = tonumber(string.match(entry.key, "%d+")) or 0
		local okName, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, 48)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = if rank == 1 then Color3.fromRGB(255, 215, 0) else Color3.new(1, 1, 1)
		label.Text = ("#%d  %s — %d"):format(rank, if okName then name else "???", entry.value)
		label.LayoutOrder = rank
		label.Parent = frame
	end
end

local function pushLeaderboard(player: Player)
	local profile = DataService.Get(player)
	if leaderboardStore and profile and profile.Rebirths > 0 then
		pcall(function()
			(leaderboardStore :: OrderedDataStore):SetAsync("U" .. player.UserId, profile.Rebirths)
		end)
	end
end

local function registerProducts()
	local function cashProduct(seconds: number, minimum: number)
		return function(player: Player, profile: DataService.Profile): boolean
			local amount = math.max(minimum, math.floor(EconomyService.GetIncomePerSecond(player, profile) * seconds))
			profile.Cash += amount
			syncAttributes(player, profile)
			notify(player, "Compra concluída: +" .. Format.Cash(amount) .. " 💰", "cash")
			return true
		end
	end
	MonetizationService.RegisterProduct("CashSmall", cashProduct(10 * 60, 5_000))
	MonetizationService.RegisterProduct("CashMedium", cashProduct(60 * 60, 50_000))
	MonetizationService.RegisterProduct("CashLarge", cashProduct(6 * 60 * 60, 500_000))
end

function EconomyService.Init()
	DataService.OnLoaded(function(player, profile)
		local leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		local cash = Instance.new("StringValue")
		cash.Name = "Dinheiro"
		cash.Parent = leaderstats
		local rebirths = Instance.new("IntValue")
		rebirths.Name = "Renasc."
		rebirths.Parent = leaderstats
		leaderstats.Parent = player

		grantOffline(player, profile)
		syncAttributes(player, profile)
		player:SetAttribute("Loaded", true)
	end)

	for _, plot in WorldService.GetPlots() do
		plot.CollectPad.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player and plot.Owner == player then
				collect(player)
			end
		end)
	end

	Remotes.Rebirth.OnServerInvoke = rebirth
	Remotes.ClaimDaily.OnServerInvoke = claimDaily
	registerProducts()

	Players.PlayerAdded:Connect(function()
		task.wait(2)
		refreshFriends()
	end)
	Players.PlayerRemoving:Connect(function(player)
		pushLeaderboard(player)
		task.defer(refreshFriends)
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			tick()
		end
	end)

	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				pushLeaderboard(player)
			end
			refreshLeaderboard()
			task.wait(LEADERBOARD_REFRESH)
		end
	end)
end

return EconomyService
