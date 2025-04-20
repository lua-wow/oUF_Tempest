--[[
# Element: Tempest Bar

Handles the visibility and updating of the shaman enhancement tempest bar.

## Widget

Tempest - A `StatusBar` used to represent the number of stacks of Maelstorm Weapon you current have and how many left to proc Tempest skill.

## Sub-Widgets

.bg - A `Texture` used as a background. It will inherit the color of the main StatusBar.

## Notes

A default texture will be applied if the widget is a StatusBar and doesn't have a texture set.

## Sub-Widgets Options

.multiplier - Used to tint the background based on the main widgets R, G and B values. Defaults to 1 (number)[0-1]

## Examples

    local Tempest = CreateFrame("StatusBar", nil, self)
    Tempest:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, 0)
    Tempest:SetSize(120, 20)

    -- Register with oUF
    self.Tempest = Tempest
--]]

local _, ns = ...
local oUF = ns.oUF

-- Blizzard
local UnitClass = _G.UnitClass
local UnitGUID = _G.UnitGUID
local IsSpellKnown = _G.IsSpellKnown
local IsPlayerSpell = _G.IsPlayerSpell

-- Mine
local _, class = UnitClass("player")
if (class ~= "SHAMAN") then return end

local SPEC_SHAMAN_ENHANCEMENT = _G.SPEC_SHAMAN_ENHANCEMENT or 2

local Talents = {
	Tempest = 454009,
	-- AwakeningStorms = 455130
}

local Auras = {
	AwakeningStorms = 462131,
	MaelstromWeapon = 344179,
	Tempest = 454015
}

local Spells = {
	ChainHeal = 1064,
	HealingSurge = 8004,
	LavaBurst = 51505,
	ElementalBlast = 117014,
	LightningBolt = 188196,
	ChainLightning = 188443,
	Tempest = 452201,
	PrimordialStorm = 1218090
}

local Spenders = {
	[Spells.ChainHeal] = true, -- Chain Heal
	[Spells.HealingSurge] = true, -- Healing Surge
	[Spells.LavaBurst] = true, -- Lava Burst
	[Spells.ElementalBlast] = true, -- Elemental Blast
	[Spells.LightningBolt] = true, -- Lightning Bolt
	[Spells.ChainLightning] = true, -- Chain Lightning
	[Spells.Tempest] = true, -- Tempest
	[Spells.PrimordialStorm] = true, -- Primordial Storm
}

local CombatEvents = {
	["SPELL_AURA_APPLIED"] = true,			-- auraType, amount
	["SPELL_AURA_APPLIED_DOSE"] = true,		-- auraType, amount
	["SPELL_AURA_REMOVED"] = true,			-- auraType, amount
	["SPELL_AURA_REMOVED_DOSE"] = true,		-- auraType, amount
	["SPELL_AURA_REFRESH"] = true,			-- auraType, #amount (amount is missing)
	["SPELL_CAST_SUCCESS"] = true,
}

local function UpdateColor(self, event, unit)
	if (unit and unit ~= self.unit) then return end

	local element = self.Tempest

	local color = self.colors.power[Enum.PowerType.Maelstrom or 11]
	if color then
        element:SetStatusBarColor(color.r, color.g, color.b)

        local bg = element.bg
        if bg then
            local mu = bg.multiplier or 1
            bg:SetVertexColor(color.r * mu, color.g * mu, color.b * mu)
        end
	end

	--[[ Callback: Tempest:PostUpdateColor(r, g, b)
	Called after the element color has been updated.

	* self - the Tempest element
	* r    - the red component of the used color (number)[0-1]
	* g    - the green component of the used color (number)[0-1]
	* b    - the blue component of the used color (number)[0-1]
	--]]
	if element.PostUpdateColor then
		element:PostUpdateColor(color)
	end
end

