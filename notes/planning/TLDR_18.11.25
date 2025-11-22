📋 COMPREHENSIVE TLDR - GREEN MAN TAVERN LIVING WEB SYSTEM

🎯 PROJECT OVERVIEW
Green Man Tavern is a modular, database-driven, Permaculture-based real-life RPG game/app built with:

Backend: Phoenix LiveView (Elixir)
Frontend: Minimal XyFlow integration with custom JavaScript hooks
Development: Cursor.AI for AI-assisted coding
Visual Style: HyperCard-inspired (grayscale, sharp corners, system fonts)


✅ FEATURES BUILT IN THIS SESSION
1. Visual I/O System

I/O Count Badges (▲N ▼M) on nodes showing input/output counts
Hover Tooltips listing all potential inputs/outputs
Auto-Resize Nodes based on actual connections (compact by default)
Port Boxes - Grey squares on node edges showing actual connections

Left side: Inputs (green hover)
Right side: Outputs (orange hover)
Only shown for actual connections (keeps nodes compact)



2. Detail Sidebar Panel

Info Button (ℹ️) on bottom-right of each node
Sidebar Display showing:

Node name and category
Actual inputs (connected) vs Potential inputs
Actual outputs (connected) vs Potential outputs
Connection sources and destinations


HyperCard Styling throughout

3. Connection System

Drag-to-Connect: Drag from output port to input port

Orange dashed line follows cursor
Creates connection on compatible drop


Click-to-Connect: Click output → highlights compatible inputs → click input

Incompatible ports dimmed
Click elsewhere to cancel


Visual Edges: Green solid lines with resource labels
Resource Matching: Only compatible resources can connect

4. Potential Connections

Orange Dashed Lines showing possible connections between compatible nodes
Click-to-Create: Click potential edge to create actual connection
Auto-Detection: Finds unconnected outputs with matching unconnected inputs
Updates Dynamically when connections change

5. Smart Recommendations (Suggestions Button)

Analyzes System for opportunities:

Isolated Nodes: Nodes with no connections (high priority - red badge)
Unused Outputs: Resources produced but not used (medium priority - orange badge)
Incomplete Loops: One-way flows that could be circular (medium priority - orange badge)


Action Panel: Modal with HyperCard styling
Apply Button: Act on suggestions
Sorted by Priority: High → Medium → Low

6. Composite System Improvements

Hide When Expanded: Composite nodes disappear from canvas when expanded
Breadcrumb Bar: Expanded composites show in top bar with [×] to collapse
Aggregated I/O: Collapsed composites show union of all children's I/O
Edge Rerouting: Connections automatically route to/from child nodes when expanded
Smooth Animations: Fade transitions when expanding/collapsing (attempted)

7. Undo/Redo System

Full History Tracking: Up to 50 actions saved
Keyboard Shortcuts:

Ctrl+Z / Cmd+Z - Undo
Ctrl+Shift+Z / Ctrl+Y / Cmd+Shift+Z / Cmd+Y - Redo


Tracks: Node add/move/delete, edge add/delete, connections, expand/collapse

8. Keyboard Shortcuts

Undo/Redo: Ctrl+Z, Ctrl+Y
Delete: Delete or Backspace (deletes selected nodes)
Deselect: Escape
Select All: Ctrl+A
Pan Canvas: Arrow keys (Shift for 50px, normal for 10px)
Zoom: +/- keys or Ctrl+Wheel
Reset View: 0 key
Help: ? (placeholder for help modal)

9. Zoom and Pan

Mouse Wheel Zoom: Ctrl+Wheel zooms canvas (not page)
Keyboard Zoom: +/- keys
Arrow Key Pan: Move canvas up/down/left/right
Reset: 0 key resets to 100% zoom, 0,0 pan
Transform Applied: To both SVG container (edges) and nodes container

10. Multi-Select (Partial)

Marquee Selection: Click-drag on canvas creates blue dashed selection box
Shift+Click: Toggle individual node selection (NEEDS FIX)
Visual Highlight: Selected nodes show blue outline and glow
Selection Toolbar: Floating toolbar at bottom showing count, Delete, Clear buttons
Bulk Operations: Delete multiple nodes at once


🗂️ KEY FILES AND LOCATIONS
Backend (Elixir)
Main LiveView: lib/green_man_tavern_web/live/dual_panel_live.ex

Mount: Lines ~50-125 (initialize state)
Event Handlers: Lines ~1200-2500

node_added, node_moved, nodes_deleted
edge_added, edges_deleted, create_connection
expand_composite_node, collapse_composite_node
show_suggestions, apply_suggestion
undo, redo
bulk_delete, deselect_all


Helper Functions: Lines ~3000-4000

