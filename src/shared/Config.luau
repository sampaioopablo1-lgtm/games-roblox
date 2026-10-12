--!strict
-- Configuração central do jogo. Ajuste balanceamento e IDs de monetização aqui.

local Config = {}

Config.GameName = "Rouba Bichos!"

-------------------------------------------------------------------------------
-- MONETIZAÇÃO
-- Crie os Game Passes e Developer Products no Creator Hub
-- (create.roblox.com > sua experiência > Monetização) e cole os IDs abaixo.
-- Com ID = 0 o item fica oculto na loja e o benefício nunca é concedido.
-------------------------------------------------------------------------------

export type PassInfo = { Key: string, Id: number, Name: string, Description: string, SuggestedPrice: number }
export type ProductInfo = { Key: string, Id: number, Name: string, Description: string, SuggestedPrice: number }

Config.GamePasses = {
	{ Key = "VIP", Id = 0, Name = "VIP", Description = "2x dinheiro para sempre + tag VIP", SuggestedPrice = 399 },
	{ Key = "AutoCollect", Id = 0, Name = "Coleta Automática", Description = "O dinheiro da base vai direto pro seu bolso", SuggestedPrice = 199 },
	{ Key = "ExtraSlots", Id = 0, Name = "+4 Vagas na Base", Description = "Guarde mais bichos e ganhe mais", SuggestedPrice = 249 },
	{ Key = "SuperLock", Id = 0, Name = "Super Cadeado", Description = "Cadeado dura o dobro (120s)", SuggestedPrice = 149 },
	{ Key = "Lucky", Id = 0, Name = "Sortudo", Description = "Dobro de chance de mutações Ouro e Diamante", SuggestedPrice = 299 },
	{ Key = "FastThief", Id = 0, Name = "Ladrão Veloz", Description = "Corre mais rápido carregando bichos roubados", SuggestedPrice = 179 },
} :: { PassInfo }

Config.Products = {
	{ Key = "CashSmall", Id = 0, Name = "Saco de Moedas", Description = "10 minutos de renda (mín. $5K)", SuggestedPrice = 29 },
	{ Key = "CashMedium", Id = 0, Name = "Cofre de Moedas", Description = "1 hora de renda (mín. $50K)", SuggestedPrice = 99 },
	{ Key = "CashLarge", Id = 0, Name = "Banco de Moedas", Description = "6 horas de renda (mín. $500K)", SuggestedPrice = 399 },
	{ Key = "ServerLuck", Id = 0, Name = "Sorte do Servidor", Description = "15 min de chance dobrada de raros para TODOS", SuggestedPrice = 149 },
	{ Key = "MythicDrop", Id = 0, Name = "Chuva Mítica", Description = "Ganhe um bicho Mítico/Secreto + solte outro na esteira!", SuggestedPrice = 249 },
	{ Key = "InstantLock", Id = 0, Name = "Cadeado Instantâneo", Description = "Tranca sua base agora, sem esperar a recarga", SuggestedPrice = 25 },
} :: { ProductInfo }

-------------------------------------------------------------------------------
-- RARIDADES E BICHOS
-------------------------------------------------------------------------------

export type Rarity = { Name: string, Color: Color3, Weight: number, Order: number }

Config.Rarities = {
	Comum = { Name = "Comum", Color = Color3.fromRGB(190, 190, 190), Weight = 60, Order = 1 },
	Raro = { Name = "Raro", Color = Color3.fromRGB(70, 150, 255), Weight = 25, Order = 2 },
	Epico = { Name = "Épico", Color = Color3.fromRGB(170, 80, 255), Weight = 10, Order = 3 },
	Lendario = { Name = "Lendário", Color = Color3.fromRGB(255, 190, 40), Weight = 4, Order = 4 },
	Mitico = { Name = "Mítico", Color = Color3.fromRGB(255, 60, 90), Weight = 0.9, Order = 5 },
	Secreto = { Name = "Secreto", Color = Color3.fromRGB(20, 255, 200), Weight = 0.1, Order = 6 },
} :: { [string]: Rarity }

export type Critter = { Id: string, Name: string, Rarity: string, Price: number, Income: number, Size: number }

