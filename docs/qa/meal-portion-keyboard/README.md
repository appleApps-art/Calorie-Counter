# Portion keyboard visibility — 2026-09-15

## Follow-up: reproduced and corrected in the real modal sheet

The earlier check below was insufficient. With `-qa -qaRoute editMeal -qaLongMeal`, the editor stages eight extra disposable draft entries. Activating the final portion reproduced keyboard occlusion in the actual navigation-controller sheet. The viewport shrank from 719 to 445 points, but `scrollRectToVisible` left offset 502 unchanged despite the target ending at 1218.

The final fix computes and clamps the required content offset explicitly. It also tracks keyboard end-frame notifications and accounts for any overlap not already handled by the keyboard layout guide. `long-meal-fixed.png` shows the final portion and insertion cursor fully above the real decimal keyboard, after reproducing the failing scenario through Simulator UI.

The new late-keyboard-frame regression attaches its test window to a UIWindowScene so screen-coordinate conversions are valid. The older scene-less test windows could not validate real keyboard coordinates. Final full EditMealInteractionTests run: 31 passed, 0 failed; `Test-Calorie Counter-2026.09.15_11-53-18-+0300.xcresult`. Final app installed in simulator; physical-device verification remains outstanding.

## Earlier verification (superseded)

Reference: Figma M37Q2Q2mOe0UwzTWeA2Ofl / 204:56113.

EditMealViewController tracks the active portion view weakly and reveals its bounds after keyboard-guide layout changes. A 12-point vertical margin is requested, with UIScrollView handling legal offset limits. Switching fields while the keyboard is already visible also requests layout. Existing footer hiding and draft-only portion semantics are preserved.

The previous regression manually scrolled to the bottom after showing the keyboard, masking this bug. It now checks visibility without that manual scroll, checks the field against the keyboard guide, and switches from the first to the final field in an eight-item meal.

Final EditMealInteractionTests run: 30 passed, 0 failed. Result: Test-Calorie Counter-2026.09.15_11-30-13-+0300.xcresult in project DerivedData Logs/Test. The XCTest window snapshot rendered black and was not used as visual evidence. active-bottom.png is a separate real simulator screenshot after activating the final field through the UI with the decimal keyboard open. Physical-device verification was not performed.
