--[[
# Element: Tempest Bar

Handles the visibility and updating of the shaman enhancement Tempest bar.

## Widget

Tempest - A `StatusBar` used to represent the current Maelstrom Weapon stacks and the stacks spent toward the next
Tempest proc.

## Sub-Widgets

.bg    - A `Texture` used as a background. It will inherit the color of the main StatusBar.
.Value - A `FontString` showing the stacks spent toward the next Tempest, or "Tempest Ready!" while Tempest is ready.

## Notes

A default texture will be applied if the widget is a StatusBar and doesn't have a texture set.

Only enabled for the player, and only shown for Enhancement shamans with the Tempest talent, outside of vehicles.

The Tempest aura is secret in combat, so readiness comes from Lightning Bolt being overridden by Tempest.
`.tempest.duration` (a duration object) is only refreshed while the aura is not secret.

## Sub-Widgets Options

.multiplier - Used to tint the background based on the main widgets R, G and B values. Defaults to 1 (number)[0-1]

## Attributes

.cur              - current Maelstrom Weapon stacks (number)
.max              - maximum Maelstrom Weapon stacks (number)
.total            - stacks spent toward the next Tempest (number)
.threshold        - stacks needed to generate one Tempest (number)
.ready            - whether Tempest is ready (boolean)
.tempest.duration - remaining duration of the Tempest aura (LuaDurationObject?)

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
local GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID
local GetOverrideSpell = C_Spell.GetOverrideSpell
local issecretvalue = _G.issecretvalue

-- Mine
local _, class = UnitClass("player")
if (class ~= "SHAMAN") then return end

local SPEC_SHAMAN_ENHANCEMENT = _G.SPEC_SHAMAN_ENHANCEMENT or 2

-- Spell IDs: auras
local SPELL_MAELSTROM_WEAPON = 344179
local SPELL_TEMPEST = 454015

-- Spell IDs: talents
local SPELL_TEMPEST_TALENT = 454009

-- Spell IDs: spells
local SPELL_LIGHTNING_BOLT = 188196
local SPELL_TEMPEST_OVERRIDE = 452201 -- replaces Lightning Bolt while Tempest is ready

-- spells that consume Maelstrom Weapon stacks
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

	local color = self.colors.power[Enum.PowerType.Maelstrom or 11]
	if (not color) then return end

	element:SetStatusBarColor(color.r, color.g, color.b)

	local bg = element.bg
	if bg then
		local mu = bg.multiplier or 1
		bg:SetVertexColor(color.r * mu, color.g * mu, color.b * mu)
	end

	--[[ Callback: Tempest:PostUpdateColor(color)
	Called after the element color has been updated.

	* self  - the Tempest element
	* color - the used color (ColorMixin)
	--]]
	if element.PostUpdateColor then
		element:PostUpdateColor(color)
	end
end

local function UpdateBar(element)
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
	* total - stacks spent toward the next Tempest (number)
	* ready - whether Tempest is ready (boolean)
	--]]
	if element.PostUpdate then
		element:PostUpdate(element.cur, element.max, element.total, element.ready)
	end
end

-- returns: found (boolean), aura; found is nil when the aura is secret (state unknown)
local function GetAura(spellID)
	local aura = GetPlayerAuraBySpellID(spellID)
	if aura == nil then
		return false
	end
	if issecretvalue(aura) or issecretvalue(aura.applications) or issecretvalue(aura.auraInstanceID) then
		return nil
	end
	return true, aura
end

local function UpdateAuras(self, event, unit)
	if (unit and unit ~= "player") then return end

	local element = self.Tempest
	local cur, ready = element.cur, element.ready

	-- https://www.wowhead.com/spell=344179/maelstrom-weapon
	local found, aura = GetAura(SPELL_MAELSTROM_WEAPON)
	if found ~= nil then
		element.cur = found and aura.applications or 0
	end

	-- https://www.wowhead.com/spell=454015/tempest
	-- the aura is secret in combat; the Lightning Bolt -> Tempest override is not
	-- (proc can bypass the counter, so it can't be derived from total)
	element.ready = GetOverrideSpell(SPELL_LIGHTNING_BOLT) == SPELL_TEMPEST_OVERRIDE

	-- duration is only available while the aura is not secret (out of combat)
	local tempest = element.tempest
	local auraInstanceID = tempest.auraInstanceID
	found, aura = GetAura(SPELL_TEMPEST)
	if found ~= nil then
		tempest.auraInstanceID = found and aura.auraInstanceID or nil
		tempest.duration = found and C_UnitAuras.GetAuraDuration("player", aura.auraInstanceID) or nil
	end

	local changed = cur ~= element.cur or ready ~= element.ready or auraInstanceID ~= tempest.auraInstanceID
	if event == "UNIT_AURA" and not changed then return end

	UpdateBar(element)
end

local function UpdateSpellCast(self, event, unit, castGUID, spellID)
	if (unit and unit ~= "player") then return end

	if issecretvalue(spellID) or not SPENDERS[spellID] then return end

	-- UNIT_AURA has not fired yet, so element.cur still holds the pre-cast stacks: the ones spent
	local element = self.Tempest
	local spent = element.cur
	if spent > 0 then
		element.total = element.total + spent

		-- wrap around the threshold; readiness itself comes from the spell override
		if element.total >= element.threshold then
			element.total = element.total - element.threshold
		end
	end

	UpdateBar(element)
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

	--[[ Override: Tempest.Override(self, event, unit, ...)
	Used to completely override the internal update function.

	* self  - the parent object
	* event - the event triggering the update (string)
	* unit  - the unit accompanying the event (string)
	* ...   - the arguments accompanying the event
	--]]
	(self.Tempest.Override or Update)(self, ...);

	-- colors only change with visibility, not with auras or casts
	if event ~= "UNIT_AURA" and event ~= "UNIT_SPELLCAST_SUCCEEDED" then
		--[[ Override: Tempest.UpdateColor(self, event, unit)
		Used to completely override the internal function for updating the widgets' colors.

		* self  - the parent object
		* event - the event triggering the update (string)
		* unit  - the unit accompanying the event (string)
		--]]
		(self.Tempest.UpdateColor or UpdateColor)(self, ...)
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
	VisibilityPath(element.__owner, "ForceUpdate", element.__owner.__unit)
end

local function Enable(self, unit)
	local element = self.Tempest
	if (element and UnitIsUnit(unit, "player")) then
		element.__owner = self
		element.ForceUpdate = ForceUpdate

		-- state
		element.cur = 0					-- current Maelstrom Weapon stacks
		element.max = 10				-- maximum Maelstrom Weapon stacks
		element.total = 0				-- stacks spent toward the next Tempest (wraps at threshold)
		element.threshold = 40			-- stacks needed to generate one Tempest
		element.ready = false			-- Lightning Bolt is overridden by Tempest
		element.tempest = {}			-- Tempest aura cache (auraInstanceID, duration)

		-- visibility triggers
		self:RegisterEvent("SPELLS_CHANGED", VisibilityPath, true)
		self:RegisterEvent("PLAYER_TALENT_UPDATE", VisibilityPath, true)
		self:RegisterEvent("UNIT_DISPLAYPOWER", VisibilityPath)

		if element:IsObjectType("StatusBar") then
			if not element:GetStatusBarTexture() then
				element:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
			end
			element:SetMinMaxValues(0, element.max)
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
		self:UnregisterEvent("UNIT_DISPLAYPOWER", VisibilityPath)
		self:UnregisterEvent("UNIT_AURA", Path)
		self:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED", Path)
	end
end

oUF:AddElement("Tempest", VisibilityPath, Enable, Disable)
