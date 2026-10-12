--!strict
-- HUD do jogador: dinheiro, renda, renascimento, prêmio diário, loja de Robux
-- e notificações. Toda a UI é criada por código (sem assets externos).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT = Enum.Font.FredokaOne
local COLORS = {
	Panel = Color3.fromRGB(30, 32, 48),
	Accent = Color3.fromRGB(255, 196, 0),
	Green = Color3.fromRGB(70, 210, 110),
	Red = Color3.fromRGB(235, 80, 90),
	Blue = Color3.fromRGB(80, 150, 255),
	Purple = Color3.fromRGB(170, 90, 255),
	Text = Color3.new(1, 1, 1),
}

local screen = Instance.new("ScreenGui")
screen.Name = "HUD"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.Parent = playerGui

-------------------------------------------------------------------------------
-- helpers de UI
-------------------------------------------------------------------------------

local function corner(parent: GuiObject, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 12)
	c.Parent = parent
end

local function stroke(parent: GuiObject, color: Color3, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 2
	s.Parent = parent
end

local function label(parent: Instance, text: string, size: UDim2, position: UDim2, textSize: number?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.Font = FONT
	l.Text = text
	l.TextColor3 = COLORS.Text
	l.TextScaled = textSize == nil
	if textSize then
		l.TextSize = textSize
	end
	l.TextStrokeTransparency = 0.6
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, color: Color3, size: UDim2, position: UDim2): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = position
	b.BackgroundColor3 = color
	b.Font = FONT
	b.Text = text
	b.TextColor3 = COLORS.Text
	b.TextScaled = true
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b)
	stroke(b, Color3.new(0, 0, 0), 2)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = b
	-- animação de clique
	b.MouseButton1Down:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.08), { Size = size - UDim2.fromOffset(6, 6) }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.08), { Size = size }):Play()
	end)
	return b
end

local function panel(size: UDim2, position: UDim2, anchor: Vector2?): Frame
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = position
	f.AnchorPoint = anchor or Vector2.zero
	f.BackgroundColor3 = COLORS.Panel
	f.BackgroundTransparency = 0.1
	f.Parent = screen
	corner(f, 16)
	stroke(f, Color3.fromRGB(70, 75, 110), 2)
	return f
end

local function play(soundId: string, pitch: number?)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = 0.6
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

local SOUND_CASH = "rbxassetid://9125644905" -- moeda (biblioteca Roblox)
local SOUND_RARE = "rbxassetid://9125897093"
local SOUND_ERROR = "rbxassetid://9125390707"

-------------------------------------------------------------------------------
-- Topo: dinheiro + renda
-------------------------------------------------------------------------------

local top = panel(UDim2.fromOffset(300, 86), UDim2.new(0.5, 0, 0, 12), Vector2.new(0.5, 0))
local cashLabel = label(top, "$0", UDim2.new(1, -20, 0.55, 0), UDim2.fromOffset(10, 4))
cashLabel.TextColor3 = COLORS.Green
local incomeLabel = label(top, "$0/s", UDim2.new(1, -20, 0.35, 0), UDim2.new(0, 10, 0.58, 0))
incomeLabel.TextColor3 = Color3.fromRGB(200, 200, 220)

local function pulse(gui: GuiObject)
	local original = gui.Size
	TweenService:Create(gui, TweenInfo.new(0.1), { Size = original + UDim2.fromOffset(12, 12) }):Play()
	task.delay(0.1, function()
		TweenService:Create(gui, TweenInfo.new(0.15), { Size = original }):Play()
	end)
end

local lastCash = 0
local function refreshTop()
	local cash = (player:GetAttribute("Cash") :: number?) or 0
	local income = (player:GetAttribute("IncomePerSecond") :: number?) or 0
	local rebirths = (player:GetAttribute("Rebirths") :: number?) or 0
	cashLabel.Text = Format.Cash(cash)
	local bonus = ""
	if rebirths > 0 then
		bonus = ("  (🔁 %d)"):format(rebirths)
	end
	incomeLabel.Text = Format.Cash(income) .. "/s" .. bonus
	if cash > lastCash + 1 then
		pulse(top)
	end
	lastCash = cash
end
player:GetAttributeChangedSignal("Cash"):Connect(refreshTop)
player:GetAttributeChangedSignal("IncomePerSecond"):Connect(refreshTop)
player:GetAttributeChangedSignal("Rebirths"):Connect(refreshTop)

-------------------------------------------------------------------------------
-- Dica de controles / status de carregar bicho
-------------------------------------------------------------------------------

local hint = label(screen, "", UDim2.new(0.6, 0, 0, 34), UDim2.new(0.5, 0, 0, 104), 20)
hint.AnchorPoint = Vector2.new(0.5, 0)
hint.TextColor3 = COLORS.Accent

