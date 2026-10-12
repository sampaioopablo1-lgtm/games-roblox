--!strict
-- Formata números grandes: 1500 -> 1.5K, 2300000 -> 2.3M

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Format.Number(value: number): string
	if value ~= value then
		return "0"
	end
	local negative = value < 0
	value = math.abs(value)
	local index = 1
	while value >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end
	local text
	if index == 1 then
		text = tostring(math.floor(value))
	elseif value >= 100 then
		text = string.format("%d", math.floor(value))
	else
		text = (string.format("%.1f", math.floor(value * 10) / 10):gsub("%.0$", ""))
	end
	return (negative and "-" or "") .. text .. SUFFIXES[index]
end

function Format.Cash(value: number): string
	return "$" .. Format.Number(value)
end

function Format.Time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	local secs = seconds % 60
	if hours > 0 then
		return string.format("%dh%02dm", hours, minutes)
	elseif minutes > 0 then
		return string.format("%dm%02ds", minutes, secs)
	end
	return string.format("%ds", secs)
end

return Format
