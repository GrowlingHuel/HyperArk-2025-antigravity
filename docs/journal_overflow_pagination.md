# Journal Space-Based Pagination

## Problem
The journal pagination was only showing when there were 16+ entries (more than 1 page at 15 entries/page), regardless of whether content actually overflowed the available vertical space. This caused entries to be hidden (`overflow: hidden`) when they exceeded the container height, making them inaccessible.

## Solution
Implemented **space-based pagination** that detects when journal entries overflow the available vertical space and shows pagination controls dynamically.

---

## Implementation

### 1. JavaScript Hook: `JournalOverflowHook`

**File:** `assets/js/app.js`

```javascript
const JournalOverflowHook = {
  mounted() {
    this.checkOverflow()
    // Recheck on window resize and after updates
    this._resizeHandler = () => this.checkOverflow()
    window.addEventListener('resize', this._resizeHandler)
    
    // Use MutationObserver to detect content changes
    this._observer = new MutationObserver(() => this.checkOverflow())
    this._observer.observe(this.el, { childList: true, subtree: true })
  },
  updated() {
    // Small delay to ensure DOM has settled
    setTimeout(() => this.checkOverflow(), 50)
  },
  destroyed() {
    if (this._resizeHandler) {
      window.removeEventListener('resize', this._resizeHandler)
    }
    if (this._observer) {
      this._observer.disconnect()
    }
  },
  checkOverflow() {
    // Check if content height exceeds container height
    const hasOverflow = this.el.scrollHeight > this.el.clientHeight
    
    // Push event to LiveView to update pagination visibility
    this.pushEvent("journal_overflow_detected", { has_overflow: hasOverflow })
  }
}
```

**How it works:**
- Compares `scrollHeight` (total content height) to `clientHeight` (visible height)
- Detects overflow immediately on mount
- Re-checks on window resize
- Uses `MutationObserver` to detect DOM changes (entries added/removed)
- Pushes `has_overflow` boolean to LiveView

---

### 2. LiveView Handler

**File:** `lib/green_man_tavern_web/live/dual_panel_live.ex`

**Added to `mount/3`:**
```elixir
|> assign(:journal_has_overflow, false)
```

**New event handler:**
```elixir
@impl true
def handle_event("journal_overflow_detected", %{"has_overflow" => has_overflow}, socket) do
  # Update the overflow state so pagination controls know when to show
  {:noreply, assign(socket, :journal_has_overflow, has_overflow)}
end
```

---

### 3. Template Updates

**File:** `lib/green_man_tavern_web/live/dual_panel_live.html.heex`

**Added hook to journal entries container (line 1022):**
```heex
<div id="journal-entries-list" phx-hook="JournalOverflow" style="flex: 1; overflow: hidden; min-height: 0;">
```

**Changed pagination condition (line 1282):**
```heex
<!-- OLD: <%= if total_pages_pagination > 1 do %> -->
<!-- NEW: -->
<%= if @journal_has_overflow do %>
```

---

## Behavior

### Before
- Pagination only shown when `entry_count > 15` (i.e., 2+ pages)
- If you had 11 long entries that overflowed, pagination was hidden
- Overflow entries were inaccessible (`overflow: hidden`)

### After
- Pagination shown **whenever content overflows** the available space
- Works with any number of entries
- Responsive to window resizing
- Automatically updates when entries are added/removed/edited

---

## Technical Details

### Overflow Detection
```javascript
const hasOverflow = this.el.scrollHeight > this.el.clientHeight
```

- `scrollHeight`: Total height of content (including hidden)
- `clientHeight`: Visible height of container
- If `scrollHeight > clientHeight`, content is overflowing

### Event Flow
1. **DOM changes** → `MutationObserver` fires
2. **Hook checks overflow** → Compares heights
3. **Hook pushes event** → `journal_overflow_detected` to LiveView
4. **LiveView updates state** → `assign(:journal_has_overflow, true/false)`
5. **Template re-renders** → Pagination shows/hides based on `@journal_has_overflow`

### Triggers for Overflow Check
- **Mount:** Initial check when hook attached
- **Update:** When LiveView re-renders (50ms delay for DOM settling)
- **Resize:** Window/container size changes
- **Mutation:** DOM content changes (entries added/removed/edited)

---

## Testing

### Scenarios to Test
1. ✅ **Few long entries** → Should show pagination if overflow
2. ✅ **Many short entries** → Should show pagination if overflow
3. ✅ **Entries that fit** → Should NOT show pagination
4. ✅ **Window resize** → Pagination appears/disappears as needed
5. ✅ **Add entry** → Overflow rechecked
6. ✅ **Delete entry** → Overflow rechecked
7. ✅ **Edit entry** → Overflow rechecked

---

## Future Improvements

### Dynamic Entries Per Page
Instead of fixed 15 entries/page, could calculate based on average entry height:

```elixir
defp calculate_entries_per_page(entries, container_height) do
  if entries == [] do
    15
  else
    avg_height = estimate_average_entry_height(entries)
    max(5, div(container_height, avg_height))
  end
end
```

### Smooth Pagination Transitions
Could add CSS transitions when pagination appears/disappears (but must stay HyperCard aesthetic - instant or stepped only).

---

## Design Constraints

✅ **HyperCard aesthetic maintained:**
- No smooth animations
- Instant show/hide of pagination
- Sharp corners, system fonts
- Black borders and bevels

✅ **No scrollbars:**
- Pagination handles overflow instead
- Entries remain navigable without scrolling

✅ **Responsive:**
- Works on different screen sizes
- Automatically adjusts to available space

