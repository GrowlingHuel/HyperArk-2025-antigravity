/**
 * SVG Flow Editor Hook for Phoenix LiveView
 * 
 * Simple node-based editor for the Living Web system.
 * Uses vanilla JS with DOM manipulation - no React needed.
 */

const GRID_SIZE = 20;

function snapToGrid(position) {
  return {
    x: Math.round(position.x / GRID_SIZE) * GRID_SIZE,
    y: Math.round(position.y / GRID_SIZE) * GRID_SIZE
  };
}

// Collision detection helper using spiral search and grid snapping
function findNonOverlappingPosition(x, y, existingNodes) {
  const SPACING = 50; // minimum distance between nodes
  let finalX = Math.round(x / GRID_SIZE) * GRID_SIZE;
  let finalY = Math.round(y / GRID_SIZE) * GRID_SIZE;
  let attempts = 0;
  const maxAttempts = 20;

  const isTooClose = (px, py) => {
    return existingNodes.some((node) => {
      const nx = typeof node.x === 'number' ? node.x : (node.position && node.position.x) || 0;
      const ny = typeof node.y === 'number' ? node.y : (node.position && node.position.y) || 0;
      const dx = nx - px;
      const dy = ny - py;
      const distance = Math.sqrt(dx * dx + dy * dy);
      return distance < SPACING;
    });
  };

  while (attempts < maxAttempts && isTooClose(finalX, finalY)) {
    const angle = (attempts / maxAttempts) * Math.PI * 2;
    const radius = 50 + attempts * 20;
    finalX = x + Math.cos(angle) * radius;
    finalY = y + Math.sin(angle) * radius;
    const snapped = snapToGrid({ x: finalX, y: finalY });
    finalX = snapped.x;
    finalY = snapped.y;
    attempts++;
  }

  return { x: finalX, y: finalY };
}

