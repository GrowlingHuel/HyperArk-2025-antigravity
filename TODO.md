# Project Plan: Architecture Refactor & Cleanup

## Phase 1: Cleanup & preparation
- [ ] Delete dead code: `lib/green_man_tavern_web/live/character_live.ex`
- [ ] Delete dead code: `lib/green_man_tavern_web/live/living_web_live.ex`
- [ ] Delete dead code: `lib/green_man_tavern_web/live/home_live.ex`
- [ ] Delete dead code: `lib/green_man_tavern_web/live/OLD_living_web_live.ex.disabled`
- [ ] Fix DB Violation: Move `Repo.preload` from `DualPanelLive` to `Quests` context

## Phase 2: Refactoring `DualPanelLive` (The "God Object")
- [ ] Analyze `DualPanelLive` state and identify what belongs to specific components
- [ ] Refactor `TavernPanelComponent`: Move relevant event handlers from `DualPanelLive` to component
- [ ] Refactor `LivingWebPanelComponent`: Move relevant event handlers from `DualPanelLive` to component
- [ ] Refactor `PlantingGuidePanelComponent`: Move relevant event handlers from `DualPanelLive` to component
- [ ] Refactor `JournalPanelComponent`: Move relevant event handlers from `DualPanelLive` to component
- [ ] Extract Inventory logic into a new `InventoryPanelComponent` (or similar) if complexity warrants
- [ ] Extract "Opportunities Panel" into a dedicated component

## Phase 3: Styling & UI Improvements
- [ ] Extract inline styles from `dual_panel_live.html.heex` to CSS classes (Tailwind or custom CSS)
- [ ] Standardize styling across components
- [ ] Remove `!important` usage where possible

## Phase 4: Testing & Verification
- [ ] Add unit tests for new/refactored components
- [ ] Verify all functionality (Chat, Living Web, Planting Guide, Journal) works as expected after refactor