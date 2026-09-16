# Progress Log inspector — 2026-09-15

References: Figma M37Q2Q2mOe0UwzTWeA2Ofl, light 262:26694, dark 262:28846.

Kept the native 260 pt inspector and its live material. Corrected the 24 pt header-to-options gap, 10 pt inner horizontal inset, native point sizes (68 pt cards, 44 pt icon wells, 16 pt symbols), and secondary close icon. Both themes use white cards, black labels and wells, white symbols. Applied light/dark backdrop tint consistent with the other corrected inspectors. Removed sheet-height-based shrinking of the XIB constraints. Actions and dismissal flow unchanged.

Validation: simulator build succeeded on iPhone 17 Pro / iOS 26.5; captured and inspected before-light.png, after-light.png, after-dark.png. Native glass appearance varies with the charts behind the sheet; QA chart data differs from Figma. No worker changes.