local function refreshHint()
	local carrying = player:GetAttribute("Carrying") :: string?
	if carrying then
		hint.Text = "😈 Carregando " .. carrying .. " — corra para a SUA base!"
		hint.TextColor3 = COLORS.Red
	else
		hint.Text = "Esteira: compre bichos • E = pegar dos outros • F = vender • Tapa = defender"
		hint.TextColor3 = COLORS.Accent
	end
end
player:GetAttributeChangedSignal("Carrying"):Connect(refreshHint)
refreshHint()

-------------------------------------------------------------------------------
-- Botões laterais (esquerda)
-------------------------------------------------------------------------------

local side = Instance.new("Frame")
side.BackgroundTransparency = 1
side.Size = UDim2.fromOffset(150, 300)
side.Position = UDim2.new(0, 12, 0.5, 0)
side.AnchorPoint = Vector2.new(0, 0.5)
side.Parent = screen
local sideLayout = Instance.new("UIListLayout")
sideLayout.Padding = UDim.new(0, 10)
sideLayout.Parent = side

local BTN = UDim2.new(1, 0, 0, 56)
local shopButton = button(side, "🛒 Loja", COLORS.Purple, BTN, UDim2.new())
local rebirthButton = button(side, "🔁 Renascer", COLORS.Blue, BTN, UDim2.new())
local dailyButton = button(side, "🎁 Diário", COLORS.Green, BTN, UDim2.new())
local codesInfo = button(side, "👥 +Amigos", COLORS.Accent, BTN, UDim2.new())
codesInfo.TextColor3 = Color3.fromRGB(40, 30, 0)

-------------------------------------------------------------------------------
-- Notificações
-------------------------------------------------------------------------------

local toastHolder = Instance.new("Frame")
toastHolder.BackgroundTransparency = 1
toastHolder.Size = UDim2.fromOffset(360, 400)
toastHolder.Position = UDim2.new(1, -12, 0, 100)
toastHolder.AnchorPoint = Vector2.new(1, 0)
toastHolder.Parent = screen
local toastLayout = Instance.new("UIListLayout")
toastLayout.Padding = UDim.new(0, 6)
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
toastLayout.Parent = toastHolder