calculate_node_io_data (~3320)
detect_potential_connections (~3469)
analyze_system_opportunities (~3469-3610)
aggregate_composite_io (~3610)
reroute_edges_for_expanded_composite (~3808)
save_state_to_history (~3900)



Template: lib/green_man_tavern_web/live/dual_panel_live.html.heex

Breadcrumb Bar: ~226 (Expanded composites)
Toolbar: ~200-300 (buttons)
Detail Sidebar: ~400-800
Opportunities Panel: ~2515-2667
Selection Toolbar: Near end (bulk operations)

Frontend (JavaScript)
XyFlow Hook: assets/js/hooks/xyflow_editor.js

Mounted: Lines ~60-180 (initialization, event listeners)
Render Functions:

renderNodes (~900-1800)
renderEdges (~550-850)
render (~400-500, orchestrates rendering)


Connection Handlers:

Drag-to-connect (~2100-2300)
Click-to-connect (~2300-2500)


Keyboard Shortcuts: setupKeyboardShortcuts (~4204-4314)
Zoom/Pan: setupZoomAndPan (~4316), applyZoomTransform (~4335)
Marquee Selection: setupMarqueeSelection (~4370)
Port Rendering: ~1130-1350


🏗️ ARCHITECTURE OVERVIEW
Data Flow
1. User Action (click, drag, keyboard)
   ↓
2. JavaScript Hook captures event
   ↓
3. pushEvent() sends to LiveView backend
   ↓
4. Backend handler processes (updates state, database)
   ↓
5. Backend pushes updated data via push_event()
   ↓
6. Frontend handleEvent() receives updates
   ↓
7. render() updates visual display
State Management
Backend Assigns (LiveView Socket):

nodes - Map of all nodes %{node_id => node_data}
edges - Map of all edges %{edge_id => edge_data}
expanded_composites - List of expanded composite IDs
selected_nodes - List of selected node IDs
opportunities - List of detected opportunities
history_stack - List of state snapshots for undo/redo
history_index - Current position in history

Frontend State (JavaScript Hook):

this.nodes - Nodes object from backend
this.edges - Edges object from backend
this.potentialEdges - Calculated potential connections
this.expandedComposites - List of expanded composites
this.selectedNodes - Array of selected node IDs
this.zoomLevel - Current zoom (1 = 100%)
this.panX, this.panY - Pan offset

Connection Lifecycle

Detection: Backend calculates potential connections
Visualization: Frontend renders orange dashed lines
User Action: Click/drag to create connection
Creation: Backend creates edge in database
Confirmation: Backend pushes updated edges
Display: Frontend renders green solid line
Port Update: Port boxes appear on connected nodes


⚠️ KNOWN ISSUES
HIGH PRIORITY

Shift+Click Selection Not Working

Symptom: Shift+Click doesn't toggle node selection
Cause: Click handler may be overridden or not attached
Fix: Verify handler in renderNode() with console.log debugging


Selection Toolbar Stuck

Symptom: Toolbar shows "1 node selected" and never disappears
Cause: Backend @selected_nodes not clearing or not syncing with frontend
Fix: Verify selection_cleared event pushes and frontend handles it
Debug: Yellow debug box added to show actual @selected_nodes value


Edge Positioning Not Precise

Symptom: Edges connect to node boundaries, not exact port positions
Cause: Edge calculations use node center/edge, not port coordinates
Status: Cosmetic issue, functionally correct
Future: Calculate exact port Y positions for perfect alignment



MEDIUM PRIORITY

Composite Expand/Collapse Animations

Symptom: Animations may not be smooth or working
Cause: setTimeout timing or render conflicts
Status: Needs testing and refinement


Missing Edges for Deleted Nodes

Symptom: Console warnings about edges to non-existent nodes
Cause: Old edges not cleaned up properly
Status: Frontend skips rendering (safe), but backend cleanup needed



LOW PRIORITY

Zoom Transform Origin

May need adjustment for natural zoom feel
Currently zooms from top-left (0,0)


Pan Limits

No boundaries, can pan infinitely
Could add canvas bounds checking




🚀 FUTURE ENHANCEMENTS
Phase 2: Visual Polish

Edge-to-Port Snapping: Calculate exact port positions for edge endpoints
Connection Animations: Animate edge creation/deletion
Node Drag Selection: Improve multi-select UX
Custom Cursors: Context-aware cursors (grab, pointer, crosshair)
Minimap: Overview of entire canvas with viewport indicator

Phase 3: Advanced Features

Connection Bundling: Multiple resources in single edge
Node Templates: Save/load node configurations
Auto-Layout: Automatic node positioning algorithms
Search/Filter: Find nodes by name, category, resource type
Export/Import: Save entire system diagrams
Collaboration: Multi-user editing (future)

