# Recipe detail: dark palette — 2026-09-10

Reference: [Figma 262:27773](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-27773).

Verified the full Nutrition screen with Figma design context, rendered screenshot, resolved variables, and donut SVG fills.

| Element | Figma dark value | Implementation |
| --- | --- | --- |
| Screen | #000000 | AppColor.backgroundsPrimary; patterned image hidden in dark |
| Hero, score, calorie and list cards | #1C1C1E | AppColor.backgroundsPrimaryElevated |
| Tags | #000000 / #FFFFFF | Fixed black fill, white title and SF Symbol |
| Score badge and ring progress | #00DAC3 | AppColor.accentMint |
| Ring track | #767680 at 18% | AppColor.fillQuaternary |
| Score link / selected segment | #00D2E0 | AppColor.teal |
| Nutrition separators | #1A1A1A | AppColor.separatorVibrant |
| Save button fill | #767680 at 24% | AppColor.fillTertiary |

AdaptiveView previously reapplied AppColor.card during layout and trait updates. Its cardFillColor now defaults to the original color but can be configured by RecipeDetailViewController, so recipe card fills survive relayout and theme changes.

The light screen retains its existing patterned background and white cards. Shared row and card defaults remain unchanged for other screens.

Validation: clean simulator build and 10 existing tests passed in /tmp/bity-recipe-palette.xcresult. Repeated the existing recipe-detail test with temporary visual capture and an assertion of the controller's active style: passed in /tmp/bity-recipe-palette-verified.xcresult. The temporary capture code was removed; the test source was restored byte-for-byte.

Reviewed top and bottom renders at 402×874 points (1206×2622 PNG) in dark, light, and dark after switching on the same controller. First drawHierarchy captures were discarded because they did not reflect the requested style reliably. These final images use layer rendering with an explicit controller style and omit live glass/status-bar rendering.

The fixture uses the existing broth test's text/nutrition and a photo exported from the Figma reference solely to inspect the palette; it does not represent a saved user recipe or validate image matching. This is a color correction, not a claim of complete layout parity.

- [Dark top](dark-top.png)
- [Dark bottom](dark-bottom.png)
- [Light top](light-top.png)
- [Light bottom](light-bottom.png)
- [Dark after switching](dark-after-switch-top.png)
- [Dark bottom after switching](dark-after-switch-bottom.png)
- [Figma reference](figma-dark.png)