local function toast(text: string, kind: string)
	local color = if kind == "cash" then COLORS.Green elseif kind == "error" then COLORS.Red elseif kind == "rare" then COLORS.Purple else COLORS.Panel
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 44)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 1
	frame.Parent = toastHolder
	corner(frame)
	stroke(frame, Color3.new(0, 0, 0), 1.5)
	local l = label(frame, text, UDim2.new(1, -16, 1, -8), UDim2.fromOffset(8, 4), 18)
	l.TextWrapped = true
	l.TextTransparency = 1
	TweenService:Create(frame, TweenInfo.new(0.2), { BackgroundTransparency = 0.1 }):Play()
	TweenService:Create(l, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
	if kind == "cash" then
		play(SOUND_CASH, 1 + math.random() * 0.2)
	elseif kind == "rare" then
		play(SOUND_RARE)
	elseif kind == "error" then
		play(SOUND_ERROR)
	end
	task.delay(4, function()
		TweenService:Create(frame, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(l, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.wait(0.4)
		frame:Destroy()
	end)
end
Remotes.Notify.OnClientEvent:Connect(toast)

-------------------------------------------------------------------------------
-- Loja de Robux
-------------------------------------------------------------------------------

local shop = panel(UDim2.fromOffset(620, 460), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
shop.Visible = false
label(shop, "🛒 LOJA", UDim2.new(1, 0, 0, 44), UDim2.fromOffset(0, 8)).TextColor3 = COLORS.Accent
local closeShop = button(shop, "X", COLORS.Red, UDim2.fromOffset(40, 40), UDim2.new(1, -50, 0, 10))

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -24, 1, -70)
list.Position = UDim2.fromOffset(12, 60)
list.BackgroundTransparency = 1
list.ScrollBarThickness = 6
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = shop
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(285, 110)
grid.CellPadding = UDim2.fromOffset(10, 10)
grid.Parent = list

local function shopCard(title: string, description: string, price: number, owned: boolean, color: Color3, onClick: () -> ())
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Color3.fromRGB(45, 48, 70)
	card.Parent = list
	corner(card)
	stroke(card, color, 2)
	label(card, title, UDim2.new(1, -16, 0, 30), UDim2.fromOffset(8, 6)).TextXAlignment = Enum.TextXAlignment.Left
	local desc = label(card, description, UDim2.new(1, -16, 0, 34), UDim2.fromOffset(8, 36), 14)
	desc.TextWrapped = true
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextColor3 = Color3.fromRGB(200, 200, 220)
	local buy = button(card, if owned then "✅ Adquirido" else ("🟢 " .. price .. " R$"), if owned then Color3.fromRGB(90, 90, 110) else color, UDim2.new(1, -16, 0, 30), UDim2.new(0, 8, 1, -36))
	if not owned then
		buy.MouseButton1Click:Connect(onClick)
	end
end

local function rebuildShop()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for _, pass in Config.GamePasses do
		if pass.Id ~= 0 then
			local owned = player:GetAttribute("Pass_" .. pass.Key) == true
			shopCard("⭐ " .. pass.Name, pass.Description, pass.SuggestedPrice, owned, COLORS.Accent, function()
				MarketplaceService:PromptGamePassPurchase(player, pass.Id)
			end)
		end
	end
	for _, product in Config.Products do
		if product.Id ~= 0 then
			shopCard("💎 " .. product.Name, product.Description, product.SuggestedPrice, false, COLORS.Purple, function()
				MarketplaceService:PromptProductPurchase(player, product.Id)
			end)
		end
	end
	if #list:GetChildren() <= 1 then
		local l = label(list, "Nenhum item configurado.\nDefina os IDs em Shared/Config.luau", UDim2.fromOffset(580, 100), UDim2.new(), 20)
		l.TextWrapped = true
	end
end

shopButton.MouseButton1Click:Connect(function()
	rebuildShop()
	shop.Visible = not shop.Visible
end)
closeShop.MouseButton1Click:Connect(function()
	shop.Visible = false
end)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(_, _, purchased)
	if purchased then
		task.delay(0.5, rebuildShop)
	end
end)

-------------------------------------------------------------------------------
-- Renascer / Diário / Amigos
-------------------------------------------------------------------------------

local function confirm(title: string, body: string, onYes: () -> ())
	local dialog = panel(UDim2.fromOffset(420, 220), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	label(dialog, title, UDim2.new(1, -20, 0, 44), UDim2.fromOffset(10, 10)).TextColor3 = COLORS.Accent
	local b = label(dialog, body, UDim2.new(1, -20, 0, 80), UDim2.fromOffset(10, 60), 18)
	b.TextWrapped = true
	local yes = button(dialog, "Sim!", COLORS.Green, UDim2.fromOffset(180, 48), UDim2.new(0, 16, 1, -60))
	local no = button(dialog, "Agora não", COLORS.Red, UDim2.fromOffset(180, 48), UDim2.new(1, -196, 1, -60))
	yes.MouseButton1Click:Connect(function()
		dialog:Destroy()
		onYes()
	end)
	no.MouseButton1Click:Connect(function()
		dialog:Destroy()
	end)
end

local function refreshRebirthButton()
	local rebirths = (player:GetAttribute("Rebirths") :: number?) or 0
	rebirthButton.Text = "🔁 Renascer\n" .. Format.Cash(Config.GetRebirthCost(rebirths))
end
player:GetAttributeChangedSignal("Rebirths"):Connect(refreshRebirthButton)
refreshRebirthButton()

rebirthButton.MouseButton1Click:Connect(function()
	local rebirths = (player:GetAttribute("Rebirths") :: number?) or 0
	local bonus = math.floor((rebirths + 1) * Config.Rebirth.IncomeBonusPerRebirth * 100)
	confirm("🔁 Renascer?", ("Custa %s. Você perde dinheiro e bichos, mas ganha +%d%% de renda PARA SEMPRE."):format(Format.Cash(Config.GetRebirthCost(rebirths)), bonus), function()
		local ok, message = Remotes.Rebirth:InvokeServer()
		toast(message, if ok then "rare" else "error")
	end)
end)

local function refreshDaily()
	local last = (player:GetAttribute("LastDaily") :: number?) or 0
	local remaining = last + 86400 - os.time()
	dailyButton.Text = if remaining > 0 then "🎁 " .. Format.Time(remaining) else "🎁 Diário!"
end
task.spawn(function()
	while true do
		refreshDaily()
		task.wait(1)
	end
end)
dailyButton.MouseButton1Click:Connect(function()
	local ok, message = Remotes.ClaimDaily:InvokeServer()
	toast(message, if ok then "cash" else "error")
end)

codesInfo.MouseButton1Click:Connect(function()
	local friends = (player:GetAttribute("FriendsInServer") :: number?) or 0
	toast(("Amigos no servidor: %d → +%d%% de renda (máx. +%d%%). Convide amigos!"):format(
		friends,
		math.min(friends * Config.FriendBonusPerFriend, Config.FriendBonusMax) * 100,
		Config.FriendBonusMax * 100
	), "info")
end)

refreshTop()