Config.Critters = {
	{ Id = "pipoquinha", Name = "Pipoquinha", Rarity = "Comum", Price = 50, Income = 1, Size = 2 },
	{ Id = "bolotinha", Name = "Bolotinha", Rarity = "Comum", Price = 120, Income = 2, Size = 2.2 },
	{ Id = "fofura", Name = "Fofura", Rarity = "Comum", Price = 250, Income = 4, Size = 2.4 },
	{ Id = "zigzag", Name = "Zigue-Zague", Rarity = "Raro", Price = 800, Income = 10, Size = 2.6 },
	{ Id = "brisa", Name = "Brisa", Rarity = "Raro", Price = 1_500, Income = 18, Size = 2.8 },
	{ Id = "faisca", Name = "Faísca", Rarity = "Raro", Price = 3_000, Income = 32, Size = 3 },
	{ Id = "trovao", Name = "Trovão", Rarity = "Epico", Price = 9_000, Income = 80, Size = 3.2 },
	{ Id = "nebulosa", Name = "Nebulosa", Rarity = "Epico", Price = 20_000, Income = 160, Size = 3.4 },
	{ Id = "cristal", Name = "Cristalzinho", Rarity = "Epico", Price = 45_000, Income = 320, Size = 3.6 },
	{ Id = "dragaozinho", Name = "Dragãozinho", Rarity = "Lendario", Price = 150_000, Income = 900, Size = 3.8 },
	{ Id = "fenix", Name = "Fênix Bebê", Rarity = "Lendario", Price = 400_000, Income = 2_200, Size = 4 },
	{ Id = "kraken", Name = "Mini Kraken", Rarity = "Lendario", Price = 900_000, Income = 4_500, Size = 4.2 },
	{ Id = "tita", Name = "Titã Cósmico", Rarity = "Mitico", Price = 3_000_000, Income = 13_000, Size = 4.6 },
	{ Id = "leviata", Name = "Leviatã", Rarity = "Mitico", Price = 8_000_000, Income = 30_000, Size = 5 },
	{ Id = "glitch", Name = "Glitch", Rarity = "Secreto", Price = 25_000_000, Income = 90_000, Size = 5.2 },
	{ Id = "infinito", Name = "Infinito", Rarity = "Secreto", Price = 100_000_000, Income = 300_000, Size = 5.6 },
} :: { Critter }

local critterById: { [string]: Critter } = {}
for _, critter in Config.Critters do
	critterById[critter.Id] = critter
end

function Config.GetCritter(id: string): Critter?
	return critterById[id]
end

export type Mutation = { Name: string, Multiplier: number, Chance: number, Color: Color3? }

-- Chance por compra. O passe "Sortudo" dobra estas chances.
Config.Mutations = {
	Ouro = { Name = "Ouro", Multiplier = 2, Chance = 0.06, Color = Color3.fromRGB(255, 215, 0) },
	Diamante = { Name = "Diamante", Multiplier = 5, Chance = 0.01, Color = Color3.fromRGB(120, 240, 255) },
} :: { [string]: Mutation }

-------------------------------------------------------------------------------
-- BALANCEAMENTO
-------------------------------------------------------------------------------

Config.StartingCash = 100
Config.BaseSlots = 8
Config.ExtraSlotsFromPass = 4
Config.SellRefund = 0.5 -- vender devolve 50% do preço

Config.Conveyor = {
	SpawnInterval = 2.5, -- segundos entre bichos na esteira
	Speed = 9, -- studs por segundo
	Length = 320,
}

Config.Lock = {
	Duration = 60,
	SuperDuration = 120,
	Cooldown = 90, -- conta a partir do fim do cadeado
}

Config.Steal = {
	HoldDuration = 1.2, -- segurar E por X segundos para roubar
	CarrySpeed = 13,
	FastCarrySpeed = 19,
	Timeout = 60, -- se não chegar na base em X s, o bicho volta
	SlapRange = 10,
	SlapCooldown = 0.8,
	StunTime = 1.2,
}

Config.Rebirth = {
	BaseCost = 75_000,
	CostGrowth = 4,
	IncomeBonusPerRebirth = 0.5, -- +50% renda por renascimento
}

function Config.GetRebirthCost(rebirths: number): number
	return math.floor(Config.Rebirth.BaseCost * Config.Rebirth.CostGrowth ^ rebirths)
end

Config.FriendBonusPerFriend = 0.1 -- +10% renda por amigo no servidor
Config.FriendBonusMax = 0.5

Config.Offline = {
	MaxSeconds = 2 * 60 * 60, -- até 2h de ganho offline
	Rate = 0.25, -- 25% da renda normal
}

-- Prêmio diário: índice = dia da sequência (repete o último depois do 7º)
Config.DailyRewards = { 500, 1_500, 5_000, 15_000, 50_000, 150_000, 500_000 }
Config.DailyRewardScalesWithRebirth = true

Config.ServerLuckDuration = 15 * 60
Config.ServerLuckMultiplier = 2

return Config
