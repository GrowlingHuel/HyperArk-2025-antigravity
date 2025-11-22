# CRITICAL BUG: Pagination Feedback Loop - November 4, 2025

## 🚨 Severity: CRITICAL

### User Report
User navigated through journal pages and observed:
1. Page count **changing dynamically** (1 → 3 → 5 pages)
2. Entries per page fluctuating erratically
3. **Nonsensical/combined entries** appearing

### Initial Investigation

**Database Check:**
```
Total entries: 15 (all legitimate, no corruption)
Sources: character_conversation, manual_entry, system_action
```

**Conclusion:** Database is fine. Problem is in the UI layer.

---

## Root Cause Analysis

### The Feedback Loop

The JavaScript `JournalOverflowHook` was **recalculating `entries_per_page` on EVERY page navigation**, creating a destructive feedback loop:

```
Page 1 (15 total entries):
├─ Hook measures 9 entries fit
├─ Sets entries_per_page = 9
└─ Calculates total_pages = ceil(15/9) = 2 pages ✅

User clicks "Next"

Page 2:
├─ Shows entries 10-15 (6 entries)
├─ Hook measures ALL 6 fit (no overflow on this page)
├─ Sets entries_per_page = 6 ❌
└─ Calculates total_pages = ceil(15/6) = 3 pages ❌

LiveView re-renders

Page 2 (now of 3):
├─ Shows entries 13-15 (3 entries, since entries_per_page = 6)
├─ Hook measures ALL 3 fit
├─ Sets entries_per_page = 3 ❌❌
└─ Calculates total_pages = ceil(15/3) = 5 pages ❌❌

Infinite spiral continues...
```

### Why This Happened

1. **Hook measured visible entries** on current page
2. **Assumed those entries represented capacity**
3. **Applied that capacity globally**
4. **Triggered on EVERY mutation** (page changes)
5. **Created cascading recalculations**

---

## Symptoms Explained

### 1. Changing Page Count (1 → 3 → 5)
**Cause:** Each navigation triggered recalculation with fewer visible entries, increasing total pages.

### 2. Varying Entries Per Page
**Cause:** Hook was measuring different numbers of entries on different pages.

### 3. "Nonsensical/Combined Entries"
**Cause:** Likely artifacts from:
- Rapid re-renders during recalculation
- Entries being sliced at different points
- Knowledge term processing running mid-update
- Or user misinterpreting paginated content during the chaos

---

## The Fix

### Strategy
**Cache `entries_per_page` and only recalculate on:**
1. ✅ Initial mount (page 1 load)
2. ✅ Window resize
3. ❌ ~~Page navigation~~ (NO!)
4. ❌ ~~Content mutations~~ (NO!)

### Implementation

**File:** `assets/js/app.js`

#### Before (Broken)
```javascript
mounted() {
  this.checkOverflow()
  this._observer = new MutationObserver(() => this.checkOverflow())
  this._observer.observe(this.el, { childList: true, subtree: true })
},
updated() {
  setTimeout(() => this.checkOverflow(), 50)
},
checkOverflow() {
  const entries = this.el.querySelectorAll('[data-journal-entry]')
  // Measures CURRENT page entries
  // Sets entries_per_page based on CURRENT view
  // Triggers on EVERY change
}
```

**Problem:** Hook recalculates on every mutation, using current page's entries.

#### After (Fixed)
```javascript
mounted() {
  this._calculatedEntriesPerPage = null
  this.checkOverflow(true) // Force initial calculation
  
  // Resize = recalculate (container size changed)
  this._resizeHandler = () => this.checkOverflow(true)
  window.addEventListener('resize', this._resizeHandler)
  
  // Mutations = check overflow only, DON'T recalculate
  this._observer = new MutationObserver(() => this.checkOverflow(false))
  this._observer.observe(this.el, { childList: true, subtree: true })
},
updated() {
  // Page navigation = check overflow only, DON'T recalculate
  setTimeout(() => this.checkOverflow(false), 50)
},
checkOverflow(forceCalculation = false) {
  const hasOverflow = this.el.scrollHeight > this.el.clientHeight
  
  // Only calculate if forced OR not yet calculated
  if (forceCalculation || !this._calculatedEntriesPerPage) {
    const entries = this.el.querySelectorAll('[data-journal-entry]')
    // ... count entries that fit ...
    this._calculatedEntriesPerPage = Math.max(1, visibleEntries)
  }
  
  // Always use CACHED value
  this.pushEvent("journal_overflow_detected", { 
    has_overflow: hasOverflow,
    entries_per_page: this._calculatedEntriesPerPage || 15
  })
}
```

