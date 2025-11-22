📝 TLDR FOR NEXT THREAD: FIXING INPUTS/OUTPUTS

🎯 WHAT WE ACCOMPLISHED IN THIS THREAD
✅ BATCH 1-2: Core Bug Fixed

Problem: Collapsing/expanding composites affected wrong nodes (cross-contamination)
Solution:

Added expanded_composites array to socket assigns (view state)
Fixed parent_composite_id matching logic (strict equality)
Added hidden node filtering in expansion handler


Result: ✅ Expand/collapse works correctly, no cross-contamination

✅ BATCH 3: Visual Features Implemented

Breadcrumb bar: Shows expanded composites with collapse buttons
Category icons & shading: Nodes show emoji (🌱💧♻️⚡) + greyscale backgrounds
Port detection: Backend detects boundary-crossing edges (no visual yet)
Container panels: (Implemented but needs refinement)

✅ Visual Issues Fixed

Reduced node padding (6px/8px) for compact nodes
Fixed expanded node text size (wrapped in spans with 9px font-size)
Hidden node filtering prevents wrong systems from appearing


🔴 CRITICAL ISSUE FOR NEXT THREAD: INPUTS/OUTPUTS
The Problem
Currently, when you expand a composite:

❌ No visual inputs/outputs on expanded nodes
❌ No port indicators showing where external connections enter/exit
❌ Connections don't visually show which inputs/outputs they're using

What We Decided (From Earlier Discussion)
From our architectural planning:

Option A (Port Nodes): When composite expanded, show special boundary marker nodes
Aggregated I/O: Collapsed composites should show combined inputs/outputs from children
Visual ports: Inputs/outputs should be visible on nodes as connection points

Current State

✅ Backend detects ports: detect_boundary_edges/3 function exists (Prompt 11)
✅ Logs show: [PortDetection] Found X input edges, Y output edges
❌ NO visual rendering of inputs/outputs yet
❌ NO port labels on nodes
❌ NO handles for XyFlow connections


📂 RELEVANT FILES & ARTIFACTS
Key Files in Project:

/mnt/project/Permaculture_Systems_Flow_Diagram_-_Prototype.tsx - Original prototype
/mnt/project/DUAL_PANEL_STATE_ARCHITECTURE_md.md - Architecture doc
/mnt/project/gmt_project_brief.txt - Project brief

Current Codebase:

lib/green_man_tavern_web/live/dual_panel_live.ex - LiveView with:

expand_composite_node handler (lines ~1750-1880)
detect_boundary_edges/3 helper (added in Batch 3)


assets/js/xyflow_editor.js - Frontend with:

renderNode function (line ~727)
Hidden node filtering in expansion handler (lines ~1974-2035)



Database Structure:
elixirnodes: %{
  "node_id" => %{
    "name" => "Herb Garden",
    "category" => "food",
    "inputs" => ["water", "sunlight", "soil"],
    "outputs" => ["herbs", "seeds"],
    "parent_composite_id" => "composite_X",
    "x" => 100,
    "y" => 200
  }
}
```

---

## 🎨 DESIGN DECISIONS MADE

From earlier in thread:

1. **Port System (Option A):**
   - Show port nodes as boundary markers
   - Example: `[◄ Water In]` node when composite expanded
   - Ports map to internal node connections

2. **Aggregated I/O on Collapsed Composites:**
   - Collapsed composite shows union of all children's I/O
   - Example: Kitchen System shows ["water", "food_scraps"] inputs

3. **Visual Style:**
   - HyperCard greyscale aesthetic (maintained)
   - Small, compact nodes (achieved)
   - Clear I/O labels (NOT IMPLEMENTED YET)

---

## 🚧 WHAT NEEDS TO HAPPEN NEXT

### **Phase 1: Visual I/O Labels**
Add input/output labels to expanded nodes:
```
┌─────────────┐
│ 🌱 Herb     │
│   Garden    │
├─────────────┤
│ IN:         │
│ • water     │
│ • sunlight  │
├─────────────┤
│ OUT:        │
│ • herbs     │
└─────────────┘
```

### **Phase 2: Port Nodes**
Create special port nodes at composite boundaries:
```
External ──→ [Port In] ──→ Internal Node ──→ [Port Out] ──→ External
```

### **Phase 3: XyFlow Handles**
Add connection handles to nodes for dragging connections

---

## 💬 QUESTIONS FOR NEXT THREAD

**YOU SAID:** You'll provide images and suggestions for I/O implementation

**PLEASE BRING:**
1. Screenshots/mockups of how you want I/O to look
2. Clarification on port node placement
3. Decision on whether I/O labels should be:
   - Always visible?
   - Toggle-able?
   - Only on hover?

---

## 🔗 REFERENCE THIS THREAD

**Start next thread with:**
```
Continuing from previous thread on composite system expand/collapse.

CONTEXT: We fixed the core expand/collapse bug and added visual features (breadcrumbs, icons, etc). Now we need to implement INPUTS/OUTPUTS visualization for nodes and composite systems.

Current state:
- Backend detects ports via detect_boundary_edges/3
- NO visual rendering of I/O yet
- Need to show inputs/outputs on expanded nodes
- Need port nodes at composite boundaries

[Attach relevant screenshots/mockups here]

Please reference the TLDR from the previous thread for full context.

Context Window: ~23,000 tokens remaining (enough for this TLDR!)
