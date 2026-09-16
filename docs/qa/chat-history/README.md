# Chat History — 2026-09-15

Figma references: M37Q2Q2mOe0UwzTWeA2Ofl, light 204:57602, dark 204:57800.

Visual corrections: secondary gray canvas (#F2F2F7 / #1C1C1E), filled white/black grouped cards with shadows rather than borders, single-line titles and previews, minimum 70 pt rows, theme-aware separators and chevrons, 10 pt navigation-to-search spacing, regular-weight clear-history action. Reuses native glass buttons and existing horizontal/vertical edge fades.

Behavior: no-result search does not hide clear-all when saved conversations exist; empty history has its own localized message; clear-all resets search and category only after successful storage deletion; persistence failures are surfaced; leaving history cancels dictation. Existing per-conversation navigation, all-message search and category isolation retained.

Validation: ChatHistoryConversationTests and ChatConversationPersistenceTests, 11 passed / 0 failed on iPhone 17 Pro, iOS 26.5. Native screenshots before-light.png, after-light.png, after-dark.png use QA conversation fixtures (content differs from Figma). No worker changes.