local function ScanAuras(self, event, unit, ...)
	print("ScanAuras", self, event, unit, ...)
	if (unit ~= self.unit) then return end

	local element = self.Tempest
	if not element then return end
	
	local asInfo = C_UnitAuras.GetPlayerAuraBySpellID(Auras.AwakeningStorms)
	element.awakeningStacks = asInfo and asInfo.applications or 0

	-- https://www.wowhead.com/spell=344179/maelstrom-weapon
	local mwInfo = C_UnitAuras.GetPlayerAuraBySpellID(Auras.MaelstromWeapon)
	element.maelstromStacks = mwInfo and mwInfo.applications or 0
	
	-- https://www.wowhead.com/spell=454015/tempest
	local tempestInfo = C_UnitAuras.GetPlayerAuraBySpellID(Auras.Tempest)
	element.tempestStacks = tempestInfo and tempestInfo.applications or 0
	element.tempestDuration = tempestInfo and tempestInfo.duration or 0
	element.tempestExpirationTime = tempestInfo and tempestInfo.expirationTime or 0
	element.tempestReady = (element.tempestStacks > 0)
end

local function Update(self, event, unit, ...)
	local element = self.Tempest

	if (event == "COMBAT_LOG_EVENT_UNFILTERED") then
		local _, subevent, _, sourceGUID, _, _, _, destGUID, destName, _, _, spellID, spellName, _, auraType, amount = CombatLogGetCurrentEventInfo()
		
		-- ignore unwanted subevents
		if not CombatEvents[subevent] then return end

		-- ignore subevents from other units
		if (sourceGUID and sourceGUID ~= element.guid) then return end
		
		local changed = false
		if subevent == "SPELL_CAST_SUCCESS" then
			if Spenders[spellID] then
				if element.maelstromStacks > 0 then
					element.maelstromSpentTotal = element.maelstromSpentTotal + element.maelstromStacks
					if element.maelstromSpentTotal >= element.threshold then
						element.maelstromSpentTotal = math.max(0, element.maelstromSpentTotal - element.threshold)
					end
					element.maelstromStacks = 0
				end
			else
				return
			end
		elseif subevent == "SPELL_AURA_APPLIED" then
			if spellID == Auras.MaelstromWeapon then
				element.maelstromStacks = amount or 1
			elseif spellID == Auras.AwakeningStorms then
				element.awakeningStacks = amount or 1
			elseif spellID == Auras.Tempest then
				element.tempestStacks = amount or 1
				changed = true
			else
				return
			end
		elseif subevent == "SPELL_AURA_REMOVED" then
			if spellID == Auras.MaelstromWeapon then
				element.maelstromStacks = 0
			elseif spellID == Auras.AwakeningStorms then
				element.awakeningStacks = 0
			elseif spellID == Auras.Tempest then
				element.tempestStacks = 0
				changed = true
			else
				return
			end
		elseif subevent == "SPELL_AURA_REFRESH" then
			if spellID == Auras.MaelstromWeapon then
				element.maelstromStacks = amount or element.maelstromStacks
			elseif spellID == Auras.AwakeningStorms then
				element.awakeningStacks = amount or element.awakeningStacks
			elseif spellID == Auras.Tempest then
				element.tempestStacks = amount or element.tempestStacks
				changed = true
			else
				return
			end
		elseif subevent == "SPELL_AURA_APPLIED_DOSE" then
			if spellID == Auras.MaelstromWeapon then
				element.maelstromStacks = amount or element.maelstromStacks
			elseif spellID == Auras.AwakeningStorms then
				element.awakeningStacks = amount or element.awakeningStacks
			elseif spellID == Auras.Tempest then
				element.tempestStacks = amount or element.tempestStacks
				changed = true
			else
				return
			end
		elseif subevent == "SPELL_AURA_REMOVED_DOSE" then
			if spellID == Auras.MaelstromWeapon then
				element.maelstromStacks = amount or math.max(0, element.maelstromStacks - 1)
			elseif spellID == Auras.AwakeningStorms then
				element.awakeningStacks = amount or math.max(0, element.awakeningStacks - 1)
			elseif spellID == Auras.Tempest then
				element.tempestStacks = amount or math.max(0, element.tempestStacks - 1)
				changed = true
			else
				return
			end
		end

		if changed then
			local tempestInfo = C_UnitAuras.GetPlayerAuraBySpellID(Auras.Tempest)
			element.tempestDuration = tempestInfo and tempestInfo.duration or 0
			element.tempestExpirationTime = tempestInfo and tempestInfo.expirationTime or 0
		end
	elseif (unit == self.unit) then
		ScanAuras(self, event, unit, ...)
	else
		return
	end

	element.tempestReady = (element.tempestStacks > 0)

	--[[ Callback: Tempest:PreUpdate()
	Called before the element has been updated.

	* self - the Tempest element
	--]]
	if element.PreUpdate then
		element:PreUpdate()
	end

	element:SetMinMaxValues(0, element.max)
	element:SetValue(element.maelstromStacks)

	--[[ Callback: Tempest:PostUpdate(cur, max)
	Called after the element has been updated.

	* self - the Tempest element
	--]]
	if element.PostUpdate then
		element:PostUpdate()
	end
