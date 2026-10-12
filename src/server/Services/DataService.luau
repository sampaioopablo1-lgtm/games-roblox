--!strict
-- Carrega/salva o progresso dos jogadores com DataStore, trava de sessão
-- simples (evita duplicação ao trocar de servidor) e salvamento automático.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

export type SlotData = { Id: string, Mutation: string? }

export type Profile = {
	Cash: number,
	Rebirths: number,
	Slots: { [string]: SlotData }, -- chave "1".."12" (string para salvar sem buracos)
	Uncollected: number,
	DailyStreak: number,
	LastDaily: number,
	LastOnline: number,
	TotalStolen: number,
	TotalSpentRobux: number,
	Purchases: { string },
	SessionLock: { JobId: string, Time: number }?,
}

local DataService = {}

local STORE_NAME = "RoubaBichos_v1"
local AUTOSAVE_INTERVAL = 120
local LOCK_EXPIRY = 30 * 60
local MAX_LOAD_ATTEMPTS = 6
local MAX_RECEIPTS_KEPT = 50

local jobId = if RunService:IsStudio() then "studio-" .. HttpService:GenerateGUID(false) else game.JobId

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore indisponível (ative 'Enable Studio Access to API Services'):", result)
	end
end

local profiles: { [Player]: Profile } = {}
local canSave: { [Player]: boolean } = {}
local loadedCallbacks: { (Player, Profile) -> () } = {}

local function defaultProfile(): Profile
	return {
		Cash = Config.StartingCash,
		Rebirths = 0,
		Slots = {},
		Uncollected = 0,
		DailyStreak = 0,
		LastDaily = 0,
		LastOnline = 0,
		TotalStolen = 0,
		TotalSpentRobux = 0,
		Purchases = {},
		SessionLock = nil,
	}
end

-- Preenche campos novos em perfis antigos sem perder dados.
local function reconcile(data: any): Profile
	local profile = defaultProfile()
	if type(data) == "table" then
		for key, value in data do
			(profile :: any)[key] = value
		end
	end
	return profile
end

local function key(player: Player): string
	return "Player_" .. player.UserId
end

local function loadAsync(player: Player): (Profile?, boolean)
	if not store then
		return defaultProfile(), false
	end

	for attempt = 1, MAX_LOAD_ATTEMPTS do
		local lockedElsewhere = false
		local loaded: Profile? = nil
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(key(player), function(old)
				local profile = reconcile(old)
				local lock = profile.SessionLock
				if lock and lock.JobId ~= jobId and os.time() - lock.Time < LOCK_EXPIRY and attempt < MAX_LOAD_ATTEMPTS then
					lockedElsewhere = true
					return nil -- não altera nada; tenta de novo
				end
				profile.SessionLock = { JobId = jobId, Time = os.time() }
				loaded = profile
				return profile
			end)
		end)
		if ok and loaded then
			return loaded, true
		elseif not ok then
			warn(("[DataService] Falha ao carregar %s (tentativa %d): %s"):format(player.Name, attempt, tostring(err)))
		elseif lockedElsewhere then
			-- outro servidor ainda está salvando; espera liberar
		end
		if not player.Parent then
			return nil, false
		end
		task.wait(if lockedElsewhere then 5 else 2 ^ attempt)
	end
	return nil, false
end

local function saveAsync(player: Player, release: boolean): boolean
	local profile = profiles[player]
	if not profile or not canSave[player] or not store then
		return false
	end
	profile.LastOnline = os.time()
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key(player), function(old)
			local current = reconcile(old)
			local lock = current.SessionLock
			if lock and lock.JobId ~= jobId then
				-- Outro servidor assumiu a sessão; não sobrescreve.
				return nil
			end
			local toSave = table.clone(profile)
			toSave.SessionLock = if release then nil else { JobId = jobId, Time = os.time() }
			return toSave
		end)
	end)
	if not ok then
		warn("[DataService] Falha ao salvar", player.Name, err)
	end
	return ok
end

function DataService.Get(player: Player): Profile?
	return profiles[player]
end

function DataService.OnLoaded(callback: (Player, Profile) -> ())
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile)
	end
end

function DataService.Save(player: Player): boolean
	return saveAsync(player, false)
end

-- Guarda o ID do recibo para nunca conceder a mesma compra duas vezes.
function DataService.HasReceipt(profile: Profile, purchaseId: string): boolean
	return table.find(profile.Purchases, purchaseId) ~= nil
end

function DataService.AddReceipt(profile: Profile, purchaseId: string)
	table.insert(profile.Purchases, purchaseId)
	while #profile.Purchases > MAX_RECEIPTS_KEPT do
		table.remove(profile.Purchases, 1)
	end
end

function DataService.Init()
	local function onPlayerAdded(player: Player)
		local profile, saveable = loadAsync(player)
		if not player.Parent then
			return
		end
		if not profile then
			player:Kick("Não foi possível carregar seus dados. Tente entrar novamente em instantes.")
			return
		end
		profiles[player] = profile
		canSave[player] = saveable
		for _, callback in loadedCallbacks do
			task.spawn(callback, player, profile)
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		saveAsync(player, true)
		profiles[player] = nil
		canSave[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in profiles do
				task.spawn(saveAsync, player, false)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				saveAsync(player, true)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.2)
		end
	end)
end

return DataService
