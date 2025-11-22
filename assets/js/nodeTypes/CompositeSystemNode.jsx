import { Handle, Position } from 'reactflow';

const COLORS = {
  default: { bg: '#E8E8E8', border: '#000000', innerBorder: '#666666', text: '#000000' },
  selected: { bg: '#D8D8D8', border: '#000000', innerBorder: '#333333', text: '#000000' },
  hover: { bg: '#E0E0E0', border: '#000000', innerBorder: '#666666', text: '#000000' },
  expanded: { bg: '#F0F0F0', border: '#000000', innerBorder: '#999999', text: '#000000' }
};

function CompositeSystemNode({ data, selected }) {
  const isExpanded = data.is_expanded || false;
  const colors = isExpanded ? COLORS.expanded : (selected ? COLORS.selected : COLORS.default);
  
  // Generate handles based on external inputs/outputs
  const externalInputs = data.external_inputs || {};
  const externalOutputs = data.external_outputs || {};
  const inputCount = Object.keys(externalInputs).length;
  const outputCount = Object.keys(externalOutputs).length;

  return (
    <div
      style={{
        position: 'relative',
        background: colors.bg,
        border: `2px solid ${colors.border}`,
        borderRadius: '0px',
        padding: '2px',
        minWidth: '160px',
        color: colors.text,
        fontFamily: "'Chicago', 'Geneva', 'Monaco', system-ui",
        fontSize: '11px',
        fontWeight: '500',
        textAlign: 'center',
        boxShadow: selected ? '0 0 0 3px #000000' : '2px 2px 0 #666666',
        cursor: 'move'
      }}
    >
      {/* Double border effect - inner border */}
      <div
        style={{
          border: `2px solid ${colors.innerBorder}`,
          borderRadius: '0px',
          padding: '10px 12px',
          background: colors.bg
        }}
      >
        {/* Icon and header */}
        <div style={{ 
          display: 'flex', 
          alignItems: 'center', 
          justifyContent: 'center',
          gap: '6px',
          marginBottom: '6px'
        }}>
          <span style={{ fontSize: '16px', lineHeight: '1' }}>
            {data.icon_name || '📦'}
          </span>
          <span style={{ 
            fontSize: '12px', 
            fontWeight: '700',
            fontFamily: "'Chicago', 'Geneva', monospace"
          }}>
            {data.label || data.name || 'Composite'}
          </span>
        </div>

        {/* Description or node count */}
        <div style={{ 
          fontSize: '9px', 
          opacity: 0.8,
          marginBottom: '4px'
        }}>
          {isExpanded ? '(Expanded)' : `(${data.node_count || inputCount + outputCount} nodes)`}
        </div>

        {/* Input/Output indicator */}
        {!isExpanded && (
          <div style={{ 
            fontSize: '8px', 
            opacity: 0.6,
            display: 'flex',
            justifyContent: 'space-around',
            marginTop: '6px',
            paddingTop: '4px',
            borderTop: `1px solid ${colors.innerBorder}`
          }}>
            <span>In: {inputCount}</span>
            <span>Out: {outputCount}</span>
          </div>
        )}

        {/* Expansion state badge */}
        {isExpanded && (
          <div style={{
            position: 'absolute',
            top: '2px',
            right: '2px',
            background: '#000',
            color: '#FFF',
            padding: '2px 4px',
            fontSize: '7px',
            fontWeight: 'bold',
            fontFamily: "'Monaco', monospace"
          }}>
            EXPANDED
          </div>
        )}
      </div>

      {/* Input handles - left side */}
      {!isExpanded && Object.keys(externalInputs).map((inputKey, idx) => (
        <Handle
          key={`input-${inputKey}`}
          type="target"
          position={Position.Left}
          id={`input-${inputKey}`}
          style={{ 
            background: '#666666', 
            width: '10px', 
            height: '10px',
            border: '2px solid #000',
            top: `${(idx + 1) * (100 / (inputCount + 1))}%`
          }}
          title={inputKey}
        />
      ))}

      {/* Output handles - right side */}
      {!isExpanded && Object.keys(externalOutputs).map((outputKey, idx) => (
        <Handle
          key={`output-${outputKey}`}
          type="source"
          position={Position.Right}
          id={`output-${outputKey}`}
          style={{ 
            background: '#666666', 
            width: '10px', 
            height: '10px',
            border: '2px solid #000',
            top: `${(idx + 1) * (100 / (outputCount + 1))}%`
          }}
          title={outputKey}
        />
      ))}

      {/* If expanded, show single general-purpose handles */}
      {isExpanded && (
        <>
          <Handle
            type="target"
            position={Position.Left}
            style={{ 
              background: '#999999', 
              width: '12px', 
              height: '12px',
              border: '2px solid #000'
            }}
          />
          <Handle
            type="source"
            position={Position.Right}
            style={{ 
              background: '#999999', 
              width: '12px', 
              height: '12px',
              border: '2px solid #000'
            }}
          />
        </>
      )}
    </div>
  );
}

export default CompositeSystemNode;














