# Technical Notes & Solutions

This document tracks complex technical solutions and patterns discovered during development.

---

## LiveView Event Handling: Bypassing DOM Event Propagation with Hooks

**Date:** November 2, 2025  
**Status:** ✅ SOLVED  
**Impact:** Critical - Enables clickable character names in journal entries

### The Problem

Character names in journal entries needed to be clickable to load that character in the left panel, BUT:
- The journal entry itself was clickable (to enable editing mode)
- Clicking a character name was triggering BOTH actions
- Using `event.stopPropagation()` prevented the parent edit action BUT also prevented LiveView from seeing the `phx-click` event

### Why Standard Approaches Failed

1. **Attempt 1: `phx-click` with `event.stopPropagation()`**
   - Result: Parent edit mode was prevented ✅
   - Result: LiveView never received the event ❌
   - Reason: LiveView uses event delegation (listens on ancestor elements), so stopped events never reach LiveView

2. **Attempt 2: Parent onclick handler checking for child clicks**
   - Result: Still prevented LiveView from receiving the event ❌
   - Reason: Once propagation is stopped at any level, LiveView's handlers don't fire

3. **Attempt 3: Removing `stopPropagation()` entirely**
   - Result: LiveView received the event ✅
   - Result: Parent edit mode ALSO fired ❌
   - Reason: Both handlers executed

### The Solution: JavaScript Hook with Manual Event Push

**Key Insight:** Use a JavaScript hook that manually pushes events to LiveView, completely bypassing the DOM event system.

#### Implementation

**1. Create the Hook** (`assets/js/app.js`):

```javascript
const CharacterLinkHook = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      e.preventDefault()        // Prevent default link navigation
      e.stopPropagation()       // Prevent parent edit mode from firing
      
      const slug = this.el.getAttribute("data-character-slug")
      
      // Manually push event to LiveView (bypasses DOM event system)
      this.pushEvent("select_character", {character_slug: slug})
    })
  }
}
```

**2. Register the Hook**:

```javascript
const liveSocket = new LiveSocket("/live", Socket, {
  hooks: {
    CharacterLink: CharacterLinkHook,
    // ... other hooks
  }
})
```

**3. Use in Template** (`dual_panel_live.html.heex`):

```heex
<a
  id={link_id}
  phx-hook="CharacterLink"
  data-character-slug={char_slug}
  href="#"
  style="..."
>
  <%= char_name %>
</a>
```

**Note:** Use `data-character-slug` (not `phx-value-character_slug`) because we're reading it in JavaScript, not using LiveView's automatic parameter binding.

#### How It Works

1. User clicks character name → Hook's click handler fires
2. `preventDefault()` stops link navigation
3. `stopPropagation()` prevents parent div's `phx-click="start_edit_entry"` from firing
4. Hook calls `this.pushEvent("select_character", ...)` which sends event **directly to LiveView** via WebSocket
5. LiveView's `handle_event("select_character", ...)` receives the event and loads the character

#### Why This Works

- **Hook's `pushEvent()`** communicates with LiveView over the WebSocket connection, not through DOM events
- DOM event propagation is irrelevant - the message goes straight to the server
- This is the **same pattern** used by `KnowledgeTermHook` for term popups

### Pattern: When to Use Manual Event Pushing

Use JavaScript hooks with `pushEvent()` when:
- ✅ You need to stop event propagation but still communicate with LiveView
- ✅ You have nested clickable elements with conflicting behaviors
- ✅ You need to capture DOM events that LiveView doesn't handle directly (e.g., hover, mouseenter/leave)
- ✅ You need to process data in JavaScript before sending to LiveView

### Related Code

- **Hook Definition:** `assets/js/app.js` (lines ~123-143)
- **Hook Registration:** `assets/js/app.js` (line ~282)
- **Template Usage:** `lib/green_man_tavern_web/live/dual_panel_live.html.heex` (lines ~1021-1041)
- **Server Handler:** `lib/green_man_tavern_web/live/dual_panel_live.ex` (`handle_event("select_character", ...)`)

### Testing

To verify the fix is working:
1. Open browser console
2. Click a character name in a journal entry
3. Should see: `[CharacterLinkHook] Character link clicked, slug: the-farmer`
4. Should see: `[CharacterLinkHook] Pushed select_character event to LiveView`
5. Server logs should show: `[DualPanel] select_character event START`
6. Character should load in left panel
7. Journal entry should NOT enter edit mode

