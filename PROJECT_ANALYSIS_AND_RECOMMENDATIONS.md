# Project Analysis & Recommendations

> **Last Updated**: 2025-11-30
> **Current Status**: Architecture needs modularization; some cleanup already completed

## 1. Executive Summary

The Green Man Tavern project is an ambitious and functionally rich application that combines RPG elements with practical permaculture tools. It has successfully implemented a complex Dual-Panel architecture that allows for simultaneous interaction with character agents and system design tools.

**Good News**: Components exist and are being used (`TavernPanelComponent`, `LivingWebPanelComponent`, `PlantingGuidePanelComponent`, `JournalPanelComponent`).

**Remaining Issue**: `DualPanelLive` (1221 lines) still handles too many responsibilities - it manages routing, global state, and event handling for features that could be delegated to components.

## 2. Project Structure Analysis

### Backend (Contexts & Schema)
**Status: Healthy**
The backend follows standard Phoenix patterns well. Contexts (`PlantingGuide`, `Sessions`, `Inventory`, etc.) properly encapsulate business logic and database interactions. The separation of concerns here is good and should be maintained.

### Frontend (LiveView)
**Status: Needs Refactoring**
The frontend architecture has diverged from the modular plan.
- **DualPanelLive**: This single file handles routing, global state, and event handling for all sub-features (Journal, Living Web, Planting Guide). This makes it difficult to maintain and extend.
- **Components**: While components exist (`TavernPanelComponent`, `LivingWebPanelComponent`, etc.), they are currently under-utilized. Much of the logic that should reside within them (event handling, specific state management) is still effectively "hoisted" up to the parent `DualPanelLive`.

### Styling
**Status: Brittle**
There is a heavy reliance on inline styles and `!important` overrides in `dual_panel_live.html.heex`. This makes the UI fragile and hard to theme or adjust. Moving towards consistent Tailwind CSS classes is highly recommended.

## 3. Key Aspects & Recommendations

### A. Modularization of `DualPanelLive`
**Current State**: `DualPanelLive` handles events for inventory, chat, node selection, and navigation.
**Recommendation**:
- **Delegate Responsibility**: Push event handling down to the respective components. For example, `handle_event("send_message", ...)` is currently in the parent, but could arguably be handled within `TavernPanelComponent` if it manages its own form state, communicating back to the parent only when necessary (or updating the context directly and relying on PubSub for updates).
- **Dedicated Components**: Create `InventoryPanelComponent` and `OpportunitiesPanelComponent` to encapsulate the currently inline HTML and logic for these features.

### B. State Management
**Current State**: `socket.assigns` in `DualPanelLive` is a mix of global state (current user) and feature-specific state (journal entries, planting guide data).
**Recommendation**:
- **Scoped State**: Components should manage their own ephemeral state where possible.
- **Context-Driven Updates**: Continue using PubSub for cross-component updates (e.g., when a quest is updated, the Journal component refreshes), which is already implemented and working well.

### C. Code Cleanup
**Current State**: One remaining dead code file identified: `database_live.ex` (not referenced in router).
**Recommendation**: Delete this file to reduce noise in the codebase.

### D. Testing
**Current State**: Test coverage appears low for the complex interactions in `DualPanelLive`.
**Recommendation**: As logic is extracted into components, write unit tests for those components. It is often easier to test a focused `LiveComponent` than a massive `LiveView`.

## 4. Proposed Refactoring Workflow

1.  **Cleanup**: Remove dead code immediately to clear the workspace.
2.  **Component Extraction**:
    -   Identify a logical block in `DualPanelLive` (e.g., Inventory logic).
    -   Create a new component (e.g., `InventoryPanelComponent`).
    -   Move the render logic and event handlers to this component.
    -   Mount the component in `DualPanelLive`.
    -   Repeat for other sections.
3.  **Style Refactor**: As each component is touched, replace inline styles with Tailwind classes.

## 5. Conclusion

The project has a solid foundation. The "God Object" issue is a common growing pain in LiveView applications. By methodically refactoring `DualPanelLive` into smaller, self-contained components, we will improve maintainability, testability, and developer velocity for future features.