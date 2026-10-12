--!strict
-- Ponto de entrada do servidor. A ordem importa: dados → monetização → mundo → resto.

local Services = script.Parent.Services

local DataService = require(Services.DataService)
local MonetizationService = require(Services.MonetizationService)
local WorldService = require(Services.WorldService)
local EconomyService = require(Services.EconomyService)
local BaseService = require(Services.BaseService)
local ConveyorService = require(Services.ConveyorService)
local StealService = require(Services.StealService)

WorldService.Init()
MonetizationService.Init()
EconomyService.Init()
BaseService.Init()
ConveyorService.Init()
StealService.Init()
DataService.Init() -- por último: dispara OnLoaded para quem já estiver conectado

print("[Pega Bichos] Servidor pronto.")
