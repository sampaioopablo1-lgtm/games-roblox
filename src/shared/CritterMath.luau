--!strict
-- Cálculos de renda compartilhados por servidor e cliente.

local Config = require(script.Parent.Config)

local CritterMath = {}

function CritterMath.BaseIncome(critterId: string, mutation: string?): number
	local critter = Config.GetCritter(critterId)
	if not critter then
		return 0
	end
	local mutationInfo = mutation and Config.Mutations[mutation]
	return critter.Income * (if mutationInfo then mutationInfo.Multiplier else 1)
end

function CritterMath.SellValue(critterId: string, mutation: string?): number
	local critter = Config.GetCritter(critterId)
	if not critter then
		return 0
	end
	local mutationInfo = mutation and Config.Mutations[mutation]
	return math.floor(critter.Price * Config.SellRefund * (if mutationInfo then mutationInfo.Multiplier else 1))
end

function CritterMath.DisplayName(critterId: string, mutation: string?): string
	local critter = Config.GetCritter(critterId)
	local name = if critter then critter.Name else critterId
	return if mutation then name .. " " .. mutation else name
end

return CritterMath