---

## Knowledge Term Popups: Click-to-Show with Full Wikipedia Extracts

**Date:** November 3, 2025  
**Status:** ✅ SOLVED  
**Impact:** UX Improvement - Click-based interaction with comprehensive summaries

### The Problem

Knowledge term popups (hover definitions for terms like "permaculture", "fermentation", etc.) were only showing the first sentence (~20-50 words) followed by an ellipsis. Users wanted more comprehensive information (~250 words) that was easily readable.

### The Root Cause

**1. Backend Truncation** (`lib/green_man_tavern/knowledge/term_lookup.ex`):

```elixir
# OLD CODE - Only took first sentence!
summary = extract
|> String.split(".")
|> Enum.at(0)  # ❌ Just the first sentence

summary = String.slice(summary, 0, 250)  # Then limited to 250 chars
```

**2. Frontend Limitations** (`assets/js/app.js`):
- Popup had `maxWidth: "400px"` but no `maxHeight` or scrolling
- Longer content would overflow off-screen

### The Solution

**1. Use Full Wikipedia Extract:**

```elixir
# NEW CODE - Use the full extract (2-3 paragraphs, 100-150 words)
case Req.get(url, headers: headers, receive_timeout: 5_000) do
  {:ok, %Req.Response{status: 200, body: %{"extract" => extract}}} ->
    summary = if String.length(extract) > 0 do
      extract  # ✅ Full Wikipedia extract
    else
      "Summary not available"
    end
    {:ok, summary}
end
```

**2. Make Popup Scrollable:**

```javascript
this.popup.style.maxWidth = "500px"   // Increased from 400px
this.popup.style.maxHeight = "400px"  // ✅ NEW: Limits height
this.popup.style.overflowY = "auto"   // ✅ NEW: Enables scrolling
```

### Implementation Details

- **Wikipedia API** returns an `extract` field with 2-3 paragraphs (typically 500-800 characters, ~100-150 words)
- This provides good context without being overwhelming
- Popup is now scrollable if content exceeds 400px height
- Wider popup (500px vs 400px) improves readability

### Cache Invalidation

After making these changes, existing cached terms needed to be cleared:

```bash
mix run -e "GreenManTavern.Repo.delete_all(GreenManTavern.Knowledge.Term)"
```

Terms will be automatically refetched with full extracts on next hover.

### Click-Based Interaction (Added Same Day)

Changed from hover-based to click-based interaction for better UX:

