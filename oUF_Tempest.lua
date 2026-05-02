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

-- Spell IDs: auras
local SPELL_MAELSTROM_WEAPON = 344179
local SPELL_TEMPEST = 454015
local SPELL_AWAKENING_STORMS = 462131

-- Spell IDs: talents
local SPELL_MAELSTROM_WEAPON_TALENT = 187880
local SPELL_TEMPEST_TALENT = 454009
local SPELL_AWAKENING_STORMS_TALENT = 455130

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

local SPENDERS = {
	[1064] = true, -- Chain Heal
	[8004] = true, -- Healing Surge
	[51505] = true, -- Lava Burst
	[117014] = true, -- Elemental Blast
	[188196] = true, -- Lightning Bolt
	[188443] = true, -- Chain Lightning
	[452201] = true, -- Tempest
	[1218090] = true, -- Primordial Storm
}

local function UpdateColor(self, event, unit)
	local element = self.Tempest
	if (not element) then return end

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

local function Update(self)
	local element = self.Tempest
	if not element then return end

	element:SetMinMaxValues(0, element.max)
	element:SetValue(element.cur)

	if element.Value then
		if element.ready then
            element.Value:SetText("Tempest Ready!")
        else
            element.Value:SetFormattedText("%d / %d", element.cur, element.total)
        end
	end

	--[[ Callback: Tempest:PostUpdate(cur, max, total, ready)
    Called after the element has been updated.

    * self  - the Tempest element
    * cur   - current Maelstrom Weapon stacks (number)
    * max   - maximum Maelstrom Weapon stacks (number)
    * total - accumulated stacks spent toward next Tempest (number)
    * ready - whether Tempest aura is active (boolean)
    --]]
    if element.PostUpdate then
        element:PostUpdate(element.cur, element.max, element.total, element.ready)
    end
end

local function ProcessData(unit, data)
	if not data then
		return nil, nil, 0, nil
	end

	local applications = tonumber(C_UnitAuras.GetAuraApplicationDisplayCount(unit, data.auraInstanceID, 0)) or 0
	local duration = C_UnitAuras.GetAuraDuration(unit, data.auraInstanceID)
	return data, data.auraInstanceID, applications, duration
end

local function UpdateAuras(self, event, unit, updateInfo)
	if (unit ~= self.unit) then return end

	local element = self.Tempest
	if not element then return end

	do
		-- https://www.wowhead.com/spell=344179/maelstrom-weapon
		local data, auraInstanceID, applications, duration = ProcessData(unit, C_UnitAuras.GetUnitAuraBySpellID(unit, SPELL_MAELSTROM_WEAPON))
		element.maelstromWeapon = {
			data = data,
			auraInstanceID = auraInstanceID,
			applications = applications,
			duration = duration
		}
		element.cur = applications or 0
	end

	do
		-- https://www.wowhead.com/spell=454015/tempes
		local data, auraInstanceID, applications, duration = ProcessData(unit, C_UnitAuras.GetUnitAuraBySpellID(unit, SPELL_TEMPEST))
		element.tempest = {
			data = data,
			auraInstanceID = auraInstanceID,
			applications = applications,
			duration = duration
		}
		-- real aura is the only reliable ready signal (proc can bypass the counter)
		element.ready = applications > 0
	end

	do
		local data, auraInstanceID, applications, duration = ProcessData(unit, C_UnitAuras.GetUnitAuraBySpellID(unit, SPELL_AWAKENING_STORMS))
		element.awakeningStorms = {
			data = data,
			auraInstanceID = auraInstanceID,
			applications = applications,
			duration = duration
		}
	end

	Update(self)
end

local function UpdateSpellCast(self, event, unit, castGUID, spellID, castBarID)
	if (unit ~= self.unit) then return end

	local element = self.Tempest
	if not element then return end

	if not SPENDERS[spellID] then return end

	-- At this point UNIT_AURA has NOT fired yet, so element.cur still holds
    -- the pre-cast stack count — exactly what we want to count as "spent".
    local spent = element.cur
    if spent > 0 then
        element.total = element.total + spent

        -- wrap around the threshold; Tempest aura will confirm via UNIT_AURA
        if element.total >= element.threshold then
            element.total = element.total - element.threshold
        end
    end

	Update(self)
end

local function Update(self, event, unit, ...)
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		UpdateSpellCast(self, event, unit, ...)
	else
		UpdateAuras(self, event, unit, ...)
	end
end

local function Path(self, ...)
	local event = ...

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
	if event ~= "UNIT_SPELLCAST_SUCCEEDED" then
		(self.Tempest.UpdateColor or UpdateColor) (self, ...)
	end
end

local function Visibility(self, event, unit)
    local element = self.Tempest
    
	local spec = C_SpecializationInfo.GetSpecialization()
	local isTempestKnown = C_SpellBook.IsSpellKnown(SPELL_TEMPEST_TALENT)
	local visible = (spec == SPEC_SHAMAN_ENHANCEMENT and isTempestKnown and not UnitHasVehiclePlayerFrameUI("player"))
	
	element.__visible = visible

	if visible then
		self:RegisterEvent("UNIT_AURA", Path)
		self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", Path)

		if not element:IsShown() then
			element:Show()
		end

		Path(self, event, unit)
	else
		self:UnregisterEvent("UNIT_AURA", Path)
		self:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED", Path)

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

		-- identity
		element.guid = UnitGUID("player")

		-- state
		element.cur = 0						-- current 'Maelstorm Weapon' stacks
		element.max = 10					-- maximum 'Maelstorm Weapon' stacks
		element.total = 0					-- stacks spent toward next tempest proc (wraps at threshold)
		element.threshold = 40				-- stacks needed to generate one Tempest

		-- ready flag (set by UNIT_AURA via actual Tempest aura)
		element.ready = false

		-- aura cache tables (populated by UpdateAuras)
		element.maelstromWeapon = nil
		element.tempest         = nil
		element.awakeningStorms = nil

		-- visibility triggers
		self:RegisterEvent("SPELLS_CHANGED", VisibilityPath, true)
		self:RegisterEvent("PLAYER_TALENT_UPDATE", VisibilityPath, true)
		self:RegisterEvent('UNIT_DISPLAYPOWER', VisibilityPath)

		if element:IsObjectType("StatusBar") then
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

		self:UnregisterEvent("SPELLS_CHANGED", VisibilityPath)
		self:UnregisterEvent("PLAYER_TALENT_UPDATE", VisibilityPath)
		self:UnregisterEvent("UNIT_AURA", Path)
		self:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED", Path)
	end
end

oUF:AddElement("Tempest", VisibilityPath, Enable, Disable)
