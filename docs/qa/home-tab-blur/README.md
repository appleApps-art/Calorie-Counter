# Home tab bar backdrop — 2026-09-14

Reference: Figma `M37Q2Q2mOe0UwzTWeA2Ofl`, Home / Empty Dark `204:55699`, footer `204:55749`.

The effect's container previously had a gradient layer mask. UIKit documents that masking an ancestor of UIVisualEffectView can cause its effect to fail. The same gradient also faded the blur across the whole footer, leaving content readable near the tabs.

The mask now belongs directly to UIVisualEffectView and is resized/reassigned after layout. The footer reaches full effect at the end of the 24-point adapted overhang above the tab bar. This short blend avoids the hard edge of a native material while retaining full blur behind the tabs. The existing light/dark TabBarBackground asset supplies the gradient; native UIKit material is used rather than an exact configurable Figma blur radius. Flipped header use retains its original gradient direction.

Verification on iPhone 17 Pro, iOS 26.5 simulator:

- Final targeted XCTest run: 3 passed, 0 failed (HomeTabBarBlurTests plus the two RecipesChromeTests backdrop tests).
- Tests cover foreground layer ordering, bottom coverage, correct mask ownership, resizing and flipped header behavior.
- Visual inspection: `after-empty-dark.png`, `after-empty-light.png`, `after-dark.png` (filled). Original filled dark state: `before-dark.png`.
- Final result: `Test-Calorie Counter-2026.09.14_22-49-53-+0300.xcresult` in the project's DerivedData Logs/Test directory.
- Earlier full RecipesChromeTests run had an unrelated failure in `testCreateSheetLaysOutGapBetweenCloseAndOptions` (close wrapper lookup). That create-sheet code was not changed; the full suite is not claimed green.

Latest debug build installed in simulator. Physical-device rendering was not verified.
