-- FormatNumber.lua
-- Utility for display-friendly number formatting: 1K, 2.3M, etc.
local FormatNumber = {}

function FormatNumber.Format(value)
	if value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	elseif value >= 1000 then
		return string.format("%.1fK", value / 1000)
	end
	return tostring(value)
end

return FormatNumber