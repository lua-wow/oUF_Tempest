# oUF_Tempest

Shaman Enhancement Tempest tracker support for oUF layouts

# Element: Tempest Bar

Handles the visibility and updating of the shaman enhancement Tempest bar.

## Widget

Tempest - A `StatusBar` used to represent the current Maelstrom Weapon stacks and the stacks spent toward the next Tempest proc.

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

```lua
local Tempest = CreateFrame("StatusBar", nil, self)
Tempest:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, 0)
Tempest:SetSize(120, 20)

-- Register with oUF
self.Tempest = Tempest
```