const XyflowEditorHook = {
  mounted() {
    console.log("=== XyflowEditor Hook Mounted ===");
    console.log("Container element:", this.el);
    this.container = this.el;
    this.nodes = [];
    this.edges = [];
    this.potentialEdges = [];
    this.expandedComposites = []; // Track expanded composite node IDs
    this.selectedNode = null;
      // PART 3: Ensure selectedNodes initialization
      this.selectedNodes = [];
      this.selectedEdges = new Set(); // Track selected edges
      this.marqueeActive = false; // Marquee selection state
      this.marqueeStart = null; // Marquee start position
      this.connectingPort = null; // Track port connection in progress
      this.dragState = null; // For drag-to-connect
      this.tempLine = null; // Temporary SVG line during drag
      this.clickState = null; // For click-to-connect
      this.isDraggingNode = false; // Flag to prevent bounds updates during drag
      this.isMarqueeSelecting = false; // Flag for marquee selection box
      this.marqueeBox = null; // DOM element for selection box
      this.marqueeStartX = 0;
      this.marqueeStartY = 0;
      this.isPanningCanvas = false; // Flag to distinguish canvas panning from marquee selection
      this.zoomLevel = 1; // Zoom level (1 = 100%)
      this.panX = 0; // Pan X offset
      this.panY = 0; // Pan Y offset
      this.showKeyboardHelp = false; // Keyboard shortcuts help panel
      
      // Load initial nodes, edges, and projects from data attributes
      this.loadInitialData();
    
    // Log container dimensions
    console.log("Container dimensions:", { width: this.el.offsetWidth, height: this.el.offsetHeight });

    // Render the nodes
    this.renderNodes();
    
      // Setup drag and drop
      this.setupDragAndDrop();
      // Setup marquee selection
      this.setupMarqueeSelection();
      // Setup toolbar action buttons
      this.setupToolbarButtons();
    
    // Setup library item drag handlers
    this.setupLibraryItemDrag();
    
    // Setup server event listeners
    this.setupServerEvents();
    
    // Setup keyboard shortcuts
    this.setupKeyboardShortcuts();
    
    // Setup zoom and pan controls
    this.setupZoomAndPan();

    // Debug: log nodes_updated events pushed from server
    this.handleEvent("nodes_updated", ({ nodes }) => {
      console.log("Nodes updated:", nodes);
      console.log("Node count:", Array.isArray(nodes) ? nodes.length : (nodes && Object.keys(nodes).length) || 0);
      
      if (nodes) {
        const normalizedNodes = this.normalizeNodes(nodes);
        
        // Filter out expanded composite nodes
        const visibleNodes = normalizedNodes.filter(node => {
          if (this.expandedComposites.includes(node.id)) {
            console.log('[NodesUpdated] Filtering out expanded composite node:', node.id);
            return false;
          }
          return true;
        });
        
        this.nodes = visibleNodes;
        this.renderNodes();
        this.renderEdges();
      }
      
      if (Array.isArray(nodes) && nodes.length > 0) {
        console.log("First node structure:", JSON.stringify(nodes[0], null, 2));
      }
      // Update edges if provided and re-render
      if (edges !== undefined) {
        this.edges = edges;
        this.renderEdges();
      }
    });
    
    // Listen for edge added/updated events
    this.handleEvent("edge_added_success", ({ edges }) => {
      console.log("Edge added successfully, edges:", edges);
      if (edges !== undefined) {
        this.edges = edges;
        this.renderEdges();
      }
    });

    // Listen for edges deleted
    this.handleEvent("edges_deleted_success", ({ edges }) => {
      console.log("Edges deleted successfully, edges:", edges);
      if (edges !== undefined) {
        this.edges = edges;
        this.renderEdges();
        // Clear edge selection
        if (this.selectedEdges) {
          this.selectedEdges.clear();
        }
        this.updateSelectionCount();
      }
    });

    // Listen for edges updated (from create_connection)
    this.handleEvent("edges_updated", ({ edges }) => {
      console.log("Edges updated, edges:", edges);
      if (edges !== undefined) {
        this.edges = edges;
        this.renderEdges();
      }
    });

    // Listen for reset zoom event (from UI button)
    this.handleEvent("reset_zoom", () => {
      console.log('Reset zoom event received');
      this.zoomLevel = 1;
      this.panX = 0;
      this.panY = 0;
      this.applyZoomTransform();
      
      // Also reset transforms directly as backup
      if (this.svgContainer) {
        this.svgContainer.style.transform = 'scale(1) translate(0px, 0px)';
      }
      
      const nodesContainer = this.nodesContainer || 
                             this.el.querySelector('.nodes-container') || 
                             this.el.querySelector('[data-nodes-container]');
      if (nodesContainer) {
        nodesContainer.style.transform = 'scale(1) translate(0px, 0px)';
      }
    });

    // Listen for selection cleared event (from backend)
    this.handleEvent("selection_cleared", () => {
      this.selectedNodes = [];
      this.renderNodes();
    });
    
    // Prompt 1: Add handler for nodes_selected event from backend
    this.handleEvent("nodes_selected", ({ nodes }) => {
      if (nodes && Array.isArray(nodes)) {
        this.selectedNodes = nodes;
        this.renderNodes();
      }
    });

    // Listen for potential edges updated
    this.handleEvent("potential_edges_updated", ({ potential_edges }) => {
      console.log("Potential edges updated, count:", potential_edges?.length || 0);
      this.potentialEdges = potential_edges || [];
      this.renderEdges(); // Re-render to show/hide potential edges
    });

    // Listen for successful nodes deletion
    this.handleEvent("nodes_deleted_success", ({ node_ids }) => {
      if (!Array.isArray(node_ids)) return;
      node_ids.forEach((nodeId) => {
        const nodeEl = document.querySelector(`[data-node-id="${nodeId}"]`);
        if (nodeEl) {
          nodeEl.remove();
        }
        // Remove from nodes array
        this.nodes = (this.nodes || []).filter((n) => n.id !== nodeId);
        // Remove from selection
        if (this.selectedNodes) {
          this.selectedNodes = this.selectedNodes.filter(id => id !== nodeId);
        }
        
        // Also remove any edges connected to deleted node
        if (this.edges) {
          const edgesArray = Array.isArray(this.edges) 
            ? this.edges 
            : Object.entries(this.edges || {}).map(([edgeId, edgeData]) => ({
                id: edgeId,
                source_id: edgeData.source_id || edgeData.source,
                target_id: edgeData.target_id || edgeData.target
              }));
          
          const edgesToRemove = edgesArray
            .filter(edge => edge.source_id === nodeId || edge.target_id === nodeId)
            .map(edge => edge.id);
          
          // Remove from edges map
          edgesToRemove.forEach(edgeId => {
            if (Array.isArray(this.edges)) {
              this.edges = this.edges.filter(e => e.id !== edgeId);
            } else {
              delete this.edges[edgeId];
            }
            // Remove from edge selection
            if (this.selectedEdges) {
              this.selectedEdges.delete(edgeId);
            }
          });
          
          // Re-render edges to update display
          if (edgesToRemove.length > 0) {
            this.renderEdges();
          }
        }
      });
      if (this.updateSelectionCount) {
        this.updateSelectionCount();
      }
      // Update canvas bounds after nodes are deleted
      this.updateCanvasBounds();
      console.log(`Deleted ${node_ids.length} nodes`);
    });

    // Listen for nodes hidden success
    this.handleEvent("nodes_hidden_success", ({ node_ids }) => {
      if (!Array.isArray(node_ids)) return;
      node_ids.forEach((nodeId) => {
        const nodeEl = document.querySelector(`[data-node-id="${nodeId}"]`);
        if (nodeEl) {
          nodeEl.remove();
        }
        if (this.selectedNodes) {
          this.selectedNodes = this.selectedNodes.filter(id => id !== nodeId);
        }
      });
      if (this.updateSelectionCount) {
        this.updateSelectionCount();
      }
      // Update canvas bounds after nodes are hidden
      this.updateCanvasBounds();
      console.log(`Hidden ${node_ids.length} nodes`);
    });

    // Listen for show all success (server will trigger LV re-render)
    this.handleEvent("show_all_success", ({ nodes }) => {
      console.log('Showing all nodes, will trigger re-render');
    });

    // Listen for canvas cleared
    this.handleEvent("canvas_cleared", () => {
      if (this.canvas) {
        this.canvas.innerHTML = '';
      }
      this.nodes = [];
      this.selectedNodes = []; // Fix: Ensure selectedNodes is always an array, not a Set
      if (this.updateSelectionCount) {
        this.updateSelectionCount();
      }
      // Update canvas bounds after canvas is cleared
      this.updateCanvasBounds();
      console.log('Canvas cleared');
    });
  },

  updated() {
    // Update nodes and edges when server sends new data
    this.loadInitialData();
    this.renderNodes();
    this.setupLibraryItemDrag();

    // Inspect rendered nodes in DOM
    const reactNodes = document.querySelectorAll('.react-flow__node');
    console.log("Rendered .react-flow__node in DOM:", reactNodes.length);
    if (reactNodes.length > 0) {
      const cs = window.getComputedStyle(reactNodes[0]);
      console.log("First RF node HTML:", reactNodes[0].innerHTML);
      console.log("First RF node computed styles:", { border: cs.border, background: cs.backgroundColor, padding: cs.padding });
    }
    const domNodes = this.container.querySelectorAll('.flow-node');
    console.log("Rendered .flow-node in DOM:", domNodes.length);
    if (domNodes.length > 0) {
      const cs2 = window.getComputedStyle(domNodes[0]);
      console.log("First flow-node HTML:", domNodes[0].innerHTML);
      console.log("First flow-node computed styles:", { border: cs2.border, background: cs2.backgroundColor, padding: cs2.padding });
    }
  },

  destroyed() {
    // Clean up
    if (this.dragStartHandler) {
      document.removeEventListener('dragstart', this.dragStartHandler);
    }
    if (this.dragEndHandler) {
      document.removeEventListener('dragend', this.dragEndHandler);
    }
  },

  normalizeNodes(nodesData) {
    // Convert nodes from object format {id: {...}} to array format [{id, ...}]
    if (typeof nodesData === 'object' && nodesData !== null) {
      return Object.entries(nodesData).map(([id, data]) => ({ id, ...data }));
    }
    return [];
  },

  loadInitialData() {
    // Parse nodes, edges, and projects from data attributes
    const nodesData = this.el.dataset.nodes;
    const edgesData = this.el.dataset.edges;
    const projectsData = this.el.dataset.projects;

    if (nodesData) {
      try {
        const parsed = JSON.parse(nodesData);
        this.nodes = this.normalizeNodes(parsed);
      } catch (e) {
        console.error('Error parsing nodes:', e);
        this.nodes = [];
      }
    } else {
      this.nodes = [];
    }

    if (edgesData) {
      try {
        const parsed = JSON.parse(edgesData);
        this.edges = typeof parsed === 'object' ? Object.entries(parsed).map(([id, data]) => ({ id, ...data })) : [];
      } catch (e) {
        console.error('Error parsing edges:', e);
        this.edges = [];
      }
    } else {
      this.edges = [];
    }

    if (projectsData) {
      try {
        const parsed = JSON.parse(projectsData);
        // Normalize to an array of projects with id, name, category, icon_name
        this.projects = Array.isArray(parsed) ? parsed : [];
      } catch (e) {
        console.error('Error parsing projects:', e);
        this.projects = [];
      }
    } else {
      this.projects = [];
    }
  },

  renderNodes() {
    // Clear existing nodes
    this.container.innerHTML = '';
    
    // Create a canvas wrapper
    this.canvas = document.createElement('div');
    this.canvas.className = 'flow-canvas';
    // Use explicit positioning - don't rely on percentages that might constrain
    this.canvas.style.position = 'relative';
    // Start with explicit dimensions instead of percentages
    // These will be updated by updateCanvasBounds()
    const scrollArea = this.container.closest('.canvas-scroll-area');
    const viewport = scrollArea || this.container;
    const initialWidth = viewport.clientWidth || 800;
    const initialHeight = viewport.clientHeight || 600;
    this.canvas.style.width = `${initialWidth}px`;
    this.canvas.style.height = `${initialHeight}px`;
    this.canvas.style.background = 'transparent'; // Background is on .canvas-scroll-area
    
    // Create SVG container for edges (behind nodes)
    this.svgContainer = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    this.svgContainer.style.position = 'absolute';
    this.svgContainer.style.top = '0';
    this.svgContainer.style.left = '0';
    this.svgContainer.style.width = '100%';
    this.svgContainer.style.height = '100%';
    this.svgContainer.style.pointerEvents = 'none';
    this.svgContainer.style.zIndex = '1';
    this.svgContainer.style.overflow = 'visible';
    // Set explicit SVG dimensions to match canvas
    this.svgContainer.setAttribute('width', `${initialWidth}`);
    this.svgContainer.setAttribute('height', `${initialHeight}`);
    this.canvas.appendChild(this.svgContainer);
    
    // Create a nodes container that can be transformed for negative positions
    // This container should be transparent so the canvas background shows through
    this.nodesContainer = document.createElement('div');
    this.nodesContainer.style.position = 'absolute';
    this.nodesContainer.style.top = '0';
    this.nodesContainer.style.left = '0';
    this.nodesContainer.style.width = '100%';
    this.nodesContainer.style.height = '100%';
    this.nodesContainer.style.background = 'transparent';
    this.nodesContainer.style.pointerEvents = 'none'; // Allow clicks to pass through to nodes
    this.nodesContainer.style.zIndex = '2';
    this.canvas.appendChild(this.nodesContainer);
    
    this.container.appendChild(this.canvas);
    
    // Create marquee selection box (recreate if renderNodes() was called and cleared it)
    // Place it in nodesContainer so it uses the same coordinate system as nodes
    if (!this.marqueeBox || (!this.nodesContainer.contains(this.marqueeBox) && !this.canvas.contains(this.marqueeBox))) {
      // Remove from old location if it exists
      if (this.marqueeBox && this.marqueeBox.parentNode) {
        this.marqueeBox.parentNode.removeChild(this.marqueeBox);
      }
      
      this.marqueeBox = document.createElement('div');
      this.marqueeBox.className = 'marquee-selection-box';
      this.marqueeBox.style.position = 'absolute';
      this.marqueeBox.style.border = '2px dashed #000';
      this.marqueeBox.style.background = 'rgba(0, 0, 0, 0.1)';
      this.marqueeBox.style.pointerEvents = 'none';
      this.marqueeBox.style.zIndex = '1000';
      this.marqueeBox.style.display = 'none';
      
      // Add to nodesContainer (same coordinate system as nodes)
      if (this.nodesContainer) {
        this.nodesContainer.appendChild(this.marqueeBox);
      } else if (this.canvas) {
        this.canvas.appendChild(this.marqueeBox);
      }
    }

    // Filter nodes to only show:
    // 1. Top-level nodes (no parent_composite_id)
    // 2. Nodes whose parent composite is expanded
    // 3. Collapsed composite nodes (expanded ones are hidden)
    const expandedCompositeIds = new Set(this.expandedComposites || []);

    const nodesToRender = this.nodes.filter(node => {
      // Skip expanded composite nodes - they should not be visible
      if (expandedCompositeIds.has(node.id)) {
        return false;
      }

      // Show collapsed composite nodes (they need to be visible to expand)
      const category = (node.category || '').toLowerCase();
      const isComposite = category === 'composite' || node.composite_system_id;
      if (isComposite) {
        return true; // Show collapsed composites
      }

      // Show top-level nodes (no parent)
      if (!node.parent_composite_id) {
        return true;
      }

      // Show nodes whose parent is expanded
      if (expandedCompositeIds.has(node.parent_composite_id)) {
        return true;
      }

      // Hide everything else
      return false;
    });

    // Render filtered nodes
    nodesToRender.forEach(node => {
      this.renderNode(node);
    });

    // Render composite containers for expanded composites
    this.renderCompositeContainers();

    // Render edges after nodes
    this.renderEdges();

    // Update canvas size based on node bounds
    this.updateCanvasBounds();

    // Ensure selection count reflects current state after re-render
    if (this.updateSelectionCount) {
      this.updateSelectionCount();
    }
  },

  renderCompositeContainers() {
    if (!this.canvas || !this.nodes) return;
    
    // Remove existing containers
    const existingContainers = this.canvas.querySelectorAll('.composite-container');
    existingContainers.forEach(container => container.remove());
    
    // Find all expanded composite nodes
    const expandedComposites = this.nodes.filter(node => {
      const category = (node.category || '').toLowerCase();
      const isComposite = category === 'composite' || node.composite_system_id;
      return isComposite && (node.is_expanded || false);
    });
    
    // Create container for each expanded composite
    expandedComposites.forEach(compositeNode => {
      const compositeId = compositeNode.id;
      const compositeName = compositeNode.name || 'System';
      
      // Find all nodes that belong to this composite
      const childNodes = this.nodes.filter(n => n.parent_composite_id === compositeId);
      
      if (childNodes.length === 0) return;
      
      // Calculate bounds
      const bounds = this.calculateCompositeBounds(childNodes);
      
      // Create container
      const container = this.createCompositeContainer(compositeName, bounds);
      
      // Add to canvas (behind nodes)
      if (this.canvas) {
        this.canvas.appendChild(container);
      }
    });
  },

  calculateCompositeBounds(nodes) {
    if (!nodes || nodes.length === 0) {
      return { minX: 0, minY: 0, width: 100, height: 100 };
    }
    
    const positions = nodes.map(n => ({
      x: n.x || 0,
      y: n.y || 0
    }));
    
    const minX = Math.min(...positions.map(p => p.x));
    const minY = Math.min(...positions.map(p => p.y));
    const maxX = Math.max(...positions.map(p => p.x)) + 120; // Node width estimate (composite nodes are 120px)
    const maxY = Math.max(...positions.map(p => p.y)) + 60; // Node height estimate
    
    return {
      minX,
      minY,
      width: maxX - minX,
      height: maxY - minY
    };
  },

  createCompositeContainer(compositeName, bounds) {
    const container = document.createElement('div');
    container.className = 'composite-container';
    container.style.cssText = `
      position: absolute;
      left: ${bounds.minX - 20}px;
      top: ${bounds.minY - 40}px;
      width: ${bounds.width + 40}px;
      height: ${bounds.height + 60}px;
      border: 2px solid #999;
      background: rgba(248, 248, 248, 0.5);
      pointer-events: none;
      z-index: -1;
    `;
    
    // Add header
    const header = document.createElement('div');
    header.style.cssText = `
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      height: 20px;
      background: #D8D8D8;
      border-bottom: 2px solid #999;
      padding: 2px 8px;
      font-family: Chicago, Geneva, monospace;
      font-size: 11px;
      font-weight: bold;
      color: #333;
    `;
    header.textContent = compositeName + ' (expanded)';
    container.appendChild(header);
    
    return container;
  },

  renderEdges() {
    if (!this.svgContainer || !this.edges) return;
    
    // Clear existing edges (but preserve defs for arrowhead)
    const defs = this.svgContainer.querySelector('defs');
    while (this.svgContainer.firstChild) {
      this.svgContainer.removeChild(this.svgContainer.firstChild);
    }
    if (defs) {
      this.svgContainer.appendChild(defs);
    }
    
    // Get transform from nodesContainer if it exists
    const transform = this.getNodesContainerTransform();
    const offsetX = transform.x || 0;
    const offsetY = transform.y || 0;
    
    // Render each edge
    // Edges are stored as a map: { "edge_id": { "source_id": "...", "target_id": "..." } }
    const edgesArray = Array.isArray(this.edges) 
      ? this.edges 
      : Object.entries(this.edges || {}).map(([edgeId, edgeData]) => ({
          id: edgeId,
          source_id: edgeData.source_id || edgeData.source,
          target_id: edgeData.target_id || edgeData.target,
          source_handle: edgeData.source_handle,
          target_handle: edgeData.target_handle,
          label: edgeData.label,
          resource_type: edgeData.resource_type,
          connection_type: edgeData.connection_type
        }));
    
    // Build nodes map for quick lookup
    const nodesMap = {};
    this.nodes.forEach(node => {
      nodesMap[node.id] = node;
    });
    
    edgesArray.forEach(edge => {
      const sourceId = edge.source_id || edge.source;
      const targetId = edge.target_id || edge.target;
      const edgeId = edge.id;
      
      // Skip rendering edges that connect to non-existent nodes
      const sourceNode = nodesMap[sourceId];
      const targetNode = nodesMap[targetId];
      
      if (!sourceNode || !targetNode) {
        console.warn('[RenderEdges] Skipping edge - node not found:', {
          edgeId,
          sourceId,
          targetId,
          sourceExists: !!sourceNode,
          targetExists: !!targetNode
        });
        return; // Skip this edge
      }
      
      // Extract resource_type with fallback chain
      const resourceType = edge.resource_type || edge.source_handle || edge.target_handle || edge.label || 'connection';
      const isActual = (edge.connection_type === 'actual' || !edge.connection_type); // Default to actual
      
      // Get node positions (accounting for transform offset)
      const sourceX = (sourceNode.x || sourceNode.position?.x || 0) + offsetX;
      const sourceY = (sourceNode.y || sourceNode.position?.y || 0) + offsetY;
      const targetX = (targetNode.x || targetNode.position?.x || 0) + offsetX;
      const targetY = (targetNode.y || targetNode.position?.y || 0) + offsetY;
      
      // Get node dimensions (default to 140x80)
      const sourceWidth = 140;
      const sourceHeight = 80;
      const targetWidth = 140;
      const targetHeight = 80;
      
      // Calculate connection points
      // If edge has source_handle/target_handle, use port positions
      // Otherwise fallback to center-right/center-left
      let sourceX1, sourceY1, targetX1, targetY1;
      
      if (edge.source_handle && edge.target_handle) {
        // Find port handle positions
        const sourceHandleEl = this.canvas.querySelector(
          `[data-node-id="${sourceId}"][data-port="${edge.source_handle}"][data-port-type="output"]`
        );
        const targetHandleEl = this.canvas.querySelector(
          `[data-node-id="${targetId}"][data-port="${edge.target_handle}"][data-port-type="input"]`
        );
        
        if (sourceHandleEl && targetHandleEl) {
          const sourceRect = sourceHandleEl.getBoundingClientRect();
          const canvasRect = this.canvas.getBoundingClientRect();
          sourceX1 = sourceRect.left - canvasRect.left + sourceRect.width / 2 + offsetX;
          sourceY1 = sourceRect.top - canvasRect.top + sourceRect.height / 2 + offsetY;
          
          const targetRect = targetHandleEl.getBoundingClientRect();
          targetX1 = targetRect.left - canvasRect.left + targetRect.width / 2 + offsetX;
          targetY1 = targetRect.top - canvasRect.top + targetRect.height / 2 + offsetY;
        } else {
          // Fallback to center positions
          sourceX1 = sourceX + sourceWidth;
          sourceY1 = sourceY + sourceHeight / 2;
          targetX1 = targetX;
          targetY1 = targetY + targetHeight / 2;
        }
      } else {
        // Default: center-right of source, center-left of target
        sourceX1 = sourceX + sourceWidth;
        sourceY1 = sourceY + sourceHeight / 2;
        targetX1 = targetX;
        targetY1 = targetY + targetHeight / 2;
      }
      
      // Calculate Bezier curve control points for smooth curved edges
      const dx = targetX1 - sourceX1;
      const dy = targetY1 - sourceY1;
      const curvature = 0.5; // Curvature factor (0 = straight, 1 = very curved)
      
      const cp1x = sourceX1 + dx * curvature;
      const cp1y = sourceY1;
      const cp2x = targetX1 - dx * curvature;
      const cp2y = targetY1;
      
      // Create SVG path for Bezier curve
      const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
      const pathData = `M ${sourceX1} ${sourceY1} C ${cp1x} ${cp1y}, ${cp2x} ${cp2y}, ${targetX1} ${targetY1}`;
      path.setAttribute('d', pathData);
      
      // Check if edge is selected
      const isSelected = this.selectedEdges && this.selectedEdges.has(edgeId);
      
      // Style based on connection_type
      const strokeColor = isActual ? '#22c55e' : '#f97316';  // Green for actual, orange for potential
      const strokeWidth = isSelected ? '4' : (isActual ? '2' : '1');
      const strokeDasharray = isActual ? '0' : '5,5';  // Solid for actual, dashed for potential
      
      path.setAttribute('stroke', isSelected ? '#000' : strokeColor);
      path.setAttribute('stroke-width', strokeWidth);
      path.setAttribute('stroke-dasharray', strokeDasharray);
      path.setAttribute('fill', 'none');
      path.setAttribute('marker-end', 'url(#arrowhead)');
      path.dataset.edgeId = edgeId;
      path.style.cursor = 'pointer';
      path.style.transition = 'none'; // Instant updates for HyperCard aesthetic
      
      // Make edge clickable for selection
      path.addEventListener('click', (e) => {
        e.stopPropagation();
        // Clear node selection when clicking edge
        if (this.selectedNodes) {
          this.selectedNodes = [];
          // Clear node visual states
          const nodeElements = this.canvas.querySelectorAll('.flow-node');
          nodeElements.forEach(nodeEl => {
            const checkbox = nodeEl.querySelector('.node-select-checkbox');
            if (checkbox) {
              checkbox.checked = false;
            }
            nodeEl.classList.remove('selected');
            const category = nodeEl.dataset.category;
            nodeEl.style.zIndex = '';
            nodeEl.style.border = '2px solid #000';
            nodeEl.style.background = getCategoryBackground(category);
            nodeEl.style.boxShadow = '2px 2px 0 rgba(0,0,0,0.3)';
          });
        }
        this.toggleEdgeSelection(edgeId);
      });
      
      // Always show resource label in middle of edge
      const midX = (sourceX1 + targetX1) / 2;
      const midY = (sourceY1 + targetY1) / 2;
      
      const label = document.createElementNS('http://www.w3.org/2000/svg', 'text');
      label.setAttribute('x', midX);
      label.setAttribute('y', midY - 5);
      label.setAttribute('text-anchor', 'middle');
      label.setAttribute('font-size', '10px');
      label.setAttribute('font-weight', '500');
      label.setAttribute('fill', strokeColor);
      label.setAttribute('font-family', 'Chicago, Geneva, monospace');
      label.textContent = resourceType;
      
      // Add background rectangle for readability
      const labelRect = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
      const textLength = resourceType.length * 6; // Approximate text width
      labelRect.setAttribute('x', midX - textLength / 2 - 4);
      labelRect.setAttribute('y', midY - 17);
      labelRect.setAttribute('width', textLength + 8);
      labelRect.setAttribute('height', '14');
      labelRect.setAttribute('fill', '#FFF');
      labelRect.setAttribute('stroke', strokeColor);
      labelRect.setAttribute('stroke-width', '1');
      
      this.svgContainer.appendChild(labelRect);
      this.svgContainer.appendChild(label);
      
      // Add to SVG container
      this.svgContainer.appendChild(path);
    });
    
    // Render potential edges (dashed orange lines)
    if (this.potentialEdges && Array.isArray(this.potentialEdges)) {
      // Create nodes map for quick lookup
      const nodesMap = {};
      this.nodes.forEach(node => {
        nodesMap[node.id] = node;
      });

      this.potentialEdges.forEach(edge => {
        const sourceNode = nodesMap[edge.source_id];
        const targetNode = nodesMap[edge.target_id];
        
        if (!sourceNode || !targetNode) return;
        
        // Get node positions (accounting for transform offset)
        const sourceX = (sourceNode.x || sourceNode.position?.x || 0) + offsetX;
        const sourceY = (sourceNode.y || sourceNode.position?.y || 0) + offsetY;
        const targetX = (targetNode.x || targetNode.position?.x || 0) + offsetX;
        const targetY = (targetNode.y || targetNode.position?.y || 0) + offsetY;
        
        // Get node dimensions (default to 100x50 for regular nodes)
        const sourceWidth = 100;
        const sourceHeight = 50;
        const targetWidth = 100;
        const targetHeight = 50;
        
        // Calculate connection points (right side of source, left side of target)
        const sourceX1 = sourceX + sourceWidth;
        const sourceY1 = sourceY + sourceHeight / 2;
        const targetX1 = targetX;
        const targetY1 = targetY + targetHeight / 2;
        
        // Calculate Bezier curve control points for smooth curved edges
        const dx = targetX1 - sourceX1;
        const dy = targetY1 - sourceY1;
        const curvature = 0.5; // Curvature factor
        
        const cp1x = sourceX1 + dx * curvature;
        const cp1y = sourceY1;
        const cp2x = targetX1 - dx * curvature;
        const cp2y = targetY1;
        
        // Create SVG path for Bezier curve
        const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
        const pathData = `M ${sourceX1} ${sourceY1} C ${cp1x} ${cp1y}, ${cp2x} ${cp2y}, ${targetX1} ${targetY1}`;
        path.setAttribute('d', pathData);
        
        path.setAttribute('stroke', '#f97316'); // Orange
        path.setAttribute('stroke-width', '1.5');
        path.setAttribute('stroke-dasharray', '5,5'); // Dashed
        path.setAttribute('fill', 'none');
        path.setAttribute('opacity', '0.6');
        path.setAttribute('class', 'potential-edge');
        path.style.cursor = 'pointer';
        path.style.transition = 'none'; // Instant updates for HyperCard aesthetic
        
        // Click to create connection
        path.addEventListener('click', (e) => {
          e.stopPropagation();
          this.pushEvent('create_connection', {
            source_id: edge.source_id,
            source_handle: edge.resource_type,
            target_id: edge.target_id,
            target_handle: edge.resource_type
          });
        });
        
        // Hover effect
        path.addEventListener('mouseenter', () => {
          path.setAttribute('stroke-width', '2.5');
          path.setAttribute('opacity', '1');
        });
        path.addEventListener('mouseleave', () => {
          path.setAttribute('stroke-width', '1.5');
          path.setAttribute('opacity', '0.6');
        });
        
        this.svgContainer.appendChild(path);
        
        // Add label
        const midX = (sourceX1 + targetX1) / 2;
        const midY = (sourceY1 + targetY1) / 2;
        
        const label = document.createElementNS('http://www.w3.org/2000/svg', 'text');
        label.setAttribute('x', midX);
        label.setAttribute('y', midY - 5);
        label.setAttribute('text-anchor', 'middle');
        label.setAttribute('font-size', '9px');
        label.setAttribute('font-weight', '500');
        label.setAttribute('fill', '#f97316');
        label.setAttribute('opacity', '0.8');
        label.setAttribute('font-family', 'Chicago, Geneva, monospace');
        label.textContent = edge.resource_type || 'connection';
        label.style.pointerEvents = 'none';
        
        // Add background rectangle for readability
        const labelRect = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
        const textLength = (edge.resource_type || 'connection').length * 6;
        labelRect.setAttribute('x', midX - textLength / 2 - 4);
        labelRect.setAttribute('y', midY - 17);
        labelRect.setAttribute('width', textLength + 8);
        labelRect.setAttribute('height', '14');
        labelRect.setAttribute('fill', '#FFF');
        labelRect.setAttribute('stroke', '#f97316');
        labelRect.setAttribute('stroke-width', '1');
        labelRect.setAttribute('opacity', '0.9');
        labelRect.style.pointerEvents = 'none';
        
        this.svgContainer.appendChild(labelRect);
        this.svgContainer.appendChild(label);
      });
    }
    
    // Create arrowhead marker definition (if it doesn't exist)
    if (!this.svgContainer.querySelector('defs')) {
      const defs = document.createElementNS('http://www.w3.org/2000/svg', 'defs');
      const marker = document.createElementNS('http://www.w3.org/2000/svg', 'marker');
      marker.setAttribute('id', 'arrowhead');
      marker.setAttribute('markerWidth', '10');
      marker.setAttribute('markerHeight', '10');
      marker.setAttribute('refX', '9');
      marker.setAttribute('refY', '3');
      marker.setAttribute('orient', 'auto');
      
      const polygon = document.createElementNS('http://www.w3.org/2000/svg', 'polygon');
      polygon.setAttribute('points', '0 0, 10 3, 0 6');
      polygon.setAttribute('fill', '#333');
      marker.appendChild(polygon);
      defs.appendChild(marker);
      this.svgContainer.appendChild(defs);
    }
  },

  renderNode(node) {
    console.log("Creating node (renderNode):", node);
    console.log('[RenderNode] Rendering node:', node.id, 'inputs:', node.inputs?.length || 0, 'outputs:', node.outputs?.length || 0);
    
    // Skip rendering if this node is an expanded composite
    if (this.expandedComposites && this.expandedComposites.includes(node.id)) {
      console.log('[RenderNode] Skipping expanded composite node:', node.id);
      return;
    }
    
    // Check if this is a composite node
    const category = (node.category || '').toLowerCase();
    const isComposite = category === 'composite' || node.composite_system_id;
    const isExpanded = node.is_expanded || false;
    const isExpandedInternal = node.parent_composite_id; // This node is inside an expanded composite
    
    // Create node element
    const nodeEl = document.createElement('div');
    const categoryClass = category ? `node-${category}` : '';
    const statusClass = node.status === 'planned' ? 'node-planned' : (node.status === 'problem' ? 'node-problem' : '');
    nodeEl.className = ['flow-node', categoryClass, statusClass].filter(Boolean).join(' ');
    nodeEl.style.position = 'absolute';
    nodeEl.style.left = `${node.x}px`;
    nodeEl.style.top = `${node.y}px`;
    
    // Composite nodes are slightly larger
    if (isComposite) {
      nodeEl.style.width = '120px';
      nodeEl.style.minHeight = '60px';
      nodeEl.style.padding = '2px'; // Space for double border
    } else {
      nodeEl.style.width = '100px';
      nodeEl.style.minHeight = '50px';
      nodeEl.style.padding = '6px';
    }
    
    // Calculate required height based on ACTUAL connected ports (for auto-resizing)
    // We need to calculate connected ports early for height
    const edgesForHeight = Array.isArray(this.edges) 
      ? this.edges 
      : Object.entries(this.edges || {}).map(([edgeId, edgeData]) => ({
          source_id: edgeData.source_id || edgeData.source,
          target_id: edgeData.target_id || edgeData.target,
          source_handle: edgeData.source_handle,
          target_handle: edgeData.target_handle
        }));

    const connectedInputsCount = edgesForHeight.filter(e => 
      (e.target_id || e.target) === node.id && e.target_handle
    ).length;

    const connectedOutputsCount = edgesForHeight.filter(e => 
      (e.source_id || e.source) === node.id && e.source_handle
    ).length;

    const maxPorts = Math.max(connectedInputsCount, connectedOutputsCount);
    
    const baseHeight = 60; // Icon + name
    const portSpace = maxPorts * 16; // 16px per port
    const bottomSpace = 20; // Space for I/O counts and buttons
    const calculatedHeight = Math.max(80, baseHeight + portSpace + bottomSpace);
    
    // Apply calculated height
    nodeEl.style.height = `${calculatedHeight}px`;
    nodeEl.style.minHeight = `${calculatedHeight}px`;
    nodeEl.style.border = '2px solid #000';
    nodeEl.style.borderRadius = '0';
    nodeEl.style.background = isComposite ? '#E8E8E8' : getCategoryBackground(category);
    nodeEl.style.cursor = 'move';
    nodeEl.style.userSelect = 'none';
    nodeEl.dataset.nodeId = node.id;
    nodeEl.dataset.category = category;
    if (isComposite) {
      nodeEl.dataset.compositeId = node.composite_system_id;
    }

    // PART 1: Attach click handler RIGHT AFTER creating nodeEl, BEFORE appending children
    // This ensures the handler is attached early and fires properly
    nodeEl.addEventListener('click', (event) => {
      // CRITICAL: Ignore clicks ONLY on checkbox or info button themselves
      const clickedElement = event.target;
      const isCheckbox = clickedElement.classList.contains('node-select-checkbox');
      const isInfoButton = clickedElement.classList.contains('node-info-button');
      
      if (isCheckbox || isInfoButton) {
        event.stopPropagation(); // Prevent bubbling
        return; // Don't process selection
      }
      
      // Initialize selectedNodes if needed
      if (!Array.isArray(this.selectedNodes)) {
        this.selectedNodes = [];
      }
      
      // SHIFT+CLICK: Toggle selection (add/remove from array)
      if (event.shiftKey) {
        event.stopPropagation();
        event.preventDefault();
        
        const index = this.selectedNodes.indexOf(node.id);
        if (index > -1) {
          // Remove from selection
          this.selectedNodes.splice(index, 1);
        } else {
          // Add to selection
          this.selectedNodes.push(node.id);
        }
        
        // Push to backend
        this.pushEvent("nodes_selected", {node_ids: [...this.selectedNodes]});
        this.renderNodes();
        return; // CRITICAL: Stop here, don't continue to single-select
      }
      
      // REGULAR CLICK: Replace selection with just this node
      this.selectedNodes = [node.id];
      this.pushEvent("nodes_selected", {node_ids: [node.id]});
      this.renderNodes();
    });

    // Add HyperCard styling
    nodeEl.style.boxShadow = '2px 2px 0 rgba(0,0,0,0.3)';
    nodeEl.style.fontFamily = "'Chicago', 'Geneva', 'Monaco', monospace";
    nodeEl.style.fontSize = '9px'; // Base font size - all child elements should override this
    nodeEl.style.color = '#000';
    
    // Visual selection highlight
    if (this.selectedNodes && this.selectedNodes.includes(node.id)) {
      nodeEl.style.outline = '3px solid #0066FF';
      nodeEl.style.outlineOffset = '2px';
      nodeEl.style.boxShadow = '0 0 10px rgba(0, 102, 255, 0.5), 2px 2px 0 rgba(0,0,0,0.3)';
    } else {
      // Clear outline if not selected
      nodeEl.style.outline = '';
      nodeEl.style.outlineOffset = '';
      const isComposite = (node.category || '').toLowerCase() === 'composite' || node.composite_system_id;
      nodeEl.style.boxShadow = '2px 2px 0 rgba(0,0,0,0.3)';
    }

    // Selection checkbox (top-right) - greyscale styling
    const checkbox = document.createElement('input');
    checkbox.type = 'checkbox';
    checkbox.className = 'node-select-checkbox';
    checkbox.style.position = 'absolute';
    checkbox.style.top = '4px';
    checkbox.style.right = '4px';
    checkbox.style.width = '16px';
    checkbox.style.height = '16px';
    checkbox.style.border = '1px solid #000';
    checkbox.style.background = '#FFF';
    checkbox.style.cursor = 'pointer';
    // Only add greyscale filter - keep everything else as default
    checkbox.style.accentColor = '#000';
    checkbox.style.filter = 'grayscale(100%)';
    checkbox.addEventListener('click', (e) => {
      e.stopPropagation();
      const id = nodeEl.dataset.nodeId;
      if (checkbox.checked) {
        if (!this.selectedNodes.includes(id)) {
          this.selectedNodes.push(id);
        }
        nodeEl.classList.add('selected');
        nodeEl.style.zIndex = '10';
        nodeEl.style.border = '5px solid #000';
        nodeEl.style.background = '#FFF';
        nodeEl.style.boxShadow = '4px 4px 0 #000';
      } else {
        this.selectedNodes = this.selectedNodes.filter(nid => nid !== id);
        nodeEl.classList.remove('selected');
        nodeEl.style.zIndex = '';
        nodeEl.style.border = '2px solid #000';
        nodeEl.style.background = getCategoryBackground(nodeEl.dataset.category);
        nodeEl.style.boxShadow = '2px 2px 0 rgba(0,0,0,0.3)';
      }
      // Update selection counter in toolbar
      if (this.updateSelectionCount) {
        this.updateSelectionCount();
      }
    });
    nodeEl.appendChild(checkbox);

    // Info button (bottom-right corner)
    const infoButton = document.createElement('button');
    infoButton.type = 'button';
    infoButton.className = 'node-info-button';
    infoButton.textContent = 'ℹ️';
    infoButton.style.position = 'absolute';
    infoButton.style.bottom = '4px';
    infoButton.style.right = '4px';
    infoButton.style.width = '20px';
    infoButton.style.height = '20px';
    infoButton.style.padding = '0';
    infoButton.style.margin = '0';
    infoButton.style.border = '1px solid #666';
    infoButton.style.borderRadius = '0';
    infoButton.style.background = '#e5e7eb';
    infoButton.style.color = '#374151';
    infoButton.style.fontSize = '12px';
    infoButton.style.lineHeight = '1';
    infoButton.style.cursor = 'pointer';
    infoButton.style.display = 'flex';
    infoButton.style.alignItems = 'center';
    infoButton.style.justifyContent = 'center';
    infoButton.style.zIndex = '5';
    infoButton.style.boxShadow = '1px 1px 0 rgba(0,0,0,0.2)';
    infoButton.title = 'View node info';
    
    // Hover effect
    infoButton.addEventListener('mouseenter', () => {
      infoButton.style.background = '#d1d5db';
      infoButton.style.boxShadow = 'inset 1px 1px 2px rgba(0,0,0,0.3)';
    });
    infoButton.addEventListener('mouseleave', () => {
      infoButton.style.background = '#e5e7eb';
      infoButton.style.boxShadow = '1px 1px 0 rgba(0,0,0,0.2)';
    });
    
    // Click handler - push event to LiveView
    infoButton.addEventListener('click', (e) => {
      e.stopPropagation(); // Prevent node dragging/selection
      e.preventDefault();
      this.pushEvent('node_info_clicked', { node_id: node.id });
    });
    
    nodeEl.appendChild(infoButton);

    // Create content container (for composite nodes, this will be the inner bordered div)
    let contentContainer;
    if (isComposite) {
      contentContainer = document.createElement('div');
      contentContainer.style.border = '2px solid #666';
      contentContainer.style.borderRadius = '0';
      contentContainer.style.padding = '6px 8px';
      contentContainer.style.background = '#E8E8E8';
      contentContainer.style.fontSize = '9px'; // Explicitly set to prevent inheritance - all node text should be 9px
      contentContainer.style.fontFamily = "'Chicago', 'Geneva', monospace"; // Explicitly set
      nodeEl.appendChild(contentContainer);
      
      // Double-click to expand/collapse composite
      // Add to both nodeEl and contentContainer to catch all clicks
      const handleDoubleClick = (e) => {
        e.stopPropagation();
        e.preventDefault();
        
        console.log('[Composite] Double-click detected!', {
          target: e.target,
          nodeId: node.id,
          isExpanded: isExpanded,
          compositeId: node.composite_system_id,
          nodeData: node
        });
        
        if (isExpanded) {
          console.log('[Composite] Requesting collapse for node:', node.id);
          this.pushEvent('collapse_composite_node', { node_id: node.id });
        } else {
          console.log('[Composite] Requesting expand for node:', node.id);
          this.pushEvent('expand_composite_node', { node_id: node.id });
        }
      };
      
      nodeEl.addEventListener('dblclick', handleDoubleClick);
      if (contentContainer) {
        contentContainer.addEventListener('dblclick', handleDoubleClick);
      }
    } else {
      contentContainer = nodeEl;
    }

      // Icon and name (layout differs for composite vs regular)
      if (isComposite) {
        // Composite: icon and name in same line
        const headerDiv = document.createElement('div');
        headerDiv.style.display = 'flex';
        headerDiv.style.alignItems = 'center';
        headerDiv.style.justifyContent = 'center';
        headerDiv.style.gap = '4px';
        headerDiv.style.marginBottom = '4px';
        headerDiv.style.fontSize = '9px'; // Explicitly set to prevent inheritance - composite names should be 9px
        
        const iconSpan = document.createElement('span');
        iconSpan.textContent = node.icon_name || '📦';
        iconSpan.style.fontSize = '14px'; // Icons can be slightly larger
        iconSpan.style.lineHeight = '1';
        headerDiv.appendChild(iconSpan);
        
        const nameSpan = document.createElement('span');
        nameSpan.textContent = node.name || 'Composite';
        nameSpan.style.fontSize = '9px'; // Explicitly set - must override parent
        nameSpan.style.fontWeight = '700';
        nameSpan.style.fontFamily = "'Chicago', 'Geneva', monospace";
        nameSpan.style.overflow = 'hidden';
        nameSpan.style.textOverflow = 'ellipsis';
        nameSpan.style.whiteSpace = 'nowrap';
        nameSpan.style.maxWidth = '120px';
        headerDiv.appendChild(nameSpan);
        
        contentContainer.appendChild(headerDiv);
        
        // Info text
        const infoDiv = document.createElement('div');
        infoDiv.style.fontSize = '9px'; // Explicitly set
        infoDiv.style.fontFamily = "'Chicago', 'Geneva', monospace"; // Explicitly set
        infoDiv.style.opacity = '0.8';
        infoDiv.style.marginBottom = '2px';
        infoDiv.textContent = isExpanded ? '(Expanded)' : '(Double-click to expand)';
        contentContainer.appendChild(infoDiv);
    } else {
      // Regular node: icon above name
      const iconDiv = document.createElement('div');
      iconDiv.className = 'node-icon';
      const iconText = getCategoryIcon(node);
      iconDiv.textContent = iconText;
      // Use smaller icon for expanded internal nodes
      const iconFontSize = isExpandedInternal ? '9px' : '16px';
      // Use setProperty with important to ensure font-size is applied
      iconDiv.style.setProperty('font-size', iconFontSize, 'important');
      iconDiv.style.setProperty('font-family', "'Chicago', 'Geneva', monospace", 'important');
      iconDiv.style.lineHeight = '1';
      iconDiv.style.marginBottom = isExpandedInternal ? '2px' : '4px';
      iconDiv.style.display = 'block';
      // Only apply filter and text shadow if it's an emoji icon, not text
      if (!iconText || iconText.length > 2 || !/[\u{1F300}-\u{1F9FF}]/u.test(iconText)) {
        // It's text (like icon_name), not an emoji - style it as text
        iconDiv.style.filter = 'none';
        iconDiv.style.color = '#000';
        iconDiv.style.textShadow = 'none';
        iconDiv.style.fontWeight = '600';
      } else {
        // It's an emoji - use the styled version
        iconDiv.style.filter = 'grayscale(100%) contrast(1000%) brightness(1.2)';
        iconDiv.style.color = '#FFF';
        iconDiv.style.textShadow = '-1px -1px 0 #000, 1px -1px 0 #000, -1px 1px 0 #000, 1px 1px 0 #000, 0 -1px 0 #000, -1px 0 0 #000, 1px 0 0 #000, 0 1px 0 #000';
      }
      contentContainer.appendChild(iconDiv);

      // Name - with double-click editing support
      // CRITICAL: Always wrap the name in a span/div with explicit font-size
      const nameDiv = document.createElement('span'); // Use span for tighter wrapping
      nameDiv.className = 'node-name';
      // Prefer stored node.name; otherwise look up from projects by project_id
      const fallbackProject = getProjectById(this.projects, node.project_id);
      const projectName = fallbackProject && fallbackProject.name || 'Node';
      const customName = node.custom_name;
      const resolvedName = customName || node.name || projectName;
      nameDiv.textContent = resolvedName; // Use textContent, not innerHTML
      nameDiv.style.fontWeight = '600';
      // All nodes use 9px font size for consistency
      const nameFontSize = '9px';
      // Use setProperty with important to override any CSS rules
      nameDiv.style.setProperty('font-size', nameFontSize, 'important');
      nameDiv.style.setProperty('font-family', "'Chicago', 'Geneva', monospace", 'important');
      nameDiv.style.setProperty('display', 'block', 'important'); // Override CSS -webkit-box
      nameDiv.style.lineHeight = '1.2';
      nameDiv.style.overflow = 'hidden';
      nameDiv.style.textOverflow = 'ellipsis';
      nameDiv.style.whiteSpace = 'nowrap';
      nameDiv.style.maxWidth = isExpandedInternal ? '90px' : '120px'; // Smaller max width for expanded nodes
      nameDiv.style.cursor = 'text';
      nameDiv.title = 'Double-click to rename';
      nameDiv.dataset.nodeId = node.id;
      
      // Double-click to edit
      nameDiv.addEventListener('dblclick', (e) => {
        e.stopPropagation(); // Prevent node dragging
        this.enableNodeNameEdit(nameDiv, node.id, projectName);
      });
      
      // CRITICAL: Ensure nameDiv is appended - this wraps the name text
      contentContainer.appendChild(nameDiv);
    }

    // Add I/O count display at bottom of node
    const availableInputs = node.inputs || [];
    const availableOutputs = node.outputs || [];
    const ioInputCount = availableInputs.length;
    const ioOutputCount = availableOutputs.length;

    console.log('[RenderNode] I/O counts - inputs:', ioInputCount, 'outputs:', ioOutputCount);

    if (ioInputCount > 0 || ioOutputCount > 0) {
      console.log('[RenderNode] Creating I/O display for node:', node.id);
      const ioDisplay = document.createElement('div');
      ioDisplay.style.position = 'absolute';
      ioDisplay.style.bottom = '4px';
      ioDisplay.style.left = '4px';
      ioDisplay.style.fontSize = '9px'; // Readable but compact
      ioDisplay.style.fontWeight = 'bold';
      ioDisplay.style.color = '#000'; // Black text (was red)
      ioDisplay.style.backgroundColor = '#E5E7EB'; // Light grey background (was yellow)
      ioDisplay.style.padding = '2px 6px'; // Compact padding
      ioDisplay.style.border = '1px solid #000'; // Thin black border
      ioDisplay.style.borderRadius = '0'; // Square corners (HyperCard style)
      ioDisplay.style.zIndex = '15'; // Above node content, below badges
      ioDisplay.style.pointerEvents = 'none';
      ioDisplay.style.fontFamily = 'Chicago, Geneva, monospace';
      ioDisplay.style.display = 'flex';
      ioDisplay.style.gap = '6px'; // Space between ▲3 and ▼2
      ioDisplay.style.boxShadow = '1px 1px 0 rgba(0,0,0,0.2)'; // Subtle HyperCard bevel

      if (ioInputCount > 0) {
        const inputSpan = document.createElement('span');
        inputSpan.textContent = `▲${ioInputCount}`;
        ioDisplay.appendChild(inputSpan);
      }

      if (ioOutputCount > 0) {
        const outputSpan = document.createElement('span');
        outputSpan.textContent = `▼${ioOutputCount}`;
        ioDisplay.appendChild(outputSpan);
      }

      nodeEl.appendChild(ioDisplay);
    }

    // Add hover tooltip with full I/O lists
    const tooltip = document.createElement('div');
    tooltip.className = 'node-io-tooltip';
    tooltip.style.position = 'absolute';
    tooltip.style.top = '100%';
    tooltip.style.left = '50%';
    tooltip.style.transform = 'translateX(-50%)';
    tooltip.style.marginTop = '8px';
    tooltip.style.background = '#FFF';
    tooltip.style.border = '2px solid #000';
    tooltip.style.borderRadius = '0';
    tooltip.style.padding = '8px';
    tooltip.style.fontSize = '9px';
    tooltip.style.fontFamily = 'Chicago, Geneva, monospace';
    tooltip.style.zIndex = '1000';
    tooltip.style.minWidth = '120px';
    tooltip.style.boxShadow = '2px 2px 0 rgba(0,0,0,0.3)';
    tooltip.style.display = 'none';
    tooltip.style.pointerEvents = 'none';
    tooltip.style.whiteSpace = 'nowrap';

    // Build tooltip content
    let tooltipHTML = '';

    if (availableInputs.length > 0) {
      tooltipHTML += '<div style="margin-bottom: 4px;"><strong>IN:</strong></div>';
      availableInputs.forEach(input => {
        tooltipHTML += `<div style="margin-left: 8px;">• ${input}</div>`;
      });
    }

    if (availableOutputs.length > 0) {
      if (availableInputs.length > 0) tooltipHTML += '<div style="height: 4px;"></div>';
      tooltipHTML += '<div style="margin-bottom: 4px;"><strong>OUT:</strong></div>';
      availableOutputs.forEach(output => {
        tooltipHTML += `<div style="margin-left: 8px;">• ${output}</div>`;
      });
    }

    tooltip.innerHTML = tooltipHTML;
    nodeEl.appendChild(tooltip);

    // Add hover handlers to show/hide tooltip
    // These will stack with existing handlers (e.g., for connection handles)
    nodeEl.addEventListener('mouseenter', () => {
      if (ioInputCount > 0 || ioOutputCount > 0) {
        tooltip.style.display = 'block';
      }
    });

    nodeEl.addEventListener('mouseleave', () => {
      tooltip.style.display = 'none';
    });

    // Create visual port boxes (only for regular nodes with I/O)
    if (!isComposite && !isExpandedInternal && (ioInputCount > 0 || ioOutputCount > 0)) {
      // Get edges array in consistent format
      const edgesArray = Array.isArray(this.edges) 
        ? this.edges 
        : Object.entries(this.edges || {}).map(([edgeId, edgeData]) => ({
            id: edgeId,
            source_id: edgeData.source_id || edgeData.source,
            target_id: edgeData.target_id || edgeData.target,
            source_handle: edgeData.source_handle,
            target_handle: edgeData.target_handle
          }));

      // Find which input resources are actually connected to this node
      const connectedInputs = new Set();
      edgesArray.forEach(edge => {
        if ((edge.target_id || edge.target) === node.id && edge.target_handle) {
          connectedInputs.add(edge.target_handle);
        }
      });

      // Find which output resources are actually connected from this node
      const connectedOutputs = new Set();
      edgesArray.forEach(edge => {
        if ((edge.source_id || edge.source) === node.id && edge.source_handle) {
          connectedOutputs.add(edge.source_handle);
        }
      });

      // Filter to only show ports for connected resources
      const inputPortsToShow = (node.inputs || []).filter(input => connectedInputs.has(input));
      const outputPortsToShow = (node.outputs || []).filter(output => connectedOutputs.has(output));

      // INPUT PORTS (left side) - only show connected inputs
      inputPortsToShow.forEach((inputName, index) => {
        const portBox = document.createElement('div');
        portBox.className = 'input-port';
        portBox.dataset.portName = inputName;
        portBox.dataset.nodeId = node.id;
        portBox.dataset.portType = 'input';
        
        portBox.style.position = 'absolute';
        portBox.style.left = '-6px';
        portBox.style.top = `${30 + (index * 16)}px`;
        portBox.style.width = '12px';
        portBox.style.height = '12px';
        portBox.style.background = '#E5E7EB';
        portBox.style.border = '2px solid #000';
        portBox.style.borderRadius = '0';
        portBox.style.cursor = 'crosshair';
        portBox.style.zIndex = '10';
        portBox.style.boxShadow = '1px 1px 0 rgba(0,0,0,0.2)';
        portBox.title = `Input: ${inputName}`;
        
        // Prevent node dragging when interacting with port
        portBox.addEventListener('mousedown', (e) => {
          e.stopPropagation();
        });
        
        // Hover effect (green for inputs)
        portBox.addEventListener('mouseenter', () => {
          if (!this.clickState || this.clickState.sourcePort === inputName) {
            portBox.style.background = '#22c55e';
          }
        });
        portBox.addEventListener('mouseleave', () => {
          if (!this.clickState || this.clickState.sourcePort !== inputName) {
            portBox.style.background = '#E5E7EB';
          }
        });
        
        // Click handler for click-to-connect
        portBox.addEventListener('click', (e) => {
          e.stopPropagation();
          
          if (this.clickState && this.clickState.sourcePort === inputName) {
            // Second click: Complete connection
            const targetPort = inputName;
            const sourcePort = this.clickState.sourcePort;
            
            if (sourcePort === targetPort) {
              // Compatible - create connection
              this.pushEvent('create_connection', {
                source_id: this.clickState.sourceNodeId,
                source_handle: sourcePort,
                target_id: node.id,
                target_handle: targetPort
              });
            } else {
              // Incompatible
              console.log(`Cannot connect ${sourcePort} to ${targetPort}`);
            }
            
            this.resetClickState();
          }
        });
        
        nodeEl.appendChild(portBox);
      });
      
      // OUTPUT PORTS (right side) - only show connected outputs
      outputPortsToShow.forEach((outputName, index) => {
        const portBox = document.createElement('div');
        portBox.className = 'output-port';
        portBox.dataset.portName = outputName;
        portBox.dataset.nodeId = node.id;
        portBox.dataset.portType = 'output';
        
        portBox.style.position = 'absolute';
        portBox.style.right = '-6px';
        portBox.style.top = `${30 + (index * 16)}px`;
        portBox.style.width = '12px';
        portBox.style.height = '12px';
        portBox.style.background = '#E5E7EB';
        portBox.style.border = '2px solid #000';
        portBox.style.borderRadius = '0';
        portBox.style.cursor = 'crosshair';
        portBox.style.zIndex = '10';
        portBox.style.boxShadow = '1px 1px 0 rgba(0,0,0,0.2)';
        portBox.title = `Output: ${outputName}`;
        
        // Prevent node dragging when interacting with port
        portBox.addEventListener('mousedown', (e) => {
          e.stopPropagation();
        });
        
        // Hover effect (orange for outputs)
        portBox.addEventListener('mouseenter', () => {
          portBox.style.background = '#f97316';
        });
        portBox.addEventListener('mouseleave', () => {
          if (!this.clickState || this.clickState.selectedElement !== portBox) {
            portBox.style.background = '#E5E7EB';
          }
        });
        
        // Drag handler for drag-to-connect
        portBox.addEventListener('mousedown', (e) => {
          if (portBox.dataset.portType !== 'output') return;
          
          e.stopPropagation();
          e.preventDefault();
          
          // Get port position in SVG coordinates
          const rect = portBox.getBoundingClientRect();
          const svgRect = this.svgContainer.getBoundingClientRect();
          
          this.dragState = {
            sourceNodeId: node.id,
            sourcePort: outputName,
            startX: rect.left + rect.width/2 - svgRect.left,
            startY: rect.top + rect.height/2 - svgRect.top
          };
          
          // Create temporary line
          this.tempLine = document.createElementNS('http://www.w3.org/2000/svg', 'line');
          this.tempLine.setAttribute('stroke', '#f97316');
          this.tempLine.setAttribute('stroke-width', '2');
          this.tempLine.setAttribute('stroke-dasharray', '5,5');
          this.tempLine.setAttribute('x1', this.dragState.startX);
          this.tempLine.setAttribute('y1', this.dragState.startY);
          this.tempLine.setAttribute('x2', this.dragState.startX);
          this.tempLine.setAttribute('y2', this.dragState.startY);
          this.svgContainer.appendChild(this.tempLine);
          
          // Add global listeners
          const handleDragMove = (e) => {
            if (!this.dragState || !this.tempLine) return;
            
            const svgRect = this.svgContainer.getBoundingClientRect();
            const x = e.clientX - svgRect.left;
            const y = e.clientY - svgRect.top;
            
            this.tempLine.setAttribute('x2', x);
            this.tempLine.setAttribute('y2', y);
          };
          
          const handleDragEnd = (e) => {
            if (!this.dragState) return;
            
            // Check if dropped on input port
            const targetElement = document.elementFromPoint(e.clientX, e.clientY);
            
            if (targetElement && targetElement.classList.contains('input-port')) {
              const targetNodeId = targetElement.dataset.nodeId;
              const targetPort = targetElement.dataset.portName;
              const sourcePort = this.dragState.sourcePort;
              
              // Check compatibility (exact match for now)
              if (sourcePort === targetPort) {
                // Create connection via LiveView
                this.pushEvent('create_connection', {
                  source_id: this.dragState.sourceNodeId,
                  source_handle: sourcePort,
                  target_id: targetNodeId,
                  target_handle: targetPort
                });
              } else {
                // Show incompatible feedback
                console.log(`Cannot connect ${sourcePort} to ${targetPort}`);
              }
            }
            
            // Clean up
            if (this.tempLine) {
              this.tempLine.remove();
              this.tempLine = null;
            }
            this.dragState = null;
            document.removeEventListener('mousemove', handleDragMove);
            document.removeEventListener('mouseup', handleDragEnd);
          };
          
          document.addEventListener('mousemove', handleDragMove);
          document.addEventListener('mouseup', handleDragEnd);
        });
        
        // Click handler for click-to-connect
        portBox.addEventListener('click', (e) => {
          e.stopPropagation();
          
          // First click: Select output port
          this.resetClickState(); // Clear any previous selection
          
          this.clickState = {
            sourceNodeId: node.id,
            sourcePort: outputName,
            selectedElement: portBox
          };
          
          // Highlight selected output
          portBox.style.background = '#f97316';
          portBox.style.borderColor = '#f97316';
          portBox.style.borderWidth = '3px';
          
          // Highlight compatible input ports
          document.querySelectorAll('.input-port').forEach(inputPort => {
            if (inputPort.dataset.portName === outputName) {
              inputPort.style.background = '#22c55e';
              inputPort.style.animation = 'pulse 1s ease-in-out infinite';
            } else {
              inputPort.style.opacity = '0.3'; // Dim incompatible ports
            }
          });
        });
        
        nodeEl.appendChild(portBox);
      });
    }

    // Add connection count badges (after content, before handles)
    if (!isComposite) {
      // Count edges for this node
      const edgesArray = Array.isArray(this.edges) 
        ? this.edges 
        : Object.entries(this.edges || {}).map(([edgeId, edgeData]) => ({
            id: edgeId,
            source_id: edgeData.source_id || edgeData.source,
            target_id: edgeData.target_id || edgeData.target
          }));
      
      const outputCount = edgesArray.filter(e => (e.source_id || e.source) === node.id).length;
      const inputCount = edgesArray.filter(e => (e.target_id || e.target) === node.id).length;
      
      // Output badge (top-right corner)
      if (outputCount > 0) {
        const outputBadge = document.createElement('div');
        outputBadge.textContent = `${outputCount}→`;
        outputBadge.style.position = 'absolute';
        outputBadge.style.top = '4px';
        outputBadge.style.right = '4px';
        outputBadge.style.fontSize = '8px';
        outputBadge.style.fontWeight = 'bold';
        outputBadge.style.color = '#666';
        outputBadge.style.background = '#f3f4f6';
        outputBadge.style.padding = '2px 4px';
        outputBadge.style.borderRadius = '0';
        outputBadge.style.border = '1px solid #999';
        outputBadge.style.lineHeight = '1';
        outputBadge.style.pointerEvents = 'none';
        outputBadge.style.fontFamily = 'Chicago, Geneva, monospace';
        outputBadge.style.zIndex = '4';
        nodeEl.appendChild(outputBadge);
      }
      
      // Input badge (below output badge)
      if (inputCount > 0) {
        const inputBadge = document.createElement('div');
        inputBadge.textContent = `${inputCount}←`;
        inputBadge.style.position = 'absolute';
        inputBadge.style.top = '20px';
        inputBadge.style.right = '4px';
        inputBadge.style.fontSize = '8px';
        inputBadge.style.fontWeight = 'bold';
        inputBadge.style.color = '#666';
        inputBadge.style.background = '#f3f4f6';
        inputBadge.style.padding = '2px 4px';
        inputBadge.style.borderRadius = '0';
        inputBadge.style.border = '1px solid #999';
        inputBadge.style.lineHeight = '1';
        inputBadge.style.pointerEvents = 'none';
        inputBadge.style.fontFamily = 'Chicago, Geneva, monospace';
        inputBadge.style.zIndex = '4';
        nodeEl.appendChild(inputBadge);
      }
    }

    // Add input/output port handles for regular nodes
    if (!isComposite && !isExpandedInternal) {
      // Remove old handles if they exist (prevents duplicates on re-render)
      nodeEl.querySelectorAll('.input-handle, .output-handle').forEach(old => old.remove());
      
      // Get ports from node data (enriched by LiveView) or fallback to project
      let inputPorts = node.inputs || [];
      let outputPorts = node.outputs || [];
      
      // If node doesn't have ports, try to get from project
      if ((!inputPorts || inputPorts.length === 0) && (!outputPorts || outputPorts.length === 0)) {
        const project = getProjectById(this.projects, node.project_id);
        if (project) {
          // Try new port arrays first
          if (project.input_ports && project.input_ports.length > 0) {
            inputPorts = project.input_ports;
          } else if (project.inputs) {
            inputPorts = Object.keys(project.inputs);
          }
          
          if (project.output_ports && project.output_ports.length > 0) {
            outputPorts = project.output_ports;
          } else if (project.outputs) {
            outputPorts = Object.keys(project.outputs);
          }
        }
      }
      
      // Render input handles (left side)
      if (inputPorts && inputPorts.length > 0) {
        inputPorts.forEach((port, index) => {
          const handle = document.createElement('div');
          handle.className = 'input-handle react-flow__handle react-flow__handle-left';
          handle.dataset.port = port;
          handle.dataset.nodeId = node.id;
          handle.dataset.portType = 'input';
          handle.dataset.handleId = `input-${port}`;
          handle.dataset.handlePos = 'left';
          handle.title = port;
          handle.style.position = 'absolute';
          handle.style.left = '-6px';
          handle.style.top = `${30 + (index * 20)}px`;
          handle.style.width = '12px';
          handle.style.height = '12px';
          handle.style.background = '#FFF';
          handle.style.border = '2px solid #000';
          handle.style.borderRadius = '50%';
          handle.style.cursor = 'crosshair';  // Changed to crosshair for connection
          handle.style.zIndex = '10';
          handle.style.boxShadow = '1px 1px 0 rgba(0,0,0,0.3)';
          handle.style.display = 'none';  // Hide by default (completely remove from layout)
          
          // Hover effect - show handle when hovering directly
          handle.addEventListener('mouseenter', () => {
            handle.style.display = 'block';
            if (!this.connectingPort || this.connectingPort.type === 'output') {
              handle.style.background = '#CCC';
              handle.style.transform = 'scale(1.2)';
            }
          });
          handle.addEventListener('mouseleave', () => {
            // Only hide if not actively connecting and node is not hovered
            if (!this.connectingPort || this.connectingPort.type === 'output') {
              handle.style.background = '#FFF';
              handle.style.transform = 'scale(1)';
              // Check if node is still hovered - if not, hide handle
              if (!nodeEl.matches(':hover')) {
                handle.style.display = 'none';
              }
            }
          });
          
          // Drag-and-drop connection: allow drop on input handles
          handle.addEventListener('dragover', (e) => {
            e.preventDefault();
            e.stopPropagation();
            if (this.connectingPort && this.connectingPort.type === 'output') {
              handle.style.display = 'block';  // Ensure handle is visible during drag
              handle.style.background = '#999';
              handle.style.border = '3px solid #000';
            }
          });
          
          handle.addEventListener('dragleave', (e) => {
            e.preventDefault();
            e.stopPropagation();
            if (this.connectingPort && this.connectingPort.type === 'output') {
              handle.style.background = '#FFF';
              handle.style.border = '2px solid #000';
            }
          });
          
          handle.addEventListener('drop', (e) => {
            e.preventDefault();
            e.stopPropagation();
            if (this.connectingPort && this.connectingPort.type === 'output') {
              this.handlePortDrop(handle, 'input');
            }
          });
          
          // Click handler for connection creation (fallback)
          handle.addEventListener('click', (e) => {
            e.stopPropagation();
            this.handlePortClick(handle, 'input');
          });
          
          nodeEl.appendChild(handle);
        });
      }
      
      // Render output handles (right side)
      if (outputPorts && outputPorts.length > 0) {
        outputPorts.forEach((port, index) => {
          const handle = document.createElement('div');
          handle.className = 'output-handle react-flow__handle react-flow__handle-right';
          handle.dataset.port = port;
          handle.dataset.nodeId = node.id;
          handle.dataset.portType = 'output';
          handle.dataset.handleId = `output-${port}`;
          handle.dataset.handlePos = 'right';
          handle.draggable = true;  // Enable dragging from output handles
          handle.title = port;
          handle.style.position = 'absolute';
          handle.style.right = '-6px';
          handle.style.top = `${30 + (index * 20)}px`;
          handle.style.width = '12px';
          handle.style.height = '12px';
          handle.style.background = '#FFF';
          handle.style.border = '2px solid #000';
          handle.style.borderRadius = '50%';
          handle.style.cursor = 'grab';  // Changed to grab for dragging
          handle.style.zIndex = '10';
          handle.style.boxShadow = '1px 1px 0 rgba(0,0,0,0.3)';
          handle.style.display = 'none';  // Hide by default (completely remove from layout)
          
          // Drag start - begin connection
          handle.addEventListener('dragstart', (e) => {
            e.stopPropagation();
            this.connectingPort = {
              nodeId: node.id,
              port: port,
              type: 'output',
              handle: handle
            };
            handle.style.display = 'block';  // Ensure handle is visible during drag
            handle.style.background = '#999';
            handle.style.border = '3px solid #000';
            handle.style.cursor = 'grabbing';
            
            // Store data for drop
            e.dataTransfer.effectAllowed = 'link';
            e.dataTransfer.setData('text/plain', JSON.stringify({
              nodeId: node.id,
              port: port,
              type: 'output'
            }));
            
            console.log(`[Port] Started drag from output port "${port}" on node ${node.id}`);
            
            // Highlight all compatible input handles
            this.highlightCompatibleInputs(port);
          });
          
          handle.addEventListener('dragend', (e) => {
            e.stopPropagation();
            // Reset if connection wasn't completed (check if drop happened)
            // If drop was successful, cancelConnection will be called
            // Only reset here if drag was cancelled
            setTimeout(() => {
              if (this.connectingPort && this.connectingPort.handle === handle) {
                handle.style.background = '#FFF';
                handle.style.border = '2px solid #000';
                handle.style.cursor = 'grab';
                this.clearInputHighlights();
                this.connectingPort = null;
              }
            }, 100);
          });
          
          // Hover effect - show handle when hovering directly
          handle.addEventListener('mouseenter', () => {
            handle.style.display = 'block';
            if (!this.connectingPort) {
              handle.style.background = '#CCC';
              handle.style.transform = 'scale(1.2)';
            }
          });
          handle.addEventListener('mouseleave', () => {
            if (!this.connectingPort) {
              handle.style.background = '#FFF';
              handle.style.transform = 'scale(1)';
              // Check if node is still hovered - if not, hide handle
              if (!nodeEl.matches(':hover')) {
                handle.style.display = 'none';
              }
            }
          });
          
          // Click handler for connection creation (fallback)
          handle.addEventListener('click', (e) => {
            e.stopPropagation();
            this.handlePortClick(handle, 'output');
          });
          
          nodeEl.appendChild(handle);
        });
      }
    }
    
    // Add inputs/outputs for composite nodes
    if (isComposite && node.external_inputs && node.external_outputs) {
      const inputKeys = Object.keys(node.external_inputs || {});
      const outputKeys = Object.keys(node.external_outputs || {});
      
      if (inputKeys.length > 0 || outputKeys.length > 0) {
        const ioDiv = document.createElement('div');
        ioDiv.style.fontSize = '8px';
        ioDiv.style.opacity = '0.7';
        ioDiv.style.marginTop = '4px';
        ioDiv.style.paddingTop = '2px';
        ioDiv.style.borderTop = '1px solid #666';
        ioDiv.style.lineHeight = '1.3';
        
        if (inputKeys.length > 0) {
          const inputsSpan = document.createElement('div');
          inputsSpan.style.marginBottom = '2px';
          inputsSpan.style.fontSize = '8px';
          inputsSpan.style.fontFamily = "'Chicago', 'Geneva', monospace";
          inputsSpan.innerHTML = `<strong>IN:</strong> ${inputKeys.join(', ')}`;
          ioDiv.appendChild(inputsSpan);
        }
        
        if (outputKeys.length > 0) {
          const outputsSpan = document.createElement('div');
          outputsSpan.style.fontSize = '8px';
          outputsSpan.style.fontFamily = "'Chicago', 'Geneva', monospace";
          outputsSpan.style.marginBottom = '0px';
          outputsSpan.innerHTML = `<strong>OUT:</strong> ${outputKeys.join(', ')}`;
          ioDiv.appendChild(outputsSpan);
        }
        
        contentContainer.appendChild(ioDiv);
      }
    }

    // Show connection handles on node hover (for regular nodes only)
    if (!isComposite && !isExpandedInternal) {
      const handles = nodeEl.querySelectorAll('.input-handle, .output-handle');
      nodeEl.addEventListener('mouseenter', () => {
        handles.forEach(handle => {
          handle.style.display = 'block';
        });
      });
      nodeEl.addEventListener('mouseleave', () => {
        // Only hide if not actively connecting
        if (!this.connectingPort) {
          handles.forEach(handle => {
            handle.style.display = 'none';
          });
        }
      });
    }

    // Make node draggable
    this.makeDraggable(nodeEl);

    // Append to nodes container instead of canvas directly
    // Nodes need pointer events enabled to be draggable (container has pointer-events: none)
    nodeEl.style.pointerEvents = 'auto';
    if (this.nodesContainer) {
      this.nodesContainer.appendChild(nodeEl);
    } else {
      this.canvas.appendChild(nodeEl);
    }
    // Restore selection state for this node
    this.syncCheckboxState(nodeEl);
    return nodeEl;
  },

  makeDraggable(element) {
    let isDragging = false;
    let startX, startY, initialX, initialY;
    let dragScrollLeft = 0;
    let dragScrollTop = 0;
    let selectedNodesInitialPositions = new Map(); // Store initial positions for multi-node drag
    let dragStartMouseX = 0; // Track mouse position at drag start for cumulative offset
    let dragStartMouseY = 0;

    element.addEventListener('mousedown', (e) => {
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;
      
      // Check if this node is selected and if we have multiple nodes selected
      const nodeId = element.dataset.nodeId;
      const isNodeSelected = this.selectedNodes && this.selectedNodes.includes(nodeId);
      const hasMultipleSelected = this.selectedNodes && this.selectedNodes.length > 1;
      
      // If multiple nodes are selected and this node is one of them, prepare multi-node drag
      if (hasMultipleSelected && isNodeSelected) {
        selectedNodesInitialPositions.clear();
        
        // Store initial positions of all selected nodes
        this.selectedNodes.forEach(selectedId => {
          const selectedNodeEl = this.canvas.querySelector(`[data-node-id="${selectedId}"]`);
          if (selectedNodeEl) {
            const x = parseInt(selectedNodeEl.style.left) || 0;
            const y = parseInt(selectedNodeEl.style.top) || 0;
            selectedNodesInitialPositions.set(selectedId, { x, y });
          }
        });
      }
      // DISABLED: Let click handler manage selection instead
      // The click handler at line 1036 handles all selection logic including Shift+Click
      // else if (!isNodeSelected) {
      //   // If clicking on an unselected node, clear selection first
      //   // (User can hold Shift to add to selection, but for now we'll just select this one)
      //   this.clearSelection();
      //   if (!this.selectedNodes.includes(nodeId)) {
      //     this.selectedNodes.push(nodeId);
      //   }
      //   this.syncCheckboxState(element);
      //   console.log("📍 CALLING updateSelectionCount FROM:", new Error().stack);
      //   this.updateSelectionCount();
      // }
      
      isDragging = true;
      element.style.cursor = 'grabbing';
      
      // Store mouse position at drag start (for cumulative offset calculation)
      dragStartMouseX = e.clientX;
      dragStartMouseY = e.clientY;
      
      startX = e.clientX;
      startY = e.clientY;
      
      const rect = element.getBoundingClientRect();
      initialX = rect.left;
      initialY = rect.top;
      
      // Save scroll position at start of drag
      const scrollArea = this.container.closest('.canvas-scroll-area');
      if (scrollArea) {
        dragScrollLeft = scrollArea.scrollLeft;
        dragScrollTop = scrollArea.scrollTop;
      }
      
      // Set flag to prevent bounds updates during drag
      this.isDraggingNode = true;

      e.preventDefault();
      // REMOVED: Let click events bubble to click handler
      // e.stopPropagation(); // Prevent marquee selection from starting
    });

    document.addEventListener('mousemove', (e) => {
      if (!isDragging) return;

      const nodeId = element.dataset.nodeId;
      const hasMultipleSelected = this.selectedNodes && this.selectedNodes.length > 1 && this.selectedNodes.includes(nodeId);
      
      if (hasMultipleSelected && selectedNodesInitialPositions.size > 0) {
        // Multi-node drag: use cumulative offset from drag start
        const cumulativeDx = e.clientX - dragStartMouseX;
        const cumulativeDy = e.clientY - dragStartMouseY;
        
        // Move all selected nodes by the same cumulative offset from their initial positions
        selectedNodesInitialPositions.forEach((initialPos, selectedId) => {
          const selectedNodeEl = this.canvas.querySelector(`[data-node-id="${selectedId}"]`);
          if (selectedNodeEl) {
            const newX = initialPos.x + cumulativeDx;
            const newY = initialPos.y + cumulativeDy;
            selectedNodeEl.style.left = `${newX}px`;
            selectedNodeEl.style.top = `${newY}px`;
            
            // Update node position in nodes array for edge rendering
            const node = this.nodes.find(n => n.id === selectedId);
            if (node) {
              node.x = newX;
              node.y = newY;
            }
          }
        });
        
        // Re-render edges to reflect new positions
        this.renderEdges();
      } else {
        // Single node drag: use incremental offset (standard drag behavior)
        const dx = e.clientX - startX;
        const dy = e.clientY - startY;
        
        const currentLeft = parseInt(element.style.left || '0');
        const currentTop = parseInt(element.style.top || '0');
        const newX = currentLeft + dx;
        const newY = currentTop + dy;
        element.style.left = `${newX}px`;
        element.style.top = `${newY}px`;
        
        // Update node position in nodes array for edge rendering
        const node = this.nodes.find(n => n.id === nodeId);
        if (node) {
          node.x = newX;
          node.y = newY;
        }
        
        // Re-render edges to reflect new position
        this.renderEdges();
        
        startX = e.clientX;
        startY = e.clientY;
      }
    });

    document.addEventListener('mouseup', () => {
      if (!isDragging) return;
      
      isDragging = false;
      element.style.cursor = 'move';

      const nodeId = element.dataset.nodeId;
      const hasMultipleSelected = this.selectedNodes && this.selectedNodes.length > 1 && this.selectedNodes.includes(nodeId);
      
      if (hasMultipleSelected && selectedNodesInitialPositions.size > 0) {
        // Multi-node drag: send position updates for all selected nodes
        const updates = [];
        selectedNodesInitialPositions.forEach((initialPos, selectedId) => {
          const selectedNodeEl = this.canvas.querySelector(`[data-node-id="${selectedId}"]`);
          if (selectedNodeEl) {
            let x = parseInt(selectedNodeEl.style.left) || 0;
            let y = parseInt(selectedNodeEl.style.top) || 0;
            
            // Snap to grid on drop
            const snapped = snapToGrid({ x, y });
            x = snapped.x;
            y = snapped.y;
            selectedNodeEl.style.left = `${x}px`;
            selectedNodeEl.style.top = `${y}px`;
            
            updates.push({ node_id: selectedId, position_x: x, position_y: y });
          }
        });
        
        // Send all updates to server
        updates.forEach(update => {
          this.pushEvent('node_moved', update);
        });
        
        // Update nodes array with final positions
        updates.forEach(update => {
          const node = this.nodes.find(n => n.id === update.node_id);
          if (node) {
            node.x = update.position_x;
            node.y = update.position_y;
          }
        });
        
        // Re-render edges with updated positions
        this.renderEdges();
        
        selectedNodesInitialPositions.clear();
      } else {
        // Single node drag
        let x = parseInt(element.style.left);
        let y = parseInt(element.style.top);

        // Snap to grid on drop
        const snapped = snapToGrid({ x, y });
        x = snapped.x;
        y = snapped.y;
        element.style.left = `${x}px`;
        element.style.top = `${y}px`;

        // Update node position in nodes array
        const node = this.nodes.find(n => n.id === nodeId);
        if (node) {
          node.x = x;
          node.y = y;
        }
        
        // Re-render edges with updated position
        this.renderEdges();
        
        this.pushEvent('node_moved', {
          node_id: nodeId,
          position_x: x,
          position_y: y
        });
      }

      // Clear dragging flag
      this.isDraggingNode = false;
      
      // Update canvas bounds after node is moved, but preserve scroll position
      // Get current scroll position relative to the dragged node
      const scrollArea = this.container.closest('.canvas-scroll-area');
      const nodeScrollLeft = scrollArea ? scrollArea.scrollLeft : dragScrollLeft;
      const nodeScrollTop = scrollArea ? scrollArea.scrollTop : dragScrollTop;
      
      // Store scroll position that should be maintained
      this.pendingScrollLeft = nodeScrollLeft;
      this.pendingScrollTop = nodeScrollTop;
      
      // Delay bounds update slightly to avoid interrupting user interaction
      setTimeout(() => {
        this.updateCanvasBounds();
      }, 100);
    });
  },

  setupDragAndDrop() {
    const container = this.container;
    this.isDragging = false;

    // Show visual feedback when dragging over canvas
    container.addEventListener('dragover', (e) => {
      e.preventDefault();
      container.classList.add('xyflow-drag-over');
      container.style.cursor = 'copy';
      this.isDragging = true;
    });

    // Hide visual feedback when leaving canvas
    container.addEventListener('dragleave', (e) => {
      if (e.target === container || !container.contains(e.relatedTarget)) {
        container.classList.remove('xyflow-drag-over');
        container.style.cursor = '';
        this.isDragging = false;
      }
    });

    container.addEventListener('drop', (e) => {
      e.preventDefault();
      
      container.classList.remove('xyflow-drag-over');
      container.style.cursor = '';
      this.isDragging = false;

      const dataStr = e.dataTransfer.getData('text/plain');
      if (!dataStr) return;

      // Parse drag data (could be JSON or legacy plain project ID)
      let dragData;
      try {
        dragData = JSON.parse(dataStr);
      } catch (err) {
        // Legacy format: plain project ID
        dragData = { type: 'project', id: dataStr };
      }

      const rect = container.getBoundingClientRect();
      let rawX = e.clientX - rect.left;
      let rawY = e.clientY - rect.top;

      // Collision-avoidance with spiral + grid snapping
      const finalPos = findNonOverlappingPosition(rawX, rawY, this.nodes);
      let x = finalPos.x;
      let y = finalPos.y;
      console.log('Drop requested at', { rawX, rawY }, 'adjusted to', { x, y });

      const tempId = 'temp_' + Date.now();
      
      // Create temporary node
      this.addTemporaryNode(tempId, x, y, 'Loading...');

      // Push event to server based on type
      if (dragData.type === 'composite') {
        this.pushEvent('composite_node_added', {
          composite_id: dragData.id,
          x: Math.round(x),
          y: Math.round(y),
          temp_id: tempId
        });
      } else {
        // Default to project node
        this.pushEvent('node_added', {
          project_id: dragData.id,
          x: Math.round(x),
          y: Math.round(y),
          temp_id: tempId
        });
      }
    });
  },

  resetClickState() {
    if (this.clickState && this.clickState.selectedElement) {
      this.clickState.selectedElement.style.background = '#E5E7EB';
      this.clickState.selectedElement.style.borderColor = '#000';
      this.clickState.selectedElement.style.borderWidth = '2px';
    }
    
    this.clickState = null;
    
    // Reset all port styles
    document.querySelectorAll('.input-port, .output-port').forEach(port => {
      port.style.background = '#E5E7EB';
      port.style.borderColor = '#000';
      port.style.borderWidth = '2px';
      port.style.animation = '';
      port.style.opacity = '1';
    });
  },

  setupMarqueeSelection() {
    const container = this.container;
    const scrollArea = container.closest('.canvas-scroll-area');
    
    // Reset click state on canvas click (outside ports)
    // Only listen within canvas area, and ignore navigation elements
    const canvas = this.canvas || container;
    if (canvas) {
      canvas.addEventListener('click', (e) => {
        // CRITICAL: Let node click handler process node clicks
        if (e.target.closest('.flow-node')) {
          return; // Early return - don't process canvas clicks on nodes
        }
        
        // Ignore clicks on links, buttons, and UI elements (let navigation work)
        if (e.target.closest('a, button, .system-item, nav, header, .node-info-button')) {
          return; // Don't reset, let navigation/interaction work
        }
        
        // Only reset if clicking on canvas area (not on ports)
        if (!e.target.closest('.input-port') && !e.target.closest('.output-port')) {
          this.resetClickState();
        }
      });
    }
    
    let isMarqueeActive = false;
    let startX = 0;
    let startY = 0;
    
    // Create marquee selection box element (if it doesn't exist)
    // Place it in nodesContainer so it uses the same coordinate system as nodes
    if (!this.marqueeBox) {
      this.marqueeBox = document.createElement('div');
      this.marqueeBox.className = 'marquee-selection-box';
      this.marqueeBox.style.position = 'absolute';
      this.marqueeBox.style.border = '2px dashed #000';
      this.marqueeBox.style.background = 'rgba(0, 0, 0, 0.1)';
      this.marqueeBox.style.pointerEvents = 'none';
      this.marqueeBox.style.zIndex = '1000';
      this.marqueeBox.style.display = 'none';
      
      // Add to nodesContainer (same coordinate system as nodes)
      if (this.nodesContainer) {
        this.nodesContainer.appendChild(this.marqueeBox);
      } else if (this.canvas) {
        this.canvas.appendChild(this.marqueeBox);
      }
    }
    
    container.addEventListener('mousedown', (e) => {
      // Only start marquee if clicking directly on canvas (not on a node, toolbar, etc.)
      if (e.target.closest('.flow-node') || 
          e.target.closest('.living-web-toolbar') ||
          e.target.closest('.library-header') ||
          e.target.closest('.library-content') ||
          e.target.tagName === 'path') { // Don't start marquee if clicking on an edge
        // If clicking on canvas (not edge), clear edge selection
        if (!e.target.closest('.flow-node') && 
            !e.target.closest('.living-web-toolbar') &&
            !e.target.closest('.library-header') &&
            !e.target.closest('.library-content') &&
            e.target.tagName !== 'path') {
          this.clearEdgeSelection();
        }
        return;
      }
      
      // Clear edge selection when clicking on empty canvas
      this.clearEdgeSelection();
      
      // Check for multi-select (Shift key)
      const isMultiSelect = e.shiftKey;
      
      if (!isMultiSelect) {
        this.selectedNodes = [];
      }
      
      this.marqueeActive = true;
      this.marqueeStart = { x: e.clientX, y: e.clientY };
      this.isMarqueeSelecting = true;
      
      // Get starting position relative to nodesContainer (accounting for transform and scroll)
      const scrollLeft = scrollArea ? scrollArea.scrollLeft : 0;
      const scrollTop = scrollArea ? scrollArea.scrollTop : 0;
      
      // Get the transform offset of nodesContainer (if any)
      const nodesContainerTransform = this.getNodesContainerTransform();
      
      // Calculate position relative to the actual canvas coordinate system (where nodes are)
      // Mouse position in viewport
      const viewportX = e.clientX;
      const viewportY = e.clientY;
      
      // Get canvas position in viewport
      const canvasRect = this.canvas.getBoundingClientRect();
      
      // Convert to canvas coordinates (accounting for scroll)
      const canvasX = viewportX - canvasRect.left + scrollLeft;
      const canvasY = viewportY - canvasRect.top + scrollTop;
      
      // Account for nodesContainer transform offset (reverse the transform)
      startX = canvasX - nodesContainerTransform.x;
      startY = canvasY - nodesContainerTransform.y;
      
      this.marqueeStartX = startX;
      this.marqueeStartY = startY;
      
      // Show and position marquee box
      if (this.marqueeBox) {
        this.marqueeBox.style.display = 'block';
        this.marqueeBox.style.left = `${startX}px`;
        this.marqueeBox.style.top = `${startY}px`;
        this.marqueeBox.style.width = '0px';
        this.marqueeBox.style.height = '0px';
      }
      
      e.preventDefault();
      e.stopPropagation();
    });
    
    document.addEventListener('mousemove', (e) => {
      if (!this.marqueeActive || !this.marqueeBox) return;
      
      // Calculate current position relative to nodesContainer (same coordinate system as nodes)
      const scrollLeft = scrollArea ? scrollArea.scrollLeft : 0;
      const scrollTop = scrollArea ? scrollArea.scrollTop : 0;
      
      // Get the transform offset of nodesContainer
      const nodesContainerTransform = this.getNodesContainerTransform();
      
      // Calculate position in canvas coordinate system
      const canvasRect = this.canvas.getBoundingClientRect();
      const viewportX = e.clientX;
      const viewportY = e.clientY;
      
      const canvasX = viewportX - canvasRect.left + scrollLeft;
      const canvasY = viewportY - canvasRect.top + scrollTop;
      
      // Account for nodesContainer transform offset
      const currentX = canvasX - nodesContainerTransform.x;
      const currentY = canvasY - nodesContainerTransform.y;
      
      // Calculate rectangle bounds
      const left = Math.min(startX, currentX);
      const top = Math.min(startY, currentY);
      const width = Math.abs(currentX - startX);
      const height = Math.abs(currentY - startY);
      
      // Update marquee box
      this.marqueeBox.style.left = `${left}px`;
      this.marqueeBox.style.top = `${top}px`;
      this.marqueeBox.style.width = `${width}px`;
      this.marqueeBox.style.height = `${height}px`;
    });
    
    document.addEventListener('mouseup', (e) => {
      if (!this.marqueeActive) return;
      
      this.marqueeActive = false;
      this.isMarqueeSelecting = false;
      
      // Hide marquee box
      if (this.marqueeBox) {
        this.marqueeBox.style.display = 'none';
      }
      
      // Calculate final selection rectangle in node coordinate system
      const scrollLeft = scrollArea ? scrollArea.scrollLeft : 0;
      const scrollTop = scrollArea ? scrollArea.scrollTop : 0;
      
      // Get the transform offset of nodesContainer
      const nodesContainerTransform = this.getNodesContainerTransform();
      
      // Calculate end position in canvas coordinates
      const canvasRect = this.canvas.getBoundingClientRect();
      const canvasX = e.clientX - canvasRect.left + scrollLeft;
      const canvasY = e.clientY - canvasRect.top + scrollTop;
      
      // Convert to node coordinate system (accounting for transform)
      const endX = canvasX - nodesContainerTransform.x;
      const endY = canvasY - nodesContainerTransform.y;
      
      const left = Math.min(startX, endX);
      const top = Math.min(startY, endY);
      const right = Math.max(startX, endX);
      const bottom = Math.max(startY, endY);
      
      // Find all nodes that intersect with selection rectangle
      const selectedNodesInBox = [];
      const nodeElements = this.canvas.querySelectorAll('.flow-node:not(.temp-node)');
      
      nodeElements.forEach(nodeEl => {
        const nodeX = parseInt(nodeEl.style.left) || 0;
        const nodeY = parseInt(nodeEl.style.top) || 0;
        const nodeWidth = nodeEl.offsetWidth || 140;
        const nodeHeight = nodeEl.offsetHeight || 80;
        
        const nodeLeft = nodeX;
        const nodeRight = nodeX + nodeWidth;
        const nodeTop = nodeY;
        const nodeBottom = nodeY + nodeHeight;
        
        // Check if node intersects with selection rectangle
        if (!(nodeRight < left || nodeLeft > right || nodeBottom < top || nodeTop > bottom)) {
          const nodeId = nodeEl.dataset.nodeId;
          if (nodeId) {
            selectedNodesInBox.push(nodeId);
          }
        }
      });
      
      // Update selection based on Shift key
      const isMultiSelect = e.shiftKey;
      
      if (isMultiSelect) {
        // Add to existing selection
        selectedNodesInBox.forEach(nodeId => {
          if (!this.selectedNodes.includes(nodeId)) {
            this.selectedNodes.push(nodeId);
          }
        });
      } else {
        // Replace selection
        this.selectedNodes = selectedNodesInBox;
      }
      
      // Notify backend
      this.pushEvent('nodes_selected', { node_ids: this.selectedNodes });
      
      // Re-render to show selection highlights
      this.renderNodes();
    });
  },

  clearSelection() {
    // Clear all node selections
    this.selectedNodes = [];
    
    // Update all node checkboxes and visual states
    const nodeElements = this.canvas.querySelectorAll('.flow-node');
    nodeElements.forEach(nodeEl => {
      const checkbox = nodeEl.querySelector('.node-select-checkbox');
      if (checkbox) {
        checkbox.checked = false;
      }
      nodeEl.classList.remove('selected');
      const category = nodeEl.dataset.category;
      nodeEl.style.zIndex = '';
      nodeEl.style.border = '2px solid #000';
      nodeEl.style.background = getCategoryBackground(category);
      nodeEl.style.boxShadow = '2px 2px 0 rgba(0,0,0,0.3)';
    });
    
    // Clear edge selections
    this.clearEdgeSelection();
    
    this.updateSelectionCount();
  },

  getNodesContainerTransform() {
    // Extract transform offset from nodesContainer's CSS transform
    // Format: translate(Xpx, Ypx) or empty string
    if (!this.nodesContainer) {
      return { x: 0, y: 0 };
    }
    
    const transform = this.nodesContainer.style.transform || '';
    if (!transform) {
      return { x: 0, y: 0 };
    }
    
    // Parse translate(x, y) format
    const match = transform.match(/translate\(([^,]+)px,\s*([^)]+)px\)/);
    if (match) {
      return {
        x: parseFloat(match[1]) || 0,
        y: parseFloat(match[2]) || 0
      };
    }
    
    return { x: 0, y: 0 };
  },

  // Toolbar buttons for actions on selected nodes
  setupToolbarButtons() {
    // Delete Selected button
    const deleteBtn = document.getElementById('delete-selected-btn');
    if (deleteBtn) {
      deleteBtn.addEventListener('click', () => {
        const nodeCount = this.selectedNodes ? this.selectedNodes.length : 0;
        const edgeCount = this.selectedEdges ? this.selectedEdges.size : 0;
        
        if (nodeCount === 0 && edgeCount === 0) {
          alert('No nodes or edges selected');
          return;
        }
        
        // Delete selected nodes
        if (nodeCount > 0) {
          this.pushEvent('nodes_deleted', {
            node_ids: this.selectedNodes
          });
        }
        
        // Delete selected edges
        if (edgeCount > 0) {
          this.pushEvent('edges_deleted', {
            edge_ids: Array.from(this.selectedEdges)
          });
          // Clear edge selection after deletion
          this.selectedEdges.clear();
        }
      });
    }

    // Hide Selected button
    const hideBtn = document.getElementById('hide-selected-btn');
    if (hideBtn) {
      hideBtn.addEventListener('click', (e) => {
        e.preventDefault();
        e.stopPropagation();
        if (!this.selectedNodes || this.selectedNodes.length === 0) {
          alert('No nodes selected');
          return;
        }
        this.pushEvent('nodes_hidden', {
          node_ids: this.selectedNodes
        });
      });
    }

    // Show All button
    const showAllBtn = document.getElementById('show-all-btn');
    if (showAllBtn) {
      showAllBtn.addEventListener('click', (e) => {
        e.preventDefault();
        e.stopPropagation();
        this.pushEvent('show_all_nodes', {});
      });
    }

    // Deselect All button
    const deselectAllBtn = document.getElementById('deselect-all-btn');
    if (deselectAllBtn) {
      deselectAllBtn.addEventListener('click', (e) => {
        e.preventDefault();
        e.stopPropagation();
        this.clearSelection();
      });
    }

    // Clear All button
    const clearAllBtn = document.getElementById('clear-all-btn');
    if (clearAllBtn) {
      clearAllBtn.addEventListener('click', (e) => {
        e.preventDefault();
        e.stopPropagation();
        this.pushEvent('clear_canvas', {});
      });
    }

    // Connect button - create edge between two selected nodes
    const connectBtn = document.getElementById('connect-btn');
    if (connectBtn) {
      connectBtn.addEventListener('click', (e) => {
        e.preventDefault();
        e.stopPropagation();
        if (!this.selectedNodes || this.selectedNodes.length !== 2) {
          alert('Please select exactly 2 nodes to connect');
          return;
        }
        const selectedArray = this.selectedNodes;
        const sourceId = selectedArray[0];
        const targetId = selectedArray[1];
        
        // Push event to server to create edge
        this.pushEvent('edge_added', {
          source_id: sourceId,
          target_id: targetId
        });
      });
    }

    // Store connect button reference for state updates
    this.connectBtn = connectBtn;
    
    // Save as System button - handled by LiveView phx-click
    // The button has phx-click="show_save_system_dialog" which will handle the dialog
    // We just need to ensure the button state is updated based on selection
    const saveAsSystemBtn = document.getElementById('save-as-system-btn');
    // Note: Button click is handled by LiveView, but we still track it for state updates
    this.saveAsSystemBtn = saveAsSystemBtn;

    // Suggestions button
    const suggestionsBtn = document.getElementById('suggestions-btn');
    if (suggestionsBtn) {
      suggestionsBtn.addEventListener('click', (e) => {
        e.preventDefault();
        e.stopPropagation();
        this.pushEvent('show_suggestions', {});
      });
    }

    // Listen for suggestions loaded
    this.handleEvent('suggestions_loaded', ({ suggestions }) => {
      this.showSuggestionsPanel(suggestions || []);
    });
    
    // Initial button state update
    this.updateConnectButtonState();
    this.updateSaveAsSystemButtonState();
  },

  addTemporaryNode(id, x, y, label) {
    const nodeEl = document.createElement('div');
    nodeEl.className = 'flow-node temp-node';
    nodeEl.style.position = 'absolute';
    nodeEl.style.left = `${x}px`;
    nodeEl.style.top = `${y}px`;
    nodeEl.style.width = '140px';
    nodeEl.style.minHeight = '80px';
    nodeEl.style.height = 'auto';
    nodeEl.style.background = '#FFF';
    nodeEl.style.border = '2px dashed #000';
    nodeEl.style.borderRadius = '0';
    nodeEl.style.padding = '12px';
    nodeEl.style.opacity = '0.7';
    nodeEl.style.fontFamily = "'Chicago', 'Geneva', 'Monaco', monospace";
    nodeEl.style.fontSize = '11px';
    nodeEl.style.color = '#000';
    nodeEl.style.boxShadow = '2px 2px 0 #666';
    nodeEl.dataset.nodeId = id;
    nodeEl.style.textAlign = 'center';
    nodeEl.innerHTML = `
      <div style="font-size: 28px; line-height:1; margin-bottom: 8px;">⌛</div>
      <div style="font-weight: bold; font-size: 11px; line-height: 1.3;">${label}</div>
    `;
    nodeEl.id = id;

    // Append to nodes container if it exists, otherwise canvas
    // Nodes need pointer events enabled to be draggable (container has pointer-events: none)
    nodeEl.style.pointerEvents = 'auto';
    if (this.nodesContainer) {
      this.nodesContainer.appendChild(nodeEl);
    } else {
      this.canvas.appendChild(nodeEl);
    }
    return nodeEl;
  },

  setupLibraryItemDrag() {
    if (this.libraryDragSetup) return;
    this.libraryDragSetup = true;

    this.dragStartHandler = (e) => {
      if (e.target.classList.contains('draggable-project-item')) {
        const projectId = e.target.dataset.projectId;
        const compositeId = e.target.dataset.compositeId;
        
        if (projectId) {
          // Drag project node
          e.dataTransfer.setData('text/plain', JSON.stringify({ type: 'project', id: projectId }));
          e.target.classList.add('dragging');
        } else if (compositeId) {
          // Drag composite node
          e.dataTransfer.setData('text/plain', JSON.stringify({ type: 'composite', id: compositeId }));
          e.target.classList.add('dragging');
        }
      }
    };

    this.dragEndHandler = (e) => {
      if (e.target.classList.contains('draggable-project-item')) {
        e.target.classList.remove('dragging');
      }
    };

    document.addEventListener('dragstart', this.dragStartHandler);
    document.addEventListener('dragend', this.dragEndHandler);
  },

  // Setup server event listeners using LiveView's handleEvent API
  setupServerEvents() {
    // Listen for successful node addition
    this.handleEvent('node_added_success', (payload) => {
      console.log('Server created node successfully:', payload);
      
      // Remove temporary node
      if (payload.temp_id) {
        const tempNode = document.getElementById(payload.temp_id);
        if (tempNode) {
          tempNode.remove();
        }
      }

      // Add real node
      this.addRealNode(payload);
    });

    // Listen for composite node addition success
    this.handleEvent('composite_node_added_success', (payload) => {
      console.log('Server created composite node successfully:', payload);
      
      // Remove temporary node
      if (payload.temp_id) {
        const tempNode = document.getElementById(payload.temp_id);
        if (tempNode) {
          tempNode.remove();
        }
      }

      // Add real composite node
      this.addRealCompositeNode(payload);
    });

    // Listen for composite expansion success
    this.handleEvent('composite_expanded_success', (payload) => {
      console.log('[Composite] Expansion success event received:', payload);
      console.log('[Composite] Payload nodes count:', Object.keys(payload.nodes || {}).length);
      console.log('[Composite] Payload edges count:', Object.keys(payload.edges || {}).length);
      console.log('[Composite] First few nodes:', Object.entries(payload.nodes || {}).slice(0, 5));
      
      const compositeNodeId = payload.node_id;
      
      // Track expanded composite
      if (!this.expandedComposites.includes(compositeNodeId)) {
        this.expandedComposites.push(compositeNodeId);
      }
      
      // Fade out composite node with animation
      const compositeNode = this.canvas?.querySelector(`[data-node-id="${compositeNodeId}"]`);
      if (compositeNode) {
        compositeNode.style.transition = 'opacity 0.2s ease-out';
        compositeNode.style.opacity = '0';
      }
      
      // Reload nodes and edges from server after fade
      setTimeout(() => {
        if (payload.nodes && payload.edges) {
          console.log('[Composite] Normalizing nodes...');
          const normalizedNodes = this.normalizeNodes(payload.nodes);
          console.log('[Composite] Normalized nodes count:', normalizedNodes.length);
          
          // Filter out hidden nodes
          const visibleNodes = normalizedNodes.filter(node => {
            // Filter out expanded composite nodes (they're hidden)
            if (this.expandedComposites.includes(node.id)) {
              console.log('[Composite] Filtering out expanded composite node:', node.id);
              return false;
            }
            
            // Filter out hidden nodes
            if (node.hidden === true) {
              console.log('[Composite] Filtering out hidden node:', node.id);
              return false;
            }
            
            return true;
          });
          
          console.log('[Composite] Visible nodes after filtering:', visibleNodes.length);
          
          this.nodes = visibleNodes;
          
          // Filter edges to only include edges connected to visible nodes
          const visibleNodeIds = new Set(visibleNodes.map(n => n.id));
          const visibleEdges = {};
          Object.entries(payload.edges || {}).forEach(([edgeId, edge]) => {
            const sourceId = edge.source_id || edge.source;
            const targetId = edge.target_id || edge.target;
            
            // Only include edge if both source and target are visible
            if (visibleNodeIds.has(sourceId) && visibleNodeIds.has(targetId)) {
              visibleEdges[edgeId] = edge;
            } else {
              console.log('[Composite] Filtering out edge:', edgeId, 'source:', sourceId, 'target:', targetId);
            }
          });
          
          this.edges = visibleEdges;
          console.log('[Composite] Visible edges after filtering:', Object.keys(visibleEdges).length);
          
          console.log('[Composite] Calling renderNodes...');
          this.renderNodes();
          console.log('[Composite] Calling renderEdges...');
          this.renderEdges();
          
          // Fade in child nodes with stagger effect
          const childNodes = this.canvas?.querySelectorAll(`[data-parent-composite-id="${compositeNodeId}"]`);
          if (childNodes && childNodes.length > 0) {
            childNodes.forEach((node, index) => {
              node.style.opacity = '0';
              node.style.transform = 'scale(0.95)';
              node.style.transition = 'opacity 0.3s ease-out, transform 0.3s ease-out';
              
              setTimeout(() => {
                node.style.opacity = '1';
                node.style.transform = 'scale(1)';
              }, index * 30); // Stagger by 30ms each
            });
          }
          
          console.log('[Composite] Render complete. DOM nodes:', document.querySelectorAll('.flow-node').length);
          console.log('[Composite] Expanded nodes:', document.querySelectorAll('[data-parent-composite-id]').length);
        } else {
          console.error('[Composite] Missing nodes or edges in payload:', payload);
        }
      }, 200);
    });

    // Listen for composite collapse success
    this.handleEvent('composite_collapsed_success', (payload) => {
      console.log('Composite node collapsed:', payload);
      const compositeNodeId = payload.node_id;
      
      // Remove from expanded composites list
      this.expandedComposites = this.expandedComposites.filter(id => id !== compositeNodeId);
      
      // Fade out child nodes with animation
      const childNodes = this.canvas?.querySelectorAll(`[data-parent-composite-id="${compositeNodeId}"]`);
      if (childNodes && childNodes.length > 0) {
        childNodes.forEach((node, index) => {
          node.style.transition = 'opacity 0.2s ease-out, transform 0.2s ease-out';
          node.style.opacity = '0';
          node.style.transform = 'scale(0.95)';
        });
      }
      
      // Reload nodes and edges from server after fade
      setTimeout(() => {
        if (payload.nodes && payload.edges) {
          const normalizedNodes = this.normalizeNodes(payload.nodes);
          
          // Filter out hidden nodes and expanded composites
          const visibleNodes = normalizedNodes.filter(node => {
            // Filter out expanded composite nodes
            if (this.expandedComposites.includes(node.id)) {
              console.log('[Composite] Filtering out expanded composite node:', node.id);
              return false;
            }
            
            // Filter out hidden nodes
            if (node.hidden === true) {
              console.log('[Composite] Filtering out hidden node:', node.id);
              return false;
            }
            
            return true;
          });
          
          this.nodes = visibleNodes;
          
          // Filter edges to only include edges connected to visible nodes
          const visibleNodeIds = new Set(visibleNodes.map(n => n.id));
          const visibleEdges = {};
          Object.entries(payload.edges || {}).forEach(([edgeId, edge]) => {
            const sourceId = edge.source_id || edge.source;
            const targetId = edge.target_id || edge.target;
            
            if (visibleNodeIds.has(sourceId) && visibleNodeIds.has(targetId)) {
              visibleEdges[edgeId] = edge;
            }
          });
          
          this.edges = visibleEdges;
          this.renderNodes();
          this.renderEdges();
          
          // Fade in composite node
          const newCompositeNode = this.canvas?.querySelector(`[data-node-id="${compositeNodeId}"]`);
          if (newCompositeNode) {
            newCompositeNode.style.opacity = '0';
            newCompositeNode.style.transition = 'opacity 0.3s ease-out';
            setTimeout(() => {
              newCompositeNode.style.opacity = '1';
            }, 50);
          }
        }
      }, 200);
    });

    // Listen for composite system saved
    this.handleEvent('composite_system_saved', (payload) => {
      console.log('Composite system saved:', payload);
      
      // Close the modal if it's still open
      if (this.currentSaveOverlay && this.currentSaveOverlay.parentNode) {
        try {
          document.body.removeChild(this.currentSaveOverlay);
        } catch (e) {
          console.warn('Could not remove save overlay:', e);
        }
        this.currentSaveOverlay = null;
      }
      
      if (payload.success) {
        // Show success message without navigation
        alert(payload.message);
        
        // Update canvas if nodes and edges are provided
        if (payload.nodes && payload.edges) {
          this.nodes = this.normalizeNodes(payload.nodes);
          this.edges = payload.edges;
          
          // Clear selection
          if (this.selectedNodes) {
            this.selectedNodes = [];
          }
          
          // Re-render the canvas
          this.renderNodes();
          this.renderEdges();
          this.updateCanvasBounds();
          
          // Update selection count
          if (this.updateSelectionCount) {
            this.updateSelectionCount();
          }
        }
      } else {
        alert('Error: ' + payload.message);
      }
    });

    // Listen for node addition errors
    this.handleEvent('node_add_error', (payload) => {
      console.error('Server failed to create node:', payload);
      
      if (payload.temp_id) {
        const tempNode = document.getElementById(payload.temp_id);
        if (tempNode) {
          tempNode.remove();
        }
      }
      
      alert('Failed to add node: ' + (payload.message || 'Unknown error'));
    });
  },

  addRealNode(nodeData) {
    console.log("Creating node (addRealNode):", nodeData);
    const nodeEl = document.createElement('div');
    const category = (nodeData.category || '').toLowerCase();
    const categoryClass = category ? `node-${category}` : '';
    const statusClass = nodeData.status === 'planned' ? 'node-planned' : (nodeData.status === 'problem' ? 'node-problem' : '');
    nodeEl.className = ['flow-node', categoryClass, statusClass].filter(Boolean).join(' ');
    nodeEl.style.position = 'absolute';
    nodeEl.style.left = `${nodeData.position.x}px`;
    nodeEl.style.top = `${nodeData.position.y}px`;
    nodeEl.style.width = '140px';
    nodeEl.style.minHeight = '80px';
    nodeEl.style.height = 'auto';
    nodeEl.style.border = '2px solid #000';
    nodeEl.style.borderRadius = '0';
    nodeEl.style.padding = '12px';
    nodeEl.style.background = getCategoryBackground(category);
    nodeEl.style.cursor = 'move';
    nodeEl.style.userSelect = 'none';
    nodeEl.style.fontFamily = "'Chicago', 'Geneva', 'Monaco', monospace";
    nodeEl.style.fontSize = '11px';
    nodeEl.style.color = '#000';
    nodeEl.style.boxShadow = '2px 2px 0 rgba(0,0,0,0.3)';
    nodeEl.dataset.nodeId = nodeData.id;
    nodeEl.dataset.category = category;
    nodeEl.id = nodeData.id;

    // Selection checkbox (top-right) - greyscale styling
    const checkbox = document.createElement('input');
    checkbox.type = 'checkbox';
    checkbox.className = 'node-select-checkbox';
    checkbox.style.position = 'absolute';
    checkbox.style.top = '4px';
    checkbox.style.right = '4px';
    checkbox.style.width = '16px';
    checkbox.style.height = '16px';
    checkbox.style.border = '1px solid #000';
    checkbox.style.background = '#FFF';
    checkbox.style.cursor = 'pointer';
    // Only add greyscale filter - keep everything else as default
    checkbox.style.accentColor = '#000';
    checkbox.style.filter = 'grayscale(100%)';
    checkbox.addEventListener('click', (e) => {
      e.stopPropagation();
      const id = nodeEl.dataset.nodeId;
      if (checkbox.checked) {
        if (!this.selectedNodes.includes(id)) {
          this.selectedNodes.push(id);
        }
        nodeEl.classList.add('selected');
        nodeEl.style.zIndex = '10';
        nodeEl.style.border = '5px solid #000';
        nodeEl.style.background = '#FFF';
        nodeEl.style.boxShadow = '4px 4px 0 #000';
      } else {
        this.selectedNodes = this.selectedNodes.filter(nid => nid !== id);
        nodeEl.classList.remove('selected');
        nodeEl.style.zIndex = '';
        nodeEl.style.border = '2px solid #000';
        nodeEl.style.background = getCategoryBackground(nodeEl.dataset.category);
        nodeEl.style.boxShadow = '2px 2px 0 rgba(0,0,0,0.3)';
      }
      // Update selection counter in toolbar
      if (this.updateSelectionCount) {
        this.updateSelectionCount();
      }
    });
    nodeEl.appendChild(checkbox);

    // Icon
    const iconDiv = document.createElement('div');
    iconDiv.className = 'node-icon';
    iconDiv.textContent = getCategoryIcon(nodeData);
    iconDiv.style.fontSize = '28px';
    iconDiv.style.lineHeight = '1';
    iconDiv.style.marginBottom = '8px';
    iconDiv.style.display = 'block';
    iconDiv.style.filter = 'grayscale(100%) contrast(1000%) brightness(1.2)';
    iconDiv.style.color = '#FFF';
    iconDiv.style.textShadow = '-1px -1px 0 #000, 1px -1px 0 #000, -1px 1px 0 #000, 1px 1px 0 #000, 0 -1px 0 #000, -1px 0 0 #000, 1px 0 0 #000, 0 1px 0 #000';
    nodeEl.appendChild(iconDiv);

    // Name - with double-click editing support
    const nameDiv = document.createElement('div');
    nameDiv.className = 'node-name';
    // For server-pushed ReactFlow nodeData, resolve name/category from projects if missing
    const projId = nodeData.data && nodeData.data.project_id;
    const fallbackProject = getProjectById(this.projects, projId);
    const projectName = fallbackProject && fallbackProject.name || 'Node';
    const customName = nodeData.custom_name || nodeData.data?.custom_name;
    const resolvedName = customName || nodeData.name || projectName;
    const resolvedCategory = nodeData.category || (fallbackProject && fallbackProject.category) || undefined;
    nameDiv.textContent = resolvedName;
    nameDiv.style.fontWeight = 'bold';
    nameDiv.style.fontSize = '11px';
    nameDiv.style.lineHeight = '1.3';
    nameDiv.style.cursor = 'text';
    nameDiv.title = 'Double-click to rename';
    
    // Store nodeId for event handling
    nameDiv.dataset.nodeId = nodeData.id;
    
    // Double-click to edit
    nameDiv.addEventListener('dblclick', (e) => {
      e.stopPropagation(); // Prevent node dragging
      this.enableNodeNameEdit(nameDiv, nodeData.id, projectName);
    });
    
    nodeEl.appendChild(nameDiv);

    // Add inputs/outputs display
    if (nodeData.inputs || nodeData.outputs) {
      const inputs = nodeData.inputs || {};
      const outputs = nodeData.outputs || {};
      const inputKeys = Object.keys(inputs);
      const outputKeys = Object.keys(outputs);
      
      if (inputKeys.length > 0 || outputKeys.length > 0) {
        const ioContainer = document.createElement('div');
        ioContainer.style.marginTop = '8px';
        ioContainer.style.paddingTop = '8px';
        ioContainer.style.borderTop = '1px solid #666';
        ioContainer.style.fontSize = '9px';
        ioContainer.style.lineHeight = '1.3';
        
        if (inputKeys.length > 0) {
          const inputsDiv = document.createElement('div');
          inputsDiv.style.marginBottom = '4px';
          inputsDiv.innerHTML = `<strong>IN:</strong> ${inputKeys.join(', ')}`;
          ioContainer.appendChild(inputsDiv);
        }
        
        if (outputKeys.length > 0) {
          const outputsDiv = document.createElement('div');
          outputsDiv.innerHTML = `<strong>OUT:</strong> ${outputKeys.join(', ')}`;
          ioContainer.appendChild(outputsDiv);
        }
        
        nodeEl.appendChild(ioContainer);
      }
    }

    this.makeDraggable(nodeEl);
    // Append to nodes container if it exists, otherwise canvas
    // Nodes need pointer events enabled to be draggable (container has pointer-events: none)
    nodeEl.style.pointerEvents = 'auto';
    if (this.nodesContainer) {
      this.nodesContainer.appendChild(nodeEl);
    } else {
      this.canvas.appendChild(nodeEl);
    }
    // Restore selection state for this node
    this.syncCheckboxState(nodeEl);

    // Track in nodes array (check if already exists to avoid duplicates)
    const existingNodeIndex = this.nodes.findIndex(n => n.id === nodeData.id);
    const nodeEntry = {
      id: nodeData.id,
      name: resolvedName,
      category: resolvedCategory,
      status: nodeData.status,
      x: nodeData.position?.x || nodeData.x || parseInt(nodeEl.style.left) || 0,
      y: nodeData.position?.y || nodeData.y || parseInt(nodeEl.style.top) || 0
    };
    
    if (existingNodeIndex >= 0) {
      // Update existing node
      this.nodes[existingNodeIndex] = nodeEntry;
    } else {
      // Add new node
      this.nodes.push(nodeEntry);
    }

    // Update canvas bounds after new node is added
    this.updateCanvasBounds();
  },

  addRealCompositeNode(nodeData) {
    console.log("Creating composite node (addRealCompositeNode):", nodeData);
    const nodeEl = document.createElement('div');
    
    nodeEl.className = 'flow-node node-composite';
    nodeEl.style.position = 'absolute';
    nodeEl.style.left = `${nodeData.position.x}px`;
    nodeEl.style.top = `${nodeData.position.y}px`;
    nodeEl.style.width = '160px';
    nodeEl.style.minHeight = '100px';
    nodeEl.style.height = 'auto';
    
    // Outer border (2px black)
    nodeEl.style.border = '2px solid #000';
    nodeEl.style.borderRadius = '0';
    nodeEl.style.padding = '2px'; // Space for double border effect
    nodeEl.style.background = '#E8E8E8'; // Slightly darker grey for composites
    nodeEl.style.cursor = 'move';
    nodeEl.style.userSelect = 'none';
    nodeEl.style.fontFamily = "'Chicago', 'Geneva', 'Monaco', monospace";
    nodeEl.style.fontSize = '11px';
    nodeEl.style.color = '#000';
    nodeEl.style.boxShadow = '2px 2px 0 rgba(0,0,0,0.3)';
    nodeEl.dataset.nodeId = nodeData.node_id;
    nodeEl.dataset.compositeId = nodeData.composite_id;
    nodeEl.dataset.category = 'composite';
    nodeEl.id = nodeData.node_id;

    // Inner container for double border effect
    const innerDiv = document.createElement('div');
    innerDiv.style.border = '2px solid #666';
    innerDiv.style.borderRadius = '0';
    innerDiv.style.padding = '10px 12px';
    innerDiv.style.background = '#E8E8E8';

    // Selection checkbox (top-right)
    const checkbox = document.createElement('input');
    checkbox.type = 'checkbox';
    checkbox.className = 'node-select-checkbox';
    checkbox.style.position = 'absolute';
    checkbox.style.top = '4px';
    checkbox.style.right = '4px';
    checkbox.style.width = '16px';
    checkbox.style.height = '16px';
    checkbox.style.border = '1px solid #000';
    checkbox.style.background = '#FFF';
    checkbox.style.cursor = 'pointer';
    checkbox.style.accentColor = '#000';
    checkbox.style.filter = 'grayscale(100%)';
    checkbox.addEventListener('click', (e) => {
      e.stopPropagation();
      const id = nodeEl.dataset.nodeId;
      if (checkbox.checked) {
        if (!this.selectedNodes.includes(id)) {
          this.selectedNodes.push(id);
        }
        nodeEl.classList.add('selected');
        nodeEl.style.zIndex = '10';
        nodeEl.style.border = '5px solid #000';
        nodeEl.style.background = '#FFF';
        nodeEl.style.boxShadow = '4px 4px 0 #000';
      } else {
        this.selectedNodes = this.selectedNodes.filter(nid => nid !== id);
        nodeEl.classList.remove('selected');
        nodeEl.style.zIndex = '';
        nodeEl.style.border = '2px solid #000';
        nodeEl.style.background = '#E8E8E8';
        nodeEl.style.boxShadow = '2px 2px 0 rgba(0,0,0,0.3)';
      }
      if (this.updateSelectionCount) {
        this.updateSelectionCount();
      }
    });
    nodeEl.appendChild(checkbox);

    // Icon and name in same line
    const headerDiv = document.createElement('div');
    headerDiv.style.display = 'flex';
    headerDiv.style.alignItems = 'center';
    headerDiv.style.justifyContent = 'center';
    headerDiv.style.gap = '6px';
    headerDiv.style.marginBottom = '6px';

    const iconSpan = document.createElement('span');
    iconSpan.textContent = nodeData.icon_name || '📦';
    iconSpan.style.fontSize = '16px';
    iconSpan.style.lineHeight = '1';
    headerDiv.appendChild(iconSpan);

    const nameSpan = document.createElement('span');
    nameSpan.textContent = nodeData.name || 'Composite';
    nameSpan.style.fontSize = '12px';
    nameSpan.style.fontWeight = '700';
    nameSpan.style.fontFamily = "'Chicago', 'Geneva', monospace";
    headerDiv.appendChild(nameSpan);

    innerDiv.appendChild(headerDiv);

    // Description or node count
    const infoDiv = document.createElement('div');
    infoDiv.style.fontSize = '9px';
    infoDiv.style.opacity = '0.8';
    infoDiv.style.marginBottom = '4px';
    infoDiv.textContent = '(Click to view)';
    innerDiv.appendChild(infoDiv);

    // Input/Output counts
    const inputCount = Object.keys(nodeData.external_inputs || {}).length;
    const outputCount = Object.keys(nodeData.external_outputs || {}).length;
    
    const ioDiv = document.createElement('div');
    ioDiv.style.fontSize = '8px';
    ioDiv.style.opacity = '0.6';
    ioDiv.style.display = 'flex';
    ioDiv.style.justifyContent = 'space-around';
    ioDiv.style.marginTop = '6px';
    ioDiv.style.paddingTop = '4px';
    ioDiv.style.borderTop = '1px solid #666';
    ioDiv.innerHTML = `<span>In: ${inputCount}</span><span>Out: ${outputCount}</span>`;
    innerDiv.appendChild(ioDiv);

    nodeEl.appendChild(innerDiv);

    // Double-click to expand/collapse
    nodeEl.addEventListener('dblclick', (e) => {
      e.stopPropagation();
      console.log('Double-click on composite node, requesting expand');
      this.pushEvent('expand_composite_node', { node_id: nodeData.node_id });
    });

    this.makeDraggable(nodeEl);
    nodeEl.style.pointerEvents = 'auto';
    if (this.nodesContainer) {
      this.nodesContainer.appendChild(nodeEl);
    } else {
      this.canvas.appendChild(nodeEl);
    }
    
    this.syncCheckboxState(nodeEl);

    // Track in nodes array
    const existingNodeIndex = this.nodes.findIndex(n => n.id === nodeData.node_id);
    const nodeEntry = {
      id: nodeData.node_id,
      name: nodeData.name,
      category: 'composite',
      composite_system_id: nodeData.composite_id,
      x: nodeData.position?.x || 0,
      y: nodeData.position?.y || 0
    };
    
    if (existingNodeIndex >= 0) {
      this.nodes[existingNodeIndex] = nodeEntry;
    } else {
      this.nodes.push(nodeEntry);
    }

    this.updateCanvasBounds();
  },

  updateCanvasBounds() {
    const scrollArea = this.container.closest('.canvas-scroll-area');
    
    // Preserve scroll position to prevent viewport snapping
    // Use pending scroll position if set (from recent drag), otherwise use current
    let scrollLeft = this.pendingScrollLeft !== undefined ? this.pendingScrollLeft : (scrollArea ? scrollArea.scrollLeft : 0);
    let scrollTop = this.pendingScrollTop !== undefined ? this.pendingScrollTop : (scrollArea ? scrollArea.scrollTop : 0);
    
    // Clear pending scroll positions after use
    if (this.pendingScrollLeft !== undefined) {
      this.pendingScrollLeft = undefined;
      this.pendingScrollTop = undefined;
    }
    
    // If currently dragging, don't update bounds (wait until drag completes)
    if (this.isDraggingNode) {
      return;
    }
    
    // Debug: Log container hierarchy
    console.log('Container hierarchy:', {
      container: this.container,
      containerId: this.container?.id,
      containerHeight: this.container?.style?.height,
      scrollArea: scrollArea,
      canvas: this.canvas,
      canvasHeight: this.canvas?.style?.height
    });
    
    if (!this.canvas || !this.nodes || this.nodes.length === 0) {
      // If no nodes, set canvas to viewport size (no scrollbars)
      if (scrollArea) {
        scrollArea.style.overflowX = 'hidden';
        scrollArea.style.overflowY = 'hidden';
      }
      // Reset canvas to viewport size
      if (this.canvas) {
        const viewport = scrollArea || this.container;
        const viewportWidth = viewport.clientWidth || 800;
        const viewportHeight = viewport.clientHeight || 600;
        
        // Also reset parent container to match
        if (this.container) {
          this.container.style.setProperty('width', `${viewportWidth}px`, 'important');
          this.container.style.setProperty('height', `${viewportHeight}px`, 'important');
          this.container.style.setProperty('min-width', `${viewportWidth}px`, 'important');
          this.container.style.setProperty('min-height', `${viewportHeight}px`, 'important');
        }
        
        this.canvas.style.width = `${viewportWidth}px`;
        this.canvas.style.height = `${viewportHeight}px`;
        
        // Update SVG dimensions to match canvas
        if (this.svgContainer) {
          this.svgContainer.setAttribute('width', `${viewportWidth}`);
          this.svgContainer.setAttribute('height', `${viewportHeight}`);
        }
        this.canvas.style.minWidth = `${viewportWidth}px`;
        this.canvas.style.minHeight = `${viewportHeight}px`;
        
        // Update nodesContainer to match canvas size
        if (this.nodesContainer) {
          this.nodesContainer.style.width = `${viewportWidth}px`;
          this.nodesContainer.style.height = `${viewportHeight}px`;
          this.nodesContainer.style.minWidth = `${viewportWidth}px`;
          this.nodesContainer.style.minHeight = `${viewportHeight}px`;
        }
      }
      return;
    }

    // Get all node elements (exclude temporary nodes)
    const nodeElements = this.canvas.querySelectorAll('.flow-node:not(.temp-node)');
    if (nodeElements.length === 0) {
      if (scrollArea) {
        scrollArea.style.overflowX = 'hidden';
        scrollArea.style.overflowY = 'hidden';
      }
      // Reset canvas to viewport size
      if (this.canvas) {
        const viewport = scrollArea || this.container;
        const viewportWidth = viewport.clientWidth || 800;
        const viewportHeight = viewport.clientHeight || 600;
        
        // Also reset parent container to match
        if (this.container) {
          this.container.style.setProperty('width', `${viewportWidth}px`, 'important');
          this.container.style.setProperty('height', `${viewportHeight}px`, 'important');
          this.container.style.setProperty('min-width', `${viewportWidth}px`, 'important');
          this.container.style.setProperty('min-height', `${viewportHeight}px`, 'important');
        }
        
        this.canvas.style.width = `${viewportWidth}px`;
        this.canvas.style.height = `${viewportHeight}px`;
        
        // Update SVG dimensions to match canvas
        if (this.svgContainer) {
          this.svgContainer.setAttribute('width', `${viewportWidth}`);
          this.svgContainer.setAttribute('height', `${viewportHeight}`);
        }
        this.canvas.style.minWidth = `${viewportWidth}px`;
        this.canvas.style.minHeight = `${viewportHeight}px`;
        
        // Update nodesContainer to match canvas size
        if (this.nodesContainer) {
          this.nodesContainer.style.width = `${viewportWidth}px`;
          this.nodesContainer.style.height = `${viewportHeight}px`;
          this.nodesContainer.style.minWidth = `${viewportWidth}px`;
          this.nodesContainer.style.minHeight = `${viewportHeight}px`;
        }
      }
      return;
    }

    // Calculate bounds from all nodes
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    
    nodeElements.forEach(nodeEl => {
      const x = parseInt(nodeEl.style.left) || 0;
      const y = parseInt(nodeEl.style.top) || 0;
      const rect = nodeEl.getBoundingClientRect();
      const width = rect.width || 140; // Default node width
      const height = rect.height || 80; // Default node height
      
      minX = Math.min(minX, x);
      minY = Math.min(minY, y);
      maxX = Math.max(maxX, x + width);
      maxY = Math.max(maxY, y + height);
    });

    // Get the scroll area container (viewport)
    const viewport = scrollArea || this.container;
    
    // Get viewport dimensions (visible area)
    const viewportWidth = viewport.clientWidth || 800;
    const viewportHeight = viewport.clientHeight || 600;

    // Small margin (20px) - scrollbars appear when nodes are this close to viewport edge
    const edgeMargin = 20;
    
    // Calculate canvas dimensions based on node bounds
    // Handle negative positions by transforming the nodes container
    const canvasPadding = 50;
    
    // If we have negative positions, calculate offset to shift nodes right/down
    // This makes negative-positioned nodes accessible via scroll
    const offsetX = minX < 0 ? -minX + canvasPadding : 0;
    const offsetY = minY < 0 ? -minY + canvasPadding : 0;
    
    // Check if any nodes extend close to or beyond the visible viewport edges
    // Account for transform offset when checking positions
    let needsHorizontalScroll = false;
    let needsVerticalScroll = false;
    
    nodeElements.forEach(nodeEl => {
      const x = parseInt(nodeEl.style.left) || 0;
      const y = parseInt(nodeEl.style.top) || 0;
      const rect = nodeEl.getBoundingClientRect();
      const width = rect.width || 140;
      const height = rect.height || 80;
      
      // Account for transform offset - nodes at negative positions are shifted right/down
      const adjustedX = x + offsetX;
      const adjustedY = y + offsetY;
      
      // Node edges in adjusted canvas coordinates
      const nodeRightEdge = adjustedX + width;
      const nodeBottomEdge = adjustedY + height;
      
      // Check if node extends beyond right edge of viewport (with small margin)
      if (nodeRightEdge > viewportWidth - edgeMargin) {
        needsHorizontalScroll = true;
      }
      // Check if node extends beyond left edge (after offset adjustment)
      if (adjustedX < edgeMargin) {
        needsHorizontalScroll = true;
      }
      // Check if node extends beyond bottom edge of viewport (with small margin)
      if (nodeBottomEdge > viewportHeight - edgeMargin) {
        needsVerticalScroll = true;
      }
      // Check if node extends beyond top edge (after offset adjustment)
      if (adjustedY < edgeMargin) {
        needsVerticalScroll = true;
      }
    });
    
    // Transform the nodes container to shift nodes if needed
    // Only update transform if it actually changed to prevent visual jumps
    if (this.nodesContainer) {
      const currentTransform = this.nodesContainer.style.transform || '';
      const newTransform = (offsetX > 0 || offsetY > 0) ? `translate(${offsetX}px, ${offsetY}px)` : '';
      
      // Only apply transform if it's different from current to prevent unnecessary reflows
      if (currentTransform !== newTransform) {
        this.nodesContainer.style.transform = newTransform;
      }
    }
    
    // Calculate canvas dimensions including offset space for negative positions
    // The canvas needs to be large enough to contain all nodes including the offset
    const adjustedMinX = offsetX > 0 ? 0 : minX;
    const adjustedMinY = offsetY > 0 ? 0 : minY;
    const adjustedMaxX = maxX + offsetX;
    const adjustedMaxY = maxY + offsetY;
    
    const contentMinX = Math.min(0, adjustedMinX - canvasPadding);
    const contentMinY = Math.min(0, adjustedMinY - canvasPadding);
    const contentMaxX = adjustedMaxX + canvasPadding;
    const contentMaxY = adjustedMaxY + canvasPadding;
    
    const contentWidth = contentMaxX - contentMinX;
    const contentHeight = contentMaxY - contentMinY;

    // Canvas should be at least viewport size, but larger if nodes extend beyond
    const canvasWidth = Math.max(viewportWidth, contentWidth);
    const canvasHeight = Math.max(viewportHeight, contentHeight);

    // Debug logging - check actual DOM dimensions
    const actualContainerHeight = this.container ? this.container.offsetHeight : 0;
    const actualCanvasHeight = this.canvas ? this.canvas.offsetHeight : 0;
    const computedContainerHeight = this.container ? window.getComputedStyle(this.container).height : '0';
    const computedCanvasHeight = this.canvas ? window.getComputedStyle(this.canvas).height : '0';
    
    console.log('Canvas bounds calculation:', {
      viewportWidth,
      viewportHeight,
      contentWidth,
      contentHeight,
      canvasWidth,
      canvasHeight,
      maxY,
      adjustedMaxY,
      contentMaxY,
      minY,
      nodesCount: nodeElements.length,
      actualContainerHeight,
      actualCanvasHeight,
      computedContainerHeight,
      computedCanvasHeight
    });

    // Also update the parent container (#xyflow-container) to match canvas size
    // This is critical - the container must expand to allow canvas to grow
    // The container currently has height: 100% which constrains it - we need to override that
    if (this.container) {
      // Remove ALL constraints first
      this.container.style.setProperty('position', 'relative', 'important');
      this.container.style.setProperty('right', 'auto', 'important');
      this.container.style.setProperty('bottom', 'auto', 'important');
      
      // Set explicit dimensions that override the 100% constraint
      this.container.style.setProperty('width', `${canvasWidth}px`, 'important');
      this.container.style.setProperty('height', `${canvasHeight}px`, 'important');
      this.container.style.setProperty('min-width', `${canvasWidth}px`, 'important');
      this.container.style.setProperty('min-height', `${canvasHeight}px`, 'important');
      this.container.style.setProperty('max-width', 'none', 'important');
      this.container.style.setProperty('max-height', 'none', 'important');
      
      // Also apply background to container to ensure it's visible everywhere
      // Background is handled by .canvas-scroll-area CSS, container should be transparent
      this.container.style.setProperty('background', 'transparent', 'important');
      
      console.log('Updated container styles:', {
        setWidth: `${canvasWidth}px`,
        setHeight: `${canvasHeight}px`,
        computedWidth: window.getComputedStyle(this.container).width,
        computedHeight: window.getComputedStyle(this.container).height,
        offsetWidth: this.container.offsetWidth,
        offsetHeight: this.container.offsetHeight
      });
    }
    
    // Set canvas size - use explicit pixel values with !important to override CSS
    // This ensures the canvas expands beyond the viewport when needed
    // We need to use setProperty with important flag to override CSS rules
    this.canvas.style.setProperty('width', `${canvasWidth}px`, 'important');
    this.canvas.style.setProperty('height', `${canvasHeight}px`, 'important');
    this.canvas.style.setProperty('min-width', `${canvasWidth}px`, 'important');
    this.canvas.style.setProperty('min-height', `${canvasHeight}px`, 'important');
    // Remove any max-height constraints that might prevent expansion
    this.canvas.style.setProperty('max-width', 'none', 'important');
    this.canvas.style.setProperty('max-height', 'none', 'important');
    // Override position constraints that might limit expansion
    this.canvas.style.setProperty('bottom', 'auto', 'important');
    this.canvas.style.setProperty('right', 'auto', 'important');
    
    // Ensure background is always visible and covers the full canvas
    // Re-apply background styles to ensure they persist after size changes
    // Force background to cover entire area with explicit attachment
    this.canvas.style.background = 'transparent'; // Background is on .canvas-scroll-area
    
    // Update nodesContainer size to match canvas - it must cover the full canvas area
    // This ensures the background is always visible everywhere
    if (this.nodesContainer) {
      this.nodesContainer.style.width = `${canvasWidth}px`;
      this.nodesContainer.style.height = `${canvasHeight}px`;
      this.nodesContainer.style.minWidth = `${canvasWidth}px`;
      this.nodesContainer.style.minHeight = `${canvasHeight}px`;
    }

    if (scrollArea) {
      // Set overflow based on whether scrollbars are needed
      scrollArea.style.overflowX = needsHorizontalScroll ? 'auto' : 'hidden';
      scrollArea.style.overflowY = needsVerticalScroll ? 'auto' : 'hidden';
      
      // Also ensure scrollArea doesn't constrain the container
      // The scrollArea should allow its content (container) to expand
      scrollArea.style.setProperty('min-height', '0', 'important');
      scrollArea.style.setProperty('max-height', 'none', 'important');
    }
    
    // Force a reflow to ensure styles are applied
    // Sometimes the browser needs a nudge to recalculate
    if (this.container) {
      void this.container.offsetHeight; // Trigger reflow
    }
    if (this.canvas) {
      void this.canvas.offsetHeight; // Trigger reflow
    }
    
    // Restore scroll position to prevent viewport snapping
    // This ensures the user's view remains stable when nodes are moved
    // Use multiple restoration attempts to ensure it sticks
    if (scrollArea) {
      // Immediate restoration
      scrollArea.scrollLeft = scrollLeft;
      scrollArea.scrollTop = scrollTop;
      
      // Delayed restoration after layout
      requestAnimationFrame(() => {
        scrollArea.scrollLeft = scrollLeft;
        scrollArea.scrollTop = scrollTop;
        
        // One more after next frame to ensure it persists
        requestAnimationFrame(() => {
          scrollArea.scrollLeft = scrollLeft;
          scrollArea.scrollTop = scrollTop;
        });
      });
    }
  }
};

