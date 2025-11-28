export const RackCables = {
    mounted() {
        // Initial draw
        this.drawCables();

        // Listen for server updates
        this.handleEvent("update_cables", ({ cables }) => {
            // We can store cables in a data attribute or just pass them directly
            // But since we want to redraw on resize without asking server, 
            // we should store them locally.
            this.cables = cables;
            this.drawCables();
        });

        // Redraw on window resize - PURE CLIENT SIDE, NO SERVER NOTIFICATION
        this.resizeHandler = () => {
            if (this.cables) {
                this.drawCables();
            }
        };
        window.addEventListener("resize", this.resizeHandler);

        // Also observe the rack container for scroll/resize if needed
        // But since SVG is inside the scrolling container, scroll is handled natively.
    },

    destroyed() {
        if (this.resizeHandler) {
            window.removeEventListener("resize", this.resizeHandler);
        }
    },

    updated() {
        // If data-cables attribute changes, update
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

        // We need coordinates relative to the SVG container.
        // The SVG is likely `absolute inset-0` inside `.rack-frame` or `.devices-container`.
        // Let's assume the SVG is the `this.el`.
        const svgRect = this.el.getBoundingClientRect();

        this.cables.forEach(cable => {
            const sourceId = `${cable.source_device_id}-${cable.source_jack_id}`;
            const targetId = `${cable.target_device_id}-${cable.target_jack_id}`;

            // Find jacks
            // Note: We search document-wide or scoped to rack? Document is safer for now.
            const sourceEl = document.querySelector(`.rack-jack[data-jack-id="${sourceId}"]`);
            const targetEl = document.querySelector(`.rack-jack[data-jack-id="${targetId}"]`);

            if (sourceEl && targetEl) {
                const sourceRect = sourceEl.getBoundingClientRect();
                const targetRect = targetEl.getBoundingClientRect();

                // Calculate center points relative to the SVG
                // x = (jack.left - svg.left) + (jack.width / 2)
                // y = (jack.top - svg.top) + (jack.height / 2)

                const x1 = (sourceRect.left - svgRect.left) + (sourceRect.width / 2);
                const y1 = (sourceRect.top - svgRect.top) + (sourceRect.height / 2);
                const x2 = (targetRect.left - svgRect.left) + (targetRect.width / 2);
                const y2 = (targetRect.top - svgRect.top) + (targetRect.height / 2);

                // Bezier Logic (Gravity)
                const path = document.createElementNS("http://www.w3.org/2000/svg", "path");

                const yDiff = Math.abs(y2 - y1);
                const sag = Math.min(100, yDiff * 0.5) + 50;

                // Control points: slightly below the jacks to simulate gravity
                const cp1x = x1;
                const cp1y = y1 + sag;
                const cp2x = x2;
                const cp2y = y2 + sag;

                const d = `M ${x1} ${y1} C ${cp1x} ${cp1y}, ${cp2x} ${cp2y}, ${x2} ${y2}`;

                path.setAttribute("d", d);
                path.setAttribute("stroke", cable.cable_color || "#333");
                path.setAttribute("stroke-width", "4");
                path.setAttribute("fill", "none");
                path.setAttribute("stroke-linecap", "round");
                path.setAttribute("class", "pointer-events-none drop-shadow-md opacity-80 hover:opacity-100 transition-opacity");

                this.el.appendChild(path);
            }
        });
    }
};
