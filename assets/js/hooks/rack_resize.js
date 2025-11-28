export const RackResize = {
    mounted() {
        this.handleResize = () => {
            this.pushEventTo(this.el, "resize", { width: this.el.offsetWidth });
        };

        // Initial size
        this.handleResize();

        // Observe resize
        this.resizeObserver = new ResizeObserver(entries => {
            for (let entry of entries) {
                this.handleResize();
            }
        });

        this.resizeObserver.observe(this.el);
        window.addEventListener("resize", this.handleResize);
    },

    destroyed() {
        if (this.resizeObserver) {
            this.resizeObserver.disconnect();
        }
        window.removeEventListener("resize", this.handleResize);
    }
};