// Sync checkbox and selected styling from this.selectedNodes after (re)render
XyflowEditorHook.syncCheckboxState = function(nodeEl) {
  if (!nodeEl) return;
  const nodeId = nodeEl.dataset.nodeId;
  const checkbox = nodeEl.querySelector('.node-select-checkbox');
  if (!checkbox) return;

  if (this.selectedNodes && this.selectedNodes.includes(nodeId)) {
    checkbox.checked = true;
    nodeEl.classList.add('selected');
    nodeEl.style.zIndex = '10';
    nodeEl.style.border = '5px solid #000';
    nodeEl.style.background = '#FFF';
    nodeEl.style.boxShadow = '4px 4px 0 #000';
  } else {
    checkbox.checked = false;
    nodeEl.classList.remove('selected');
    nodeEl.style.zIndex = '';
    nodeEl.style.border = '2px solid #000';
    nodeEl.style.background = getCategoryBackground(nodeEl.dataset.category);
    nodeEl.style.boxShadow = '2px 2px 0 rgba(0,0,0,0.3)';
  }
};

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
    this.pushEvent("nodes_selected", { node_ids: nodeIds });
  }
  
  // Also update Connect button state and Save as System button state
  this.updateConnectButtonState();
  this.updateSaveAsSystemButtonState();
};

