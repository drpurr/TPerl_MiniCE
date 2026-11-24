-- TPerl_MiniCE
-- TPerl hides the cooldown numbers on its aura icons and shows its own timer FontString (button.DurationText,
-- bound with SetDurationText). MiniCE only styles cooldown numbers, so it never touches that text. This bridge
-- applies MiniCE's Unit Frames style to TPerl's timer text instead:
--  * font, size and outline: after each of TPerl's own font passes (TPerl_ApplyAuraDurationFontSize,
--    TPerl_ApplyAuraButtonFont "duration"), so TPerl's restyles don't undo it.
--  * number format: bare seconds like cooldown numbers (TPerl's own formatter adds "s").
--  * text color: MiniCE's own duration color curve (threshold colors, or its flat text color), bound once when
--    TPerl binds the timer (TPerl_GODMODE_BindAuraDuration, during the icon's setup).
-- MiniCE setting changes: TPerl never restyles aura buttons the client has adopted. It builds fresh aura
-- containers instead (TPerl_RebuildFontAuraContainers, safe in combat), and the new buttons pick up the style
-- through the hooks above. After a MiniCE change that affects unit frame timers, this asks TPerl to do that.

local MCE = LibStub("AceAddon-3.0"):GetAddon("MinimalistCooldownEdge", true)
if (not MCE) then return end

local CATEGORY = "unitframe"

local function Config()
	local profile = MCE.db and MCE.db.profile
	local config = profile and profile.categories and profile.categories[CATEGORY]
	if (config and config.enabled) then
		return config
	end
end

local function Secret()
	return TPerl_AreAurasSecret and TPerl_AreAurasSecret()
end

-- Countdown text like the cooldown numbers MiniCE styles: whole seconds rounded up with no unit, then 2m,
-- 1h, 1d. The engine does the arithmetic, so secret durations are never read in Lua.
local formatter
local function Formatter()
	if (formatter or not C_StringUtil or not C_StringUtil.CreateNumericRuleFormatter) then
		return formatter
	end
	local up = Enum.NumericRuleFormatRounding.Up
	formatter = C_StringUtil.CreateNumericRuleFormatter()
	formatter:SetBreakpoints({
		{threshold = 0, format = "%d", step = 1, rounding = up},
		{threshold = 60, format = "%dm", step = 1, rounding = up, components = {{div = 60}}},
		{threshold = 3600, format = "%dh", step = 1, rounding = up, components = {{div = 3600}}},
		{threshold = 86400, format = "%dd", step = 1, rounding = up, components = {{div = 86400}}},
	})
	return formatter
end

-- MiniCE's size is in the icon's own units, and Blizzard's nameplate aura icons are 25 units tall
-- (NamePlateConstants.AURA_ITEM_HEIGHT). TPerl's icons are laid out at their own size (often 30+), so the same
-- number would read smaller on them. Scaling by icon height / 25 keeps the text-to-icon ratio of the nameplates.
local REFERENCE_ICON = (NamePlateConstants and NamePlateConstants.AURA_ITEM_HEIGHT) or 25

local issecretvalue = issecretvalue or function() return false end
local iconHeights = setmetatable({}, {__mode = "k"})	-- aura button -> its height while it was still readable

local function Readable(value)
	return type(value) == "number" and not issecretvalue(value) and value > 0 and value or nil
end

-- Icon height in the button's own units. Once the client's aura container adopts a button, its geometry
-- reads as a secret number, so the height is remembered from setup, then taken from the size TPerl lays
-- its aura container out at (_tperlAuraBaseSize, a plain addon value).
local function IconHeight(fontString)
	local region = fontString
	local button
	for _ = 1, 6 do
		region = region and region.GetParent and region:GetParent()
		if (not region) then
			break
		end
		if (not button and type(region.SetDurationCooldown) == "function") then
			button = region
			local height = Readable(region:GetHeight())
			if (height) then
				iconHeights[button] = height
				return height
			end
			if (iconHeights[button]) then
				return iconHeights[button]
			end
		elseif (button) then
			local base = Readable(region._tperlAuraBaseSize)
			if (base) then
				return base
			end
		end
	end
	return REFERENCE_ICON
end

local function ApplyFont(fontString)
	local config = Config()
	if (not config or not fontString or not fontString.SetFont or Secret()) then
		return
	end
	if (fontString.IsForbidden and fontString:IsForbidden()) then
		return
	end
	local path = MCE.ResolveFontPath(config.font)
	local size = (tonumber(config.fontSize) or 18) * IconHeight(fontString) / REFERENCE_ICON
	local flags = MCE.NormalizeFontStyle(config.fontStyle)
	if (not fontString:SetFont(path, size, flags)) then
		fontString:SetFont(STANDARD_TEXT_FONT, size, flags)
	end
end

local function BindColor(button)
	local config = Config()
	local text = button and button.DurationText
	if (not config or not text or not button.SetDurationText or Secret()) then
		return
	end
	local colors = MCE:GetModule("DurationColorController", true)
	local curve = colors and colors:GetDurationTextCurve(CATEGORY, config)
	if (not curve) then
		return
	end
	button:SetDurationText(text, {
		textFormatter = Formatter() or (TPerl_GetAuraDurationFormatter and TPerl_GetAuraDurationFormatter()),
		textColor = {curve = curve, property = Enum.DurationTextBindingProperty.RemainingDuration},
	})
	ApplyFont(text)
	-- Rebinding can show the text again; TPerl's saved on/off state stays in charge
	if (TPerl_PrimeAuraButtonDurationVisible and button._tperlDurationConfigured) then
		TPerl_PrimeAuraButtonDurationVisible(button, button._tperlDurationVisible)
	end
end

local function Hook(name, func)
	if (type(_G[name]) == "function") then
		hooksecurefunc(name, func)
		return true
	end
	print("|cFF00CCFFTPerl MiniCE Bridge:|r "..name.." not found; TPerl may have changed.")
end

Hook("TPerl_ApplyAuraDurationFontSize", function(fontString)
	ApplyFont(fontString)
end)
Hook("TPerl_ApplyAuraButtonFont", function(button, _, key)
	if (key == "duration" and button) then
		ApplyFont(button.DurationText)
	end
end)
Hook("TPerl_GODMODE_BindAuraDuration", function(button)
	BindColor(button)
end)

-- Everything above reads from these settings; rebuild only when one of them changed.
local function Signature()
	local profile = MCE.db and MCE.db.profile
	if (not profile) then
		return ""
	end
	local parts = {}
	local function Add(value)
		if (type(value) == "table") then
			local keys = {}
			for key in pairs(value) do
				keys[#keys + 1] = tostring(key)
			end
			table.sort(keys)
			for _, key in ipairs(keys) do
				parts[#parts + 1] = key
				Add(value[key] ~= nil and value[key] or value[tonumber(key)])
			end
		else
			parts[#parts + 1] = tostring(value)
		end
	end
	Add(profile.categories and profile.categories[CATEGORY])
	Add(profile.durationTextColors)
	return table.concat(parts, "|")
end

local lastSignature
local rebuildTimer
local function RebuildTPerlAuras()
	rebuildTimer = nil
	local signature = Signature()
	if (signature == lastSignature) then
		return
	end
	lastSignature = signature
	if (type(TPerl_RebuildFontAuraContainers) == "function") then
		TPerl_RebuildFontAuraContainers()
	end
end

-- MiniCE runs ForceUpdateAll after every option change (sliders included), so wait for changes to settle.
hooksecurefunc(MCE, "ForceUpdateAll", function()
	if (rebuildTimer) then
		rebuildTimer:Cancel()
	end
	rebuildTimer = C_Timer.NewTimer(0.5, RebuildTPerlAuras)
end)

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function()
	lastSignature = Signature()
end)
