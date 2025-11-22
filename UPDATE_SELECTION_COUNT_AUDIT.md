# updateSelectionCount Function Audit

## 1. The Function (Lines 3827-3850)

```javascript
// Update the toolbar selection counter based on current selection set
XyflowEditorHook.updateSelectionCount = function() {
  const countEl = document.getElementById('selection-count');
  if (countEl) {
    const nodeCount = this.selectedNodes ? this.selectedNodes.size : 0;
    const edgeCount = this.selectedEdges ? this.selectedEdges.size : 0;
    const total = nodeCount + edgeCount;
    
    let text = '';
    if (nodeCount > 0 && edgeCount > 0) {
      text = `${nodeCount} node${nodeCount !== 1 ? 's' : ''}, ${edgeCount} edge${edgeCount !== 1 ? 's' : ''} selected`;
    } else if (nodeCount > 0) {
      text = `${nodeCount} node${nodeCount !== 1 ? 's' : ''} selected`;
    } else if (edgeCount > 0) {
      text = `${edgeCount} edge${edgeCount !== 1 ? 's' : ''} selected`;
    } else {
      text = '0 selected';
    }
    countEl.textContent = text;
  }
  
  // Send selection to LiveView
  if (this.pushEvent) {
    const nodeIds = this.selectedNodes || [];
    // Prompt 1: Log before pushing selection event
    console.log("📍 PUSHING nodes_selected FROM:", new Error().stack);
    console.log("Pushing selection event: nodes_selected", { node_ids: nodeIds });
    this.pushEvent("nodes_selected", { node_ids: nodeIds });
  }
  
  // Also update Connect button state and Save as System button state
  this.updateConnectButtonState();
  this.updateSaveAsSystemButtonState();
};
```

**Key Point**: This function pushes `nodes_selected` events to the backend. Line 3842 now has stack trace logging.

## 2. All Call Sites (13 total)

### Line 160: edges_deleted_success handler
```javascript
if (this.selectedEdges) {
  this.selectedEdges.clear();
}
console.log("📍 CALLING updateSelectionCount FROM:", new Error().stack);
this.updateSelectionCount();
```

### Line 268-270: nodes_deleted_success handler
```javascript
if (this.updateSelectionCount) {
  console.log("📍 CALLING updateSelectionCount FROM:", new Error().stack);
  this.updateSelectionCount();
}
```

### Line 289-291: nodes_hidden_success handler
```javascript
if (this.updateSelectionCount) {
  console.log("📍 CALLING updateSelectionCount FROM:", new Error().stack);
  this.updateSelectionCount();
}
```

### Line 310-312: canvas_cleared handler
```javascript
if (this.updateSelectionCount) {
  console.log("📍 CALLING updateSelectionCount FROM:", new Error().stack);
  this.updateSelectionCount();
}
```

### Line 527-529: renderNodes() function
```javascript
// Ensure selection count reflects current state after re-render
if (this.updateSelectionCount) {
  console.log("📍 CALLING updateSelectionCount FROM:", new Error().stack);
  this.updateSelectionCount();
}
```

### Line 1174-1176: Checkbox click handler (in renderNode)
```javascript
// Update selection counter in toolbar
if (this.updateSelectionCount) {
  console.log("📍 CALLING updateSelectionCount FROM:", new Error().stack);
  this.updateSelectionCount();
}
```

### Line 2093-2094: Drag handler (when clicking unselected node)
```javascript
this.syncCheckboxState(element);
console.log("📍 CALLING updateSelectionCount FROM:", new Error().stack);
this.updateSelectionCount();
```

### Line 2636-2637: clearSelection() function
```javascript
// Clear edge selections
this.clearEdgeSelection();

console.log("📍 CALLING updateSelectionCount FROM:", new Error().stack);
this.updateSelectionCount();
```

### Line 3094-3096: node_add_success handler
```javascript
// Update selection count
if (this.updateSelectionCount) {
  console.log("📍 CALLING updateSelectionCount FROM:", new Error().stack);
  this.updateSelectionCount();
}
```

### Line 3182-3184: Checkbox click handler (in addTemporaryNode)
```javascript
// Update selection counter in toolbar
if (this.updateSelectionCount) {
  console.log("📍 CALLING updateSelectionCount FROM:", new Error().stack);
  this.updateSelectionCount();
}
```

### Line 3366-3368: Checkbox click handler (in renderCompositeNode)
```javascript
if (this.updateSelectionCount) {
  console.log("📍 CALLING updateSelectionCount FROM:", new Error().stack);
  this.updateSelectionCount();
}
```

### Line 3904-3905: selectEdge() function
```javascript
// Update selection count
console.log("📍 CALLING updateSelectionCount FROM:", new Error().stack);
this.updateSelectionCount();
```

### Line 3913-3914: clearEdgeSelection() function
```javascript
this.selectedEdges.clear();
this.renderEdges();
console.log("📍 CALLING updateSelectionCount FROM:", new Error().stack);
this.updateSelectionCount();
```

## 3. Stack Trace Logging Added

✅ **ALL 13 call sites now have stack trace logging** with:
```javascript
console.log("📍 CALLING updateSelectionCount FROM:", new Error().stack);
```

✅ **The function itself (line 3842) also has stack trace logging** when pushing nodes_selected:
```javascript
console.log("📍 PUSHING nodes_selected FROM:", new Error().stack);
```

## What This Will Show

When `updateSelectionCount()` is called, you'll see:
1. **📍 CALLING updateSelectionCount FROM:** - Shows the call stack of who called the function
2. **📍 PUSHING nodes_selected FROM:** - Shows the call stack when it actually pushes the event

This will help identify:
- Which code path is triggering selection updates
- If checkbox clicks are calling updateSelectionCount (which then pushes nodes_selected)
- If drag handlers are interfering
- If renderNodes() is causing unwanted selection pushes

## Potential Issues

1. **Checkbox handlers (lines 1174, 3182, 3366)** - These call updateSelectionCount, which pushes nodes_selected. This might be interfering with the main node click handler.

2. **renderNodes() (line 527)** - Calls updateSelectionCount after every render, which might push selection events even when not needed.

3. **Drag handler (line 2093)** - Calls updateSelectionCount when clicking unselected nodes during drag setup.



