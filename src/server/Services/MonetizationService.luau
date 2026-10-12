--!strict
-- Game Passes (compra única) e Developer Products (compras repetíveis).
-- ProcessReceipt é idempotente: cada recibo é concedido no máximo uma vez.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local DataService = require(script.Parent.DataService)

local MonetizationService = {}

type ProductHandler = (player: Player, profile: DataService.Profile) -> boolean

local passIdByKey: { [string]: number } = {}
local passKeyById: { [number]: string } = {}
for _, pass in Config.GamePasses do
	if pass.Id ~= 0 then
		passIdByKey[pass.Key] = pass.Id
		passKeyById[pass.Id] = pass.Key
	end
end

local productKeyById: { [number]: string } = {}
for _, product in Config.Products do
	if product.Id ~= 0 then
		productKeyById[product.Id] = product.Key
	end
end

local handlers: { [string]: ProductHandler } = {}
local passCallbacks: { (Player, string) -> () } = {}

-- Cache de passes: atributo "Pass_<Key>" no jogador (o cliente também lê).
local function refreshPasses(player: Player)
	for passKey, passId in passIdByKey do
		local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
		if ok and owns then
			player:SetAttribute("Pass_" .. passKey, true)
		end
	end
end

function MonetizationService.HasPass(player: Player, passKey: string): boolean
	return player:GetAttribute("Pass_" .. passKey) == true
end

function MonetizationService.OnPassGranted(callback: (Player, string) -> ())
	table.insert(passCallbacks, callback)
end

function MonetizationService.RegisterProduct(productKey: string, handler: ProductHandler)
	handlers[productKey] = handler
end

local function processReceipt(receiptInfo): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = DataService.Get(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receiptInfo.PurchaseId)
	if DataService.HasReceipt(profile, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local productKey = productKeyById[receiptInfo.ProductId]
	local handler = productKey and handlers[productKey]
	if not handler then
		warn("[Monetization] Produto sem handler:", receiptInfo.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, granted = pcall(handler, player, profile)
	if not ok or not granted then
		warn("[Monetization] Falha ao conceder", productKey, granted)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	DataService.AddReceipt(profile, purchaseId)
	profile.TotalSpentRobux += receiptInfo.CurrencySpent or 0
	DataService.Save(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.Init()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local passKey = passKeyById[passId]
		if purchased and passKey then
			player:SetAttribute("Pass_" .. passKey, true)
			for _, callback in passCallbacks do
				task.spawn(callback, player, passKey)
			end
		end
	end)

	Players.PlayerAdded:Connect(refreshPasses)
	for _, player in Players:GetPlayers() do
		task.spawn(refreshPasses, player)
	end
end

return MonetizationService
