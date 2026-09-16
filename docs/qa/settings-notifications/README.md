# Settings notifications — 2026-09-15

Authoritative settings references: Figma M37Q2Q2mOe0UwzTWeA2Ofl, dark 262:28513 and light 262:26298.

SettingsCoordinator presents the inbox with settingsPresentation enabled: large native sheet, grabber, 38-point preferred corner radius, circular filled close control, primary background, permission header (60-point minimum card height), quaternary list fills without shadows, white icon wells and 12-point spacing between date sections. The standalone presentation retains the previous inbox styling and has no permission footer.

Timestamps use relative time for today and localized time of day for older notifications. Permission state remains the actual system authorization; the test simulator is off, unlike the reference's illustrative on state.

Verified final light.png and dark.png on iPhone 17 Pro / iOS 26.5 simulator. Three NotificationsLayoutTests passed, covering row widths, standalone back navigation and the settings sheet/header configuration. Final result: Test-Calorie Counter-2026.09.15_11-23-38-+0300.xcresult in project DerivedData Logs/Test. No physical-device verification.