// Update Connect button enabled/disabled state based on selection
XyflowEditorHook.updateConnectButtonState = function() {
  if (!this.connectBtn) return;
  
  const count = this.selectedNodes ? this.selectedNodes.length : 0;
  const isEnabled = count === 2;
  
  this.connectBtn.disabled = !isEnabled;
  this.connectBtn.style.opacity = isEnabled ? '1' : '0.5';
  this.connectBtn.style.cursor = isEnabled ? 'pointer' : 'not-allowed';
};

// Update Save as System button enabled/disabled state based on selection
XyflowEditorHook.updateSaveAsSystemButtonState = function() {
  const saveAsSystemBtn = document.getElementById('save-as-system-btn');
  if (!saveAsSystemBtn) return;
  
  const count = this.selectedNodes ? this.selectedNodes.length : 0;
  const isEnabled = count >= 2;  // Need at least 2 nodes
  
  saveAsSystemBtn.disabled = !isEnabled;
  saveAsSystemBtn.style.opacity = isEnabled ? '1' : '0.5';
  saveAsSystemBtn.style.cursor = isEnabled ? 'pointer' : 'not-allowed';
};

// Toggle edge selection
XyflowEditorHook.toggleEdgeSelection = function(edgeId) {
  if (!this.selectedEdges) {
    this.selectedEdges = new Set();
  }
  
  if (this.selectedEdges.has(edgeId)) {
    this.selectedEdges.delete(edgeId);
  } else {
    this.selectedEdges.add(edgeId);
  }
  
  // Re-render edges to update visual state
  this.renderEdges();
  
  // Update selection count
  this.updateSelectionCount();
};

