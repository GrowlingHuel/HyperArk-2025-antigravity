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
                hitPath.style.pointerEvents = "stroke"; // Catch clicks on the stroke

                // 2. Visible Path
                const visiblePath = document.createElementNS("http://www.w3.org/2000/svg", "path");
                visiblePath.setAttribute("d", d);
                visiblePath.setAttribute("stroke", cable.cable_color || "#333");
                visiblePath.setAttribute("stroke-width", "4");
                visiblePath.setAttribute("fill", "none");
                visiblePath.setAttribute("stroke-linecap", "round");
                visiblePath.setAttribute("class", "pointer-events-none drop-shadow-md opacity-80 transition-all duration-200");

                // Interactions
                group.addEventListener("mouseenter", () => {
                    visiblePath.setAttribute("stroke-width", "6");
                    visiblePath.style.opacity = "1";
                    visiblePath.style.filter = "brightness(1.2)";
                });

                group.addEventListener("mouseleave", () => {
                    visiblePath.setAttribute("stroke-width", "4");
                    visiblePath.style.opacity = "0.8";
                    visiblePath.style.filter = "none";
                });

                group.addEventListener("dblclick", (e) => {
                    e.stopPropagation();
                    // Push event to server to delete
                    this.pushEvent("delete_cable", { id: cable.id });
                });

                group.appendChild(hitPath);
                group.appendChild(visiblePath);
                this.el.appendChild(group);
            }
        });
    }
};
