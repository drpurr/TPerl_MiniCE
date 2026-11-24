-- Hides chosen buffs from TPerl's player buff row using the aura container's
-- own excludeSpellIDs candidate filter (Blizzard_AuraContainerUtil.lua). Helpful
-- auras on the player are always filterable this way, in or out of combat.
local HIDDEN_PLAYER_BUFFS = {
	[2580] = true, -- Find Minerals
}

local conf
if TPerl_RequestConfig then
	TPerl_RequestConfig(function(new) conf = new end)
end

local function Apply()
	local player = TPerl_Player
	local container = player and player.buffFrame
	if not (container and container.HasAuraGroup and container:HasAuraGroup("buff")) then return end
	-- Same rule TPerl uses: leave a live group alone while auras are secret.
	if TPerl_AreAurasSecret and TPerl_AreAurasSecret() then return end

	-- Keep TPerl's own "only mine" filter alongside the exclusion.
	local filters = { excludeSpellIDs = HIDDEN_PLAYER_BUFFS }
	local buffs = conf and conf.player and conf.player.buffs
	if buffs and buffs.onlyMine then
		filters.isFromPlayerOrPlayerPet = true
	end
	container:SetAuraGroupCandidateFilters("buff", filters)
end

-- TPerl (re)configures the player buff group, and rebuilds its container,
-- through TPerl_Player_Buffs_Position; re-apply the exclusion after each run.
local function HookPlayerBuffs()
	if not TPerl_Player_Buffs_Position then return false end
	hooksecurefunc("TPerl_Player_Buffs_Position", Apply)
	Apply()
	return true
end

if not HookPlayerBuffs() then
	local watcher = CreateFrame("Frame")
	watcher:RegisterEvent("ADDON_LOADED")
	watcher:SetScript("OnEvent", function(self, _, name)
		if name == "TPerl_PlayerBuffs" and HookPlayerBuffs() then
			self:UnregisterEvent("ADDON_LOADED")
		end
	end)
end
