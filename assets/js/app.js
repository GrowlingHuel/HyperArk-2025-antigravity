// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import { hooks as colocatedHooks } from "phoenix-colocated/green_man_tavern"
import ChatFormHook from "./hooks/chat_form_hook.js"
import XyflowEditorHook from "./hooks/xyflow_editor.js"
import PanelResizerHook from "./hooks/panel_resizer.js"
import PlantingGuideResizerHook from "./hooks/planting_guide_resizer.js"
import { RackCables } from "./hooks/rack_cables.js"

// Initialize topbar directly (inline to avoid import issues)
const topbar = {
  config: () => { },
  show: () => { },
  hide: () => { }
};

// Hook to stop event propagation (prevents parent click handlers from firing)
const StopPropagationHook = {
  mounted() {
    this.handleClick = (e) => {
      e.stopPropagation()
    }
    this.el.addEventListener('click', this.handleClick, true) // Use capture phase
  },
  destroyed() {
    if (this.handleClick) {
      this.el.removeEventListener('click', this.handleClick, true)
    }
  }
};

// Custom dropdown hook for status selector
const CustomDropdownHook = {
  mounted() {
    this.initDropdown()
  },

  updated() {
    // Re-initialize after update
    this.initDropdown()
  },

  initDropdown() {
    this.dropdown = this.el
    this.trigger = this.el.querySelector('.dropdown-trigger')
    this.options = this.el.querySelector('.dropdown-options')
    this.hiddenInput = this.el.querySelector('input[type="hidden"]')

    if (!this.trigger || !this.options || !this.hiddenInput) {
      console.warn('CustomDropdown: Missing required elements')
      return
    }

    // Ensure dropdown starts closed
    this.options.style.display = 'none'

    // Get form reference
    const formId = this.hiddenInput.getAttribute('form')
    this.form = formId ? document.getElementById(formId) : null

    // Remove old listeners if they exist
    if (this.triggerClickHandler) {
      this.trigger.removeEventListener('click', this.triggerClickHandler)
    }
    if (this.optionClickHandler) {
      this.options.removeEventListener('click', this.optionClickHandler)
    }

    // Toggle dropdown on trigger click
    this.triggerClickHandler = (e) => {
      e.preventDefault()
      e.stopPropagation()
      e.stopImmediatePropagation()
      // Check if dropdown is currently open (check both display and computed style)
      const currentDisplay = window.getComputedStyle(this.options).display
      const isOpen = currentDisplay === 'block' || this.options.style.display === 'block'
      // Toggle it
      this.options.style.display = isOpen ? 'none' : 'block'
      this.options.style.setProperty('display', isOpen ? 'none' : 'block', 'important')
    }
    this.trigger.addEventListener('click', this.triggerClickHandler, true)

    // Handle option selection
    this.optionClickHandler = (e) => {
      const option = e.target.closest('.dropdown-option')
      if (option) {
        e.preventDefault()
        e.stopPropagation()
        const value = option.getAttribute('data-value') || ''

        // Update hidden input value
        this.hiddenInput.value = value

        // Close dropdown immediately
        this.options.style.display = 'none'

        // Trigger form change event to submit to LiveView
        // This will cause LiveView to re-render with the new value
        const changeEvent = new Event('change', { bubbles: true, cancelable: true })
        this.hiddenInput.dispatchEvent(changeEvent)
      }
    }
    this.options.addEventListener('click', this.optionClickHandler)

    // Close dropdown when clicking outside
    if (this.handleClickOutside) {
      document.removeEventListener('click', this.handleClickOutside)
    }

    this.handleClickOutside = (e) => {
      if (this.dropdown && !this.dropdown.contains(e.target)) {
        this.options.style.display = 'none'
      }
    }
    document.addEventListener('click', this.handleClickOutside)
  },

  destroyed() {
    if (this.handleClickOutside) {
      document.removeEventListener('click', this.handleClickOutside)
    }
    if (this.triggerClickHandler && this.trigger) {
      this.trigger.removeEventListener('click', this.triggerClickHandler)
    }
    if (this.optionClickHandler && this.options) {
      this.options.removeEventListener('click', this.optionClickHandler)
    }
  }
};