// Clear all edge selections
XyflowEditorHook.clearEdgeSelection = function() {
  if (this.selectedEdges) {
    this.selectedEdges.clear();
    this.renderEdges();
    this.updateSelectionCount();
  }
};

// Handle port click for connection creation (fallback method)
XyflowEditorHook.handlePortClick = function(handle, portType) {
  const portName = handle.dataset.port;
  const nodeId = handle.dataset.nodeId;
  
  // Initialize connection state if not exists
  if (!this.connectingPort) {
    if (portType === 'output') {
      this.connectingPort = {
        nodeId: nodeId,
        port: portName,
        type: portType,
        handle: handle
      };
      handle.style.background = '#999';
      handle.style.border = '3px solid #000';
      console.log(`[Port] Started connection from ${portType} port "${portName}" on node ${nodeId}`);
      
      // Highlight compatible inputs
      this.highlightCompatibleInputs(portName);
    } else {
      console.log('[Port] Click on input port - waiting for output port to be selected first');
    }
  } else {
    // Complete connection
    const sourceNodeId = this.connectingPort.nodeId;
    const sourcePort = this.connectingPort.port;
    const sourceType = this.connectingPort.type;
    const targetNodeId = nodeId;
    const targetPort = portName;
    const targetType = portType;
    
    // Validate connection (output -> input)
    if (sourceType === 'output' && targetType === 'input') {
      // Check if ports are compatible (same name)
      if (sourcePort === targetPort) {
        // Create edge
        this.createConnection(sourceNodeId, targetNodeId, sourcePort, targetPort);
      } else {
        alert(`Cannot connect: "${sourcePort}" output to "${targetPort}" input. Ports must match.`);
        this.cancelConnection();
      }
    } else {
      alert('Can only connect output ports to input ports.');
      this.cancelConnection();
    }
  }
};

