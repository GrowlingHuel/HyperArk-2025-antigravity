# Rack Architecture Retrospective & Rollback Guide

> **Date**: November 28, 2025
> **Purpose**: To document the history, decisions, and current state of the Rack Architecture implementation to assist with a planned Git rollback.

---

## 1. Initial Vision: "The Permaculture Rack"

The goal was to replace the "Living Web" (a free-form XyFlow/Canvas-based system) with a structured, modular "Rack" interface inspired by physical audio equipment and early Macintosh aesthetics.

**Core Principles:**
- **Standard DOM Elements**: Move away from `<canvas>` for better accessibility and styling.
- **SVG Cables**: Use SVG for connecting devices, allowing for "slack" and realistic physics.
- **Database Backed**: Devices and connections stored in Postgres, not just JSON blobs.
- **Strict Grid**: Devices snap to a grid for order and clarity.

---

## 2. Implementation History (Chronological)

### Step 1: Database Foundation (✅ SUCCESS)
We established a robust database schema that should likely be **preserved** or **re-implemented** after rollback.
- **UUIDs**: Switched to UUIDs for `devices` and `patch_cables` to support distributed nature/offline-first potential.
- **Tables**:
    - `devices`: Stores device state, settings (JSONB), and position.
    - `patch_cables`: Stores connections between `source_device_id/port` and `target_device_id/port`.
- **Contexts**: Created `GreenManTavern.Rack` context with standard CRUD.

### Step 2: Frontend Core (✅ SUCCESS)
- **`RackComponent`**: A new LiveComponent to handle the rack view.
- **SVG Layer**: An SVG overlay for drawing cubic bezier curves between DOM elements.
- **Jack Coordinates**: A system to calculate the exact `(x, y)` screen coordinates of input/output jacks based on DOM element positions.

### Step 3: The "Infinite Rack" Experiment (❌ FAILED)
We attempted to implement a pan/zoomable "Infinite Canvas" using CSS transforms.
- **Why**: To allow for unlimited devices.
- **Result**:
    - **Complexity**: Calculating jack coordinates across transformed coordinate spaces became extremely difficult.
    - **UX**: The "black void" aesthetic was rejected.
    - **Performance**: Dragging and zooming caused jitter.
- **Outcome**: **REVERTED** back to a fixed grid.

### Step 4: Refinement & "Strict Grid" (⚠️ MIXED)
We pivoted back to a "Strict Grid" (3-column CSS Grid) with a fixed container width.
- **Pros**: Perfect alignment, simpler cable math.
- **Cons**:
    - **Responsiveness**: The fixed width (900px) fights against the responsive nature of the main application layout.
    - **Rigidity**: Hard to adapt to different screen sizes (mobile vs desktop).
    - **Jack Calculation**: Still relies on assumptions about device width/height that break if CSS changes.

---

## 3. What Went Wrong (The "Why" of the Rollback)

### 1. Coordinate System Fragility
The most critical failure point is the **Jack Coordinate System**.
- **The Problem**: We calculate cable start/end points based on the *assumed* position of DOM elements.
- **The Reality**: CSS Flexbox/Grid layouts are dynamic. If a sidebar opens, or the window resizes, the DOM elements move, but the SVG coordinates might not update instantly or correctly.
- **Result**: Cables "detaching" visually from their jacks, requiring complex `ResizeObserver` logic and `handle_event("resize", ...)` hooks that are brittle.

### 2. State Synchronization Complexity
- **The Problem**: Keeping the LiveView state (`devices`, `cables`) in sync with the client-side DOM positions (`getBoundingClientRect`) proved difficult.
- **Result**: "Jumping" cables, lag during updates, and race conditions where the server thinks a device is at X,Y but the client renders it at X',Y'.

### 3. "God Component" Creep
- **The Problem**: `RackComponent` started becoming a new "God Object," handling layout, device logic, cable physics, drag-and-drop, and modal editing all in one file.
- **Result**: Hard to maintain and debug.

---

## 4. What To Keep (Golden Nuggets)

Even with a rollback, the following architectural decisions were **correct** and should be retained or restored:

1.  **The Database Schema**: The `devices` and `patch_cables` tables with UUIDs are solid.
2.  **The "System" Concept**: The idea of "Composite Systems" (grouping devices) is powerful.
3.  **SVG for Cables**: Using SVG is still the right approach, but the *coordinate calculation* needs to be simpler (e.g., relative to the device, not the page).
4.  **LiveComponent Architecture**: Breaking the UI into `RackComponent`, `DeviceComponent`, etc., is the right path.

---

## 5. Recommendations for Re-Implementation

When you roll back and start again:

1.  **Simplify Coordinates**: Instead of global page coordinates, use **relative coordinates** within the Rack container.
2.  **CSS-First Layout**: Let CSS handle the layout entirely. Don't try to manually position devices with absolute positioning unless necessary.
3.  **Canvas for Cables?**: Re-evaluate if a simple HTML5 Canvas overlay *just for cables* might be more performant than hundreds of SVG paths, although SVG is easier to style.
4.  **Separate "Editor" from "Runtime"**: Maybe the "patching" mode should be distinct from the "using" mode to simplify the UI.

---

## 6. Rollback Checklist

- [ ] **Git Revert**: Identify the commit before the "Infinite Rack" or even before the `RackComponent` became too complex.
- [ ] **Database Migration**: Decide if you need to roll back the DB migrations. **Recommendation**: Keep the migrations if they don't conflict with the old code, as they are good.
- [ ] **Asset Cleanup**: Remove unused assets (images, icons) added during this sprint.