// Hook to detect shift-click for calendar day selection
// This hook intercepts shift-clicks and sends them via pushEvent, otherwise lets phx-click work
const CalendarDayHook = {
  mounted() {
    this.handleClick = (e) => {
      if (e.shiftKey) {
        // Shift-click: send via pushEvent so we can include shift_key param
        const year = this.el.getAttribute('phx-value-year')
        const month = this.el.getAttribute('phx-value-month')
        const day = this.el.getAttribute('phx-value-day')

        this.pushEvent('select_day_with_shift', {
          year: year,
          month: month,
          day: day,
          shift_key: 'true'
        })

        e.preventDefault()
        e.stopPropagation()
      }
      // Regular click: let phx-click handle it normally (don't prevent default)
    }
    this.el.addEventListener('click', this.handleClick, true) // Use capture phase
  },
  destroyed() {
    if (this.handleClick) {
      this.el.removeEventListener('click', this.handleClick, true)
    }
  }
};

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
// Simple stepped animation hook for thinking dots (no smooth transitions)
const ThinkingDotsHook = {
  mounted() {
    const dots = Array.from(this.el.querySelectorAll('.dot'))
    let index = 0
    this._interval = setInterval(() => {
      dots.forEach((dot, i) => {
        const active = i === index
        dot.style.background = active ? '#000' : '#CCC'
        dot.style.border = '1px solid #000'
        dot.style.width = dot.style.width || '8px'
        dot.style.height = dot.style.height || '8px'
        dot.style.display = 'inline-block'
      })
      index = (index + 1) % dots.length
    }, 300)
  },
  destroyed() {
    if (this._interval) clearInterval(this._interval)
  }
}

// Hook to only show scrollbars when content actually overflows
const ScrollableContentHook = {
  mounted() {
    this.checkAndSetScrollbar()
    // Recheck on window resize and content updates
    window.addEventListener('resize', () => this.checkAndSetScrollbar())
    this.el.addEventListener('phx:update', () => this.checkAndSetScrollbar())
  },
  updated() {
    this.checkAndSetScrollbar()
  },
  checkAndSetScrollbar() {
    // Skip if this is a living-web-container or journal-container (they handle their own scrolling)
    if (this.el.classList.contains('living-web-container') || this.el.classList.contains('journal-container')) {
      return
    }

    // Check if content actually overflows
    const needsScroll = this.el.scrollHeight > this.el.clientHeight

    // Only enable scrolling if content overflows
    if (needsScroll) {
      this.el.style.overflowY = 'auto'
      this.el.classList.add('scrollable')
    } else {
      this.el.style.overflowY = 'hidden'
      this.el.classList.remove('scrollable')
    }
  }
}