**Fix:** 
- Calculation happens **once** on mount
- **Cached** for all subsequent checks
- Only **recalculated** on window resize
- Mutations **only check overflow**, don't recalculate

---

## Testing

### Before Fix
```
Load page → Page 1 of 2
Click Next → Page 2 of 3 ❌
Wait... → Page 2 of 5 ❌
Chaos!
```

### After Fix
```
Load page → Page 1 of 2
Click Next → Page 2 of 2 ✅
Click Prev → Page 1 of 2 ✅
Stable!
```

---

## Edge Cases Handled

### 1. Window Resize
**Scenario:** User resizes window, changing container height.
**Behavior:** Recalculates entries_per_page ✅
```javascript
this._resizeHandler = () => this.checkOverflow(true)
```

### 2. Page Navigation
**Scenario:** User clicks Next/Prev.
**Behavior:** Checks overflow, uses cached entries_per_page ✅
```javascript
this.checkOverflow(false) // Don't recalculate
```

### 3. Entry Added/Deleted
**Scenario:** User creates or deletes an entry.
**Behavior:** Checks overflow, uses cached entries_per_page ✅
**Note:** Total pages may change, but entries_per_page stays stable

### 4. Initial Load on Page 2+
**Scenario:** User bookmarks or refreshes on page 2.
**Behavior:** Hook calculates from whatever entries are visible.
**Limitation:** May not be optimal, but won't spiral.
**Future:** Could store in localStorage or always start on page 1.

---

## Debugging Added

Console logs added for debugging:
```javascript
console.log('[JournalOverflow] Calculated entries per page:', 
  this._calculatedEntriesPerPage, 'from', entries.length, 'visible entries')
```

Check browser console to verify:
- Calculation happens once on mount
- Value is cached for subsequent checks
- Only recalculates on window resize

---

## Related Issues Fixed

1. ✅ Page count stability
2. ✅ Consistent entries per page
3. ✅ No re-render cascade
4. ✅ Performant (fewer calculations)

---

## Future Improvements

### 1. Persist Calculation
Store `entries_per_page` in localStorage:
```javascript
localStorage.setItem('journal_entries_per_page', this._calculatedEntriesPerPage)
```

### 2. Always Start on Page 1
Force navigation to page 1 on journal load to ensure accurate calculation.

### 3. Manual Recalculate Button
Let users trigger recalculation if needed (after adding many entries, etc.).

### 4. Average Entry Height
Instead of counting visible entries, calculate average height and use that:
```javascript
const avgHeight = totalHeight / totalEntries
const entriesPerPage = Math.floor(containerHeight / avgHeight)
```

---

## Lessons Learned

1. **Don't measure moving targets** - Measuring paginated content to calculate pagination creates circular dependencies.

2. **Cache expensive calculations** - Especially when they affect global state.

3. **Separate detection from calculation** - Overflow detection (changes constantly) vs. capacity calculation (should be stable).

4. **Watch for feedback loops** - When output of function A affects input of function B which affects input of function A.

5. **Test edge cases** - Initial implementation only tested page 1, bug appeared on page 2.

---

## Rollback

If issues occur:
```bash
git diff assets/js/app.js
git checkout HEAD -- assets/js/app.js
mix phx.server
```

---

## Summary

**Problem:** Dynamic recalculation of `entries_per_page` on every page change created feedback loop  
**Cause:** Hook measured current page entries instead of caching initial calculation  
**Fix:** Cache `entries_per_page` on mount, only recalculate on window resize  
**Result:** Stable, predictable pagination  

**Status:** ✅ FIXED

