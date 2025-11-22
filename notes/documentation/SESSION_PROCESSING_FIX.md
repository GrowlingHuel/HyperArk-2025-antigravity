# Session Processing Fix - UUID Type Conversion Issue

## Problem Identified

After implementing session processing triggers, journal entries and quests were still not being generated despite detailed conversations.

## Root Cause

**UUID Type Mismatch**: The `session_id` stored in socket assigns could be:
- A **string UUID** (when freshly generated with `Sessions.generate_session_id()`)
- An **Ecto.UUID struct** (when loaded from database queries)

When `process_session_end` received a UUID struct instead of a string, the query in `Sessions.get_session_messages/1` would fail silently because Ecto queries expect string UUIDs, not structs.

## Fix Applied

### 1. UUID Conversion in Session Processing Triggers

Added UUID-to-string conversion in all three trigger points:
- `handle_event("select_character", ...)`
- `handle_event("show_tavern_home", ...)`
- `handle_event("navigate", %{"page" => "journal"}, ...)`

**Code Pattern:**
```elixir
current_session_id = 
  case socket.assigns.session_id do
    %{__struct__: Ecto.UUID} = uuid -> Ecto.UUID.cast!(uuid)
    id when is_binary(id) -> id
    other -> to_string(other)
  end
```

### 2. UUID Conversion in process_session_end

Added conversion at the start of `process_session_end/2` to ensure the session_id is always a string before being passed to `SessionProcessor.process_session/1`.

### 3. Enhanced Logging

Added detailed logging to track:
- When session processing is triggered
- The session_id being processed (with type info)
- Success/failure of processing
- Whether journal_summary and quest_data were generated

**New Log Messages:**
- `[DualPanel] 📝 User switching characters - processing current session...`
- `[DualPanel] Processing session_id: ...`
- `[DualPanel] ✅ Session processing succeeded. journal_summary: present/nil, quest_data: present/nil`
- `[DualPanel] ⚠️ Session processing failed...` (now ERROR level with more detail)

## Testing Instructions

1. **Start a conversation** with a character (e.g., The Grandmother)
2. **Send 4+ detailed messages** about a topic (e.g., composting)
3. **Switch to another character** (e.g., The Alchemist)
4. **Check logs** for:
   - `[DualPanel] 📝 User switching characters - processing current session...`
   - `[DualPanel] Processing session end for session_id: ...`
   - `[DualPanel] ✅ Session processing succeeded...`
5. **Check database**:
   ```sql
   SELECT id, session_id, session_summary 
   FROM conversation_history 
   WHERE session_id IS NOT NULL 
   ORDER BY inserted_at DESC 
   LIMIT 10;
   ```
6. **Check journal entries**:
   ```sql
   SELECT id, title, body, source_type 
   FROM journal_entries 
   WHERE source_type = 'character_conversation' 
   ORDER BY inserted_at DESC 
   LIMIT 5;
   ```
7. **Check quests**:
   ```sql
   SELECT uq.id, q.title, uq.status, uq.generated_by_character_id
   FROM user_quests uq
   JOIN quests q ON uq.quest_id = q.id
   ORDER BY uq.inserted_at DESC
   LIMIT 5;
   ```

## Expected Behavior

After this fix:
- ✅ Session processing should trigger when switching characters
- ✅ Session processing should trigger when returning to tavern
- ✅ Session processing should trigger when navigating to journal
- ✅ Journal summaries should be created (one per session)
- ✅ Quests should be generated if conversation score ≥ 8
- ✅ All processing errors should be logged clearly

## Files Modified

- `lib/green_man_tavern_web/live/dual_panel_live.ex`
  - Added UUID conversion in `handle_event("select_character", ...)`
  - Added UUID conversion in `handle_event("show_tavern_home", ...)`
  - Added UUID conversion in `handle_event("navigate", %{"page" => "journal"}, ...)`
  - Added UUID conversion in `process_session_end/2`
  - Enhanced logging throughout

## Next Steps

1. Test with a real conversation
2. Monitor logs for any remaining errors
3. Verify journal entries and quests are created
4. If issues persist, check:
   - API calls to OpenRouter (may be failing)
   - Quest scoring algorithm (may be scoring too low)
   - Session extraction (may not be finding messages)