// Hook to detect journal entries overflow and show pagination when needed
const JournalOverflowHook = {
  mounted() {
    // Calculate entries per page on initial mount
    this._calculatedEntriesPerPage = null
    this._lastContainerHeight = null
    this._isCalculating = false

    // Wait for DOM to be fully rendered before calculating
    // Use requestAnimationFrame to ensure layout is complete
    requestAnimationFrame(() => {
      setTimeout(() => {
        this.checkOverflow(true) // true = force calculation
      }, 100) // Small delay to ensure all styles are applied
    })

    // Recheck on window resize (recalculate entries per page)
    this._resizeHandler = () => {
      // Only recalculate if container height actually changed significantly
      const currentHeight = this.el.clientHeight
      if (!this._lastContainerHeight || Math.abs(currentHeight - this._lastContainerHeight) > 10) {
        // Delay recalculation slightly to ensure layout is stable
        setTimeout(() => {
          this.checkOverflow(true) // Force recalculation on resize
        }, 50)
      }
    }
    window.addEventListener('resize', this._resizeHandler)

    // Use MutationObserver ONLY to detect overflow, not to recalculate entries_per_page
    // Ignore mutations that are just attribute changes (like minimized state)
    this._observer = new MutationObserver((mutations) => {
      // Only check overflow if there are actual structural changes (additions/removals)
      // Ignore attribute changes which happen when entries are minimized/expanded
      const hasStructuralChanges = mutations.some(m => m.type === 'childList')
      if (hasStructuralChanges) {
        this.checkOverflow(false) // false = no recalculation
      }
    })
    this._observer.observe(this.el, { childList: true, subtree: true, attributes: false })
  },
  updated() {
    // Small delay to ensure DOM has settled
    // Only check overflow, don't recalculate entries_per_page
    // Use a longer delay to avoid race conditions with page navigation
    if (!this._updateTimeout) {
      this._updateTimeout = setTimeout(() => {
        this.checkOverflow(false)
        this._updateTimeout = null
      }, 100)
    }
  },
  destroyed() {
    if (this._resizeHandler) {
      window.removeEventListener('resize', this._resizeHandler)
    }
    if (this._observer) {
      this._observer.disconnect()
    }
    if (this._updateTimeout) {
      clearTimeout(this._updateTimeout)
    }
  },
  checkOverflow(forceCalculation = false) {
    // Prevent concurrent calculations
    if (this._isCalculating && forceCalculation) {
      return
    }

    // Check if content height exceeds container height
    const hasOverflow = this.el.scrollHeight > this.el.clientHeight

    // Only calculate entries_per_page on:
    // 1. Initial mount (forceCalculation = true)
    // 2. Window resize with significant height change (forceCalculation = true)
    // 3. First time (if not yet calculated)
    if (forceCalculation || !this._calculatedEntriesPerPage) {
      this._isCalculating = true

      const entries = this.el.querySelectorAll('[data-journal-entry]')
      const containerHeight = this.el.clientHeight

      if (containerHeight > 0 && entries.length > 0) {
        // Calculate based on average entry height for more stable results
        // This prevents issues when some entries are very tall or very short
        let totalHeight = 0
        let entryCount = 0
        const maxEntriesToSample = Math.min(entries.length, 10) // Sample up to 10 entries

        // Calculate average height from first few entries
        const entryHeights = []
        for (let i = 0; i < maxEntriesToSample; i++) {
          const entryHeight = entries[i].offsetHeight
          if (entryHeight > 0) {
            totalHeight += entryHeight
            entryCount++
            entryHeights.push(entryHeight)
          }
        }

        let calculatedEntriesPerPage = 15 // Default fallback

        if (entryCount > 0 && totalHeight > 0) {
          const averageEntryHeight = totalHeight / entryCount
          // Calculate median height as well (more robust than average for outliers)
          entryHeights.sort((a, b) => a - b)
          const medianHeight = entryHeights.length % 2 === 0
            ? (entryHeights[entryHeights.length / 2 - 1] + entryHeights[entryHeights.length / 2]) / 2
            : entryHeights[Math.floor(entryHeights.length / 2)]

          // Use the smaller of average or median (more conservative, but accounts for tall entries)
          const representativeHeight = Math.min(averageEntryHeight, medianHeight * 1.2)

          // Be more aggressive with available space - entries have margin-bottom: 10px
          // So we account for spacing between entries
          // Use 95% of container height to leave small margin
          const availableHeight = containerHeight * 0.95

          // Calculate based on representative height, accounting for spacing (10px margin per entry)
          const entriesFromHeight = Math.floor(availableHeight / (representativeHeight + 10))

          // Also do a direct count as a sanity check - be more aggressive
          // Allow entries to slightly overflow (use 98% of container)
          let directCount = 0
          let cumulativeHeight = 0
          const maxHeight = containerHeight * 0.98

          for (let entry of entries) {
            const entryHeight = entry.offsetHeight
            // Include the margin-bottom in the height check
            const entryHeightWithMargin = entryHeight + 10
            if (cumulativeHeight + entryHeightWithMargin <= maxHeight) {
              directCount++
              cumulativeHeight += entryHeightWithMargin
            } else {
              // Check if we can fit at least part of this entry
              if (cumulativeHeight + entryHeight <= maxHeight * 1.05) {
                // Allow slight overflow for last entry
                directCount++
              }
              break
            }
          }

          // Use the higher of the two calculations
          calculatedEntriesPerPage = Math.max(entriesFromHeight, directCount)

          // Ensure minimum of 5 entries per page if container is reasonable size
          // This prevents too few entries from showing
          if (containerHeight > 300) {
            calculatedEntriesPerPage = Math.max(5, Math.min(50, calculatedEntriesPerPage))
          } else if (containerHeight > 200) {
            calculatedEntriesPerPage = Math.max(3, Math.min(50, calculatedEntriesPerPage))
          } else {
            // For very small containers, use at least 1 entry
            calculatedEntriesPerPage = Math.max(1, Math.min(50, calculatedEntriesPerPage))
          }

          // IMPORTANT: Don't cap by entries.length on first page!
          // The calculation should be based on container size and entry heights,
          // not limited by how many entries happen to be on the current page.
          // This allows proper pagination even when there are fewer entries on page 1
          // than would actually fit in the container.
        }

        this._calculatedEntriesPerPage = calculatedEntriesPerPage
        this._lastContainerHeight = containerHeight

        // Enhanced logging for debugging
        const avgHeight = entryCount > 0 ? (totalHeight / entryCount).toFixed(1) : 'N/A'
        const medianHeight = entryHeights.length > 0
          ? (entryHeights.length % 2 === 0
            ? ((entryHeights[entryHeights.length / 2 - 1] + entryHeights[entryHeights.length / 2]) / 2).toFixed(1)
            : entryHeights[Math.floor(entryHeights.length / 2)].toFixed(1))
          : 'N/A'

        console.log('[JournalOverflow] Calculated entries per page:', this._calculatedEntriesPerPage,
          '\n  Container height:', containerHeight,
          '\n  Available height (95%):', (containerHeight * 0.95).toFixed(1),
          '\n  Entries sampled:', entryCount,
          '\n  Average entry height:', avgHeight,
          '\n  Median entry height:', medianHeight,
          '\n  Total entries on page:', entries.length)
      } else {
        // Fallback if calculation can't be done yet
        this._calculatedEntriesPerPage = this._calculatedEntriesPerPage || 15
        console.log('[JournalOverflow] Using fallback entries per page:', this._calculatedEntriesPerPage,
          'containerHeight:', containerHeight, 'entries.length:', entries.length)
      }

      this._isCalculating = false
    }

    // Push event to LiveView with overflow state and STABLE entries per page
    // Always use the calculated value, never recalculate based on current page
    this.pushEvent("journal_overflow_detected", {
      has_overflow: hasOverflow,
      entries_per_page: this._calculatedEntriesPerPage || 15
    })
  }
}

