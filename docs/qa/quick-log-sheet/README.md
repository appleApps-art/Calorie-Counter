# Quick Log sheet — 2026-09-15

Reference: Figma M37Q2Q2mOe0UwzTWeA2Ofl, dark 204:56145, light 204:54533.

Verified in iPhone 17 Pro / iOS 26.5 simulator using QA Home data, Ukrainian locale.

- Native inspector glass retained, dark surface tinted black at 60% opacity.
- Cards use primary background: black in dark, white in light.
- Icon wells: #1F1F1F in dark, black in light; symbols secondary light / white respectively.
- Close uses a circular filled secondary control with a 17 pt medium xmark.
- Grid bottom anchored 26 design points above sheet edge, corresponding to reference 32 points above screen edge with 6 point floating sheet margin.
- Control dimensions scale uniformly by width, preventing flattened circles and reduced card heights in the short sheet.
- Ukrainian labels wrap to two lines at 15 pt instead of shrinking.

Validation: build and testEditMealPlusPresentsFourLoggingOptions passed. Actual simulator screenshots: dark.png and light.png. Native live glass varies with content behind the panel.
