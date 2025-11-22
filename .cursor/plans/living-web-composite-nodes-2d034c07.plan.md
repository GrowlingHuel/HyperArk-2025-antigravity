<!-- 2d034c07-83b0-4ac8-90d2-83ab9247b154 dc211076-30e2-4491-a8e1-f73eec1766d3 -->
# Living Web Composite Node System Implementation

## Overview

Enable users to collapse connected nodes into composite system nodes that can be dragged onto the canvas as placeholders, expanded via double-click, edited after creation, and nested recursively.

## Architecture Changes

### 1. Data Model Extensions

**Backend: CompositeSystem Schema (already exists)**

- Already has: `internal_node_ids`, `internal_edge_ids`, `external_inputs`, `external_outputs`
- Need to track: composite system instances on canvas

**Backend: Diagram Schema Enhancement**

- Nodes map needs to differentiate between:
- Regular project nodes: `{"project_id": 123, "x": 100, "y": 200}`
- Composite instances: `{"composite_system_id": 45, "x": 300, "y": 400, "is_expanded": false}`

**Key files:**

- `lib/green_man_tavern/diagrams/diagram.ex` - nodes structure
- `lib/green_man_tavern/diagrams/composite_system.ex` - existing schema
- `lib/green_man_tavern/diagrams.ex` - context functions

### 2. Frontend Node Type

**New React Component: CompositeSystemNode**

- Create `assets/js/nodeTypes/CompositeSystemNode.jsx`
- Visual design: Double border (HyperCard folder aesthetic)
- Display: Name, small indicator of internal complexity
- States: collapsed (placeholder) vs expanded (showing internal nodes)
- Handles: Dynamic based on `external_inputs`/`external_outputs`

**Integration:**

- Update `assets/js/components/LivingWebDiagram.jsx` to register composite node type
- Update `assets/js/hooks/xyflow_editor.js` rendering logic

### 3. Drag-and-Drop for Composites

**Frontend: Library Item Handling**

- Extend `setupLibraryItemDrag()` in `xyflow_editor.js` (line ~1348)
- Currently only handles `data-project-id`, add support for `data-composite-id`
- Differentiate drop payload: `{type: 'project', id: 123}` vs `{type: 'composite', id: 45}`

**Backend: Node Creation Handler**

- Extend `handle_event("node_added", ...)` in `dual_panel_live.ex` (line ~55)
- Add new handler: `handle_event("composite_node_added", ...)`
- Create node entry with `composite_system_id` instead of `project_id`
- Return composite data (name, icon, external_inputs, external_outputs)

### 4. Expansion/Collapse System

**Frontend: Double-Click Handler**

- Add `onNodeDoubleClick` handler in `xyflow_editor.js`
- Detect if node is composite type
- Push event to backend: `expand_composite_node` or `collapse_composite_node`

**Backend: Expansion Logic**

- `handle_event("expand_composite_node", %{"node_id" => node_id}, socket)`
- Load composite system data
- Set `is_expanded: true` on node
- Calculate position offset for internal nodes
- Add internal nodes to diagram at offset positions
- Add internal edges
- Return updated nodes/edges

**Backend: Collapse Logic**

- `handle_event("collapse_composite_node", %{"node_id" => node_id}, socket)`
- Remove internal nodes from canvas
- Remove internal edges
- Set `is_expanded: false`
- Keep composite node placeholder

**Frontend: Visual State**

- Render expanded composites with visual boundary (grey dashed border)
- Show internal nodes within boundary
- Collapsed: single composite node

### 5. Connection Handling

**Input/Output Mapping**

- Composite nodes expose `external_inputs` and `external_outputs` as connection handles
- When edge connects to composite input:
- If collapsed: edge connects to composite node handle
- If expanded: edge routes to appropriate internal node
- Edge persistence tracks both scenarios

**Edge Routing**

- Collapsed composite: edges terminate at composite node
- Expanded composite: edges pass through to internal nodes
- Backend tracks: `{source_id: "node_x", target_id: "composite_y", target_input: "water"}`

### 6. Editing Composite Systems

**Edit UI Flow**

1. User expands composite (double-click)
2. Internal nodes become editable on canvas
3. User can:

- Add new nodes inside
- Remove nodes
- Modify connections
- Adjust positions

4. "Update System" button saves changes back to composite definition

**Backend: Update Handler**

- `handle_event("update_composite_system", params, socket)`
- Extract internal node IDs and edge IDs from current canvas state
- Re-infer external inputs/outputs
- Update CompositeSystem record via `Diagrams.update_composite_system/2`

### 7. Nesting Support

**Recursive Composition**

