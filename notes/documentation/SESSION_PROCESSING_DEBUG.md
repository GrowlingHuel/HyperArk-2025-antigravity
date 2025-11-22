# Session Processing Debug Investigation

## Issue
User had detailed conversations with The Grandmother and The Alchemist about composting, but NO journal entries or quests were generated.

## Findings

### 1. Messages Have session_id
- Recent messages in database DO have session_id populated
- All messages from the conversation have the same session_id (UUID binary)

### 2. No session_summaries
- Database query shows `has_summary = false` for all recent messages
- This means `process_session_end` either:
  - Never ran
  - Ran but failed silently
  - Ran but didn't create summaries

### 3. Potential Issues

#### Issue A: session_id Type Mismatch
- `session_id` is stored as `Ecto.UUID` in database (binary format)
- `Sessions.generate_session_id()` returns a string UUID
- `Sessions.get_session_messages/1` expects a binary string
- When we pass `socket.assigns.session_id` to `process_session_end`, it might be:
  - A string (if generated fresh)
  - A binary UUID struct (if loaded from DB)
  - This could cause query failures

#### Issue B: Task.start May Not Have Access to Repo
- `process_session_end` is called inside `Task.start(fn -> ... end)`
- Tasks run in a separate process
- Need to ensure Repo is available in the task process

#### Issue C: Condition Check May Fail
- The condition checks: `socket.assigns[:selected_character] && socket.assigns[:session_id] && socket.assigns[:current_user]`
- If user switches FROM no character TO a character, `selected_character` is nil
- Session processing won't trigger

#### Issue D: Missing Error Logging
- If `SessionProcessor.process_session/1` fails, we only log a warning
- The error might be swallowed

## Recommended Fixes

1. **Convert session_id to string before passing to process_session_end**
2. **Add more detailed logging to track session processing**
3. **Ensure Repo is available in Task processes**
4. **Check if session_id needs to be converted from UUID binary to string**