**Old Behavior:**
- Hover over term for 500ms → popup shows
- Move mouse away → popup disappears immediately
- Popup was not interactive (couldn't scroll or select text)

**New Behavior:**
- Click term → popup shows/toggles
- Click outside popup → popup closes
- Popup is fully interactive (scrollable, text selectable)
- Changed cursor from `help` (question mark) to `pointer` (hand)
- Changed tooltip from "Hover for definition" to "Click for definition"

**Implementation Changes:**

```javascript
// OLD: Hover events
this.el.addEventListener("mouseenter", () => { /* ... */ })
this.el.addEventListener("mouseleave", () => { /* ... */ })
this.popup.style.pointerEvents = "none"  // Non-interactive

// NEW: Click toggle
this.el.addEventListener("click", (e) => {
  e.stopPropagation()
  if (this.popup) {
    this.hidePopup()  // Toggle off
  } else {
    this.showPopup()  // Toggle on
  }
})
this.popup.style.pointerEvents = "auto"  // Interactive!

// Global click listener to close popup when clicking outside
document.addEventListener('click', (event) => {
  const popup = document.getElementById('term-popup')
  if (popup && !popup.contains(event.target)) {
    popup.remove()
  }
})
```

**Important Fix - Only One Popup at a Time:**

Each hook instance only tracks its own `this.popup`, so clicking multiple terms would create multiple popups. Fixed by checking the entire document for any existing popup before creating a new one:

```javascript
createPopup(summary, term) {
  // Remove ANY existing popup in the document (not just this instance's)
  const existingPopup = document.getElementById('term-popup')
  if (existingPopup) {
    existingPopup.remove()
  }
  // ... create new popup
}
```

This ensures only the most recently clicked term shows a popup.

**Additional Fix - Byte vs Character Position Bug:**

Initial implementation had a critical bug where `Regex.scan` with `return: :index` returns **byte positions**, but `String.slice` expects **character positions**. This caused misalignment in text extraction, resulting in extra characters appearing before/after highlighted terms (e.g., "feFermentation" instead of "Fermentation").

**Solution:**
1. Use `:binary.part` to extract matched text directly at the byte level
2. Convert byte indices to character indices for `String.slice` compatibility
3. Return the matched string directly from the regex operation

```elixir
# Extract matched text using byte-based operations
matched_string = :binary.part(text, byte_index, byte_length)

# Convert byte index to character index
char_index = text |> String.slice(0, byte_index) |> String.length()
char_length = String.length(matched_string)

# Return matched string directly (preserves exact case and boundaries)
{term, char_index, char_length, matched_string}
```

This ensures perfect alignment between the regex match and the text extraction.

### Related Code

- **Backend Fetching:** `lib/green_man_tavern/knowledge/term_lookup.ex` (lines 68-79)
- **Frontend Display:** `assets/js/app.js` (KnowledgeTermHook, lines ~146-265)
- **Template Styling:** `lib/green_man_tavern_web/live/dual_panel_live.html.heex` (lines ~1044-1058)
- **Caching Layer:** `lib/green_man_tavern/knowledge.ex`

---

## Character Message Markdown Formatting

**Date:** November 4, 2025  
**Status:** ✅ SOLVED  
**Impact:** Critical - Character responses must display properly formatted (not show raw ### or **)

### The Problem

Character responses were displaying raw markdown syntax (### for headings, ** for bold) instead of rendering them as formatted HTML. Users saw literal text like:

```
### Here's what I suggest:

**Important:** You should focus on...
```

Instead of seeing properly formatted headings and bold text.

### The Root Cause

The `render_segments` function was HTML-escaping all text segments uniformly, treating both user messages and character messages the same way. This caused markdown formatting characters to be displayed literally.

### The Solution

**CRITICAL: Character messages MUST be rendered with markdown: true option**

Modified `render_segments` to accept an optional `markdown` parameter:

```elixir
# lib/green_man_tavern_web/live/dual_panel_live.ex
def render_segments(segments, opts \\ []) do
  render_markdown? = Keyword.get(opts, :markdown, false)
  
  segments
  |> Enum.map(fn
    {:text, t} ->
      if render_markdown? do
        # Convert markdown to HTML for character messages
        render_markdown(t)
      else
        # User messages remain plain text (escaped)
        Phoenix.HTML.html_escape(t)
      end
    # ... handle character names and terms ...
  end)
end
```

Then in the template, pass `markdown: true` for character messages:

```heex
<%!-- dual_panel_live.html.heex --%>
<%= if message.type == :user do %>
  <%!-- User messages: plain text --%>
  <%= render_segments(segments) %>
<% else %>
  <%!-- Character messages: render markdown --%>
  <%= render_segments(segments, markdown: true) %>
<% end %>
```

### How It Works

1. `process_chat_messages` processes all messages (user and character) to identify character names and knowledge terms, creating segments
2. For user messages: `render_segments(segments)` HTML-escapes text (no markdown)
3. For character messages: `render_segments(segments, markdown: true)` converts markdown to HTML using Earmark
4. Character names and knowledge terms are preserved as interactive elements in both cases

### Related Code

- **Backend Rendering:** `lib/green_man_tavern_web/live/dual_panel_live.ex` (render_segments function, line ~2181)
- **Markdown Conversion:** `lib/green_man_tavern_web/live/dual_panel_live.ex` (render_markdown function, line ~2129)
- **Template Usage:** `lib/green_man_tavern_web/live/dual_panel_live.html.heex` (line ~284-285)

### Testing

To verify markdown is rendering correctly:
1. Send a message to a character
2. Character response should show:
   - Headings properly formatted (not ### text)
   - Bold text styled (not **text**)
   - Lists properly structured
   - Paragraphs with proper spacing
3. User messages should remain plain text (no formatting)

### HTML Entity Decoding Fix (Added Same Day)

**Problem:** Character messages were displaying HTML entities like `&#39;` instead of `'`, showing text like "you&#39;ll" instead of "you'll".

**Root Cause:** Earmark (the markdown library) converts some characters to HTML entities during markdown-to-HTML conversion for safety, but these entities weren't being decoded back to characters.

**Solution:** Added `decode_html_entities/1` helper function that decodes common HTML entities after Earmark conversion:

```elixir
defp decode_html_entities(html) when is_binary(html) do
  html
  |> String.replace("&#39;", "'")      # apostrophe
  |> String.replace("&apos;", "'")     # apostrophe (alternate)
  |> String.replace("&quot;", "\"")    # double quote
  |> String.replace("&amp;", "&")      # ampersand
  |> String.replace("&lt;", "<")       # less than
  |> String.replace("&gt;", ">")       # greater than
  |> String.replace("&nbsp;", " ")     # non-breaking space
  |> String.replace("&#x27;", "'")     # apostrophe (hex)
  |> String.replace("&#x2F;", "/")     # forward slash (hex)
  |> String.replace("&#x60;", "`")     # backtick (hex)
end
```

**Important:** This fix applies at render time, so it automatically handles:
- ✅ New messages going forward
- ✅ Historical messages in the database (decoded when displayed)
- ✅ All character responses without requiring database migration

The entities are decoded AFTER Earmark converts markdown to HTML but BEFORE the HTML is marked as safe and rendered. This ensures proper character display while maintaining security.

### Critical Processing Order Fix (Same Day - MAJOR FIX)

**Problem:** Knowledge term pop-ups were breaking markdown formatting in character messages. Text like:
```
**Fermentation** is important
```

Would display as:
```
**Fermentation** is important  (with ** visible, no bold formatting)
```

Additionally, term highlighting would sometimes misalign, showing "FeFermentation" instead of "Fermentation".

**Root Cause:** The processing order was wrong:
1. ❌ OLD: Identify terms in RAW markdown → breaks up markdown syntax → markdown rendering fails
   - Input: `"**Fermentation** is important"`
   - Term identification finds "Fermentation" and splits: `{:text, "**"}, {:term, "Fermentation"}, {:text, "** is important"}`
   - Markdown rendering on fragments fails (** left as literal text)

**Solution:** Completely reversed the processing order for character messages:

**NEW FLOW (Character Messages):**
1. ✅ Convert markdown to HTML FIRST (in `process_chat_messages`)
2. ✅ Decode HTML entities
3. ✅ THEN identify knowledge terms in the HTML
4. ✅ Render segments with `html: true` (no re-processing)

**Code Changes:**

```elixir
# lib/green_man_tavern_web/live/dual_panel_live.ex
def process_chat_messages(messages, characters) do
  {processed, _seen_terms} = Enum.reduce(messages, {[], MapSet.new()}, fn message, {acc, seen_terms} ->
    # CRITICAL: Convert markdown FIRST for character messages
    content_to_process = if message.type == :character do
      case Earmark.as_html(message.content) do
        {:ok, html, _} -> decode_html_entities(html)  # Markdown→HTML→decode
        {:error, _} -> message.content
      end
    else
      message.content  # User messages: raw text
    end

    # Now identify terms in the processed content (HTML for characters, raw for users)
    segments = get_text_segments(content_to_process, characters, seen_terms: seen_terms)
    
    # Return 3-tuple: {message, segments, message_type}
    {[{message, segments, message.type} | acc], updated_seen_terms}
  end)
end
```

Template now passes `html: true` for character messages:

```heex
<%= if message.type == :user do %>
  <%= render_segments(segments) %>  <!-- Plain text, escaped -->
<% else %>
  <%= render_segments(segments, html: true) %>  <!-- Pre-rendered HTML -->
<% end %>
```

**Result:**
- ✅ Markdown formatting works perfectly (headings, bold, lists, etc.)
- ✅ Knowledge terms are properly highlighted
- ✅ Term text aligns correctly (no "FeFermentation" issues)
- ✅ No markdown syntax (**, ###) shows as literal text
- ✅ HTML entities properly decoded ('you'll' not 'you&#39;ll')

**Why This Works:**
- Markdown conversion happens BEFORE term identification
- Terms are identified in clean HTML, not fragmented by markdown syntax  
- Each knowledge term's text is extracted cleanly without markdown interference
- Final rendering just displays the pre-processed HTML as-is

**Critical Comments Added:**
- Processing flow documented in `process_chat_messages`
- Template comments explain the `html: true` flag
- Code marked as CRITICAL to prevent future breakage

---

## Other Patterns & Solutions

(Additional technical notes can be added here as they're discovered)