- Composite systems can contain nodes that are themselves composite instances
- No depth limit enforced (user can nest infinitely)
- Expansion recursively loads nested composites
- Visual indication: nested composites show small icon/badge

**Data Integrity**

- Prevent circular references: composite A contains composite B contains composite A
- Backend validation when saving/updating composites
- Check dependency chain before allowing save

### 8. UI/UX Details (HyperCard Aesthetic)

**Composite Node Styling**

- Double 2px border: outer `#000`, inner `#666` with 4px gap
- Background: `#E8E8E8` (slightly darker than regular nodes)
- Icon: 📦 or folder icon
- Font: Chicago/Geneva
- No rounded corners

**Expanded Boundary**

- Dashed grey border `#999` around internal nodes
- Semi-transparent background overlay
- Title bar showing composite name
- Collapse button (small X or ◀ icon)

**Library Section**

- Already exists: "MY SYSTEMS" section showing composites
- Add drag affordance styling on hover
- Show count of internal nodes: "My Garden (5 nodes)"

## Implementation Steps

### Phase 1: Data & Backend Foundation

1. Add helper to distinguish node types in Diagram context
2. Implement `composite_node_added` event handler
3. Implement `expand_composite_node` handler
4. Implement `collapse_composite_node` handler
5. Add circular dependency validation

### Phase 2: Frontend Node Type

1. Create CompositeSystemNode.jsx component
2. Register in LivingWebDiagram nodeTypes
3. Update node rendering in xyflow_editor.js
4. Add double-click handler

### Phase 3: Drag-and-Drop

1. Update library item drag to include composite-id
2. Update drop handler to differentiate types
3. Test dragging composites onto canvas

### Phase 4: Expansion UI

1. Implement expansion visual boundary
2. Position internal nodes relative to composite
3. Handle edge rendering for expanded state
4. Add collapse button

### Phase 5: Connection System

1. Generate dynamic handles for composite nodes
2. Update edge creation to handle composite targets
3. Test edge persistence across expand/collapse

### Phase 6: Editing & Updates

1. Add "Update System" button to expanded view
2. Implement update handler
3. Re-infer inputs/outputs after edit
4. Handle cascading updates (if composite used multiple times)

### Phase 7: Nesting & Polish

1. Test nested composites (composite within composite)
2. Add visual badges for nested composites
3. Circular dependency prevention
4. Performance optimization for deep nesting

## Key Files to Modify

**Backend:**

- `lib/green_man_tavern/diagrams.ex` - add helper functions
- `lib/green_man_tavern_web/live/dual_panel_live.ex` - event handlers
- `lib/green_man_tavern/diagrams/composite_system.ex` - validation

**Frontend:**

- `assets/js/nodeTypes/CompositeSystemNode.jsx` - NEW
- `assets/js/hooks/xyflow_editor.js` - drag/drop, double-click, rendering
- `assets/js/components/LivingWebDiagram.jsx` - node type registration
- `lib/green_man_tavern_web/live/dual_panel_live.html.heex` - library items

**Styles:**

- `assets/css/app.css` - composite node styling (inline in component preferred)

## Testing Considerations

- Drag composite from library → appears as placeholder
- Double-click composite → expands to show internals
- Edit internal structure → save updates composite
- Collapse composite → internal nodes hidden
- Connect edges to composite inputs/outputs
- Nest composite A inside composite B → both work
- Prevent composite A containing itself (circular)
- Multiple instances of same composite on canvas

### To-dos

- [ ] Add helper functions to Diagrams context for node type detection and composite instance management
- [ ] Implement composite_node_added event handler in dual_panel_live.ex
- [ ] Implement expand_composite_node event handler with positioning logic
- [ ] Implement collapse_composite_node event handler
- [ ] Add circular dependency validation to prevent infinite nesting loops
- [ ] Create CompositeSystemNode.jsx React component with HyperCard styling
- [ ] Register CompositeSystemNode in LivingWebDiagram nodeTypes
- [ ] Add double-click detection and handler in xyflow_editor.js
- [ ] Extend setupLibraryItemDrag to handle data-composite-id attributes
- [ ] Update drop handler to differentiate and handle composite drops
- [ ] Implement visual boundary rendering for expanded composites
- [ ] Calculate and apply position offsets for internal nodes during expansion
- [ ] Add collapse button to expanded composite boundary
- [ ] Generate dynamic connection handles based on external_inputs/outputs
- [ ] Update edge creation/rendering to handle composite node targets
- [ ] Add Update System button to expanded composite view
- [ ] Implement update_composite_system event handler with re-inference
- [ ] Test and debug nested composites (composite containing composite)
- [ ] Add visual indicators for nested composite nodes
- [ ] End-to-end testing: create, drag, expand, edit, nest composites