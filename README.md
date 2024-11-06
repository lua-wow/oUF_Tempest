# oUF_Tempest

Shaman Enhancement Tempest tracker support for oUF layouts

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

```lua
local Tempest = CreateFrame("StatusBar", nil, self)
Tempest:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, 0)
Tempest:SetSize(120, 20)

-- Register with oUF
self.Tempest = Tempest
```