end

local function Path(self, ...)
	--[[ Override: Tempest.Override(self, event, unit)
	Used to completely override the internal update function.

	* self  - the parent object
	* event - the event triggering the update (string)
	* unit  - the unit accompanying the event (string)
	--]]
	(self.Tempest.Override or Update)(self, ...);

	--[[ Override: Tempest.UpdateColor(self, event, unit)
	Used to completely override the internal function for updating the widgets' colors.

	* self  - the parent object
	* event - the event triggering the update (string)
	* unit  - the unit accompanying the event (string)
	--]]
	(self.Tempest.UpdateColor or UpdateColor) (self, ...)
end

local function Visibility(self, event, unit)
    local element = self.Tempest
    
	local spec = GetSpecialization()
	local visible = (spec == SPEC_SHAMAN_ENHANCEMENT and not UnitHasVehiclePlayerFrameUI("player") and IsPlayerSpell(Talents.Tempest))
	
	element.__visible = visible

	if visible then
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", Path, true)
		if not element:IsShown() then
			element:Show()
		end
		Path(self, event, unit)
	else
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED", Path)
		if element:IsShown() then
			element:Hide()
		end
	end
end

local function VisibilityPath(self, ...)
	--[[ Override: Tempest.OverrideVisibility(self, event, unit)
	Used to completely override the internal visibility toggling function.

	* self  - the parent object
	* event - the event triggering the update (string)
	* unit  - the unit accompanying the event (string)
	--]]
	(self.Tempest.OverrideVisibility or Visibility)(self, ...)
end

local function ForceUpdate(element)
	VisibilityPath(element.__owner, "ForceUpdate", element.__owner.unit)
end

local function Enable(self, unit)
	local element = self.Tempest
	if (element and UnitIsUnit(unit, "player")) then
		element.__owner = self
		element.ForceUpdate = ForceUpdate

		-- variables
		element.guid = UnitGUID("player")
		element.max = 10					-- maximum number of 'Maelstorm Weapon' stacks
		element.threshold = 40				-- every 40 'Maelstorm Weapon' stacks spent replaces your next 'Lightning Bold' with 'Tempest'

		element.maelstromStacks = 0
		element.maelstromSpentTotal = 0
		element.tempestReady = false
		element.tempestStacks = 0
		element.awakeningStacks = 0
		element.awakeningThreshold = 4

		-- Visibility logic: talent/buff based
		self:RegisterEvent("SPELLS_CHANGED", VisibilityPath, true)
		self:RegisterEvent("PLAYER_TALENT_UPDATE", VisibilityPath, true)

		if element:IsObjectType("StatusBar") and not element:GetStatusBarTexture() then
			element:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
		end

		-- do not change this without taking Visibility into account
		element:Hide()

		return true
	end
end

local function Disable(self)
	local element = self.Tempest
	if element then
		element:Hide()

		self:UnregisterEvent("SPELLS_CHANGED", VisibilityPath)
		self:UnregisterEvent("PLAYER_TALENT_UPDATE", VisibilityPath)
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED", Path)
	end
end

oUF:AddElement("Tempest", VisibilityPath, Enable, Disable)
