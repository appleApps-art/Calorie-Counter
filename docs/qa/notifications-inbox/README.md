# Notifications — 2026-09-15

Historical capture: the user subsequently supplied separate settings-specific references. The settings route now uses the sheet documented in ../settings-notifications/README.md; the permission footer described below was removed from the standalone presentation.

References: Figma file M37Q2Q2mOe0UwzTWeA2Ofl, dark 204:55961 and light 204:54349.

Corrected the sheet presentation to a navigation push with a circular back button and safe-area header. Permission controls now follow the inbox rather than displacing the first date section. This intentionally preserves existing permission functionality beyond the Figma content.

Rows now use their full available body width, wrap long titles, use 22/18-point line heights and 12-point vertical padding, preserve square icon wells, and use neutral icon colors in both themes. Section spacing is 16 points; card fills and shadows match the reference appearance. Relative timestamps use the actual notification date (yesterday's items correctly read one day ago rather than the reference's placeholder two hours ago). VoiceOver exposes the existing dismiss action.

Screenshots: before-dark.png, after-dark.png, after-light.png. Captured on iPhone 17 Pro, iOS 26.5 simulator. Filled QA route uses an isolated in-memory inbox with reference text, without replacing persisted notifications.

Final targeted test run: 2 passed, 0 failed. NotificationsLayoutTests checks full body width, wrapping, square icon wells across three row widths, safe-area header placement, permission footer placement and back navigation.

Result: Test-Calorie Counter-2026.09.15_11-03-53-+0300.xcresult in project DerivedData Logs/Test. Physical device verification was not performed.