// Hook to handle Enter key submission in textareas (for new journal entries)
const EnterToSubmitHook = {
  mounted() {
    this.el.addEventListener("keydown", (e) => {
      // Submit on Enter (but not Shift+Enter, which should create new line)
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault()
        const form = this.el.closest("form")
        if (form) {
          const textarea = form.querySelector('textarea[name="text"]')
          if (textarea && textarea.value.trim() !== "") {
            // Trigger form submission
            form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }))
          }
        }
      }
    })
  }
}

// Hook to preserve focus on input fields during LiveView updates
const PreserveFocusHook = {
  mounted() {
    // Check if this element has focus and store selection
    this._hasFocus = document.activeElement === this.el
    if (this._hasFocus && this.el.selectionStart !== undefined) {
      this._selectionStart = this.el.selectionStart
      this._selectionEnd = this.el.selectionEnd
    }
  },
  updated() {
    // After update, restore focus and selection if it was focused before
    if (this._hasFocus) {
      // Use requestAnimationFrame to ensure DOM is fully updated
      requestAnimationFrame(() => {
        this.el.focus()
        if (this._selectionStart !== undefined && this._selectionEnd !== undefined) {
          this.el.setSelectionRange(this._selectionStart, this._selectionEnd)
        }
      })
    }
  },
  beforeUpdate() {
    // Store focus state and selection before update
    this._hasFocus = document.activeElement === this.el
    if (this._hasFocus && this.el.selectionStart !== undefined) {
      this._selectionStart = this.el.selectionStart
      this._selectionEnd = this.el.selectionEnd
    }
  }
}

