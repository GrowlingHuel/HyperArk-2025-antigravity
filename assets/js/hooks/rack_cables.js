export const RackCables = {
    mounted() {
        // Initial draw
        this.drawCables();

        // Listen for server updates
        this.handleEvent("update_cables", ({ cables }) => {
            this.cables = cables;
            this.drawCables();
        });

        // Redraw on window resize - PURE CLIENT SIDE
        this.resizeHandler = () => {
            if (this.cables) {
                this.drawCables();
            }
        };
        window.addEventListener("resize", this.resizeHandler);
    },

    destroyed() {
        if (this.resizeHandler) {
            window.removeEventListener("resize", this.resizeHandler);
        }
    },

    updated() {
        const cablesData = this.el.dataset.cables;
        if (cablesData) {
            try {
                this.cables = JSON.parse(cablesData);
                this.drawCables();
            } catch (e) {
                console.error("Failed to parse cables data", e);
            }
        }
    },

    drawCables() {
        if (!this.cables) return;

        // Clear existing paths
        this.el.innerHTML = '';

        const svgRect = this.el.getBoundingClientRect();

        this.cables.forEach(cable => {
            const sourceId = `${cable.source_device_id}-${cable.source_jack_id}`;
            const targetId = `${cable.target_device_id}-${cable.target_jack_id}`;

            const sourceEl = document.querySelector(`.rack-jack[data-jack-id="${sourceId}"]`);
            const targetEl = document.querySelector(`.rack-jack[data-jack-id="${targetId}"]`);

            if (sourceEl && targetEl) {
                const sourceRect = sourceEl.getBoundingClientRect();
                const targetRect = targetEl.getBoundingClientRect();

                const x1 = (sourceRect.left - svgRect.left) + (sourceRect.width / 2);
                const y1 = (sourceRect.top - svgRect.top) + (sourceRect.height / 2);
                const x2 = (targetRect.left - svgRect.left) + (targetRect.width / 2);
                const y2 = (targetRect.top - svgRect.top) + (targetRect.height / 2);

                // Bezier Logic (Gravity)
                const yDiff = Math.abs(y2 - y1);
                const sag = Math.min(100, yDiff * 0.5) + 50;

                const cp1x = x1;
                const cp1y = y1 + sag;
                const cp2x = x2;
                const cp2y = y2 + sag;

                const d = `M ${x1} ${y1} C ${cp1x} ${cp1y}, ${cp2x} ${cp2y}, ${x2} ${y2}`;

                // Group for the cable
                const group = document.createElementNS("http://www.w3.org/2000/svg", "g");
                group.style.cursor = "pointer";

                // 1. Hit Area Path (Thicker, Transparent)
                const hitPath = document.createElementNS("http://www.w3.org/2000/svg", "path");
                hitPath.setAttribute("d", d);
                hitPath.setAttribute("stroke", "transparent");
                hitPath.setAttribute("stroke-width", "20"); // Wide hit area
                hitPath.setAttribute("fill", "none");
                hitPath.style.pointerEvents = "all"; // Aggressive capture
                hitPath.style.cursor = "pointer"; // Show pointer cursor

                // 2. Visible Cable Path
                const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
                path.setAttribute("d", d);
                
                // Convert any color to grayscale or use grayscale directly
                const color = cable.cable_color || "#333";
                const grayscaleColor = convertToGrayscale(color);
                path.setAttribute("stroke", grayscaleColor);
                path.setAttribute("stroke-width", "4");
                path.setAttribute("fill", "none");
                path.setAttribute("stroke-linecap", "round");
                
                // Apply pattern based on cable_pattern
                const pattern = cable.cable_pattern || "solid";
                switch(pattern) {
                    case "dashed":
                        path.setAttribute("stroke-dasharray", "8 4");
                        break;
                    case "dotted":
                        path.setAttribute("stroke-dasharray", "2 3");
                        path.setAttribute("stroke-linecap", "round");
                        break;
                    case "dash-dot":
                        path.setAttribute("stroke-dasharray", "8 3 2 3");
                        break;
                    default: // solid
                        path.setAttribute("stroke-dasharray", "none");
                }
                
                path.style.pointerEvents = "none"; // Let clicks pass through visual path to hit path
                path.setAttribute("class", "drop-shadow-md opacity-80 transition-all duration-200");
                // Force grayscale filter on the SVG element
                path.style.filter = "grayscale(100%)";

                group.appendChild(hitPath);
                group.appendChild(path);

                // Hover effects - Attach to hitPath
                hitPath.addEventListener("mouseenter", () => {
                    console.log("Mouse enter cable:", cable.id);
                    path.setAttribute("stroke-width", "6");
                    path.style.opacity = "1";
                    path.style.filter = "brightness(1.2)";
                });

                hitPath.addEventListener("mouseleave", () => {
                    path.setAttribute("stroke-width", "4");
                    path.style.opacity = "0.8";
                    path.style.filter = "none";
                });

                // Double-click to delete - Attach to hitPath
                hitPath.addEventListener("dblclick", (e) => {
                    console.log("Double-click detected on cable:", cable.id);
                    e.preventDefault();
                    e.stopPropagation();
                    // Push event to server to delete
                    this.pushEvent("delete_cable", { id: cable.id });
                });

                // Debug click
                hitPath.addEventListener("click", (e) => {
                    console.log("Single click on cable:", cable.id);
                    e.stopPropagation();
                });

                group.appendChild(hitPath);
                group.appendChild(path);
                this.el.appendChild(group);
            }
        });
    },
    
    // Helper function to convert any color to grayscale
    convertToGrayscale(color) {
        // Map of common colors to grayscale equivalents
        const colorMap = {
            '#ff0000': '#333', // red -> dark gray
            '#00ff00': '#666', // green -> medium gray
            '#0000ff': '#999', // blue -> light gray
            '#ffff00': '#666', // yellow -> medium gray
            '#ff00ff': '#333', // magenta -> dark gray
        };
        
        const lowerColor = color.toLowerCase();
        if (colorMap[lowerColor]) {
            return colorMap[lowerColor];
        }
        
        // Already grayscale or unknown, return as-is
        return color;
    }
};

// Make convertToGrayscale available at module level
function convertToGrayscale(color) {
    const colorMap = {
        '#ff0000': '#333',
        '#00ff00': '#666',
        '#0000ff': '#999',
        '#ffff00': '#666',
        '#ff00ff': '#333',
    };
    
    const lowerColor = color.toLowerCase();
    return colorMap[lowerColor] || color;
}