// Handle port drop (for drag-and-drop connections)
XyflowEditorHook.handlePortDrop = function(handle, portType) {
  const portName = handle.dataset.port;
  const nodeId = handle.dataset.nodeId;
  
  if (!this.connectingPort || this.connectingPort.type !== 'output') {
    console.log('[Port] Drop rejected - no active output connection');
    return;
  }
  
  // Prevent drop on the same node
  if (this.connectingPort.nodeId === nodeId) {
    console.log('[Port] Drop rejected - cannot connect to same node');
    this.cancelConnection();
    return;
  }
  
  const sourceNodeId = this.connectingPort.nodeId;
  const sourcePort = this.connectingPort.port;
  const targetNodeId = nodeId;
  const targetPort = portName;
  
  // Validate connection (ports must match)
  if (sourcePort === targetPort) {
    this.createConnection(sourceNodeId, targetNodeId, sourcePort, targetPort);
  } else {
    alert(`Cannot connect: "${sourcePort}" output to "${targetPort}" input. Ports must match.`);
    this.cancelConnection();
  }
};

// Create connection between ports
XyflowEditorHook.createConnection = function(sourceNodeId, targetNodeId, sourcePort, targetPort) {
  // Validate: don't create self-loops
  if (sourceNodeId === targetNodeId) {
    console.log('[Port] Cannot create self-loop connection');
    this.cancelConnection();
    return;
  }
  
  // Create edge
  this.pushEvent('edge_added', {
    source_id: sourceNodeId,
    target_id: targetNodeId,
    source_handle: sourcePort,
    target_handle: targetPort,
    label: sourcePort.replace(/_/g, ' ') // Convert underscores to spaces for display
  });
  console.log(`[Port] Created connection: ${sourcePort} from ${sourceNodeId} to ${targetNodeId}`);
  
  // Reset connection state
  this.cancelConnection();
};

