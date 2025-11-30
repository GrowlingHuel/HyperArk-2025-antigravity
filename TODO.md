# Project Plan: Architecture Refactor & Cleanup

> **Status**: Phase 1 Complete! Moving to Phase 2.

## Phase 1: Cleanup & preparation ✅
- [x] Delete dead code: `database_live.ex` and `database_live.html.heex`
- [x] Previously removed: `character_live.ex`, `living_web_live.ex`, `home_live.ex` (already cleaned up)
- [x] DB Violation already fixed: No `Repo.preload` in `DualPanelLive`

## Phase 2: Refactoring `DualPanelLive` ✅ COMPLETE

### Achievements:
- ✅ **Step 1**: Created `InventoryPanelComponent` (227 lines)
  - Extracted all inventory event handlers (6 handlers removed from parent)
  - Component manages its own state
  - Full CRUD operations: add, delete, select items
  
- ✅ **Step 2**: Created `OpportunitiesPanelComponent` (187 lines)
  - Extracted opportunities modal overlay rendering
  - Handles close/apply events internally
  - Template reduced by 150+ lines

- ✅ **Final Metrics**:
  - `DualPanelLive.ex`: 1221 → 1143 lines (-78 lines, -6.4%)
  - `DualPanelLive.html.heex`: 512 → 266 lines (-246 lines, -48%)
  - **Total reduction**: 324 lines of monolithic code
  - **New components**: 414 lines of focused, testable code

### Deferred (Low ROI):
- ⏸️ Node/harvest panel logic (small,  tightly coupled with diagram data)
- ⏸️ Chat logic refactoring (complex AI integration, better kept centralized)

## Phase 3: Styling & UI Improvements
- [ ] Extract inline styles from `dual_panel_live.html.heex` to CSS classes (Tailwind or custom CSS)
- [ ] Standardize styling across components
- [ ] Remove `!important` usage where possible

## Phase 4: Testing & Verification
- [ ] Add unit tests for new/refactored components
- [ ] Verify all functionality (Chat, Living Web, Planting Guide, Journal) works as expected after refactor