// Hook for character links in journal entries
const CharacterLinkHook = {
  mounted() {
    console.log("[CharacterLinkHook] Mounted on element", this.el.id)

    this.el.addEventListener("click", (e) => {
      e.preventDefault() // Prevent default link navigation
      e.stopPropagation() // Stop parent edit mode from firing

      const slug = this.el.getAttribute("data-character-slug")
      console.log("[CharacterLinkHook] Character link clicked, slug:", slug)

      if (slug) {
        // Manually push the event to LiveView (this bypasses DOM event system)
        this.pushEvent("select_character", { character_slug: slug })
        console.log("[CharacterLinkHook] Pushed select_character event to LiveView")
      } else {
        console.warn("[CharacterLinkHook] No character_slug attribute found")
      }
    })
  }
}

// Hook for knowledge term popups
const KnowledgeTermHook = {
  mounted() {
    this.popup = null
    this.pendingTerm = null

    // Listen for term summary events from LiveView using hook's handleEvent
    // This is the CORRECT way to receive push_event from LiveView
    this.handleEvent("term_summary_received", (payload) => {
      console.log("[KnowledgeTermHook] Received term_summary_received event", { payload, pendingTerm: this.pendingTerm })
      if (payload && payload.summary && this.pendingTerm) {
        console.log("[KnowledgeTermHook] Creating popup with summary")
        this.createPopup(payload.summary, this.pendingTerm)
        this.pendingTerm = null
      } else if (payload && payload.error) {
        console.warn("[KnowledgeTermHook] Error fetching summary:", payload.error)
        this.pendingTerm = null
      } else {
        console.log("[KnowledgeTermHook] Event received but no valid summary", { payload, pendingTerm: this.pendingTerm })
      }
    })

    // Click to toggle popup (show/hide)
    this.el.addEventListener("click", (e) => {
      e.stopPropagation() // Prevent click from bubbling to document

      // If popup is already showing for this term, hide it
      if (this.popup) {
        console.log("[KnowledgeTermHook] Hiding popup (clicked again)")
        this.hidePopup()
      } else {
        // Otherwise, show the popup
        console.log("[KnowledgeTermHook] Showing popup (clicked)")
        this.showPopup()
      }
    })
  },

  showPopup() {
    const term = this.el.getAttribute("data-term")
    if (!term) {
      console.warn("[KnowledgeTermHook] No data-term attribute")
      return
    }

    // Store term for the reply handler
    this.pendingTerm = term
    console.log("[KnowledgeTermHook] Requesting summary for term:", term)

    // Push event to LiveView using hook's pushEvent method
    // This is the CORRECT way to send events from a hook
    this.pushEvent("fetch_term_summary", { term: term })
    console.log("[KnowledgeTermHook] Pushed fetch_term_summary event via hook.pushEvent")
  },

  createPopup(summary, term) {
    // IMPORTANT: Remove ANY existing popup in the document first
    // This ensures only ONE popup is shown at a time across all term instances
    const existingPopup = document.getElementById('term-popup')
    if (existingPopup) {
      existingPopup.remove()
    }

    // Also clear this instance's popup reference
    if (this.popup) {
      this.popup.remove()
    }

    // Create popup element
    this.popup = document.createElement("div")
    this.popup.id = "term-popup"
    this.popup.style.position = "absolute"
    this.popup.style.background = "#FFF"
    this.popup.style.border = "2px solid #000"
    this.popup.style.padding = "12px"
    this.popup.style.maxWidth = "500px"
    this.popup.style.maxHeight = "400px"
    this.popup.style.overflowY = "auto"
    this.popup.style.fontSize = "12px"
    this.popup.style.fontFamily = "Georgia, 'Times New Roman', serif"
    this.popup.style.lineHeight = "1.6"
    this.popup.style.color = "#333"
    this.popup.style.boxShadow = "4px 4px 0 rgba(0,0,0,0.3)"
    this.popup.style.zIndex = "10000"
    this.popup.style.pointerEvents = "auto"
    this.popup.style.cursor = "default"

    this.popup.innerHTML = `
      <div style="font-weight: bold; margin-bottom: 6px; color: #000;">${term.charAt(0).toUpperCase() + term.slice(1)}</div>
      <div>${summary}</div>
    `

    // Position popup near the element, but keep it in viewport
    const rect = this.el.getBoundingClientRect()
    const scrollTop = window.pageYOffset || document.documentElement.scrollTop
    const scrollLeft = window.pageXOffset || document.documentElement.scrollLeft

    let top = rect.bottom + scrollTop + 8
    let left = rect.left + scrollLeft

    // Adjust if popup would go off screen
    const viewportWidth = window.innerWidth
    const popupWidth = 400
    if (left + popupWidth > viewportWidth) {
      left = viewportWidth - popupWidth - 10
    }

    this.popup.style.top = top + "px"
    this.popup.style.left = left + "px"

    document.body.appendChild(this.popup)

    // Stop propagation on popup clicks so it doesn't close itself
    this.popup.addEventListener("click", (e) => {
      e.stopPropagation()
    })
  },

  hidePopup() {
    if (this.popup) {
      this.popup.remove()
      this.popup = null
    }
  },

  destroyed() {
    this.hidePopup()
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }
}

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: {
    ...colocatedHooks,
    ChatForm: ChatFormHook,
    XyflowEditor: XyflowEditorHook,
    PanelResizer: PanelResizerHook,
    PlantingGuideResizer: PlantingGuideResizerHook,
    ThinkingDots: ThinkingDotsHook,
    ScrollableContent: ScrollableContentHook,
    JournalOverflow: JournalOverflowHook,
    PreserveFocus: PreserveFocusHook,
    EnterToSubmit: EnterToSubmitHook,
    CharacterLink: CharacterLinkHook,
    KnowledgeTerm: KnowledgeTermHook,
    StopPropagation: StopPropagationHook,
    CustomDropdown: CustomDropdownHook,
    CalendarDay: CalendarDayHook,
    RackCables: RackCables,
    redirect: {
      mounted() {
        this.handleEvent("redirect", (data) => {
          window.location.href = data.to
        })
      }
    }
  },
})


