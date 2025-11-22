import { Handle, Position } from 'reactflow';

const COLORS = {
  default: { bg: '#F8F8F8', border: '#333333', text: '#666666' },
  selected: { bg: '#E8E8E8', border: '#000000', text: '#000000' },
  hover: { bg: '#F0F0F0', border: '#333333', text: '#333333' }
};

function ResourceNode({ data, selected }) {
  const colors = selected ? COLORS.selected : COLORS.default;
  
  // TODO: Extract inputs/outputs from node data
  // Each node should have: data.inputs = ["water", "sunlight", ...]
  //                         data.outputs = ["herbs", "waste", ...]
  const inputs = data.inputs || [];
  const outputs = data.outputs || [];

  const handleClick = () => {
    const eventPayload = {
      node_id: data.id,
      node_type: "resource",
      node_label: data.label
    };
    
    window.liveSocket?.execJS(document.body, `
      this.pushEvent("node_selected", ${JSON.stringify(eventPayload)})
    `);
  };

  return (
    <div
      onClick={handleClick}
      style={{
        background: colors.bg,
        border: `2px solid ${colors.border}`,
        borderRadius: '0px', // Square corners for resource nodes
        padding: '8px 12px',
        minWidth: '120px',
        color: colors.text,
        fontFamily: "'Geneva', 'Monaco', 'Chicago', system-ui",
        fontSize: '11px',
        fontWeight: '500',
        textAlign: 'center',
        boxShadow: selected ? '0 0 0 2px #000000' : 'none',
        position: 'relative',
        cursor: 'pointer'
      }}
    >
      {/* TODO: Render multiple input handles on LEFT side */}
      {/* Each input should have:
          - Handle with id="input-{inputName}" (e.g., "input-water")
          - Position: Position.Left
          - Vertical spacing based on index
          - Tooltip showing input name on hover
          - Color coding by resource type (water=blue, sunlight=yellow, etc.)
          - Show handles on hover or always visible (TBD)
      */}
      {inputs.length === 0 ? (
        <Handle
          type="target"
          position={Position.Left}
          style={{ background: '#666666', width: '8px', height: '8px' }}
        />
      ) : (
        inputs.map((input, index) => (
          <Handle
            key={`input-${input}`}
            id={`input-${input}`}
            type="target"
            position={Position.Left}
            style={{
              background: '#666666',
              width: '8px',
              height: '8px',
              top: `${20 + (index * 25)}px`, // TODO: Adjust spacing based on node height
              left: '-4px'
            }}
            // TODO: Add tooltip with input name
            // TODO: Add color coding based on resource type
          />
        ))
      )}

      <div style={{ marginBottom: '4px', fontSize: '12px', fontWeight: '600' }}>
        {data.label}
      </div>
      <div style={{ fontSize: '9px', opacity: 0.8 }}>
        {data.category}
      </div>

      {/* TODO: Render multiple output handles on RIGHT side */}
      {/* Each output should have:
          - Handle with id="output-{outputName}" (e.g., "output-herbs")
          - Position: Position.Right
          - Vertical spacing based on index
          - Tooltip showing output name on hover
          - Color coding by resource type
          - Show handles on hover or always visible (TBD)
      */}
      {outputs.length === 0 ? (
        <Handle
          type="source"
          position={Position.Right}
          style={{ background: '#666666', width: '8px', height: '8px' }}
        />
      ) : (
        outputs.map((output, index) => (
          <Handle
            key={`output-${output}`}
            id={`output-${output}`}
            type="source"
            position={Position.Right}
            style={{
              background: '#666666',
              width: '8px',
              height: '8px',
              top: `${20 + (index * 25)}px`, // TODO: Adjust spacing based on node height
              right: '-4px'
            }}
            // TODO: Add tooltip with output name
            // TODO: Add color coding based on resource type
          />
        ))
      )}
    </div>
  );
}

export default ResourceNode;

