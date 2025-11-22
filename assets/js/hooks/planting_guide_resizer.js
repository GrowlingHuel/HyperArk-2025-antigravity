/**
 * PlantingGuideResizerHook - Allows users to drag a divider to resize top/bottom sections in planting guide
 * 
 * Implements HyperCard-style instant resize (no smooth transitions)
 * Stores height preference in localStorage for persistence
 */
export default {
  mounted() {
    // Use a small delay to ensure DOM is fully rendered
    setTimeout(() => {
      this.container = document.querySelector('.planting-guide-container')
      this.topSection = this.container?.querySelector('.filters-section')
      this.bottomSection = this.container?.querySelector('.plants-grid-container')
      this.resizer = this.el
      
      console.log('[PlantingGuideResizer] Mounted:', {
        container: !!this.container,
        topSection: !!this.topSection,
        bottomSection: !!this.bottomSection,
        resizer: !!this.resizer,
        resizerEl: this.el
      })
      
      if (!this.container || !this.topSection || !this.bottomSection) {
        console.warn('[PlantingGuideResizer] Missing required elements', {
          container: !!this.container,
          topSection: !!this.topSection,
          bottomSection: !!this.bottomSection
        })
        return
      }
      
      this.initResizer()
    }, 100)
  },
  
  initResizer() {

    // Load saved height preference or default to 50%
    const savedHeight = localStorage.getItem('plantingGuideTopHeight')
    const initialPercent = savedHeight ? parseFloat(savedHeight) : 50
    this.currentHeight = initialPercent // Store in hook state
    const initialHeight = `${initialPercent}%`
    
    // Set initial height
    this.setSectionHeight(initialHeight)

    // Setup drag functionality
    this.isDragging = false
    this.startY = 0
    this.startTopHeight = 0
    
    this.resizer.addEventListener('mousedown', (e) => {
      this.startDrag(e)
    })

    // Double-click to reset to 50/50 split
    this.resizer.addEventListener('dblclick', (e) => {
      e.preventDefault()
      e.stopPropagation()
      this.setSectionHeight('50%')
    })

    // Prevent text selection while dragging
    this.resizer.style.userSelect = 'none'
    this.resizer.style.cursor = 'row-resize'
    
    // Ensure resizer is visible
    this.resizer.style.display = 'block'
    this.resizer.style.visibility = 'visible'

    // Handle mouse move and mouse up globally (even outside resizer)
    document.addEventListener('mousemove', (e) => {
      if (this.isDragging) {
        this.handleDrag(e)
      }
    })

    document.addEventListener('mouseup', () => {
      if (this.isDragging) {
        this.endDrag()
      }
    })

    // Handle window resize to maintain ratio
    window.addEventListener('resize', () => {
      // Maintain current ratio on window resize
      if (this.currentHeight) {
        this.setSectionHeight(`${this.currentHeight}%`)
      }
    })
  },

  setSectionHeight(height) {
    // Ensure height is a string with % unit
    const heightValue = typeof height === 'string' ? height : `${height}%`
    
    // Extract percentage and enforce reasonable limits
    const percentMatch = heightValue.match(/([\d.]+)%/)
    let finalPercent = percentMatch ? parseFloat(percentMatch[1]) : 50
    
    // Enforce constraints: 20% minimum, 80% maximum for top section
    const minHeight = 20
    const maxHeight = 80
    finalPercent = Math.max(minHeight, Math.min(maxHeight, finalPercent))
    
    const finalHeight = `${finalPercent}%`
    
    // Set top section height with !important to override CSS rules
    this.topSection.style.setProperty('height', finalHeight, 'important')
    this.topSection.style.setProperty('flex-shrink', '0', 'important')
    this.topSection.style.setProperty('flex-grow', '0', 'important')
    this.topSection.style.setProperty('flex-basis', finalHeight, 'important')
    
    // Bottom section takes remaining space
    this.bottomSection.style.setProperty('height', 'auto', 'important')
    this.bottomSection.style.setProperty('flex-grow', '1', 'important')
    this.bottomSection.style.setProperty('flex-shrink', '1', 'important')
    this.bottomSection.style.setProperty('flex-basis', 'auto', 'important')

    // Save to localStorage (clamped value)
    localStorage.setItem('plantingGuideTopHeight', finalPercent.toString())
    
    // Also store in hook state for quick access
    this.currentHeight = finalPercent
  },

  startDrag(e) {
    e.preventDefault()
    e.stopPropagation()
    
    this.isDragging = true
    this.startY = e.clientY
    
    // Get current top section height as percentage
    const containerHeight = this.container.offsetHeight
    const topSectionHeight = this.topSection.offsetHeight
    this.startTopHeight = (topSectionHeight / containerHeight) * 100

    // Add dragging class for visual feedback
    document.body.style.cursor = 'row-resize'
    document.body.style.userSelect = 'none'
    this.resizer.style.background = '#666'
  },

  handleDrag(e) {
    if (!this.isDragging) return

    const containerHeight = this.container.offsetHeight
    const deltaY = e.clientY - this.startY
    const deltaPercent = (deltaY / containerHeight) * 100
    
    // Calculate new height
    let newHeight = this.startTopHeight + deltaPercent
    
    // Enforce constraints: 20% minimum, 80% maximum for top section
    const minHeight = 20
    const maxHeight = 80
    
    newHeight = Math.max(minHeight, Math.min(maxHeight, newHeight))
    
    // Update sections instantly (no smooth transitions for HyperCard aesthetic)
    this.setSectionHeight(`${newHeight}%`)
  },

  endDrag() {
    if (!this.isDragging) return

    this.isDragging = false
    
    // Reset cursor and selection
    document.body.style.cursor = ''
    document.body.style.userSelect = ''
    this.resizer.style.background = ''
  },

  updated() {
    // Re-find elements if DOM changed
    this.container = document.querySelector('.planting-guide-container')
    this.topSection = this.container?.querySelector('.filters-section')
    this.bottomSection = this.container?.querySelector('.plants-grid-container')
    
    // Restore section height if it was reset by LiveView update
    if (this.topSection && this.bottomSection) {
      const savedHeight = localStorage.getItem('plantingGuideTopHeight')
      const expectedPercent = savedHeight ? parseFloat(savedHeight) : (this.currentHeight || 50)
      
      // Check current computed height
      const containerHeight = this.container.offsetHeight
      const currentHeight = this.topSection.offsetHeight
      const currentPercent = containerHeight > 0 ? (currentHeight / containerHeight) * 100 : 50
      
      // If height was reset (differs significantly from expected), restore it
      // Use 2% tolerance to account for rounding errors
      if (Math.abs(currentPercent - expectedPercent) > 2) {
        console.log(`[PlantingGuideResizer] Height reset detected (${currentPercent}% vs ${expectedPercent}%), restoring...`)
        this.setSectionHeight(`${expectedPercent}%`)
      }
    }
  }
}