Phase 4: Permaculture Intelligence

Opportunity Detection: More sophisticated pattern recognition
Resource Flow Simulation: Show what flows where
System Health Metrics: Track system completeness
AI Suggestions: LLM-powered system design recommendations
Guild Patterns: Pre-built permaculture patterns

Phase 5: Game Integration

Character Interaction: Characters interact with systems
Time Progression: Systems evolve over time
Resource Tracking: Actual resource quantities
Events System: Weather, seasons, disasters
Quests/Achievements: Related to system building


🐛 DEBUGGING GUIDE
When Connections Don't Work

Check console for "create_connection" event
Verify resource types match (source output = target input)
Check backend handler receives event
Verify edge added to database
Check edges_updated event pushed to frontend

When Nodes Don't Render

Check nodes_updated event in console
Verify this.nodes has data
Check renderNode() is being called
Look for JavaScript errors in console
Verify node has required fields (id, name, x, y)

When Selection Doesn't Work

Check yellow debug box value
Look for "Node clicked" in console
Verify nodes_selected event sent to backend
Check backend @selected_nodes assign
Verify toolbar condition evaluates correctly

Console Commands (for debugging)
javascript// In browser console:
window.xyflowHook.nodes // See all nodes
window.xyflowHook.edges // See all edges
window.xyflowHook.selectedNodes // See selection
window.xyflowHook.zoomLevel // Check zoom
window.xyflowHook.render() // Force re-render

📝 QUICK START FOR NEXT SESSION
To Continue Development:

Review this TLDR - Understand current state
Test Current Features - Identify what works/doesn't
Fix Selection Issues - Priority #1

Use yellow debug box to diagnose
Check console logs for Shift+Click
Verify event flow: frontend → backend → frontend


Polish Edge Positioning - If desired

Calculate exact port Y positions
Update edge path calculations


Remove Debug Elements - Yellow box, extra console.logs

Common Commands:
bash# Start server
mix phx.server

# Compile assets
cd assets && npm run build

# Reset database (if needed)
mix ecto.reset
Key Search Terms (in code):

"selectedNodes" - Selection system
"create_connection" - Connection logic
"potential_edges" - Opportunity detection
"save_state_to_history" - Undo/redo
"setupKeyboardShortcuts" - Keyboard handling
"renderEdges" - Edge visualization


💡 IMPORTANT NOTES
Cursor.AI Context:

Always provide plain language instructions first
Request specific prompts rather than code (saves context)
Only request actual code when absolutely necessary
Batching multiple related changes is efficient

Testing Workflow:

Make changes in Cursor
Restart Phoenix server (Ctrl+C then mix phx.server)
Hard refresh browser (Ctrl+Shift+R or Cmd+Shift+R)
Check console for errors/logs
Test feature systematically

Code Style:

Backend: Elixir functional style, pattern matching
Frontend: Vanilla JavaScript (no frameworks except XyFlow)
UI: HyperCard aesthetic (grayscale, sharp borders, system fonts)
Events: Always use phx-click, pushEvent, handleEvent pattern


📊 SESSION STATISTICS
Features Implemented: 10 major systems
Batches Completed: 9 (Batch 1-9)
Files Modified: 3 main files (dual_panel_live.ex, .html.heex, xyflow_editor.js)
Lines Added: ~2000+ lines
Time Investment: ~4-5 hours (estimated)
Context Window Used: ~170,000 tokens
Completion Status: ~85% (core features done, polish needed)

🎯 NEXT SESSION PRIORITIES

✅ Fix Selection System (Shift+Click, toolbar persistence)
🎨 Edge Visual Polish (snap to ports)
🧹 Remove Debug Elements (yellow box, excess logging)
✨ Test All Features (comprehensive QA)
🚀 Phase 2 Planning (based on priorities)


📞 CONTACT POINTS FOR NEXT AI ASSISTANT
When starting the next session, share this TLDR and mention:

"We built a visual node editor for permaculture systems"
"Selection toolbar and Shift+Click need debugging"
"All code is in dual_panel_live.ex, .html.heex, and xyflow_editor.js"
"Yellow debug box shows backend selection state"
"Need to verify event flow: frontend ↔ backend"


🎓 KEY LEARNINGS

LiveView + JavaScript: Phoenix LiveView handles state, JS handles visual rendering
Event-Driven: All interactions go through pushEvent → handleEvent flow
Incremental Rendering: Only re-render what changed (performance)
State Sync Critical: Frontend and backend must stay in sync
Debug Early: Add logging/debug UI early to diagnose issues
Batch Changes: Group related features for efficiency
Test Incrementally: Verify each batch before moving to next


END OF TLDR - Ready for Next Session! 🚀