// Cancel current connection attempt
XyflowEditorHook.cancelConnection = function() {
  if (this.connectingPort) {
    const sourceHandle = this.connectingPort.handle;
    if (sourceHandle) {
      sourceHandle.style.background = '#FFF';
      sourceHandle.style.border = '2px solid #000';
      sourceHandle.style.cursor = 'grab';
    }
    this.clearInputHighlights();
    this.connectingPort = null;
  }
};

// Highlight compatible input handles
XyflowEditorHook.highlightCompatibleInputs = function(portName) {
  const allInputHandles = this.canvas.querySelectorAll('.input-handle[data-port="' + portName + '"]');
  allInputHandles.forEach(handle => {
    handle.style.border = '3px solid #999';
    handle.style.boxShadow = '0 0 8px rgba(0,0,0,0.5)';
  });
};

// Clear input handle highlights
XyflowEditorHook.clearInputHighlights = function() {
  const allInputHandles = this.canvas.querySelectorAll('.input-handle');
  allInputHandles.forEach(handle => {
    handle.style.border = '2px solid #000';
    handle.style.boxShadow = '1px 1px 0 rgba(0,0,0,0.3)';
    handle.style.background = '#FFF';
  });
};

// Show modal for saving composite system
XyflowEditorHook.showSaveSystemModal = function() {
  const selectedArray = this.selectedNodes;
  
  // Create modal overlay
  const overlay = document.createElement('div');
  overlay.style.position = 'fixed';
  overlay.style.top = '0';
  overlay.style.left = '0';
  overlay.style.width = '100%';
  overlay.style.height = '100%';
  overlay.style.background = 'rgba(0, 0, 0, 0.5)';
  overlay.style.zIndex = '10000';
  overlay.style.display = 'flex';
  overlay.style.alignItems = 'center';
  overlay.style.justifyContent = 'center';
  
  // Create modal content
  const modal = document.createElement('div');
  modal.style.background = '#FFF';
  modal.style.border = '3px solid #000';
  modal.style.borderRadius = '0';
  modal.style.padding = '20px';
  modal.style.width = '400px';
  modal.style.fontFamily = "'Chicago', 'Geneva', 'Monaco', monospace";
  modal.style.fontSize = '12px';
  modal.style.boxShadow = '4px 4px 0 rgba(0,0,0,0.3)';
  
  modal.innerHTML = `
    <div style="margin-bottom: 15px; font-weight: bold; font-size: 14px;">Save as System</div>
    <div style="margin-bottom: 10px;">
      <label style="display: block; margin-bottom: 5px;">Name *</label>
      <input type="text" id="system-name-input" style="width: 100%; padding: 4px; border: 1px solid #000; border-radius: 0; font-family: inherit; font-size: 11px;" />
    </div>
    <div style="margin-bottom: 10px;">
      <label style="display: block; margin-bottom: 5px;">Description</label>
      <textarea id="system-description-input" rows="3" style="width: 100%; padding: 4px; border: 1px solid #000; border-radius: 0; font-family: inherit; font-size: 11px; resize: none;"></textarea>
    </div>
    <div style="margin-bottom: 15px;">
      <label style="display: block; margin-bottom: 5px;">Icon (optional)</label>
      <input type="text" id="system-icon-input" placeholder="e.g., 🌱" style="width: 100%; padding: 4px; border: 1px solid #000; border-radius: 0; font-family: inherit; font-size: 11px;" />
    </div>
    <div style="display: flex; gap: 10px; justify-content: flex-end;">
      <button id="save-system-cancel" style="padding: 6px 12px; background: #FFF; border: 2px solid #000; border-radius: 0; cursor: pointer; font-family: inherit; font-size: 11px;">Cancel</button>
      <button id="save-system-submit" style="padding: 6px 12px; background: #FFF; border: 2px solid #000; border-radius: 0; cursor: pointer; font-family: inherit; font-size: 11px; font-weight: bold;">Save</button>
    </div>
  `;
  
  overlay.appendChild(modal);
  document.body.appendChild(overlay);
  
  // Focus on name input
  const nameInput = modal.querySelector('#system-name-input');
  nameInput.focus();
  
  // Cancel handler
  const cancelBtn = modal.querySelector('#save-system-cancel');
  cancelBtn.addEventListener('click', () => {
    document.body.removeChild(overlay);
  });
  
  // Submit handler
  const submitBtn = modal.querySelector('#save-system-submit');
  submitBtn.addEventListener('click', (e) => {
    e.preventDefault();
    e.stopPropagation();
    
    const name = nameInput.value.trim();
    if (!name) {
      alert('Please enter a name for the system');
      return;
    }
    
    const description = modal.querySelector('#system-description-input').value.trim();
    const iconName = modal.querySelector('#system-icon-input').value.trim();
    
    // Disable button to prevent double-clicks
    submitBtn.disabled = true;
    submitBtn.textContent = 'Saving...';
    
    try {
      // Store overlay reference for the response handler
      this.currentSaveOverlay = overlay;
      
      // Push event to server
      this.pushEvent('save_composite_system', {
        name: name,
        description: description,
        icon_name: iconName || null,
        node_ids: selectedArray
      });
      
      console.log('Save composite system event sent successfully');
      
      // Modal will be closed by the response handler
    } catch (error) {
      console.error('Error saving composite system:', error);
      alert('Error saving system: ' + error.message);
      submitBtn.disabled = false;
      submitBtn.textContent = 'Save';
    }
  });
  
  // Close on overlay click (but not modal click)
  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) {
      document.body.removeChild(overlay);
    }
  });
  
  // Close on Escape key
  const escapeHandler = (e) => {
    if (e.key === 'Escape') {
      document.body.removeChild(overlay);
      document.removeEventListener('keydown', escapeHandler);
    }
  };
  document.addEventListener('keydown', escapeHandler);
};