// Show progress bar on live navigation and form submits (disabled for now)
// topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
// window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
// window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Listen for journal scroll events (custom event from push_event)
window.addEventListener("phx:scroll_journal_to_bottom", () => {
  const journalContainer = document.getElementById("journal-container")
  if (journalContainer) {
    // Scroll to bottom after a small delay to ensure DOM is updated
    setTimeout(() => {
      journalContainer.scrollTop = journalContainer.scrollHeight
    }, 100)
  }
})

// Characters dropdown toggle function
function toggleCharactersDropdown() {
  const dropdown = document.getElementById('characters-dropdown-menu')
  if (dropdown) {
    const isVisible = dropdown.style.display === 'block'
    dropdown.style.display = isVisible ? 'none' : 'block'
  }
}

// Close dropdown when clicking outside
document.addEventListener('click', (event) => {
  const dropdown = document.getElementById('characters-dropdown-menu')
  const button = document.getElementById('characters-dropdown-btn')
  if (dropdown && button && !dropdown.contains(event.target) && !button.contains(event.target)) {
    dropdown.style.display = 'none'
  }

  // Close knowledge term popup when clicking outside
  const popup = document.getElementById('term-popup')
  if (popup && !popup.contains(event.target)) {
    popup.remove()
  }
})

// Make function available globally
window.toggleCharactersDropdown = toggleCharactersDropdown

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({ detail: reloader }) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if (keyDown === "c") {
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if (keyDown === "d") {
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

