# Recipe visual corrections — 2026-09-16

References: Figma 441:42013 (light Recipes/All), 441:45924 (dark Recipes/All within the supplied 441:45919 section).

- Recipe cards: 76 pt image at the reference width, two 21 pt title lines, calorie badge over the image, 8 pt inner spacing, 16 pt card corners.
- Segmented control: white track in light mode, elevated #1C1C1E track in dark mode; selected label white/black respectively.
- Bottom backdrop: 65 pt + bottom safe area; mint/black, with white replacing mint on Rewards. Removed the extra tab-bar overhang and transparent bar appearance. Native soft scroll-edge treatment stays enabled on the root scrolling screens to suppress content inside the glass tab bar.
- Sharing: restored 804 pt, two-column composition; wide 240 pt photo header (112 pt without a photo). Ingredients and instructions stay complete.

Validation: Xcode build and 8 targeted XCTest cases passed on iPhone 17 Pro / iOS 26.5. Includes responsive recipe cards, segment resizing, tab backdrop placement, share-card proportions, and calendar clearance.

Screenshots use deterministic QA recipes with solid image fixtures and English fixture names; they do not exercise production search translation. share-card.png is the no-photo test fixture.
