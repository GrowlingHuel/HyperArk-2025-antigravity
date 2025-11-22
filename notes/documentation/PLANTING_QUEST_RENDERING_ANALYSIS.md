# Planting Quest Rendering Analysis Report

## Problem Statement
When opening a planting quest, users see:
```
Planting Day - November 9, 2025
Unable to display quest details
Quest ID: 2
```

This is the fallback error message from the `try/rescue` block, indicating that `render_planting_quest_details` is throwing an error.

## Root Cause Analysis

### 1. Code Flow
1. User clicks to expand quest → `render_quest_item/3` is called
2. Function detects `is_planting = true` (quest_type == "planting_window")
3. Calls `render_planting_quest_details(user_quest)` at line 4646
4. Function returns `Phoenix.HTML.raw(html)` (line 4910)
5. **ERROR OCCURS** at line 4778: `Phoenix.HTML.raw(collapsed_view <> expanded_view <> "</div>")`

### 2. The Bug
**Location**: Line 4778 in `dual_panel_live.ex`

```elixir
Phoenix.HTML.raw(collapsed_view <> expanded_view <> "</div>")
```

**Problem**: 
- `collapsed_view` is a **string** (from string interpolation)
- `expanded_view` is a **`Phoenix.HTML.raw()` struct** (returns `{:safe, iodata}` tuple)
- You **cannot concatenate** a string with a `{:safe, iodata}` tuple using `<>`
- This causes: `Protocol.UndefinedError: protocol String.Chars not implemented for type Tuple`

### 3. Why This Happens
`Phoenix.HTML.raw()` returns a safe HTML struct `{:safe, iodata}`, not a string. When you try to use `<>` to concatenate:
- String `<>` Tuple → Elixir tries to convert tuple to string
- Tuples don't implement `String.Chars` protocol
- **CRASH** → Caught by `try/rescue` → Shows fallback message

### 4. Data Availability Check
The `render_planting_quest_details` function expects:
- ✅ `quest.plant_tracking` - Should be array or `%{"steps" => [...]}`
- ✅ `quest.date_window_start` and `quest.date_window_end` - Optional
- ✅ `quest.description`, `quest.objective`, or `quest.title` - At least one should exist

**The function itself is working correctly** - it's generating valid HTML. The problem is **how the result is being used**.

### 5. Comparison with Regular Quests
For regular (non-planting) quests:
- `expanded_view` is built as a **string** using string interpolation
- All parts are strings → concatenation works fine

For planting quests:
- `expanded_view` is the result of `render_planting_quest_details()`
- This returns `Phoenix.HTML.raw(html)` → **Tuple, not string**
- Concatenation fails

## Solution

### Option 1: Convert to String (Recommended)
Extract the string content from `Phoenix.HTML.raw()` before concatenation:

```elixir
expanded_view_str = case expanded_view do
  {:safe, iodata} -> 
    # Convert iodata to string
    IO.iodata_to_binary(iodata)
  str when is_binary(str) -> 
    str
  _ -> 
    ""
end

Phoenix.HTML.raw(collapsed_view <> expanded_view_str <> "</div>")
```

### Option 2: Return String from Function
Change `render_planting_quest_details` to return a string instead of `Phoenix.HTML.raw()`:

```elixir
defp render_planting_quest_details(quest) do
  # ... existing code ...
  html  # Return string directly, not wrapped in Phoenix.HTML.raw()
end
```

Then wrap the final result:
```elixir
Phoenix.HTML.raw(collapsed_view <> expanded_view <> "</div>")
```

### Option 3: Proper HTML Concatenation
Use Phoenix's safe HTML concatenation:

```elixir
result = Phoenix.HTML.raw(collapsed_view)
|> Phoenix.HTML.raw(expanded_view)
|> Phoenix.HTML.raw("</div>")
```

## Recommended Fix

**Use Option 2** - it's the cleanest and most consistent:
1. Change `render_planting_quest_details` to return a string
2. The final `Phoenix.HTML.raw()` call will handle the entire result
3. Maintains consistency with how regular quests work

## Verification Steps

After fix:
1. ✅ Quest should display without error message
2. ✅ Should show: Objective, Date range, Plant list, Progress bar
3. ✅ All data should be visible if `plant_tracking` has entries
4. ✅ Should gracefully handle empty `plant_tracking` (show empty state)

## Data Requirements

For a planting quest to display properly, it needs:
- `quest_type = "planting_window"` ✅ (detected correctly)
- `plant_tracking` as array: `[%{"plant_id" => ..., "variety_name" => ..., "status" => ...}, ...]`
- `date_window_start` and `date_window_end` (optional but recommended)
- `title`, `description`, or `objective` (at least one)

If `plant_tracking` is empty `[]`, the quest will show:
- Objective text
- Date range (if available)
- Empty plant list (no error, just no plants shown)
- No progress bar (since total = 0)

## Conclusion

**The issue is NOT missing data** - it's a **type mismatch in string concatenation**. The `render_planting_quest_details` function works correctly and generates valid HTML, but the result (a `Phoenix.HTML.raw()` tuple) cannot be concatenated with strings using `<>`.

**Fix**: Change `render_planting_quest_details` to return a plain string, then wrap the final concatenated result in `Phoenix.HTML.raw()`.

