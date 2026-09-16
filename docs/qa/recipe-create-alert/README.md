# Recipes Create inspector — 2026-09-15

Reference: Figma M37Q2Q2mOe0UwzTWeA2Ofl, light 262:24683, dark 262:26819.

Updated the existing UIKit/XIB inspector: header-to-options gap 30 pt, action height 68 pt, close and icon wells 44 pt, action symbols 16 pt, options inset 10 pt inside the floating sheet. Compact sheet geometry no longer shrinks based on the sheet height. The native material has a light/dark tint; both themes retain white action cards with black labels and icon wells, as in the supplied frames. Close uses the secondary icon color.

Validation: RecipesChromeTests 7 passed, 0 failed on iPhone 17 Pro / iOS 26.5. Final build succeeded after horizontal inset adjustment. Captured and inspected after-light.png and after-dark.png from the installed build. before-light.png captures the previous implementation. The underlying recipe images are QA fixtures; native material colors vary with the content behind them. Native sheet perimeter and grabber remain controlled by UIKit.
