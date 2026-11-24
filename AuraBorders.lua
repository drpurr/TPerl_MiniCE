-- Gives TPerl's aura icons the nameplate aura look (Blizzard_NamePlateAuras.xml):
-- rounded icon mask, the Cooldown Manager icon frame, and the rounded swipe.
-- TPerl's own gray border and its dispel-colored (blue for Magic) border are
-- removed, as nameplate auras have no dispel coloring.
--
-- All of this runs while TPerl initializes each button, before the aura
-- container adopts it, so button geometry is still readable.
local MASK_ATLAS = "UI-HUD-CoolDownManager-Mask"
local FRAME_ATLAS = "UI-HUD-CoolDownManager-IconOverlay"
local SWIPE_TEXTURE = "Interface\\HUD\\UI-HUD-CoolDownManager-Icon-Swipe"

-- Nameplate items are 25x25 with the frame anchored 6px out on each side and
-- 5px out top and bottom; keep those proportions at TPerl's icon size.
local REFERENCE_SIZE = 25
local FRAME_X, FRAME_Y = 6, 5

local issecretvalue = issecretvalue or function() return false end
local styled = setmetatable({}, { __mode = "k" })

local function ReadableSize(button)
	local width = button:GetWidth()
	if type(width) == "number" and not issecretvalue(width) and width > 0 then
		return width
	end
	return REFERENCE_SIZE
end

local function StyleIcon(button, icon)
	if not icon or icon._tperlNameplateMask then return end
	local mask = button:CreateMaskTexture()
	mask:SetAtlas(MASK_ATLAS)
	mask:SetAllPoints(icon)
	icon:AddMaskTexture(mask)
	icon._tperlNameplateMask = mask
end

local function StyleCooldown(cooldown)
	if cooldown and cooldown.SetSwipeTexture then
		cooldown:SetSwipeTexture(SWIPE_TEXTURE)
	end
end

local function HideTPerlBorders(button)
	if button._tperlNeutralAuraBorder then
		button._tperlNeutralAuraBorder:Hide()
	end
	local border = button._tperlDispelBorder
	if border then
		if button.RemoveDispelTypeTexture then
			button:RemoveDispelTypeTexture(border)
		end
		border:Hide()
	end
end

local function AddFrame(button)
	-- TPerl's border frame sits above the cooldown swipe; reuse it so the
	-- frame draws over the swipe like on nameplates.
	local parent = button._tperlAuraBorderFrame or button
	local scale = ReadableSize(button) / REFERENCE_SIZE
	local frame = parent:CreateTexture(nil, "OVERLAY")
	frame:SetAtlas(FRAME_ATLAS)
	frame:SetPoint("TOPLEFT", button, "TOPLEFT", -FRAME_X * scale, FRAME_Y * scale)
	frame:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", FRAME_X * scale, -FRAME_Y * scale)
	button._tperlNameplateFrame = frame
end

local function Restyle(button, fullSurface)
	-- fullSurface = TPerl's party/player frame dispel highlight, not an icon.
	if fullSurface or not button or styled[button] then return end
	styled[button] = true

	HideTPerlBorders(button)
	AddFrame(button)

	-- Some TPerl frames create the icon and cooldown after the border, some
	-- before; cover both.
	StyleIcon(button, button.Icon)
	StyleCooldown(button.Cooldown)
	if button.SetIcon then
		hooksecurefunc(button, "SetIcon", function(self, icon) StyleIcon(self, icon) end)
	end
	if button.SetDurationCooldown then
		hooksecurefunc(button, "SetDurationCooldown", function(_, cooldown) StyleCooldown(cooldown) end)
	end
end

if TPerl_SetupAuraDispelBorder then
	hooksecurefunc("TPerl_SetupAuraDispelBorder", Restyle)
end