// Show suggestions panel
XyflowEditorHook.showSuggestionsPanel = function(suggestions) {
  // Remove existing panel if present
  const existing = document.getElementById('suggestions-panel');
  if (existing) {
    existing.remove();
  }

  if (suggestions.length === 0) {
    alert('No suggestions available at this time.');
    return;
  }

  // Create panel overlay
  const overlay = document.createElement('div');
  overlay.id = 'suggestions-panel';
  overlay.style.position = 'fixed';
  overlay.style.top = '0';
  overlay.style.left = '0';
  overlay.style.width = '100%';
  overlay.style.height = '100%';
  overlay.style.background = 'rgba(0, 0, 0, 0.5)';
  overlay.style.zIndex = '10000';
  overlay.style.display = 'flex';
  overlay.style.alignItems = 'center';
  overlay.style.justifyContent = 'center';

  // Create panel content
  const panel = document.createElement('div');
  panel.style.background = '#FFF';
  panel.style.border = '3px solid #000';
  panel.style.borderRadius = '0';
  panel.style.padding = '20px';
  panel.style.width = '500px';
  panel.style.maxHeight = '70vh';
  panel.style.overflowY = 'auto';
  panel.style.fontFamily = "'Chicago', 'Geneva', 'Monaco', monospace";
  panel.style.fontSize = '12px';
  panel.style.boxShadow = '4px 4px 0 rgba(0,0,0,0.3)';

  panel.innerHTML = `
    <div style="margin-bottom: 15px; font-weight: bold; font-size: 14px; display: flex; justify-content: space-between; align-items: center;">
      <span>Suggestions (${suggestions.length})</span>
      <button id="suggestions-close" style="padding: 4px 8px; background: #FFF; border: 1px solid #000; border-radius: 0; cursor: pointer; font-family: inherit; font-size: 10px;">Close</button>
    </div>
    <div id="suggestions-list"></div>
  `;

  const listDiv = panel.querySelector('#suggestions-list');
  
  suggestions.forEach((suggestion, index) => {
    const priorityColor = suggestion.priority === 'high' ? '#000' : (suggestion.priority === 'medium' ? '#333' : '#666');
    const item = document.createElement('div');
    item.style.padding = '10px';
    item.style.marginBottom = '8px';
    item.style.border = '1px solid #000';
    item.style.background = '#FFF';
    item.style.borderLeft = `4px solid ${priorityColor}`;
    
    item.innerHTML = `
      <div style="margin-bottom: 5px; font-weight: bold; color: ${priorityColor};">
        [${suggestion.priority.toUpperCase()}] ${suggestion.type}
      </div>
      <div style="margin-bottom: 8px; font-size: 11px;">
        ${suggestion.description}
      </div>
      <button class="apply-suggestion-btn" data-index="${index}" style="padding: 4px 8px; background: #FFF; border: 1px solid #000; border-radius: 0; cursor: pointer; font-family: inherit; font-size: 10px;">
        Apply
      </button>
    `;
    
    const applyBtn = item.querySelector('.apply-suggestion-btn');
    applyBtn.addEventListener('click', () => {
      this.pushEvent('apply_suggestion', {
        type: suggestion.type,
        action: suggestion.action
      });
      overlay.remove();
    });
    
    listDiv.appendChild(item);
  });

  overlay.appendChild(panel);
  document.body.appendChild(overlay);

  // Close button
  const closeBtn = panel.querySelector('#suggestions-close');
  closeBtn.addEventListener('click', () => {
    overlay.remove();
  });

  // Close on overlay click
  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) {
      overlay.remove();
    }
  });

  // Close on Escape
  const escapeHandler = (e) => {
    if (e.key === 'Escape') {
      overlay.remove();
      document.removeEventListener('keydown', escapeHandler);
    }
  };
  document.addEventListener('keydown', escapeHandler);
};

// Enable inline editing for node name
XyflowEditorHook.enableNodeNameEdit = function(nameDiv, nodeId, defaultName) {
  const currentText = nameDiv.textContent.trim();
  
  // Create input field
  const input = document.createElement('input');
  input.type = 'text';
  input.value = currentText;
  input.style.width = '100%';
  input.style.padding = '2px 4px';
  input.style.border = '1px solid #000';
  input.style.borderRadius = '0';
  input.style.background = '#FFF';
  input.style.color = '#000';
  input.style.fontFamily = "'Chicago', 'Geneva', 'Monaco', monospace";
  input.style.fontSize = '11px';
  input.style.fontWeight = 'bold';
  input.style.boxShadow = 'inset 1px 1px 0 rgba(0,0,0,0.3)';
  
  // Replace nameDiv with input
  nameDiv.style.display = 'none';
  nameDiv.parentNode.insertBefore(input, nameDiv);
  input.focus();
  input.select();
  
  // Save on blur or Enter
  const saveName = () => {
    const newName = input.value.trim();
    const finalName = newName || defaultName;
    
    // Update nameDiv content
    nameDiv.textContent = finalName;
    nameDiv.style.display = '';
    input.remove();
    
    // Only push event if name changed
    if (finalName !== currentText && finalName !== defaultName) {
      this.pushEvent('node_renamed', {
        node_id: nodeId,
        custom_name: finalName
      });
      
      // Update local node data
      const node = this.nodes.find(n => n.id === nodeId);
      if (node) {
        node.custom_name = finalName;
      }
    } else if (finalName === defaultName) {
      // If name was reset to default, clear custom_name
      this.pushEvent('node_renamed', {
        node_id: nodeId,
        custom_name: null
      });
      
      const node = this.nodes.find(n => n.id === nodeId);
      if (node) {
        delete node.custom_name;
      }
    }
  };
  
  // Cancel on Escape
  const cancelEdit = () => {
    nameDiv.style.display = '';
    input.remove();
  };
  
  input.addEventListener('blur', saveName);
  input.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      saveName();
    } else if (e.key === 'Escape') {
      e.preventDefault();
      cancelEdit();
    }
  });
};

function getCategoryIcon(node) {
  if (node.icon_name) return node.icon_name;
  if (node.icon) return node.icon;
  const category = (node.category || '').toLowerCase();
  switch (category) {
    case 'food': return '🌱';
    case 'water': return '💧';
    case 'waste': return '♻️';
    case 'energy': return '⚡';
    case 'processing': return '⚙️';
    case 'storage': return '📦';
    case 'composite': return '📦';
    default: return '▣';
  }
}

// Add keyboard shortcuts and zoom methods to hook
XyflowEditorHook.setupKeyboardShortcuts = function() {
  // Global keyboard listener
  this.keyboardHandler = (e) => {
    // Don't trigger if typing in input field
    if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA' || e.target.isContentEditable) {
      return;
    }

    // Ctrl/Cmd + Z = Undo
    if ((e.ctrlKey || e.metaKey) && e.key === 'z' && !e.shiftKey) {
      e.preventDefault();
      this.pushEvent('undo', {});
      return;
    }

    // Ctrl/Cmd + Shift + Z OR Ctrl/Cmd + Y = Redo
    if ((e.ctrlKey || e.metaKey) && (e.key === 'y' || (e.key === 'z' && e.shiftKey))) {
      e.preventDefault();
      this.pushEvent('redo', {});
      return;
    }

      // Delete/Backspace = Delete selected
      if ((e.key === 'Delete' || e.key === 'Backspace') && this.selectedNodes && this.selectedNodes.length > 0) {
        e.preventDefault();
        this.pushEvent('bulk_delete', { node_ids: this.selectedNodes });
        return;
      }

      // PART 2: Fix Escape Key - Complete rewrite
      if (e.key === 'Escape') {
        e.preventDefault();
        
        // Close detail sidebar
        this.pushEvent("close_detail_panel", {});
        
        // Clear selection
        this.selectedNodes = [];
        this.pushEvent("deselect_all", {});
        
        // Force re-render
        this.renderNodes();
        this.renderEdges();
        return;
      }

      // Ctrl/Cmd + A = Select all visible nodes
      if ((e.ctrlKey || e.metaKey) && e.key === 'a') {
        e.preventDefault();
        this.selectedNodes = this.nodes.map(n => n.id);
        this.renderNodes();
        this.pushEvent('nodes_selected', { node_ids: this.selectedNodes });
        return;
      }

    // ? = Show keyboard shortcuts help
    if (e.key === '?') {
      e.preventDefault();
      this.showKeyboardHelp = !this.showKeyboardHelp;
      this.pushEvent('toggle_keyboard_help', {});
      return;
    }

    // Arrow keys = Pan canvas
    if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.key)) {
      e.preventDefault();
      const panAmount = e.shiftKey ? 50 : 10;

      switch(e.key) {
        case 'ArrowUp': 
          this.panY += panAmount; 
          break;
        case 'ArrowDown': 
          this.panY -= panAmount; 
          break;
        case 'ArrowLeft': 
          this.panX += panAmount; 
          break;
        case 'ArrowRight': 
          this.panX -= panAmount; 
          break;
      }

      console.log('Panning:', this.panX, this.panY);
      this.applyZoomTransform(); // CRITICAL: Must call this!
      return;
    }

    // + or = key - Zoom in
    if (e.key === '+' || e.key === '=') {
      e.preventDefault();
      this.zoomLevel = Math.min(3, (this.zoomLevel || 1) * 1.1);
      console.log('Zoom in:', this.zoomLevel);
      this.applyZoomTransform(); // CRITICAL
      return;
    }

    // - or _ key - Zoom out
    if (e.key === '-' || e.key === '_') {
      e.preventDefault();
      this.zoomLevel = Math.max(0.1, (this.zoomLevel || 1) * 0.9);
      console.log('Zoom out:', this.zoomLevel);
      this.applyZoomTransform(); // CRITICAL
      return;
    }

    // 0 = Reset zoom and pan (handle both main keyboard and numpad)
    if (e.key === '0' || e.code === 'Digit0' || e.code === 'Numpad0') {
      e.preventDefault();
      e.stopPropagation();

      console.log('Reset zoom/pan triggered');

      this.zoomLevel = 1;
      this.panX = 0;
      this.panY = 0;

      this.applyZoomTransform();

      // Also reset any SVG transforms directly as backup
      if (this.svgContainer) {
        this.svgContainer.style.transform = 'scale(1) translate(0px, 0px)';
      }

      const nodesContainer = this.nodesContainer || 
                             this.el.querySelector('.nodes-container') || 
                             this.el.querySelector('[data-nodes-container]');
      if (nodesContainer) {
        nodesContainer.style.transform = 'scale(1) translate(0px, 0px)';
      }

      console.log('Zoom/pan reset complete');
      return;
    }
  };

  document.addEventListener('keydown', this.keyboardHandler);
};

XyflowEditorHook.setupZoomAndPan = function() {
  // Zoom with Ctrl/Cmd + Mouse Wheel
  const canvasArea = this.el.querySelector('.canvas-area') || this.el;

  canvasArea.addEventListener('wheel', (e) => {
    if (e.ctrlKey || e.metaKey) {
      e.preventDefault(); // CRITICAL: Prevent page zoom
      e.stopPropagation();

      const zoomDelta = e.deltaY > 0 ? 0.9 : 1.1;
      this.zoomLevel = Math.max(0.1, Math.min(3, (this.zoomLevel || 1) * zoomDelta));

      console.log('Zoom level:', this.zoomLevel);

      this.applyZoomTransform();
    }
  }, { passive: false }); // Important: passive false allows preventDefault
};

XyflowEditorHook.applyZoomTransform = function() {
  const transform = `scale(${this.zoomLevel}) translate(${this.panX}px, ${this.panY}px)`;

  // Apply to SVG container (edges)
  if (this.svgContainer) {
    this.svgContainer.style.transform = transform;
    this.svgContainer.style.transformOrigin = '0 0';
  }

  // Apply to nodes container
  const nodesContainer = this.nodesContainer || 
                         this.el.querySelector('.nodes-container') || 
                         this.el.querySelector('[data-nodes-container]');

  if (nodesContainer) {
    nodesContainer.style.transform = transform;
    nodesContainer.style.transformOrigin = '0 0';
  }

  console.log('Applied zoom transform:', this.zoomLevel, 'pan:', this.panX, this.panY);
  console.log('SVG container:', this.svgContainer);
  console.log('Nodes container:', nodesContainer);
};

// Clean up on destroy
if (!XyflowEditorHook.destroyed) {
  const originalDestroyed = XyflowEditorHook.destroyed || function() {};
  XyflowEditorHook.destroyed = function() {
    // Clean up keyboard listener
    if (this.keyboardHandler) {
      document.removeEventListener('keydown', this.keyboardHandler);
    }
    // Call original destroyed if it exists
    if (originalDestroyed) {
      originalDestroyed.call(this);
    }
  };
}

export default XyflowEditorHook;

// Helpers appended to hook
function getCategoryBackground(category) {
  // Category shading (greyscale only) - more visible than before
  switch ((category || '').toLowerCase()) {
    case 'food': return '#E8E8E8';      // Light grey
    case 'water': return '#D8D8D8';     // Medium-light grey
    case 'waste': return '#C8C8C8';      // Medium grey
    case 'energy': return '#B8B8B8';     // Medium-dark grey
    case 'processing': return '#D0D0D0'; // Between light and medium
    case 'storage': return '#D0D0D0';   // Between light and medium
    case 'composite': return '#E8E8E8'; // Very light grey
    default: return '#E8E8E8';
  }
}

function getProjectById(projects, projectId) {
  if (!projects || !projectId) return null;
  const idNum = typeof projectId === 'string' ? parseInt(projectId, 10) : projectId;
  return projects.find((p) => p.id === idNum) || null;
}

function isPositionOccupied(x, y, existingNodes, threshold = 50) {
  return existingNodes.some((n) => {
    const nx = typeof n.x === 'number' ? n.x : (n.position && n.position.x) || 0;
    const ny = typeof n.y === 'number' ? n.y : (n.position && n.position.y) || 0;
    const dx = nx - x;
    const dy = ny - y;
    const distance = Math.sqrt(dx * dx + dy * dy);
    return distance < threshold;
  });
}

XyflowEditorHook.findAvailablePosition = function(initialX, initialY) {
  let finalX = initialX;
  let finalY = initialY;
  let attempts = 0;
  while (isPositionOccupied(finalX, finalY, this.nodes) && attempts < 10) {
    finalX += 30;
    finalY += 30;
    attempts++;
  }
  return { x: finalX, y: finalY };
};
