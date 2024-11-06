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

-- Mine
local _, class = UnitClass("player")
if (class ~= "SHAMAN") then return end

local SPEC_SHAMAN_ENHANCEMENT = _G.SPEC_SHAMAN_ENHANCEMENT or 2

local AWAKENING_STORMS = 462131
local MAELSTROM_WEAPON = 344179
local TEMPEST = 454015

local SPENDERS = {
    [1064] = true, -- Chain Heal
    [8004] = true, -- Healing Surge
    [51505] = true, -- Lava Burst
    [117014] = true, -- Elemental Blast
    [188196] = true, -- Lightning Bolt
    [188443] = true, -- Chain Lightning
    [320674] = false -- Chain Harvest (Venthyr Covenant Ability)
    [452201] = true, -- Tempest
}

local COMBAT_EVENTS = {
    ["SPELL_AURA_APPLIED"] = true,
    ["SPELL_AURA_APPLIED_DOSE"] = true,
    ["SPELL_AURA_REMOVED"] = true,
    ["SPELL_AURA_REMOVED_DOSE"] = true,
    ["SPELL_AURA_REFRESH"] = true,
    ["SPELL_CAST_SUCCESS"] = true,
}

local function UpdateColor(self, event, unit)
	-- if (unit and unit ~= self.unit) then return end
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

local function Update(self, event, unit)
    local element = self.Tempest

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()

        -- filter events
        if not COMBAT_EVENTS[subevent] then return end
        
        -- watch only sevent casted by the player
        if sourceGUID ~= element.guid then return end

        local spellID, spellName, spellSchool, auraType, amount = select(12, CombatLogGetCurrentEventInfo())
        
        local changed = false
        if (subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_APPLIED_DOSE") then
            if spellID == MAELSTROM_WEAPON then
                element.value = (amount or 1)
                changed = true
            elseif spellID == TEMPEST then
                element.tempest = (amount or 1)
                changed = true
            end
        elseif (subevent == "SPELL_AURA_REMOVED" or subevent == "SPELL_AURA_REMOVED_DOSE") then
            if spellID == MAELSTROM_WEAPON then
                element.value = (amount or 1)
                changed = true
            elseif spellID == TEMPEST then
                element.tempest = (amount or 1)
                changed = true
            end
        elseif subevent == "SPELL_AURA_REFRESH" and spellID == MAELSTROM_WEAPON then
            changed = true
        elseif subevent == "SPELL_CAST_SUCCESS" and SPENDERS[spellID] then
			element.total = element.total - element.value
			if element.total <= 0 then
				element.total = element.total + element.threshold
			end
			element.last_update = GetTime()
			change = true
        end
    else
		-- https://www.wowhead.com/spell=462131/awakening-storms
        local asInfo = C_UnitAuras.GetPlayerAuraBySpellID(462131)
		local awakeningStorms = asInfo and asInfo.applications or 0

		-- https://www.wowhead.com/spell=344179/maelstrom-weapon
		local mwInfo = C_UnitAuras.GetPlayerAuraBySpellID(MAELSTROM_WEAPON)
        -- local maelstormWeapon = mwInfo and mwInfo.applications or 0
		element.value = mwInfo and mwInfo.applications or 0
		
		-- https://www.wowhead.com/spell=454015/tempest
		local mwInfo = C_UnitAuras.GetPlayerAuraBySpellID(TEMPEST)
		element.tempest = mwInfo and mwInfo.applications or 0
    end

	--[[ Callback: Tempest:PreUpdate()
	Called before the element has been updated.

	* self - the Tempest element
	--]]
	if element.PreUpdate then
		element:PreUpdate()
	end

    if element.Value then
        element.Value:SetFormattedText("%d / %d / %d (%d)", element.value, element.total, element.threshold, element.tempest)
    end
	
	element:SetMinMaxValues(0, element.threshold)
    element:SetValue(element.value + element.total)

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
	if (spec ~= SPEC_SHAMAN_ENHANCEMENT or UnitHasVehiclePlayerFrameUI("player")) then
		if element:IsShown() then
			element:Hide()
			self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED", Path)
		end
	else
		if not element:IsShown() then
			element:Show()
			self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", Path, true)
		end

		Path(self, event, unit)
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
		element.threshold = 40 -- number of 'Maelstorm Weapon' necessary to spend to turn 'Lightning Bold' into 'Tempest'
		element.value = 0 -- number of stacks of 'Maelstorm Weapon'
		element.total = element.threshold -- number of stacks of 'Maelstorm Weapon' spend
		element.tempest = 0 -- number of stacks of 'Tempest'
		element.last_update = 0

		self:RegisterEvent("PLAYER_TALENT_UPDATE", VisibilityPath, true)

		if element:IsObjectType("StatusBar") then
            element:SetMinMaxValues(0, 40)
            if not element:GetStatusBarTexture() then
			    element:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
            end
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

		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED", Path)
		self:UnregisterEvent("PLAYER_TALENT_UPDATE", VisibilityPath)
	end
end

oUF:AddElement("Tempest", VisibilityPath, Enable, Disable)
