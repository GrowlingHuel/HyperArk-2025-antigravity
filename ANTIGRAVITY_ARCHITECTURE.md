# ANTIGRAVITY ARCHITECTURE AUDIT

> **Date**: November 22, 2025
> **Scope**: Phoenix LiveView Codebase (`lib/green_man_tavern_web`, `lib/green_man_tavern`)
> **Focus**: Context Structure, Data Flow, Regulations, Internal Consistency

---

## 1. Executive Summary

The **Green Man Tavern** application has successfully achieved its functional goal of a persistent **Dual-Panel Architecture**, but it has significantly diverged from its intended *architectural* plan.

Instead of a modular system using `LiveComponents` for each panel, the application relies on a single **Monolithic LiveView** (`DualPanelLive`) that acts as a "God Object," handling routing, state management, business logic, and rendering for the entire application.

While the **Context Layer** (Backend) is generally healthy and well-structured, the **Presentation Layer** (Frontend/LiveView) is brittle, oversized, and difficult to maintain due to this monolithic approach and extensive use of inline styles.

---

## 2. Context Modules Structure (Backend)

**Status: ✅ HEALTHY**

The application follows standard Phoenix Context patterns effectively.

*   **Encapsulation**: Contexts like `PlantingGuide`, `Sessions`, and `Inventory` properly encapsulate business logic and database queries.
*   **Schema Usage**: Ecto schemas are used consistently. No raw SQL or map-based data passing was observed in the core logic.
*   **Separation of Concerns**:
    *   `PlantingGuide`: Handles complex date calculations and frost logic internally.
    *   `Sessions`: Provides a clean API for session management, hiding the underlying `ConversationHistory` complexity.
    *   `AI`: Manages interaction with LLMs.

**Recommendation**: Continue this pattern. The backend architecture is solid.

---

## 3. Data Flow & LiveView Architecture (Frontend)

**Status: ⚠️ CRITICAL ARCHITECTURAL DIVERGENCE**

### 3.1 The "God Object": `DualPanelLive`
*   **File Size**: `dual_panel_live.ex` is **6,800+ lines**. `dual_panel_live.html.heex` is **2,800+ lines**.
*   **Responsibilities**: It handles *everything*:
    *   **Routing**: Manages `live_action` for Home, Living Web, Journal, Planting Guide.
    *   **State**: Holds state for *all* features simultaneously in `socket.assigns` (Nodes, Edges, Journal Entries, Quests, Plants, Chat).
    *   **Events**: Handles 50+ event types (`select_character`, `node_selected`, `add_inventory_item`, `select_city`, etc.).
    *   **Rendering**: Renders all UI inline using conditional logic (`case @right_panel_action do...`).

### 3.2 Missing Components
The original "Two-Panel Architecture Plan" called for:
*   `TavernPanelComponent` (Left Panel)
*   `LivingWebPanelComponent` (Right Panel)

**Reality**: These components **do not exist**. The `lib/green_man_tavern_web/live/panels/` directory is missing. All logic intended for these components was dumped directly into `DualPanelLive`.

### 3.3 Data Flow
*   **Current**: `Router` → `DualPanelLive` (Monolith) → `Contexts` → `Database`
*   **Ideal**: `Router` → `DualPanelLive` (Container) → `LiveComponents` (Feature Logic) → `Contexts` → `Database`

---

## 4. Regulations & Violations

### 4.1 Database Access
*   **Rule**: "All database access must use Ecto schemas and reside in a Context."
*   **Finding**: Mostly followed.
    *   **Violation**: `DualPanelLive.mount/3` calls `Repo.preload` directly (Line 104). This should be moved to a Context function (e.g., `Quests.list_user_quests_with_characters`).

### 4.2 Dead Code
The following files appear to be abandoned remnants of the pre-dual-panel era. They are not referenced in the Router or `DualPanelLive`:
*   `lib/green_man_tavern_web/live/character_live.ex`
*   `lib/green_man_tavern_web/live/living_web_live.ex`
*   `lib/green_man_tavern_web/live/home_live.ex`
*   `lib/green_man_tavern_web/live/OLD_living_web_live.ex.disabled`

### 4.3 Styling
*   **Rule**: "Use Tailwind CSS."
*   **Finding**: `dual_panel_live.html.heex` relies heavily on **Inline CSS** with `!important` overrides.
    *   *Example*: `<div style="width: 100vw !important; ... border: 2px solid #000 !important;">`
    *   This makes the UI extremely hard to maintain or theme.

---

## 5. Action Plan: Restoring Internal Consistency

To align the project with its mission and ensure maintainability, the following steps are required:

### Phase 1: Cleanup (Immediate)
1.  **Delete Dead Code**: Remove `character_live.ex`, `living_web_live.ex`, `home_live.ex` and their templates.
2.  **Fix DB Violation**: Move `Repo.preload` from `DualPanelLive` to the `Quests` context.

### Phase 2: Refactoring (High Priority)
1.  **Extract Components**: Break `DualPanelLive` into functional `LiveComponents`:
    *   `GreenManTavernWeb.Live.Components.TavernPanel` (Chat/Character logic)
    *   `GreenManTavernWeb.Live.Components.LivingWebPanel` (Canvas logic)
    *   `GreenManTavernWeb.Live.Components.PlantingGuidePanel` (Planting logic)
    *   `GreenManTavernWeb.Live.Components.JournalPanel` (Journal logic)
2.  **Delegate Events**: Move event handlers (`handle_event`) from the parent LiveView to their respective components using `myself`.

### Phase 3: Styling (Medium Priority)
1.  **Extract CSS**: Move inline styles to a dedicated CSS file or use Tailwind utility classes consistently.
2.  **Remove `!important`**: Refactor CSS specificity to avoid reliance on `!important`.

---

## 6. Conclusion

The project is **functionally successful** but **architecturally indebted**. The "God Object" `DualPanelLive` is a major bottleneck for future development. Refactoring this into the originally planned Component-based architecture is the single most important step for the codebase's long-term health.
